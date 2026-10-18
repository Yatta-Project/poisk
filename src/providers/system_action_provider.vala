using Poisk.Core;

namespace Poisk.Providers {

    public delegate void SystemActionCallback ();

    public class SystemAction : GLib.Object {
        public string id { get; set; }
        public string title { get; set; }
        public string subtitle { get; set; }
        public string icon_name { get; set; }
        public string action_label { get; set; }
        public string[] keywords { get; set; }
        public SystemActionCallback callback;

        public SystemAction (
            string id,
            string title,
            string subtitle,
            string icon_name,
            string action_label,
            string[] keywords,
            owned SystemActionCallback callback
        ) {
            this.id = id;
            this.title = title;
            this.subtitle = subtitle;
            this.icon_name = icon_name;
            this.action_label = action_label;
            this.keywords = keywords;
            this.callback = (owned) callback;
        }

        public void execute () {
            callback ();
        }
    }

    public class SystemActionProvider : GLib.Object, SearchProvider {
        public string id { get { return "system-actions"; } }
        public string display_name { get { return "System Actions"; } }
        public string category { get { return "Команда"; } }
        public bool is_enabled { get; set; default = true; }

        private Gee.ArrayList<SystemAction> actions = new Gee.ArrayList<SystemAction> ();
        private CommandManager command_manager;

        public SystemActionProvider () {
            command_manager = CommandManager.get_default ();
            init_actions ();
        }

        private void init_actions () {
            // 1. Lock screen
            actions.add (new SystemAction (
                "system:lock",
                "Заблокировать экран",
                "Система · Заблокировать текущий сеанс пользователя",
                "system-lock-screen-symbolic",
                "Заблокировать",
                { "заблокировать", "блок", "замок", "блокировка", "lock", "lockscreen", "screen" },
                () => {
                    spawn_cmd ({ "loginctl", "lock-session" });
                }
            ));

            // 2. Suspend / Sleep
            actions.add (new SystemAction (
                "system:suspend",
                "Спящий режим",
                "Система · Перевести компьютер в ждущий режим",
                "system-suspend-symbolic",
                "Усыпить",
                { "сон", "спящий режим", "ждущий режим", "приостановить", "suspend", "sleep" },
                () => {
                    spawn_cmd ({ "systemctl", "suspend" });
                }
            ));

            // 3. Reboot / Restart
            actions.add (new SystemAction (
                "system:reboot",
                "Перезагрузить компьютер",
                "Система · Перезапуск операционной системы",
                "system-reboot-symbolic",
                "Перезагрузить",
                { "перезагрузка", "перезагрузить", "рестарт", "ребут", "reboot", "restart" },
                () => {
                    spawn_cmd ({ "systemctl", "reboot" });
                }
            ));

            // 4. Power off / Shut down
            actions.add (new SystemAction (
                "system:poweroff",
                "Выключить компьютер",
                "Система · Завершить работу и отключить питание",
                "system-shutdown-symbolic",
                "Выключить",
                { "выключить", "выключение", "завершить работу", "питание", "shutdown", "shut down", "poweroff", "power off", "turn off" },
                () => {
                    spawn_cmd ({ "systemctl", "poweroff" });
                }
            ));

            // 5. Log out
            actions.add (new SystemAction (
                "system:logout",
                "Завершить сеанс",
                "Система · Выйти из текущей учетной записи",
                "system-log-out-symbolic",
                "Выйти",
                { "завершить сеанс", "выйти", "выход", "сеанс", "разлогиниться", "logout", "log out", "sign out" },
                () => {
                    spawn_cmd ({ "loginctl", "terminate-session", "" });
                }
            ));
        }

        private static void spawn_cmd (string[] argv) {
            try {
                Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
            } catch (Error e) {
                warning ("SystemActionProvider failed to execute command: %s", e.message);
            }
        }

        public async List<SearchItem> search (string query_text, Cancellable? cancellable = null) {
            var items = new List<SearchItem> ();
            string q = query_text.strip ().down ();
            if (q.length == 0) return items;

            // 1. Search Built-in Actions (if not hidden)
            foreach (var action in actions) {
                if (cancellable != null && cancellable.is_cancelled ()) break;
                if (command_manager.is_builtin_hidden (action.id)) continue;

                int best_score = 0;

                // Title match
                string title_lower = action.title.down ();
                if (title_lower == q) {
                    best_score = int.max (best_score, 1600);
                } else if (title_lower.has_prefix (q)) {
                    best_score = int.max (best_score, 1200 + (100 - (title_lower.length - q.length)));
                } else if (title_lower.contains (q)) {
                    best_score = int.max (best_score, 700);
                }

                // Keywords match
                foreach (var kw in action.keywords) {
                    string kw_lower = kw.down ();
                    if (kw_lower == q) {
                        best_score = int.max (best_score, 1500);
                    } else if (kw_lower.has_prefix (q)) {
                        best_score = int.max (best_score, 1100 + (100 - (kw_lower.length - q.length)));
                    } else if (kw_lower.contains (q)) {
                        best_score = int.max (best_score, 600);
                    } else {
                        int f_score = SearchEngine.fuzzy_score (q, kw_lower);
                        if (f_score > 60) {
                            best_score = int.max (best_score, f_score + 100);
                        }
                    }
                }

                if (best_score > 0) {
                    var item = new SearchItem (
                        action.id,
                        action.title,
                        action.subtitle,
                        action.icon_name,
                        "Команда"
                    );
                    item.score = best_score;
                    item.action_label = action.action_label;
                    item.preview_text = "<b>%s</b>\n\n%s\n\nНажмите ↵ для выполнения команды.".printf (
                        Markup.escape_text (action.title),
                        Markup.escape_text (action.subtitle)
                    );
                    item.provider = this;
                    item.target_object = action;
                    items.append (item);
                }
            }

            // 2. Search Custom Commands
            foreach (var cmd in command_manager.get_custom_commands ()) {
                if (cancellable != null && cancellable.is_cancelled ()) break;
                if (!cmd.is_enabled) continue;

                int best_score = 0;

                // Name match
                string name_lower = cmd.name.down ();
                if (name_lower == q) {
                    best_score = int.max (best_score, 1600);
                } else if (name_lower.has_prefix (q)) {
                    best_score = int.max (best_score, 1200 + (100 - (name_lower.length - q.length)));
                } else if (name_lower.contains (q)) {
                    best_score = int.max (best_score, 700);
                }

                // Keywords match
                foreach (var kw in cmd.get_keywords ()) {
                    string kw_lower = kw.down ();
                    if (kw_lower == q) {
                        best_score = int.max (best_score, 1500);
                    } else if (kw_lower.has_prefix (q)) {
                        best_score = int.max (best_score, 1100 + (100 - (kw_lower.length - q.length)));
                    } else if (kw_lower.contains (q)) {
                        best_score = int.max (best_score, 600);
                    } else {
                        int f_score = SearchEngine.fuzzy_score (q, kw_lower);
                        if (f_score > 60) {
                            best_score = int.max (best_score, f_score + 100);
                        }
                    }
                }

                if (best_score > 0) {
                    string sub = (cmd.description.length > 0) ? cmd.description : cmd.command;
                    var item = new SearchItem (
                        cmd.id,
                        cmd.name,
                        sub,
                        cmd.icon_name,
                        "Команда"
                    );
                    item.score = best_score;
                    item.action_label = "Выполнить";
                    item.preview_text = "<b>%s</b>\n\n%s\n\nКоманда: <code>%s</code>\n\nНажмите ↵ для запуска.".printf (
                        Markup.escape_text (cmd.name),
                        Markup.escape_text (sub),
                        Markup.escape_text (cmd.command)
                    );
                    item.provider = this;
                    item.target_object = cmd;
                    items.append (item);
                }
            }

            return items;
        }

        public void activate (SearchItem item) {
            var action = item.target_object as SystemAction;
            if (action != null) {
                action.execute ();
                return;
            }

            var cmd = item.target_object as CustomCommand;
            if (cmd != null) {
                spawn_cmd ({ "/bin/sh", "-c", cmd.command });
            }
        }
    }
}
