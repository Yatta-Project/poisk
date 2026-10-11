using Gtk;

namespace Poisk.UI {

    public class SatelliteButton : Button {
        private Image icon_image;
        private string current_icon_name;
        public bool frosted { get; set; default = false; }
        public double blur_radius { get; set; default = 20.0; }
        public float corner_radius { get; set; default = 16.0f; }

        public SatelliteButton (string icon_name, string? tooltip = null) {
            Object ();
            this.current_icon_name = icon_name;

            this.add_css_class ("satellite-bubble");
            this.set_size_request (54, 54);
            this.valign = Align.START;
            this.halign = Align.CENTER;

            if (tooltip != null) {
                this.tooltip_text = tooltip;
            }

            icon_image = new Image.from_icon_name (icon_name);
            icon_image.pixel_size = 26;
            this.set_child (icon_image);
        }

        public new void set_icon_name (string icon_name) {
            this.current_icon_name = icon_name;
            icon_image.set_from_icon_name (icon_name);
        }

        public void set_animated_class (string? css_class) {
            this.remove_css_class ("spin");
            this.remove_css_class ("bounce");
            this.remove_css_class ("pulse");

            if (css_class != null && css_class.length > 0) {
                this.add_css_class (css_class);
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot) {
            base.snapshot (snapshot);
        }
    }
}
