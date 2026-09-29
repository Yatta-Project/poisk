using Gtk;
using Vicinae.Core;

namespace Vicinae.UI {

    public class ResultRow : ListBoxRow {
        public SearchItem item { get; private set; }

        private Image icon_img;
        private Label title_lbl;
        private Label subtitle_lbl;
        private Label badge_lbl;

        public ResultRow (SearchItem item) {
            this.item = item;
            this.add_css_class ("vicinae-result-row");

            var main_box = new Box (Orientation.HORIZONTAL, 12);
            main_box.margin_start = 12;
            main_box.margin_end = 12;
            main_box.margin_top = 8;
            main_box.margin_bottom = 8;

            // Icon
            icon_img = new Image.from_icon_name (item.icon_name);
            icon_img.pixel_size = 28;
            main_box.append (icon_img);

            // Text Box (Title + Subtitle)
            var text_box = new Box (Orientation.VERTICAL, 2);
            text_box.hexpand = true;

            title_lbl = new Label (item.title);
            title_lbl.halign = Align.START;
            title_lbl.ellipsize = Pango.EllipsizeMode.END;
            title_lbl.add_css_class ("heading");
            text_box.append (title_lbl);

            subtitle_lbl = new Label (item.subtitle);
            subtitle_lbl.halign = Align.START;
            subtitle_lbl.ellipsize = Pango.EllipsizeMode.END;
            subtitle_lbl.add_css_class ("dim-label");
            subtitle_lbl.add_css_class ("caption");
            text_box.append (subtitle_lbl);

            main_box.append (text_box);

            // Badge / Category pill
            badge_lbl = new Label (item.category);
            badge_lbl.valign = Align.CENTER;
            badge_lbl.add_css_class ("dim-label");
            badge_lbl.add_css_class ("caption");
            main_box.append (badge_lbl);

            this.set_child (main_box);
        }
    }
}
