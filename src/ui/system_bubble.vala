using Gtk;

namespace Poisk.UI {

    public class SystemBubble : Box {
        private SatelliteButton button;
        private Popover popover;

        public signal void action_triggered ();

        public SystemBubble () {
            Object (orientation: Orientation.HORIZONTAL, spacing: 0);

            // Determine best available system logo
            var icon_theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            string logo_name = "preferences-system";
            if (icon_theme.has_icon ("nix-snowflake")) {
                logo_name = "nix-snowflake";
            } else if (icon_theme.has_icon ("distributor-logo-pantheon")) {
                logo_name = "distributor-logo-pantheon";
            } else if (icon_theme.has_icon ("distributor-logo")) {
                logo_name = "distributor-logo";
            } else if (icon_theme.has_icon ("fedora-logo-icon")) {
                logo_name = "fedora-logo-icon";
            } else if (icon_theme.has_icon ("fedora-logo")) {
                logo_name = "fedora-logo";
            }

            button = new SatelliteButton (logo_name, "Системное меню и параметры");
            button.add_css_class ("system-bubble-btn");
            button.frosted = true;
            this.valign = Align.START;
            this.append (button);

            setup_popover ();

            button.clicked.connect (() => {
                popover.popup ();
            });
        }

        public void set_frosted (bool enabled) {
            button.frosted = enabled;
            if (enabled) {
                button.remove_css_class ("reduce-transparency");
            } else {
                button.add_css_class ("reduce-transparency");
            }
            button.queue_draw ();
        }

        private void setup_popover () {
            popover = new Popover ();
            popover.set_parent (button);
            popover.add_css_class ("system-flyout-popover");
            popover.position = PositionType.BOTTOM;

            var box = new Box (Orientation.VERTICAL, 4);
            box.margin_start = 6;
            box.margin_end = 6;
            box.margin_top = 6;
            box.margin_bottom = 6;

            var header_label = new Label ("Система");
            header_label.add_css_class ("system-flyout-title");
            header_label.halign = Align.START;
            box.append (header_label);

            var sep = new Separator (Orientation.HORIZONTAL);
            box.append (sep);

            // 1. Settings / Switchboard
            box.append (create_item ("preferences-system-symbolic", "Параметры системы", () => {
                execute_cmd ("io.elementary.switchboard || gnome-control-center || systemsettings");
            }));

            // 2. Lock screen
            box.append (create_item ("changes-prevent-symbolic", "Заблокировать экран", () => {
                execute_cmd ("loginctl lock-session || dbus-send --type=method_call --dest=org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver.Lock");
            }));

            // 3. Log out
            box.append (create_item ("system-log-out-symbolic", "Завершить сеанс", () => {
                execute_cmd ("gnome-session-quit --logout || io.elementary.wingpanel --toggle-indicator=session || loginctl terminate-session ${XDG_SESSION_ID:-self}");
            }));

            // 4. Reboot
            box.append (create_item ("system-reboot-symbolic", "Перезагрузка", () => {
                execute_cmd ("systemctl reboot || gnome-session-quit --reboot");
            }));

            // 5. Power off
            box.append (create_item ("system-shutdown-symbolic", "Выключить", () => {
                execute_cmd ("systemctl poweroff || gnome-session-quit --power-off");
            }));

            popover.set_child (box);
        }

        private Button create_item (string icon_name, string title, owned ActionCallback cb) {
            var item_btn = new Button ();
            item_btn.add_css_class ("system-flyout-item");

            var row = new Box (Orientation.HORIZONTAL, 10);
            var icon = new Image.from_icon_name (icon_name);
            icon.pixel_size = 16;
            var lbl = new Label (title);
            lbl.halign = Align.START;

            row.append (icon);
            row.append (lbl);
            item_btn.set_child (row);

            item_btn.clicked.connect (() => {
                popover.popdown ();
                action_triggered ();
                cb ();
            });

            return item_btn;
        }

        public bool is_popover_open () {
            return popover != null && popover.visible;
        }

        private void execute_cmd (string cmd) {
            try {
                string[] argv = { "sh", "-c", cmd };
                Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
            } catch (Error e) {
                warning ("Failed to execute command: %s", e.message);
            }
        }

        public delegate void ActionCallback ();
    }
}
