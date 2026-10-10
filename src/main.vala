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

        public Application () {
            Object (
                application_id: "io.github.mrlogiousbanana.poisk",
                flags: ApplicationFlags.HANDLES_COMMAND_LINE
            );
        }

        protected override void startup () {
            base.startup ();
            Adw.init ();
            Granite.init ();

            // Detect desktop bridge (Pantheon is primary)
            var de = DesktopBridge.get_current_desktop ();
            if (de == DesktopEnvironment.GNOME) {
                desktop_bridge = new GnomeBridge ();
            } else {
                desktop_bridge = new PantheonBridge ();
            }

            // Init core search engine and register only core providers
            engine = new SearchEngine ();
            engine.register_provider (new AppProvider ());
            engine.register_provider (new WindowProvider (desktop_bridge));
            engine.register_provider (new CalcProvider ());

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
                    if (window != null && window.visible) {
                        window.set_visible (false);
                    } else {
                        activate ();
                    }
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
                    command_line.print ("Поиск (Poisk) — быстрый лаунчер для Pantheon и Linux\n\nИспользование:\n  poisk [ОПЦИИ]\n\nОпции:\n  -t, --toggle        Показать / скрыть палитру поиска\n  -b, --background    Запустить в фоновом режиме (демон)\n  -q, --quit          Завершить фоновый процесс лаунчера\n  -v, --version       Показать версию\n  -h, --help          Показать эту справку\n");
                    if (window == null) {
                        this.quit ();
                    }
                    return 0;
                } else if (arg == "--version" || arg == "-v") {
                    command_line.print ("Poisk 1.0.0\nhttps://github.com/mrlogiousbanana/poisk\nОсновано на концепциях Vicinae (https://github.com/vicinaehq/vicinae)\n");
                    if (window == null) {
                        this.quit ();
                    }
                    return 0;
                }
            }

            activate ();
            return 0;
        }

        public static int main (string[] args) {
            GLib.Environment.set_variable ("GDK_BACKEND", "wayland", true);
            var app = new Application ();
            return app.run (args);
        }
    }
}
