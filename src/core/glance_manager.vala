using Gee;

namespace Poisk.Core {

    public class GlanceManager : GLib.Object {
        private static GlanceManager? _instance = null;
        public static GlanceManager get_default () {
            if (_instance == null) {
                _instance = new GlanceManager ();
            }
            return _instance;
        }

        private Gee.HashMap<string, GlanceItem> items;
        private Gee.HashSet<string> connected_meeting_ids;
        private Gee.ArrayList<GlanceProvider> providers;
        private uint expiry_timer_id = 0;
        private GlanceItem? last_emitted = null;
        private string dismissed_path;

        public signal void glance_changed (GlanceItem? active_item);
        public signal void glance_activated (string id);
        public signal void glance_dismissed (string id);

        public GlanceManager () {
            items = new Gee.HashMap<string, GlanceItem> ();
            connected_meeting_ids = new Gee.HashSet<string> ();
            providers = new Gee.ArrayList<GlanceProvider> ();

            init_storage ();

            // Check expirations every second
            expiry_timer_id = GLib.Timeout.add_seconds (1, () => {
                check_expirations ();
                return GLib.Source.CONTINUE;
            });
        }

        private void init_storage () {
            string config_dir = GLib.Path.build_filename (GLib.Environment.get_user_config_dir (), "poisk");
            GLib.DirUtils.create_with_parents (config_dir, 0755);
            dismissed_path = GLib.Path.build_filename (config_dir, "dismissed_glances.json");
            load_dismissed ();
        }

        private void load_dismissed () {
            if (!GLib.FileUtils.test (dismissed_path, GLib.FileTest.EXISTS)) return;
            try {
                var parser = new Json.Parser ();
                parser.load_from_file (dismissed_path);
                var root = parser.get_root ();
                if (root != null && root.get_node_type () == Json.NodeType.ARRAY) {
                    var arr = root.get_array ();
                    for (uint i = 0; i < arr.get_length (); i++) {
                        string val = arr.get_string_element (i);
                        if (val.length > 0) connected_meeting_ids.add (val);
                    }
                }
            } catch (Error e) {
                warning ("Failed to load dismissed glances: %s", e.message);
            }
        }

        private void save_dismissed () {
            try {
                var builder = new Json.Builder ();
                builder.begin_array ();
                foreach (var id in connected_meeting_ids) {
                    builder.add_string_value (id);
                }
                builder.end_array ();
                var generator = new Json.Generator ();
                generator.set_root (builder.get_root ());
                generator.to_file (dismissed_path);
            } catch (Error e) {
                warning ("Failed to save dismissed glances: %s", e.message);
            }
        }

        ~GlanceManager () {
            if (expiry_timer_id > 0) {
                GLib.Source.remove (expiry_timer_id);
                expiry_timer_id = 0;
            }
        }

        public void register_provider (GlanceProvider provider) {
            providers.add (provider);
            provider.glance_updated.connect ((item) => {
                if (item != null) {
                    set_glance (item);
                } else {
                    clear_glance (provider.id);
                }
            });
            var initial = provider.get_current_glance ();
            if (initial != null) {
                set_glance (initial);
            }
        }

        public void set_glance (GlanceItem item) {
            // If this meeting was already connected to or dismissed, don't show it again
            if (connected_meeting_ids.contains (item.id)) {
                return;
            }

            items.set (item.id, item);
            recalculate_active ();
        }

        public void clear_glance (string id) {
            bool modified = false;
            if (items.has_key (id)) {
                items.unset (id);
                modified = true;
            }

            var to_remove = new Gee.ArrayList<string> ();
            foreach (var k in items.keys) {
                if (k.has_prefix (id + ":")) {
                    to_remove.add (k);
                }
            }
            foreach (var k in to_remove) {
                items.unset (k);
                modified = true;
            }

            if (modified) {
                recalculate_active ();
            }
        }

        public void dismiss_glance (string id) {
            connected_meeting_ids.add (id);
            save_dismissed ();
            clear_glance (id);
            glance_dismissed (id);
        }

        public void mark_connected (string meeting_id) {
            dismiss_glance (meeting_id);
        }

        public bool is_connected (string meeting_id) {
            return connected_meeting_ids.contains (meeting_id);
        }

        public GlanceItem? get_active_glance () {
            int64 now = GLib.get_monotonic_time ();
            GlanceItem? best = null;

            foreach (var entry in items.entries) {
                var item = entry.value;
                if (item.is_expired (now)) {
                    continue;
                }
                if (item.was_activated && item.auto_dismiss_on_activate) {
                    continue;
                }
                if (connected_meeting_ids.contains (item.id)) {
                    continue;
                }
                if (best == null || item.priority > best.priority) {
                    best = item;
                }
            }
            return best;
        }

        public void execute_item (GlanceItem item) {
            item.was_activated = true;

            // Remember connected meetings (e.g. "calendar:123" or "calendar")
            if (item.id.has_prefix ("calendar") || item.id.has_prefix ("meet")) {
                connected_meeting_ids.add (item.id);
                save_dismissed ();
            }

            // Execute native callback or command / url / app
            if (item.has_native_action ()) {
                item.invoke_native_action ();
            } else if (item.action_type != null) {
                dispatch_action (item.action_type, item.action_payload);
            }

            glance_activated (item.id);

            if (item.auto_dismiss_on_activate) {
                clear_glance (item.id);
            } else {
                recalculate_active ();
            }
        }

        private void dispatch_action (string action_type, string? payload) {
            if (payload == null || payload.length == 0) return;
            try {
                if (action_type == "meeting" || action_type == "url") {
                    MeetingLauncher.launch_meeting (payload);
                } else if (action_type == "app") {
                    string clean_app = payload.has_suffix (".desktop") ? payload : payload + ".desktop";
                    string[] argv = { "gtk-launch", clean_app };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                } else if (action_type == "command") {
                    string[] argv = { "sh", "-c", payload };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                }
            } catch (Error e) {
                warning ("GlanceManager failed to dispatch action %s: %s", action_type, e.message);
            }
        }

        private void check_expirations () {
            int64 now = GLib.get_monotonic_time ();
            var to_remove = new Gee.ArrayList<string> ();
            foreach (var entry in items.entries) {
                if (entry.value.is_expired (now)) {
                    to_remove.add (entry.key);
                }
            }
            if (to_remove.size > 0) {
                foreach (var k in to_remove) {
                    items.unset (k);
                }
                recalculate_active ();
            }
        }

        private void recalculate_active () {
            var active = get_active_glance ();
            if (active != last_emitted) {
                last_emitted = active;
                glance_changed (active);
            }
        }
    }
}
