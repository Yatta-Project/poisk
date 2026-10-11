{ pkgs ? import <nixpkgs> {} }:

let
  poiskSettingsView = ./src/ui/settings_view.vala;
  poiskSchema = ./data/io.github.mrlogiousbanana.poisk.gschema.xml;
in
pkgs.pantheon.switchboard-plug-pantheon-shell.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    cat << 'EOF' > src/Views/Poisk.vala
using Gtk;
using Adw;

public class PantheonShell.Poisk : Switchboard.SettingsPage {
    public Poisk () {
        Object (
            title: _("Search"),
            icon: new ThemedIcon ("system-search"),
            show_end_title_buttons: true
        );
    }

    construct {
        child = new global::Poisk.UI.SettingsView ();
    }
}
EOF
    grep -v '^using ' "${poiskSettingsView}" >> src/Views/Poisk.vala
    sed -i "s|'Views/Multitasking.vala',|'Views/Multitasking.vala',\n    'Views/Poisk.vala',|" src/meson.build
    sed -i '/var multitasking = new Multitasking ();/a \            var poisk = new Poisk ();' src/Plug.vala
    sed -i '/stack.add_titled (multitasking, "multitasking", _("Multitasking"));/a \            stack.add_titled (poisk, "poisk", _("Search"));' src/Plug.vala
    sed -i '/settings.set ("desktop\/multitasking", "multitasking");/a \        settings.set ("desktop/poisk", "poisk");\n        settings.set ("desktop/search", "poisk");' src/Plug.vala
    sed -i 's|case "multitasking":|case "poisk":\n                stack.set_visible_child_name ("poisk");\n                break;\n            case "multitasking":|' src/Plug.vala
    sed -i '/search_results.set ("%s → %s".printf (display_name, _("Multitasking")), "multitasking");/a \        search_results.set ("%s → %s".printf (display_name, _("Search")), "poisk");' src/Plug.vala
    if [ -f po/ru.po ]; then
      printf '\nmsgid "Search"\nmsgstr "Поиск"\n' >> po/ru.po
    fi
  '';
})
