using Gtk;

namespace Poisk.UI {

    public class SystemBubble : Box {
        public enum DisplayMode {
            STANDALONE,
            EMBEDDED
        }

        private SatelliteButton standalone_button;
        private Image embedded_image;
        private Box embedded_box;
        private string system_logo_name;
        private DisplayMode current_mode = DisplayMode.STANDALONE;

        public SystemBubble (DisplayMode mode = DisplayMode.STANDALONE) {
            Object (orientation: Orientation.HORIZONTAL, spacing: 0);

            system_logo_name = resolve_system_logo ();

            // 1. Standalone satellite squircle (54x54)
            standalone_button = new SatelliteButton (system_logo_name, null);
            standalone_button.add_css_class ("system-bubble-btn");
            standalone_button.frosted = true;
            standalone_button.can_focus = false;
            standalone_button.can_target = false; // Purely decorative, no click action

            // 2. Embedded compact icon (for monolithic capsule)
            embedded_box = new Box (Orientation.HORIZONTAL, 0);
            embedded_box.add_css_class ("embedded-system-bubble");
            embedded_box.valign = Align.CENTER;
            embedded_box.halign = Align.CENTER;
            embedded_box.set_size_request (24, 24);

            embedded_image = new Image.from_icon_name (system_logo_name);
            embedded_image.pixel_size = 24;
            embedded_image.set_size_request (24, 24);
            embedded_image.halign = Align.CENTER;
            embedded_image.valign = Align.CENTER;
            embedded_box.append (embedded_image);

            set_mode (mode);
        }

        private string resolve_system_logo () {
            var icon_theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            if (icon_theme.has_icon ("nix-snowflake")) {
                return "nix-snowflake";
            } else if (icon_theme.has_icon ("distributor-logo-pantheon")) {
                return "distributor-logo-pantheon";
            } else if (icon_theme.has_icon ("distributor-logo")) {
                return "distributor-logo";
            } else if (icon_theme.has_icon ("fedora-logo-icon")) {
                return "fedora-logo-icon";
            } else if (icon_theme.has_icon ("fedora-logo")) {
                return "fedora-logo";
            }
            return "preferences-system";
        }

        public void set_mode (DisplayMode mode) {
            current_mode = mode;
            if (standalone_button.get_parent () != null) {
                this.remove (standalone_button);
            }
            if (embedded_box.get_parent () != null) {
                this.remove (embedded_box);
            }

            if (mode == DisplayMode.STANDALONE) {
                this.valign = Align.START;
                this.set_size_request (-1, -1);
                this.append (standalone_button);
            } else {
                this.valign = Align.CENTER;
                this.set_size_request (56, 56);
                this.append (embedded_box);
            }
        }

        public void set_frosted (bool enabled) {
            standalone_button.frosted = enabled;
            if (enabled) {
                standalone_button.remove_css_class ("reduce-transparency");
                embedded_box.remove_css_class ("reduce-transparency");
            } else {
                standalone_button.add_css_class ("reduce-transparency");
                embedded_box.add_css_class ("reduce-transparency");
            }
            standalone_button.queue_draw ();
            embedded_box.queue_draw ();
        }
    }
}
