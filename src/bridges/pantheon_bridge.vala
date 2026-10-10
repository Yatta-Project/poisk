using Poisk.Core;

namespace Poisk.Bridges {

    [DBus (name = "org.pantheon.gala.DesktopIntegration")]
    public interface GalaDesktopIntegrationProxy : GLib.Object {
        public struct WindowInfo {
            uint64 uid;
            GLib.HashTable<string, Variant> properties;
        }

        public abstract async WindowInfo[] get_windows () throws Error;
        public abstract async void focus_window (uint64 uid) throws Error;
        public signal void windows_changed ();
    }

    public class PantheonBridge : DesktopBridge {
        public override string name { get { return "Pantheon (Gala)"; } }
        private bool _is_available = false;
        public override bool is_available { get { return _is_available; } }

        private GalaDesktopIntegrationProxy? gala_proxy = null;

        public PantheonBridge () {
            init_gala.begin ();
        }

        private async void init_gala () {
            try {
                gala_proxy = yield Bus.get_proxy<GalaDesktopIntegrationProxy> (
                    BusType.SESSION,
                    "org.pantheon.gala",
                    "/org/pantheon/gala/DesktopInterface"
                );
                if (gala_proxy != null) {
                    _is_available = true;
                }
            } catch (Error e) {
                warning ("PantheonBridge: Failed to connect to Gala DesktopIntegration: %s", e.message);
                _is_available = false;
            }
        }

        public override async List<SearchItem> get_open_windows () {
            var items = new List<SearchItem> ();
            if (gala_proxy == null) {
                yield init_gala ();
                if (gala_proxy == null) return items;
            }

            try {
                var windows = yield gala_proxy.get_windows ();
                foreach (var win in windows) {
                    var props = win.properties;
                    if (props == null) continue;

                    string title = "";
                    string app_id = "";
                    string wm_class = "";

                    var title_v = props.lookup ("title");
                    if (title_v != null && title_v.is_of_type (VariantType.STRING)) {
                        title = title_v.get_string ();
                    }

                    var app_id_v = props.lookup ("app-id");
                    if (app_id_v != null && app_id_v.is_of_type (VariantType.STRING)) {
                        app_id = app_id_v.get_string ();
                    }

                    var wm_class_v = props.lookup ("wm-class");
                    if (wm_class_v != null && wm_class_v.is_of_type (VariantType.STRING)) {
                        wm_class = wm_class_v.get_string ();
                    }

                    // Skip Poisk launcher itself and dock/panels
                    string wm_lower = wm_class.down ();
                    if (wm_lower == "poisk" || wm_lower == "vicinae" || app_id.contains ("poisk") ||
                        wm_class == "io.elementary.dock" || wm_class == "io.elementary.wingpanel") {
                        continue;
                    }

                    if (title.length == 0 && wm_class.length == 0 && app_id.length == 0) {
                        continue;
                    }

                    string display_title = (title.length > 0) ? title : (wm_class.length > 0 ? wm_class : app_id);
                    string subtitle = (wm_class.length > 0) ? wm_class : app_id;

                    // Resolve icon
                    string icon_name = "application-x-executable";
                    if (app_id.length > 0) {
                        try {
                            var app_info = new DesktopAppInfo (app_id);
                            if (app_info != null && app_info.get_icon () != null) {
                                icon_name = app_info.get_icon ().to_string ();
                            }
                        } catch (Error e) {
                        }
                    }
                    if (icon_name == "application-x-executable" && wm_class.length > 0) {
                        icon_name = wm_class;
                    }

                    string uid_str = win.uid.to_string ();
                    var item = new SearchItem (
                        "win:" + uid_str,
                        display_title,
                        subtitle,
                        icon_name,
                        "Open Windows"
                    );
                    item.action_label = "Switch to Window";
                    item.extra_info = uid_str;
                    item.preview_text = "<b>%s</b>\n\nClass: <tt>%s</tt>\nApp ID: <tt>%s</tt>\nWindow ID: <tt>%s</tt>".printf (
                        Markup.escape_text (display_title),
                        Markup.escape_text (wm_class),
                        Markup.escape_text (app_id),
                        Markup.escape_text (uid_str)
                    );
                    items.append (item);
                }
            } catch (Error e) {
                warning ("PantheonBridge: get_windows failed: %s", e.message);
            }

            return items;
        }

        public override async void activate_window (string window_id) {
            if (gala_proxy == null) return;
            try {
                uint64 uid = uint64.parse (window_id);
                yield gala_proxy.focus_window (uid);
            } catch (Error e) {
                warning ("PantheonBridge: focus_window %s failed: %s", window_id, e.message);
            }
        }

        public override async void close_window (string window_id) {
        }
    }
}
