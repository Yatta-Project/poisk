using Gtk;
using Adw;

namespace Poisk.UI {

    public class SettingsView : Adw.PreferencesPage {
        private GLib.Settings? poisk_settings = null;
        private GLib.Settings? wm_settings = null;

        public SettingsView () {
            Object (
                title: "Поиск",
                icon_name: "system-search"
            );

            init_settings ();
            build_ui ();
        }

        private void init_settings () {
            var schema_source = SettingsSchemaSource.get_default ();
            if (schema_source != null) {
                if (schema_source.lookup ("io.github.mrlogiousbanana.poisk", true) != null) {
                    poisk_settings = new GLib.Settings ("io.github.mrlogiousbanana.poisk");
                }
                if (schema_source.lookup ("io.elementary.desktop.wm.behavior", true) != null) {
                    wm_settings = new GLib.Settings ("io.elementary.desktop.wm.behavior");
                }
            }
        }

        private void build_ui () {
            // Group 1: Appearance
            var appearance_group = new Adw.PreferencesGroup ();
            appearance_group.title = "Внешний вид";
            appearance_group.description = "Настройка визуальных эффектов и отображения лаунчера";
            this.add (appearance_group);

            var frosted_row = new Adw.SwitchRow ();
            frosted_row.title = "Эффект размытия (Frosted Glass)";
            frosted_row.subtitle = "Использовать полупрозрачность дока Pantheon с размытием фона";
            if (poisk_settings != null) {
                poisk_settings.bind ("enable-frosted-glass", frosted_row, "active", SettingsBindFlags.DEFAULT);
            }
            appearance_group.add (frosted_row);

            var grid_row = new Adw.SwitchRow ();
            grid_row.title = "Сетка часто используемых программ";
            grid_row.subtitle = "Отображать Spotlight-сетку программ при пустой строке поиска";
            if (poisk_settings != null) {
                poisk_settings.bind ("show-app-grid", grid_row, "active", SettingsBindFlags.DEFAULT);
            }
            appearance_group.add (grid_row);

            var max_results_adjustment = new Adjustment (30, 5, 50, 5, 10, 0);
            var max_results_row = new Adw.SpinRow (max_results_adjustment, 5, 0);
            max_results_row.title = "Максимум результатов";
            max_results_row.subtitle = "Лимит элементов в списке поисковой выдачи";
            if (poisk_settings != null) {
                poisk_settings.bind ("max-results", max_results_adjustment, "value", SettingsBindFlags.DEFAULT);
            }
            appearance_group.add (max_results_row);

            // Group 2: System Integration
            var integration_group = new Adw.PreferencesGroup ();
            integration_group.title = "Интеграция с системой";
            integration_group.description = "Горячие клавиши Pantheon и автозапуск";
            this.add (integration_group);

            var super_row = new Adw.SwitchRow ();
            super_row.title = "Вызов клавишей Super";
            super_row.subtitle = "Использовать одиночное нажатие Super для мгновенного вызова Poisk";
            if (wm_settings != null) {
                bool is_super_poisk = (wm_settings.get_string ("overlay-action") == "poisk --toggle");
                super_row.active = is_super_poisk;
                super_row.notify["active"].connect (() => {
                    if (super_row.active) {
                        wm_settings.set_string ("overlay-action", "poisk --toggle");
                    } else {
                        wm_settings.set_string ("overlay-action", "io.elementary.wingpanel --toggle-indicator=appmenu");
                    }
                });
            } else {
                super_row.sensitive = false;
            }
            integration_group.add (super_row);

            var autostart_row = new Adw.SwitchRow ();
            autostart_row.title = "Автозапуск в фоне";
            autostart_row.subtitle = "Запускать фоновую службу Poisk при входе в сеанс";
            string autostart_path = Path.build_filename (Environment.get_user_config_dir (), "autostart", "io.github.mrlogiousbanana.poisk.desktop");
            autostart_row.active = FileUtils.test (autostart_path, FileTest.EXISTS);
            autostart_row.notify["active"].connect (() => {
                set_autostart_enabled (autostart_row.active);
            });
            integration_group.add (autostart_row);

            // Group 3: Search Providers
            var providers_group = new Adw.PreferencesGroup ();
            providers_group.title = "Источники поиска";
            providers_group.description = "Включение и отключение категорий поисковой выдачи";
            this.add (providers_group);

            var apps_row = new Adw.SwitchRow ();
            apps_row.title = "Приложения";
            apps_row.subtitle = "Поиск по установленным приложениям системы (.desktop)";
            if (poisk_settings != null) {
                poisk_settings.bind ("enable-apps", apps_row, "active", SettingsBindFlags.DEFAULT);
            }
            providers_group.add (apps_row);

            var windows_row = new Adw.SwitchRow ();
            windows_row.title = "Открытые окна";
            windows_row.subtitle = "Быстрый поиск и переключение между запущенными окнами";
            if (poisk_settings != null) {
                poisk_settings.bind ("enable-windows", windows_row, "active", SettingsBindFlags.DEFAULT);
            }
            providers_group.add (windows_row);

            var calc_row = new Adw.SwitchRow ();
            calc_row.title = "Калькулятор";
            calc_row.subtitle = "Мгновенное вычисление математических выражений";
            if (poisk_settings != null) {
                poisk_settings.bind ("enable-calc", calc_row, "active", SettingsBindFlags.DEFAULT);
            }
            providers_group.add (calc_row);

            // Group 4: About
            var about_group = new Adw.PreferencesGroup ();
            about_group.title = "О программе";
            this.add (about_group);

            var version_row = new Adw.ActionRow ();
            version_row.title = "Poisk 1.0.0";
            version_row.subtitle = "Быстрый нативный лаунчер и командная палитра для Pantheon и Linux";
            var icon = new Image.from_icon_name ("system-search");
            icon.pixel_size = 32;
            version_row.add_prefix (icon);
            about_group.add (version_row);

            var repo_row = new Adw.ActionRow ();
            repo_row.title = "Репозиторий Poisk";
            repo_row.subtitle = "https://github.com/mrlogiousbanana/poisk";
            var open_repo_btn = new Button.from_icon_name ("external-link-symbolic");
            open_repo_btn.valign = Align.CENTER;
            open_repo_btn.clicked.connect (() => {
                open_url ("https://github.com/mrlogiousbanana/poisk");
            });
            repo_row.add_suffix (open_repo_btn);
            about_group.add (repo_row);

            var vicinae_row = new Adw.ActionRow ();
            vicinae_row.title = "Оригинальный Vicinae";
            vicinae_row.subtitle = "https://github.com/vicinaehq/vicinae";
            var open_vicinae_btn = new Button.from_icon_name ("external-link-symbolic");
            open_vicinae_btn.valign = Align.CENTER;
            open_vicinae_btn.clicked.connect (() => {
                open_url ("https://github.com/vicinaehq/vicinae");
            });
            vicinae_row.add_suffix (open_vicinae_btn);
            about_group.add (vicinae_row);
        }

        private void set_autostart_enabled (bool enable) {
            string autostart_dir = Path.build_filename (Environment.get_user_config_dir (), "autostart");
            string autostart_path = Path.build_filename (autostart_dir, "io.github.mrlogiousbanana.poisk.desktop");

            if (enable) {
                try {
                    DirUtils.create_with_parents (autostart_dir, 0755);
                    string desktop_content = """[Desktop Entry]
Name=Поиск
Name[en]=Poisk
GenericName=Application Launcher
Comment=Fast native launcher and productivity palette for Pantheon and Linux
Exec=poisk --background
Icon=system-search
Terminal=false
Type=Application
Categories=Utility;Core;
X-GNOME-Autostart-enabled=true
""";
                    FileUtils.set_contents (autostart_path, desktop_content);
                } catch (Error e) {
                    warning ("Failed to create autostart entry: %s", e.message);
                }
            } else {
                if (FileUtils.test (autostart_path, FileTest.EXISTS)) {
                    FileUtils.unlink (autostart_path);
                }
            }
        }

        private void open_url (string url) {
            try {
                string[] argv = { "xdg-open", url };
                Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
            } catch (Error e) {
                warning ("Failed to open url: %s", e.message);
            }
        }
    }
}
