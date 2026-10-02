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
| Waits for a task it started in the background | Sits and watches an hourglass: the sand runs down, the hourglass turns over |
| Writes to another session | Throws a letter, which flies to the pet of that session |
| Got a message of another session while working | A mailbox stands beside the pet, flag up. With the number of letters when more than one waits |
| Wrote to another session, which still works on it | Sits by the hourglass, turned toward the pet of that session |
| Reads that message | The mailbox goes away. The pet holds the letter out and reads it |
| Left a server running in the background | Its eyes glow green, slowly, on and off |
| Could not write a file that another session had just changed | The two pets turn to each other and glare. Bubble with the file and the other session, two falling notes. For 10 minutes they glare again when they meet |
| At rest | Walks, sits, sleeps |
| Context 75 % full or more | Its head smokes |
| Closed | The pet goes away |

### With the hooks

| Event | Pet |
|---|---|
| Tool started | Caption above the head: "Edit · pet.gd", "Bash · Run the tests". On several lines when needed |
| Permission request | Bubble with the message of Claude |
| End of a turn you asked for | Jump, hearts, bubble "Task done!", two rising notes |
| End of a turn another session asked for | Nods twice. No bubble, no sound |
| Subagent started | A small pet runs off from the big one with a sheet of paper, and stays beside it. Four at most |
| Tests passed | Jump, bubble "Green tests!" |
| Tests failed | Shakes, bubble "Red tests", two falling notes |
| Other failed command | Shakes, drop of sweat, two falling notes |
| No event for 8 seconds while working | Taps its foot, looks down |
| No event for 25 seconds | Meditates: sitting, floating above the floor, math signs circling around |
| Waiting for more than 2 minutes | Jumps higher, reminder bubble every minute |
| Waiting for 20 seconds, terminal not focused | Runs to the screen edge nearest to the pointer and knocks twice. Again every 30 seconds |

A command counts as a test when it contains `pytest`, `jest`, `vitest`, `phpunit`, `rspec`, `ctest`, or `test` after `npm`, `pnpm`, `yarn`, `bun`, `cargo`, `go`, `dotnet`, `mvn`, `gradle`, `make`, `composer`.

The silence of the hooks does not say why the session is silent: long thinking of the model and a slow network look the same.

The reminder and the knock only happen when the terminal of the session is not focused. Without the [GNOME extension](gnome-extension.md) the focus is not known: Paros assumes the terminal does not have it.

### Waiting for a background task

A session can end its turn while a command or an agent it started in the background still runs: a server that boots, a long build. It then waits for that task, not for you. The pet does not say "Task done!": it sits by an hourglass until the task ends and the session resumes. The hover card reads "Waiting for a background task". Such a session does not join the tower.

A server is not a task to wait for: it runs until it is stopped. A command started in the background counts as a server when it contains `vite`, `nodemon`, `webpack-dev-server`, `http-server`, `live-server`, `browser-sync`, `uvicorn`, `gunicorn`, `dev`, `start`, `serve`, `watch` or `preview` after `npm`, `pnpm`, `yarn` or `bun`, `next dev`, `astro dev`, `nuxt dev`, `ng serve`, `jekyll serve`, `hugo serve`, `-m http.server`, `runserver`, `flask run`, `php -S`, `docker compose up`, `--watch` or `tail -f`. The turn that starts it ends with "Task done!". The eyes of the pet glow green as long as the server runs, and the hover card reads "Servers running".

Paros reads this from the transcript: the command started in the background, its result, then the notice of its end, or the order to stop it. And from the registry: the status `shell` tells that the turn is over and that a command still runs.

### Letters between sessions

A session can write to another one with the `SendMessage` tool. The pet of the sender throws a letter, which flies in an arc to the pet of the recipient. The seal of the letter has the color of the sender.

A session at rest reads the message at once: its pet holds the letter out and reads it. A session at work reads it later, between two steps or at the end of its turn. Until then the letter waits in a mailbox beside the pet, with a raised flag. The hover card reads "Letters to read". On the lock screen the number of letters is not shown.

A session that wrote to another one and ended its turn waits for the answer, not for you: its pet sits by the hourglass, turned toward the other pet, as long as the other session works. The hover card reads "Waiting for the answer of", with the name. No "Task done!" then: it comes when the answer has arrived and the work is finished. A turn that another session started, and that you did not ask for, ends with a nod.

Paros reads this from the transcripts: what started each turn (you, another session, the end of a background task), the `SendMessage` call of the sender, with the name of the recipient, and the queue of the recipient, where the message enters then leaves.

### Summary of a session at rest

When a session has been at rest for a few minutes, Claude Code writes a summary of where it stands: the goal, what is done, what comes next. The hover card shows it in place of the start of the last prompt, cut at 220 characters. The summary goes away with the next turn.

### Two sessions on the same file

Claude Code refuses to write a file that changed since the session read it. When another session wrote that same file with `Edit` or `Write` in the 15 minutes before, the two sessions step on each other: their pets glare, and the bubble names the file and the other session.

Two sessions in the same folder and on the same branch are not rivals for that alone: they may work together.

### Git status of the session folder

Read every 10 seconds (`git status --porcelain=v2 --branch` and `git diff --shortstat HEAD`), without taking a lock on the repository.

| Status | Pet |
|---|---|
| Uncommitted lines: 1, 50, 300 or more | Pile of 1, 2 or 3 folders on its arm. Each folder slows the walk by 20 % |
| Merge, rebase or cherry-pick to finish | Hard hat, warning sign |
| Behind the upstream branch | Map in hand, scratches its head, "?" |
| Commit that leaves the working tree clean | Three strokes of a broom, then sunglasses for a minute |

Being behind upstream is as of the last `git fetch`. Paros runs none.

## Where the information comes from

| Source | Gives | Note |
|---|---|---|
| `~/.claude/sessions/<pid>.json` | Open sessions, name, folder, status (`busy`, `waiting`, `idle`, `shell`) | Internal Claude Code format, not documented: an update may change it |
| Session transcript, in `~/.claude/projects/` | Color (`/color`), last prompt, summary, context tokens, background tasks, messages between sessions, files written | Only the lines added since the last reading are read |
| `$XDG_RUNTIME_DIR/paros/claude-events.log` | Tools, subagents, failures, end of turn, permission requests | Written by `hooks/claude-hook.sh` |
| Session folder | Git status | Through the `git` command |

If `CLAUDE_CONFIG_DIR` is set, it replaces `~/.claude`.

A session whose process no longer exists is ignored, even if its file was left behind.

### Context

The context tokens are the sum of the input tokens of the last answer of the model (input, cache write, cache read), rounded to 10,000. The size of the context window of the model is written nowhere: it is a setting ("Model context, in thousands of tokens", 1000 by default). The head smokes at 75 % of that size.

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

On screen, a pet shows the session name, the git branch and the tool in use. The hover card also shows the folder, and the start of the last prompt or the summary of the session. On the lock screen, no text is shown.

## Limits

- A background task with no notice of its end after 30 minutes is forgotten, unless the registry tells that a command still runs: the pet goes back to rest.
- A server started by a command that the list does not know counts as a task: the pet waits by the hourglass.
- A letter flies only to a session that has a pet, found by its name: a message to a session on another machine, or to a subagent, shows nothing. With two sessions of the same name, the letter goes to the first one found.
- A message of a session without pet gets no flight: the letter is in the mailbox at once.
- A collision is seen only when the other session wrote the file with `Edit` or `Write`. A file changed by a command (`sed`, a script, a formatter) has no known author: nothing is shown.
- `Stop` also fires on `/clear` and on a compaction: the pet then jumps although no task is done.
- The subagent count follows the `SubagentStart` and `SubagentStop` events. A missed event makes it wrong until the session closes.
- The script needs a POSIX shell. On Windows, Claude Code runs hooks with Git Bash.
