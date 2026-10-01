# Claude Code

[Français](../fr/claude-code.md)

Paros follows the interactive Claude Code sessions of the machine, for the current user. Subagents and background sessions get no pet. Cloud sessions (claude.ai/code) and sessions on another machine are not seen.

## What a pet shows

### Without the hooks

| Session | Pet |
|---|---|
| Open | A pet appears, with the name and color of the session |
| Working | Stays in place, looks up, three dots fill up above its head |
| Waiting for a permission or an answer | Waves its arms in turn, blinking "!" |
| At rest | Walks, sits, sleeps |
| Context 75 % full or more | Its head smokes |
| Closed | The pet goes away |

### With the hooks

| Event | Pet |
|---|---|
| Tool started | Caption above the head: "Edit · pet.gd", "Bash · Run the tests". On several lines when needed |
| Permission request | Bubble with the message of Claude |
| End of turn | Jump, hearts, bubble « Tâche finie ! », two rising notes |
| Subagent started | A small pet runs off from the big one with a sheet of paper, and stays beside it. Four at most |
| Tests passed | Jump, bubble « Tests verts ! » |
| Tests failed | Shakes, bubble « Tests rouges », two falling notes |
| Other failed command | Shakes, drop of sweat, two falling notes |
| No event for 8 seconds while working | Taps its foot, looks down |
| No event for 25 seconds | Meditates: sitting, floating above the floor, math signs circling around |
| Waiting for more than 2 minutes | Jumps higher, reminder bubble every minute |
| Waiting for 20 seconds, terminal not focused | Runs to the screen edge nearest to the pointer and knocks twice. Again every 30 seconds |

A command counts as a test when it contains `pytest`, `jest`, `vitest`, `phpunit`, `rspec`, `ctest`, or `test` after `npm`, `pnpm`, `yarn`, `bun`, `cargo`, `go`, `dotnet`, `mvn`, `gradle`, `make`, `composer`.

The silence of the hooks does not say why the session is silent: long thinking of the model and a slow network look the same.

The reminder and the knock only happen when the terminal of the session is not focused. Without the [GNOME extension](gnome-extension.md) the focus is not known: Paros assumes the terminal does not have it.

### Git status of the session folder

Read every 10 seconds (`git status --porcelain=v2 --branch` and `git diff --shortstat HEAD`), without taking a lock on the repository.

| Status | Pet |
|---|---|
| Uncommitted lines: 1, 50, 300 or more | Pile of 1, 2 or 3 folders on its arm. Each folder slows the walk by 20 % |
| Merge, rebase or cherry-pick to finish | Hard hat, warning sign |
| Behind the upstream branch | Map in hand, scratches its head, "?" |
| Commit that leaves the working tree clean | Three strokes of a broom, then sunglasses for a minute |
| Same folder and same branch as another session | The two pets glare at each other when they meet |

Being behind upstream is as of the last `git fetch`. Paros runs none.

## Where the information comes from

| Source | Gives | Note |
|---|---|---|
| `~/.claude/sessions/<pid>.json` | Open sessions, name, folder, status (`busy`, `waiting`, `idle`) | Internal Claude Code format, not documented: an update may change it |
| Session transcript, in `~/.claude/projects/` | Color (`/color`), last prompt, context tokens | Only the lines added since the last reading are read |
| `$XDG_RUNTIME_DIR/paros/claude-events.log` | Tools, subagents, failures, end of turn, permission requests | Written by `hooks/claude-hook.sh` |
| Session folder | Git status | Through the `git` command |

If `CLAUDE_CONFIG_DIR` is set, it replaces `~/.claude`.

A session whose process no longer exists is ignored, even if its file was left behind.

### Context

The context tokens are the sum of the input tokens of the last answer of the model (input, cache write, cache read), rounded to 10,000. The size of the context window of the model is written nowhere: it is a setting (« Contexte du modèle, en milliers de tokens », 1000 by default). The head smokes at 75 % of that size.

## Installing the hooks

In `~/.claude/settings.json`, declare the script for each of these events: `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Notification`, `SubagentStart`, `SubagentStop`, `Stop`.

```json
{
  "hooks": {
    "PreToolUse": [
      { "hooks": [{ "type": "command", "command": "/path/to/Paros/hooks/claude-hook.sh", "async": true }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "/path/to/Paros/hooks/claude-hook.sh", "async": true }] }
    ]
  }
}
```

Repeat the same block for the six other events. Hooks in `~/.claude/settings.json` apply to every session of the user, whatever the project. A session that is already open picks them up without a restart.

The script cannot disturb a session: it runs in the background (`async`), prints nothing and always exits with 0.

### What the script writes

One line per event, six fields separated by tabs:

| Field | Example |
|---|---|
| Event | `PreToolUse` |
| Session id | `c1c3d9b6-…` |
| Notification type | `permission_prompt` |
| Tool | `Edit` |
| Detail, 120 characters at most | Name of the file touched, else description of the command, else message of the notification |
| Kind | `test` when the command runs tests, empty otherwise |

## Privacy

The file `$XDG_RUNTIME_DIR/paros/claude-events.log` holds, in clear text, the tool names, the names of the files touched and the descriptions of the commands of every session. It is in the runtime folder of the user, readable by that user only, and goes away when the user logs out of the system.

On screen, a pet shows the session name, the git branch and the tool in use. The hover card also shows the folder and the start of the last prompt. On the lock screen, no text is shown.

## Limits

- `Stop` also fires on `/clear` and on a compaction: the pet then jumps although no task is done.
- The subagent count follows the `SubagentStart` and `SubagentStop` events. A missed event makes it wrong until the session closes.
- The script needs a POSIX shell. On Windows, Claude Code runs hooks with Git Bash.
