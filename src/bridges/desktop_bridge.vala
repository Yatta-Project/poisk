using Poisk.Core;

namespace Poisk.Bridges {

    public enum DesktopEnvironment {
        PANTHEON,
        GNOME,
        CINNAMON,
        OTHER
    }

    public abstract class DesktopBridge : Object {
        public abstract string name { get; }
        public abstract bool is_available { get; }

        public abstract async List<SearchItem> get_open_windows ();
        public abstract async void activate_window (string window_id);
        public abstract async void close_window (string window_id);

        public static DesktopEnvironment get_current_desktop () {
            string? de = Environment.get_variable ("XDG_CURRENT_DESKTOP");
            if (de != null) {
                string de_lower = de.down ();
                if ("pantheon" in de_lower) return DesktopEnvironment.PANTHEON;
                if ("cinnamon" in de_lower) return DesktopEnvironment.CINNAMON;
                if ("gnome" in de_lower) return DesktopEnvironment.GNOME;
            }
            return DesktopEnvironment.OTHER;
        }
    }
}
