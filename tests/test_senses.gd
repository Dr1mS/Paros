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
	sense._terminals_path = folder.path_join("advising.txt")
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

	write(sense._log_path, text + "\t".join(["Stop", SESSION, "", "", "", "", ""]) + "\n" + "\t".join(["SubagentStart", SESSION, "", "", "", "", "a1"]) + "\n")
	sense._poll()
	check_equal(last_event(&"session_subagents").get("agents")[-1].name, "Find the bug", "a subagent given more work starts again under its name")
	sense.free()


func test_compaction_from_hooks_then_from_the_transcript() -> void:
	var sense := claude_sense()
	var transcript := folder.path_join("claude/projects/-work").path_join(SESSION + ".jsonl")
	var usage := '{"type":"assistant","message":{"usage":{"input_tokens":2,"cache_creation_input_tokens":0,"cache_read_input_tokens":800000}}}'
	var boundary := '{"type":"system","subtype":"compact_boundary","content":"Conversation compacted","compactMetadata":{"trigger":"auto","preTokens":800000}}'
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "busy"))
	write(transcript, usage + "\n" + boundary.replace("auto", "manual") + "\n" + usage + "\n")
	write(sense._log_path, "")
	sense._poll()
	check(&"session_compacting" not in event_names(), "a compaction made before Paros looked is old")

	var log := "\t".join(["PreCompact", SESSION, "", "", "", "auto", ""]) + "\n"
	write(sense._log_path, log)
	sense._poll()
	check_equal(last_event(&"session_compacting"), {"session": SESSION, "compacting": true, "auto": true}, "the hook tells the start, and that the context was full")
	log += "\t".join(["Stop", SESSION, "", "", "", "", ""]) + "\n"
	write(sense._log_path, log)
	sense._poll()
	check(&"session_finished" not in event_names(), "a Stop while it compacts ends no turn")
	var file := FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string(boundary + "\n")
	file.close()
	sense._poll()
	check_equal(last_event(&"session_compacting").get("compacting"), false, "the transcript tells the end")
	check_equal(last_event(&"session_changed").get("context"), 0, "the head is emptied")
	record_events()
	log += "\t".join(["PostCompact", SESSION, "", "", "", "auto", ""]) + "\n" + "\t".join(["Stop", SESSION, "", "", "", "", ""]) + "\n"
	write(sense._log_path, log)
	sense._poll()
	check_equal(event_names().filter(func(name: StringName) -> bool: return name in [&"session_compacting", &"session_finished"]), [], "the hook after the line, and the Stop that follows: no news")

	sense._sessions[SESSION].compacted -= sense.COMPACT_ECHO_SECONDS
	file = FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string(boundary.replace("auto", "manual") + "\n")
	file.close()
	sense._poll()
	var told := _events.filter(func(event: Array) -> bool: return event[0] == &"session_compacting").map(func(event: Array) -> Array: return [event[1].compacting, event[1].auto])
	check_equal(told, [[true, false], [false, false]], "without the hook, the line tells both, after the fact")

	sense._sessions[SESSION].compacted -= sense.COMPACT_ECHO_SECONDS
	log += "\t".join(["PreCompact", SESSION, "", "", "", "manual", ""]) + "\n"
	write(sense._log_path, log)
	sense._poll()
	check_equal(last_event(&"session_compacting").get("compacting"), true, "compacts again")
	log += "\t".join(["PreToolUse", SESSION, "", "Read", "x", "", ""]) + "\n"
	write(sense._log_path, log)
	sense._poll()
	check_equal(last_event(&"session_compacting").get("compacting"), false, "a failed compaction ends with the next move of the session")
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
		'{"session_id":"s1","transcript_path":"/t.jsonl","cwd":"/y","hook_event_name":"PreCompact","trigger":"auto","custom_instructions":""}',
	]
	for input: String in runs:
		write(folder.path_join("input.json"), input)
		OS.execute("sh", ["-c", "XDG_RUNTIME_DIR='%s' '%s' < '%s'" % [folder, script, folder.path_join("input.json")]])
	var lines := FileAccess.get_file_as_string(folder.path_join("paros/claude-events.log")).split("\n", false)
	check_equal(lines.size(), 7, "one line per event")
	check_equal(Array(lines[0].split("\t")), ["PreToolUse", "s1", "", "Edit", "pet.gd", "", ""], "file name of an edit")
	check_equal(Array(lines[1].split("\t")), ["PreToolUse", "s1", "", "Write", "pet_body.gd", "", ""], "file name of a Windows path")
	check_equal(Array(lines[2].split("\t")), ["PostToolUse", "s1", "", "Bash", "Run unit tests", "test", ""], "a test command")
	check_equal(Array(lines[3].split("\t")), ["Notification", "s1", "permission_prompt", "", "Claude needs your permission", "", ""], "a question")
	check_equal(lines[4].split("\t")[4].length(), 120, "long detail cut")
	check_equal(Array(lines[5].split("\t")), ["SubagentStop", "s1", "", "", "Other agent", "", "a1"], "id of the subagent")
	check_equal(Array(lines[6].split("\t")), ["PreCompact", "s1", "", "", "", "auto", ""], "what started a compaction")


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

	record_events()
	file = FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string(call.replace('{"type":"assistant"', '{"type":"assistant","timestamp":"2020-01-01T00:00:00.000Z"') + "\n")
	file.close()
	sense._poll()
	var told := _events.filter(func(event: Array) -> bool: return event[0] == &"session_advisor").map(func(event: Array) -> bool: return event[1].asking)
	check_equal(told, [true, false], "a call written long after it was made is told, then over at once")
	sense.free()


func test_terminal_tells_the_advisor_is_asked() -> void:
	var sense := claude_sense()
	var transcript := folder.path_join("claude/projects/-work").path_join(SESSION + ".jsonl")
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "busy"))
	write(transcript, '{"type":"assistant","message":"I ask the advisor."}\n')
	write(sense._log_path, "")
	sense._poll()
	var now := Time.get_unix_time_from_system()
	write(sense._terminals_path, "%.3f\n" % now)
	sense._poll()
	check(&"session_advisor" not in event_names(), "the helper runs, no terminal shows the advisor")
	write(sense._terminals_path, "%.3f\n%.3f\n" % [now, now])
	sense._poll()
	check_equal(last_event(&"session_advisor").get("asking"), true, "a terminal shows it: the busy session that kept silent asks")

	# The call is written in the transcript once it is answered.
	record_events()
	var stamp := Time.get_datetime_string_from_unix_time(int(now))
	var file := FileAccess.open(transcript, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"type":"assistant","timestamp":"%s.000Z","message":{"content":[{"type":"server_tool_use","id":"srvtoolu_1","name":"advisor","input":{}}]}}\n' % stamp)
	file.close()
	sense._poll()
	var told := _events.filter(func(event: Array) -> bool: return event[0] == &"session_advisor").map(func(event: Array) -> bool: return event[1].asking)
	check_equal(told, [false], "the same call, read late in the transcript: answered, not asked again")
	sense._poll()
	check_equal(told.size(), 1, "and the terminal that still shows it for a moment does not ask again")

	record_events()
	write(sense._terminals_path, "%.3f\n%.3f\n" % [now - 60.0, now + 1.0])
	sense._poll()
	check(&"session_advisor" not in event_names(), "a helper that stopped writing tells nothing")
	Settings.set_value("claude", "sage_live", false)
	write(sense._terminals_path, "%.3f\n%.3f\n" % [now, now + 1.0])
	sense._poll()
	check(&"session_advisor" not in event_names(), "nor does the helper with the setting off")
	Settings.set_value("claude", "sage_live", true)
	sense.free()


func test_terminal_with_two_silent_sessions_tells_none() -> void:
	var sense := claude_sense()
	write(folder.path_join("claude/sessions/1.json"), registry(OS.get_process_id(), "busy"))
	write(folder.path_join("claude/sessions/2.json"), registry(OS.get_process_id(), "busy").replace(SESSION, "other-session"))
	write(sense._log_path, "")
	sense._poll()
	var now := Time.get_unix_time_from_system()
	write(sense._terminals_path, "%.3f\n%.3f\n" % [now, now])
	sense._poll()
	check(&"session_advisor" not in event_names(), "one terminal, two busy sessions that keep silent: which one is not known")
	write(sense._terminals_path, "%.3f\n%.3f\n%.3f\n" % [now, now, now + 0.5])
	sense._poll()
	var asked := _events.filter(func(event: Array) -> bool: return event[0] == &"session_advisor")
	check_equal(asked.size(), 2, "two terminals, two sessions: both ask")
	write(sense._terminals_path, "%.3f\n" % now)
	sense._poll()
	check_equal(last_event(&"session_advisor").get("asking"), false, "no terminal shows it any more: over")
	sense.free()


func test_terminal_helper_finds_the_advisor_at_work() -> void:
	if OS.get_name() != "Linux":
		return
	var script := ProjectSettings.globalize_path("res://linux/paros-terminal.py")
	var bottom := "\n\n✽ Herding… (1m 28s · ↓ 7.1k tokens)\n────────────────────\n❯ \n────────────────────\n  ⏵⏵ auto mode on\n"
	var screens := {
		"I ask the advisor.\n\n● Advising using Opus 5.5" + bottom: "1",
		# The dot blinks.
		"I ask the advisor.\n\n  Advising using Opus 5.5" + bottom: "1",
		"● Advising using Opus 5.5\n  ⎿  ✔ Advisor has reviewed the conversation and will apply the feedback" + bottom: "0",
		"● The terminal showed\n  ● Advising using Opus 5.5\n  a moment ago." + bottom: "0",
		"● Running 1 shell command…" + bottom: "0",
	}
	for screen: String in screens:
		write(folder.path_join("screen.txt"), screen)
		var output := []
		OS.execute("sh", ["-c", "python3 -I '%s' --test < '%s'" % [script, folder.path_join("screen.txt")]], output)
		check_equal(str(output[0]).strip_edges(), screens[screen], "screen that ends with: " + screen.left(60).replace("\n", " / "))


const CONVERSATION := "c6bdd622-affe-47d2-889d-2409d3b69971"


## An agy sense that reads a fake agy folder and a fake /proc, where one agy
## process runs the conversation CONVERSATION in the folder "work".
func agy_sense() -> Node:
	var sense: Node = load("res://src/senses/agy_sense.gd").new()
	sense._agy_dir = folder.path_join("agy")
	sense._bridge_dir = folder.path_join("bridge")
	sense._proc_dir = folder.path_join("proc")
	sense._log_path = folder.path_join("agy-events.log")
	write(folder.path_join("proc/4242/comm"), "agy\n")
	write(folder.path_join("proc/7/comm"), "bash\n")
	write(folder.path_join("agy/presence/%s.lock" % CONVERSATION), "")
	DirAccess.make_dir_recursive_absolute(folder.path_join("proc/4242/fd"))
	DirAccess.make_dir_recursive_absolute(folder.path_join("my work"))
	OS.execute("ln", ["-s", folder.path_join("agy/presence/%s.lock" % CONVERSATION), folder.path_join("proc/4242/fd/75")])
	OS.execute("ln", ["-s", "/dev/null", folder.path_join("proc/4242/fd/0")])
	OS.execute("ln", ["-s", folder.path_join("my work"), folder.path_join("proc/4242/cwd")])
	return sense


## Adds steps to the transcript of CONVERSATION, then polls.
func add_steps(sense: Node, steps: Array) -> void:
	var path := folder.path_join("agy/brain/%s/.system_generated/logs/transcript_full.jsonl" % CONVERSATION)
	if not FileAccess.file_exists(path):
		write(path, "")
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	file.seek_end()
	for step: Dictionary in steps:
		step.merge({"created_at": Time.get_datetime_string_from_system(true) + "Z"})
		file.store_string(JSON.stringify(step) + "\n")
	file.close()
	sense._poll()


func call_step(name: String, args: Dictionary, tokens := 0) -> Dictionary:
	return {"type": "PLANNER_RESPONSE", "source": "MODEL", "input_tokens": tokens, "tool_calls": [{"name": name, "args": args}]}


func result_step(content: String, status := "DONE") -> Dictionary:
	return {"type": "GENERIC", "source": "MODEL", "status": status, "content": content}


func test_agy_session_opens_works_then_closes() -> void:
	if OS.get_name() != "Linux":
		return
	var sense := agy_sense()
	write(folder.path_join("agy/annotations/%s.pbtxt" % CONVERSATION), 'title:"Probl\\303\\250me \\"A\\""\n')
	add_steps(sense, [
		{"type": "USER_INPUT", "content": "<USER_REQUEST>\nfix the bug\n</USER_REQUEST>\n<ADDITIONAL_METADATA>x</ADDITIONAL_METADATA>"},
		{"type": "PLANNER_RESPONSE", "input_tokens": 3000, "cache_read_tokens": 14842, "content": "Done."},
	])
	var opened := last_event(&"session_opened")
	check_equal(opened.get("session"), CONVERSATION, "the conversation is the session")
	check_equal(opened.get("name"), 'Problème "A"', "named after its title, escapes read")
	check_equal(opened.get("kind"), &"agy", "an agy session")
	check_equal(opened.get("pid"), 4242, "its process")
	check_equal(opened.get("cwd"), folder.path_join("my work"), "its folder")
	check_equal(opened.get("last_prompt"), "fix the bug", "the request, without what agy adds")
	check_equal(opened.get("context"), 20000, "input tokens, rounded")
	check_equal(last_event(&"session_phase").get("phase"), &"idle", "the turn was over before")
	check(&"session_finished" not in event_names(), "an old turn is no news")

	add_steps(sense, [
		{"type": "USER_INPUT", "content": "<USER_REQUEST>\nrun the tests\n</USER_REQUEST>"},
		call_step("view_file", {"AbsolutePath": "/work/README.md", "toolSummary": "Read"}),
	])
	check_equal(last_event(&"session_phase").get("phase"), &"working", "works from the request on")
	check_equal(last_event(&"session_turn").get("origin"), &"human", "a turn of the user")
	check_equal(last_event(&"session_activity"), {"session": CONVERSATION, "tool": "view_file", "detail": "README.md"}, "tool and file")
	add_steps(sense, [
		result_step("File Path: README.md"),
		call_step("run_command", {"CommandLine": "npm test", "toolSummary": "Run tests"}),
		result_step("The command exited with code 1.\nOutput:\nfail"),
	])
	check_equal(last_event(&"session_tool_failed").get("test"), true, "red tests")
	check_equal(last_event(&"session_tool_failed").get("detail"), "Run tests", "with the summary of the command")
	add_steps(sense, [call_step("run_command", {"CommandLine": "npm test"}), result_step("The command exited with code 0.")])
	check(&"session_tests_passed" in event_names(), "green tests")
	add_steps(sense, [{"type": "PLANNER_RESPONSE", "content": "All green."}])
	check(&"session_finished" in event_names(), "the last answer ends the turn")
	check_equal(last_event(&"session_phase").get("phase"), &"idle", "at rest")

	OS.execute("rm", [folder.path_join("proc/4242/fd/75")])
	sense._scan_in = 0.0
	sense._poll()
	check(&"session_closed" in event_names(), "closed when the process lets go of its conversation")
	sense.free()


## Antigravity Desktop: one language_server runs every conversation of a
## window and holds the presence lock of the one the window shows.
func test_agy_desktop_conversations() -> void:
	if OS.get_name() != "Linux":
		return
	var sense := agy_sense()
	var desktop := folder.path_join("desktop")
	sense._server_dirs = [desktop]
	var shown := "11111111-1111-1111-1111-111111111111"
	var recent := "22222222-2222-2222-2222-222222222222"
	var idle := "33333333-3333-3333-3333-333333333333"
	var subagent := "44444444-4444-4444-4444-444444444444"
	write(folder.path_join("proc/5555/comm"), "language_server\n")
	DirAccess.make_dir_recursive_absolute(folder.path_join("proc/5555/fd"))
	write(desktop.path_join("presence/%s.lock" % shown), "")
	OS.execute("ln", ["-s", desktop.path_join("presence/%s.lock" % shown), folder.path_join("proc/5555/fd/9")])
	for id in [shown, recent, idle, subagent]:
		write(desktop.path_join("brain/%s/.system_generated/logs/transcript_full.jsonl" % id), "")
	for id in [shown, recent, idle]:
		write(desktop.path_join("annotations/%s.pbtxt" % id), 'title:"%s"\n' % id.left(4))
	OS.execute("touch", ["-d", "2 hours ago", desktop.path_join("brain/%s/.system_generated/logs/transcript_full.jsonl" % shown)])
	OS.execute("touch", ["-d", "2 hours ago", desktop.path_join("brain/%s/.system_generated/logs/transcript_full.jsonl" % idle)])
	write(folder.path_join("bridge/peers/agy-%s.json" % recent), JSON.stringify({"workspace": folder.path_join("my work")}))
	sense._poll()
	var opened := {}
	for event: Array in _events:
		if event[0] == &"session_opened":
			opened[event[1].session] = event[1]
	check(opened.has(shown), "the conversation the window shows")
	check(opened.has(recent), "a conversation with a recent step")
	check(not opened.has(idle), "no pet for a conversation idle for long")
	check(not opened.has(subagent), "no pet for a subagent: no annotations, unknown to the bridge")
	check_equal(opened[recent].get("pid"), 5555, "its language server")
	check_equal(opened[recent].get("cwd"), folder.path_join("my work"), "its folder, from the bridge")
	check_equal(opened[shown].get("name"), "1111", "named after its title")
	check(opened.has(CONVERSATION), "the agy CLI session is still seen")

	Settings.set_value("agy", "desktop", false)
	sense._scan_in = 0.0
	sense._poll()
	Settings.set_value("agy", "desktop", true)
	var closed := []
	for event: Array in _events:
		if event[0] == &"session_closed":
			closed.append(event[1].session)
	check(shown in closed and recent in closed, "the setting turns the Desktop pets off")
	check(CONVERSATION not in closed, "not the agy CLI ones")
	sense.free()


func test_agy_background_tasks_letters_and_cancel() -> void:
	if OS.get_name() != "Linux":
		return
	var sense := agy_sense()
	add_steps(sense, [{"type": "PLANNER_RESPONSE", "content": "Hello."}])
	check_equal(last_event(&"session_opened").get("name"), "my work", "no title: named after its folder")
	add_steps(sense, [
		{"type": "USER_INPUT", "content": '<USER_REQUEST>\nMessage(s)\n<bridge-message id="1" from="claude:paros-35" ts="x">\nhi\n</bridge-message>\n</USER_REQUEST>'},
		call_step("run_command", {"CommandLine": "sleep 12 && echo done"}),
		result_step("Tool is running as a background task with task id: %s/task-17\nTask Description: sleep" % CONVERSATION, "RUNNING"),
		call_step("run_command", {"CommandLine": '/usr/bin/python3 /home/me/.agent-bridge/bridge.py send claude:paros-35 "ok"'}),
		result_step("The command exited with code 0."),
		{"type": "PLANNER_RESPONSE", "content": "Launched, waiting."},
	])
	check_equal(last_event(&"session_turn"), {"session": CONVERSATION, "origin": &"peer", "from": "claude:paros-35"}, "a turn asked by a peer")
	check_equal(last_event(&"session_message_sent").get("to"), "claude:paros-35", "wrote through the bridge")
	check_equal(last_event(&"session_background").get("background"), 1, "a task runs in the background")
	check_equal(last_event(&"session_phase").get("phase"), &"idle", "the turn is over, the task goes on")
	add_steps(sense, [{"type": "SYSTEM_MESSAGE", "source": "SYSTEM", "content": '<SYSTEM_MESSAGE>\n[Message] timestamp=x sender=%s/task-17 priority=MESSAGE_PRIORITY_HIGH content=Task id "%s/task-17" finished with result:' % [CONVERSATION, CONVERSATION]}])
	check_equal(last_event(&"session_background").get("background"), 0, "the task ended")
	check_equal(last_event(&"session_phase").get("phase"), &"working", "the model takes the result")

	write(folder.path_join("bridge/inbox/agy-%s/1-a.json" % CONVERSATION), "{}")
	sense._poll()
	check_equal(last_event(&"session_mail").get("mail"), 1, "a message of the bridge waits")

	write(sense._log_path, "Stop\t%s\tUSER_CANCELED\n" % CONVERSATION)
	sense._poll()
	check_equal(last_event(&"session_phase").get("phase"), &"idle", "cancelled: at rest with no last answer")
	sense.free()


func test_agy_hook_script_writes_one_line() -> void:
	if OS.get_name() != "Linux":
		return
	var output: Array = []
	var input := '{"conversationId":"%s","terminationReason":"USER_CANCELED","fullyIdle":true}' % CONVERSATION
	write(folder.path_join("input.json"), input)
	var script := ProjectSettings.globalize_path("res://hooks/agy-hook.sh")
	OS.execute("sh", ["-c", "XDG_RUNTIME_DIR='%s' '%s' Stop < '%s'" % [folder, script, folder.path_join("input.json")]], output)
	check_equal(output[0].strip_edges(), "{}", "answers with an empty object")
	check_equal(FileAccess.get_file_as_string(folder.path_join("paros/agy-events.log")), "Stop\t%s\tUSER_CANCELED\n" % CONVERSATION, "one line")


func test_agy_question_subagents_kill_timer_errors_and_checkpoint() -> void:
	if OS.get_name() != "Linux":
		return
	var sense := agy_sense()
	write(folder.path_join("agy/annotations/%s.pbtxt" % CONVERSATION), 'title:"New Conversation"\n')
	add_steps(sense, [
		# An older version of agy: a type per tool result.
		{"type": "USER_INPUT", "content": "<USER_REQUEST>\nold\n</USER_REQUEST>"},
		call_step("run_command", {"CommandLine": "mvn spring-boot:run"}),
		{"type": "RUN_COMMAND", "source": "MODEL", "status": "RUNNING", "content": "Tool is running as a background task with task id: %s/task-3" % CONVERSATION},
		{"type": "PLANNER_RESPONSE", "content": "Started."},
	])
	check_equal(last_event(&"session_opened").get("name"), "my work", "the title agy gives at first is no name")
	check_equal(last_event(&"session_background").get("background"), 1, "a task read from a result of the older format")
	add_steps(sense, [
		{"type": "USER_INPUT", "content": "<USER_REQUEST>\ngo\n</USER_REQUEST>"},
		call_step("manage_task", {"Action": "kill", "TaskId": "%s/task-3" % CONVERSATION}),
	])
	check_equal(last_event(&"session_background").get("background"), 0, "a killed task is over")
	add_steps(sense, [
		result_step('Task "%s/task-3" cancelled.' % CONVERSATION),
		call_step("schedule", {"DurationSeconds": "5", "Prompt": "check"}),
		result_step("Tool is running as a background task with task id: %s/task-9\nTask Description: Timer: 5s" % CONVERSATION, "RUNNING"),
		{"type": "PLANNER_RESPONSE", "content": "Waiting for the timer."},
	])
	check_equal(last_event(&"session_background"), {"session": CONVERSATION, "background": 1, "servers": 0}, "a timer is waited for")
	add_steps(sense, [{"type": "SYSTEM_MESSAGE", "source": "SYSTEM", "content": "[Message] timestamp=x sender=%s/task-9 priority=MESSAGE_PRIORITY_HIGH content=check" % CONVERSATION}])
	check_equal(last_event(&"session_background").get("background"), 0, "the timer went off")
	check_equal(last_event(&"session_phase").get("phase"), &"working", "and wakes the model")

	add_steps(sense, [
		call_step("search_web", {"query": "godot read_link", "toolSummary": "Search"}),
		result_step("The search returned"),
		call_step("view_file", {"AbsolutePath": "/tmp/missing.txt"}),
		{"type": "GENERIC", "source": "MODEL", "status": "ERROR", "error": "failed to read file: stat /tmp/missing.txt", "content": "Encountered error"},
	])
	check(event_names().has(&"session_activity") and _events.any(func(event: Array) -> bool: return event[0] == &"session_activity" and event[1].detail == "godot read_link"), "the search is shown")
	check_equal(last_event(&"session_tool_failed").get("tool"), "view_file", "a tool in error")
	check_equal(last_event(&"session_tool_failed").get("detail"), "failed to read file: stat /tmp/missing.txt", "with its error")

	add_steps(sense, [call_step("ask_question", {"questions": [{"question": "Which database?", "options": ["H2", "PostgreSQL"]}]})])
	check_equal(last_event(&"session_phase").get("phase"), &"waiting", "waits for the answer of the user")
	check_equal(last_event(&"session_needs_you").get("detail"), "Which database?", "the question")
	add_steps(sense, [result_step("A1: H2")])
	check_equal(last_event(&"session_phase").get("phase"), &"working", "answered")

	var subagent := "a42bbca8-3f35-4a43-8637-0409a98ee460"
	add_steps(sense, [
		call_step("invoke_subagent", {"Subagents": [{"Role": "Sense Counter", "TypeName": "research", "Prompt": "count"}]}),
		result_step('Created the following subagents:\n{\n  "conversationId": "%s",\n  "logAbsoluteUri": "file:///x"\n}' % subagent),
	])
	var path := folder.path_join("agy/brain/%s/.system_generated/logs/transcript_full.jsonl" % subagent)
	write(path, "\n".join([
		JSON.stringify({"type": "SYSTEM_MESSAGE", "source": "SYSTEM", "content": "[Message] timestamp=x sender=%s priority=HIGH content=count" % CONVERSATION}),
		JSON.stringify(call_step("run_command", {"CommandLine": "ls src/senses", "toolSummary": "List senses"})),
	]) + "\n")
	sense._poll()
	check_equal(last_event(&"session_subagents").get("agents"), [{"id": subagent, "name": "Sense Counter", "tool": "run_command", "detail": "List senses"}], "a small pet per subagent, with its tool")
	var events_before := _events.size()
	var add_sub := func(steps: Array) -> void:
		var appended := FileAccess.open(path, FileAccess.READ_WRITE)
		appended.seek_end()
		for step: Dictionary in steps:
			appended.store_string(JSON.stringify(step) + "\n")
		appended.close()
		sense._poll()
	add_sub.call([
		result_step("Tool is running as a background task with task id: %s/task-5" % subagent, "RUNNING"),
		{"type": "PLANNER_RESPONSE", "content": "Waiting for the command."},
	])
	add_sub.call([
		{"type": "SYSTEM_MESSAGE", "source": "SYSTEM", "content": "[Message] timestamp=x sender=%s/task-5 priority=HIGH content=done" % subagent},
		call_step("run_command", {"CommandLine": "wc -l x"}),
	])
	check(_events.slice(events_before).all(func(event: Array) -> bool: return event[0] != &"session_subagents" or event[1].count == 1), "it stays while it waits for its background task")
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string(JSON.stringify(result_step("The command exited with code 2.")) + "\n" + JSON.stringify({"type": "PLANNER_RESPONSE", "content": "16 files."}) + "\n")
	file.close()
	sense._poll()
	check_equal(last_event(&"session_tool_failed").get("agent"), subagent, "the failure of the subagent")
	check_equal(last_event(&"session_subagents").get("count"), 0, "its work is done")

	add_steps(sense, [{"type": "CHECKPOINT", "source": "SYSTEM", "content": "{{ CHECKPOINT 0 }} The earlier parts of this conversation have been truncated"}])
	check_equal(last_event(&"session_compacting"), {"session": CONVERSATION, "compacting": false, "auto": true}, "the context was truncated")
	sense.free()
