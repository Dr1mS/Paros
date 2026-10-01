# Development

[Français](../fr/developpement.md)

## Requirements

- Godot 4.7 or later. `GODOT_PATH` must point to its binary, otherwise `godot` is looked up in `PATH`.
- `git`, for the git sense and for one of the tests.
- For sounds on Linux: `pw-play`, `paplay` or `aplay`.
- For the export: the Godot export templates of the same version as the editor.

```sh
export GODOT_PATH="/path/to/godot"
```

## Running from the sources

```sh
./run.sh
```

After a clone, or after adding a script with `class_name`, run the import once:

```sh
"$GODOT_PATH" --headless --path . --import
```

## Tests

```sh
./test.sh                      # every test
./test.sh test_pet test_brain  # some files
```

The tests run without a display, in a few seconds. The script exits with 1 when a test fails.

Settings, the autostart file and the runtime folder are redirected to a temporary folder: nothing of the user is touched. Without a display, the actions on the desktop (`Desktop`) and the sounds do nothing.

| File | What it covers |
|---|---|
| `test_pet.gd` | State machine of a pet: wishes, short states, flight and bounces, umbrella, errands, perch, discreet mode |
| `test_pets.gd` | Meetings, rivalry, high five, frame rate |
| `test_brain.gd` | Rules: one pet per session, wishes, sleep, lock screen, git, context, knock, tower, card |
| `test_senses.gd` | Reading of the Claude Code registry and transcripts, hook log, git output, desktop file, hook script |
| `test_core.gd` | Settings, focus timer, sound synthesis and WAV file, bubble, autostart |

### Writing a test

A `tests/test_*.gd` file extends `res://tests/test_case.gd`. Each method whose name starts with `test_` is a test. Each test runs in a fresh instance.

```gdscript
extends "res://tests/test_case.gd"

func test_pet_thinks_when_asked() -> void:
	var pet := make_pet()
	pet.wish = Pet.Wish.THINK
	step(pet, 0.1)
	check_equal(pet.state, Pet.State.THINK, "thinks")
```

| Helper | Role |
|---|---|
| `check(condition, what)`, `check_equal(actual, wanted, what)`, `check_near(actual, wanted, margin, what)` | Checks |
| `make_pet()` | A pet standing still on the floor of `AREA` |
| `step(pet, seconds)` | Advances the time of the pet |
| `stand(pet)` | Puts it back at rest, with nothing planned |
| `record_events()`, `event_names()`, `last_event(name)` | Events posted on the bus |
| `before_each()`, `after_each()` | Before and after each test |

Time only advances through `step`: a test does not depend on the clock. Randomness is seeded before each test.

What the tests do not cover: drawing, the real mouse, real windows and real screens, the GNOME extension.

## Exporting a binary

```sh
./build.sh          # build/paros.x86_64
./build.sh Windows  # build/paros.exe
```

The export templates are installed from the editor: Editor > Manage Export Templates. They go to `~/.local/share/godot/export_templates/`.

The binary is standalone: Godot is no longer needed to run it. `tests/`, `hooks/`, `gnome-extension/` and `docs/` are not included. `build/` is not tracked by git.

After a change to the code, rebuild the binary, otherwise `./run.sh` without Godot runs the old one.

## Performance

Measured on an Intel HD 530, exported binary, one pet, mouse moving.

| | Share of one core |
|---|---|
| Total | 6 to 7 % |
| X11 event thread of the engine | 2 to 4 %, depending on mouse activity |
| Main thread: scripts and rendering | 1.5 to 2 % |
| Memory | 150 MB |

What mattered, in order:

| Choice | Gain | Where |
|---|---|---|
| OpenGL ES driver instead of OpenGL | Rendering twice as cheap with several windows | `project.godot` |
| No audio driver on Linux | 4 %: its thread ran all the time, sound or not | `project.godot`, `sound.gd` |
| 12 frames per second when every pet is calm, 30 otherwise | | `pets.gd` |
| Drawing only when the picture changes: a calm pet animates by steps, 6 per second | | `pet_body.gd`, `low_processor_mode` |
| Screen layout read 4 times a second | | `pet.gd` |
| 2 frames per second with the screen locked and off | | `pets.gd` |

What is left is the engine itself. Its X11 event thread receives every mouse motion, wherever the pointer is. Reducing it would mean patching Godot.

To measure, read the CPU time per thread in `/proc/<pid>/task/*/stat` over a fixed duration. `perf` and `strace -p` are often refused without privileges.

Two traps met on the way:

- A window off screen with vertical sync waits one second per frame under OpenGL ES. So neither the main window nor the pet windows use vertical sync.
- The engine keeps the screen from going to sleep by default (`keep_screen_on`). It is turned off in `project.godot`.

## Platforms

| | Status |
|---|---|
| Linux, GNOME, Wayland | Tested |
| Linux, other desktop | The core works. Inactivity sense and extension missing |
| Windows | Binary built, never run. Inactivity sense, system alerts, terminal bell and extension missing. Hooks need Git Bash |

What is specific to Linux is isolated: reading `/proc` and `/sys`, `gdbus`, the `$XDG_RUNTIME_DIR` folder, the audio players. Elsewhere these parts stay silent.

## Known limits

- **Undocumented formats**: `~/.claude/sessions/*.json` and the transcripts. A Claude Code update may break session tracking.
- **GNOME extension**: to be checked again with each GNOME version. Any change needs logging out and back in.
- **Monitors under the lock screen**: Paros switches them back on every second, for lack of a way to stop GNOME from switching them off. They may blink once.
- **Terminal tabs**: the right window is not always found when the session is in a background tab.
- **Context window**: its size cannot be read, it is a setting.
- **On top of everything**: the pet windows sit above the others. Without the extension they stay visible over a full screen application.
- **Mouse wheel over a number field of the settings**: changes the value instead of scrolling.
- **Interface language**: French only.

## Troubleshooting

| Symptom | Likely cause | Remedy |
|---|---|---|
| `godot: not found` | `GODOT_PATH` not set in this terminal | Export it, or build the binary with `./build.sh` |
| No pet for a session | Session not interactive, or registry format changed | `cat ~/.claude/sessions/*.json`: the `kind` field must be `interactive` |
| No bubble, no caption | Hooks not installed | See [Claude Code](claude-code.md#installing-the-hooks), then `tail $XDG_RUNTIME_DIR/paros/claude-events.log` |
| Double-click does nothing, no perch | Extension missing, or an old version still in memory | See [GNOME extension](gnome-extension.md#installing) |
| No sound | No audio player found | Install `pipewire-bin` (`pw-play`) or `pulseaudio-utils` (`paplay`) |
| The pet keeps knocking | Extension missing: the terminal focus is not known | Install the extension, or untick « Toquer quand le terminal n'a pas le focus » |
| The screen no longer turns off under the lock screen | Screen hold | Set « Écran allumé après verrouillage » to 0 |
| Lock screen stuck | Extension | `Ctrl+Alt+F3`, `gnome-extensions disable paros@paros.local` |

To see script errors: run from the sources with `./run.sh` in a terminal.
