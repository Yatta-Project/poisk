using Gtk;
using Switchboard;

public class PoiskPlug : Switchboard.Plug {
    public PoiskPlug () {
        var settings = new Gee.TreeMap<string, string?> (null, null);
        settings.set ("poisk", null);
        settings.set ("search", null);

        Object (
            category: Category.PERSONAL,
            code_name: "io.github.mrlogiousbanana.poisk",
            display_name: "Поиск",
            description: "Быстрый нативный лаунчер и командная палитра",
            icon: "system-search",
            supported_settings: settings
        );
    }

    public override Gtk.Widget get_widget () {
        return new Poisk.UI.SettingsView ();
    }

    public override void shown () {}
    public override void hidden () {}
    public override void search_callback (string location) {}

    public override async Gee.TreeMap<string, string> search (string search_term) {
        var res = new Gee.TreeMap<string, string> (null, null);
        res.set ("Поиск → Внешний вид", "");
        res.set ("Поиск → Горячие клавиши", "");
        res.set ("Поиск → Источники поиска", "");
        return res;
    }
}

public Switchboard.Plug get_plug (Module module) {
    return new PoiskPlug ();
}
