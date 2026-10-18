using GLib;
using Json;
using Gee;

namespace Poisk.Core {

    public class SystemInfoConfig : GLib.Object {
        public string tool { get; set; default = "fastfetch"; }
        public string extra_args { get; set; default = ""; }
        public string custom_command { get; set; default = "fastfetch"; }
        public string action_on_enter { get; set; default = "terminal"; } // "terminal" or "copy"
    }

    public class SystemInfoManager : GLib.Object {
        private static SystemInfoManager? instance = null;
        private string config_path;
        private SystemInfoConfig config;
        private string cached_output = "";
        private int64 cache_timestamp = 0;

        public signal void changed ();

        public static SystemInfoManager get_default () {
            if (instance == null) {
                instance = new SystemInfoManager ();
            }
            return instance;
        }

        private SystemInfoManager () {
            config = new SystemInfoConfig ();
            string config_dir = GLib.Path.build_filename (Environment.get_user_config_dir (), "poisk");
            DirUtils.create_with_parents (config_dir, 0755);
            config_path = GLib.Path.build_filename (config_dir, "system_info.json");
            load ();

            // Default fallback if fastfetch is not installed but neofetch or others are
            if (!has_tool (config.tool) && config.tool != "custom") {
                string[] candidates = { "fastfetch", "neofetch", "hyfetch", "pfetch", "cpufetch", "inxi" };
                foreach (var c in candidates) {
                    if (has_tool (c)) {
                        config.tool = c;
                        break;
                    }
                }
            }
        }

        public SystemInfoConfig get_config () {
            return config;
        }

        public string tool {
            get { return config.tool; }
            set { config.tool = value; save (); changed (); }
        }

        public string extra_args {
            get { return config.extra_args; }
            set { config.extra_args = value; save (); changed (); }
        }

        public string custom_command {
            get { return config.custom_command; }
            set { config.custom_command = value; save (); changed (); }
        }

        public string action_on_enter {
            get { return config.action_on_enter; }
            set { config.action_on_enter = value; save (); changed (); }
        }

        public static bool has_tool (string name) {
            return Environment.find_program_in_path (name) != null;
        }

        public static Gee.ArrayList<string> get_detected_tools () {
            var list = new Gee.ArrayList<string> ();
            string[] known = { "fastfetch", "neofetch", "hyfetch", "pfetch", "cpufetch", "inxi" };
            foreach (var k in known) {
                if (has_tool (k)) {
                    list.add (k);
                }
            }
            return list;
        }

        public void load () {
            if (!FileUtils.test (config_path, FileTest.EXISTS)) return;
            try {
                var parser = new Json.Parser ();
                parser.load_from_file (config_path);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) return;
                var obj = root.get_object ();

                if (obj.has_member ("tool")) config.tool = obj.get_string_member ("tool");
                if (obj.has_member ("extra_args")) config.extra_args = obj.get_string_member ("extra_args");
                if (obj.has_member ("custom_command")) config.custom_command = obj.get_string_member ("custom_command");
                if (obj.has_member ("action_on_enter")) config.action_on_enter = obj.get_string_member ("action_on_enter");
            } catch (Error e) {
                warning ("Failed to load system_info.json: %s", e.message);
            }
        }

        public void save () {
            try {
                var builder = new Json.Builder ();
                builder.begin_object ();
                builder.set_member_name ("tool");
                builder.add_string_value (config.tool);
                builder.set_member_name ("extra_args");
                builder.add_string_value (config.extra_args);
                builder.set_member_name ("custom_command");
                builder.add_string_value (config.custom_command);
                builder.set_member_name ("action_on_enter");
                builder.add_string_value (config.action_on_enter);
                builder.end_object ();

                var generator = new Json.Generator ();
                generator.set_root (builder.get_root ());
                generator.to_file (config_path);
            } catch (Error e) {
                warning ("Failed to save system_info.json: %s", e.message);
            }
        }

        public string get_effective_command (string? override_args = null) {
            if (config.tool == "custom") {
                string base_cmd = (config.custom_command.strip ().length > 0) ? config.custom_command.strip () : "fastfetch";
                if (override_args != null && override_args.strip ().length > 0) {
                    return base_cmd + " " + override_args.strip ();
                }
                return base_cmd;
            }

            string bin = Environment.find_program_in_path (config.tool) ?? config.tool;
            string args_to_use = "";

            if (override_args != null && override_args.strip ().length > 0) {
                args_to_use = override_args.strip ();
            } else if (config.extra_args.strip ().length > 0) {
                args_to_use = config.extra_args.strip ();
            }

            if (args_to_use.length > 0) {
                return bin + " " + args_to_use;
            }
            return bin;
        }

        public void invalidate_cache () {
            cached_output = "";
            cache_timestamp = 0;
        }

        public async string run_fetch (string? override_args = null, Cancellable? cancellable = null) throws GLib.Error {
            int64 now = get_monotonic_time ();
            // Cache for 3 seconds if same query
            if (override_args == null && cached_output.length > 0 && (now - cache_timestamp < 3000000)) {
                return cached_output;
            }

            string cmd = get_effective_command (override_args);

            // Execute via shell with Subprocess
            string[] argv = { "/bin/sh", "-c", cmd };
            var subp = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_MERGE);

            string? stdout_buf = null;
            string? stderr_buf = null;

            yield subp.communicate_utf8_async (null, cancellable, out stdout_buf, out stderr_buf);

            string result = stdout_buf ?? "";
            if (override_args == null) {
                cached_output = result;
                cache_timestamp = now;
            }

            return result;
        }

        public void launch_in_terminal (string? override_args = null) {
            string cmd = get_effective_command (override_args);
            string term = find_terminal_emulator ();
            string sh = (Environment.find_program_in_path ("bash") != null) ? "bash" : "sh";
            string shell_cmd = "%s; echo; echo 'Нажмите Enter для выхода...'; read _line".printf (cmd);

            try {
                if (term == "io.elementary.terminal") {
                    string[] argv = {
                        "io.elementary.terminal",
                        "-n",
                        "--",
                        sh, "-c",
                        shell_cmd
                    };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                } else if (term == "gnome-terminal" || term == "ptyxis") {
                    string[] argv = {
                        term,
                        "--",
                        sh, "-c",
                        shell_cmd
                    };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                } else if (term == "alacritty" || term == "kitty" || term == "foot") {
                    string[] argv = {
                        term,
                        "-e",
                        sh, "-c",
                        shell_cmd
                    };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                } else if (term == "xterm") {
                    string[] argv = {
                        "xterm",
                        "-hold",
                        "-e",
                        cmd
                    };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                } else {
                    // Fallback using xdg-terminal-exec if available
                    string[] argv = { "xdg-terminal-exec", sh, "-c", shell_cmd };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                }
            } catch (Error e) {
                warning ("Failed to launch terminal: %s", e.message);
            }
        }

        private static string find_terminal_emulator () {
            string[] known = {
                "io.elementary.terminal",
                "gnome-terminal",
                "ptyxis",
                "alacritty",
                "kitty",
                "foot",
                "wezterm",
                "konsole",
                "xterm"
            };
            foreach (var t in known) {
                if (Environment.find_program_in_path (t) != null) {
                    return t;
                }
            }
            return "xterm";
        }
    }
}
