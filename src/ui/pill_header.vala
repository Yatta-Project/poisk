using Gtk;

namespace Poisk.UI {

    public class PillHeader : Box {
        private Entry entry;
        private Revealer glance_revealer;
        private GlancePill glance_pill;

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

            glance_pill = new GlancePill ();
            glance_pill.dismissed.connect (() => {
                glance_revealer.reveal_child = false;
            });

            glance_revealer = new Revealer ();
            glance_revealer.transition_type = RevealerTransitionType.CROSSFADE;
            glance_revealer.transition_duration = 160;
            glance_revealer.set_child (glance_pill);
            glance_revealer.valign = Align.CENTER;
            glance_revealer.reveal_child = false;

            entry.changed.connect (() => {
                string text = entry.get_text ();
                glance_revealer.reveal_child = (text.length == 0 && glance_pill.has_action);
                search_changed (text);
            });

            entry.activate.connect (() => {
                if (entry.get_text ().strip ().length == 0 && glance_pill.has_action) {
                    glance_pill.execute_action ();
                    return;
                }
                activate ();
            });

            this.append (entry);
            this.append (glance_revealer);
        }

        public void apply_glance_item (Poisk.Core.GlanceItem item, owned GlancePill.ActionCallback? cb = null, owned GlancePill.DismissCallback? dismiss_cb = null) {
            glance_pill.set_dismiss_callback ((owned) dismiss_cb);
            glance_pill.apply_item (item, (owned) cb);
            glance_revealer.reveal_child = (entry.get_text ().length == 0 && glance_pill.has_action);
        }

        public void dismiss_glance () {
            glance_pill.dismiss ();
        }

        public void set_glance (string? icon_name, string? emoji, string text, owned GlancePill.ActionCallback? cb = null) {
            glance_pill.set_glance (icon_name, emoji, text, (owned) cb);
            glance_revealer.reveal_child = (entry.get_text ().length == 0 && glance_pill.has_action);
        }

        public void clear_glance () {
            glance_pill.set_glance (null, null, "");
            glance_revealer.reveal_child = false;
        }

        public GlancePill get_glance_pill () {
            return glance_pill;
        }

        public bool has_glance_action () {
            return glance_pill.has_action;
        }

        public string get_text () {
            return entry.get_text ();
        }

        public void set_text (string text) {
            entry.set_text (text);
            glance_revealer.reveal_child = (text.length == 0 && glance_pill.has_action);
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
