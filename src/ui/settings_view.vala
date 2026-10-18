using Gtk;
using Adw;

namespace Poisk.UI {

    public class SettingsView : Box {
        private GLib.Settings? poisk_settings = null;
        private GLib.Settings? wm_settings = null;
        private GLib.Settings? wingpanel_settings = null;
        private GLib.Settings? mutter_settings = null;
        private GLib.Settings? media_keys = null;
        private GLib.Settings? cinnamon_keybindings = null;
        private Adw.Clamp clamp;
        private Box content_box;
        private Adw.PreferencesPage? target_page = null;
        private bool is_recording_shortcut = false;
        private EventControllerKey? shortcut_controller = null;
        private string prev_recorded_shortcut = "Super";
        private bool super_key_held = false;

        public SettingsView (Adw.PreferencesPage? target_page = null) {
            Object (orientation: Orientation.VERTICAL, spacing: 0);
            this.target_page = target_page;

            clamp = new Adw.Clamp ();
            clamp.maximum_size = 680;
            clamp.tightening_threshold = 480;
            clamp.margin_top = 18;
            clamp.margin_bottom = 24;
            clamp.margin_start = 18;
            clamp.margin_end = 18;
            clamp.hexpand = true;
            clamp.vexpand = true;

            content_box = new Box (Orientation.VERTICAL, 24);
            content_box.hexpand = true;
            clamp.set_child (content_box);

            this.hexpand = true;
            this.vexpand = true;

            if (target_page == null) {
                this.append (clamp);
            }

            init_settings ();
            build_ui ();
        }

        private void add_group (Adw.PreferencesGroup group) {
            if (target_page != null) {
                target_page.add (group);
            } else {
                content_box.append (group);
            }
        }

        private void init_settings () {
            var schema_source = SettingsSchemaSource.get_default ();
            if (schema_source != null) {
                if (schema_source.lookup ("io.github.mrlogiousbanana.poisk", true) != null) {
                    poisk_settings = new GLib.Settings ("io.github.mrlogiousbanana.poisk");
                }
                if (schema_source.lookup ("io.elementary.desktop.wm.behavior", true) != null) {
                    wm_settings = new GLib.Settings ("io.elementary.desktop.wm.behavior");
                }
                if (schema_source.lookup ("io.elementary.desktop.wingpanel", true) != null) {
                    var schema = schema_source.lookup ("io.elementary.desktop.wingpanel", true);
                    if (schema != null && schema.has_key ("use-transparency")) {
                        wingpanel_settings = new GLib.Settings ("io.elementary.desktop.wingpanel");
                    }
                }
                if (schema_source.lookup ("org.gnome.mutter", true) != null) {
                    mutter_settings = new GLib.Settings ("org.gnome.mutter");
                }
                if (schema_source.lookup ("org.gnome.settings-daemon.plugins.media-keys", true) != null) {
                    media_keys = new GLib.Settings ("org.gnome.settings-daemon.plugins.media-keys");
                }
                if (schema_source.lookup ("org.cinnamon.desktop.keybindings", true) != null) {
                    cinnamon_keybindings = new GLib.Settings ("org.cinnamon.desktop.keybindings");
                }
            }

            // Fallback for poisk_settings when running in Switchboard / Nix wrapper where XDG_DATA_DIRS may not include ~/.local/share
            if (poisk_settings == null) {
                string[] search_dirs = {
                    Path.build_filename (Environment.get_user_data_dir (), "glib-2.0", "schemas"),
                    Path.build_filename (Environment.get_home_dir (), ".local", "share", "glib-2.0", "schemas"),
                };
                foreach (var dir in search_dirs) {
                    if (FileUtils.test (dir, FileTest.IS_DIR)) {
                        try {
                            var custom_source = new SettingsSchemaSource.from_directory (dir, schema_source, false);
                            var schema = custom_source.lookup ("io.github.mrlogiousbanana.poisk", true);
                            if (schema != null) {
                                poisk_settings = new GLib.Settings.full (schema, null, null);
                                break;
                            }
                        } catch (Error e) {
                            // try next dir
                        }
                    }
                }
            }
        }

        private void build_ui () {
            // Group 1: Appearance
            var appearance_group = new Adw.PreferencesGroup ();
            appearance_group.title = "Внешний вид";
            appearance_group.description = "Настройка визуального стиля, прозрачности и размытия";
            add_group (appearance_group);

            // 1. Layout Style ComboRow
            var style_model = new StringList (new string[] {
                "Монолитный (единая капсула стиля Plank/Spotlight)",
                "С островком (сателлитный значок и поиск)"
            });
            var layout_row = new Adw.ComboRow ();
            layout_row.title = "Форм-фактор оформления";
            layout_row.subtitle = "Выберите между монолитной капсулой или стилем с отдельным островком";
            layout_row.model = style_model;

            if (poisk_settings != null) {
                string current_style = poisk_settings.get_string ("layout-style");
                layout_row.selected = (current_style == "island") ? 1 : 0;
                layout_row.notify["selected"].connect (() => {
                    poisk_settings.set_string ("layout-style", (layout_row.selected == 1) ? "island" : "monolithic");
                });
            }
            appearance_group.add (layout_row);

            // 2. Frosted Glass Toggle
            var frosted_row = new Adw.SwitchRow ();
            frosted_row.title = "Эффект размытия (Frosted Glass)";
            frosted_row.subtitle = "Включить размытие фона под поверхностью лаунчера";
            if (poisk_settings != null) {
                poisk_settings.bind ("enable-frosted-glass", frosted_row, "active", SettingsBindFlags.DEFAULT);
            }
            appearance_group.add (frosted_row);

            // 3. Opacity Slider
            var opacity_row = new Adw.ActionRow ();
            opacity_row.title = "Непрозрачность окна";
            opacity_row.subtitle = "Регулировка плотности фона и матового стекла (0% — прозрачное, 100% — сплошное)";

            var opacity_adj = new Adjustment (84, 0, 100, 1, 5, 0);
            var opacity_scale = new Scale (Orientation.HORIZONTAL, opacity_adj);
            opacity_scale.set_size_request (170, -1);
            opacity_scale.draw_value = true;
            opacity_scale.value_pos = PositionType.RIGHT;
            opacity_scale.valign = Align.CENTER;
            opacity_scale.set_format_value_func ((scale, val) => {
                return "%d%%".printf ((int) val);
            });

            if (poisk_settings != null) {
                opacity_adj.value = (int) (poisk_settings.get_double ("window-opacity") * 100.0);
                opacity_adj.value_changed.connect (() => {
                    poisk_settings.set_double ("window-opacity", opacity_adj.value / 100.0);
                });
            }

            var opacity_reset_btn = new Button.from_icon_name ("edit-undo-symbolic");
            opacity_reset_btn.add_css_class ("flat");
            opacity_reset_btn.valign = Align.CENTER;
            opacity_reset_btn.tooltip_text = "Сбросить к значению по умолчанию (84%)";
            opacity_reset_btn.clicked.connect (() => {
                opacity_adj.value = 84;
            });

            opacity_row.add_suffix (opacity_scale);
            opacity_row.add_suffix (opacity_reset_btn);
            appearance_group.add (opacity_row);

            // 4. Blur Radius Slider
            var blur_row = new Adw.ActionRow ();
            blur_row.title = "Радиус размытия композитора";
            blur_row.subtitle = "Сила сглаживания фонового изображения в пикселях";

            var blur_adj = new Adjustment (18, 0, 48, 1, 4, 0);
            var blur_scale = new Scale (Orientation.HORIZONTAL, blur_adj);
            blur_scale.set_size_request (170, -1);
            blur_scale.draw_value = true;
            blur_scale.value_pos = PositionType.RIGHT;
            blur_scale.valign = Align.CENTER;
            blur_scale.set_format_value_func ((scale, val) => {
                return "%d px".printf ((int) val);
            });

            if (poisk_settings != null) {
                blur_adj.value = poisk_settings.get_int ("blur-radius");
                blur_adj.value_changed.connect (() => {
                    poisk_settings.set_int ("blur-radius", (int) blur_adj.value);
                });
            }

            var blur_reset_btn = new Button.from_icon_name ("edit-undo-symbolic");
            blur_reset_btn.add_css_class ("flat");
            blur_reset_btn.valign = Align.CENTER;
            blur_reset_btn.tooltip_text = "Сбросить к значению по умолчанию (18 px)";
            blur_reset_btn.clicked.connect (() => {
                blur_adj.value = 18;
            });

            blur_row.add_suffix (blur_scale);
            blur_row.add_suffix (blur_reset_btn);
            appearance_group.add (blur_row);

            if (wingpanel_settings != null) {
                wingpanel_settings.changed["use-transparency"].connect (() => {
                    update_transparency_sensitivity (opacity_row, blur_row, frosted_row, layout_row);
                });
            }

            frosted_row.notify["active"].connect (() => {
                update_transparency_sensitivity (opacity_row, blur_row, frosted_row, layout_row);
            });

            layout_row.notify["selected"].connect (() => {
                update_transparency_sensitivity (opacity_row, blur_row, frosted_row, layout_row);
            });

            update_transparency_sensitivity (opacity_row, blur_row, frosted_row, layout_row);

            // 5. Max results (compact ActionRow + SpinButton)
            var max_results_row = new Adw.ActionRow ();
            max_results_row.title = "Максимум результатов";
            max_results_row.subtitle = "Лимит элементов в списке поисковой выдачи (от 5 до 50)";

            var max_results_adjustment = new Adjustment (30, 5, 50, 5, 10, 0);
            if (poisk_settings != null) {
                max_results_adjustment.value = poisk_settings.get_int ("max-results");
                max_results_adjustment.value_changed.connect (() => {
                    poisk_settings.set_int ("max-results", (int) max_results_adjustment.value);
                });
            }

            var max_results_spin = new SpinButton (max_results_adjustment, 5, 0);
            max_results_spin.valign = Align.CENTER;
            max_results_spin.numeric = true;
            max_results_spin.set_width_chars (4);
            max_results_spin.max_width_chars = 4;
            max_results_spin.halign = Align.END;

            max_results_row.add_suffix (max_results_spin);
            appearance_group.add (max_results_row);

            // Group 2: System Integration
            var integration_group = new Adw.PreferencesGroup ();
            integration_group.title = "Интеграция с системой";
            integration_group.description = "Горячие клавиши и автозапуск";
            add_group (integration_group);

            // Shortcut row with interactive recorder
            var shortcut_row = new Adw.ActionRow ();
            shortcut_row.title = "Клавиша вызова";
            shortcut_row.subtitle = "Нажмите кнопку справа, чтобы задать клавишу или сочетание";

            var shortcut_btn = new Button.with_label ("Super");
            shortcut_btn.valign = Align.CENTER;
            shortcut_btn.add_css_class ("pill");

            init_shortcut_ui (shortcut_btn);
            setup_shortcut_recorder (shortcut_btn);

            shortcut_row.add_suffix (shortcut_btn);
            integration_group.add (shortcut_row);

            var autostart_row = new Adw.SwitchRow ();
            autostart_row.title = "Автозапуск в фоне";
            autostart_row.subtitle = "Запускать фоновую службу Poisk при входе в сеанс";
            string autostart_path = Path.build_filename (Environment.get_user_config_dir (), "autostart", "io.github.mrlogiousbanana.poisk.desktop");
            autostart_row.active = FileUtils.test (autostart_path, FileTest.EXISTS);
            autostart_row.notify["active"].connect (() => {
                set_autostart_enabled (autostart_row.active);
            });
            integration_group.add (autostart_row);

            // Group 3: Search Providers
            var providers_group = new Adw.PreferencesGroup ();
            providers_group.title = "Источники поиска";
            providers_group.description = "Включение и отключение категорий поисковой выдачи";
            add_group (providers_group);

            var apps_row = new Adw.SwitchRow ();
            apps_row.title = "Приложения";
            apps_row.subtitle = "Поиск по установленным приложениям системы (.desktop)";
            if (poisk_settings != null) {
                poisk_settings.bind ("enable-apps", apps_row, "active", SettingsBindFlags.DEFAULT);
            }
            providers_group.add (apps_row);

            var windows_row = new Adw.SwitchRow ();
            windows_row.title = "Открытые окна";
            windows_row.subtitle = "Быстрый поиск и переключение между запущенными окнами";
            if (poisk_settings != null) {
                poisk_settings.bind ("enable-windows", windows_row, "active", SettingsBindFlags.DEFAULT);
            }
            providers_group.add (windows_row);

            var calc_row = new Adw.SwitchRow ();
            calc_row.title = "Калькулятор";
            calc_row.subtitle = "Мгновенное вычисление математических выражений";
            if (poisk_settings != null) {
                poisk_settings.bind ("enable-calc", calc_row, "active", SettingsBindFlags.DEFAULT);
            }
            providers_group.add (calc_row);

            // Group 4: Application Groups
            var groups_prefs = new Adw.PreferencesGroup ();
            groups_prefs.title = "Группы приложений";
            groups_prefs.description = "Кастомные метки, скрытие и группировка в меню";
            add_group (groups_prefs);

            var group_menu_row = new Adw.SwitchRow ();
            group_menu_row.title = "Группировать приложения в меню";
            group_menu_row.subtitle = "Отображать приложения по секциям в режиме обзора (:menu)";
            if (poisk_settings != null) {
                poisk_settings.bind ("group-apps-in-menu", group_menu_row, "active", SettingsBindFlags.DEFAULT);
            }
            groups_prefs.add (group_menu_row);

            var manage_groups_row = new Adw.ActionRow ();
            manage_groups_row.title = "Настроить группы и скрытые приложения";
            manage_groups_row.subtitle = "Изменение порядка, Drag &amp; Drop и скрытие программ";
            var manage_btn = new Button.with_label ("Настроить...");
            manage_btn.valign = Align.CENTER;
            manage_btn.add_css_class ("suggested-action");
            manage_btn.clicked.connect (() => {
                try {
                    string[] argv = { "poisk", "--manage-groups" };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                } catch (Error e) {
                    warning ("Failed to open group manager: %s", e.message);
                }
            });
            manage_groups_row.add_suffix (manage_btn);
            manage_groups_row.activatable_widget = manage_btn;
            groups_prefs.add (manage_groups_row);

            // Group 5: Commands
            var commands_prefs = new Adw.PreferencesGroup ();
            commands_prefs.title = "Команды и быстрые действия";
            commands_prefs.description = "Встроенные команды системы и пользовательские скрипты";
            add_group (commands_prefs);

            var manage_commands_row = new Adw.ActionRow ();
            manage_commands_row.title = "Настроить команды поиска";
            manage_commands_row.subtitle = "Скрытие системных действий, добавление своих команд и значков";
            var manage_cmds_btn = new Button.with_label ("Настроить...");
            manage_cmds_btn.valign = Align.CENTER;
            manage_cmds_btn.add_css_class ("suggested-action");
            manage_cmds_btn.clicked.connect (() => {
                try {
                    string[] argv = { "poisk", "--manage-commands" };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                } catch (Error e) {
                    warning ("Failed to open command manager: %s", e.message);
                }
            });
            manage_commands_row.add_suffix (manage_cmds_btn);
            manage_commands_row.activatable_widget = manage_cmds_btn;
            commands_prefs.add (manage_commands_row);

            // Group 6: About
            var about_group = new Adw.PreferencesGroup ();
            about_group.title = "О программе";
            add_group (about_group);

            var version_row = new Adw.ActionRow ();
            version_row.title = "Poisk 1.1.0";
            version_row.subtitle = "GTK-ориентированный лёгкий аналог Spotlight";
            var icon = new Image.from_icon_name ("system-search");
            icon.pixel_size = 32;
            version_row.add_prefix (icon);
            about_group.add (version_row);

            var repo_row = new Adw.ActionRow ();
            repo_row.title = "Репозиторий Poisk (Yatta-Project)";
            repo_row.subtitle = "https://github.com/Yatta-Project/poisk";
            var open_repo_btn = new Button.from_icon_name ("external-link-symbolic");
            open_repo_btn.valign = Align.CENTER;
            open_repo_btn.clicked.connect (() => {
                open_url ("https://github.com/Yatta-Project/poisk");
            });
            repo_row.add_suffix (open_repo_btn);
            about_group.add (repo_row);
        }

        private void update_transparency_sensitivity (Adw.ActionRow opacity_row, Adw.ActionRow blur_row, Adw.SwitchRow frosted_row, Adw.ComboRow layout_row) {
            bool sys_trans = true;
            if (wingpanel_settings != null) {
                sys_trans = wingpanel_settings.get_boolean ("use-transparency");
            }

            bool is_pantheon = (wingpanel_settings != null || wm_settings != null);
            bool is_island = (layout_row.selected == 1);

            opacity_row.sensitive = sys_trans;
            if (!sys_trans) {
                opacity_row.subtitle = "Отключено параметрами системы (Включён режим уменьшения прозрачности)";
            } else {
                opacity_row.subtitle = "Регулировка плотности фона и матового стекла (0% — прозрачное, 100% — сплошное)";
            }

            if (!sys_trans) {
                frosted_row.sensitive = false;
                frosted_row.subtitle = "Отключено параметрами системы (Включён режим уменьшения прозрачности)";
                blur_row.visible = false;
            } else if (is_pantheon && is_island) {
                frosted_row.sensitive = false;
                frosted_row.subtitle = "Не поддерживается композитором Gala в режиме с островком (доступно в монолитном стиле)";
                blur_row.visible = false;
            } else {
                frosted_row.sensitive = true;
                frosted_row.subtitle = "Включить размытие фона под поверхностью лаунчера";
                blur_row.visible = frosted_row.active;
                blur_row.subtitle = "Сила сглаживания фонового изображения в пикселях";
            }
        }

        private void init_shortcut_ui (Button shortcut_btn) {
            string current = "Super";
            if (poisk_settings != null) {
                try {
                    current = poisk_settings.get_string ("shortcut-name");
                    if (current == "") current = "Super";
                } catch (Error e) {
                    current = "Super";
                }
            } else if (wm_settings != null) {
                bool is_super_poisk = (wm_settings.get_string ("overlay-action") == "poisk --toggle");
                current = is_super_poisk ? "Super" : "<Super>space";
            }
            update_shortcut_button_label (shortcut_btn, current);
        }

        private void update_shortcut_button_label (Button shortcut_btn, string accel_name) {
            if (accel_name == "Super" || accel_name == "Super_L" || accel_name == "Super_R") {
                shortcut_btn.label = "Super";
            } else {
                uint keyval;
                Gdk.ModifierType mods;
                Gtk.accelerator_parse (accel_name, out keyval, out mods);
                string label = Gtk.accelerator_get_label (keyval, mods);
                shortcut_btn.label = (label != "") ? label : accel_name;
            }
        }

        private void finish_recording_shortcut (Button shortcut_btn) {
            if (shortcut_controller != null) {
                shortcut_btn.remove_controller (shortcut_controller);
                shortcut_controller = null;
            }
            is_recording_shortcut = false;
            super_key_held = false;
            shortcut_btn.remove_css_class ("suggested-action");
        }

        private void setup_shortcut_recorder (Button shortcut_btn) {
            shortcut_btn.clicked.connect (() => {
                if (is_recording_shortcut) {
                    finish_recording_shortcut (shortcut_btn);
                    apply_shortcut (prev_recorded_shortcut);
                    update_shortcut_button_label (shortcut_btn, prev_recorded_shortcut);
                    return;
                }

                is_recording_shortcut = true;
                super_key_held = false;
                shortcut_btn.add_css_class ("suggested-action");
                shortcut_btn.label = "Нажмите клавиши... (Esc — отмена)";

                prev_recorded_shortcut = "Super";
                if (poisk_settings != null) {
                    try {
                        prev_recorded_shortcut = poisk_settings.get_string ("shortcut-name");
                        if (prev_recorded_shortcut == "") prev_recorded_shortcut = "Super";
                    } catch (Error e) {}
                }

                // Temporarily silence compositor triggers so pressing Super does not launch Poisk during recording
                if (wm_settings != null) {
                    try {
                        wm_settings.set_string ("overlay-action", "");
                    } catch (Error e) {}
                }
                if (mutter_settings != null) {
                    try {
                        mutter_settings.set_string ("overlay-key", "");
                    } catch (Error e) {}
                }

                shortcut_controller = new EventControllerKey ();
                shortcut_controller.set_propagation_phase (PropagationPhase.CAPTURE);

                shortcut_controller.key_pressed.connect ((keyval, keycode, state) => {
                    if (keyval == Gdk.Key.Escape) {
                        finish_recording_shortcut (shortcut_btn);
                        apply_shortcut (prev_recorded_shortcut);
                        update_shortcut_button_label (shortcut_btn, prev_recorded_shortcut);
                        return true;
                    }

                    // Single Super key detection (wait for key_released to distinguish single Super tap from combo)
                    if (keyval == Gdk.Key.Super_L || keyval == Gdk.Key.Super_R ||
                        keyval == Gdk.Key.Meta_L || keyval == Gdk.Key.Meta_R) {
                        super_key_held = true;
                        return true;
                    }

                    // Ignore standalone modifier presses
                    if (keyval == Gdk.Key.Shift_L || keyval == Gdk.Key.Shift_R ||
                        keyval == Gdk.Key.Control_L || keyval == Gdk.Key.Control_R ||
                        keyval == Gdk.Key.Alt_L || keyval == Gdk.Key.Alt_R) {
                        return false;
                    }

                    // A regular key is pressed (either with modifiers or alone)
                    super_key_held = false;
                    var mod_mask = Gtk.accelerator_get_default_mod_mask ();
                    var cleaned_mods = state & mod_mask;

                    string accel = Gtk.accelerator_name (keyval, cleaned_mods);
                    if (accel != "") {
                        finish_recording_shortcut (shortcut_btn);
                        apply_shortcut (accel);
                        update_shortcut_button_label (shortcut_btn, accel);
                        return true;
                    }

                    return false;
                });

                shortcut_controller.key_released.connect ((keyval, keycode, state) => {
                    if (super_key_held && (keyval == Gdk.Key.Super_L || keyval == Gdk.Key.Super_R ||
                                           keyval == Gdk.Key.Meta_L || keyval == Gdk.Key.Meta_R)) {
                        // User tapped Super alone!
                        finish_recording_shortcut (shortcut_btn);
                        apply_shortcut ("Super");
                        update_shortcut_button_label (shortcut_btn, "Super");
                    }
                });

                shortcut_btn.add_controller (shortcut_controller);
                shortcut_btn.grab_focus ();
            });
        }

        private void apply_shortcut (string accel_name) {
            if (poisk_settings != null) {
                try {
                    poisk_settings.set_string ("shortcut-name", accel_name);
                } catch (Error e) {
                    warning ("Failed to save shortcut-name: %s", e.message);
                }
            }

            const string POISK_KB_PATH = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/poisk/";

            if (accel_name == "Super" || accel_name == "Super_L" || accel_name == "Super_R") {
                // Single Super key mode
                if (wm_settings != null) {
                    wm_settings.set_string ("overlay-action", "poisk --toggle");
                }
                if (mutter_settings != null) {
                    mutter_settings.set_string ("overlay-key", "Super_L");
                }
                if (media_keys != null) {
                    string[] current = media_keys.get_strv ("custom-keybindings");
                    string[] updated = {};
                    foreach (var b in current) {
                        if (b != POISK_KB_PATH) {
                            updated += b;
                        }
                    }
                    media_keys.set_strv ("custom-keybindings", updated);
                }
            } else {
                // Key combination or single custom key mode
                if (wm_settings != null) {
                    wm_settings.set_string ("overlay-action", "io.elementary.wingpanel --toggle-indicator=app-launcher");
                }
                if (mutter_settings != null) {
                    mutter_settings.set_string ("overlay-key", "Super_L");
                }
                if (media_keys != null) {
                    string[] current = media_keys.get_strv ("custom-keybindings");
                    bool exists = false;
                    foreach (var b in current) {
                        if (b == POISK_KB_PATH) {
                            exists = true;
                            break;
                        }
                    }
                    if (!exists) {
                        string[] updated = current;
                        updated += POISK_KB_PATH;
                        media_keys.set_strv ("custom-keybindings", updated);
                    }

                    try {
                        var poisk_kb = new GLib.Settings.with_path ("org.gnome.settings-daemon.plugins.media-keys.custom-keybinding", POISK_KB_PATH);
                        poisk_kb.set_string ("name", "Poisk");
                        poisk_kb.set_string ("command", "poisk --toggle");
                        poisk_kb.set_string ("binding", accel_name);
                    } catch (Error e) {
                        warning ("Failed to configure custom-keybinding: %s", e.message);
                    }
                }
            }

            if (cinnamon_keybindings != null) {
                try {
                    string[] current = cinnamon_keybindings.get_strv ("custom-list");
                    bool exists = false;
                    foreach (var item in current) {
                        if (item == "custom-poisk") {
                            exists = true;
                            break;
                        }
                    }
                    if (!exists) {
                        string[] updated = current;
                        updated += "custom-poisk";
                        cinnamon_keybindings.set_strv ("custom-list", updated);
                    }

                    string kb_path = "/org/cinnamon/desktop/keybindings/custom-keybindings/custom-poisk/";
                    var poisk_kb = new GLib.Settings.with_path ("org.cinnamon.desktop.keybindings.custom-keybinding", kb_path);
                    poisk_kb.set_string ("name", "Poisk");
                    poisk_kb.set_string ("command", "poisk --toggle");
                    string cinnamon_binding = (accel_name == "Super" || accel_name == "Super_L" || accel_name == "Super_R") ? "Super_L" : accel_name;
                    string[] bindings = { cinnamon_binding };
                    poisk_kb.set_strv ("binding", bindings);
                } catch (Error e) {
                    warning ("Failed to configure Cinnamon custom-keybinding: %s", e.message);
                }
            }
        }

        private void set_autostart_enabled (bool enable) {
            string autostart_dir = Path.build_filename (Environment.get_user_config_dir (), "autostart");
            string autostart_path = Path.build_filename (autostart_dir, "io.github.mrlogiousbanana.poisk.desktop");

            if (enable) {
                try {
                    DirUtils.create_with_parents (autostart_dir, 0755);
                    string desktop_content = """[Desktop Entry]
Name=Поиск
Name[en]=Poisk
GenericName=Application Launcher
Comment=Fast native launcher and productivity palette for Pantheon and Linux
Exec=poisk --background
Icon=system-search
Terminal=false
Type=Application
Categories=Utility;Core;
X-GNOME-Autostart-enabled=true
NoDisplay=false
""";
                    FileUtils.set_contents (autostart_path, desktop_content);
                } catch (Error e) {
                    warning ("Failed to create autostart entry: %s", e.message);
                }
            } else {
                if (FileUtils.test (autostart_path, FileTest.EXISTS)) {
                    FileUtils.unlink (autostart_path);
                }
            }
        }

        private void open_url (string url) {
            try {
                string[] argv = { "xdg-open", url };
                Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
            } catch (Error e) {
                warning ("Failed to open url: %s", e.message);
            }
        }
    }
}
