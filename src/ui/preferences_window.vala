using Gtk;
using Adw;

namespace Poisk.UI {

    public class PoiskPreferencesWindow : Adw.PreferencesWindow {
        public PoiskPreferencesWindow (Gtk.Window? parent = null) {
            Object (
                title: "Параметры Поиска",
                transient_for: parent,
                modal: false,
                default_width: 640,
                default_height: 580
            );

            this.add (new SettingsView ());
        }
    }
}
