using Gtk;

namespace Poisk.UI {

    public class PillHeader : Box {
        private Entry entry;

        public signal void search_changed (string query);
        public new signal void activate ();

        public PillHeader () {
            Object (orientation: Orientation.HORIZONTAL, spacing: 0);

            this.add_css_class ("poisk-pill-header");
            this.set_size_request (-1, 56);
            this.valign = Align.START;
            this.halign = Align.FILL;
            this.hexpand = true;

            // Main Search Text Entry
            entry = new Entry ();
            entry.hexpand = true;
            entry.vexpand = true;
            entry.valign = Align.CENTER;
            entry.placeholder_text = "Поиск приложений и окон...";
            entry.add_css_class ("pill-entry");

            entry.changed.connect (() => {
                search_changed (entry.get_text ());
            });

            entry.activate.connect (() => {
                activate ();
            });

            this.append (entry);
        }

        public string get_text () {
            return entry.get_text ();
        }

        public void set_text (string text) {
            entry.set_text (text);
        }

        public void grab_entry_focus () {
            entry.grab_focus ();
        }

        public void set_mode_icon (string icon_name) {
        }

        public Entry get_entry_widget () {
            return entry;
        }
    }
}
