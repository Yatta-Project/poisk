using Gtk;
using Adw;
using Vicinae.Core;

namespace Vicinae.UI {

    public class LauncherWindow : Adw.ApplicationWindow {
        private SearchEngine engine;
        private SearchEntry search_entry;
        private ListBox result_list;
        private ScrolledWindow list_scroll;
        private PreviewPane preview_pane;
        private Label footer_label;
        private Cancellable? current_search_cancellable = null;

        public LauncherWindow (Gtk.Application app, SearchEngine engine) {
            Object (application: app);
            this.engine = engine;

            this.title = "Vicinae";
            this.set_default_size (740, 480);
            this.resizable = false;
            this.decorated = false; // Borderless floating window
            this.set_hide_on_close (true);
            this.add_css_class ("vicinae-window");

            setup_ui ();
            setup_key_handling ();
            setup_css ();

            // Focus and reset search entry on show
            this.notify["is-active"].connect (() => {
                if (this.is_active) {
                    search_entry.grab_focus ();
                }
            });

            this.notify["visible"].connect (() => {
                if (this.visible) {
                    search_entry.set_text ("");
                    trigger_search ("");
                    search_entry.grab_focus ();
                }
            });

            // Initial search (frequently used apps)
            trigger_search ("");
        }

        private void setup_ui () {
            var root_box = new Box (Orientation.VERTICAL, 0);
            root_box.add_css_class ("vicinae-root");

            // 1. Search Header Bar
            var header_box = new Box (Orientation.HORIZONTAL, 8);
            header_box.margin_start = 14;
            header_box.margin_end = 14;
            header_box.margin_top = 12;
            header_box.margin_bottom = 12;

            search_entry = new SearchEntry ();
            search_entry.hexpand = true;
            search_entry.placeholder_text = "Type a command, app, window, or math...";
            search_entry.add_css_class ("vicinae-search-entry");
            search_entry.search_changed.connect (on_search_changed);
            search_entry.activate.connect (activate_selected);

            header_box.append (search_entry);
            root_box.append (header_box);

            var sep1 = new Separator (Orientation.HORIZONTAL);
            root_box.append (sep1);

            // 2. Main Content Area (Results List + Preview Pane)
            var content_box = new Box (Orientation.HORIZONTAL, 0);
            content_box.vexpand = true;

            // List of results
            list_scroll = new ScrolledWindow ();
            list_scroll.hexpand = true;
            list_scroll.vexpand = true;
            list_scroll.hscrollbar_policy = PolicyType.NEVER;

            result_list = new ListBox ();
            result_list.selection_mode = SelectionMode.SINGLE;
            result_list.add_css_class ("navigation-sidebar");
            result_list.row_selected.connect (on_row_selected);
            result_list.row_activated.connect (on_row_activated);

            list_scroll.set_child (result_list);
            content_box.append (list_scroll);

            var sep_vert = new Separator (Orientation.VERTICAL);
            content_box.append (sep_vert);

            // Preview pane
            preview_pane = new PreviewPane ();
            content_box.append (preview_pane);

            root_box.append (content_box);

            var sep2 = new Separator (Orientation.HORIZONTAL);
            root_box.append (sep2);

            // 3. Footer Bar with Shortcuts
            var footer_box = new Box (Orientation.HORIZONTAL, 12);
            footer_box.margin_start = 14;
            footer_box.margin_end = 14;
            footer_box.margin_top = 8;
            footer_box.margin_bottom = 8;

            footer_label = new Label ("↵ Open    ⎋ Close    ↑↓ Navigate    Tab Actions");
            footer_label.add_css_class ("dim-label");
            footer_label.add_css_class ("caption");
            footer_box.append (footer_label);

            root_box.append (footer_box);

            this.set_content (root_box);
        }

        private void setup_key_handling () {
            var key_controller = new EventControllerKey ();
            key_controller.set_propagation_phase (PropagationPhase.CAPTURE);
            key_controller.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Escape) {
                    if (Application.dmenu_mode) {
                        Posix.exit (1);
                    }
                    this.set_visible (false);
                    return true;
                }

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

                return false;
            });
            ((Gtk.Widget) this).add_controller (key_controller);
        }

        private void setup_css () {
            var provider = new CssProvider ();
            string css = """
                .vicinae-window {
                    border-radius: 16px;
                    border: 1px solid alpha(currentColor, 0.15);
                    box-shadow: 0 16px 40px rgba(0, 0, 0, 0.35);
                }
                .vicinae-root {
                    border-radius: 16px;
                }
                .vicinae-search-entry {
                    border: none;
                    background: transparent;
                    box-shadow: none;
                    font-size: 1.15rem;
                }
                .vicinae-result-row {
                    border-radius: 8px;
                    margin: 2px 8px;
                    padding: 2px;
                    transition: background 150ms ease;
                }
                .vicinae-preview-pane {
                    background: alpha(currentColor, 0.02);
                }
            """;
            provider.load_from_string (css);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }

        private void on_search_changed () {
            string text = search_entry.get_text ();
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
            var items = yield engine.query (query, cancellable);
            if (cancellable.is_cancelled ()) return;

            // Clear previous list
            ListBoxRow? child = result_list.get_first_child () as ListBoxRow;
            while (child != null) {
                var next = child.get_next_sibling () as ListBoxRow;
                result_list.remove (child);
                child = next;
            }

            // Populate results
            foreach (var item in items) {
                var row = new ResultRow (item);
                result_list.append (row);
            }

            // Select first row
            var first_row = result_list.get_row_at_index (0);
            if (first_row != null) {
                result_list.select_row (first_row);
            } else {
                preview_pane.update (null);
            }
        }

        private void on_row_selected (ListBoxRow? row) {
            if (row != null && row is ResultRow) {
                var res = (ResultRow) row;
                preview_pane.update (res.item);
            } else {
                preview_pane.update (null);
            }
        }

        private void on_row_activated (ListBoxRow row) {
            if (row is ResultRow) {
                var res = (ResultRow) row;
                if (Application.dmenu_mode) {
                    this.destroy ();
                } else {
                    this.set_visible (false);
                }
                res.item.execute ();
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
            int idx = current != null ? current.get_index () + 1 : 0;
            var next = result_list.get_row_at_index (idx);
            if (next != null) {
                result_list.select_row (next);
                var vadj = list_scroll.get_vadjustment ();
                if (vadj != null) {
                    double target_y = idx * 48.0;
                    vadj.clamp_page (target_y, target_y + 48.0);
                }
            }
        }

        private void select_prev_row () {
            var current = result_list.get_selected_row ();
            if (current != null && current.get_index () > 0) {
                int idx = current.get_index () - 1;
                var prev = result_list.get_row_at_index (idx);
                if (prev != null) {
                    result_list.select_row (prev);
                    var vadj = list_scroll.get_vadjustment ();
                    if (vadj != null) {
                        double target_y = idx * 48.0;
                        vadj.clamp_page (target_y, target_y + 48.0);
                    }
                }
            }
        }
    }
}
