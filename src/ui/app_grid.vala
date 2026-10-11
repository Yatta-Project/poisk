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
        private FadingBox fading_box;
        private Box content_box;
        private List<AppGridItem> all_cards = new List<AppGridItem> ();
        private int selected_card_index = -1;
        private GLib.Settings? poisk_settings = null;

        public signal void item_activated (SearchItem item);

        public AppGrid () {
            Object (orientation: Orientation.VERTICAL, spacing: 0);
            this.hexpand = true;
            this.vexpand = true;

            var schema_source = SettingsSchemaSource.get_default ();
            if (schema_source != null && schema_source.lookup ("io.github.mrlogiousbanana.poisk", true) != null) {
                poisk_settings = new GLib.Settings ("io.github.mrlogiousbanana.poisk");
            }

            scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.hexpand = true;
            scroll.vexpand = true;

            content_box = new Box (Orientation.VERTICAL, 12);
            content_box.hexpand = true;
            content_box.margin_top = 8;
            content_box.margin_bottom = 16;
            content_box.margin_start = 12;
            content_box.margin_end = 12;

            scroll.set_child (content_box);

            fading_box = new FadingBox (Orientation.VERTICAL, 0);
            fading_box.attach_scrolled_window (scroll);
            fading_box.append (scroll);
            this.append (fading_box);
        }

        private FlowBox create_flow_box () {
            var fb = new FlowBox ();
            fb.selection_mode = SelectionMode.SINGLE;
            fb.max_children_per_line = 6;
            fb.min_children_per_line = 5;
            fb.homogeneous = true;
            fb.column_spacing = 10;
            fb.row_spacing = 10;
            fb.halign = Align.START;
            fb.valign = Align.START;
            fb.margin_start = 14;
            fb.margin_end = 14;

            fb.child_activated.connect ((child) => {
                if (child is AppGridItem) {
                    var card = (AppGridItem) child;
                    item_activated (card.item);
                }
            });

            return fb;
        }

        public void set_items (List<SearchItem> items) {
            fading_box.reset_scroll ();
            all_cards = new List<AppGridItem> ();
            selected_card_index = -1;

            // Clear previous widgets
            Widget? child = content_box.get_first_child ();
            while (child != null) {
                Widget? next = child.get_next_sibling ();
                content_box.remove (child);
                child = next;
            }

            bool group_in_menu = true;
            if (poisk_settings != null) {
                group_in_menu = poisk_settings.get_boolean ("group-apps-in-menu");
            }

            var group_manager = AppGroupManager.get_default ();

            if (!group_in_menu) {
                // Flat mode without category headers
                var flow_box = create_flow_box ();

                foreach (var item in items) {
                    var card = new AppGridItem (item);
                    flow_box.append (card);
                    all_cards.append (card);
                }
                content_box.append (flow_box);
            } else {
                // Grouped mode: iterate over configured groups
                var groups = group_manager.get_groups ();
                var processed_items = new HashTable<string, bool> (str_hash, str_equal);

                foreach (var g in groups) {
                    if (g.is_hidden) continue;

                    var group_items = new List<SearchItem> ();
                    foreach (var item in items) {
                        string gid = group_manager.get_app_group_id (item.id);
                        if (gid == g.id) {
                            group_items.append (item);
                            processed_items.insert (item.id, true);
                        }
                    }

                    if (group_items.length () > 0) {
                        // Group Section Header with clean separator
                        var header_box = new Box (Orientation.HORIZONTAL, 8);
                        header_box.margin_start = 14;
                        header_box.margin_end = 14;
                        header_box.margin_top = 16;
                        header_box.margin_bottom = 6;
                        header_box.valign = Align.CENTER;

                        // Emoji label
                        string em = g.emoji.strip ();
                        if (em.length > 0) {
                            var emoji_lbl = new Label (em);
                            emoji_lbl.add_css_class ("poisk-category-emoji");
                            header_box.append (emoji_lbl);
                        }

                        // Title label (bold, larger)
                        var title = new Label (g.name);
                        title.add_css_class ("poisk-category-title");
                        header_box.append (title);

                        // Separator line: Рабочие ------------------------------------
                        var sep = new Separator (Orientation.HORIZONTAL);
                        sep.hexpand = true;
                        sep.valign = Align.CENTER;
                        sep.add_css_class ("poisk-category-separator");
                        header_box.append (sep);

                        content_box.append (header_box);

                        // Grid for this group
                        var flow_box = create_flow_box ();
                        foreach (var item in group_items) {
                            var card = new AppGridItem (item);
                            flow_box.append (card);
                            all_cards.append (card);
                        }
                        content_box.append (flow_box);
                    }
                }

                // Any leftover items not matched in existing groups
                var leftover = new List<SearchItem> ();
                foreach (var item in items) {
                    if (!processed_items.contains (item.id)) {
                        leftover.append (item);
                    }
                }
                if (leftover.length () > 0) {
                    var flow_box = create_flow_box ();
                    foreach (var item in leftover) {
                        var card = new AppGridItem (item);
                        flow_box.append (card);
                        all_cards.append (card);
                    }
                    content_box.append (flow_box);
                }
            }

            if (all_cards.length () > 0) {
                select_index (0);
            }
        }

        private void select_index (int idx) {
            if (idx < 0 || idx >= (int) all_cards.length ()) return;

            // Unselect previous
            if (selected_card_index >= 0 && selected_card_index < (int) all_cards.length ()) {
                var prev_card = all_cards.nth_data (selected_card_index);
                var prev_fb = prev_card.get_parent () as FlowBox;
                if (prev_fb != null) {
                    prev_fb.unselect_child (prev_card);
                }
            }

            selected_card_index = idx;
            var curr_card = all_cards.nth_data (selected_card_index);
            var curr_fb = curr_card.get_parent () as FlowBox;
            if (curr_fb != null) {
                curr_fb.select_child (curr_card);
                fading_box.scroll_to_child (curr_card);
            }
        }

        public void select_next () {
            if (all_cards.length () == 0) return;
            int next = (selected_card_index < 0) ? 0 : selected_card_index + 1;
            if (next < (int) all_cards.length ()) {
                select_index (next);
            }
        }

        public void select_prev () {
            if (all_cards.length () == 0) return;
            int prev = (selected_card_index <= 0) ? 0 : selected_card_index - 1;
            select_index (prev);
        }

        public void select_down () {
            if (all_cards.length () == 0) return;
            int next = (selected_card_index < 0) ? 0 : selected_card_index + 5;
            if (next >= (int) all_cards.length ()) {
                next = (int) all_cards.length () - 1;
            }
            select_index (next);
        }

        public void select_up () {
            if (all_cards.length () == 0) return;
            int prev = (selected_card_index < 0) ? 0 : selected_card_index - 5;
            if (prev < 0) prev = 0;
            select_index (prev);
        }

        public void activate_selected () {
            if (selected_card_index >= 0 && selected_card_index < (int) all_cards.length ()) {
                var card = all_cards.nth_data (selected_card_index);
                item_activated (card.item);
            }
        }
    }
}
