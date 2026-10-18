using Gtk;
using Adw;
using Poisk.Core;

namespace Poisk.UI {

    public class CommandEditorDialog : Adw.Window {
        private CustomCommand? target_cmd = null;
        private Adw.EntryRow name_row;
        private Adw.EntryRow desc_row;
        private Adw.EntryRow cmd_row;
        private Adw.EntryRow icon_row;
        private Adw.EntryRow keywords_row;
        private Image icon_preview;

        public signal void saved (CustomCommand cmd);

        public CommandEditorDialog (Gtk.Window? parent = null, CustomCommand? existing_cmd = null) {
            Object (
                title: (existing_cmd != null) ? "Редактировать команду" : "Новая команда",
                transient_for: parent,
                modal: true,
                default_width: 520,
                default_height: 480
            );

            this.target_cmd = existing_cmd;

            var main_box = new Box (Orientation.VERTICAL, 0);

            // HeaderBar
            var header = new Adw.HeaderBar ();
            var cancel_btn = new Button.with_label ("Отмена");
            cancel_btn.clicked.connect (() => {
                this.close ();
            });
            header.pack_start (cancel_btn);

            var save_btn = new Button.with_label ("Сохранить");
            save_btn.add_css_class ("suggested-action");
            save_btn.clicked.connect (on_save_clicked);
            header.pack_end (save_btn);

            main_box.append (header);

            // Preferences content
            var clamp = new Adw.Clamp ();
            clamp.maximum_size = 500;
            clamp.margin_top = 18;
            clamp.margin_bottom = 24;
            clamp.margin_start = 18;
            clamp.margin_end = 18;

            var group = new Adw.PreferencesGroup ();
            group.title = "Параметры команды";
            group.description = "Настройте имя, команду для выполнения в терминале и значок";

            name_row = new Adw.EntryRow ();
            name_row.title = "Название";
            name_row.text = (existing_cmd != null) ? existing_cmd.name : "";

            desc_row = new Adw.EntryRow ();
            desc_row.title = "Описание";
            desc_row.text = (existing_cmd != null) ? existing_cmd.description : "";

            cmd_row = new Adw.EntryRow ();
            cmd_row.title = "Команда (bash / shell)";
            cmd_row.text = (existing_cmd != null) ? existing_cmd.command : "";

            icon_row = new Adw.EntryRow ();
            icon_row.title = "Значок (icon name)";
            string initial_icon = (existing_cmd != null && existing_cmd.icon_name.length > 0)
                ? existing_cmd.icon_name
                : "system-run-symbolic";
            icon_row.text = initial_icon;

            icon_preview = new Image.from_icon_name (initial_icon);
            icon_preview.pixel_size = 24;
            icon_preview.valign = Align.CENTER;
            icon_row.add_suffix (icon_preview);

            icon_row.notify["text"].connect (() => {
                string ic = icon_row.text.strip ();
                if (ic.length == 0) ic = "system-run-symbolic";
                icon_preview.set_from_icon_name (ic);
            });

            keywords_row = new Adw.EntryRow ();
            keywords_row.title = "Ключевые слова (через запятую)";
            keywords_row.text = (existing_cmd != null) ? existing_cmd.keywords_str : "";

            group.add (name_row);
            group.add (desc_row);
            group.add (cmd_row);
            group.add (icon_row);
            group.add (keywords_row);

            clamp.set_child (group);

            var scroll = new ScrolledWindow ();
            scroll.hexpand = true;
            scroll.vexpand = true;
            scroll.set_child (clamp);

            main_box.append (scroll);
            this.set_content (main_box);
        }

        private void on_save_clicked () {
            string name = name_row.text.strip ();
            string cmd = cmd_row.text.strip ();
            if (name.length == 0 || cmd.length == 0) {
                // Shake or warning
                return;
            }

            string desc = desc_row.text.strip ();
            string icon = icon_row.text.strip ();
            if (icon.length == 0) icon = "system-run-symbolic";
            string kw = keywords_row.text.strip ();

            string id = (target_cmd != null) ? target_cmd.id : "custom_" + GLib.get_monotonic_time ().to_string ();
            bool is_enabled = (target_cmd != null) ? target_cmd.is_enabled : true;

            var result_cmd = new CustomCommand (id, name, desc, icon, cmd, kw, is_enabled);
            saved (result_cmd);
            this.close ();
        }
    }

    public class CommandManagerDialog : Adw.Window {
        private CommandManager command_manager;
        private Adw.PreferencesGroup builtins_group;
        private Adw.PreferencesGroup custom_group;

        public CommandManagerDialog (Gtk.Window? parent = null) {
            Object (
                title: "Управление командами и действиями",
                transient_for: parent,
                modal: false,
                default_width: 680,
                default_height: 600
            );

            command_manager = CommandManager.get_default ();

            var main_box = new Box (Orientation.VERTICAL, 0);

            // Header Bar
            var header = new Adw.HeaderBar ();
            var add_btn = new Button.with_label ("+ Новая команда");
            add_btn.add_css_class ("suggested-action");
            add_btn.clicked.connect (on_add_command_clicked);
            header.pack_start (add_btn);
            main_box.append (header);

            // Scrolled content
            var scroll = new ScrolledWindow ();
            scroll.hexpand = true;
            scroll.vexpand = true;

            var clamp = new Adw.Clamp ();
            clamp.maximum_size = 640;
            clamp.margin_top = 18;
            clamp.margin_bottom = 24;
            clamp.margin_start = 18;
            clamp.margin_end = 18;

            var content_box = new Box (Orientation.VERTICAL, 24);

            // Group 1: Built-in actions
            builtins_group = new Adw.PreferencesGroup ();
            builtins_group.title = "Встроенные команды системы";
            builtins_group.description = "Включение и скрытие стандартных системных действий в строке поиска";
            content_box.append (builtins_group);

            // Group 2: Custom commands
            custom_group = new Adw.PreferencesGroup ();
            custom_group.title = "Пользовательские команды";
            custom_group.description = "Ваши собственные команды, вызываемые через поиск";
            content_box.append (custom_group);

            clamp.set_child (content_box);
            scroll.set_child (clamp);
            main_box.append (scroll);

            this.set_content (main_box);

            populate_builtins ();
            populate_custom_commands ();

            command_manager.changed.connect (() => {
                populate_builtins ();
                populate_custom_commands ();
            });
        }

        private void populate_builtins () {
            // Remove previous rows
            // Note: Adw.PreferencesGroup doesn't have a direct clear(), so we recreate the rows
            var builtin_defs = new BuiltinDef[] {
                { "system:lock", "Заблокировать экран", "блок, заблокировать, lock, lockscreen", "system-lock-screen-symbolic" },
                { "system:suspend", "Спящий режим", "сон, спящий режим, ждущий режим, sleep, suspend", "system-suspend-symbolic" },
                { "system:reboot", "Перезагрузить компьютер", "перезагрузка, рестарт, reboot, restart", "system-reboot-symbolic" },
                { "system:poweroff", "Выключить компьютер", "выключить, питание, shutdown, shut down, poweroff", "system-shutdown-symbolic" },
                { "system:logout", "Завершить сеанс", "выйти, сеанс, logout, sign out", "system-log-out-symbolic" }
            };

            // Clear builtins group children
            var child = builtins_group.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                builtins_group.remove (child);
                child = next;
            }

            foreach (var b in builtin_defs) {
                var row = new Adw.ActionRow ();
                row.title = b.title;
                row.subtitle = b.subtitle;

                var icon = new Image.from_icon_name (b.icon_name);
                icon.pixel_size = 24;
                icon.valign = Align.CENTER;
                row.add_prefix (icon);

                var sw = new Switch ();
                sw.valign = Align.CENTER;
                sw.active = !command_manager.is_builtin_hidden (b.id);
                string b_id = b.id;
                sw.notify["active"].connect (() => {
                    command_manager.set_builtin_hidden (b_id, !sw.active);
                });

                row.add_suffix (sw);
                row.activatable_widget = sw;
                builtins_group.add (row);
            }
        }

        private void populate_custom_commands () {
            // Clear custom group children
            var child = custom_group.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                custom_group.remove (child);
                child = next;
            }

            var commands = command_manager.get_custom_commands ();
            if (commands.size == 0) {
                var empty_row = new Adw.ActionRow ();
                empty_row.title = "Нет добавленных команд";
                empty_row.subtitle = "Нажмите «+ Новая команда», чтобы добавить своё действие";
                var icon = new Image.from_icon_name ("system-run-symbolic");
                icon.pixel_size = 24;
                icon.valign = Align.CENTER;
                empty_row.add_prefix (icon);
                custom_group.add (empty_row);
                return;
            }

            foreach (var cmd in commands) {
                var row = new Adw.ActionRow ();
                row.title = cmd.name;
                string sub = (cmd.description.length > 0) ? cmd.description + " · " + cmd.command : cmd.command;
                row.subtitle = sub;

                var icon = new Image.from_icon_name (cmd.icon_name);
                icon.pixel_size = 24;
                icon.valign = Align.CENTER;
                row.add_prefix (icon);

                var actions_box = new Box (Orientation.HORIZONTAL, 8);
                actions_box.valign = Align.CENTER;

                var sw = new Switch ();
                sw.valign = Align.CENTER;
                sw.active = cmd.is_enabled;
                string cmd_id = cmd.id;
                sw.notify["active"].connect (() => {
                    command_manager.set_custom_command_enabled (cmd_id, sw.active);
                });
                actions_box.append (sw);

                var edit_btn = new Button.from_icon_name ("document-edit-symbolic");
                edit_btn.valign = Align.CENTER;
                edit_btn.tooltip_text = "Редактировать";
                var c_ref = cmd;
                edit_btn.clicked.connect (() => {
                    var editor = new CommandEditorDialog (this, c_ref);
                    editor.saved.connect ((updated_cmd) => {
                        command_manager.update_custom_command (updated_cmd);
                    });
                    editor.present ();
                });
                actions_box.append (edit_btn);

                var del_btn = new Button.from_icon_name ("user-trash-symbolic");
                del_btn.valign = Align.CENTER;
                del_btn.add_css_class ("destructive-action");
                del_btn.tooltip_text = "Удалить";
                del_btn.clicked.connect (() => {
                    command_manager.remove_custom_command (cmd_id);
                });
                actions_box.append (del_btn);

                row.add_suffix (actions_box);
                custom_group.add (row);
            }
        }

        private void on_add_command_clicked () {
            var editor = new CommandEditorDialog (this, null);
            editor.saved.connect ((new_cmd) => {
                command_manager.add_custom_command (new_cmd);
            });
            editor.present ();
        }

        private struct BuiltinDef {
            public string id;
            public string title;
            public string subtitle;
            public string icon_name;
        }
    }
}
