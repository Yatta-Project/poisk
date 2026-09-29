namespace Vicinae.Bridges {

    public enum DesktopEnvironment {
        GNOME,
        PANTHEON,
        OTHER
    }

    public abstract class DesktopBridge : Object {
        public abstract string name { get; }
        public abstract bool is_available { get; }

        public signal void clipboard_changed (string text, string source);

        public abstract async List<Vicinae.Core.SearchItem> get_open_windows ();
        public abstract async void activate_window (string window_id);
        public abstract async void close_window (string window_id);

        public static DesktopEnvironment get_current_desktop () {
            string? de = Environment.get_variable ("XDG_CURRENT_DESKTOP");
            if (de != null) {
                string de_lower = de.down ();
                if ("gnome" in de_lower) return DesktopEnvironment.GNOME;
                if ("pantheon" in de_lower) return DesktopEnvironment.PANTHEON;
            }
            return DesktopEnvironment.OTHER;
        }
    }
}
