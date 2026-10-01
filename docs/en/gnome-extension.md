# GNOME Shell extension

[Français](../fr/extension-gnome.md)

Under Wayland, an application sees neither the focused window, nor the pointer outside its own windows, nor the lock screen. It cannot bring another window to the front either. GNOME Shell knows all of this. The `paros@paros.local` extension runs inside GNOME Shell and acts as a bridge.

Without the extension, everything described here is missing, and the rest of Paros works.

## Installing

```sh
./gnome-extension/install.sh
```

Then log out and back in. Under Wayland, GNOME loads an extension, or a new version of it, only when the session opens.

Check:

```sh
gnome-extensions info paros@paros.local      # State: ACTIVE
cat "$XDG_RUNTIME_DIR/paros/desktop.json"    # must contain "locked" and "covered"
```

If the file has no `"covered"`, GNOME still runs an older version of the extension: log out and back in.

Uninstall:

```sh
gnome-extensions disable paros@paros.local
rm -r ~/.local/share/gnome-shell/extensions/paros@paros.local
```

Declared GNOME Shell versions: 45 to 48. Tested with 46.

## What it brings

### Terminal to the front

Double-click a pet, or « Aller à son terminal » in the menu. The window is searched among those of the session process and its parents, then by its title if it contains the session name.

Limit: every GNOME Terminal window belongs to the same process. If the session is in a background tab, the title does not match and the window chosen may be the wrong one. The bell sent at the same time marks the right tab.

### Perch

A pet sometimes jumps onto the top edge of the focused window, more often while it thinks. It walks and sits there. If the window moves or loses the focus, it falls, and opens its umbrella when the fall is long. A window that is full screen, too narrow or too close to the top of the screen is not a perch.

### Sleeping by the pointer

When the pointer has not moved for a minute, the nearest free pet walks to it and falls asleep beside it. It wakes up when the pointer moves.

### Knocking

Paros knows whether the terminal of a session is focused. A session waiting for 20 seconds with an unfocused terminal: its pet runs to the screen edge nearest to the pointer and knocks twice. See [Claude Code](claude-code.md).

### Full screen

When an application takes a screen in full screen (game, video), the pets leave that screen and go to the nearest free one. If every screen is in full screen, they hide. They come back when the full screen ends.

### Lock screen

GNOME hides every application window behind the lock screen. The extension stays enabled while the screen is locked and draws a live copy of each pet window over it. The copies take neither clicks nor keys.

| While locked | |
|---|---|
| No text | No name, no tool in use, no bubble. Sounds go on |
| Screen on | GNOME switches the monitors off as soon as the screen locks. Paros switches them back on every second for 10 minutes (setting « Écran allumé après verrouillage », 0 to do nothing), then switches them off itself. Automatic suspend is held back meanwhile |
| Pets awake | They do not fall asleep for inactivity. At night, they sleep |
| Screen off | Paros barely draws: 2 frames per second |

The monitors may blink once when locking: GNOME switches them off, Paros switches them back on within a second.

If something goes wrong on the lock screen:

1. `Ctrl+Alt+F3`, log in on the console.
2. `gnome-extensions disable paros@paros.local`
3. `Ctrl+Alt+F2` (or `F1`) to come back.

## How it works

The extension writes the desktop state to `$XDG_RUNTIME_DIR/paros/desktop.json`, twice a second at most, and only when it changes. It rewrites it every 10 seconds anyway: a file older than 30 seconds tells Paros that the extension no longer runs.

```json
{
  "pointer": [612, 669],
  "locked": false,
  "mirrored": 0,
  "covered": [[1920, 0, 1920, 1080]],
  "active": {"x": 100, "y": 100, "width": 814, "height": 618, "fullscreen": false, "pid": 2888974}
}
```

| Field | Meaning |
|---|---|
| `pointer` | Pointer position |
| `locked` | The lock screen is up |
| `mirrored` | Number of pets copied onto the lock screen. For diagnosis |
| `covered` | Monitors under a full screen window |
| `active` | Focused window, or `null` |

Coordinates are screen coordinates, in pixels.

It also exposes one D-Bus method on `org.gnome.Shell`, object `/org/paros/Desktop`:

```
org.paros.Desktop.Activate(au pids, s title) -> b
```

Brings to the front a window owned by one of the processes, preferably the one whose title contains the text. Returns false when no window matches.

A pet window is recognized by its class (`Paros`), by the fact that it places itself, and by its width of more than 100 pixels.

## Without Paros

The extension does nothing but write this file and wait for a D-Bus call. With Paros closed, it has no visible effect.
