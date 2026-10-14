using Poisk.Core;

namespace Poisk.Providers {

    public class AppProvider : Object, SearchProvider {
        public string id { get { return "apps"; } }
        public string display_name { get { return "Applications"; } }
        public string category { get { return "Applications"; } }
        public bool is_enabled { get; set; default = true; }

        private List<AppInfo> cached_apps = new List<AppInfo> ();

        public AppProvider () {
            reload_apps ();
            AppInfoMonitor.get ().changed.connect (() => {
                reload_apps ();
            });
        }

        private void reload_apps () {
            cached_apps = new List<AppInfo> ();
            var apps = AppInfo.get_all ();
            foreach (var app in apps) {
                if (app.should_show ()) {
                    cached_apps.append (app);
                }
            }
        }

        public async List<SearchItem> search (string query_text, Cancellable? cancellable = null) {
            var items = new List<SearchItem> ();
            var db = Database.get_default ();
            var group_manager = AppGroupManager.get_default ();

            foreach (unowned AppInfo app in cached_apps) {
                if (cancellable != null && cancellable.is_cancelled ()) break;

                string name = app.get_display_name () ?? app.get_name () ?? "";
                string desc = app.get_description () ?? "";
                string exec = app.get_executable () ?? "";
                string app_id = app.get_id () ?? name;

                // 1. Skip hidden applications completely
                if (group_manager.is_app_hidden (app_id)) {
                    continue;
                }

                string group_name = group_manager.get_app_group_name (app_id);
                string badge_label = group_manager.get_app_badge_label (app_id);

                int score = 0;
                if (query_text.length == 0) {
                    // When empty, show frequently used apps
                    int usage = db.get_app_usage_count (app_id);
                    if (usage > 0) {
                        score = 200 + int.min (usage * 10, 500);
                    } else {
                        score = 50;
                    }
                } else {
                    int name_score = SearchEngine.fuzzy_score (query_text, name);
                    int exec_score = SearchEngine.fuzzy_score (query_text, exec);
                    int desc_score = desc.length > 0 ? (SearchEngine.fuzzy_score (query_text, desc) / 2) : 0;
                    int group_score = int.max (
                        SearchEngine.fuzzy_score (query_text, group_name),
                        SearchEngine.fuzzy_score (query_text, badge_label)
                    );
                    
                    score = int.max (name_score, int.max (exec_score, desc_score));
                    if (group_score > 0) {
                        score = int.max (score, group_score + 150);
                    }

                    if (score > 0) {
                        int usage = db.get_app_usage_count (app_id);
                        score += int.min (usage * 15, 300); // Frequency boost
                    }
                }

                if (score > 0) {
                    string icon_name = "application-x-executable";
                    var icon = app.get_icon ();
                    if (icon != null) {
                        icon_name = icon.to_string ();
                    }

                    var item = new SearchItem (
                        "app:" + app_id,
                        name,
                        desc.length > 0 ? desc : exec,
                        icon_name,
                        badge_label
                    );
                    item.score = score;
                    item.action_label = "Launch Application";
                    item.provider = this;
                    item.target_object = app;
                    item.preview_text = "<b>%s</b>\n\n%s\n\nGroup: <tt>%s</tt>\nCommand: <tt>%s</tt>\nDesktop File: <tt>%s</tt>".printf (
                        Markup.escape_text (name),
                        Markup.escape_text (desc.length > 0 ? desc : "No description available"),
                        Markup.escape_text (badge_label),
                        Markup.escape_text (exec),
                        Markup.escape_text (app_id)
                    );

                    items.append (item);
                }
            }

            return items;
        }

        public List<SearchItem> get_all_applications () {
            var items = new List<SearchItem> ();
            var group_manager = AppGroupManager.get_default ();

            foreach (unowned AppInfo app in cached_apps) {
                string name = app.get_display_name () ?? app.get_name () ?? "";
                string desc = app.get_description () ?? "";
                string exec = app.get_executable () ?? "";
                string app_id = app.get_id () ?? name;

                if (group_manager.is_app_hidden (app_id)) {
                    continue;
                }

                string badge_label = group_manager.get_app_badge_label (app_id);

                string icon_name = "application-x-executable";
                var icon = app.get_icon ();
                if (icon != null) {
                    icon_name = icon.to_string ();
                }

                var item = new SearchItem (
                    "app:" + app_id,
                    name,
                    desc.length > 0 ? desc : exec,
                    icon_name,
                    badge_label
                );
                item.action_label = "Launch Application";
                item.provider = this;
                item.target_object = app;
                items.append (item);
            }
            items.sort ((a, b) => a.title.collate (b.title));
            return items;
        }

        public List<AppInfo> get_all_installed_app_infos () {
            var list = new List<AppInfo> ();
            foreach (unowned AppInfo app in cached_apps) {
                list.append (app);
            }
            list.sort ((a, b) => {
                string an = a.get_display_name () ?? a.get_name () ?? "";
                string bn = b.get_display_name () ?? b.get_name () ?? "";
                return an.collate (bn);
            });
            return list;
        }

        public void activate (SearchItem item) {
            AppInfo? app = item.target_object as AppInfo;
            if (app == null) {
                string app_id = item.id.replace ("app:", "");
                foreach (unowned AppInfo a in cached_apps) {
                    if (a.get_id () == app_id || a.get_name () == app_id || a.get_display_name () == app_id) {
                        app = a;
                        break;
                    }
                }
            }

            if (app != null) {
                bool launched = false;
                try {
                    var display = Gdk.Display.get_default ();
                    var context = display != null ? display.get_app_launch_context () : null;
                    if (context != null) {
                        string? wayland = GLib.Environment.get_variable ("WAYLAND_DISPLAY");
                        if (wayland != null) {
                            context.setenv ("WAYLAND_DISPLAY", wayland);
                        } else {
                            string runtime_dir = GLib.Environment.get_user_runtime_dir ();
                            if (GLib.FileUtils.test (GLib.Path.build_filename (runtime_dir, "wayland-0"), GLib.FileTest.EXISTS)) {
                                context.setenv ("WAYLAND_DISPLAY", "wayland-0");
                            }
                        }
                        string? x11 = GLib.Environment.get_variable ("DISPLAY");
                        if (x11 != null) {
                            context.setenv ("DISPLAY", x11);
                        } else if (GLib.FileUtils.test ("/tmp/.X11-unix/X0", GLib.FileTest.EXISTS)) {
                            context.setenv ("DISPLAY", ":0");
                        }
                    }
                    launched = app.launch (null, context);
                    Database.get_default ().record_app_launch (app.get_id () ?? item.id);
                } catch (Error e) {
                    warning ("AppProvider: app.launch failed for %s: %s", app.get_name (), e.message);
                }

                if (!launched) {
                    string? cmd = app.get_commandline ();
                    if (cmd != null && cmd.length > 0) {
                        try {
                            string clean_cmd = cmd.replace ("%u", "").replace ("%U", "").replace ("%f", "").replace ("%F", "").strip ();
                            Process.spawn_command_line_async (clean_cmd);
                            launched = true;
                        } catch (SpawnError se) {
                            warning ("AppProvider: spawn fallback failed for %s: %s", app.get_name (), se.message);
                        }
                    }
                }
            } else {
                warning ("AppProvider: Could not find AppInfo for %s", item.id);
            }
        }
    }
}
