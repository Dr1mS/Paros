// Bridge between GNOME Shell and Paros.
//
// Writes the desktop state to $XDG_RUNTIME_DIR/paros/desktop.json:
//   {"pointer": [x, y], "locked": bool, "mirrored": n,
//    "active": {"x", "y", "width", "height", "fullscreen", "pid"} | null}
// locked: the lock screen is up. mirrored: number of pets shown on it.
// and offers one D-Bus method on org.gnome.Shell, object /org/paros/Desktop:
//   org.paros.Desktop.Activate(au pids, s title) -> b
// which brings to the front a window owned by one of the processes, the one
// whose title contains the given text when there are several.
//
// While the screen is locked, shows the pets on the lock screen. GNOME hides
// every application window behind the lock screen: the extension draws live
// copies of the pet windows over it. The copies take no input.
// The extension stays enabled on the lock screen for this ("session-modes"
// in metadata.json).

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const INTERFACE = `
<node>
  <interface name="org.paros.Desktop">
    <method name="Activate">
      <arg type="au" direction="in" name="pids"/>
      <arg type="s" direction="in" name="title"/>
      <arg type="b" direction="out" name="found"/>
    </method>
  </interface>
</node>`;

const POLL_MS = 500;
// The file is rewritten at least this often, so that Paros can tell a live
// extension from a file left behind.
const HEARTBEAT_MS = 10000;

export default class ParosExtension extends Extension {
    enable() {
        this._folder = GLib.build_filenamev([GLib.get_user_runtime_dir(), 'paros']);
        this._path = GLib.build_filenamev([this._folder, 'desktop.json']);
        GLib.mkdir_with_parents(this._folder, 0o700);
        this._written = '';
        this._writtenAt = 0;
        // Window actor of a pet -> its copy on the lock screen.
        this._mirrors = new Map();
        this._lockLayer = null;

        this._dbus = Gio.DBusExportedObject.wrapJSObject(INTERFACE, this);
        this._dbus.export(Gio.DBus.session, '/org/paros/Desktop');

        this._timer = GLib.timeout_add(GLib.PRIORITY_LOW, POLL_MS, () => {
            this._write();
            return GLib.SOURCE_CONTINUE;
        });
        this._write();
    }

    disable() {
        GLib.source_remove(this._timer);
        this._timer = null;
        this._clearLockScreen();
        this._dbus.unexport();
        this._dbus = null;
        GLib.unlink(this._path);
    }

    Activate(pids, title) {
        const owned = global.get_window_actors()
            .map(actor => actor.meta_window)
            .filter(window => pids.includes(window.get_pid()));
        if (owned.length === 0)
            return false;
        const named = title ? owned.find(window => (window.get_title() ?? '').includes(title)) : null;
        Main.activateWindow(named ?? owned[0]);
        return true;
    }

    // A pet window: owned by Paros, placed by Paros itself, larger than the
    // small empty main window.
    _isPet(window) {
        return window.get_wm_class() === 'Paros' && window.is_override_redirect() &&
            window.get_frame_rect().width > 100;
    }

    // Keeps one copy per pet window on the lock screen, none when unlocked.
    // Never lets an error reach the lock screen: on failure, shows nothing.
    _mirrorPets(locked) {
        try {
            if (!locked) {
                this._clearLockScreen();
                return;
            }
            if (!this._lockLayer) {
                this._lockLayer = new Clutter.Actor({reactive: false});
                Main.layoutManager.screenShieldGroup.add_child(this._lockLayer);
            }
            const pets = new Set(global.get_window_actors().filter(actor => this._isPet(actor.meta_window)));
            for (const [actor, mirror] of this._mirrors) {
                if (!pets.has(actor)) {
                    mirror.destroy();
                    this._mirrors.delete(actor);
                }
            }
            for (const actor of pets) {
                if (this._mirrors.has(actor))
                    continue;
                const mirror = new Clutter.Clone({source: actor, reactive: false});
                // Follows the window as the pet walks.
                mirror.add_constraint(new Clutter.BindConstraint({
                    source: actor, coordinate: Clutter.BindCoordinate.POSITION,
                }));
                this._lockLayer.add_child(mirror);
                this._mirrors.set(actor, mirror);
            }
        } catch (error) {
            console.error(`Paros: cannot show the pets on the lock screen: ${error.message}`);
            this._clearLockScreen();
        }
    }

    _clearLockScreen() {
        this._mirrors.clear();
        // Destroys the copies with it.
        this._lockLayer?.destroy();
        this._lockLayer = null;
    }

    _write() {
        const locked = Main.sessionMode.isLocked;
        this._mirrorPets(locked);
        const [x, y] = global.get_pointer();
        const window = global.display.focus_window;
        let active = null;
        if (window) {
            const frame = window.get_frame_rect();
            active = {
                x: frame.x, y: frame.y, width: frame.width, height: frame.height,
                fullscreen: window.is_fullscreen(), pid: window.get_pid(),
            };
        }
        const state = JSON.stringify({pointer: [x, y], locked, mirrored: this._mirrors.size, active});
        const now = GLib.get_monotonic_time() / 1000;
        if (state === this._written && now - this._writtenAt < HEARTBEAT_MS)
            return;
        this._written = state;
        this._writtenAt = now;
        try {
            GLib.file_set_contents(this._path, state);
        } catch (error) {
            console.error(`Paros: cannot write ${this._path}: ${error.message}`);
        }
    }
}
