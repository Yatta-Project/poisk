using Gtk;
using Adw;
using Vicinae.Core;
using Vicinae.Bridges;
using Vicinae.Providers;
using Vicinae.UI;

namespace Vicinae {

    public class Application : Adw.Application {
        private SearchEngine engine;
        private DesktopBridge desktop_bridge;
        private LauncherWindow? window = null;

        public static bool dmenu_mode = false;
        private static GLib.List<string> dmenu_lines;

        public Application (bool is_dmenu = false) {
            Object (
                application_id: is_dmenu ? null : "org.vicinae.launcher",
                flags: is_dmenu ? ApplicationFlags.FLAGS_NONE : ApplicationFlags.HANDLES_COMMAND_LINE
            );
            dmenu_mode = is_dmenu;
        }

        protected override void startup () {
            base.startup ();
            Adw.init ();
            Granite.init ();

            if (dmenu_mode) {
                engine = new SearchEngine ();
                engine.register_provider (new DmenuProvider ((owned) dmenu_lines, (selected) => {
                    stdout.printf ("%s\n", selected);
                    stdout.flush ();
                    this.quit ();
                }));
                return;
            }

            // Detect desktop bridge
            var de = DesktopBridge.get_current_desktop ();
            if (de == DesktopEnvironment.PANTHEON) {
                desktop_bridge = new PantheonBridge ();
            } else {
                desktop_bridge = new GnomeBridge ();
            }

            // Init core engine and register providers
            engine = new SearchEngine ();
            engine.register_provider (new AppProvider ());
            engine.register_provider (new WindowProvider (desktop_bridge));
            engine.register_provider (new ClipboardProvider ());
            engine.register_provider (new CalcProvider ());
            engine.register_provider (new ScriptProvider ());
        }

        protected override void activate () {
            if (window == null) {
                window = new LauncherWindow (this, engine);
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
                } else if (arg == "--help" || arg == "-h") {
                    command_line.print ("Usage:\n  vicinae [OPTIONS]\n\nOptions:\n  -t, --toggle    Toggle launcher palette\n  -q, --quit      Quit launcher daemon\n  -d, --dmenu     Run in dmenu stdin/stdout pipe mode\n  -v, --version   Show version information\n  -h, --help      Show this help message\n");
                    return 0;
                } else if (arg == "--version" || arg == "-v") {
                    command_line.print ("Vicinae (Vala Native Edition) 0.1.0\n");
                    return 0;
                }
            }

            activate ();
            return 0;
        }

        public static int main (string[] args) {
            bool dmenu = false;
            foreach (string arg in args) {
                if (arg == "--dmenu" || arg == "-d") {
                    dmenu = true;
                    break;
                }
            }

            if (dmenu) {
                dmenu_lines = new GLib.List<string> ();
                string? line;
                while ((line = stdin.read_line ()) != null) {
                    string trimmed = line.strip ();
                    if (trimmed.length > 0) {
                        dmenu_lines.append (trimmed);
                    }
                }
                var app = new Application (true);
                return app.run ({ args[0] });
            }

            var app = new Application (false);
            return app.run (args);
        }
    }
}
