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

        public SystemActionProvider () {
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
                { "сон", "спать", "спящий режим", "ждущий режим", "приостановить", "suspend", "sleep" },
                () => {
                    spawn_cmd ({ "systemctl", "suspend" });
                }
            ));

            // 3. Reboot
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
                { "выключить", "выключение", "вырубить", "питание", "завершить работу", "shutdown", "poweroff", "power off", "turn off" },
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
                { "выйти", "выход", "сеанс", "разлогиниться", "logout", "log out", "sign out" },
                () => {
                    spawn_cmd ({ "loginctl", "terminate-session", "" });
                }
            ));

            // 6. Empty Trash
            actions.add (new SystemAction (
                "system:empty-trash",
                "Очистить корзину",
                "Система · Безвозвратно удалить файлы из корзины",
                "user-trash-symbolic",
                "Очистить",
                { "корзина", "очистить корзину", "мусорка", "trash", "empty trash", "clean trash" },
                () => {
                    spawn_cmd ({ "gio", "trash", "--empty" });
                }
            ));

            // 7. Toggle Theme (Dark / Light)
            actions.add (new SystemAction (
                "system:toggle-theme",
                "Переключить тему оформления",
                "Система · Сменить режим между тёмным и светлым",
                "display-symbolic",
                "Переключить",
                { "тема", "темная тема", "светлая тема", "оформление", "dark theme", "light theme", "theme", "dark mode", "light mode" },
                () => {
                    try {
                        var settings = new GLib.Settings ("org.gnome.desktop.interface");
                        string current = settings.get_string ("color-scheme");
                        string next = (current == "prefer-dark") ? "default" : "prefer-dark";
                        settings.set_string ("color-scheme", next);
                    } catch (Error e) {
                        warning ("Failed to toggle theme: %s", e.message);
                    }
                }
            ));

            // 8. Screenshot
            actions.add (new SystemAction (
                "system:screenshot",
                "Сделать снимок экрана",
                "Система · Захват экрана или области",
                "applets-screenshooter-symbolic",
                "Снимок",
                { "скриншот", "скрин", "снимок", "снимок экрана", "screenshot", "screen" },
                () => {
                    spawn_cmd ({ "io.elementary.screenshot" });
                }
            ));

            // 9. Toggle Mute
            actions.add (new SystemAction (
                "system:mute-toggle",
                "Включить / Выключить звук",
                "Система · Переключить режим без звука",
                "audio-volume-muted-symbolic",
                "Переключить",
                { "звук", "без звука", "заглушить", "мут", "размут", "тишина", "mute", "unmute", "volume" },
                () => {
                    spawn_cmd ({ "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle" });
                }
            ));

            // 10. System Settings
            actions.add (new SystemAction (
                "system:settings",
                "Параметры системы",
                "Система · Открыть настройки elementary OS",
                "preferences-system-symbolic",
                "Открыть",
                { "настройки", "параметры", "опции", "конфигурация", "settings", "preferences", "control center" },
                () => {
                    spawn_cmd ({ "io.elementary.settings" });
                }
            ));

            // 11. Terminal
            actions.add (new SystemAction (
                "system:terminal",
                "Открыть терминал",
                "Система · Запустить командную строку",
                "utilities-terminal-symbolic",
                "Открыть",
                { "терминал", "консоль", "командная строка", "terminal", "console", "bash", "sh" },
                () => {
                    spawn_cmd ({ "io.elementary.terminal" });
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

            foreach (var action in actions) {
                if (cancellable != null && cancellable.is_cancelled ()) break;

                int best_score = 0;

                // 1. Check title
                string title_lower = action.title.down ();
                if (title_lower == q) {
                    best_score = int.max (best_score, 1600);
                } else if (title_lower.has_prefix (q)) {
                    best_score = int.max (best_score, 1200 + (100 - (title_lower.length - q.length)));
                } else if (title_lower.contains (q)) {
                    best_score = int.max (best_score, 700);
                }

                // 2. Check keywords
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

            return items;
        }

        public void activate (SearchItem item) {
            var action = item.target_object as SystemAction;
            if (action != null) {
                action.execute ();
            }
        }
    }
}
