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
                    command_line.print ("Поиск (Poisk) — быстрый лаунчер для Pantheon и Linux\n\nИспользование:\n  poisk [ОПЦИИ]\n\nОпции:\n  -t, --toggle        Показать / скрыть палитру поиска\n  -p, --preferences   Открыть параметры Поиска\n  -g, --manage-groups Настроить группы и скрытые приложения\n  -b, --background    Запустить в фоновом режиме (демон)\n  -q, --quit          Завершить фоновый процесс лаунчера\n  -v, --version       Показать версию\n  -h, --help          Показать эту справку\n");
                    return 0;
                } else if (arg == "--version" || arg == "-v") {
                    command_line.print ("Poisk 1.0.0\nhttps://github.com/mrlogiousbanana/poisk\nОсновано на концепциях Vicinae (https://github.com/vicinaehq/vicinae)\n");
                    return 0;
                }
            }

            activate ();
            return 0;
        }

        public static int main (string[] args) {
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
