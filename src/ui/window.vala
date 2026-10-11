using Gtk;
using Adw;
using Poisk.Core;

namespace Poisk.UI {

    public class LauncherWindow : Gtk.Window {
        public enum WindowMode {
            CAPSULE,
            RESULTS,
            MENU
        }

        public enum WindowLayoutStyle {
            MONOLITHIC,
            ISLAND
        }

        private WindowMode current_mode = WindowMode.CAPSULE;
        private WindowLayoutStyle current_layout = WindowLayoutStyle.MONOLITHIC;

        private SearchEngine engine;
        private Box window_container;
        private Box root_box;
        private SystemBubble system_bubble;
        private Box? monolithic_header_box = null;
        private Separator? header_separator = null;
        private FrostedBox capsule_box;
        private PillHeader pill_header;
        private Box results_card;
        private ListBox result_list;
        private ScrolledWindow list_scroll;
        private Box menu_card;
        private AppGrid app_grid;
        private Label menu_footer_label;
        private Label footer_label;
        private Box footer_box;
        private Cancellable? current_search_cancellable = null;
        private GLib.Settings? transparency_settings = null;
        private GLib.Settings? poisk_settings = null;
        private MultiBlurManager blur_manager;
        private Gtk.CssProvider dynamic_css_provider = new Gtk.CssProvider ();
        private int target_window_height = 624;

        public LauncherWindow (SearchEngine engine) {
            Object ();
            this.engine = engine;

            // Empty title to prevent dock / window switcher detection
            this.title = "";
            target_window_height = get_target_window_height ();
            this.set_default_size (848, target_window_height);
            this.resizable = false;
            this.decorated = false; // Borderless floating window
            this.modal = true;
            this.set_hide_on_close (true);
            this.add_css_class ("poisk-window");

            blur_manager = new MultiBlurManager (this);

            setup_ui ();
            setup_key_handling ();
            setup_click_dismiss ();
            setup_css ();
            setup_system_transparency ();

            // Prewarm common SVG icons at startup before interactive rendering
            ResultRow.get_cached_icon ("org.gnome.Software", 28);
            ResultRow.get_cached_icon ("io.elementary.appcenter", 28);

            this.map.connect (() => {
                unowned var surface = this.get_surface ();
                if (surface is Gdk.Wayland.Toplevel) {
                    // Set distinct application id with NO matching .desktop file to comprehensively prevent dock inclusion
                    ((Gdk.Wayland.Toplevel) surface).set_application_id ("io.github.mrlogiousbanana.poisk.floating");
                }

                blur_manager.request_focus ();
                GLib.Timeout.add (60, () => {
                    update_blur ();
                    blur_manager.request_focus ();
                    return GLib.Source.REMOVE;
                });
            });

            // Focus on show, auto-hide on focus loss
            this.notify["is-active"].connect (() => {
                if (this.is_active) {
                    pill_header.grab_entry_focus ();
                } else if (this.visible) {
                    GLib.Timeout.add (120, () => {
                        if (!this.is_active && this.visible) {
                            this.set_visible (false);
                        }
                        return GLib.Source.REMOVE;
                    });
                }
            });

            this.notify["visible"].connect (() => {
                if (this.visible) {
                    pill_header.set_text ("");
                    switch_mode (WindowMode.CAPSULE);
                    blur_manager.request_focus ();
                    pill_header.grab_entry_focus ();
                    GLib.Timeout.add (30, () => {
                        update_blur ();
                        blur_manager.request_focus ();
                        return GLib.Source.REMOVE;
                    });
                }
            });

            switch_mode (WindowMode.CAPSULE);
        }

        private int get_target_window_height () {
            int monitor_h = 960;
            var display = Gdk.Display.get_default ();
            if (display != null) {
                var monitors = display.get_monitors ();
                if (monitors.get_n_items () > 0) {
                    var monitor = (Gdk.Monitor) monitors.get_item (0);
                    if (monitor != null) {
                        var geom = monitor.get_geometry ();
                        if (geom.height > 0) {
                            monitor_h = geom.height;
                        }
                    }
                }
            }
            int target_h = (int) (monitor_h * 0.60f + 48.0f);
            if (target_h < 560) target_h = 560;
            if (target_h > 720) target_h = 720;
            return target_h;
        }

        private void setup_click_dismiss () {
            var click_controller = new GestureClick ();
            click_controller.pressed.connect ((n_press, x, y) => {
                double cap_x = 0, cap_y = 0;
                capsule_box.translate_coordinates (window_container, 0, 0, out cap_x, out cap_y);
                int cap_w = capsule_box.get_width ();
                int cap_h = capsule_box.get_height ();

                double bub_x = 0, bub_y = 0;
                int bub_w = 0, bub_h = 0;
                if (system_bubble != null && current_layout == WindowLayoutStyle.ISLAND) {
                    system_bubble.translate_coordinates (window_container, 0, 0, out bub_x, out bub_y);
                    bub_w = system_bubble.get_width ();
                    bub_h = system_bubble.get_height ();
                }

                bool in_capsule = (x >= cap_x && x <= cap_x + cap_w && y >= cap_y && y <= cap_y + cap_h);
                bool in_bubble = (current_layout == WindowLayoutStyle.ISLAND &&
                                  x >= bub_x && x <= bub_x + bub_w && y >= bub_y && y <= bub_y + bub_h);

                if (!in_capsule && !in_bubble) {
                    this.set_visible (false);
                }
            });
            window_container.add_controller (click_controller);
        }

        private void setup_system_transparency () {
            var schema_source = SettingsSchemaSource.get_default ();
            if (schema_source != null && schema_source.lookup ("io.github.mrlogiousbanana.poisk", true) != null) {
                poisk_settings = new GLib.Settings ("io.github.mrlogiousbanana.poisk");
                poisk_settings.changed["enable-frosted-glass"].connect (() => {
                    update_transparency_mode ();
                });
                poisk_settings.changed["layout-style"].connect (() => {
                    apply_layout_style ();
                });
                poisk_settings.changed["window-opacity"].connect (() => {
                    update_dynamic_css ();
                    update_blur ();
                });
                poisk_settings.changed["blur-radius"].connect (() => {
                    update_transparency_mode ();
                    update_blur ();
                });
            }

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
                                poisk_settings.changed["enable-frosted-glass"].connect (() => {
                                    update_transparency_mode ();
                                });
                                poisk_settings.changed["layout-style"].connect (() => {
                                    apply_layout_style ();
                                });
                                poisk_settings.changed["window-opacity"].connect (() => {
                                    update_dynamic_css ();
                                    update_blur ();
                                });
                                poisk_settings.changed["blur-radius"].connect (() => {
                                    update_transparency_mode ();
                                    update_blur ();
                                });
                                break;
                            }
                        } catch (Error e) {
                        }
                    }
                }
            }

            if (schema_source != null) {
                var schema = schema_source.lookup ("io.elementary.desktop.wingpanel", true);
                if (schema != null && schema.has_key ("use-transparency")) {
                    transparency_settings = new GLib.Settings ("io.elementary.desktop.wingpanel");
                    transparency_settings.changed["use-transparency"].connect (() => {
                        update_transparency_mode ();
                    });
                }
            }

            apply_layout_style ();
            update_dynamic_css ();
            update_transparency_mode ();
        }

        private void apply_layout_style () {
            string style = "monolithic";
            if (poisk_settings != null) {
                style = poisk_settings.get_string ("layout-style");
            }

            current_layout = (style == "island") ? WindowLayoutStyle.ISLAND : WindowLayoutStyle.MONOLITHIC;

            // Reconstruct header according to layout style
            if (current_layout == WindowLayoutStyle.MONOLITHIC) {
                if (system_bubble.get_parent () != null) {
                    ((Box) system_bubble.get_parent ()).remove (system_bubble);
                }
                if (pill_header.get_parent () != null) {
                    ((Box) pill_header.get_parent ()).remove (pill_header);
                }

                system_bubble.set_mode (SystemBubble.DisplayMode.EMBEDDED);

                if (monolithic_header_box == null) {
                    monolithic_header_box = new Box (Orientation.HORIZONTAL, 0);
                    monolithic_header_box.valign = Align.START;
                    monolithic_header_box.hexpand = true;

                    header_separator = new Separator (Orientation.VERTICAL);
                    header_separator.add_css_class ("header-separator");
                    header_separator.set_size_request (1, 24);
                    header_separator.valign = Align.CENTER;
                } else {
                    if (header_separator.get_parent () != null) {
                        monolithic_header_box.remove (header_separator);
                    }
                }

                monolithic_header_box.append (system_bubble);
                monolithic_header_box.append (header_separator);
                monolithic_header_box.append (pill_header);

                capsule_box.prepend (monolithic_header_box);
                pill_header.hexpand = true;

                capsule_box.add_css_class ("monolithic-capsule");
                capsule_box.remove_css_class ("island-capsule");
            } else {
                // ISLAND mode: system_bubble sits on root_box, capsule_box only holds pill_header
                if (monolithic_header_box != null && monolithic_header_box.get_parent () != null) {
                    capsule_box.remove (monolithic_header_box);
                }
                if (system_bubble.get_parent () != null) {
                    ((Box) system_bubble.get_parent ()).remove (system_bubble);
                }
                if (pill_header.get_parent () != null) {
                    ((Box) pill_header.get_parent ()).remove (pill_header);
                }

                system_bubble.set_mode (SystemBubble.DisplayMode.STANDALONE);
                root_box.prepend (system_bubble);
                capsule_box.prepend (pill_header);

                capsule_box.remove_css_class ("monolithic-capsule");
                capsule_box.add_css_class ("island-capsule");
            }

            switch_mode (current_mode);
        }

        private void update_dynamic_css () {
            double opacity = 0.84;
            if (poisk_settings != null) {
                opacity = poisk_settings.get_double ("window-opacity");
            }
            if (opacity < 0.0) opacity = 0.0;
            if (opacity > 1.0) opacity = 1.0;

            string op_str = "%.3f".printf (opacity).replace (",", ".");

            string dynamic_css = """
                .poisk-capsule,
                .satellite-bubble,
                .system-bubble-btn {
                    background-image: linear-gradient(to bottom, rgba(255, 255, 255, %s), rgba(235, 235, 235, %s));
                }
                @media (prefers-color-scheme: dark) {
                    .poisk-capsule,
                    .satellite-bubble,
                    .system-bubble-btn {
                        background-image: linear-gradient(to bottom, rgba(44, 44, 44, %s), rgba(55, 55, 55, %s));
                    }
                }
            """.printf (op_str, op_str, op_str, op_str);

            dynamic_css_provider.load_from_string (dynamic_css);
        }

        private void update_transparency_mode () {
            bool system_reduced = false;
            if (transparency_settings != null) {
                system_reduced = !transparency_settings.get_boolean ("use-transparency");
            }

            if (system_reduced) {
                capsule_box.add_css_class ("reduce-transparency");
                this.add_css_class ("reduce-transparency");
                capsule_box.frosted = false;
                if (system_bubble != null) {
                    system_bubble.set_frosted (false);
                }
                if (blur_manager != null) {
                    blur_manager.remove_blur ();
                }
            } else {
                capsule_box.remove_css_class ("reduce-transparency");
                this.remove_css_class ("reduce-transparency");

                bool poisk_blur = true;
                int blur_r = 18;
                if (poisk_settings != null) {
                    poisk_blur = poisk_settings.get_boolean ("enable-frosted-glass");
                    blur_r = poisk_settings.get_int ("blur-radius");
                }
                bool blur_enabled = poisk_blur && (blur_r > 0);
                capsule_box.frosted = blur_enabled;
                if (system_bubble != null) {
                    system_bubble.set_frosted (blur_enabled);
                }

                if (blur_enabled) {
                    update_blur ();
                } else {
                    if (blur_manager != null) {
                        blur_manager.remove_blur ();
                    }
                }
            }
            update_dynamic_css ();
            capsule_box.queue_draw ();
        }

        public void set_frosted_enabled (bool enabled) {
            update_transparency_mode ();
        }

        public void switch_mode (WindowMode mode) {
            current_mode = mode;
            int cap_width = (current_layout == WindowLayoutStyle.MONOLITHIC) ? 740 : 680;

            switch (mode) {
                case WindowMode.CAPSULE:
                    results_card.visible = false;
                    menu_card.visible = false;
                    pill_header.visible = true;
                    pill_header.remove_css_class ("expanded-header");
                    this.remove_css_class ("expanded-card");
                    capsule_box.remove_css_class ("expanded-card");
                    capsule_box.set_size_request (cap_width, 58);
                    break;

                case WindowMode.RESULTS:
                    menu_card.visible = false;
                    results_card.visible = true;
                    pill_header.visible = true;
                    pill_header.add_css_class ("expanded-header");
                    this.add_css_class ("expanded-card");
                    capsule_box.add_css_class ("expanded-card");
                    capsule_box.set_size_request (cap_width, 444);
                    break;

                case WindowMode.MENU:
                    results_card.visible = false;
                    menu_card.visible = true;
                    pill_header.visible = true;
                    pill_header.add_css_class ("expanded-header");
                    this.add_css_class ("expanded-card");
                    capsule_box.add_css_class ("expanded-card");
                    capsule_box.set_size_request (cap_width, 444);
                    break;
            }

            GLib.Timeout.add (30, () => {
                update_blur ();
                return GLib.Source.REMOVE;
            });
        }

        private void update_blur () {
            if (blur_manager == null || capsule_box == null) return;
            if (poisk_settings != null && !poisk_settings.get_boolean ("enable-frosted-glass")) {
                blur_manager.remove_blur ();
                return;
            }
            if (transparency_settings != null && !transparency_settings.get_boolean ("use-transparency")) {
                blur_manager.remove_blur ();
                return;
            }

            int radius = 18;
            double opacity = 0.84;
            if (poisk_settings != null) {
                radius = poisk_settings.get_int ("blur-radius");
                opacity = poisk_settings.get_double ("window-opacity");
            }

            if (radius <= 0) {
                blur_manager.remove_blur ();
                return;
            }

            double cap_x = 0, cap_y = 0;
            capsule_box.translate_coordinates (window_container, 0, 0, out cap_x, out cap_y);
            int cap_w = capsule_box.get_width ();
            int cap_h = capsule_box.get_height ();
            int win_w = this.get_width ();
            int win_h = this.get_height ();

            double bub_x = 0, bub_y = 0;
            int bub_w = 0, bub_h = 0;
            if (system_bubble != null) {
                system_bubble.translate_coordinates (window_container, 0, 0, out bub_x, out bub_y);
                bub_w = system_bubble.get_width ();
                bub_h = system_bubble.get_height ();
            }

            if (cap_w <= 0 || cap_h <= 0 || win_w <= 0 || win_h <= 0) return;

            bool is_island = (current_layout == WindowLayoutStyle.ISLAND);

            // In monolithic mode: single capsule is blurred.
            // In island mode on Gala: blur strictly the search capsule (left = cap_x) so 14px gap has 0 blur spill!
            uint left = (uint) (cap_x > 0 ? cap_x : 0);
            uint top = (uint) (cap_y > 0 ? cap_y : 0);
            uint right = (uint) ((win_w > cap_x + cap_w) ? (win_w - (cap_x + cap_w)) : 0);
            uint bottom = (uint) ((win_h > cap_y + cap_h) ? (win_h - (cap_y + cap_h)) : 0);

            blur_manager.attach_blur (
                left, right, top, bottom, (uint) radius,
                is_island,
                (int) bub_x, (int) bub_y, bub_w, bub_h,
                (int) cap_x, (int) cap_y, cap_w, cap_h,
                opacity
            );
        }

        private void setup_ui () {
            window_container = new Box (Orientation.VERTICAL, 0);
            window_container.add_css_class ("poisk-window-container");
            window_container.valign = Align.FILL;
            window_container.halign = Align.FILL;
            window_container.hexpand = true;
            window_container.vexpand = true;
            window_container.set_size_request (848, target_window_height);

            root_box = new Box (Orientation.HORIZONTAL, 14);
            root_box.add_css_class ("poisk-root");
            root_box.valign = Align.START;
            root_box.halign = Align.CENTER;
            root_box.margin_start = 48;
            root_box.margin_end = 48;
            root_box.margin_top = 24;
            root_box.margin_bottom = 24;

            // Decorative system bubble widget
            system_bubble = new SystemBubble ();

            // Main Search Card (dock blur background)
            capsule_box = new FrostedBox (Orientation.VERTICAL, 0);
            capsule_box.frosted = true;
            capsule_box.blur_radius = 24.0;
            capsule_box.corner_radius = 18.0f;
            capsule_box.add_css_class ("poisk-capsule");
            capsule_box.set_size_request (740, 56);
            capsule_box.valign = Align.START;
            capsule_box.halign = Align.FILL;
            capsule_box.hexpand = true;

            pill_header = new PillHeader ();
            pill_header.search_changed.connect (on_search_changed);
            pill_header.activate.connect (on_header_activate);

            // Results Body
            results_card = new Box (Orientation.VERTICAL, 4);
            results_card.add_css_class ("poisk-results-card");
            results_card.set_size_request (-1, 384);
            results_card.valign = Align.FILL;
            results_card.halign = Align.FILL;
            results_card.vexpand = true;
            results_card.hexpand = true;
            results_card.visible = false;

            var list_content_box = new Box (Orientation.HORIZONTAL, 0);
            list_content_box.vexpand = true;
            list_content_box.hexpand = true;

            list_scroll = new ScrolledWindow ();
            list_scroll.hexpand = true;
            list_scroll.vexpand = true;
            list_scroll.hscrollbar_policy = PolicyType.NEVER;

            result_list = new ListBox ();
            result_list.hexpand = true;
            result_list.selection_mode = SelectionMode.SINGLE;
            result_list.add_css_class ("navigation-sidebar");
            result_list.row_selected.connect (on_row_selected);
            result_list.row_activated.connect (on_row_activated);

            list_scroll.set_child (result_list);
            list_content_box.append (list_scroll);

            results_card.append (list_content_box);

            var sep_foot = new Separator (Orientation.HORIZONTAL);
            results_card.append (sep_foot);

            footer_box = new Box (Orientation.HORIZONTAL, 8);
            footer_box.margin_start = 12;
            footer_box.margin_end = 12;
            footer_box.margin_top = 4;
            footer_box.margin_bottom = 6;

            footer_label = new Label ("↵ Выполнить / Открыть    ⎋ Очистить    ↑↓ Навигация");
            footer_label.add_css_class ("dim-label");
            footer_label.add_css_class ("caption");
            footer_label.halign = Align.START;
            footer_label.hexpand = true;
            footer_box.append (footer_label);

            results_card.append (footer_box);
            capsule_box.append (results_card);

            // Applications Grid Menu Body (when typing :menu or :apps)
            menu_card = new Box (Orientation.VERTICAL, 4);
            menu_card.add_css_class ("poisk-results-card");
            menu_card.set_size_request (-1, 384);
            menu_card.valign = Align.FILL;
            menu_card.halign = Align.FILL;
            menu_card.vexpand = true;
            menu_card.hexpand = true;
            menu_card.visible = false;

            app_grid = new AppGrid ();
            app_grid.item_activated.connect ((item) => {
                this.set_visible (false);
                item.execute ();
            });
            menu_card.append (app_grid);

            var sep_menu_foot = new Separator (Orientation.HORIZONTAL);
            menu_card.append (sep_menu_foot);

            var menu_footer_box = new Box (Orientation.HORIZONTAL, 8);
            menu_footer_box.margin_start = 12;
            menu_footer_box.margin_end = 12;
            menu_footer_box.margin_top = 4;
            menu_footer_box.margin_bottom = 6;

            menu_footer_label = new Label ("↵ Запустить    ⎋ Очистить    ←↑↓→ Навигация");
            menu_footer_label.add_css_class ("dim-label");
            menu_footer_label.add_css_class ("caption");
            menu_footer_label.halign = Align.START;
            menu_footer_label.hexpand = true;
            menu_footer_box.append (menu_footer_label);

            menu_card.append (menu_footer_box);
            capsule_box.append (menu_card);

            root_box.append (capsule_box);
            window_container.append (root_box);
            this.set_child (window_container);
        }

        private void on_header_activate () {
            if (current_mode == WindowMode.RESULTS) {
                activate_selected ();
            } else if (current_mode == WindowMode.MENU) {
                app_grid.activate_selected ();
            }
        }

        private void setup_key_handling () {
            var key_controller = new EventControllerKey ();
            key_controller.set_propagation_phase (PropagationPhase.CAPTURE);
            key_controller.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Escape) {
                    if (current_mode == WindowMode.RESULTS || current_mode == WindowMode.MENU || pill_header.get_text ().length > 0) {
                        pill_header.set_text ("");
                        switch_mode (WindowMode.CAPSULE);
                        return true;
                    }

                    this.set_visible (false);
                    return true;
                }

                if (current_mode == WindowMode.RESULTS) {
                    if (keyval == Gdk.Key.Down) {
                        select_next_row ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Up) {
                        select_prev_row ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                        activate_selected ();
                        return true;
                    }
                }

                if (current_mode == WindowMode.MENU) {
                    if (keyval == Gdk.Key.Right) {
                        app_grid.select_next ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Left) {
                        app_grid.select_prev ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Down) {
                        app_grid.select_down ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Up) {
                        app_grid.select_up ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                        app_grid.activate_selected ();
                        return true;
                    }
                }

                return false;
            });
            ((Gtk.Widget) this).add_controller (key_controller);
        }

        private void setup_css () {
            var provider = new Gtk.CssProvider ();
            string css = """
                window.poisk-window {
                    background: transparent;
                    background-color: transparent;
                    box-shadow: none;
                    border: none;
                    padding: 0;
                    margin: 0;
                }
                .poisk-window-container,
                .poisk-root {
                    background: transparent;
                    background-color: transparent;
                }

                /* Satellite bubble and System button - identical to dock style */
                .satellite-bubble,
                .system-bubble-btn {
                    border-radius: 16px;
                    background-color: transparent;
                    border: 1px solid rgba(0, 0, 0, 0.18);
                    box-shadow:
                        inset 0 1px 0 0 rgba(255, 255, 255, 0.96),
                        inset 0 -1px 0 0 rgba(0, 0, 0, 0.04),
                        0 8px 24px rgba(0, 0, 0, 0.16),
                        0 2px 6px rgba(0, 0, 0, 0.08);
                    padding: 0;
                    min-width: 54px;
                    min-height: 54px;
                    transition: all 180ms cubic-bezier(0.25, 0.8, 0.25, 1);
                }

                /* Embedded system bubble inside monolithic header - uniform 16px margins */
                .embedded-system-bubble {
                    margin: 16px;
                    min-width: 24px;
                    min-height: 24px;
                    opacity: 0.90;
                }

                separator.header-separator,
                .header-separator {
                    background: alpha(currentColor, 0.15);
                    min-width: 1px;
                    min-height: 24px;
                    max-height: 24px;
                    border: none;
                    padding: 0;
                    margin-top: 16px;
                    margin-bottom: 16px;
                    margin-left: 0px;
                    margin-right: 16px;
                }

                .reduce-transparency .system-bubble-btn,
                .system-bubble-btn.reduce-transparency {
                    background-image: none;
                    background-color: @bg_color;
                    opacity: 1.0;
                }

                /* Elementary Dock-like unified capsule with exact colors */
                .poisk-capsule {
                    background-color: transparent;
                    border: 1px solid rgba(0, 0, 0, 0.18);
                    box-shadow:
                        inset 0 1px 0 0 rgba(255, 255, 255, 0.96),
                        inset 0 -1px 0 0 rgba(0, 0, 0, 0.04),
                        0 10px 32px rgba(0, 0, 0, 0.18),
                        0 2px 8px rgba(0, 0, 0, 0.08);
                    border-radius: 18px;
                    padding: 0;
                    margin: 0;
                    min-height: 56px;
                    transition: all 180ms cubic-bezier(0.25, 0.8, 0.25, 1);
                }

                .reduce-transparency .poisk-capsule,
                .poisk-capsule.reduce-transparency {
                    background-image: none;
                    background: @bg_color;
                    opacity: 1.0;
                }

                .poisk-capsule.expanded-card {
                    border-radius: 18px;
                    box-shadow:
                        inset 0 1px 0 0 rgba(255, 255, 255, 0.96),
                        inset 0 -1px 0 0 rgba(0, 0, 0, 0.05),
                        0 16px 44px rgba(0, 0, 0, 0.24),
                        0 4px 12px rgba(0, 0, 0, 0.12);
                }

                /* Dark Theme adaptation matching plank-dark/dock.theme */
                @media (prefers-color-scheme: dark) {
                    .poisk-capsule,
                    .satellite-bubble,
                    .system-bubble-btn {
                        background-color: transparent;
                        border: 1px solid rgba(0, 0, 0, 0.37);
                        box-shadow:
                            inset 0 1px 0 0 rgba(180, 180, 180, 0.50),
                            inset 0 -1px 0 0 rgba(0, 0, 0, 0.40),
                            0 12px 36px rgba(0, 0, 0, 0.45),
                            0 4px 10px rgba(0, 0, 0, 0.25);
                    }

                    .poisk-capsule.expanded-card {
                        box-shadow:
                            inset 0 1px 0 0 rgba(180, 180, 180, 0.50),
                            inset 0 -1px 0 0 rgba(0, 0, 0, 0.40),
                            0 16px 48px rgba(0, 0, 0, 0.55),
                            0 5px 14px rgba(0, 0, 0, 0.30);
                    }
                }

                /* Header */
                .poisk-pill-header {
                    background: transparent;
                    border: none;
                    border-radius: 16px;
                    box-shadow: none;
                    min-height: 56px;
                    padding: 0;
                }
                .poisk-pill-header.expanded-header {
                    border-bottom: 1px solid alpha(@borders, 0.50);
                    border-bottom-left-radius: 0;
                    border-bottom-right-radius: 0;
                }

                /* Clean Entry without blue focus border */
                entry.pill-entry,
                entry.pill-entry:focus,
                entry.pill-entry:focus-within,
                entry.pill-entry text,
                entry.pill-entry text:focus,
                entry.pill-entry text:focus-within {
                    border: none;
                    background: transparent;
                    background-color: transparent;
                    box-shadow: none;
                    outline: none;
                    font-size: 16px;
                    font-weight: 400;
                    padding-right: 16px;
                }

                .monolithic-capsule .poisk-pill-header {
                    padding-left: 0px;
                    padding-right: 16px;
                    margin: 0;
                    border: none;
                }

                .monolithic-capsule entry.pill-entry,
                .monolithic-capsule entry.pill-entry:focus,
                .monolithic-capsule entry.pill-entry:focus-within,
                .monolithic-capsule entry.pill-entry text,
                .monolithic-capsule entry.pill-entry text:focus,
                .monolithic-capsule entry.pill-entry text:focus-within {
                    padding-left: 0px;
                    margin-left: 0px;
                    border: none;
                    box-shadow: none;
                    outline: none;
                }

                .island-capsule .poisk-pill-header {
                    padding-left: 16px;
                    padding-right: 16px;
                }

                .island-capsule entry.pill-entry,
                .island-capsule entry.pill-entry:focus,
                .island-capsule entry.pill-entry:focus-within,
                .island-capsule entry.pill-entry text,
                .island-capsule entry.pill-entry text:focus,
                .island-capsule entry.pill-entry text:focus-within {
                    padding-left: 0px;
                    margin-left: 0px;
                }

                /* Results & Menu Body */
                .poisk-results-card {
                    background: transparent;
                    border: none;
                    border-bottom-left-radius: 18px;
                    border-bottom-right-radius: 18px;
                    box-shadow: none;
                    padding: 6px;
                }
                list.navigation-sidebar {
                    background: transparent;
                }

                .poisk-result-row {
                    border-radius: 10px;
                    margin: 2px 8px;
                    padding: 4px;
                    transition: background 120ms ease;
                }
                .poisk-result-row:selected,
                .poisk-result-row:hover {
                    background: alpha(currentColor, 0.08);
                }

                .poisk-grid-card {
                    border-radius: 12px;
                    padding: 4px;
                    transition: all 120ms ease;
                    background: transparent;
                }
                .poisk-grid-card:hover,
                .poisk-grid-card:selected {
                    background: alpha(currentColor, 0.08);
                }

                /* Soft Drop Shadows for App Icons */
                .poisk-app-icon {
                    filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.12));
                }
                .poisk-grid-icon {
                    filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.14));
                }

                /* Search Results List Typography */
                .poisk-row-title {
                    font-size: 14.5px;
                    font-weight: 600;
                    color: @theme_fg_color;
                }
                .poisk-row-subtitle {
                    font-size: 12px;
                    opacity: 0.68;
                }
                .poisk-row-badge {
                    font-size: 13px;
                    font-weight: 500;
                    opacity: 0.80;
                }

                /* Menu Category Headers */
                .poisk-category-emoji {
                    font-size: 17px;
                    margin-right: 2px;
                }
                .poisk-category-title {
                    font-size: 15px;
                    font-weight: 700;
                    color: @theme_fg_color;
                }
                .poisk-category-count {
                    font-size: 12px;
                    font-weight: 600;
                    opacity: 0.60;
                    margin-right: 6px;
                }
                .poisk-category-separator {
                    opacity: 0.30;
                    min-height: 1px;
                }
            """;
            provider.load_from_string (css);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_USER
            );
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                dynamic_css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_USER + 10
            );
        }

        private void on_search_changed () {
            string text = pill_header.get_text ();
            trigger_search (text);
        }

        private void trigger_search (string query) {
            if (current_search_cancellable != null) {
                current_search_cancellable.cancel ();
            }
            current_search_cancellable = new Cancellable ();

            execute_search.begin (query, current_search_cancellable);
        }

        private async void execute_search (string query, Cancellable cancellable) {
            string q = query.strip ();
            if (q.length == 0) {
                switch_mode (WindowMode.CAPSULE);
                return;
            }

            if (q == ":menu" || q.has_prefix (":menu ") || q == ":apps" || q.has_prefix (":apps ")) {
                string filter = "";
                if (q.has_prefix (":menu ")) {
                    filter = q.substring (6).strip ();
                } else if (q.has_prefix (":apps ")) {
                    filter = q.substring (6).strip ();
                }
                var all_apps = engine.get_all_applications ();
                var filtered = new List<SearchItem> ();
                foreach (var app in all_apps) {
                    if (filter.length == 0) {
                        filtered.append (app);
                    } else if (SearchEngine.fuzzy_score (filter, app.title) > 0 ||
                               SearchEngine.fuzzy_score (filter, app.subtitle) > 0 ||
                               SearchEngine.fuzzy_score (filter, app.category) > 0) {
                        filtered.append (app);
                    }
                }
                app_grid.set_items (filtered);
                switch_mode (WindowMode.MENU);
                menu_footer_label.set_text ("↵ Запустить    ⎋ Очистить    ←↑↓→ Навигация (%u прил.)".printf (filtered.length ()));
                return;
            }

            var items = yield engine.query (query, cancellable);
            if (cancellable.is_cancelled ()) return;

            switch_mode (WindowMode.RESULTS);
            footer_label.set_text ("↵ Выполнить / Открыть    ⎋ Очистить    ↑↓ Навигация");

            // Clear previous list
            ListBoxRow? child = result_list.get_first_child () as ListBoxRow;
            while (child != null) {
                var next = child.get_next_sibling () as ListBoxRow;
                result_list.remove (child);
                child = next;
            }

            // Populate results (cap according to max-results setting)
            int max_limit = 30;
            if (poisk_settings != null) {
                max_limit = poisk_settings.get_int ("max-results");
            }
            int count = 0;
            foreach (var item in items) {
                if (count >= max_limit) break;
                var row = new ResultRow (item);
                result_list.append (row);
                count++;
            }

            // Auto-select first item
            var first = result_list.get_row_at_index (0);
            if (first != null) {
                result_list.select_row (first);
            }
        }

        private void on_row_selected (ListBoxRow? row) {
        }

        private void on_row_activated (ListBoxRow row) {
            var result_row = row as ResultRow;
            if (result_row != null) {
                var item = result_row.item;
                this.set_visible (false);
                item.execute ();
            }
        }

        private void activate_selected () {
            var row = result_list.get_selected_row ();
            if (row != null) {
                on_row_activated (row);
            }
        }

        private void select_next_row () {
            var current = result_list.get_selected_row ();
            int idx = (current != null) ? current.get_index () + 1 : 0;
            var next = result_list.get_row_at_index (idx);
            if (next != null) {
                result_list.select_row (next);
                ensure_row_visible (next);
            }
        }

        private void select_prev_row () {
            var current = result_list.get_selected_row ();
            int idx = (current != null) ? current.get_index () - 1 : 0;
            if (idx >= 0) {
                var prev = result_list.get_row_at_index (idx);
                if (prev != null) {
                    result_list.select_row (prev);
                    ensure_row_visible (prev);
                }
            }
        }

        private void ensure_row_visible (ListBoxRow row) {
            var adj = list_scroll.get_vadjustment ();
            double y = 0;
            row.translate_coordinates (result_list, 0, 0, null, out y);
            int height = row.get_height ();
            if (y < adj.get_value ()) {
                adj.set_value (y);
            } else if (y + height > adj.get_value () + adj.get_page_size ()) {
                adj.set_value (y + height - adj.get_page_size ());
            }
        }
    }
}
