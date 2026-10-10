using Gtk;
using Poisk.Core;

namespace Poisk.UI {

    public class PreviewPane : Box {
        private Image icon_img;
        private Label title_lbl;
        private Label category_lbl;
        private Label preview_lbl;
        private Label action_lbl;
        private ScrolledWindow scroll;

        public PreviewPane () {
            Object (orientation: Orientation.VERTICAL, spacing: 16);
            this.add_css_class ("vicinae-preview-pane");
            this.width_request = 260;
            this.margin_start = 16;
            this.margin_end = 16;
            this.margin_top = 16;
            this.margin_bottom = 16;

            // Header (Icon + Title)
            var header_box = new Box (Orientation.VERTICAL, 8);
            header_box.halign = Align.CENTER;

            icon_img = new Image.from_icon_name ("system-run");
            icon_img.pixel_size = 56;
            icon_img.add_css_class ("vicinae-preview-icon");
            header_box.append (icon_img);

            title_lbl = new Label ("");
            title_lbl.add_css_class ("title-3");
            title_lbl.wrap = true;
            title_lbl.justify = Justification.CENTER;
            header_box.append (title_lbl);

            category_lbl = new Label ("");
            category_lbl.add_css_class ("dim-label");
            category_lbl.add_css_class ("caption");
            header_box.append (category_lbl);

            this.append (header_box);

            var sep = new Separator (Orientation.HORIZONTAL);
            this.append (sep);

            // Preview Scroll area
            scroll = new ScrolledWindow ();
            scroll.vexpand = true;
            scroll.hexpand = true;
            scroll.hscrollbar_policy = PolicyType.NEVER;

            preview_lbl = new Label ("");
            preview_lbl.wrap = true;
            preview_lbl.use_markup = false;
            preview_lbl.halign = Align.START;
            preview_lbl.valign = Align.START;
            preview_lbl.xalign = 0.0f;
            preview_lbl.selectable = true;
            scroll.set_child (preview_lbl);

            this.append (scroll);

            // Bottom action hint
            action_lbl = new Label ("");
            action_lbl.add_css_class ("caption");
            action_lbl.add_css_class ("dim-label");
            action_lbl.halign = Align.END;
            this.append (action_lbl);
        }

        public void set_item (SearchItem? item) {
            update (item);
        }

        public void update (SearchItem? item) {
            if (item == null) {
                this.visible = false;
                return;
            }

            this.visible = true;
            var paintable = ResultRow.get_cached_icon (item.icon_name, 56);
            if (paintable != null) {
                icon_img.set_from_paintable (paintable);
            } else if (item.icon_name.has_prefix ("/") && FileUtils.test (item.icon_name, FileTest.EXISTS)) {
                icon_img.set_from_file (item.icon_name);
            } else {
                icon_img.set_from_icon_name (item.icon_name);
            }
            title_lbl.set_text (item.title);
            category_lbl.set_text (item.category);

            if (item.preview_text.length > 0) {
                try {
                    Pango.AttrList attr_list;
                    string plain_text;
                    Pango.parse_markup (item.preview_text, -1, 0, out attr_list, out plain_text, null);
                    preview_lbl.set_text (plain_text);
                    preview_lbl.set_attributes (attr_list);
                } catch (GLib.Error e) {
                    preview_lbl.set_attributes (null);
                    preview_lbl.set_text (item.preview_text);
                }
            } else {
                preview_lbl.set_attributes (null);
                preview_lbl.set_text (item.subtitle);
            }

            action_lbl.set_text ("↵ %s".printf (item.action_label));
        }
    }
}
