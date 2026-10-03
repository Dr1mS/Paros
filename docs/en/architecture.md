# Architecture

[Français](../fr/architecture.md)

## Principle

```
senses ──post──▶ Events ──listened by──▶ brain ──orders──▶ pets ──read by──▶ body
```

- A **sense** watches one thing of the world (Claude Code sessions, the clock, git, the desktop) and posts events. It knows neither the brain nor the pets.
- **Events** is the bus: a single signal, `sensed(event, data)`.
- The **brain** holds every rule: which event causes which behavior. It is the only place where an event becomes an order.
- A **pet** is a state machine. It carries out the orders and handles its own motion.
- The **body** draws the pet from its state. It decides nothing.

Adding a feature nearly always comes down to: a sense that posts an event, a rule in the brain, a state or an attribute of the pet, its drawing in the body.

## Files

| File | Role |
|---|---|
| `main.tscn`, `src/main.gd` | Main scene: `Pets`, `Brain`, `SettingsWindow`, and the senses under `Senses` |
| `project.godot` | Engine settings: transparent window, X11 driver, OpenGL ES driver, no audio on Linux |
| **`src/core/`** | |
| `input_method.gd` | Starts the app again without X11 input method server. Autoload `InputMethod`, the first one |
| `events.gd` | Event bus. Autoload `Events` |
| `settings.gd` | User settings. Autoload `Settings` |
| `focus.gd` | Focus timer. Autoload `Focus` |
| `sound.gd` | Synthesized sounds. Autoload `Sound` |
| `language.gd` | Interface language and French texts. Autoload `Language` |
| `desktop.gd` | Actions on the desktop: terminal to the front, bell, monitor power, reading `/proc`. Class `Desktop` |
| `autostart.gd` | Start at login. Class `Autostart` |
| **`src/senses/`** | |
| `claude_code_sense.gd` | Claude Code sessions: registry, transcripts, hook log |
| `git_sense.gd` | Git status of the folder of each session |
| `desktop_sense.gd` | File written by the GNOME extension, or by the Windows helper: focused window, pointer, lock, full screen |
| `system_sense.gd` | Temperature, load, battery |
| `clock_sense.gd` | Night and day |
| `idle_sense.gd` | User inactivity, asked from GNOME |
| `music_sense.gd` | Media players that play, asked from MPRIS |
| **`src/brain/`** | |
| `brain.gd` | Every rule |
| **`src/pet/`** | |
| `pets.gd` | Creates and removes the pets. Handles what takes two pets, the letters, and the frame rate |
| `pet_window.tscn` | Window of one pet: `Pet`, `Body`, `Bubble`, `Pointer`, `ContextMenu` |
| `letter_window.tscn`, `letter.gd` | Window of a letter that flies from a pet to another |
| `pet.gd` | State machine, window motion, flight, perch |
| `pet_body.gd` | Drawing |
| `pointer.gd` | Mouse on the pet |
| **`src/ui/`** | |
| `bubble.gd` | Bubble and card |
| `context_menu.gd` | Right-click menu |
| `settings_window.gd` | Settings window |
| **Outside `src/`** | |
| `hooks/claude-hook.sh` | Script called by the Claude Code hooks |
| `gnome-extension/` | GNOME Shell extension and its installer |
| `tests/` | Unit tests |
| `docs/` | Documentation, in English and in French, and screenshots |
| `run.sh`, `build.sh`, `test.sh` | Run, export, test |

## Windows

Each pet has its own system window: 300 × 272 pixels at size 1, transparent, without border, always on top, without focus. The pet does not move inside its window: the window moves across the desktop. A click shape (`mouse_passthrough_polygon`) limits the clickable area to the body.

A letter between two pets has its own small window, of the same kind, which lets every click through. At rest it is parked off screen, and serves again for the next letter.

The main Godot window cannot be hidden. It stays empty, parked off screen.

The application runs on X11, so through XWayland under Wayland: native Wayland does not let a window choose its position.

On Windows, a click shape (`mouse_passthrough_polygon`) is also a window region: it would cut the drawing. The polygon is then the whole window, and `Pointer` lets the clicks through by hand (`mouse_passthrough`) when the mouse is not over the body. The main window has no taskbar button.

## Windows helper

`windows/paros-desktop.ps1` is to Windows what the GNOME extension is to GNOME. `Desktop.start_helper()` copies it to the runtime folder (`%TEMP%\paros`) and starts it hidden; it ends with the app. It writes `desktop.json`, in the format of the extension (plus `idle_ms`, `music`, `cpu`, `battery`), and `processes.json` (pid → parent, creation time). Senses read these files: `DesktopSense`, `IdleSense`, `MusicSense`, `SystemSense`, and `Desktop.lineage` / `Desktop.is_process_running` instead of `/proc`.

Requests go the other way, as one file per request in `requests/`: `focus` (raise the terminal of a session: the window that holds its console, found by the console title, then by ancestor processes) and `ring` (bell of its console).

## The pet

### Wish and state

The brain gives a **wish** (`Pet.Wish`): `ROAM`, `SLEEP`, `THINK`, `ALERT`, `WAIT`. It is a standing order. The pet obeys as soon as it is at rest: a cheer in progress ends first.

The **state** (`Pet.State`) is what the pet does right now:

| State | End |
|---|---|
| `IDLE`, `SIT`, `WALK` | Random duration, or change of wish |
| `SLEEP`, `THINK`, `ALERT`, `WAIT` | When the wish changes. `SLEEP` goes through `STRETCH` |
| `STRETCH`, `CHEER`, `GREET`, `GLARE`, `HIGH_FIVE`, `WORRY`, `ROAST`, `KNOCK`, `SWEEP`, `THROW`, `READ`, `NOD` | Fixed duration, in `Pet.TIMED` |
| `CLIMB` | Arrival on the perch |
| `CARRIED` | When the mouse lets go |
| `FALL` | Landing |

### Attributes

The brain also sets attributes that the body draws on top of the state: `label`, `color`, `accessory`, `caption`, `minis`, `urgent`, `fullness`, `baggage`, `hard_hat`, `lost`, `tapping`, `meditating`, `headlamp`, `cool`, `grooving`, `mail`, `serving`, `discreet`, `rooted`, `pace`, `dispute`, `perch`, `avoid`.

### Floor

The floor of a pet is the bottom of the usable area of its screen. The walk area extends over the free screens placed side by side. A perch replaces the floor with the top edge of a rectangle. The screen layout is read four times a second, not every frame: asking the display server is slow.

## Events

An event has a name and a dictionary of data.

### Claude Code sessions — `claude_code_sense.gd`

All carry `session`, the session id.

| Event | Data | Effect in the brain |
|---|---|---|
| `session_opened` | `name`, `color`, `cwd`, `last_prompt`, `pid`, `context`, `summary` | Creates the pet, dresses it |
| `session_changed` | the same | Dresses it again |
| `session_closed` | | Removes the pet |
| `session_phase` | `phase` (`idle`, `working`, `waiting`), `since` | Sets the wish |
| `session_activity` | `tool`, `detail` | Caption |
| `session_quiet` | `level` (0, 1, 2) | Foot tapping, meditation |
| `session_subagents` | `count` | Small pets |
| `session_background` | `background`, `servers` | Hourglass while the turn is over and a background task still runs. No "Task done!". Green eyes while a server runs |
| `session_message_sent` | `to`, the name of a session | The pet throws a letter to the pet of that session. Once its turn is over, it waits for the answer while that session works |
| `session_mail` | `mail` | Mailbox while messages of other sessions wait to be read. Reading of the letter when one leaves |
| `session_collision` | `other`, `file`, `path` | The two pets glare, bubble, sound. Rivals for 10 minutes |
| `session_turn` | `origin` (`human`, `peer`, `task-notification`…), `from` | A turn started by another session ends with a nod, not a cheer |
| `session_needs_you` | `detail` | Bubble |
| `session_finished` | | Jump, bubble, sound |
| `session_tests_passed` | | Jump, bubble, sound |
| `session_tool_failed` | `tool`, `detail`, `kind` | Shake, sound |

### Git — `git_sense.gd`

| Event | Data | Effect |
|---|---|---|
| `repo_state` | `session`, `branch`, `dirty`, `behind`, `conflict` | Name tag, folders carried, hard hat, map |
| `repo_cleaned` | `session` | Broom, sunglasses |

### Desktop — `desktop_sense.gd`

| Event | Data | Effect |
|---|---|---|
| `desktop_state` | `active`, `fullscreen`, `pid`, `covered` | Perch, screens to avoid, terminal focus |
| `pointer_at` | `position` | Kept for the knock |
| `pointer_idle` | `position` | A pet comes to sleep beside it |
| `pointer_moved` | | It wakes up |
| `screen_locked` | `locked` | Discreet mode, screen held on |

### Other senses

| Event | Data | Emitter | Effect |
|---|---|---|---|
| `night`, `day` | | `clock_sense.gd` | Sleep, headlamp |
| `user_idle`, `user_active` | | `idle_sense.gd` | Sleep |
| `cpu_hot` | | `system_sense.gd` | Campfire |
| `battery_low` | `percent` | `system_sense.gd` | Bubble |
| `system_load` | `load` | `system_sense.gd` | Walk speed |
| `music` | `playing` | `music_sense.gd` | Nod and note |

### Pets and interface

| Event | Data | Emitter | Effect |
|---|---|---|---|
| `pointer_tap`, `pointer_double`, `pointer_grab`, `pointer_drop` | `pet` | `pet/pointer.gd` | Cheer, terminal, carried, released |
| `pointer_enter`, `pointer_leave` | `pet` | `pet/pointer.gd` | Card |
| `letter_landed` | `pet` | `pet/letter.gd` | The letter goes to the mailbox, or is read if the session took it already |
| `pointer_menu` | `pet` | `pet/pointer.gd` | Opens the menu of that pet |
| `files_dropped` | `pet`, `files` | `pet/pointer.gd` | Clipboard |
| `pet_landed`, `pet_knocked` | `pet` | `pet/pet.gd` | Sounds |
| `locate_requested` | `pet` | `ui/context_menu.gd` | Terminal bell |
| `settings_requested` | | `ui/context_menu.gd` | Opens the settings |
| `focus_started`, `focus_finished`, `break_finished` | | `core/focus.gd` | Bubbles |

## Recipes

### Adding a sense

1. Create `src/senses/my_sense.gd`, which calls `Events.post(&"my_event", {...})`. Post only when something changes.
2. Add it as a node under `Senses` in `main.tscn`.
3. Add the rule in `_on_sensed` of `brain.gd`.
4. Describe the event in the header of the sense and in this document.

A sense that runs a program does it in a thread (`Thread`): `OS.execute` blocks, and a blocked frame freezes the pets. See `git_sense.gd`.

### Adding a short behavior

1. Add the state to `Pet.State` and its duration to `Pet.TIMED`.
2. Add it to the branch of the fixed-duration states in `Pet._process`.
3. Add a public method that calls `_play(State.MY_STATE)`.
4. Draw the pose in `pet_body.gd`: offsets in the `match state` of `_draw`, extra shapes with `_blocks`.
5. Call the method from a rule of the brain.

### Adding an accessory

Add an entry to `ACCESSORIES` in `pet_body.gd` (`room`: space taken above the head, `blocks`: shapes and colors), and raise `Pet.ACCESSORY_COUNT`. Shapes are in grid units: 1 unit is 9 pixels, the origin is under the feet, Y is negative upward.

### Adding a sound

Add an entry to `TUNES` in `sound.gd`: a list of notes, each with its duration then its frequencies. Then `Sound.play(&"name")` from the brain.

### Adding a setting

1. Add the key and its default value to `DEFAULTS` in `settings.gd`.
2. Add a line to `FIELDS` in `settings_window.gd`.
3. Read the value with `Settings.value("section", "key")` at the moment it is used, so that a change applies at once.

A test checks that every setting of `DEFAULTS` is in the window.

### Adding a displayed text

Write it in English, as the argument of `tr()`: `pet.say(tr("Task done!"))`. A text with a number keeps its placeholder: `tr("Focus: %d min") % minutes`. The text of a label of the settings window is translated by the control itself.

Then add its French version to `FRENCH` in `language.gd`. A test checks that both versions have the same placeholders, and that every label of the settings has a French text.

## Conventions

- Code and comments in English. Displayed texts are written in English in the code and translated to French in `language.gd`.
- A comment says why, not what the line does.
- Rules go in the brain. A sense never orders a pet.
- Nothing is drawn from an image file.
