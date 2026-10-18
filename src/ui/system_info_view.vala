using Gtk;
using Poisk.Core;

namespace Poisk.UI {

    public class SystemInfoView : Box {
        private SystemInfoManager manager;
        private ScrolledWindow scrolled_window;
        private Label output_label;
        private Gtk.Spinner loading_spinner;
        private Label status_label;
        private Box status_box;
        private Button copy_btn;
        private Button refresh_btn;
        private Button config_btn;
        private Label footer_label;
        private string raw_output = "";
        private string? current_override_args = null;
        private Cancellable? current_cancellable = null;

        public signal void close_requested ();

        public SystemInfoView () {
            Object (orientation: Orientation.VERTICAL, spacing: 0);
            manager = SystemInfoManager.get_default ();

            this.vexpand = true;
            this.hexpand = true;

            // Main output display scroll area
            scrolled_window = new ScrolledWindow ();
            scrolled_window.vexpand = true;
            scrolled_window.hexpand = true;
            scrolled_window.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);

            var content_wrapper = new Box (Orientation.VERTICAL, 0);
            content_wrapper.vexpand = true;
            content_wrapper.hexpand = true;
            content_wrapper.valign = Align.START;

            // Loading / Status Box
            status_box = new Box (Orientation.HORIZONTAL, 10);
            status_box.valign = Align.CENTER;
            status_box.halign = Align.CENTER;
            status_box.vexpand = true;
            status_box.margin_top = 40;
            status_box.margin_bottom = 40;

            loading_spinner = new Gtk.Spinner ();
            loading_spinner.set_size_request (24, 24);
            status_box.append (loading_spinner);

            status_label = new Label ("Сбор характеристик системы...");
            status_label.add_css_class ("dim-label");
            status_box.append (status_label);

            content_wrapper.append (status_box);

            // Fastfetch / Fetch Terminal-style output
            output_label = new Label ("");
            output_label.use_markup = true;
            output_label.selectable = true;
            output_label.xalign = 0.0f;
            output_label.yalign = 0.0f;
            output_label.halign = Align.START;
            output_label.valign = Align.START;
            output_label.margin_start = 28;
            output_label.margin_end = 24;
            output_label.margin_top = 18;
            output_label.margin_bottom = 18;
            output_label.add_css_class ("system-fetch-text");
            output_label.add_css_class ("monospace");
            output_label.visible = false;

            content_wrapper.append (output_label);
            scrolled_window.set_child (content_wrapper);
            this.append (scrolled_window);

            // Separator
            var sep = new Separator (Orientation.HORIZONTAL);
            this.append (sep);

            // Footer
            var footer_box = new Box (Orientation.HORIZONTAL, 6);
            footer_box.margin_start = 14;
            footer_box.margin_end = 12;
            footer_box.margin_top = 4;
            footer_box.margin_bottom = 6;

            footer_label = new Label ("↵ Запустить в терминале    Ctrl+C Скопировать    ⎋ Очистить");
            footer_label.add_css_class ("dim-label");
            footer_label.add_css_class ("caption");
            footer_label.halign = Align.START;
            footer_label.hexpand = true;
            footer_box.append (footer_label);

            // Refresh button
            refresh_btn = new Button.from_icon_name ("view-refresh-symbolic");
            refresh_btn.valign = Align.CENTER;
            refresh_btn.tooltip_text = "Обновить системные данные (Ctrl+R)";
            refresh_btn.add_css_class ("flat");
            refresh_btn.add_css_class ("circular");
            refresh_btn.clicked.connect (() => {
                manager.invalidate_cache ();
                load_info.begin (current_override_args);
            });
            footer_box.append (refresh_btn);

            // Copy button
            copy_btn = new Button.from_icon_name ("edit-copy-symbolic");
            copy_btn.valign = Align.CENTER;
            copy_btn.tooltip_text = "Скопировать вывод в буфер обмена (Ctrl+C)";
            copy_btn.add_css_class ("flat");
            copy_btn.add_css_class ("circular");
            copy_btn.clicked.connect (() => {
                copy_to_clipboard ();
            });
            footer_box.append (copy_btn);

            // Settings button
            config_btn = new Button.from_icon_name ("emblem-system-symbolic");
            config_btn.valign = Align.CENTER;
            config_btn.tooltip_text = "Настроить системную информацию (:system)";
            config_btn.add_css_class ("flat");
            config_btn.add_css_class ("circular");
            config_btn.clicked.connect (() => {
                open_config_dialog ();
            });
            footer_box.append (config_btn);

            this.append (footer_box);

            manager.changed.connect (() => {
                manager.invalidate_cache ();
                load_info.begin (current_override_args);
            });
        }

        public async void load_info (string? override_args = null) {
            current_override_args = override_args;

            if (current_cancellable != null) {
                current_cancellable.cancel ();
            }
            current_cancellable = new Cancellable ();

            status_box.visible = true;
            loading_spinner.visible = true;
            loading_spinner.start ();
            status_label.set_text ("Сбор характеристик системы...");
            output_label.visible = false;

            try {
                string raw = yield manager.run_fetch (override_args, current_cancellable);
                if (current_cancellable.is_cancelled ()) return;

                raw_output = raw;
                loading_spinner.stop ();
                status_box.visible = false;

                if (raw.strip ().length == 0) {
                    output_label.set_text ("(Команда не вернула данных)");
                } else {
                    string markup = AnsiParser.ansi_to_pango (raw);
                    output_label.set_markup (markup);
                }
                output_label.visible = true;

                // Update footer shortcut label based on manager config
                if (manager.action_on_enter == "copy") {
                    footer_label.set_text ("↵ Скопировать    Ctrl+R Обновить    ⎋ Очистить");
                } else {
                    footer_label.set_text ("↵ Запустить в терминале    Ctrl+C Скопировать    ⎋ Очистить");
                }
            } catch (Error e) {
                if (current_cancellable != null && current_cancellable.is_cancelled ()) return;
                loading_spinner.stop ();
                loading_spinner.visible = false;
                status_box.visible = true;
                status_label.set_text ("Ошибка запуска: " + e.message);
                output_label.visible = false;
            }
        }

        public void copy_to_clipboard () {
            string plain = AnsiParser.strip_ansi (raw_output);
            if (plain.length == 0) return;

            var display = Gdk.Display.get_default ();
            if (display != null) {
                var clipboard = display.get_clipboard ();
                clipboard.set_text (plain);
            }

            copy_btn.tooltip_text = "Скопировано!";
            GLib.Timeout.add_seconds (2, () => {
                copy_btn.tooltip_text = "Скопировать вывод в буфер обмена (Ctrl+C)";
                return GLib.Source.REMOVE;
            });
        }

        public void execute_default_action () {
            if (manager.action_on_enter == "copy") {
                copy_to_clipboard ();
            } else {
                manager.launch_in_terminal (current_override_args);
            }
        }

        public void open_config_dialog () {
            Gtk.Window? parent_win = this.get_root () as Gtk.Window;
            var dlg = new SystemInfoConfigDialog (parent_win);
            dlg.present ();
        }
    }
}
