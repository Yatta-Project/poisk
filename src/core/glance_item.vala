using Gtk;
using Json;

namespace Poisk.Core {

    public class GlanceItem : GLib.Object {
        public string id { get; set; default = ""; }
        public int priority { get; set; default = 0; }

        // Content
        public string? title { get; set; default = null; }
        public string? markup { get; set; default = null; }
        public string? icon_name { get; set; default = null; }
        public string? icon_emoji { get; set; default = null; }
        public string? icon_path { get; set; default = null; }
        public string? dot_color { get; set; default = null; } // e.g. "green", "red", "orange", "#38bdf8"
        public string? shortcut_badge { get; set; default = "↵"; } // null or empty to hide
        public double progress { get; set; default = -1.0; } // -1.0 for none, 0.0 .. 1.0
        public string? tooltip { get; set; default = null; }

        // Styling / Background
        public string? background { get; set; default = null; } // linear-gradient(...), hex, rgba
        public string? border_color { get; set; default = null; }
        public string? text_color { get; set; default = null; }
        public string? custom_css { get; set; default = null; }

        // Actions
        public string? action_type { get; set; default = null; } // "url", "app", "command", "dbus-callback"
        public string? action_payload { get; set; default = null; }
        public bool auto_dismiss_on_activate { get; set; default = true; }

        // Lifecycle & State
        public int64 expires_at { get; set; default = 0; } // monotonic microsec (0 = no expiry)
        public bool was_activated { get; set; default = false; }

        // In-process native hooks (for internal providers)
        public delegate void NativeActionCallback ();
        private NativeActionCallback? _native_action = null;

        public void set_native_action (owned NativeActionCallback? cb) {
            _native_action = (owned) cb;
        }

        public void invoke_native_action () {
            if (_native_action != null) {
                _native_action ();
            }
        }

        public bool has_native_action () {
            return _native_action != null;
        }

        public Gtk.Widget? custom_widget { get; set; default = null; }

        public GlanceItem (string id, int priority = 0) {
            GLib.Object (id: id, priority: priority);
        }

        public bool is_expired (int64 now) {
            return expires_at > 0 && now >= expires_at;
        }

        public static GlanceItem from_json (string json_str) throws GLib.Error {
            var parser = new Json.Parser ();
            parser.load_from_data (json_str, -1);
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                throw new GLib.IOError.INVALID_DATA ("Root must be a JSON object");
            }

            var obj = root.get_object ();
            string item_id = obj.has_member ("id") ? obj.get_string_member ("id") : "custom";
            int prio = obj.has_member ("priority") ? (int) obj.get_int_member ("priority") : 0;

            var item = new GlanceItem (item_id, prio);

            if (obj.has_member ("title")) item.title = obj.get_string_member ("title");
            if (obj.has_member ("markup")) item.markup = obj.get_string_member ("markup");

            if (obj.has_member ("icon_name")) item.icon_name = obj.get_string_member ("icon_name");
            else if (obj.has_member ("icon")) item.icon_name = obj.get_string_member ("icon");

            if (obj.has_member ("icon_emoji")) item.icon_emoji = obj.get_string_member ("icon_emoji");
            else if (obj.has_member ("emoji")) item.icon_emoji = obj.get_string_member ("emoji");

            if (obj.has_member ("icon_path")) item.icon_path = obj.get_string_member ("icon_path");

            if (obj.has_member ("dot_color")) item.dot_color = obj.get_string_member ("dot_color");
            else if (obj.has_member ("dot")) item.dot_color = obj.get_string_member ("dot");

            if (obj.has_member ("shortcut_badge")) item.shortcut_badge = obj.get_string_member ("shortcut_badge");
            else if (obj.has_member ("badge")) item.shortcut_badge = obj.get_string_member ("badge");

            if (obj.has_member ("progress")) item.progress = obj.get_double_member ("progress");
            if (obj.has_member ("tooltip")) item.tooltip = obj.get_string_member ("tooltip");

            if (obj.has_member ("background")) item.background = obj.get_string_member ("background");
            else if (obj.has_member ("bg")) item.background = obj.get_string_member ("bg");

            if (obj.has_member ("border_color")) item.border_color = obj.get_string_member ("border_color");
            else if (obj.has_member ("border")) item.border_color = obj.get_string_member ("border");

            if (obj.has_member ("text_color")) item.text_color = obj.get_string_member ("text_color");
            else if (obj.has_member ("color")) item.text_color = obj.get_string_member ("color");

            if (obj.has_member ("custom_css")) item.custom_css = obj.get_string_member ("custom_css");
            else if (obj.has_member ("css")) item.custom_css = obj.get_string_member ("css");

            if (obj.has_member ("action_type")) item.action_type = obj.get_string_member ("action_type");
            if (obj.has_member ("action_payload")) item.action_payload = obj.get_string_member ("action_payload");
            else if (obj.has_member ("action")) item.action_payload = obj.get_string_member ("action");

            if (item.action_type == null && item.action_payload != null) {
                // Auto-detect action type
                string p = item.action_payload;
                if (p.has_prefix ("http://") || p.has_prefix ("https://")) {
                    item.action_type = "url";
                } else if (p.has_suffix (".desktop")) {
                    item.action_type = "app";
                } else {
                    item.action_type = "command";
                }
            }

            if (obj.has_member ("auto_dismiss")) item.auto_dismiss_on_activate = obj.get_boolean_member ("auto_dismiss");

            if (obj.has_member ("ttl")) {
                int64 ttl = obj.get_int_member ("ttl");
                if (ttl > 0) {
                    item.expires_at = GLib.get_monotonic_time () + ttl * 1000000;
                }
            }

            return item;
        }
    }
}
