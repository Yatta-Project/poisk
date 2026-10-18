using Gtk;
using Adw;
using Poisk.Core;
using Poisk.Bridges;
using Poisk.Providers;
using Poisk.UI;

namespace Poisk {

    public class Application : Adw.Application {
        private SearchEngine engine;
        private DesktopBridge desktop_bridge;
        private LauncherWindow? window = null;
        private int64 last_toggle_time = 0;
        private GlanceManager glance_manager;
        private GlanceDBusService glance_dbus_service;
        private UpdatesGlanceProvider updates_glance_provider;
        private CalendarGlanceProvider calendar_glance_provider;

        public Application () {
            Object (
                application_id: "io.github.mrlogiousbanana.poisk",
                flags: ApplicationFlags.HANDLES_COMMAND_LINE
            );
        }

        private PoiskPreferencesWindow? prefs_window = null;
        private GroupManagerDialog? groups_window = null;

        public void show_preferences () {
            if (prefs_window == null) {
                prefs_window = new PoiskPreferencesWindow (window);
                prefs_window.close_request.connect (() => {
                    prefs_window = null;
                    return false;
                });
            }
            prefs_window.present ();
        }

        public void show_manage_groups () {
            if (groups_window == null) {
                Gtk.Window? parent = (prefs_window != null && prefs_window.visible) ? (Gtk.Window) prefs_window : (Gtk.Window?) window;
                groups_window = new GroupManagerDialog (parent);
                groups_window.close_request.connect (() => {
                    groups_window = null;
                    return false;
                });
            }
            groups_window.present ();
        }

        protected override void startup () {
            base.startup ();
            Adw.init ();
            Granite.init ();

            // Detect desktop bridge
            var de = DesktopBridge.get_current_desktop ();
            if (de == DesktopEnvironment.GNOME) {
                desktop_bridge = new GnomeBridge ();
            } else if (de == DesktopEnvironment.CINNAMON) {
                desktop_bridge = new CinnamonBridge ();
            } else {
                desktop_bridge = new PantheonBridge ();
            }

            // Init core search engine and register only core providers
            engine = new SearchEngine ();
            var app_provider = new AppProvider ();
            var window_provider = new WindowProvider (desktop_bridge);
            var calc_provider = new CalcProvider ();

            var schema_source = SettingsSchemaSource.get_default ();
            if (schema_source != null && schema_source.lookup ("io.github.mrlogiousbanana.poisk", true) != null) {
                var poisk_settings = new GLib.Settings ("io.github.mrlogiousbanana.poisk");
                app_provider.is_enabled = poisk_settings.get_boolean ("enable-apps");
                window_provider.is_enabled = poisk_settings.get_boolean ("enable-windows");
                calc_provider.is_enabled = poisk_settings.get_boolean ("enable-calc");

                poisk_settings.changed["enable-apps"].connect (() => {
                    app_provider.is_enabled = poisk_settings.get_boolean ("enable-apps");
                });
                poisk_settings.changed["enable-windows"].connect (() => {
                    window_provider.is_enabled = poisk_settings.get_boolean ("enable-windows");
                });
                poisk_settings.changed["enable-calc"].connect (() => {
                    calc_provider.is_enabled = poisk_settings.get_boolean ("enable-calc");
                });
            }

            engine.register_provider (app_provider);
            engine.register_provider (window_provider);
            engine.register_provider (calc_provider);

            // Init centralized glance manager, providers and D-Bus interface
            glance_manager = GlanceManager.get_default ();
            updates_glance_provider = new UpdatesGlanceProvider ();
            calendar_glance_provider = new CalendarGlanceProvider ();
            glance_manager.register_provider (updates_glance_provider);
            glance_manager.register_provider (calendar_glance_provider);

            try {
                var connection = Bus.get_sync (BusType.SESSION);
                glance_dbus_service = new GlanceDBusService (glance_manager);
                connection.register_object ("/io/github/mrlogiousbanana/poisk/Glance", glance_dbus_service);
            } catch (Error e) {
                warning ("Failed to register Glance D-Bus service: %s", e.message);
            }

            this.hold (); // Keep application background daemon alive
        }

        protected override void activate () {
            if (window == null) {
                window = new LauncherWindow (engine);
            }
            window.present ();
        }

        public override int command_line (ApplicationCommandLine command_line) {
            string[] args = command_line.get_arguments ();

            for (int i = 1; i < args.length; i++) {
                string arg = args[i];
                if (arg == "--toggle" || arg == "-t") {
                    int64 now = GLib.get_monotonic_time ();
                    // 250ms debounce to prevent any accidental double-toggling
                    if (now - last_toggle_time < 250000) {
                        return 0;
                    }
                    last_toggle_time = now;

                    if (window != null && window.visible) {
                        window.set_visible (false);
                    } else {
                        activate ();
                    }
                    return 0;
                } else if (arg == "--preferences" || arg == "-p" || arg == "--settings") {
                    show_preferences ();
                    return 0;
                } else if (arg == "--manage-groups" || arg == "-g" || arg == "--groups") {
                    show_manage_groups ();
                    return 0;
                } else if (arg == "--quit" || arg == "-q") {
                    if (window != null) {
                        window.destroy ();
                    }
                    quit ();
                    return 0;
                } else if (arg == "--background" || arg == "-b" || arg == "--daemon") {
                    // Daemon mode: stay resident in background without opening window
                    return 0;
                } else if (arg == "--help" || arg == "-h") {
                    command_line.print ("Поиск (Poisk) — GTK-ориентированный лёгкий аналог Spotlight\n\nИспользование:\n  poisk [ОПЦИИ]\n\nОпции:\n  -t, --toggle        Показать / скрыть палитру поиска\n  -p, --preferences   Открыть параметры Поиска\n  -g, --manage-groups Настроить группы и скрытые приложения\n  -b, --background    Запустить в фоновом режиме (демон)\n  -q, --quit          Завершить фоновый процесс лаунчера\n  -v, --version       Показать версию\n  -h, --help          Показать эту справку\n");
                    return 0;
                } else if (arg == "--version" || arg == "-v") {
                    command_line.print ("Poisk 1.1.0\nhttps://github.com/Yatta-Project/poisk\nОсновано на концепциях Vicinae (https://github.com/vicinaehq/vicinae)\n");
                    return 0;
                } else if (arg == "glance" || arg == "--glance") {
                    return handle_glance_cli (args, i + 1, command_line);
                }
            }

            activate ();
            return 0;
        }

        private int handle_glance_cli (string[] args, int start_idx, ApplicationCommandLine cmd_line) {
            if (start_idx >= args.length) {
                cmd_line.print ("Использование:\n  poisk glance set [ОПЦИИ]\n  poisk glance clear [id]\n  poisk glance get\n\nОпции set:\n  --id <id>          Идентификатор виджета (по умолчанию: custom)\n  --priority <число> Приоритет (по умолчанию: 50)\n  --title <текст>    Текст виджета\n  --markup <разметка> Pango разметка (bold, цвета и т.д.)\n  --icon <иконка>    Имя системной иконки, эмодзи или путь к файлу\n  --dot <цвет>       Точка-индикатор (green, red, orange, hex)\n  --badge <бейдж>    Клавишный бейдж (↵, Tab, none)\n  --bg <css>         Фон (linear-gradient, hex, rgba)\n  --border <css>     Цвет рамки\n  --color <css>      Цвет текста\n  --action <cmd/url> Команда, URL или desktop-файл\n  --ttl <секунды>    Время жизни виджета\n  --json <json>      JSON-конфигурация целиком\n");
                return 0;
            }

            string subcmd = args[start_idx];
            if (subcmd == "clear") {
                string item_id = (start_idx + 1 < args.length) ? args[start_idx + 1] : "custom";
                glance_manager.clear_glance (item_id);
                cmd_line.print ("Виджет '%s' удалён\n".printf (item_id));
                return 0;
            } else if (subcmd == "activate") {
                string item_id = (start_idx + 1 < args.length) ? args[start_idx + 1] : "";
                var active = glance_manager.get_active_glance ();
                if (active != null && (item_id == "" || active.id == item_id)) {
                    cmd_line.print ("Активация виджета: %s\n".printf (active.id));
                    glance_manager.execute_item (active);
                } else {
                    cmd_line.printerr ("Нет подходящего виджета для активации\n");
                }
                return 0;
            } else if (subcmd == "dismiss") {
                string item_id = (start_idx + 1 < args.length) ? args[start_idx + 1] : "";
                if (item_id.length == 0) {
                    var active = glance_manager.get_active_glance ();
                    if (active != null) item_id = active.id;
                }
                if (item_id.length > 0) {
                    glance_manager.mark_connected (item_id);
                    cmd_line.print ("Виджет '%s' отклонён / отмечен подключенным\n".printf (item_id));
                }
                return 0;
            } else if (subcmd == "get") {
                var active = glance_manager.get_active_glance ();
                if (active != null) {
                    cmd_line.print ("Активный виджет: id=%s, priority=%d, title=%s\n".printf (active.id, active.priority, active.title ?? ""));
                } else {
                    cmd_line.print ("Нет активного виджета\n");
                }
                return 0;
            } else if (subcmd == "set") {
                string item_id = "custom";
                int priority = 50;
                string? title = null;
                string? markup = null;
                string? icon = null;
                string? dot = null;
                string? badge = "↵";
                string? bg = null;
                string? border = null;
                string? color = null;
                string? action = null;
                int ttl = 0;
                string? json_data = null;

                for (int j = start_idx + 1; j < args.length; j++) {
                    string a = args[j];
                    if (a == "--json" && j + 1 < args.length) {
                        json_data = args[++j];
                    } else if (a == "--id" && j + 1 < args.length) {
                        item_id = args[++j];
                    } else if (a == "--priority" && j + 1 < args.length) {
                        priority = int.parse (args[++j]);
                    } else if (a == "--title" && j + 1 < args.length) {
                        title = args[++j];
                    } else if (a == "--markup" && j + 1 < args.length) {
                        markup = args[++j];
                    } else if (a == "--icon" && j + 1 < args.length) {
                        icon = args[++j];
                    } else if (a == "--dot" && j + 1 < args.length) {
                        dot = args[++j];
                    } else if (a == "--badge" && j + 1 < args.length) {
                        badge = args[++j];
                        if (badge == "none" || badge == "null" || badge == "false") badge = null;
                    } else if (a == "--bg" && j + 1 < args.length) {
                        bg = args[++j];
                    } else if (a == "--border" && j + 1 < args.length) {
                        border = args[++j];
                    } else if (a == "--color" && j + 1 < args.length) {
                        color = args[++j];
                    } else if (a == "--action" && j + 1 < args.length) {
                        action = args[++j];
                    } else if (a == "--ttl" && j + 1 < args.length) {
                        ttl = int.parse (args[++j]);
                    }
                }

                if (json_data != null) {
                    try {
                        var item = GlanceItem.from_json (json_data);
                        glance_manager.set_glance (item);
                        cmd_line.print ("Виджет '%s' успешно установлен из JSON\n".printf (item.id));
                    } catch (Error e) {
                        cmd_line.printerr ("Ошибка разбора JSON: %s\n".printf (e.message));
                    }
                    return 0;
                }

                var item = new GlanceItem (item_id, priority);
                item.title = title;
                item.markup = markup;
                if (icon != null) {
                    if (icon.has_prefix ("/") || icon.has_prefix (".")) {
                        item.icon_path = icon;
                    } else if (icon.char_count () <= 2 && !icon.has_suffix ("-symbolic")) {
                        item.icon_emoji = icon;
                    } else {
                        item.icon_name = icon;
                    }
                }
                item.dot_color = dot;
                item.shortcut_badge = badge;
                item.background = bg;
                item.border_color = border;
                item.text_color = color;
                if (action != null) {
                    item.action_payload = action;
                    if (action.has_prefix ("http://") || action.has_prefix ("https://")) {
                        item.action_type = "url";
                    } else if (action.has_suffix (".desktop")) {
                        item.action_type = "app";
                    } else {
                        item.action_type = "command";
                    }
                }
                if (ttl > 0) {
                    item.expires_at = GLib.get_monotonic_time () + (int64) ttl * 1000000;
                }

                glance_manager.set_glance (item);
                cmd_line.print ("Виджет '%s' успешно установлен (приоритет %d)\n".printf (item.id, item.priority));
                return 0;
            }

            cmd_line.printerr ("Неизвестная команда glance: %s\n".printf (subcmd));
            return 1;
        }

        public static int main (string[] args) {
            // Ensure display environment variables are present even if started before session environment was imported
            if (GLib.Environment.get_variable ("WAYLAND_DISPLAY") == null) {
                string runtime_dir = GLib.Environment.get_user_runtime_dir ();
                if (GLib.FileUtils.test (GLib.Path.build_filename (runtime_dir, "wayland-0"), GLib.FileTest.EXISTS)) {
                    GLib.Environment.set_variable ("WAYLAND_DISPLAY", "wayland-0", false);
                }
            }
            if (GLib.Environment.get_variable ("DISPLAY") == null) {
                if (GLib.FileUtils.test ("/tmp/.X11-unix/X0", GLib.FileTest.EXISTS)) {
                    GLib.Environment.set_variable ("DISPLAY", ":0", false);
                }
            }
            // Prioritize Wayland on Wayland compositors (Pantheon, GNOME Wayland),
            // but seamlessly fallback to X11 on X11 environments (Cinnamon, GNOME on Xorg, etc.)
            if (GLib.Environment.get_variable ("GDK_BACKEND") == null) {
                GLib.Environment.set_variable ("GDK_BACKEND", "wayland,x11,*", false);
            }
            var app = new Application ();
            return app.run (args);
        }
    }
}
