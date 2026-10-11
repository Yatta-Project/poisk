using Poisk.Core;

namespace Poisk.Bridges {

    [DBus (name = "org.Cinnamon")]
    public interface CinnamonProxy : GLib.Object {
        public abstract async void eval (string script, out bool success, out string result) throws Error;
    }

    public class CinnamonBridge : DesktopBridge {
        public override string name { get { return "Cinnamon (Muffin)"; } }
        private bool _is_available = false;
        public override bool is_available { get { return _is_available; } }

        private CinnamonProxy? cinnamon_proxy = null;

        public CinnamonBridge () {
            init_dbus.begin ();
        }

        private async void init_dbus () {
            try {
                cinnamon_proxy = yield Bus.get_proxy<CinnamonProxy> (
                    BusType.SESSION,
                    "org.Cinnamon",
                    "/org/Cinnamon"
                );
                _is_available = (cinnamon_proxy != null);
            } catch (Error e) {
                _is_available = false;
                debug ("CinnamonBridge: org.Cinnamon D-Bus not active: %s", e.message);
            }
        }

        public override async List<SearchItem> get_open_windows () {
            var items = new List<SearchItem> ();
            if (cinnamon_proxy == null) return items;

            try {
                bool success = false;
                string result = "";
                string script = """
                    JSON.stringify(
                        global.get_window_actors()
                            .map(function(a) { return a.meta_window; })
                            .filter(function(w) { return w && !w.is_skip_taskbar(); })
                            .map(function(w) {
                                return {
                                    id: w.get_xwindow ? w.get_xwindow() : (w.get_id ? w.get_id() : 0),
                                    title: w.get_title() || "",
                                    wm_class: w.get_wm_class() || ""
                                };
                            })
                    );
                """;

                yield cinnamon_proxy.eval (script, out success, out result);
                if (!success || result.length == 0) return items;

                var parser = new Json.Parser ();
                parser.load_from_data (result);
                var root = parser.get_root ();
                if (root != null && root.get_node_type () == Json.NodeType.ARRAY) {
                    var array = root.get_array ();
                    foreach (unowned Json.Node element in array.get_elements ()) {
                        if (element.get_node_type () != Json.NodeType.OBJECT) continue;
                        var obj = element.get_object ();

                        int64 win_id = obj.has_member ("id") ? obj.get_int_member ("id") : 0;
                        string title = obj.has_member ("title") ? obj.get_string_member ("title") : "Untitled";
                        string wm_class = obj.has_member ("wm_class") ? obj.get_string_member ("wm_class") : "";

                        if (title.length == 0 && wm_class.length == 0) continue;

                        string display_title = (title.length > 0) ? title : wm_class;
                        string subtitle = (wm_class.length > 0) ? wm_class : "Окно Cinnamon";
                        string icon_name = (wm_class.length > 0) ? wm_class.down () : "preferences-system-windows";

                        var item = new SearchItem (
                            "cinnamon-win-%lld".printf (win_id),
                            display_title,
                            subtitle,
                            icon_name,
                            "Windows"
                        );
                        item.action_label = "Switch to Window";
                        item.extra_info = "%lld".printf (win_id);

                        items.append (item);
                    }
                }
            } catch (Error e) {
                debug ("CinnamonBridge: error listing windows: %s", e.message);
            }

            return items;
        }

        public override async void activate_window (string window_id) {
            if (cinnamon_proxy == null) return;
            try {
                bool success = false;
                string result = "";
                string script = """
                    (function() {
                        var target_id = %s;
                        var actor = global.get_window_actors().find(function(a) {
                            var w = a.meta_window;
                            if (!w) return false;
                            var id = w.get_xwindow ? w.get_xwindow() : (w.get_id ? w.get_id() : 0);
                            return id === target_id;
                        });
                        if (actor && actor.meta_window) {
                            actor.meta_window.activate(global.get_current_time());
                        }
                    })();
                """.printf (window_id);

                yield cinnamon_proxy.eval (script, out success, out result);
            } catch (Error e) {
                debug ("CinnamonBridge: error activating window: %s", e.message);
            }
        }

        public override async void close_window (string window_id) {
            if (cinnamon_proxy == null) return;
            try {
                bool success = false;
                string result = "";
                string script = """
                    (function() {
                        var target_id = %s;
                        var actor = global.get_window_actors().find(function(a) {
                            var w = a.meta_window;
                            if (!w) return false;
                            var id = w.get_xwindow ? w.get_xwindow() : (w.get_id ? w.get_id() : 0);
                            return id === target_id;
                        });
                        if (actor && actor.meta_window) {
                            actor.meta_window.delete(global.get_current_time());
                        }
                    })();
                """.printf (window_id);

                yield cinnamon_proxy.eval (script, out success, out result);
            } catch (Error e) {
                debug ("CinnamonBridge: error closing window: %s", e.message);
            }
        }
    }
}
