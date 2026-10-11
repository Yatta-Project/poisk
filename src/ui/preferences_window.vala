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

            var page = new Adw.PreferencesPage ();
            page.title = "Поиск";
            page.icon_name = "system-search";
            new SettingsView (page);
            this.add (page);
        }
    }
}
