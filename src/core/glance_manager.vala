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

        public signal void glance_changed (GlanceItem? active_item);
        public signal void glance_activated (string id);

        public GlanceManager () {
            items = new Gee.HashMap<string, GlanceItem> ();
            connected_meeting_ids = new Gee.HashSet<string> ();
            providers = new Gee.ArrayList<GlanceProvider> ();

            // Check expirations every second
            expiry_timer_id = GLib.Timeout.add_seconds (1, () => {
                check_expirations ();
                return GLib.Source.CONTINUE;
            });
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
            // If this meeting was already connected to via the pill, don't show it again
            if (connected_meeting_ids.contains (item.id)) {
                return;
            }

            items.set (item.id, item);
            recalculate_active ();
        }

        public void clear_glance (string id) {
            if (items.has_key (id)) {
                items.unset (id);
                recalculate_active ();
            }
        }

        public void mark_connected (string meeting_id) {
            connected_meeting_ids.add (meeting_id);
            clear_glance (meeting_id);
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
