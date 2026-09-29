using Vicinae.Core;

namespace Vicinae.Providers {

    public class ScriptCommand : Object {
        public string file_path;
        public string title;
        public string description;
        public string package_name;
        public string icon_name;
        public string mode; // "silent", "fullOutput", "inline"

        public ScriptCommand (string path) {
            this.file_path = path;
            this.title = Path.get_basename (path);
            this.description = "";
            this.package_name = "Scripts";
            this.icon_name = "text-x-script";
            this.mode = "fullOutput";
            parse_metadata ();
        }

        private void parse_metadata () {
            try {
                var file = File.new_for_path (file_path);
                var dis = new DataInputStream (file.read ());
                string? line;
                int lines_read = 0;

                while ((line = dis.read_line ()) != null && lines_read < 40) {
                    lines_read++;
                    string l = line.strip ();
                    if (!l.has_prefix ("#") && !l.has_prefix ("//")) continue;

                    if ("@raycast.title" in l || "@title" in l) {
                        this.title = extract_val (l);
                    } else if ("@raycast.description" in l || "@description" in l) {
                        this.description = extract_val (l);
                    } else if ("@raycast.packageName" in l || "@package" in l) {
                        this.package_name = extract_val (l);
                    } else if ("@raycast.icon" in l || "@icon" in l) {
                        this.icon_name = extract_val (l);
                    } else if ("@raycast.mode" in l || "@mode" in l) {
                        this.mode = extract_val (l);
                    }
                }
            } catch (Error e) {
                // Ignore parse errors
            }
        }

        private string extract_val (string line) {
            int idx = line.index_of (" ");
            if (idx >= 0) {
                string rest = line.substring (idx + 1).strip ();
                int next_space = rest.index_of (" ");
                if (next_space >= 0) {
                    return rest.substring (next_space + 1).strip ();
                }
                return rest;
            }
            return "";
        }
    }

    public class ScriptProvider : Object, SearchProvider {
        public string id { get { return "scripts"; } }
        public string display_name { get { return "Script Commands"; } }
        public string category { get { return "Scripts"; } }
        public bool is_enabled { get; set; default = true; }

        private List<ScriptCommand> commands = new List<ScriptCommand> ();

        public ScriptProvider () {
            reload_scripts ();
        }

        public void reload_scripts () {
            commands = new List<ScriptCommand> ();
            string scripts_dir = Path.build_filename (Environment.get_user_config_dir (), "vicinae", "scripts");
            DirUtils.create_with_parents (scripts_dir, 0755);

            try {
                var dir = Dir.open (scripts_dir);
                string? name;
                while ((name = dir.read_name ()) != null) {
                    string full_path = Path.build_filename (scripts_dir, name);
                    if (FileUtils.test (full_path, FileTest.IS_EXECUTABLE) && !FileUtils.test (full_path, FileTest.IS_DIR)) {
                        commands.append (new ScriptCommand (full_path));
                    }
                }
            } catch (Error e) {
                // Directory empty or error
            }
        }

        public async List<SearchItem> search (string query_text, Cancellable? cancellable = null) {
            var items = new List<SearchItem> ();

            foreach (var cmd in commands) {
                if (cancellable != null && cancellable.is_cancelled ()) break;

                int score = 0;
                if (query_text.length == 0) {
                    score = 60;
                } else if (query_text.has_prefix (">") || query_text.has_prefix ("sh ")) {
                    string q = query_text.substring (query_text.index_of (" ") + 1).strip ();
                    score = SearchEngine.fuzzy_score (q, cmd.title) + 600;
                } else {
                    score = SearchEngine.fuzzy_score (query_text, cmd.title);
                }

                if (score > 0) {
                    var item = new SearchItem (
                        "script:" + cmd.file_path,
                        cmd.title,
                        cmd.description.length > 0 ? cmd.description : cmd.package_name,
                        cmd.icon_name.length > 0 ? cmd.icon_name : "text-x-script",
                        "Scripts"
                    );
                    item.score = score;
                    item.action_label = "Run Script";
                    item.preview_text = "<b>Script Command</b>\n\n%s\n\nPath: <tt>%s</tt>\nMode: %s".printf (
                        Markup.escape_text (cmd.title),
                        Markup.escape_text (cmd.file_path),
                        Markup.escape_text (cmd.mode)
                    );

                    item.provider = this;
                    items.append (item);
                }
            }

            return items;
        }

        public void activate (SearchItem item) {
            string path = item.id.replace ("script:", "");
            try {
                string[] argv = { path };
                Pid pid;
                Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, out pid);
                Process.close_pid (pid);
            } catch (Error e) {
                warning ("Failed to execute script %s: %s", path, e.message);
            }
        }
    }
}
