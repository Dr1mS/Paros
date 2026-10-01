extends Node
## Follows the Claude Code sessions running on this machine.
## Posts, each with {session}:
##   session_opened {name, color}, session_changed {name, color}, session_closed,
##   session_phase {phase: &"idle" | &"working" | &"waiting"},
##   session_finished, session_needs_you.
##
## Reads three kinds of local files:
## - <claude dir>/sessions/<pid>.json: one per live session, with its name and
##   status. Internal Claude Code format, not documented: may change.
## - the session transcript: the color chosen with /color.
## - the log written by hooks/claude-hook.sh, one line per hook event:
##   "<hook_event_name> <session_id> <notification_type>".

const POLL_SECONDS := 0.5
## Notification types that mean Claude waits for the user.
const ASKING: Array[String] = ["permission_prompt", "elicitation_dialog"]
const COLOR_LINE := '{"type":"agent-color"'

var _claude_dir := OS.get_environment("HOME").path_join(".claude")
var _log_path := "/tmp/paros/claude-events.log"
var _log_offset := 0
## Session id -> {name, color, phase, asking, transcript, transcript_offset}.
var _sessions := {}


func _ready() -> void:
	if OS.has_environment("CLAUDE_CONFIG_DIR"):
		_claude_dir = OS.get_environment("CLAUDE_CONFIG_DIR")
	if OS.has_environment("XDG_RUNTIME_DIR"):
		_log_path = OS.get_environment("XDG_RUNTIME_DIR").path_join("paros/claude-events.log")
	# Skip history: only hook events from now on matter.
	var file := FileAccess.open(_log_path, FileAccess.READ)
	if file:
		_log_offset = file.get_length()
	var timer := Timer.new()
	timer.wait_time = POLL_SECONDS
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)
	_poll()


func _poll() -> void:
	var live := _read_registry()
	for id: String in _sessions.keys():
		if not live.has(id):
			_sessions.erase(id)
			Events.post(&"session_closed", {"session": id})
	for id: String in live:
		_update(id, live[id])
	_read_hook_log()
	for id: String in _sessions:
		_update_phase(id, live[id].get("status", "idle"))


## Session id -> registry entry, for each live interactive session.
func _read_registry() -> Dictionary:
	var live := {}
	var folder := _claude_dir.path_join("sessions")
	for file_name in DirAccess.get_files_at(folder):
		if file_name.get_extension() != "json":
			continue
		var entry: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file_name)))
		if entry is Dictionary and entry.get("kind") == "interactive" and entry.has("sessionId") and _is_running(entry):
			live[entry.sessionId] = entry
	return live


## A crashed session leaves its registry file behind.
func _is_running(entry: Dictionary) -> bool:
	if OS.get_name() != "Linux":
		return true
	return DirAccess.dir_exists_absolute("/proc/%d" % entry.get("pid", 0))


func _update(id: String, entry: Dictionary) -> void:
	var opened := not _sessions.has(id)
	if opened:
		_sessions[id] = {"name": "", "color": "", "phase": &"idle", "asking": false, "transcript": "", "transcript_offset": 0}
	var session: Dictionary = _sessions[id]
	var name_now: String = entry.get("name", "")
	var color_now := _read_color(id, session)
	if opened or name_now != session.name or color_now != session.color:
		session.name = name_now
		session.color = color_now
		Events.post(&"session_opened" if opened else &"session_changed", {"session": id, "name": name_now, "color": color_now})


## Reads only what was added to the transcript since the last call.
func _read_color(id: String, session: Dictionary) -> String:
	var color: String = session.color
	if session.transcript.is_empty():
		session.transcript = _find_transcript(id)
	var file := FileAccess.open(session.transcript, FileAccess.READ)
	if file == null:
		return color
	file.seek(session.transcript_offset)
	while file.get_position() < file.get_length():
		var line := file.get_line()
		if line.begins_with(COLOR_LINE):
			var parsed: Variant = JSON.parse_string(line)
			if parsed is Dictionary:
				color = parsed.get("agentColor", "")
	session.transcript_offset = file.get_position()
	return color


func _find_transcript(id: String) -> String:
	var projects := _claude_dir.path_join("projects")
	for project in DirAccess.get_directories_at(projects):
		var path := projects.path_join(project).path_join(id + ".jsonl")
		if FileAccess.file_exists(path):
			return path
	return ""


func _read_hook_log() -> void:
	var file := FileAccess.open(_log_path, FileAccess.READ)
	if file == null:
		return
	if file.get_length() < _log_offset:
		_log_offset = 0
	file.seek(_log_offset)
	while file.get_position() < file.get_length():
		var parts := file.get_line().split(" ")
		if parts.size() < 3 or not _sessions.has(parts[1]):
			continue
		var session: Dictionary = _sessions[parts[1]]
		session.asking = parts[0] == "Notification" and parts[2] in ASKING
		if session.asking:
			Events.post(&"session_needs_you", {"session": parts[1]})
		elif parts[0] == "Stop":
			Events.post(&"session_finished", {"session": parts[1]})
	_log_offset = file.get_position()


func _update_phase(id: String, status: String) -> void:
	var session: Dictionary = _sessions[id]
	if status == "idle":
		session.asking = false
	var phase := &"idle"
	if session.asking or status == "waiting":
		phase = &"waiting"
	elif status == "busy":
		phase = &"working"
	if phase != session.phase:
		session.phase = phase
		Events.post(&"session_phase", {"session": id, "phase": phase})
