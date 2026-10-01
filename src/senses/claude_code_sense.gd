extends Node
## Follows the Claude Code sessions running on this machine.
## Posts, each with {session}:
##   session_opened, session_changed {name, color, cwd, last_prompt, pid, context},
##     context: tokens in the context window of the session,
##   session_closed,
##   session_phase {phase: &"idle" | &"working" | &"waiting", since: Unix time},
##   session_activity {tool, detail}, session_subagents {count},
##   session_quiet {level}: working with no hook event, 0: for a moment,
##     1: for a while, 2: for long,
##   session_needs_you {detail}, session_finished,
##   session_tool_failed {tool, detail, kind}, session_tests_passed.
##
## Reads three kinds of local files:
## - <claude dir>/sessions/<pid>.json: one per live session, with its name and
##   status. Internal Claude Code format, not documented: may change.
## - the session transcript: color (/color), last prompt, token use.
## - the log written by hooks/claude-hook.sh, one line per hook event.

## Fields of a hook log line, separated by tabs.
enum Field { EVENT, SESSION, NOTIFICATION, TOOL, DETAIL, KIND, COUNT }

const POLL_SECONDS := 0.5
## Notification types that mean Claude waits for the user.
const ASKING: Array[String] = ["permission_prompt", "elicitation_dialog"]
const COLOR_LINE := '{"type":"agent-color"'
const PROMPT_LINE := '{"type":"last-prompt"'
## In the transcript line of each answer of the model.
const USAGE_MARK := '"usage":{'
## Tokens are posted rounded to this step, to post less often.
const TOKEN_STEP := 10000
## Seconds without hook event that make a working session quiet at level 1,
## then 2. Long thinking or slow network: the two look the same from here.
const QUIET_SECONDS: Array[float] = [8.0, 25.0]
## Session fields that the pet shows: a change posts session_changed.
const SHOWN: Array[String] = ["name", "color", "cwd", "last_prompt", "pid", "context"]

var _claude_dir := _home().path_join(".claude")
var _log_path := "/tmp/paros/claude-events.log"
var _log_offset := 0
## Session id -> the SHOWN fields, plus phase, asking, subagents, transcript,
## transcript_offset, heard (time of the last hook event), quiet.
var _sessions := {}
## Input token counts of an answer: fresh, written to cache, read from cache.
var _token_counts := RegEx.create_from_string('"(?:input_tokens|cache_creation_input_tokens|cache_read_input_tokens)":(\\d+)')


func _ready() -> void:
	if OS.has_environment("CLAUDE_CONFIG_DIR"):
		_claude_dir = OS.get_environment("CLAUDE_CONFIG_DIR")
	# Same folder as the hook script: the runtime folder, else the temporary one.
	for variable: String in ["XDG_RUNTIME_DIR", "TEMP"]:
		if OS.has_environment(variable):
			_log_path = OS.get_environment(variable).path_join("paros/claude-events.log")
			break
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
		_update_phase(id, live[id])


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
		_sessions[id] = {
			"name": "", "color": "", "cwd": "", "last_prompt": "", "pid": 0, "context": 0,
			"phase": &"", "asking": false, "subagents": 0, "transcript": "", "transcript_offset": 0,
			"heard": _now(), "quiet": 0,
		}
	var session: Dictionary = _sessions[id]
	var before := _shown(session)
	session.name = entry.get("name", "")
	session.cwd = entry.get("cwd", "")
	session.pid = int(entry.get("pid", 0))
	_read_transcript(id, session)
	var shown := _shown(session)
	if opened or shown != before:
		shown.session = id
		Events.post(&"session_opened" if opened else &"session_changed", shown)


func _shown(session: Dictionary) -> Dictionary:
	var shown := {}
	for field in SHOWN:
		shown[field] = session[field]
	return shown


## Reads only what was added to the transcript since the last call.
func _read_transcript(id: String, session: Dictionary) -> void:
	if session.transcript.is_empty():
		session.transcript = _find_transcript(id)
	var file := FileAccess.open(session.transcript, FileAccess.READ)
	if file == null:
		return
	file.seek(session.transcript_offset)
	while file.get_position() < file.get_length():
		var line := file.get_line()
		if line.begins_with(COLOR_LINE):
			session.color = _json_field(line, "agentColor")
		elif line.begins_with(PROMPT_LINE):
			session.last_prompt = _json_field(line, "lastPrompt")
		elif USAGE_MARK in line:
			session.context = _count_tokens(line)
	session.transcript_offset = file.get_position()


## Size of the context sent for an answer: its three input counts, added.
func _count_tokens(line: String) -> int:
	var tokens := 0
	# The counts come first in the usage object: stop before any other number.
	for found in _token_counts.search_all(line, line.find(USAGE_MARK)).slice(0, 3):
		tokens += found.get_string(1).to_int()
	return roundi(float(tokens) / TOKEN_STEP) * TOKEN_STEP


func _json_field(line: String, field: String) -> String:
	var parsed: Variant = JSON.parse_string(line)
	return str(parsed.get(field, "")) if parsed is Dictionary else ""


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
		var fields := file.get_line().split("\t")
		if fields.size() == Field.COUNT and _sessions.has(fields[Field.SESSION]):
			_handle_hook(fields)
	_log_offset = file.get_position()


func _handle_hook(fields: PackedStringArray) -> void:
	var id := fields[Field.SESSION]
	var session: Dictionary = _sessions[id]
	var event := fields[Field.EVENT]
	session.heard = _now()
	# Any later event means the question was answered.
	session.asking = event == "Notification" and fields[Field.NOTIFICATION] in ASKING
	match event:
		"Notification":
			if session.asking:
				Events.post(&"session_needs_you", {"session": id, "detail": fields[Field.DETAIL]})
		"PreToolUse":
			Events.post(&"session_activity", {"session": id, "tool": fields[Field.TOOL], "detail": fields[Field.DETAIL]})
		"PostToolUse":
			if fields[Field.KIND] == "test":
				Events.post(&"session_tests_passed", {"session": id})
		"PostToolUseFailure":
			Events.post(&"session_tool_failed", {
				"session": id, "tool": fields[Field.TOOL], "detail": fields[Field.DETAIL], "kind": fields[Field.KIND],
			})
		"SubagentStart", "SubagentStop":
			session.subagents = maxi(session.subagents + (1 if event == "SubagentStart" else -1), 0)
			Events.post(&"session_subagents", {"session": id, "count": session.subagents})
		"Stop":
			Events.post(&"session_finished", {"session": id})


func _update_phase(id: String, entry: Dictionary) -> void:
	var session: Dictionary = _sessions[id]
	var status: String = entry.get("status", "idle")
	if status == "idle":
		session.asking = false
	var phase := &"idle"
	if session.asking or status == "waiting":
		phase = &"waiting"
	elif status == "busy":
		phase = &"working"
	if phase != session.phase:
		var since := Time.get_unix_time_from_system()
		# First look at a session: its phase began before, at the time the registry gives.
		if session.phase.is_empty() and entry.has("statusUpdatedAt"):
			since = entry.statusUpdatedAt / 1000.0
		session.phase = phase
		session.heard = _now()
		Events.post(&"session_phase", {"session": id, "phase": phase, "since": since})
	var silent_for: float = _now() - session.heard if phase == &"working" else 0.0
	var quiet := QUIET_SECONDS.filter(func(seconds: float) -> bool: return silent_for >= seconds).size()
	if quiet != session.quiet:
		session.quiet = quiet
		Events.post(&"session_quiet", {"session": id, "level": quiet})


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _home() -> String:
	return OS.get_environment("USERPROFILE" if OS.get_name() == "Windows" else "HOME")
