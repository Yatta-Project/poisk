using Gtk;

namespace Poisk.UI {

    public class GlancePill : Button {
        private Box content_box;
        private Label icon_label;
        private Image icon_image;
        private Label title_label;
        private Label badge_label;

        public delegate void ActionCallback ();
        private ActionCallback? action_cb = null;

        public signal void activated ();

        public bool has_action {
            get { return action_cb != null; }
        }

        public GlancePill () {
            Object ();

            this.add_css_class ("poisk-glance-pill");
            this.valign = Align.CENTER;
            this.halign = Align.END;
            this.cursor = new Gdk.Cursor.from_name ("pointer", null);

            content_box = new Box (Orientation.HORIZONTAL, 6);
            content_box.valign = Align.CENTER;
            content_box.halign = Align.CENTER;

            icon_label = new Label ("");
            icon_label.add_css_class ("glance-icon-emoji");
            icon_label.visible = false;

            icon_image = new Image ();
            icon_image.pixel_size = 14;
            icon_image.add_css_class ("glance-icon-image");
            icon_image.visible = false;

            title_label = new Label ("");
            title_label.add_css_class ("glance-title");
            title_label.ellipsize = Pango.EllipsizeMode.END;
            title_label.max_width_chars = 36;

            badge_label = new Label ("↵");
            badge_label.add_css_class ("glance-key-badge");

            content_box.append (icon_label);
            content_box.append (icon_image);
            content_box.append (title_label);
            content_box.append (badge_label);

            this.set_child (content_box);

            this.clicked.connect (() => {
                execute_action ();
            });
        }

        public void set_glance (string? icon_name, string? emoji, string text, owned ActionCallback? cb = null) {
            action_cb = (owned) cb;
            title_label.label = text;

            if (emoji != null && emoji.length > 0) {
                icon_label.label = emoji;
                icon_label.visible = true;
                icon_image.visible = false;
            } else if (icon_name != null && icon_name.length > 0) {
                icon_image.icon_name = icon_name;
                icon_image.visible = true;
                icon_label.visible = false;
            } else {
                icon_label.visible = false;
                icon_image.visible = false;
            }
        }

        public void execute_action () {
            if (action_cb != null) {
                action_cb ();
                activated ();
            }
        }
    }
}
