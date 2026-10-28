# agy

[Français](../fr/agy.md)

Paros also follows the sessions of agy, the Antigravity CLI of Google, and the conversations of Antigravity Desktop, for the current user. Each one gets its own pet, drawn after the agy mascot: an "A" in a gradient from orange to green and blue. It lives with the Claude Code pets: it walks, sits, sleeps, greets them, and they write letters to each other through [Diaulos](https://github.com/Dr1mS/Diaulos).

![A Claude pet throws a letter, an agy pet reads one, another thinks with the small pets of its two subagents, a last one waves at a question](../images/agy.png)

Linux only. Nothing to install: Paros reads the files agy writes. An optional hook tells the end of a cancelled turn.

## What a pet shows

| Session | Pet |
|---|---|
| Open | A pet appears, named after the title of the conversation (`/rename`, else the one agy gives it), else after its folder: "New Conversation", the title of a new session, does not count. Its name tag is blue: agy has no `/color` |
| Working | Stays in place, looks up, three dots fill up above its head |
| Tool started | Caption above the head: "view_file · README.md", "run_command · Run tests", "search_web · godot read_link" |
| Asks you a question (`ask_question`) | Waves its arms in turn, bubble with the question, until you answer |
| Waits for a command or a timer (`schedule`) it started in the background | Sits and watches an hourglass. A task stopped with `manage_task` ends the wait |
| Started subagents (`invoke_subagent`) | A small "A" per subagent, named after its role, with the tool it uses. It stays while its subagent works or waits for its own background task, then runs back |
| Left a server running in the background | Its eyes glow green |
| End of a turn you asked for | Jump, hearts, bubble "Task done!" |
| End of a turn another session asked for | Nods twice |
| Tests passed | Jump, bubble "Green tests!" |
| Tests failed, other failed command, tool in error | Shakes, two falling notes. In a subagent: its small pet shakes, no sound |
| Truncated the start of the conversation | Sits by a bin and throws away sheets of its head, after the fact |
| No new step for 8 seconds, then 25 | Taps its foot, then meditates |
| Writes to another session through Diaulos | Throws a letter, which flies to the pet of that session |
| A message of Diaulos waits in its inbox | A mailbox stands beside the pet. It reads the letter when the session takes it |
| Context 75 % full or more | Its head smokes. The window counts 1 million tokens, the one of the Gemini models |
| Closed | The pet goes away. A conversation of Antigravity Desktop has no process of its own: see [Antigravity Desktop](#antigravity-desktop) |

Its arms show only while they rise: when it cheers, waves, throws or reads. At rest the "A" keeps the shape of the mascot.

It wears no accessory: nothing sits well on the point of the "A". Its back arm shows to carry the folders of uncommitted changes. During a merge or a rebase, the warning sign stands beside it, without the hard hat. The git branch, the folders carried and the other reactions to the repository work as for a Claude Code session: see [Claude Code](claude-code.md).

## Antigravity Desktop

Antigravity Desktop runs every conversation of a window in one background process, its language server, and writes them in the same format as the CLI, in `~/.gemini/antigravity/`. Nothing tells which tabs are open. A conversation of Desktop gets a pet:

- while the window shows it: the language server holds its presence lock;
- as soon as it works, and for 10 minutes after its last step. The pet then goes away, and comes back at its next turn;
- until Desktop closes.

Right click → Settings → agy: "Pets for Antigravity Desktop conversations" turns them off, and "A Desktop pet leaves after an idle of" sets the delay (1 to 120 minutes).

The folder of a Desktop conversation is written in no file Paros reads, except the peer file of [Diaulos](https://github.com/Dr1mS/Diaulos), when the bridge knows the conversation. Without it, the pet is named after the conversation alone ("Antigravity" while it has no title), and git is not followed. Subagents have no pet of their own: they stay small pets, as in the CLI.

A session of the agy CLI that Diaulos wakes without a terminal (`agy -p`) is a real `agy` process: its pet comes for the time of its turn, then goes away with the process.

## Diaulos

[Diaulos](https://github.com/Dr1mS/Diaulos) lets agy and Claude Code sessions write to each other. Paros shows these messages as letters:

- A Claude Code session that calls the `send` tool of the `agent-bridge` MCP server throws a letter to the pet of the address.
- An agy session that runs `bridge.py send <address>` throws a letter too.
- The address finds the pet: `claude:<name>`, `agy:<title>` or `agy:<start of the conversation id>`, `claude@<part of the folder>`, `agy@<part of the folder>`, or `claude` or `agy` alone when one other session of that kind runs.
- A message that waits in the inbox of an agy session (`~/.agent-bridge/inbox/agy-<id>/`) puts a mailbox beside its pet.

Nothing to set up: Paros reads the commands of the sessions and the inboxes of Diaulos.

## What Paros reads

| File | What for |
|---|---|
| `/proc/<pid>/fd` of each `agy` process | The process holds `~/.gemini/antigravity-cli/presence/<conversation id>.lock` open: the conversation it runs. Its folder is the one of the process |
| `/proc/<pid>/fd` of each `language_server` process | Antigravity Desktop (`~/.gemini/antigravity/`) or IDE (`~/.gemini/antigravity-ide/`): the data folder it keeps files open in, and the presence lock of the conversation the window shows. Paros never reads its command line |
| `~/.gemini/antigravity/brain/*/` and `annotations/` | The conversations of Desktop: the date of the last step of each transcript, its title. A conversation with no annotations file, and unknown to Diaulos, is a subagent |
| `~/.agent-bridge/peers/agy-<conversation id>.json` | The folder of a Desktop conversation, when Diaulos knows it |
| `~/.gemini/antigravity-cli/annotations/<conversation id>.pbtxt` | The title of the conversation |
| `~/.gemini/antigravity-cli/brain/<conversation id>/.system_generated/logs/transcript_full.jsonl` | One line per step: the request, each answer of the model with its tool calls, their results, the end of the tasks started in the background, the reports of the subagents, the truncation of the context (`CHECKPOINT`), the tokens used. Each subagent has its own, in `brain/<its conversation id>/` |
| `~/.agent-bridge/inbox/agy-<conversation id>/` | The messages of Diaulos that wait |
| `$XDG_RUNTIME_DIR/paros/agy-events.log` | Written by the hook, see below |

A step is written once it is done. The answer of the model comes before the results of its tool calls: the caption shows the tool while it runs. An answer with no tool call ends the turn.

## The hook

A turn cancelled by the user (Esc), or ended on an error, has no last answer in the transcript: without the hook, the pet goes on thinking, then meditates until the next turn. The `Stop` hook of agy tells it.

In `~/.gemini/config/hooks.json`, add:

```json
{
  "paros": {
    "Stop": [
      { "type": "command", "command": "/path/to/Paros/hooks/agy-hook.sh Stop", "timeout": 5 }
    ]
  }
}
```

Keep the other keys of the file, such as `agent-bridge` for Diaulos. agy loads its hooks at startup: restart the open sessions.

The script writes one line per event, three fields separated by tabs: the event, the conversation id and the reason of the end (`NO_TOOL_CALL`, `USER_CANCELED`, `ERROR`…). It prints `{}`, which lets agy stop, and always exits with 0.

## Limits

- Linux only: the conversation of a process is read in `/proc`. On Windows, agy sessions get no pet.
- Antigravity Desktop: a pet stands for a conversation the window shows or that worked in the last minutes, not for each open tab, which no file tells. Its folder comes from Diaulos only. The IDE should work the same way, but is not tested.
- agy writes no wait for a permission in a file Paros can read: only a question (`ask_question`) makes the pet wave its arms. With `toolPermission` set to `always-proceed`, agy never asks for a permission.
- A command counts as failed when its result reads "The command exited with code" followed by anything but 0. Another tool fails when its step has the status `ERROR`.
- A turn told working with no new step for 10 minutes when Paros starts is taken as over.
- The formats read are those of agy with language server 1.4. They are not documented and may change.

## Privacy

Paros reads the transcripts of agy in place, keeps nothing on disk and sends nothing. The hook log holds only event names, conversation ids and reasons of the end. On screen, the pet shows the title of the conversation, the git branch and the tool in use; the hover card also shows the folder and the start of the last request.
