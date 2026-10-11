import { ExtensionPreferences } from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';
import Adw from 'gi://Adw';
import Gtk from 'gi://Gtk';
import Gio from 'gi://Gio';
import Gdk from 'gi://Gdk';
import GLib from 'gi://GLib';

export default class PoiskPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        let settings = null;
        try {
            settings = this.getSettings('io.github.mrlogiousbanana.poisk');
        } catch (e) {
            try {
                settings = new Gio.Settings({ schema_id: 'io.github.mrlogiousbanana.poisk' });
            } catch (err) {
                console.error('Poisk: failed to load GSettings schema:', err);
            }
        }

        const page = new Adw.PreferencesPage({
            title: 'Поиск',
            icon_name: 'system-search',
        });
        window.add(page);

        // Group 1: Appearance
        const appearanceGroup = new Adw.PreferencesGroup({
            title: 'Внешний вид',
            description: 'Настройка визуального стиля, прозрачности и размытия',
        });
        page.add(appearanceGroup);

        // Layout style
        const styleModel = Gtk.StringList.new([
            'Монолитный (единая капсула)',
            'С островком (сателлитный значок и поиск)',
        ]);
        const layoutRow = new Adw.ComboRow({
            title: 'Форм-фактор оформления',
            subtitle: 'Выберите между монолитной капсулой или стилем с отдельным островком',
            model: styleModel,
        });
        if (settings) {
            const currentStyle = settings.get_string('layout-style');
            layoutRow.selected = currentStyle === 'island' ? 1 : 0;
            layoutRow.connect('notify::selected', () => {
                settings.set_string('layout-style', layoutRow.selected === 1 ? 'island' : 'monolithic');
            });
        }
        appearanceGroup.add(layoutRow);

        // Frosted Glass
        const frostedRow = new Adw.SwitchRow({
            title: 'Эффект размытия (Frosted Glass)',
            subtitle: 'Включить размытие фона под поверхностью лаунчера',
        });
        if (settings) {
            settings.bind('enable-frosted-glass', frostedRow, 'active', Gio.SettingsBindFlags.DEFAULT);
        }
        appearanceGroup.add(frostedRow);

        // Opacity Slider
        const opacityRow = new Adw.ActionRow({
            title: 'Непрозрачность окна',
            subtitle: 'Регулировка плотности фона и матового стекла (0% — прозрачное, 100% — сплошное)',
        });
        const opacityAdj = new Gtk.Adjustment({
            value: 84,
            lower: 0,
            upper: 100,
            step_increment: 1,
            page_increment: 5,
        });
        const opacityScale = new Gtk.Scale({
            orientation: Gtk.Orientation.HORIZONTAL,
            adjustment: opacityAdj,
            draw_value: true,
            value_pos: Gtk.PositionType.RIGHT,
            valign: Gtk.Align.CENTER,
        });
        opacityScale.set_size_request(170, -1);
        opacityScale.set_format_value_func((scale, val) => `${Math.round(val)}%`);

        if (settings) {
            opacityAdj.value = Math.round(settings.get_double('window-opacity') * 100);
            opacityAdj.connect('value-changed', () => {
                settings.set_double('window-opacity', opacityAdj.value / 100.0);
            });
        }

        const opacityResetBtn = new Gtk.Button({
            icon_name: 'edit-undo-symbolic',
            valign: Gtk.Align.CENTER,
            tooltip_text: 'Сбросить к значению по умолчанию (84%)',
        });
        opacityResetBtn.add_css_class('flat');
        opacityResetBtn.connect('clicked', () => {
            opacityAdj.value = 84;
        });

        opacityRow.add_suffix(opacityScale);
        opacityRow.add_suffix(opacityResetBtn);
        appearanceGroup.add(opacityRow);

        // Blur Radius Slider
        const blurRow = new Adw.ActionRow({
            title: 'Радиус размытия композитора',
            subtitle: 'Сила сглаживания фонового изображения в пикселях',
        });
        const blurAdj = new Gtk.Adjustment({
            value: 18,
            lower: 0,
            upper: 48,
            step_increment: 1,
            page_increment: 4,
        });
        const blurScale = new Gtk.Scale({
            orientation: Gtk.Orientation.HORIZONTAL,
            adjustment: blurAdj,
            draw_value: true,
            value_pos: Gtk.PositionType.RIGHT,
            valign: Gtk.Align.CENTER,
        });
        blurScale.set_size_request(170, -1);
        blurScale.set_format_value_func((scale, val) => `${Math.round(val)} px`);

        if (settings) {
            blurAdj.value = settings.get_int('blur-radius');
            blurAdj.connect('value-changed', () => {
                settings.set_int('blur-radius', Math.round(blurAdj.value));
            });
        }

        const blurResetBtn = new Gtk.Button({
            icon_name: 'edit-undo-symbolic',
            valign: Gtk.Align.CENTER,
            tooltip_text: 'Сбросить к значению по умолчанию (18 px)',
        });
        blurResetBtn.add_css_class('flat');
        blurResetBtn.connect('clicked', () => {
            blurAdj.value = 18;
        });

        blurRow.add_suffix(blurScale);
        blurRow.add_suffix(blurResetBtn);
        appearanceGroup.add(blurRow);

        // Dynamic visibility of blur row based on frosted glass toggle
        const updateBlurVisibility = () => {
            blurRow.visible = frostedRow.active;
        };
        frostedRow.connect('notify::active', updateBlurVisibility);
        updateBlurVisibility();

        // Max results (compact ActionRow + SpinButton)
        const maxResultsRow = new Adw.ActionRow({
            title: 'Максимум результатов',
            subtitle: 'Лимит элементов в списке поисковой выдачи (от 5 до 50)',
        });
        const maxResultsAdj = new Gtk.Adjustment({
            value: 30,
            lower: 5,
            upper: 50,
            step_increment: 5,
            page_increment: 10,
        });
        if (settings) {
            maxResultsAdj.value = settings.get_int('max-results');
            maxResultsAdj.connect('value-changed', () => {
                settings.set_int('max-results', Math.round(maxResultsAdj.value));
            });
        }
        const maxResultsSpin = new Gtk.SpinButton({
            adjustment: maxResultsAdj,
            numeric: true,
            valign: Gtk.Align.CENTER,
            halign: Gtk.Align.END,
            width_chars: 4,
            max_width_chars: 4,
        });
        maxResultsRow.add_suffix(maxResultsSpin);
        appearanceGroup.add(maxResultsRow);

        // Group 2: System Integration
        const integrationGroup = new Adw.PreferencesGroup({
            title: 'Интеграция с системой',
            description: 'Горячие клавиши и автозапуск',
        });
        page.add(integrationGroup);

        // Shortcut row with recorder
        const shortcutRow = new Adw.ActionRow({
            title: 'Клавиша вызова',
            subtitle: 'Нажмите кнопку справа, чтобы задать клавишу или сочетание',
        });
        const shortcutBtn = new Gtk.Button({
            label: 'Super',
            valign: Gtk.Align.CENTER,
        });
        shortcutBtn.add_css_class('pill');

        const updateShortcutLabel = (accel) => {
            if (accel === 'Super' || accel === 'Super_L' || accel === 'Super_R') {
                shortcutBtn.label = 'Super';
            } else {
                const [ok, keyval, mods] = Gtk.accelerator_parse(accel);
                const label = ok ? Gtk.accelerator_get_label(keyval, mods) : accel;
                shortcutBtn.label = label || accel;
            }
        };

        if (settings) {
            updateShortcutLabel(settings.get_string('shortcut-name') || 'Super');
        }

        let isRecording = false;
        let controller = null;
        let superHeld = false;
        let prevShortcut = 'Super';

        const finishRecording = () => {
            if (controller) {
                shortcutBtn.remove_controller(controller);
                controller = null;
            }
            isRecording = false;
            superHeld = false;
            shortcutBtn.remove_css_class('suggested-action');
        };

        const applyShortcut = (accel) => {
            if (settings) {
                settings.set_string('shortcut-name', accel);
            }
            // GNOME media-keys custom keybinding
            try {
                const schemaSource = Gio.SettingsSchemaSource.get_default();
                if (schemaSource && schemaSource.lookup('org.gnome.settings-daemon.plugins.media-keys', true)) {
                    const mediaKeys = new Gio.Settings({ schema_id: 'org.gnome.settings-daemon.plugins.media-keys' });
                    const POISK_PATH = '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/poisk/';
                    let bindings = mediaKeys.get_strv('custom-keybindings');

                    if (accel === 'Super' || accel === 'Super_L' || accel === 'Super_R') {
                        // Single Super key in GNOME
                        if (schemaSource.lookup('org.gnome.mutter', true)) {
                            const mutter = new Gio.Settings({ schema_id: 'org.gnome.mutter' });
                            mutter.set_string('overlay-key', 'Super_L');
                        }
                        mediaKeys.set_strv('custom-keybindings', bindings.filter(b => b !== POISK_PATH));
                    } else {
                        if (!bindings.includes(POISK_PATH)) {
                            bindings.push(POISK_PATH);
                            mediaKeys.set_strv('custom-keybindings', bindings);
                        }
                        const poiskKb = new Gio.Settings({
                            schema_id: 'org.gnome.settings-daemon.plugins.media-keys.custom-keybinding',
                            path: POISK_PATH,
                        });
                        poiskKb.set_string('name', 'Poisk');
                        poiskKb.set_string('command', 'poisk --toggle');
                        poiskKb.set_string('binding', accel);
                    }
                }
            } catch (e) {
                console.error('Poisk: failed to configure media-keys:', e);
            }
        };

        shortcutBtn.connect('clicked', () => {
            if (isRecording) {
                finishRecording();
                applyShortcut(prevShortcut);
                updateShortcutLabel(prevShortcut);
                return;
            }

            isRecording = true;
            superHeld = false;
            shortcutBtn.add_css_class('suggested-action');
            shortcutBtn.label = 'Нажмите клавиши... (Esc — отмена)';

            prevShortcut = settings ? settings.get_string('shortcut-name') || 'Super' : 'Super';

            // Temporarily silence mutter overlay key during recording
            try {
                const mutter = new Gio.Settings({ schema_id: 'org.gnome.mutter' });
                mutter.set_string('overlay-key', '');
            } catch (e) {}

            controller = new Gtk.EventControllerKey();
            controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);

            controller.connect('key-pressed', (ctrl, keyval, keycode, state) => {
                if (keyval === Gdk.KEY_Escape) {
                    finishRecording();
                    applyShortcut(prevShortcut);
                    updateShortcutLabel(prevShortcut);
                    return true;
                }

                if (keyval === Gdk.KEY_Super_L || keyval === Gdk.KEY_Super_R ||
                    keyval === Gdk.KEY_Meta_L || keyval === Gdk.KEY_Meta_R) {
                    superHeld = true;
                    return true;
                }

                if (keyval === Gdk.KEY_Shift_L || keyval === Gdk.KEY_Shift_R ||
                    keyval === Gdk.KEY_Control_L || keyval === Gdk.KEY_Control_R ||
                    keyval === Gdk.KEY_Alt_L || keyval === Gdk.KEY_Alt_R) {
                    return false;
                }

                superHeld = false;
                const modMask = Gtk.accelerator_get_default_mod_mask();
                const cleanedMods = state & modMask;
                const accel = Gtk.accelerator_name(keyval, cleanedMods);
                if (accel) {
                    finishRecording();
                    applyShortcut(accel);
                    updateShortcutLabel(accel);
                    return true;
                }
                return false;
            });

            controller.connect('key-released', (ctrl, keyval, keycode, state) => {
                if (superHeld && (keyval === Gdk.KEY_Super_L || keyval === Gdk.KEY_Super_R ||
                                  keyval === Gdk.KEY_Meta_L || keyval === Gdk.KEY_Meta_R)) {
                    finishRecording();
                    applyShortcut('Super');
                    updateShortcutLabel('Super');
                }
            });

            shortcutBtn.add_controller(controller);
            shortcutBtn.grab_focus();
        });

        shortcutRow.add_suffix(shortcutBtn);
        integrationGroup.add(shortcutRow);

        // Autostart Toggle
        const autostartRow = new Adw.SwitchRow({
            title: 'Автозапуск в фоне',
            subtitle: 'Запускать фоновую службу Poisk при входе в сеанс',
        });
        const autostartDir = GLib.build_filenamev([GLib.get_user_config_dir(), 'autostart']);
        const autostartPath = GLib.build_filenamev([autostartDir, 'io.github.mrlogiousbanana.poisk.desktop']);
        autostartRow.active = GLib.file_test(autostartPath, GLib.FileTest.EXISTS);
        autostartRow.connect('notify::active', () => {
            if (autostartRow.active) {
                try {
                    GLib.mkdir_with_parents(autostartDir, 0o755);
                    const content = `[Desktop Entry]\nName=Поиск\nGenericName=Application Launcher\nComment=Fast native launcher and productivity palette for Pantheon and Linux\nExec=poisk --background\nIcon=system-search\nTerminal=false\nType=Application\nCategories=Utility;Core;\nX-GNOME-Autostart-enabled=true\nNoDisplay=true\n`;
                    GLib.file_set_contents(autostartPath, content);
                } catch (e) {
                    console.error('Failed to create autostart desktop entry:', e);
                }
            } else {
                if (GLib.file_test(autostartPath, GLib.FileTest.EXISTS)) {
                    GLib.unlink(autostartPath);
                }
            }
        });
        integrationGroup.add(autostartRow);

        // Group 3: Search Providers
        const providersGroup = new Adw.PreferencesGroup({
            title: 'Источники поиска',
            description: 'Включение и отключение категорий поисковой выдачи',
        });
        page.add(providersGroup);

        const appsRow = new Adw.SwitchRow({
            title: 'Приложения',
            subtitle: 'Поиск по установленным приложениям системы (.desktop)',
        });
        if (settings) {
            settings.bind('enable-apps', appsRow, 'active', Gio.SettingsBindFlags.DEFAULT);
        }
        providersGroup.add(appsRow);

        const windowsRow = new Adw.SwitchRow({
            title: 'Открытые окна',
            subtitle: 'Быстрый поиск и переключение между запущенными окнами',
        });
        if (settings) {
            settings.bind('enable-windows', windowsRow, 'active', Gio.SettingsBindFlags.DEFAULT);
        }
        providersGroup.add(windowsRow);

        const calcRow = new Adw.SwitchRow({
            title: 'Калькулятор',
            subtitle: 'Мгновенное вычисление математических выражений',
        });
        if (settings) {
            settings.bind('enable-calc', calcRow, 'active', Gio.SettingsBindFlags.DEFAULT);
        }
        providersGroup.add(calcRow);

        // Group 4: About
        const aboutGroup = new Adw.PreferencesGroup({
            title: 'О программе',
        });
        page.add(aboutGroup);

        const versionRow = new Adw.ActionRow({
            title: 'Poisk 1.1.0',
            subtitle: 'GTK-ориентированный лёгкий аналог Spotlight',
        });
        const icon = new Gtk.Image({
            icon_name: 'system-search',
            pixel_size: 32,
        });
        versionRow.add_prefix(icon);
        aboutGroup.add(versionRow);

        const repoRow = new Adw.ActionRow({
            title: 'Репозиторий Poisk',
            subtitle: 'https://github.com/mrlogiousbanana/poisk',
        });
        const openRepoBtn = new Gtk.Button({
            icon_name: 'external-link-symbolic',
            valign: Gtk.Align.CENTER,
        });
        openRepoBtn.connect('clicked', () => {
            try {
                Gio.AppInfo.launch_default_for_uri('https://github.com/mrlogiousbanana/poisk', null);
            } catch (e) {
                console.error('Failed to open repo URL:', e);
            }
        });
        repoRow.add_suffix(openRepoBtn);
        aboutGroup.add(repoRow);
    }
}
