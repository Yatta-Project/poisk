import Shell from 'gi://Shell';
import Clutter from 'gi://Clutter';
import Meta from 'gi://Meta';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const DBUS_IFACE = `
<node>
  <interface name="org.gnome.Shell.Extensions.PoiskBlur">
    <method name="SetBlurConfig">
      <arg type="b" direction="in" name="is_island"/>
      <arg type="i" direction="in" name="radius"/>
      <arg type="d" direction="in" name="opacity"/>
    </method>
    <method name="SetPillGeometry">
      <arg type="i" direction="in" name="bubble_x"/>
      <arg type="i" direction="in" name="bubble_y"/>
      <arg type="i" direction="in" name="bubble_w"/>
      <arg type="i" direction="in" name="bubble_h"/>
      <arg type="i" direction="in" name="cap_x"/>
      <arg type="i" direction="in" name="cap_y"/>
      <arg type="i" direction="in" name="cap_w"/>
      <arg type="i" direction="in" name="cap_h"/>
    </method>
    <method name="RemoveBlur">
    </method>
  </interface>
</node>`;

export default class PoiskBlurExtension extends Extension {
    enable() {
        this._isIsland = false;
        this._radius = 18;
        this._opacity = 0.84;
        this._bubbleGeom = { x: 0, y: 0, w: 54, h: 54 };
        this._capGeom = { x: 68, y: 0, w: 680, h: 56 };
        this._activeEffects = new Map();
        this._subActors = new Map();

        // Export D-Bus interface
        this._dbusImpl = Gio.DBusExportedObject.wrapJSObject(DBUS_IFACE, this);
        this._dbusImpl.export(Gio.DBus.session, '/org/gnome/Shell/Extensions/PoiskBlur');

        // Watch for window-created signals
        this._windowCreatedId = global.display.connect('window-created', (display, window) => {
            this._checkWindow(window);
        });

        // Check existing windows
        for (const actor of global.get_window_actors()) {
            const metaWin = actor.meta_window;
            if (metaWin) {
                this._checkWindow(metaWin);
            }
        }
    }

    disable() {
        if (this._windowCreatedId) {
            global.display.disconnect(this._windowCreatedId);
            this._windowCreatedId = 0;
        }

        this._clearAllBlur();

        if (this._dbusImpl) {
            this._dbusImpl.unexport();
            this._dbusImpl = null;
        }
    }

    SetBlurConfig(isIsland, radius, opacity) {
        this._isIsland = Boolean(isIsland);
        this._radius = Math.max(0, Math.min(48, radius));
        this._opacity = Math.max(0.3, Math.min(1.0, opacity));
        this._updateAllBlur();
    }

    SetPillGeometry(bx, by, bw, bh, cx, cy, cw, ch) {
        this._bubbleGeom = { x: bx, y: by, w: bw, h: bh };
        this._capGeom = { x: cx, y: cy, w: cw, h: ch };
        this._updateAllBlur();
    }

    RemoveBlur() {
        this._clearAllBlur();
    }

    _isPoiskWindow(metaWin) {
        if (!metaWin) return false;
        const wmClass = metaWin.get_wm_class() || '';
        const appId = metaWin.get_sandboxed_app_id() || metaWin.get_id() || '';
        const title = metaWin.get_title() || '';
        return wmClass.includes('poisk') || appId.includes('poisk') || title === 'Поиск';
    }

    _checkWindow(metaWin) {
        if (this._isPoiskWindow(metaWin)) {
            if (typeof metaWin.hide_from_window_list === 'function') {
                metaWin.hide_from_window_list();
            }
            const actor = metaWin.get_compositor_private();
            if (actor) {
                this._applyBlurToActor(actor, metaWin);
            }
        }
    }

    _applyBlurToActor(actor, metaWin) {
        this._removeBlurFromActor(actor);

        if (this._isIsland) {
            // Island mode: create two separate background blur sub-actors (satellite squircle and search pill)
            // with 0 blur in the 14px gap
            const bubbleBlur = new Clutter.Actor({
                x: this._bubbleGeom.x,
                y: this._bubbleGeom.y,
                width: this._bubbleGeom.w,
                height: this._bubbleGeom.h,
                opacity: 255
            });
            const bubbleEffect = new Shell.BlurEffect({
                brightness: this._opacity,
                sigma: this._radius,
                mode: Shell.BlurMode.BACKGROUND
            });
            bubbleBlur.add_effect_with_name('poisk-bubble-blur', bubbleEffect);

            const capBlur = new Clutter.Actor({
                x: this._capGeom.x,
                y: this._capGeom.y,
                width: this._capGeom.w,
                height: this._capGeom.h,
                opacity: 255
            });
            const capEffect = new Shell.BlurEffect({
                brightness: this._opacity,
                sigma: this._radius,
                mode: Shell.BlurMode.BACKGROUND
            });
            capBlur.add_effect_with_name('poisk-cap-blur', capEffect);

            actor.insert_child_at_index(bubbleBlur, 0);
            actor.insert_child_at_index(capBlur, 0);

            this._subActors.set(actor, [bubbleBlur, capBlur]);
        } else {
            // Monolithic mode: apply Shell.BlurEffect directly to the window actor
            const effect = new Shell.BlurEffect({
                brightness: this._opacity,
                sigma: this._radius,
                mode: Shell.BlurMode.BACKGROUND
            });
            actor.add_effect_with_name('poisk-blur-effect', effect);
            this._activeEffects.set(actor, effect);
        }
    }

    _removeBlurFromActor(actor) {
        if (this._activeEffects.has(actor)) {
            actor.remove_effect_by_name('poisk-blur-effect');
            this._activeEffects.delete(actor);
        }
        if (this._subActors.has(actor)) {
            const sub = this._subActors.get(actor);
            for (const child of sub) {
                actor.remove_child(child);
                child.destroy();
            }
            this._subActors.delete(actor);
        }
    }

    _updateAllBlur() {
        for (const actor of global.get_window_actors()) {
            const metaWin = actor.meta_window;
            if (this._isPoiskWindow(metaWin)) {
                this._applyBlurToActor(actor, metaWin);
            }
        }
    }

    _clearAllBlur() {
        for (const actor of global.get_window_actors()) {
            this._removeBlurFromActor(actor);
        }
        this._activeEffects.clear();
        this._subActors.clear();
    }
}
