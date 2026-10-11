using Gtk;
using Adw;
using Poisk.Core;

namespace Poisk.UI {

    public class GroupManagerDialog : Adw.Window {
        private AppGroupManager group_manager;
        private Box groups_container;
        private SearchEntry search_entry;
        private string search_filter = "";
        private List<AppInfo> all_apps = new List<AppInfo> ();

        public GroupManagerDialog (Gtk.Window? parent = null) {
            Object (
                title: "Управление группами приложений",
                transient_for: parent,
                modal: true,
                default_width: 720,
                default_height: 640
            );

            group_manager = AppGroupManager.get_default ();
            load_installed_apps ();

            var main_box = new Box (Orientation.VERTICAL, 0);

            // Header Bar
            var header = new Adw.HeaderBar ();
            var add_btn = new Button.with_label ("+ Новая группа");
            add_btn.add_css_class ("suggested-action");
            add_btn.clicked.connect (on_add_group_clicked);
            header.pack_start (add_btn);
            main_box.append (header);

            // Filter Bar
            var filter_box = new Box (Orientation.HORIZONTAL, 12);
            filter_box.margin_start = 16;
            filter_box.margin_end = 16;
            filter_box.margin_top = 10;
            filter_box.margin_bottom = 10;

            search_entry = new SearchEntry ();
            search_entry.hexpand = true;
            search_entry.placeholder_text = "Фильтр приложений по имени...";
            search_entry.search_changed.connect (() => {
                search_filter = search_entry.get_text ().strip ().down ();
                refresh_groups ();
            });
            filter_box.append (search_entry);

            main_box.append (filter_box);

            // Scrolled Window with Groups
            var scroll = new ScrolledWindow ();
            scroll.hexpand = true;
            scroll.vexpand = true;

            groups_container = new Box (Orientation.VERTICAL, 16);
            groups_container.margin_start = 16;
            groups_container.margin_end = 16;
            groups_container.margin_top = 6;
            groups_container.margin_bottom = 24;

            scroll.set_child (groups_container);
            main_box.append (scroll);

            this.set_content (main_box);

            group_manager.changed.connect (refresh_groups);
            refresh_groups ();
        }

        private void load_installed_apps () {
            all_apps = new List<AppInfo> ();
            var apps = AppInfo.get_all ();
            foreach (var app in apps) {
                if (app.should_show ()) {
                    all_apps.append (app);
                }
            }
            all_apps.sort ((a, b) => {
                string an = a.get_display_name () ?? a.get_name () ?? "";
                string bn = b.get_display_name () ?? b.get_name () ?? "";
                return an.collate (bn);
            });
        }

        private void refresh_groups () {
            // Clear current list
            Widget? child = groups_container.get_first_child ();
            while (child != null) {
                Widget? next = child.get_next_sibling ();
                groups_container.remove (child);
                child = next;
            }

            var groups = group_manager.get_groups ();
            int total_groups = (int) groups.length ();

            for (int i = 0; i < total_groups; i++) {
                var g = groups.nth_data (i);
                var card = build_group_card (g, i, total_groups);
                groups_container.append (card);
            }
        }

        private Widget build_group_card (AppGroup group, int index, int total_count) {
            var card = new Box (Orientation.VERTICAL, 8);
            card.add_css_class ("card");
            card.margin_bottom = 4;

            // Header Box
            var header_box = new Box (Orientation.HORIZONTAL, 10);
            header_box.margin_start = 14;
            header_box.margin_end = 14;
            header_box.margin_top = 10;
            header_box.margin_bottom = 8;
            header_box.valign = Align.CENTER;

            // Drag handle for group
            var handle_icon = new Image.from_icon_name ("view-more-horizontal-symbolic");
            handle_icon.pixel_size = 16;
            handle_icon.opacity = 0.50;
            header_box.append (handle_icon);

            // Group Icon
            var group_icon = new Image.from_icon_name (group.icon_name);
            group_icon.pixel_size = 20;
            if (group.is_hidden) {
                group_icon.add_css_class ("error");
            }
            header_box.append (group_icon);

            // Title
            var title_lbl = new Label (group.name);
            title_lbl.add_css_class ("heading");
            title_lbl.hexpand = true;
            title_lbl.halign = Align.START;
            header_box.append (title_lbl);

            // Count badge
            int app_count = count_apps_in_group (group.id);
            var count_badge = new Label ("%d прил.".printf (app_count));
            count_badge.add_css_class ("dim-label");
            count_badge.add_css_class ("caption");
            header_box.append (count_badge);

            // Action buttons
            var btn_box = new Box (Orientation.HORIZONTAL, 4);

            if (!group.is_hidden) {
                // Move Up button
                var up_btn = new Button.from_icon_name ("go-up-symbolic");
                up_btn.add_css_class ("flat");
                up_btn.tooltip_text = "Поднять группу выше";
                up_btn.sensitive = (index > 0);
                up_btn.clicked.connect (() => {
                    group_manager.move_group_up (group.id);
                });
                btn_box.append (up_btn);

                // Move Down button
                var down_btn = new Button.from_icon_name ("go-down-symbolic");
                down_btn.add_css_class ("flat");
                down_btn.tooltip_text = "Опустить группу ниже";
                down_btn.sensitive = (index < total_count - 2); // Do not move below Hidden
                down_btn.clicked.connect (() => {
                    group_manager.move_group_down (group.id);
                });
                btn_box.append (down_btn);
            }

            // Custom group actions (rename / delete)
            if (!group.is_default && !group.is_hidden) {
                var edit_btn = new Button.from_icon_name ("document-edit-symbolic");
                edit_btn.add_css_class ("flat");
                edit_btn.tooltip_text = "Переименовать группу";
                edit_btn.clicked.connect (() => {
                    prompt_rename_group (group);
                });
                btn_box.append (edit_btn);

                var del_btn = new Button.from_icon_name ("user-trash-symbolic");
                del_btn.add_css_class ("flat");
                del_btn.add_css_class ("destructive-action");
                del_btn.tooltip_text = "Удалить группу";
                del_btn.clicked.connect (() => {
                    group_manager.delete_group (group.id);
                });
                btn_box.append (del_btn);
            }

            header_box.append (btn_box);
            card.append (header_box);

            // Separator
            var sep = new Separator (Orientation.HORIZONTAL);
            card.append (sep);

            // Apps list in this group
            var apps_flow = new FlowBox ();
            apps_flow.selection_mode = SelectionMode.NONE;
            apps_flow.max_children_per_line = 3;
            apps_flow.min_children_per_line = 1;
            apps_flow.column_spacing = 8;
            apps_flow.row_spacing = 6;
            apps_flow.margin_start = 12;
            apps_flow.margin_end = 12;
            apps_flow.margin_top = 8;
            apps_flow.margin_bottom = 12;

            int rendered_apps = 0;
            foreach (unowned AppInfo app in all_apps) {
                string app_id = app.get_id () ?? app.get_name () ?? "";
                string assigned_group = group_manager.get_app_group_id (app_id);

                if (assigned_group == group.id) {
                    string name = app.get_display_name () ?? app.get_name () ?? "";
                    if (search_filter.length > 0 && !name.down ().contains (search_filter)) {
                        continue;
                    }

                    var app_pill = build_app_item (app, group.id);
                    apps_flow.append (app_pill);
                    rendered_apps++;
                }
            }

            if (rendered_apps == 0) {
                var empty_lbl = new Label (search_filter.length > 0 ? "Нет совпадений по фильтру" : "Перетащите сюда приложения или назначьте через кнопку");
                empty_lbl.add_css_class ("dim-label");
                empty_lbl.add_css_class ("caption");
                empty_lbl.margin_top = 8;
                empty_lbl.margin_bottom = 8;
                card.append (empty_lbl);
            } else {
                card.append (apps_flow);
            }

            // Setup Drop Target on Group Card
            var drop_target = new DropTarget (typeof (string), Gdk.DragAction.MOVE);
            drop_target.drop.connect ((val, x, y) => {
                string data = val.get_string ();
                if (data.has_prefix ("app:")) {
                    string dropped_app_id = data.substring (4);
                    group_manager.set_app_group (dropped_app_id, group.id);
                    return true;
                } else if (data.has_prefix ("group:")) {
                    string dragged_gid = data.substring (6);
                    if (dragged_gid != group.id && !group.is_hidden) {
                        // Reorder groups
                        var current_groups = group_manager.get_groups ();
                        int from_idx = -1;
                        int to_idx = -1;
                        for (int k = 0; k < current_groups.length (); k++) {
                            if (current_groups.nth_data (k).id == dragged_gid) from_idx = k;
                            if (current_groups.nth_data (k).id == group.id) to_idx = k;
                        }
                        if (from_idx >= 0 && to_idx >= 0) {
                            if (from_idx < to_idx) {
                                for (int s = from_idx; s < to_idx; s++) {
                                    group_manager.move_group_down (dragged_gid);
                                }
                            } else {
                                for (int s = from_idx; s > to_idx; s--) {
                                    group_manager.move_group_up (dragged_gid);
                                }
                            }
                        }
                        return true;
                    }
                }
                return false;
            });
            card.add_controller (drop_target);

            // Group Header DragSource (drag group to reorder)
            if (!group.is_hidden) {
                var group_drag_source = new DragSource ();
                group_drag_source.actions = Gdk.DragAction.MOVE;
                group_drag_source.prepare.connect ((x, y) => {
                    Value val = "group:" + group.id;
                    return new Gdk.ContentProvider.for_value (val);
                });
                header_box.add_controller (group_drag_source);
            }

            return card;
        }

        private Widget build_app_item (AppInfo app, string current_group_id) {
            string app_id = app.get_id () ?? app.get_name () ?? "";
            string name = app.get_display_name () ?? app.get_name () ?? "";

            var item_box = new Box (Orientation.HORIZONTAL, 6);
            item_box.add_css_class ("card");
            item_box.margin_start = 2;
            item_box.margin_end = 2;
            item_box.margin_top = 2;
            item_box.margin_bottom = 2;
            item_box.valign = Align.CENTER;

            // Icon
            string icon_name = "application-x-executable";
            var icon = app.get_icon ();
            if (icon != null) {
                icon_name = icon.to_string ();
            }
            var paintable = ResultRow.get_cached_icon (icon_name, 22);
            Image img;
            if (paintable != null) {
                img = new Image.from_paintable (paintable);
            } else {
                img = new Image.from_icon_name (icon_name);
            }
            img.pixel_size = 22;
            img.margin_start = 6;
            item_box.append (img);

            // Label
            var lbl = new Label (name);
            lbl.ellipsize = Pango.EllipsizeMode.END;
            lbl.max_width_chars = 18;
            lbl.hexpand = true;
            lbl.halign = Align.START;
            lbl.add_css_class ("caption");
            item_box.append (lbl);

            // Quick Move MenuButton
            var menu_btn = new MenuButton ();
            menu_btn.icon_name = "view-more-symbolic";
            menu_btn.add_css_class ("flat");
            menu_btn.tooltip_text = "Переместить в другую группу...";

            var popover = new Popover ();
            var popover_box = new Box (Orientation.VERTICAL, 4);
            popover_box.margin_start = 6;
            popover_box.margin_end = 6;
            popover_box.margin_top = 6;
            popover_box.margin_bottom = 6;

            foreach (var target_g in group_manager.get_groups ()) {
                if (target_g.id == current_group_id) continue;

                var btn = new Button.with_label (target_g.name);
                btn.add_css_class ("flat");
                string tid = target_g.id;
                btn.clicked.connect (() => {
                    popover.popdown ();
                    group_manager.set_app_group (app_id, tid);
                });
                popover_box.append (btn);
            }

            popover.set_child (popover_box);
            menu_btn.set_popover (popover);
            item_box.append (menu_btn);

            // DragSource for App
            var drag_source = new DragSource ();
            drag_source.actions = Gdk.DragAction.MOVE;
            drag_source.prepare.connect ((x, y) => {
                Value val = "app:" + app_id;
                return new Gdk.ContentProvider.for_value (val);
            });
            item_box.add_controller (drag_source);

            return item_box;
        }

        private int count_apps_in_group (string group_id) {
            int count = 0;
            foreach (unowned AppInfo app in all_apps) {
                string app_id = app.get_id () ?? app.get_name () ?? "";
                if (group_manager.get_app_group_id (app_id) == group_id) {
                    count++;
                }
            }
            return count;
        }

        private void on_add_group_clicked () {
            var dialog = new Adw.MessageDialog (this, "Новая группа приложений", "Введите название для новой группы:");
            dialog.add_response ("cancel", "Отмена");
            dialog.add_response ("create", "Создать");
            dialog.set_response_appearance ("create", Adw.ResponseAppearance.SUGGESTED);

            var entry = new Entry ();
            entry.placeholder_text = "Например: Разработка, Игры, Учёба";
            entry.margin_top = 10;
            entry.margin_bottom = 10;
            entry.activate.connect (() => {
                dialog.response ("create");
            });
            dialog.set_extra_child (entry);

            dialog.response.connect ((resp) => {
                if (resp == "create") {
                    string text = entry.get_text ().strip ();
                    if (text.length > 0) {
                        group_manager.add_group (text);
                    }
                }
            });

            dialog.present ();
        }

        private void prompt_rename_group (AppGroup group) {
            var dialog = new Adw.MessageDialog (this, "Переименование группы", "Введите новое название для группы «%s»:".printf (group.name));
            dialog.add_response ("cancel", "Отмена");
            dialog.add_response ("save", "Сохранить");
            dialog.set_response_appearance ("save", Adw.ResponseAppearance.SUGGESTED);

            var entry = new Entry ();
            entry.text = group.name;
            entry.margin_top = 10;
            entry.margin_bottom = 10;
            entry.activate.connect (() => {
                dialog.response ("save");
            });
            dialog.set_extra_child (entry);

            dialog.response.connect ((resp) => {
                if (resp == "save") {
                    string text = entry.get_text ().strip ();
                    if (text.length > 0) {
                        group_manager.rename_group (group.id, text);
                    }
                }
            });

            dialog.present ();
        }
    }
}
