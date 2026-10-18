using Gtk;
using Adw;
using Poisk.Core;

namespace Poisk.UI {

    public class SystemInfoConfigDialog : Adw.Window {
        private SystemInfoManager manager;
        private Adw.ComboRow tool_row;
        private Adw.EntryRow args_row;
        private Adw.EntryRow custom_cmd_row;
        private Adw.ComboRow enter_action_row;
        private Label preview_label;
        private Gtk.Spinner preview_spinner;
        private Button test_btn;
        private Gee.ArrayList<string> tool_names;

        public SystemInfoConfigDialog (Gtk.Window? parent = null) {
            Object (
                title: "Настройка системной информации (:system)",
                transient_for: parent,
                modal: true,
                default_width: 620,
                default_height: 580
            );

            manager = SystemInfoManager.get_default ();

            var main_box = new Box (Orientation.VERTICAL, 0);

            // Header Bar
            var header = new Adw.HeaderBar ();
            var close_btn = new Button.with_label ("Закрыть");
            close_btn.clicked.connect (() => {
                this.close ();
            });
            header.pack_end (close_btn);
            main_box.append (header);

            // Content clamp
            var scroll = new ScrolledWindow ();
            scroll.hexpand = true;
            scroll.vexpand = true;

            var clamp = new Adw.Clamp ();
            clamp.maximum_size = 580;
            clamp.margin_top = 18;
            clamp.margin_bottom = 24;
            clamp.margin_start = 18;
            clamp.margin_end = 18;

            var content_box = new Box (Orientation.VERTICAL, 20);

            // Group 1: General Parameters
            var prefs_group = new Adw.PreferencesGroup ();
            prefs_group.title = "Параметры утилиты fetch";
            prefs_group.description = "Выберите используемую команду для сбора характеристик ПК";
            content_box.append (prefs_group);

            // 1. Tool combo
            tool_row = new Adw.ComboRow ();
            tool_row.title = "Утилита (Fetch tool)";

            tool_names = new Gee.ArrayList<string> ();
            var detected = SystemInfoManager.get_detected_tools ();
            foreach (var d in detected) {
                tool_names.add (d);
            }
            if (!tool_names.contains ("fastfetch")) tool_names.add ("fastfetch");
            if (!tool_names.contains ("neofetch")) tool_names.add ("neofetch");
            tool_names.add ("custom"); // Custom command option

            var tool_model = new StringList (null);
            uint selected_idx = 0;
            for (int i = 0; i < tool_names.size; i++) {
                string t = tool_names[i];
                string label = t;
                if (t == "custom") {
                    label = "Своя команда (Custom shell command)";
                } else if (!SystemInfoManager.has_tool (t)) {
                    label = t + " (не найдена в PATH)";
                } else {
                    label = t + " (установлена)";
                }
                tool_model.append (label);

                if (t == manager.tool) {
                    selected_idx = (uint) i;
                }
            }

            tool_row.model = tool_model;
            tool_row.selected = selected_idx;
            tool_row.notify["selected"].connect (on_tool_changed);
            prefs_group.add (tool_row);

            // 2. Extra parameters / flags
            args_row = new Adw.EntryRow ();
            args_row.title = "Дополнительные параметры / флаги";
            args_row.text = manager.extra_args;
            args_row.notify["text"].connect (() => {
                manager.extra_args = args_row.text.strip ();
            });
            prefs_group.add (args_row);

            // 3. Custom command row (shown if tool == custom)
            custom_cmd_row = new Adw.EntryRow ();
            custom_cmd_row.title = "Команда shell";
            custom_cmd_row.text = manager.custom_command;
            custom_cmd_row.notify["text"].connect (() => {
                manager.custom_command = custom_cmd_row.text.strip ();
            });
            prefs_group.add (custom_cmd_row);
            custom_cmd_row.visible = (manager.tool == "custom");

            // 4. Action on Enter
            enter_action_row = new Adw.ComboRow ();
            enter_action_row.title = "Действие по нажатию ↵ Enter";
            var action_model = new StringList (null);
            action_model.append ("Запустить в терминале");
            action_model.append ("Скопировать текст в буфер обмена");
            enter_action_row.model = action_model;
            enter_action_row.selected = (manager.action_on_enter == "copy") ? 1 : 0;
            enter_action_row.notify["selected"].connect (() => {
                manager.action_on_enter = (enter_action_row.selected == 1) ? "copy" : "terminal";
            });
            prefs_group.add (enter_action_row);

            // Group 2: Live Preview
            var preview_group = new Adw.PreferencesGroup ();
            preview_group.title = "Предпросмотр вывода";
            preview_group.description = "Результат выполнения команды в реальном времени";
            content_box.append (preview_group);

            var preview_card = new Box (Orientation.VERTICAL, 8);
            preview_card.add_css_class ("card");
            preview_card.margin_top = 4;
            preview_card.margin_bottom = 4;
            preview_card.margin_start = 0;
            preview_card.margin_end = 0;
            preview_card.set_size_request (-1, 240);

            var preview_header_bar = new Box (Orientation.HORIZONTAL, 8);
            preview_header_bar.margin_start = 12;
            preview_header_bar.margin_end = 12;
            preview_header_bar.margin_top = 8;
            preview_header_bar.margin_bottom = 4;

            preview_spinner = new Gtk.Spinner ();
            preview_spinner.valign = Align.CENTER;
            preview_spinner.visible = false;
            preview_header_bar.append (preview_spinner);

            var cmd_preview_label = new Label ("");
            cmd_preview_label.add_css_class ("dim-label");
            cmd_preview_label.add_css_class ("caption");
            cmd_preview_label.hexpand = true;
            cmd_preview_label.halign = Align.START;
            preview_header_bar.append (cmd_preview_label);

            test_btn = new Button.with_label ("Проверить команду");
            test_btn.valign = Align.CENTER;
            test_btn.clicked.connect (() => {
                run_test_preview (cmd_preview_label);
            });
            preview_header_bar.append (test_btn);

            preview_card.append (preview_header_bar);

            var preview_scroll = new ScrolledWindow ();
            preview_scroll.vexpand = true;
            preview_scroll.hexpand = true;
            preview_scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);

            preview_label = new Label ("Нажмите «Проверить команду» для загрузки предпросмотра");
            preview_label.use_markup = true;
            preview_label.selectable = true;
            preview_label.halign = Align.START;
            preview_label.valign = Align.START;
            preview_label.margin_start = 14;
            preview_label.margin_end = 14;
            preview_label.margin_top = 8;
            preview_label.margin_bottom = 12;
            preview_label.add_css_class ("system-fetch-text");

            preview_scroll.set_child (preview_label);
            preview_card.append (preview_scroll);
            preview_group.add (preview_card);

            clamp.set_child (content_box);
            scroll.set_child (clamp);
            main_box.append (scroll);

            this.set_content (main_box);

            // Auto-trigger preview test once dialog is presented
            GLib.Timeout.add (100, () => {
                run_test_preview (cmd_preview_label);
                return GLib.Source.REMOVE;
            });
        }

        private void on_tool_changed () {
            uint idx = tool_row.selected;
            if (idx < tool_names.size) {
                string chosen = tool_names[(int) idx];
                manager.tool = chosen;
                custom_cmd_row.visible = (chosen == "custom");
            }
        }

        private void run_test_preview (Label cmd_lbl) {
            cmd_lbl.set_text (manager.get_effective_command ());
            preview_spinner.visible = true;
            preview_spinner.start ();
            test_btn.sensitive = false;

            manager.invalidate_cache ();
            manager.run_fetch.begin (null, null, (obj, res) => {
                preview_spinner.stop ();
                preview_spinner.visible = false;
                test_btn.sensitive = true;
                try {
                    string raw = manager.run_fetch.end (res);
                    if (raw.strip ().length == 0) {
                        preview_label.set_text ("(Команда не вернула данных)");
                    } else {
                        string markup = AnsiParser.ansi_to_pango (raw);
                        preview_label.set_markup (markup);
                    }
                } catch (Error e) {
                    preview_label.set_text ("Ошибка: " + e.message);
                }
            });
        }
    }
}
