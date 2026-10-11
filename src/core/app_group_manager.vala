using GLib;
using Json;

namespace Poisk.Core {

    public class AppGroup : GLib.Object {
        public string id { get; set; default = ""; }
        public string name { get; set; default = ""; }
        public string emoji { get; set; default = "📦"; }
        public string icon_name { get; set; default = "folder-symbolic"; }
        public int position { get; set; default = 0; }
        public bool is_hidden { get; set; default = false; }
        public bool is_default { get; set; default = false; }

        public AppGroup (string id, string name, string emoji = "📦", string icon_name = "folder-symbolic", int position = 0, bool is_hidden = false, bool is_default = false) {
            this.id = id;
            this.name = name;
            this.emoji = emoji;
            this.icon_name = icon_name;
            this.position = position;
            this.is_hidden = is_hidden;
            this.is_default = is_default;
        }
    }

    public class AppGroupManager : GLib.Object {
        private static AppGroupManager? instance = null;

        private List<AppGroup> groups = new List<AppGroup> ();
        private HashTable<string, string> app_to_group = new HashTable<string, string> (str_hash, str_equal);
        private string config_path;
        private Settings? poisk_settings = null;
        private int64 current_version = 0;
        private bool is_saving = false;

        public signal void changed ();

        public static AppGroupManager get_default () {
            if (instance == null) {
                instance = new AppGroupManager ();
            }
            return instance;
        }

        private AppGroupManager () {
            string config_dir = GLib.Path.build_filename (Environment.get_user_config_dir (), "poisk");
            DirUtils.create_with_parents (config_dir, 0755);
            config_path = GLib.Path.build_filename (config_dir, "app_groups.json");

            init_settings ();
            load ();

            if (poisk_settings != null) {
                poisk_settings.changed["groups-version"].connect (() => {
                    if (!is_saving) {
                        int64 remote_version = poisk_settings.get_int64 ("groups-version");
                        if (remote_version > current_version) {
                            load ();
                            changed ();
                        }
                    }
                });
            }
        }

        private void init_settings () {
            var schema_source = SettingsSchemaSource.get_default ();
            if (schema_source != null && schema_source.lookup ("io.github.mrlogiousbanana.poisk", true) != null) {
                poisk_settings = new Settings ("io.github.mrlogiousbanana.poisk");
            }
        }

        private void init_default_groups () {
            groups = new List<AppGroup> ();
            groups.append (new AppGroup ("work", "Рабочие", "💼", "applications-office-symbolic", 0, false, false));
            groups.append (new AppGroup ("default", "Основные", "📦", "applications-other-symbolic", 1, false, true));
            groups.append (new AppGroup ("hidden", "Скрытые", "👁️", "view-hidden-symbolic", 999, true, false));
        }

        public string normalize_app_id (string app_id) {
            string id = app_id;
            if (id.has_prefix ("app:")) {
                id = id.substring (4);
            }
            return id.strip ();
        }

        public List<AppGroup> get_groups () {
            var list = new List<AppGroup> ();
            foreach (var g in groups) {
                list.append (g);
            }
            list.sort ((a, b) => {
                if (a.is_hidden && !b.is_hidden) return 1;
                if (!a.is_hidden && b.is_hidden) return -1;
                return a.position - b.position;
            });
            return list;
        }

        public AppGroup? get_group (string group_id) {
            foreach (var g in groups) {
                if (g.id == group_id) return g;
            }
            return null;
        }

        public AppGroup? get_default_group () {
            foreach (var g in groups) {
                if (g.is_default) return g;
            }
            return get_group ("default");
        }

        public AppGroup? get_hidden_group () {
            return get_group ("hidden");
        }

        public string get_app_group_id (string raw_app_id) {
            string id = normalize_app_id (raw_app_id);
            unowned string? gid = app_to_group.lookup (id);
            if (gid != null && get_group (gid) != null) {
                return gid;
            }
            return "default";
        }

        public string get_app_group_name (string raw_app_id) {
            string gid = get_app_group_id (raw_app_id);
            var g = get_group (gid);
            if (g != null) {
                return g.name;
            }
            return "Основные";
        }

        public string get_app_badge_label (string raw_app_id) {
            string gid = get_app_group_id (raw_app_id);
            var g = get_group (gid);
            if (g != null) {
                string em = g.emoji.strip ();
                string nm = g.name.strip ();
                if (em.length > 0) {
                    if (nm.has_prefix (em)) {
                        return nm;
                    }
                    return em + " " + nm;
                }
                return nm;
            }
            return "📦 Основные";
        }

        public bool is_app_hidden (string raw_app_id) {
            return get_app_group_id (raw_app_id) == "hidden";
        }

        public void set_app_group (string raw_app_id, string group_id) {
            string id = normalize_app_id (raw_app_id);
            if (group_id == "default" || group_id.length == 0) {
                app_to_group.remove (id);
            } else {
                app_to_group.insert (id, group_id);
            }
            save ();
            changed ();
        }

        public AppGroup add_group (string name, string emoji = "📁", string icon_name = "folder-symbolic") {
            int max_pos = 0;
            foreach (var g in groups) {
                if (!g.is_hidden && g.position > max_pos) {
                    max_pos = g.position;
                }
            }

            string new_id = "custom_" + get_monotonic_time ().to_string ();
            string clean_emoji = emoji.strip ();
            if (clean_emoji.length == 0) clean_emoji = "📁";
            var new_group = new AppGroup (new_id, name.strip (), clean_emoji, icon_name, max_pos + 1, false, false);
            groups.append (new_group);

            save ();
            changed ();
            return new_group;
        }

        public bool update_group (string group_id, string new_name, string new_emoji = "") {
            var g = get_group (group_id);
            if (g == null) return false;

            string clean_name = new_name.strip ();
            if (clean_name.length > 0) {
                g.name = clean_name;
            }
            string clean_emoji = new_emoji.strip ();
            if (clean_emoji.length > 0) {
                g.emoji = clean_emoji;
            }

            save ();
            changed ();
            return true;
        }

        public bool rename_group (string group_id, string new_name) {
            return update_group (group_id, new_name, "");
        }

        public bool delete_group (string group_id) {
            var g = get_group (group_id);
            if (g == null) return false;
            if (g.is_default || g.is_hidden) return false; // Protected system groups

            // Move any apps in this group to default
            var keys_to_reset = new List<string> ();
            app_to_group.foreach ((key, val) => {
                if (val == group_id) {
                    keys_to_reset.append (key);
                }
            });
            foreach (var k in keys_to_reset) {
                app_to_group.remove (k);
            }

            groups.remove (g);
            recompact_positions ();
            save ();
            changed ();
            return true;
        }

        public bool move_group_up (string group_id) {
            var sorted = get_groups ();
            int idx = -1;
            for (int i = 0; i < sorted.length (); i++) {
                if (sorted.nth_data (i).id == group_id) {
                    idx = i;
                    break;
                }
            }

            if (idx > 0) {
                var prev = sorted.nth_data (idx - 1);
                var curr = sorted.nth_data (idx);
                if (!prev.is_hidden && !curr.is_hidden) {
                    int tmp = prev.position;
                    prev.position = curr.position;
                    curr.position = tmp;
                    if (prev.position == curr.position) {
                        curr.position = tmp - 1;
                    }
                    recompact_positions ();
                    save ();
                    changed ();
                    return true;
                }
            }
            return false;
        }

        public bool move_group_down (string group_id) {
            var sorted = get_groups ();
            int idx = -1;
            for (int i = 0; i < sorted.length (); i++) {
                if (sorted.nth_data (i).id == group_id) {
                    idx = i;
                    break;
                }
            }

            if (idx >= 0 && idx < sorted.length () - 1) {
                var curr = sorted.nth_data (idx);
                var next = sorted.nth_data (idx + 1);
                if (!next.is_hidden && !curr.is_hidden) {
                    int tmp = next.position;
                    next.position = curr.position;
                    curr.position = tmp;
                    if (next.position == curr.position) {
                        curr.position = tmp + 1;
                    }
                    recompact_positions ();
                    save ();
                    changed ();
                    return true;
                }
            }
            return false;
        }

        public void recompact_positions () {
            var sorted = get_groups ();
            int pos = 0;
            foreach (var g in sorted) {
                if (!g.is_hidden) {
                    g.position = pos++;
                } else {
                    g.position = 999;
                }
            }
        }

        public List<string> get_app_ids_in_group (string group_id, List<string> all_known_app_ids) {
            var res = new List<string> ();
            foreach (var app_id in all_known_app_ids) {
                string gid = get_app_group_id (app_id);
                if (gid == group_id) {
                    res.append (app_id);
                }
            }
            return res;
        }

        public int get_apps_count_in_group (string group_id, List<string> all_known_app_ids) {
            int count = 0;
            foreach (var app_id in all_known_app_ids) {
                if (get_app_group_id (app_id) == group_id) {
                    count++;
                }
            }
            return count;
        }

        public void load () {
            if (!FileUtils.test (config_path, FileTest.EXISTS)) {
                init_default_groups ();
                save ();
                return;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_file (config_path);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                    init_default_groups ();
                    return;
                }

                var root_obj = root.get_object ();

                // 1. Groups array
                groups = new List<AppGroup> ();
                if (root_obj.has_member ("groups")) {
                    var arr = root_obj.get_array_member ("groups");
                    for (uint i = 0; i < arr.get_length (); i++) {
                        var g_obj = arr.get_object_element (i);
                        string gid = g_obj.get_string_member ("id");
                        string name = g_obj.get_string_member ("name");
                        string icon = g_obj.has_member ("icon_name") ? g_obj.get_string_member ("icon_name") : "folder-symbolic";
                        string emoji = g_obj.has_member ("emoji") ? g_obj.get_string_member ("emoji") : "";
                        if (emoji.length == 0) {
                            if (gid == "work") emoji = "💼";
                            else if (gid == "default") emoji = "📦";
                            else if (gid == "hidden") emoji = "👁️";
                            else emoji = "📁";
                        }
                        int pos = g_obj.has_member ("position") ? (int) g_obj.get_int_member ("position") : (int) i;
                        bool is_hidden = g_obj.has_member ("is_hidden") ? g_obj.get_boolean_member ("is_hidden") : (gid == "hidden");
                        bool is_default = g_obj.has_member ("is_default") ? g_obj.get_boolean_member ("is_default") : (gid == "default");

                        groups.append (new AppGroup (gid, name, emoji, icon, pos, is_hidden, is_default));
                    }
                }

                // Ensure default & hidden groups always exist
                if (get_group ("default") == null) {
                    groups.append (new AppGroup ("default", "Основные", "📦", "applications-other-symbolic", 0, false, true));
                }
                if (get_group ("hidden") == null) {
                    groups.append (new AppGroup ("hidden", "Скрытые", "👁️", "view-hidden-symbolic", 999, true, false));
                }

                // 2. App mappings
                app_to_group = new HashTable<string, string> (str_hash, str_equal);
                if (root_obj.has_member ("app_assignments")) {
                    var mapping_obj = root_obj.get_object_member ("app_assignments");
                    mapping_obj.foreach_member ((obj, key, node) => {
                        if (node.get_node_type () == Json.NodeType.VALUE) {
                            app_to_group.insert (key, node.get_string ());
                        }
                    });
                }

                recompact_positions ();
            } catch (Error e) {
                warning ("Failed to load app groups from %s: %s", config_path, e.message);
                init_default_groups ();
            }
        }

        public void save () {
            is_saving = true;
            try {
                var builder = new Json.Builder ();
                builder.begin_object ();

                // Groups array
                builder.set_member_name ("groups");
                builder.begin_array ();
                foreach (var g in get_groups ()) {
                    builder.begin_object ();
                    builder.set_member_name ("id");
                    builder.add_string_value (g.id);
                    builder.set_member_name ("name");
                    builder.add_string_value (g.name);
                    builder.set_member_name ("emoji");
                    builder.add_string_value (g.emoji);
                    builder.set_member_name ("icon_name");
                    builder.add_string_value (g.icon_name);
                    builder.set_member_name ("position");
                    builder.add_int_value (g.position);
                    builder.set_member_name ("is_hidden");
                    builder.add_boolean_value (g.is_hidden);
                    builder.set_member_name ("is_default");
                    builder.add_boolean_value (g.is_default);
                    builder.end_object ();
                }
                builder.end_array ();

                // App assignments
                builder.set_member_name ("app_assignments");
                builder.begin_object ();
                app_to_group.foreach ((key, val) => {
                    builder.set_member_name (key);
                    builder.add_string_value (val);
                });
                builder.end_object ();

                builder.end_object ();

                var generator = new Json.Generator ();
                generator.set_root (builder.get_root ());
                generator.pretty = true;
                generator.to_file (config_path);

                // Increment version in GSettings to trigger notification across processes
                current_version = get_real_time ();
                if (poisk_settings != null) {
                    poisk_settings.set_int64 ("groups-version", current_version);
                }
            } catch (Error e) {
                warning ("Failed to save app groups to %s: %s", config_path, e.message);
            } finally {
                is_saving = false;
            }
        }
    }
}
