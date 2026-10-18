using GLib;
using Json;
using Gee;

namespace Poisk.Core {

    public class CustomCommand : GLib.Object {
        public string id { get; set; default = ""; }
        public string name { get; set; default = ""; }
        public string description { get; set; default = ""; }
        public string icon_name { get; set; default = "system-run-symbolic"; }
        public string command { get; set; default = ""; }
        public string keywords_str { get; set; default = ""; }
        public bool is_enabled { get; set; default = true; }

        public CustomCommand (string id, string name, string description, string icon_name, string command, string keywords_str = "", bool is_enabled = true) {
            this.id = id;
            this.name = name;
            this.description = description;
            this.icon_name = (icon_name.strip ().length > 0) ? icon_name.strip () : "system-run-symbolic";
            this.command = command;
            this.keywords_str = keywords_str;
            this.is_enabled = is_enabled;
        }

        public string[] get_keywords () {
            if (keywords_str.strip ().length == 0) return {};
            string[] raw = keywords_str.split (",");
            var res = new Gee.ArrayList<string> ();
            foreach (var r in raw) {
                string trimmed = r.strip ();
                if (trimmed.length > 0) res.add (trimmed);
            }
            return res.to_array ();
        }
    }

    public class CommandManager : GLib.Object {
        private static CommandManager? instance = null;

        private Gee.HashSet<string> hidden_builtins = new Gee.HashSet<string> ();
        private Gee.ArrayList<CustomCommand> custom_commands = new Gee.ArrayList<CustomCommand> ();
        private string config_path;

        public signal void changed ();

        public static CommandManager get_default () {
            if (instance == null) {
                instance = new CommandManager ();
            }
            return instance;
        }

        private CommandManager () {
            string config_dir = GLib.Path.build_filename (Environment.get_user_config_dir (), "poisk");
            DirUtils.create_with_parents (config_dir, 0755);
            config_path = GLib.Path.build_filename (config_dir, "commands.json");
            load ();
        }

        public bool is_builtin_hidden (string id) {
            return hidden_builtins.contains (id);
        }

        public void set_builtin_hidden (string id, bool hidden) {
            if (hidden) {
                hidden_builtins.add (id);
            } else {
                hidden_builtins.remove (id);
            }
            save ();
            changed ();
        }

        public Gee.ArrayList<CustomCommand> get_custom_commands () {
            var list = new Gee.ArrayList<CustomCommand> ();
            foreach (var c in custom_commands) {
                list.add (c);
            }
            return list;
        }

        public CustomCommand? get_custom_command (string id) {
            foreach (var c in custom_commands) {
                if (c.id == id) return c;
            }
            return null;
        }

        public void add_custom_command (CustomCommand cmd) {
            custom_commands.add (cmd);
            save ();
            changed ();
        }

        public void update_custom_command (CustomCommand cmd) {
            for (int i = 0; i < custom_commands.size; i++) {
                if (custom_commands[i].id == cmd.id) {
                    custom_commands[i] = cmd;
                    break;
                }
            }
            save ();
            changed ();
        }

        public void remove_custom_command (string id) {
            for (int i = 0; i < custom_commands.size; i++) {
                if (custom_commands[i].id == id) {
                    custom_commands.remove_at (i);
                    break;
                }
            }
            save ();
            changed ();
        }

        public void set_custom_command_enabled (string id, bool enabled) {
            var cmd = get_custom_command (id);
            if (cmd != null) {
                cmd.is_enabled = enabled;
                save ();
                changed ();
            }
        }

        public void load () {
            hidden_builtins.clear ();
            custom_commands.clear ();

            if (!FileUtils.test (config_path, FileTest.EXISTS)) {
                return;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_file (config_path);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) return;

                var root_obj = root.get_object ();

                // 1. Hidden built-ins
                if (root_obj.has_member ("hidden_builtins")) {
                    var hb_arr = root_obj.get_array_member ("hidden_builtins");
                    for (uint i = 0; i < hb_arr.get_length (); i++) {
                        string bid = hb_arr.get_string_element (i);
                        if (bid.length > 0) {
                            hidden_builtins.add (bid);
                        }
                    }
                }

                // 2. Custom commands
                if (root_obj.has_member ("custom_commands")) {
                    var cc_arr = root_obj.get_array_member ("custom_commands");
                    for (uint i = 0; i < cc_arr.get_length (); i++) {
                        var c_node = cc_arr.get_element (i);
                        if (c_node.get_node_type () != Json.NodeType.OBJECT) continue;
                        var c_obj = c_node.get_object ();

                        string id = c_obj.has_member ("id") ? c_obj.get_string_member ("id") : "";
                        string name = c_obj.has_member ("name") ? c_obj.get_string_member ("name") : "";
                        string description = c_obj.has_member ("description") ? c_obj.get_string_member ("description") : "";
                        string icon_name = c_obj.has_member ("icon_name") ? c_obj.get_string_member ("icon_name") : "system-run-symbolic";
                        string command = c_obj.has_member ("command") ? c_obj.get_string_member ("command") : "";
                        string keywords_str = c_obj.has_member ("keywords") ? c_obj.get_string_member ("keywords") : "";
                        bool is_enabled = c_obj.has_member ("is_enabled") ? c_obj.get_boolean_member ("is_enabled") : true;

                        if (id.length > 0 && name.length > 0 && command.length > 0) {
                            custom_commands.add (new CustomCommand (id, name, description, icon_name, command, keywords_str, is_enabled));
                        }
                    }
                }
            } catch (Error e) {
                warning ("Failed to load commands config from %s: %s", config_path, e.message);
            }
        }

        public void save () {
            try {
                var builder = new Json.Builder ();
                builder.begin_object ();

                // Hidden builtins
                builder.set_member_name ("hidden_builtins");
                builder.begin_array ();
                foreach (var bid in hidden_builtins) {
                    builder.add_string_value (bid);
                }
                builder.end_array ();

                // Custom commands
                builder.set_member_name ("custom_commands");
                builder.begin_array ();
                foreach (var c in custom_commands) {
                    builder.begin_object ();
                    builder.set_member_name ("id");
                    builder.add_string_value (c.id);
                    builder.set_member_name ("name");
                    builder.add_string_value (c.name);
                    builder.set_member_name ("description");
                    builder.add_string_value (c.description);
                    builder.set_member_name ("icon_name");
                    builder.add_string_value (c.icon_name);
                    builder.set_member_name ("command");
                    builder.add_string_value (c.command);
                    builder.set_member_name ("keywords");
                    builder.add_string_value (c.keywords_str);
                    builder.set_member_name ("is_enabled");
                    builder.add_boolean_value (c.is_enabled);
                    builder.end_object ();
                }
                builder.end_array ();

                builder.end_object ();

                var generator = new Json.Generator ();
                generator.set_root (builder.get_root ());
                generator.pretty = true;
                generator.to_file (config_path);
            } catch (Error e) {
                warning ("Failed to save commands config to %s: %s", config_path, e.message);
            }
        }
    }
}
