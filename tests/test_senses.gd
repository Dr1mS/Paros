extends "res://tests/test_case.gd"
## What the senses read: Claude Code files, hook log, git output, desktop file,
## media players.

const SESSION := "11111111-2222-3333-4444-555555555555"

var folder := OS.get_environment("XDG_RUNTIME_DIR").path_join("test-senses")


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


func test_live_session_opens_then_closes() -> void:
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


func test_dead_or_background_sessions_are_ignored() -> void:
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
		["PreToolUse", "", "Edit", "pet.gd", ""],
		["PostToolUse", "", "Bash", "Run tests", "test"],
		["PostToolUseFailure", "", "Bash", "Build", ""],
		["SubagentStart", "", "", "", ""],
		["SubagentStart", "", "", "", ""],
		["SubagentStop", "", "", "", ""],
		["Notification", "permission_prompt", "", "Claude needs your permission to use Bash", ""],
	]
	var text := ""
	for line: Array in lines:
		text += "\t".join([line[0], SESSION, line[1], line[2], line[3], line[4]]) + "\n"
	text += "PreToolUse\tsome-other-session\t\tEdit\tx\t\n"
	write(sense._log_path, text)
	sense._poll()
	check_equal(last_event(&"session_activity").get("detail"), "pet.gd", "tool in use, unknown session ignored")
	check(&"session_tests_passed" in event_names(), "green tests")
	check_equal(last_event(&"session_tool_failed").get("tool"), "Bash", "failed command")
	check_equal(last_event(&"session_subagents").get("count"), 1, "two started, one stopped")
	check_equal(last_event(&"session_needs_you").get("detail"), "Claude needs your permission to use Bash", "question")
	check_equal(last_event(&"session_phase").get("phase"), &"waiting", "waiting although the registry says busy")

	write(sense._log_path, text + "\t".join(["Stop", SESSION, "", "", "", ""]) + "\n")
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
		'{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"cd x && npm run test","description":"Run unit tests"}}',
		'{"session_id":"s1","hook_event_name":"Notification","message":"Claude needs your permission","notification_type":"permission_prompt"}',
		'{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls","description":"%s"}}' % "x".repeat(300),
	]
	for input: String in runs:
		write(folder.path_join("input.json"), input)
		OS.execute("sh", ["-c", "XDG_RUNTIME_DIR='%s' '%s' < '%s'" % [folder, script, folder.path_join("input.json")]])
	var lines := FileAccess.get_file_as_string(folder.path_join("paros/claude-events.log")).split("\n", false)
	check_equal(lines.size(), 4, "one line per event")
	check_equal(Array(lines[0].split("\t")), ["PreToolUse", "s1", "", "Edit", "pet.gd", ""], "file name of an edit")
	check_equal(Array(lines[1].split("\t")), ["PostToolUse", "s1", "", "Bash", "Run unit tests", "test"], "a test command")
	check_equal(Array(lines[2].split("\t")), ["Notification", "s1", "permission_prompt", "", "Claude needs your permission", ""], "a question")
	check_equal(lines[3].split("\t")[4].length(), 120, "long detail cut")
