extends "res://tests/test_case.gd"
## What the senses read: Claude Code files, hook log, git output, desktop file,
## media players.

const SESSION := "11111111-2222-3333-4444-555555555555"

var folder := (OS.get_environment("XDG_RUNTIME_DIR") if OS.has_environment("XDG_RUNTIME_DIR") else OS.get_temp_dir()).path_join("test-senses")


func before_each() -> void:
	OS.execute("rm", ["-rf", folder])
	DirAccess.make_dir_recursive_absolute(folder)
	record_events()


func write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(text)


## A Claude Code sense that reads a fake Claude folder. Not in the tree: it
## polls only when the test asks.
func claude_sense() -> Node:
	var sense: Node = load("res://src/senses/claude_code_sense.gd").new()
	sense._claude_dir = folder.path_join("claude")
	sense._log_path = folder.path_join("events.log")
	return sense


func registry(pid: int, status: String, name := "Alpha", kind := "interactive") -> String:
	return JSON.stringify({
		"pid": pid, "sessionId": SESSION, "cwd": "/work", "kind": kind, "name": name, "status": status,
		"statusUpdatedAt": 1000000.0,
	})


## Windows: the process list the desktop helper writes, with only this process
## in it. Nothing to do elsewhere.
func seed_processes() -> void:
	if OS.get_name() != "Windows":
		return
	write(Desktop.runtime_dir().path_join("paros/processes.json"), JSON.stringify({
		"updated": Time.get_unix_time_from_system(), "processes": {str(OS.get_process_id()): [1, "777"]},
	}))
	Desktop._processes_read_at = -1.0


func test_live_session_opens_then_closes() -> void:
	seed_processes()
	var sense := claude_sense()
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "busy"))
	sense._poll()
	check_equal(last_event(&"session_opened").get("name"), "Alpha", "opened with its name")
	check_equal(last_event(&"session_phase").get("phase"), &"working", "busy means working")
	check_equal(last_event(&"session_phase").get("since"), 1000.0, "since the time the registry gives")
	OS.execute("rm", [folder.path_join("claude/sessions/1.json")])
	sense._poll()
	check(&"session_closed" in event_names(), "closed when the file goes")
	sense.free()


func test_process_of_a_session_still_runs() -> void:
	if OS.get_name() == "Linux":
		check(Desktop.is_process_running(OS.get_process_id()), "this process runs")
		check(not Desktop.is_process_running(999999999), "no such process")
	elif OS.get_name() == "Windows":
		seed_processes()
		var pid := OS.get_process_id()
		check(Desktop.is_process_running(pid), "this process runs")
		check(Desktop.is_process_running(pid, "777"), "same creation time")
		check(not Desktop.is_process_running(pid, "888"), "same pid, other process: the pid was reused")
		check(not Desktop.is_process_running(999999999), "no such process")


func test_dead_or_background_sessions_are_ignored() -> void:
	seed_processes()
	var sense := claude_sense()
	write(folder.path_join("claude/sessions/1.json"), registry(999999999, "busy"))
	write(folder.path_join("claude/sessions/2.json"), registry(OS.get_process_id(), "busy", "Agent", "background"))
	sense._poll()
	check(&"session_opened" not in event_names(), "nothing opened")
	sense.free()


func test_transcript_gives_color_prompt_and_tokens() -> void:
	var sense := claude_sense()
	var transcript := folder.path_join("claude/projects/-work").path_join(SESSION + ".jsonl")
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "idle"))
	write(transcript, "\n".join([
		'{"type":"agent-color","agentColor":"red","sessionId":"x"}',
		'{"type":"last-prompt","lastPrompt":"fix the bug","sessionId":"x"}',
		'{"type":"assistant","message":{"usage":{"input_tokens":2,"cache_creation_input_tokens":1440,"cache_read_input_tokens":381812,"output_tokens":500}}}',
		'{"type":"user","message":"quotes the line {\\"type\\":\\"agent-color\\",\\"agentColor\\":\\"blue\\"}"}',
	]) + "\n")
	sense._poll()
	var opened := last_event(&"session_opened")
	check_equal(opened.get("color"), "red", "color, not the quoted one")
	check_equal(opened.get("last_prompt"), "fix the bug", "last prompt")
	check_equal(opened.get("context"), 380000, "input tokens, rounded")

	var file := FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"type":"agent-color","agentColor":"green","sessionId":"x"}\n')
	file.close()
	sense._poll()
	check_equal(last_event(&"session_changed").get("color"), "green", "new color read from the added lines")
	sense.free()


func test_hook_lines_become_events() -> void:
	var sense := claude_sense()
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "busy"))
	write(sense._log_path, "")
	sense._poll()
	var lines := [
		["PreToolUse", "", "Edit", "pet.gd", "", ""],
		["PostToolUse", "", "Bash", "Run tests", "test", ""],
		["PostToolUseFailure", "", "Bash", "Build", "", ""],
		["PreToolUse", "", "Agent", "Find the bug", "", ""],
		["PreToolUse", "", "Edit", "pet.gd", "", ""],
		["SubagentStart", "", "", "", "", "a1"],
		["SubagentStart", "", "", "", "", "a2"],
		["PreToolUse", "", "Read", "brain.gd", "", "a2"],
		["PostToolUseFailure", "", "Bash", "Build", "", "a2"],
		["PreToolUse", "", "Grep", "lost", "", "a9"],
		["SubagentStop", "", "", "", "", "a1"],
		["SubagentStop", "", "", "", "", ""],
		["SubagentStop", "", "", "", "", "a9"],
		["Notification", "permission_prompt", "", "Claude needs your permission to use Bash", "", ""],
	]
	var text := ""
	for line: Array in lines:
		text += "\t".join([line[0], SESSION, line[1], line[2], line[3], line[4], line[5]]) + "\n"
	text += "PreToolUse\tsome-other-session\t\tEdit\tx\t\t\n"
	write(sense._log_path, text)
	sense._poll()
	check_equal(last_event(&"session_activity").get("detail"), "pet.gd", "tool in use, unknown session and subagents ignored")
	check(&"session_tests_passed" in event_names(), "green tests")
	check_equal(last_event(&"session_tool_failed").get("tool"), "Bash", "failed command")
	check_equal(last_event(&"session_tool_failed").get("agent"), "a2", "the last one failed in a subagent")
	check_equal(last_event(&"session_subagents").get("count"), 1, "two started, one stopped, the stops of unknown agents ignored")
	check_equal(last_event(&"session_subagents").get("agents"), [{"id": "a2", "name": "", "tool": "Read", "detail": "brain.gd"}], "tool of the subagent left, none for an unknown one")
	check_equal(last_event(&"session_needs_you").get("detail"), "Claude needs your permission to use Bash", "question")
	check_equal(last_event(&"session_phase").get("phase"), &"waiting", "waiting although the registry says busy")

	write(sense._log_path, text + "\t".join(["Stop", SESSION, "", "", "", "", ""]) + "\n")
	sense._poll()
	check(&"session_finished" in event_names(), "end of turn")
	check_equal(last_event(&"session_phase").get("phase"), &"working", "the question is answered")
	sense.free()


func test_silent_work_gets_quiet() -> void:
	var sense := claude_sense()
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "busy"))
	sense._poll()
	sense._sessions[SESSION].heard -= 10.0
	sense._poll()
	check_equal(last_event(&"session_quiet").get("level"), 1, "a while")
	sense._sessions[SESSION].heard -= 30.0
	sense._poll()
	check_equal(last_event(&"session_quiet").get("level"), 2, "long")
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "idle"))
	sense._poll()
	check_equal(last_event(&"session_quiet").get("level"), 0, "not quiet at rest")
	sense.free()


func test_git_status_output() -> void:
	var sense: Node = load("res://src/senses/git_sense.gd").new()
	var state := {"branch": "", "dirty": 0, "behind": 0, "conflict": false, "head": "", "clean": true}
	sense.read_status("\n".join([
		"# branch.oid 0123456789abcdef",
		"# branch.head feature/x",
		"# branch.upstream origin/feature/x",
		"# branch.ab +1 -3",
		"1 .M N... 100644 100644 100644 aaa bbb src/pet.gd",
		"? notes.txt",
	]), state)
	check_equal(state.branch, "feature/x", "branch")
	check_equal(state.behind, 3, "behind")
	check_equal(state.head, "0123456789abcdef", "commit")
	check(not state.clean, "not clean")
	check(not state.conflict, "no conflict")
	sense.read_status("u UU N... 100644 100644 100644 100644 a b c file.txt\n", state)
	check(state.conflict, "unmerged file")
	check_equal(sense.count_changed_lines(" 3 files changed, 10 insertions(+), 2 deletions(-)\n"), 12, "lines changed")
	check_equal(sense.count_changed_lines(" 1 file changed, 1 insertion(+)\n"), 1, "one line")
	check_equal(sense.count_changed_lines(""), 0, "nothing")
	sense.free()


func test_git_on_a_real_repository() -> void:
	var sense: Node = load("res://src/senses/git_sense.gd").new()
	var repo := folder.path_join("repo")
	var git := "git -c user.name=test -c user.email=test@test -c init.defaultBranch=main -C '%s' " % repo
	DirAccess.make_dir_recursive_absolute(repo)
	write(repo.path_join("a.txt"), "one\ntwo\n")
	OS.execute("sh", ["-c", git + "init -q && " + git + "add a.txt && " + git + "commit -q -m first"])
	var clean: Dictionary = sense._inspect(repo)
	check_equal(clean.branch, "main", "branch")
	check(clean.clean, "clean after the commit")
	check_equal(clean.dirty, 0, "no line changed")
	write(repo.path_join("a.txt"), "one\nTWO\nthree\n")
	var dirty: Dictionary = sense._inspect(repo)
	check(not dirty.clean, "not clean")
	check_equal(dirty.dirty, 3, "two lines added, one removed")
	check_equal(sense._inspect(folder).branch, "", "not a repository")
	sense.free()


func test_clean_commit_is_reported_once() -> void:
	var sense: Node = load("res://src/senses/git_sense.gd").new()
	sense._folders["s1"] = "/work"
	var state := {"branch": "main", "dirty": 5, "behind": 0, "conflict": false, "head": "aaa", "clean": false}
	sense._report("s1", state.duplicate())
	check_equal(last_event(&"repo_state").get("dirty"), 5, "state posted")
	check(not last_event(&"repo_state").has("head"), "without the commit id")
	state.merge({"dirty": 0, "head": "bbb", "clean": true}, true)
	sense._report("s1", state.duplicate())
	check(&"repo_cleaned" in event_names(), "new commit, nothing left")
	_events.clear()
	sense._report("s1", state.duplicate())
	check(event_names().is_empty(), "nothing new: nothing posted")
	sense.free()


func test_background_tasks_run_until_their_notice() -> void:
	var sense := claude_sense()
	var transcript := folder.path_join("claude/projects/-work").path_join(SESSION + ".jsonl")
	var now := Time.get_datetime_string_from_system(true)
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "idle"))
	write(transcript, "\n".join([
		'{"type":"user","timestamp":"%s.123Z","toolUseResult":{"stdout":"","backgroundTaskId":"b1"}}' % now,
		'{"type":"user","timestamp":"%s.123Z","toolUseResult":{"isAsync":true,"status":"async_launched","agentId":"a1"}}' % now,
		'{"type":"user","timestamp":"2020-01-01T00:00:00.000Z","toolUseResult":{"backgroundTaskId":"old"}}',
		'{"type":"user","timestamp":"%s.123Z","message":"quotes {\\"backgroundTaskId\\":\\"quoted\\"}"}' % now,
	]) + "\n")
	sense._poll()
	check_equal(last_event(&"session_background").get("background"), 2, "a command and an agent, not the old one nor the quoted one")

	var file := FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"type":"queue-operation","operation":"enqueue","content":"<task-notification>\\n<task-id>b1</task-id>\\n<status>completed</status>"}\n')
	file.close()
	sense._poll()
	check_equal(last_event(&"session_background").get("background"), 1, "the command ended")

	file = FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"type":"assistant","message":{"content":[{"type":"tool_use","name":"TaskStop","input":{"task_id":"a1"}}]}}\n')
	file.close()
	sense._poll()
	check_equal(last_event(&"session_background").get("background"), 0, "the agent was stopped: no notice comes")
	sense.free()


func test_messages_between_sessions() -> void:
	var sense := claude_sense()
	var transcript := folder.path_join("claude/projects/-work").path_join(SESSION + ".jsonl")
	var send := '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"SendMessage","input":{"summary":"hi","to":"%s"}}],"usage":{"input_tokens":1}}}'
	var letter := '{"type":"queue-operation","operation":"%s","content":"<cross-session-message from=\\"uds:/run/1.sock\\" from-name=\\"Beta\\">\\nhello"}'
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "busy"))
	write(transcript, "\n".join([send % "Old", letter % "enqueue", '{"type":"queue-operation","operation":"dequeue"}']) + "\n")
	sense._poll()
	check(&"session_message_sent" not in event_names(), "a message sent before the first reading is old")
	check(&"session_mail" not in event_names(), "its letter was read already")

	var add := func(lines: Array) -> void:
		var file := FileAccess.open(transcript, FileAccess.READ_WRITE)
		file.seek_end()
		file.store_string("\n".join(lines) + "\n")
		file.close()
		sense._poll()
	add.call([send % "Beta", '{"type":"user","message":"quotes {\\"name\\":\\"SendMessage\\",\\"input\\":{\\"to\\":\\"Quoted\\"}}"}'])
	check_equal(last_event(&"session_message_sent").get("to"), "Beta", "sent to Beta, the quoted one ignored")
	check_equal(event_names().count(&"session_message_sent"), 1, "once")
	add.call([
		letter % "enqueue",
		'{"type":"queue-operation","operation":"enqueue","content":"<task-notification>\\n<task-id>b1</task-id>"}',
		letter % "enqueue",
	])
	check_equal(last_event(&"session_mail").get("mail"), 2, "two letters wait, the notice is not one")
	add.call(['{"type":"queue-operation","operation":"dequeue"}'])
	check_equal(last_event(&"session_mail").get("mail"), 1, "the first one was taken")
	add.call([letter.replace('"content"', '"reason":"absorbed_mid_turn","content"') % "remove"])
	check_equal(last_event(&"session_mail").get("mail"), 0, "the other one was read during the turn")
	add.call([letter % "enqueue", letter % "enqueue", '{"type":"queue-operation","operation":"popAll"}'])
	check_equal(last_event(&"session_mail").get("mail"), 0, "queue emptied")
	sense.free()


func test_what_started_the_turn() -> void:
	var sense := claude_sense()
	var transcript := folder.path_join("claude/projects/-work").path_join(SESSION + ".jsonl")
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "busy"))
	write(transcript, "\n".join([
		'{"type":"user","message":{"content":"old"},"origin":{"kind":"peer","name":"Old"}}',
		'{"type":"user","message":{"content":"fix it"},"origin":{"kind":"human"}}',
	]) + "\n")
	sense._poll()
	check_equal(event_names().count(&"session_turn"), 1, "only the turn in progress when first seen")
	check_equal(last_event(&"session_turn").get("origin"), &"human", "started by the user")
	check_equal(event_names().find(&"session_opened") < event_names().find(&"session_turn"), true, "after the session opens")

	var file := FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string("\n".join([
		'{"type":"user","message":{"content":"quotes {\\"origin\\":{\\"kind\\":\\"human\\"}}"}}',
		'{"type":"user","isMeta":true,"message":{"content":"Another Claude session sent a message"},"origin":{"kind":"peer","from":"uds:/run/1.sock","name":"Beta"}}',
	]) + "\n")
	file.close()
	sense._poll()
	check_equal(event_names().count(&"session_turn"), 2, "one more, the quoted one ignored")
	check_equal(last_event(&"session_turn").get("origin"), &"peer", "started by another session")
	check_equal(last_event(&"session_turn").get("from"), "Beta", "with its name")
	sense.free()


func test_server_in_the_background_is_not_a_wait() -> void:
	var sense := claude_sense()
	var transcript := folder.path_join("claude/projects/-work").path_join(SESSION + ".jsonl")
	var now := Time.get_datetime_string_from_system(true)
	var launch := '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"%s","name":"Bash","input":{"command":"%s","run_in_background":true}}]}}'
	var result := '{"type":"user","timestamp":"%s.123Z","message":{"content":[{"tool_use_id":"%s","type":"tool_result"}]},"toolUseResult":{"backgroundTaskId":"%s"}}'
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "idle"))
	write(transcript, "\n".join([
		launch % ["t1", "npm run dev"], result % [now, "t1", "b1"],
		launch % ["t2", "node scripts/sweep.mjs 40000"], result % [now, "t2", "b2"],
		launch % ["t3", "python3 -m http.server 8000"], result % ["2020-01-01T00:00:00", "t3", "old"],
	]) + "\n")
	sense._poll()
	check_equal(last_event(&"session_background").get("background"), 1, "one task to wait for")
	check_equal(last_event(&"session_background").get("servers"), 1, "one server, the old one forgotten")

	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "shell"))
	sense._poll()
	check_equal(last_event(&"session_background").get("servers"), 2, "the registry tells a command runs: the old one counts")
	check_equal(last_event(&"session_phase").get("phase"), &"idle", "at rest meanwhile")

	var file := FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"type":"queue-operation","operation":"enqueue","content":"<task-notification>\\n<task-id>b1</task-id>"}\n')
	file.close()
	sense._poll()
	check_equal(last_event(&"session_background").get("servers"), 1, "the server was stopped")
	for command: String in ["vite", "cd web && pnpm dev", "npx vite --port 5173", "tsc --watch", "uvicorn app:app", "docker compose up -d"]:
		check(sense.is_server(command), "server: " + command)
	for command: String in ["npm test", "npm run build", "node scripts/devtools.mjs", "cargo build", "sleep 5 && curl localhost"]:
		check(not sense.is_server(command), "not a server: " + command)
	sense.free()


func test_refused_write_after_another_session_is_a_collision() -> void:
	var other := "99999999-2222-3333-4444-555555555555"
	var sense := claude_sense()
	var projects := folder.path_join("claude/projects/-work")
	var now := Time.get_datetime_string_from_system(true)
	var edit := '{"type":"assistant","timestamp":"%s.000Z","message":{"content":[{"type":"tool_use","id":"%s","name":"%s","input":{"file_path":"%s","old_string":"a"}}]}}'
	var refusal := '{"type":"user","message":{"content":[{"type":"tool_result","content":"<tool_use_error>File has been modified since read, either by the user or by a linter.</tool_use_error>","is_error":true,"tool_use_id":"%s"}]},"timestamp":"%s.500Z"}'
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "busy"))
	write(folder.path_join("claude/sessions/2.json"), registry(OS.get_process_id(), "busy", "Beta").replace(SESSION, other))
	write(projects.path_join(SESSION + ".jsonl"), "")
	write(projects.path_join(other + ".jsonl"), edit % [now, "o1", "Write", "/work/src/pet.gd"] + "\n")
	sense._poll()

	var file := FileAccess.open(projects.path_join(SESSION + ".jsonl"), FileAccess.READ_WRITE)
	file.store_string("\n".join([
		edit % [now, "t1", "Edit", "/work/src/pet.gd"], refusal % ["t1", now],
		edit % [now, "t2", "Edit", "/work/src/alone.gd"], refusal % ["t2", now],
	]) + "\n")
	file.close()
	sense._poll()
	check_equal(event_names().count(&"session_collision"), 1, "one collision: nobody else wrote the second file")
	var collision := last_event(&"session_collision")
	check_equal([collision.get("session"), collision.get("other")], [SESSION, other], "who was refused, who wrote before")
	check_equal(collision.get("file"), "pet.gd", "the file")
	sense.free()


func test_summary_of_a_session_at_rest() -> void:
	var sense := claude_sense()
	var transcript := folder.path_join("claude/projects/-work").path_join(SESSION + ".jsonl")
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "idle"))
	write(transcript, '{"parentUuid":"p","type":"system","subtype":"away_summary","content":"Goal: fix the bug. Done, tests pass. (disable recaps in /config)"}\n')
	sense._poll()
	check_equal(last_event(&"session_opened").get("summary"), "Goal: fix the bug. Done, tests pass.", "summary, without the hint")
	var file := FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"type":"user","message":{"content":"and now?"},"origin":{"kind":"human"}}\n')
	file.close()
	sense._poll()
	check_equal(last_event(&"session_changed").get("summary"), "", "gone with the next turn")
	sense.free()


func test_music_players() -> void:
	var sense: Node = load("res://src/senses/music_sense.gd").new()
	var names := "(['org.freedesktop.DBus', ':1.7', 'org.mpris.MediaPlayer2.spotify', 'org.mpris.MediaPlayer2.firefox.instance_1_23'],)"
	check_equal(Array(sense.players(names)), ["org.mpris.MediaPlayer2.spotify", "org.mpris.MediaPlayer2.firefox.instance_1_23"], "players among the bus names")
	check_equal(Array(sense.players("(['org.freedesktop.DBus'],)")), [], "no player")
	sense._report(true)
	sense._report(true)
	check_equal(event_names().count(&"music"), 1, "posted once")
	check_equal(last_event(&"music").get("playing"), true, "playing")
	sense._report(false)
	check_equal(last_event(&"music").get("playing"), false, "stopped")
	sense.free()


func test_desktop_file() -> void:
	var sense: Node = load("res://src/senses/desktop_sense.gd").new()
	sense._path = folder.path_join("desktop.json")
	write(sense._path, JSON.stringify({
		"pointer": [10, 20], "locked": true, "mirrored": 1, "covered": [[1920, 0, 1920, 1080]],
		"active": {"x": 5, "y": 6, "width": 700, "height": 500, "fullscreen": false, "pid": 99},
	}))
	sense._poll()
	var state := last_event(&"desktop_state")
	check_equal(state.get("active"), Rect2(5, 6, 700, 500), "focused window")
	check_equal(state.get("pid"), 99, "its process")
	check_equal(state.get("covered"), [Rect2(1920, 0, 1920, 1080)], "covered screens")
	check_equal(last_event(&"screen_locked").get("locked"), true, "locked")
	check_equal(last_event(&"pointer_at").get("position"), Vector2(10, 20), "pointer")

	# Older extension: no list of covered screens.
	write(sense._path, JSON.stringify({
		"pointer": [10, 20], "active": {"x": 0, "y": 0, "width": 1920, "height": 1080, "fullscreen": true, "pid": 99},
	}))
	sense._poll()
	check_equal(last_event(&"desktop_state").get("covered"), [Rect2(0, 0, 1920, 1080)], "the focused full screen window")
	check_equal(last_event(&"screen_locked").get("locked"), false, "unlocked")

	sense._still_for = sense.IDLE_AFTER_SECONDS
	sense._poll()
	check(&"pointer_idle" in event_names(), "pointer still for long")
	OS.execute("rm", [sense._path])
	sense._poll()
	check_equal(last_event(&"desktop_state").get("pid"), -1, "no file: nothing known")
	sense.free()


func test_hook_script_writes_one_line_per_event() -> void:
	var script := ProjectSettings.globalize_path("res://hooks/claude-hook.sh")
	var runs := [
		'{"session_id":"s1","cwd":"/y","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/home/u/src/pet.gd","old_string":"a \\"session_id\\":\\"evil\\" b"}}',
		# A Windows path: backslashes are doubled in the JSON of the hooks.
		'{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"C:\\\\Users\\\\u\\\\src\\\\pet_body.gd"}}',
		'{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"cd x && npm run test","description":"Run unit tests"}}',
		'{"session_id":"s1","hook_event_name":"Notification","message":"Claude needs your permission","notification_type":"permission_prompt"}',
		'{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls","description":"%s"}}' % "x".repeat(300),
		'{"session_id":"s1","agent_id":"a1","agent_type":"general-purpose","hook_event_name":"SubagentStop","background_tasks":[{"id":"a2","type":"subagent","description":"Other agent"}]}',
	]
	for input: String in runs:
		write(folder.path_join("input.json"), input)
		OS.execute("sh", ["-c", "XDG_RUNTIME_DIR='%s' '%s' < '%s'" % [folder, script, folder.path_join("input.json")]])
	var lines := FileAccess.get_file_as_string(folder.path_join("paros/claude-events.log")).split("\n", false)
	check_equal(lines.size(), 6, "one line per event")
	check_equal(Array(lines[0].split("\t")), ["PreToolUse", "s1", "", "Edit", "pet.gd", "", ""], "file name of an edit")
	check_equal(Array(lines[1].split("\t")), ["PreToolUse", "s1", "", "Write", "pet_body.gd", "", ""], "file name of a Windows path")
	check_equal(Array(lines[2].split("\t")), ["PostToolUse", "s1", "", "Bash", "Run unit tests", "test", ""], "a test command")
	check_equal(Array(lines[3].split("\t")), ["Notification", "s1", "permission_prompt", "", "Claude needs your permission", "", ""], "a question")
	check_equal(lines[4].split("\t")[4].length(), 120, "long detail cut")
	check_equal(Array(lines[5].split("\t")), ["SubagentStop", "s1", "", "", "Other agent", "", "a1"], "id of the subagent")


func test_advisor_calls_are_read_from_the_transcript() -> void:
	var sense := claude_sense()
	var transcript := folder.path_join("claude/projects/-work").path_join(SESSION + ".jsonl")
	var call := '{"type":"assistant","message":{"content":[{"type":"server_tool_use","id":"srvtoolu_1","name":"advisor","input":{}}]}}'
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "busy"))
	write(transcript, call + "\n")
	sense._poll()
	check(&"session_advisor" not in event_names(), "a call made before Paros looked is old")
	for line: String in [
		'{"type":"user","message":"quotes {\\"type\\":\\"server_tool_use\\",\\"name\\":\\"advisor\\"}"}',
		'{"type":"assistant","message":{"content":[{"type":"server_tool_use","id":"srvtoolu_2","name":"web_search","input":{}}]}}',
	]:
		var file := FileAccess.open(transcript, FileAccess.READ_WRITE)
		file.seek_end()
		file.store_string(line + "\n")
		file.close()
		sense._poll()
	check(&"session_advisor" not in event_names(), "neither a quoted call nor another server tool")
	var file := FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string(call + "\n")
	file.close()
	sense._poll()
	check_equal(last_event(&"session_advisor").get("asking"), true, "the advisor is asked")
	file = FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"type":"assistant","message":{"content":[{"type":"advisor_tool_result","tool_use_id":"srvtoolu_1","content":{"type":"advisor_redacted_result"}}]}}\n')
	file.close()
	sense._poll()
	check_equal(last_event(&"session_advisor").get("asking"), false, "it answered")

	file = FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string(call + "\n")
	file.close()
	write(sense._log_path, "")
	sense._poll()
	check_equal(last_event(&"session_advisor").get("asking"), true, "asked again")
	write(sense._log_path, "\t".join(["PreToolUse", SESSION, "", "Read", "x", "", "a1"]) + "\n")
	sense._poll()
	check_equal(last_event(&"session_advisor").get("asking"), true, "the tool of a subagent tells nothing")
	write(sense._log_path, "\t".join(["PreToolUse", SESSION, "", "Read", "x", "", "a1"]) + "\n" + "\t".join(["PreToolUse", SESSION, "", "Edit", "y", "", ""]) + "\n")
	sense._poll()
	check_equal(last_event(&"session_advisor").get("asking"), false, "the next tool of the session: the answer came, even if the transcript does not say so")
	sense.free()
