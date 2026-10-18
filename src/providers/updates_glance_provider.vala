using Poisk.Core;

namespace Poisk.Providers {

    public class UpdatesGlanceProvider : GLib.Object, GlanceProvider {
        public string id { get { return "system-updates"; } }

        private GlanceItem? current_item = null;
        private uint check_timer_id = 0;
        private bool is_checking = false;

        public UpdatesGlanceProvider () {
            // Initial check in background after 2 seconds
            GLib.Timeout.add_seconds (2, () => {
                check_updates_async.begin ();
                return GLib.Source.REMOVE;
            });

            // Re-check every 30 minutes
            check_timer_id = GLib.Timeout.add_seconds (1800, () => {
                check_updates_async.begin ();
                return GLib.Source.CONTINUE;
            });
        }

        ~UpdatesGlanceProvider () {
            if (check_timer_id > 0) {
                GLib.Source.remove (check_timer_id);
                check_timer_id = 0;
            }
        }

        public GlanceItem? get_current_glance () {
            return current_item;
        }

        public async void check_updates_async () {
            if (is_checking) return;
            is_checking = true;

            new Thread<void*> ("poisk-updates-check", () => {
                int count = query_flatpak_updates ();
                Idle.add (() => {
                    this.on_check_completed (count);
                    this.is_checking = false;
                    return GLib.Source.REMOVE;
                });
                return null;
            });
        }

        private int query_flatpak_updates () {
            try {
                string[] argv = { "flatpak", "remote-ls", "--updates" };
                string stdout_buf = "";
                string stderr_buf = "";
                int exit_status = 0;

                Process.spawn_sync (
                    null,
                    argv,
                    null,
                    SpawnFlags.SEARCH_PATH,
                    null,
                    out stdout_buf,
                    out stderr_buf,
                    out exit_status
                );

                if (exit_status == 0 && stdout_buf.length > 0) {
                    string[] lines = stdout_buf.strip ().split ("\n");
                    int count = 0;
                    foreach (var l in lines) {
                        if (l.strip ().length > 0) {
                            count++;
                        }
                    }
                    return count;
                }
            } catch (Error e) {
                // Flatpak might not be available or command failed
            }
            return 0;
        }

        private void on_check_completed (int count) {
            if (count > 0) {
                var item = new GlanceItem (this.id, 30);
                item.icon_name = "software-update-available-symbolic";
                item.title = format_updates_count (count);
                item.shortcut_badge = "↵";
                item.tooltip = "Доступно обновлений системы: %d\nНажмите Enter, чтобы открыть центр приложений".printf (count);
                item.action_type = "app";
                item.action_payload = "io.elementary.appcenter";
                item.auto_dismiss_on_activate = true;

                // Native action launcher with fallback
                item.set_native_action (() => {
                    try {
                        string[] argv = { "io.elementary.appcenter", "--show-updates" };
                        Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    } catch (Error e1) {
                        try {
                            string[] fallback = { "io.elementary.appcenter" };
                            Process.spawn_async (null, fallback, null, SpawnFlags.SEARCH_PATH, null, null);
                        } catch (Error e2) {
                            try {
                                string[] fallback_gnome = { "gnome-software" };
                                Process.spawn_async (null, fallback_gnome, null, SpawnFlags.SEARCH_PATH, null, null);
                            } catch (Error e3) {
                                warning ("Failed to open update manager: %s", e3.message);
                            }
                        }
                    }
                });

                current_item = item;
                glance_updated (item);
            } else {
                current_item = null;
                glance_updated (null);
            }
        }

        private string format_updates_count (int count) {
            int rem10 = count % 10;
            int rem100 = count % 100;

            if (rem100 >= 11 && rem100 <= 19) {
                return "%d обновлений".printf (count);
            } else if (rem10 == 1) {
                return "%d обновление".printf (count);
            } else if (rem10 >= 2 && rem10 <= 4) {
                return "%d обновления".printf (count);
            } else {
                return "%d обновлений".printf (count);
            }
        }
    }
}
