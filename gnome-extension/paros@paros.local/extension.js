// Bridge between GNOME Shell and Paros.
//
// Writes the desktop state to $XDG_RUNTIME_DIR/paros/desktop.json:
//   {"pointer": [x, y], "active": {"x", "y", "width", "height", "fullscreen", "pid"} | null}
// and offers one D-Bus method on org.gnome.Shell, object /org/paros/Desktop:
//   org.paros.Desktop.Activate(au pids, s title) -> b
// which brings to the front a window owned by one of the processes, the one
// whose title contains the given text when there are several.

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

    _write() {
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
        const state = JSON.stringify({pointer: [x, y], active});
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
