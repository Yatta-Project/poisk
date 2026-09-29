using Vicinae.Core;

namespace Vicinae.Bridges {

    [DBus (name = "org.pantheon.gala")]
    public interface GalaProxy : Object {
        public abstract async void perform_action (int action_id) throws Error;
    }

    public class PantheonBridge : DesktopBridge {
        public override string name { get { return "Pantheon (Gala)"; } }
        private bool _is_available = false;
        public override bool is_available { get { return _is_available; } }

        public PantheonBridge () {
            init_gala.begin ();
        }

        private async void init_gala () {
            if (DesktopBridge.get_current_desktop () == DesktopEnvironment.PANTHEON) {
                _is_available = true;
            }
        }

        public override async List<SearchItem> get_open_windows () {
            var items = new List<SearchItem> ();
            // In Pantheon, windows can be queried through Gala DBus or fallback
            return items;
        }

        public override async void activate_window (string window_id) {
            debug ("PantheonBridge: Activate window %s", window_id);
        }

        public override async void close_window (string window_id) {
            debug ("PantheonBridge: Close window %s", window_id);
        }
    }
}
