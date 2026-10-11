using Gtk;
using Switchboard;

public class PoiskSettingsPage : Switchboard.SettingsPage {
    public PoiskSettingsPage () {
        Object (
            title: "Поиск",
            icon: new GLib.ThemedIcon ("system-search"),
            child: new Poisk.UI.SettingsView ()
        );
    }
}

public class PoiskPlug : Switchboard.Plug {
    public PoiskPlug () {
        var settings = new Gee.TreeMap<string, string?> (null, null);
        settings.set ("desktop/poisk", null);
        settings.set ("desktop/search", null);
        settings.set ("poisk", null);
        settings.set ("search", null);

        Object (
            category: Category.PERSONAL,
            code_name: "io.github.mrlogiousbanana.poisk",
            display_name: "Поиск",
            description: "Параметры поиска и оформления лаунчера рабочего стола",
            icon: "system-search",
            supported_settings: settings
        );

        // Hide standalone tile from the root Switchboard grid so settings live inside the Desktop category
        this.can_show = false;
    }

    private PoiskSettingsPage? page = null;

    public override Gtk.Widget get_widget () {
        if (page == null) {
            page = new PoiskSettingsPage ();
        }
        return page;
    }

    public override void shown () {}
    public override void hidden () {}
    public override void search_callback (string location) {}

    public override async Gee.TreeMap<string, string> search (string search_term) {
        var res = new Gee.TreeMap<string, string> (null, null);
        res.set ("Рабочий стол → Поиск → Внешний вид", "desktop/poisk");
        res.set ("Рабочий стол → Поиск → Горячие клавиши", "desktop/poisk");
        res.set ("Рабочий стол → Поиск → Источники поиска", "desktop/poisk");
        return res;
    }
}

public Switchboard.Plug get_plug (Module module) {
    return new PoiskPlug ();
}
