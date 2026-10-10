using Gtk;
using Poisk.Core;

namespace Poisk.UI {

    public class AppGridItem : FlowBoxChild {
        public SearchItem item { get; private set; }

        public AppGridItem (SearchItem item) {
            this.item = item;
            this.add_css_class ("vicinae-grid-card");

            var box = new Box (Orientation.VERTICAL, 6);
            box.halign = Align.CENTER;
            box.valign = Align.CENTER;
            box.margin_top = 8;
            box.margin_bottom = 8;
            box.margin_start = 6;
            box.margin_end = 6;

            Image icon_img;
            var paintable = ResultRow.get_cached_icon (item.icon_name, 48);
            if (paintable != null) {
                icon_img = new Image.from_paintable (paintable);
            } else if (item.icon_name.has_prefix ("/") && FileUtils.test (item.icon_name, FileTest.EXISTS)) {
                icon_img = new Image.from_file (item.icon_name);
            } else {
                icon_img = new Image.from_icon_name (item.icon_name);
            }
            icon_img.pixel_size = 48;
            icon_img.add_css_class ("vicinae-grid-icon");
            box.append (icon_img);

            var label = new Label (item.title);
            label.add_css_class ("caption");
            label.max_width_chars = 11;
            label.ellipsize = Pango.EllipsizeMode.END;
            label.justify = Justification.CENTER;
            label.wrap = false;
            box.append (label);

            this.set_child (box);
        }
    }

    public class AppGrid : Box {
        private ScrolledWindow scroll;
        private FlowBox flow_box;
        public signal void item_activated (SearchItem item);

        public AppGrid () {
            Object (orientation: Orientation.VERTICAL, spacing: 0);
            this.hexpand = true;
            this.vexpand = true;

            scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.hexpand = true;
            scroll.vexpand = true;

            flow_box = new FlowBox ();
            flow_box.selection_mode = SelectionMode.SINGLE;
            flow_box.max_children_per_line = 6;
            flow_box.min_children_per_line = 5;
            flow_box.homogeneous = true;
            flow_box.column_spacing = 10;
            flow_box.row_spacing = 10;
            flow_box.margin_start = 16;
            flow_box.margin_end = 16;
            flow_box.margin_top = 12;
            flow_box.margin_bottom = 16;
            flow_box.halign = Align.CENTER;
            flow_box.valign = Align.START;

            flow_box.child_activated.connect ((child) => {
                if (child is AppGridItem) {
                    var card = (AppGridItem) child;
                    item_activated (card.item);
                }
            });

            scroll.set_child (flow_box);
            this.append (scroll);
        }

        public void set_items (List<SearchItem> items) {
            Widget? child = flow_box.get_first_child ();
            while (child != null) {
                Widget? next = child.get_next_sibling ();
                flow_box.remove (child);
                child = next;
            }

            foreach (var item in items) {
                var card = new AppGridItem (item);
                flow_box.append (card);
            }

            var first = flow_box.get_child_at_index (0);
            if (first != null) {
                flow_box.select_child (first);
            }
        }

        public void select_next () {
            var selected = flow_box.get_selected_children ();
            int idx = 0;
            if (selected != null && selected.data != null) {
                idx = ((FlowBoxChild) selected.data).get_index () + 1;
            }
            var next = flow_box.get_child_at_index (idx);
            if (next != null) {
                flow_box.select_child (next);
            }
        }

        public void select_prev () {
            var selected = flow_box.get_selected_children ();
            if (selected != null && selected.data != null) {
                int idx = ((FlowBoxChild) selected.data).get_index () - 1;
                if (idx >= 0) {
                    var prev = flow_box.get_child_at_index (idx);
                    if (prev != null) {
                        flow_box.select_child (prev);
                    }
                }
            }
        }

        public void select_down () {
            var selected = flow_box.get_selected_children ();
            int idx = 0;
            if (selected != null && selected.data != null) {
                idx = ((FlowBoxChild) selected.data).get_index () + 5;
            }
            var next = flow_box.get_child_at_index (idx);
            if (next != null) {
                flow_box.select_child (next);
            }
        }

        public void select_up () {
            var selected = flow_box.get_selected_children ();
            if (selected != null && selected.data != null) {
                int idx = ((FlowBoxChild) selected.data).get_index () - 5;
                if (idx >= 0) {
                    var prev = flow_box.get_child_at_index (idx);
                    if (prev != null) {
                        flow_box.select_child (prev);
                    }
                }
            }
        }

        public void activate_selected () {
            var selected = flow_box.get_selected_children ();
            if (selected != null && selected.data != null) {
                var child = (FlowBoxChild) selected.data;
                if (child is AppGridItem) {
                    var card = (AppGridItem) child;
                    item_activated (card.item);
                }
            }
        }
    }
}
