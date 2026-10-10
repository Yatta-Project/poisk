using Gtk;
using Adw;
using Poisk.Core;

namespace Poisk.UI {

    public class LauncherWindow : Gtk.Window {
        public enum WindowMode {
            CAPSULE,
            RESULTS,
            MENU
        }

        private WindowMode current_mode = WindowMode.CAPSULE;

        private SearchEngine engine;
        private Box root_box;
        private FrostedBox capsule_box;
        private PillHeader pill_header;
        private Box results_card;
        private ListBox result_list;
        private ScrolledWindow list_scroll;
        private Box menu_card;
        private AppGrid app_grid;
        private Label menu_footer_label;
        private Label footer_label;
        private Box footer_box;
        private Cancellable? current_search_cancellable = null;
        private GLib.Settings? transparency_settings = null;

        public LauncherWindow (SearchEngine engine) {
            Object ();
            this.engine = engine;

            this.title = "Поиск";
            this.set_default_size (846, 152);
            this.resizable = true;
            this.decorated = false; // Borderless floating window
            this.modal = true;
            this.set_hide_on_close (true);
            this.add_css_class ("poisk-window");

            setup_ui ();
            setup_key_handling ();
            setup_css ();
            setup_system_transparency ();

            // Prewarm common SVG icons at startup before interactive rendering
            ResultRow.get_cached_icon ("org.gnome.Software", 28);
            ResultRow.get_cached_icon ("io.elementary.appcenter", 28);

            this.map.connect (() => {
                set_skip_taskbar (this);
                int cur_h = (current_mode == WindowMode.CAPSULE) ? 152 : 546;
                resize_and_center_window (this, 846, cur_h);
            });

            // Focus on show, auto-hide on focus loss
            this.notify["is-active"].connect (() => {
                if (this.is_active) {
                    pill_header.grab_entry_focus ();
                } else if (this.visible) {
                    GLib.Timeout.add (120, () => {
                        if (!this.is_active && this.visible) {
                            this.set_visible (false);
                        }
                        return GLib.Source.REMOVE;
                    });
                }
            });

            this.notify["visible"].connect (() => {
                if (this.visible) {
                    pill_header.set_text ("");
                    switch_mode (WindowMode.CAPSULE);
                    pill_header.grab_entry_focus ();
                }
            });

            switch_mode (WindowMode.CAPSULE);
        }

        private void setup_system_transparency () {
            // Adapt to elementary OS transparency settings
            var schema_source = SettingsSchemaSource.get_default ();
            var schema = schema_source.lookup ("io.elementary.desktop.wingpanel", true);
            if (schema != null && schema.has_key ("use-transparency")) {
                transparency_settings = new GLib.Settings ("io.elementary.desktop.wingpanel");
                transparency_settings.changed["use-transparency"].connect (() => {
                    update_transparency_mode ();
                });
                update_transparency_mode ();
            } else {
                // Default: enable blur effect
                set_frosted_enabled (true);
            }
        }

        private void update_transparency_mode () {
            if (transparency_settings != null) {
                bool use_trans = transparency_settings.get_boolean ("use-transparency");
                set_frosted_enabled (use_trans);
            }
        }

        public void set_frosted_enabled (bool enabled) {
            capsule_box.frosted = enabled;
            if (enabled) {
                capsule_box.remove_css_class ("reduce-transparency");
                this.remove_css_class ("reduce-transparency");
            } else {
                capsule_box.add_css_class ("reduce-transparency");
                this.add_css_class ("reduce-transparency");
            }
            capsule_box.queue_draw ();
        }

        public void switch_mode (WindowMode mode) {
            current_mode = mode;
            switch (mode) {
                case WindowMode.CAPSULE:
                    results_card.visible = false;
                    menu_card.visible = false;
                    pill_header.visible = true;
                    pill_header.remove_css_class ("expanded-header");
                    this.remove_css_class ("expanded-card");
                    capsule_box.remove_css_class ("expanded-card");
                    capsule_box.set_size_request (680, 56);

                    resize_and_center_window (this, 846, 152);
                    break;

                case WindowMode.RESULTS:
                    menu_card.visible = false;
                    results_card.visible = true;
                    pill_header.visible = true;
                    pill_header.add_css_class ("expanded-header");
                    this.add_css_class ("expanded-card");
                    capsule_box.add_css_class ("expanded-card");
                    capsule_box.set_size_request (680, 444);

                    resize_and_center_window (this, 846, 546);
                    break;

                case WindowMode.MENU:
                    results_card.visible = false;
                    menu_card.visible = true;
                    pill_header.visible = true;
                    pill_header.add_css_class ("expanded-header");
                    this.add_css_class ("expanded-card");
                    capsule_box.add_css_class ("expanded-card");
                    capsule_box.set_size_request (680, 444);

                    resize_and_center_window (this, 846, 546);
                    break;
            }
        }

        private void setup_ui () {
            root_box = new Box (Orientation.HORIZONTAL, 0);
            root_box.valign = Align.START;
            root_box.halign = Align.CENTER;
            root_box.margin_start = 48;
            root_box.margin_end = 48;
            root_box.margin_top = 40;
            root_box.margin_bottom = 56;

            // Main Card (dock blur background)
            capsule_box = new FrostedBox (Orientation.VERTICAL, 0);
            capsule_box.frosted = true;
            capsule_box.blur_radius = 24.0;
            capsule_box.corner_radius = 16.0f;
            capsule_box.add_css_class ("poisk-capsule");
            capsule_box.set_size_request (680, 56);
            capsule_box.valign = Align.START;
            capsule_box.halign = Align.FILL;
            capsule_box.hexpand = true;

            pill_header = new PillHeader ();
            pill_header.search_changed.connect (on_search_changed);
            pill_header.activate.connect (on_header_activate);
            capsule_box.append (pill_header);

            // Results Body
            results_card = new Box (Orientation.VERTICAL, 4);
            results_card.add_css_class ("poisk-results-card");
            results_card.set_size_request (-1, 384);
            results_card.valign = Align.FILL;
            results_card.halign = Align.FILL;
            results_card.vexpand = true;
            results_card.hexpand = true;
            results_card.visible = false;

            var list_content_box = new Box (Orientation.HORIZONTAL, 0);
            list_content_box.vexpand = true;
            list_content_box.hexpand = true;

            list_scroll = new ScrolledWindow ();
            list_scroll.hexpand = true;
            list_scroll.vexpand = true;
            list_scroll.hscrollbar_policy = PolicyType.NEVER;

            result_list = new ListBox ();
            result_list.hexpand = true;
            result_list.selection_mode = SelectionMode.SINGLE;
            result_list.add_css_class ("navigation-sidebar");
            result_list.row_selected.connect (on_row_selected);
            result_list.row_activated.connect (on_row_activated);

            list_scroll.set_child (result_list);
            list_content_box.append (list_scroll);

            results_card.append (list_content_box);

            var sep_foot = new Separator (Orientation.HORIZONTAL);
            results_card.append (sep_foot);

            footer_box = new Box (Orientation.HORIZONTAL, 8);
            footer_box.margin_start = 12;
            footer_box.margin_end = 12;
            footer_box.margin_top = 4;
            footer_box.margin_bottom = 6;

            footer_label = new Label ("↵ Выполнить / Открыть    ⎋ Очистить    ↑↓ Навигация");
            footer_label.add_css_class ("dim-label");
            footer_label.add_css_class ("caption");
            footer_label.halign = Align.START;
            footer_label.hexpand = true;
            footer_box.append (footer_label);

            results_card.append (footer_box);
            capsule_box.append (results_card);

            // Applications Grid Menu Body (when typing :menu or :apps)
            menu_card = new Box (Orientation.VERTICAL, 4);
            menu_card.add_css_class ("poisk-results-card");
            menu_card.set_size_request (-1, 384);
            menu_card.valign = Align.FILL;
            menu_card.halign = Align.FILL;
            menu_card.vexpand = true;
            menu_card.hexpand = true;
            menu_card.visible = false;

            app_grid = new AppGrid ();
            app_grid.item_activated.connect ((item) => {
                this.set_visible (false);
                item.execute ();
            });
            menu_card.append (app_grid);

            var sep_menu_foot = new Separator (Orientation.HORIZONTAL);
            menu_card.append (sep_menu_foot);

            var menu_footer_box = new Box (Orientation.HORIZONTAL, 8);
            menu_footer_box.margin_start = 12;
            menu_footer_box.margin_end = 12;
            menu_footer_box.margin_top = 4;
            menu_footer_box.margin_bottom = 6;

            menu_footer_label = new Label ("↵ Запустить    ⎋ Очистить    ←↑↓→ Навигация");
            menu_footer_label.add_css_class ("dim-label");
            menu_footer_label.add_css_class ("caption");
            menu_footer_label.halign = Align.START;
            menu_footer_label.hexpand = true;
            menu_footer_box.append (menu_footer_label);

            menu_card.append (menu_footer_box);
            capsule_box.append (menu_card);

            root_box.append (capsule_box);
            this.set_child (root_box);
        }

        private void on_header_activate () {
            if (current_mode == WindowMode.RESULTS) {
                activate_selected ();
            } else if (current_mode == WindowMode.MENU) {
                app_grid.activate_selected ();
            }
        }

        private void setup_key_handling () {
            var key_controller = new EventControllerKey ();
            key_controller.set_propagation_phase (PropagationPhase.CAPTURE);
            key_controller.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Escape) {
                    if (current_mode == WindowMode.RESULTS || current_mode == WindowMode.MENU || pill_header.get_text ().length > 0) {
                        pill_header.set_text ("");
                        switch_mode (WindowMode.CAPSULE);
                        return true;
                    }

                    this.set_visible (false);
                    return true;
                }

                if (current_mode == WindowMode.RESULTS) {
                    if (keyval == Gdk.Key.Down) {
                        select_next_row ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Up) {
                        select_prev_row ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                        activate_selected ();
                        return true;
                    }
                }

                if (current_mode == WindowMode.MENU) {
                    if (keyval == Gdk.Key.Right) {
                        app_grid.select_next ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Left) {
                        app_grid.select_prev ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Down) {
                        app_grid.select_down ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Up) {
                        app_grid.select_up ();
                        return true;
                    }
                    if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                        app_grid.activate_selected ();
                        return true;
                    }
                }

                return false;
            });
            ((Gtk.Widget) this).add_controller (key_controller);
        }

        private void setup_css () {
            var provider = new CssProvider ();
            string css = """
                /* Clean transparent root window */
                window,
                window.poisk-window {
                    background: transparent;
                    background-color: transparent;
                    box-shadow: none;
                    border: none;
                    padding: 0;
                    margin: 0;
                }

                /* Elementary Dock-like unified card with highlights and borders */
                .poisk-capsule {
                    background: alpha(@bg_color, 0.80);
                    box-shadow:
                        inset 0 -1px 0 0 alpha(@highlight_color, 0.40),
                        inset 0 1px 0 0 alpha(@highlight_color, 0.60),
                        inset 1px 0 0 0 alpha(@highlight_color, 0.14),
                        inset -1px 0 0 0 alpha(@highlight_color, 0.14),
                        0 0 0 1px @borders,
                        0 8px 26px alpha(black, 0.28),
                        0 2px 6px alpha(black, 0.18);
                    border-radius: 16px;
                    border: none;
                    padding: 0;
                    margin: 0;
                    min-height: 56px;
                    transition: all 180ms cubic-bezier(0.25, 0.8, 0.25, 1);
                }

                .reduce-transparency .poisk-capsule,
                .poisk-capsule.reduce-transparency {
                    background: @bg_color;
                    opacity: 1.0;
                }

                .poisk-capsule.expanded-card {
                    border-radius: 18px;
                    box-shadow:
                        inset 0 -1px 0 0 alpha(@highlight_color, 0.40),
                        inset 0 1px 0 0 alpha(@highlight_color, 0.60),
                        inset 1px 0 0 0 alpha(@highlight_color, 0.14),
                        inset -1px 0 0 0 alpha(@highlight_color, 0.14),
                        0 0 0 1px @borders,
                        0 14px 42px alpha(black, 0.35),
                        0 4px 10px alpha(black, 0.20);
                }

                /* Header */
                .poisk-pill-header {
                    background: transparent;
                    border: none;
                    border-radius: 16px;
                    box-shadow: none;
                    min-height: 56px;
                    padding: 0 14px;
                }
                .poisk-pill-header.expanded-header {
                    border-bottom: 1px solid alpha(@borders, 0.50);
                    border-bottom-left-radius: 0;
                    border-bottom-right-radius: 0;
                }

                /* Clean Entry without blue focus border */
                entry.pill-entry,
                entry.pill-entry:focus,
                entry.pill-entry:focus-within,
                entry.pill-entry text,
                entry.pill-entry text:focus,
                entry.pill-entry text:focus-within {
                    border: none;
                    background: transparent;
                    background-color: transparent;
                    box-shadow: none;
                    outline: none;
                    font-size: 16px;
                    font-weight: 400;
                    padding-left: 6px;
                    padding-right: 6px;
                }

                /* Results & Menu Body */
                .poisk-results-card {
                    background: transparent;
                    border: none;
                    border-bottom-left-radius: 18px;
                    border-bottom-right-radius: 18px;
                    box-shadow: none;
                    padding: 6px;
                }
                list.navigation-sidebar {
                    background: transparent;
                }

                .poisk-result-row {
                    border-radius: 10px;
                    margin: 2px 8px;
                    padding: 4px;
                    transition: background 120ms ease;
                }
                .poisk-result-row:selected,
                .poisk-result-row:hover {
                    background: alpha(currentColor, 0.08);
                }

                .poisk-grid-card {
                    border-radius: 12px;
                    padding: 4px;
                    transition: all 120ms ease;
                    background: transparent;
                }
                .poisk-grid-card:hover,
                .poisk-grid-card:selected {
                    background: alpha(currentColor, 0.08);
                }

                /* Soft Drop Shadows for App Icons */
                .poisk-app-icon {
                    filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.12));
                }
                .poisk-grid-icon {
                    filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.14));
                }
            """;
            provider.load_from_string (css);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_USER
            );
        }

        private void on_search_changed () {
            string text = pill_header.get_text ();
            trigger_search (text);
        }

        private void trigger_search (string query) {
            if (current_search_cancellable != null) {
                current_search_cancellable.cancel ();
            }
            current_search_cancellable = new Cancellable ();

            execute_search.begin (query, current_search_cancellable);
        }

        private async void execute_search (string query, Cancellable cancellable) {
            string q = query.strip ();
            if (q.length == 0) {
                switch_mode (WindowMode.CAPSULE);
                return;
            }

            if (q == ":menu" || q.has_prefix (":menu ") || q == ":apps" || q.has_prefix (":apps ")) {
                string filter = "";
                if (q.has_prefix (":menu ")) {
                    filter = q.substring (6).strip ();
                } else if (q.has_prefix (":apps ")) {
                    filter = q.substring (6).strip ();
                }
                var all_apps = engine.get_all_applications ();
                var filtered = new List<SearchItem> ();
                foreach (var app in all_apps) {
                    if (filter.length == 0) {
                        filtered.append (app);
                    } else if (SearchEngine.fuzzy_score (filter, app.title) > 0 ||
                               SearchEngine.fuzzy_score (filter, app.subtitle) > 0) {
                        filtered.append (app);
                    }
                }
                app_grid.set_items (filtered);
                switch_mode (WindowMode.MENU);
                menu_footer_label.set_text ("↵ Запустить    ⎋ Очистить    ←↑↓→ Навигация (%u прил.)".printf (filtered.length ()));
                return;
            }

            var items = yield engine.query (query, cancellable);
            if (cancellable.is_cancelled ()) return;

            switch_mode (WindowMode.RESULTS);
            footer_label.set_text ("↵ Выполнить / Открыть    ⎋ Очистить    ↑↓ Навигация");

            // Clear previous list
            ListBoxRow? child = result_list.get_first_child () as ListBoxRow;
            while (child != null) {
                var next = child.get_next_sibling () as ListBoxRow;
                result_list.remove (child);
                child = next;
            }

            // Populate results (cap at 30 to keep UI instant)
            int count = 0;
            foreach (var item in items) {
                if (count >= 30) break;
                var row = new ResultRow (item);
                result_list.append (row);
                count++;
            }

            // Auto-select first item
            var first = result_list.get_row_at_index (0);
            if (first != null) {
                result_list.select_row (first);
            }
        }

        private void on_row_selected (ListBoxRow? row) {
        }

        private void on_row_activated (ListBoxRow row) {
            var result_row = row as ResultRow;
            if (result_row != null) {
                var item = result_row.item;
                this.set_visible (false);
                item.execute ();
            }
        }

        private void activate_selected () {
            var row = result_list.get_selected_row ();
            if (row != null) {
                on_row_activated (row);
            }
        }

        private void select_next_row () {
            var current = result_list.get_selected_row ();
            int idx = (current != null) ? current.get_index () + 1 : 0;
            var next = result_list.get_row_at_index (idx);
            if (next != null) {
                result_list.select_row (next);
                ensure_row_visible (next);
            }
        }

        private void select_prev_row () {
            var current = result_list.get_selected_row ();
            int idx = (current != null) ? current.get_index () - 1 : 0;
            if (idx >= 0) {
                var prev = result_list.get_row_at_index (idx);
                if (prev != null) {
                    result_list.select_row (prev);
                    ensure_row_visible (prev);
                }
            }
        }

        private void ensure_row_visible (ListBoxRow row) {
            var adj = list_scroll.get_vadjustment ();
            double y = 0;
            row.translate_coordinates (result_list, 0, 0, null, out y);
            int height = row.get_height ();
            if (y < adj.get_value ()) {
                adj.set_value (y);
            } else if (y + height > adj.get_value () + adj.get_page_size ()) {
                adj.set_value (y + height - adj.get_page_size ());
            }
        }
    }
}
