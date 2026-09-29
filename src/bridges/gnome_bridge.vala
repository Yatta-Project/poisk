using Vicinae.Core;

namespace Vicinae.Bridges {

    [DBus (name = "org.gnome.Shell.Extensions.Windows")]
    public interface GnomeWindowsProxy : GLib.Object {
        public abstract async string list () throws Error;
        public abstract async void activate (uint32 winid) throws Error;
        public abstract async void close (uint32 winid) throws Error;
        public abstract async void minimize (uint32 winid) throws Error;
        public abstract async void maximize (uint32 winid) throws Error;
    }

    [DBus (name = "org.gnome.Shell.Extensions.Clipboard")]
    public interface GnomeClipboardProxy : GLib.Object {
        public abstract async string get_current_content () throws Error;
        public abstract async void set_content (string content) throws Error;
        public signal void clipboard_changed (uint8[] content, string mime_type, string source_app);
    }

    public class GnomeBridge : DesktopBridge {
        public override string name { get { return "GNOME Shell (Mutter)"; } }
        private bool _is_available = false;
        public override bool is_available { get { return _is_available; } }

        private GnomeWindowsProxy? windows_proxy = null;
        private GnomeClipboardProxy? clipboard_proxy = null;

        public GnomeBridge () {
            init_dbus.begin ();
        }

        private async void init_dbus () {
            try {
                windows_proxy = yield Bus.get_proxy<GnomeWindowsProxy> (
                    BusType.SESSION,
                    "org.gnome.Shell",
                    "/org/gnome/Shell/Extensions/Windows"
                );

                clipboard_proxy = yield Bus.get_proxy<GnomeClipboardProxy> (
                    BusType.SESSION,
                    "org.gnome.Shell",
                    "/org/gnome/Shell/Extensions/Clipboard"
                );

                if (clipboard_proxy != null) {
                    clipboard_proxy.clipboard_changed.connect ((content, mime_type, source_app) => {
                        string text = (string) content;
                        Database.get_default ().add_clipboard_entry (text, mime_type, source_app);
                        this.clipboard_changed (text, source_app);
                    });
                }

                _is_available = true;
            } catch (Error e) {
                _is_available = false;
                debug ("GnomeBridge: Extensions D-Bus not active yet: %s", e.message);
            }
        }

        public override async List<SearchItem> get_open_windows () {
            var items = new List<SearchItem> ();
            if (windows_proxy == null) return items;

            try {
                string json_data = yield windows_proxy.list ();
                var parser = new Json.Parser ();
                parser.load_from_data (json_data);
                var root = parser.get_root ();
                if (root == null || !root.is_null () == false || root.get_node_type () != Json.NodeType.ARRAY) {
                    var array = root.get_array ();
                    foreach (unowned Json.Node element in array.get_elements ()) {
                        if (element.get_node_type () != Json.NodeType.OBJECT) continue;
                        var obj = element.get_object ();

                        int64 win_id = obj.has_member ("id") ? obj.get_int_member ("id") : 0;
                        string title = obj.has_member ("title") ? obj.get_string_member ("title") : "Untitled";
                        string wm_class = obj.has_member ("wm_class") ? obj.get_string_member ("wm_class") : "";
                        int64 ws = obj.has_member ("workspace") ? obj.get_int_member ("workspace") : 0;

                        if (title.length == 0 && wm_class.length == 0) continue;

                        string display_title = title.length > 0 ? title : wm_class;
                        string subtitle = "Workspace %lld • %s".printf (ws + 1, wm_class);

                        string icon_name = wm_class.down ();
                        if (icon_name.length == 0) icon_name = "preferences-system-windows";

                        var item = new SearchItem (
                            "win:%lld".printf (win_id),
                            display_title,
                            subtitle,
                            icon_name,
                            "Open Windows"
                        );
                        item.action_label = "Switch to Window";
                        item.extra_info = "%lld".printf (win_id);
                        item.preview_text = "Window: %s\nClass: %s\nID: %lld\nWorkspace: %lld".printf (
                            display_title, wm_class, win_id, ws + 1
                        );

                        items.append (item);
                    }
                }
            } catch (Error e) {
                warning ("GnomeBridge: Failed to list windows: %s", e.message);
            }

            return items;
        }

        public override async void activate_window (string window_id) {
            if (windows_proxy == null) return;
            try {
                uint32 id = (uint32) int.parse (window_id);
                yield windows_proxy.activate (id);
            } catch (Error e) {
                warning ("GnomeBridge: Failed to activate window %s: %s", window_id, e.message);
            }
        }

        public override async void close_window (string window_id) {
            if (windows_proxy == null) return;
            try {
                uint32 id = (uint32) int.parse (window_id);
                yield windows_proxy.close (id);
            } catch (Error e) {
                warning ("GnomeBridge: Failed to close window %s: %s", window_id, e.message);
            }
        }
    }
}
