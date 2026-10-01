extends Node
## Turns sensed events into pet behavior. All rules live here.
## One pet per Claude Code session. With no session, one pet with no name.

## Key of the pet shown when no session exists.
const NO_SESSION := ""
## Claude Code session colors (/color).
const COLORS := {
	"red": Color("#e5484d"),
	"blue": Color("#4a90e2"),
	"green": Color("#46a758"),
	"yellow": Color("#e2b93b"),
	"purple": Color("#8e6fd8"),
	"orange": Color("#f08c3a"),
	"pink": Color("#e86aa6"),
	"cyan": Color("#3bb8c4"),
}
const TICK_SECONDS := 1.0
## Seconds between two reminders of the same waiting session.
const NAG_REPEAT_SECONDS := 60.0
const PATH_MAX_LENGTH := 38
const PROMPT_MAX_LENGTH := 70

@export var pets: Pets

var _night := false
var _user_idle := false
## Session id -> what the sense told about it: name, cwd, branch, last_prompt,
## pid, phase, since, tool, detail, count. Plus "nagged". Times are Unix times.
var _sessions := {}


func _ready() -> void:
	Events.sensed.connect(_on_sensed)
	pets.add(NO_SESSION)
	var timer := Timer.new()
	timer.wait_time = TICK_SECONDS
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)


func _on_sensed(event: StringName, data: Dictionary) -> void:
	# Session events: keep what was told, then find the pet.
	var pet: Pet = data.get("pet")
	if data.has("session"):
		if event == &"session_opened":
			pets.remove(NO_SESSION)
			pets.add(data.session)
			_sessions[data.session] = {"phase": &"idle", "since": _now(), "nagged": 0.0}
		if not _sessions.has(data.session):
			return
		_sessions[data.session].merge(data, true)
		pet = pets.find(data.session)

	match event:
		&"pointer_tap":
			pet.cheer()
		&"pointer_grab":
			pet.grab()
		&"pointer_drop":
			pet.release()
		&"locate_requested":
			_ring_terminal(pet.key)
		&"night":
			_night = true
		&"day":
			_night = false
		&"user_idle":
			_user_idle = true
		&"user_active":
			_user_idle = false
		&"session_opened", &"session_changed":
			_dress(pet, data)
		&"session_closed":
			pets.remove(data.session)
			_sessions.erase(data.session)
			if pets.keys().is_empty():
				pets.add(NO_SESSION)
		&"session_phase":
			pet.urgent = false
		&"session_subagents":
			pet.minis = data.count
		&"session_finished":
			pet.cheer()
			pet.say("Tâche finie !")
		&"session_needs_you":
			pet.say(data.detail if not data.detail.is_empty() else "Claude attend ta réponse")
		&"session_tests_passed":
			pet.cheer()
			pet.say("Tests verts !")
		&"session_tool_failed":
			pet.worry()
			if data.kind == "test":
				pet.say("Tests rouges")
		&"focus_started":
			_tell_all("Focus : %d min" % Settings.value("focus", "minutes"))
		&"focus_finished":
			_tell_all("Pause ! %d min" % Settings.value("focus", "break_minutes"), true)
		&"break_finished":
			_tell_all("Fin de pause. On reprend ?")
		&"cpu_hot":
			if Settings.value("system", "alerts"):
				_tell_all("Processeur chaud : %d °C" % data.celsius, false, true)
		&"battery_low":
			if Settings.value("system", "alerts"):
				_tell_all("Batterie faible : %d %%" % data.percent, false, true)
	_refresh()


## Every second: cards show durations, and a long wait gets a reminder.
func _tick() -> void:
	var nag_after: float = Settings.value("claude", "nag_minutes") * 60.0
	for key: String in _sessions:
		var session: Dictionary = _sessions[key]
		var waited: float = _now() - session.since
		if session.phase == &"waiting" and waited >= nag_after and _now() - session.nagged >= NAG_REPEAT_SECONDS:
			session.nagged = _now()
			pets.find(key).urgent = true
			pets.find(key).say("Claude attend depuis %s" % _duration(waited))
	_refresh()


## Sets what follows from the whole state: wish, caption and card of each pet.
func _refresh() -> void:
	for key: String in pets.keys():
		var pet := pets.find(key)
		var session: Dictionary = _sessions.get(key, {})
		var phase: StringName = session.get("phase", &"idle")
		pet.wish = _wish(phase)
		pet.caption = _activity(session) if phase == &"working" and Settings.value("claude", "show_activity") else ""
		pet.show_card(_card(session) if pet.hovered else "")


func _dress(pet: Pet, data: Dictionary) -> void:
	pet.label = data.name if data.branch.is_empty() else "%s · %s" % [data.name, data.branch]
	pet.color = COLORS.get(data.color, Pet.DEFAULT_COLOR)
	# From the name: the same session keeps its accessory.
	pet.accessory = posmod(hash(data.name), Pet.ACCESSORY_COUNT)


## Highest priority first.
func _wish(phase: StringName) -> Pet.Wish:
	if phase == &"waiting":
		return Pet.Wish.ALERT
	if phase == &"working":
		return Pet.Wish.THINK
	if _night or _user_idle:
		return Pet.Wish.SLEEP
	return Pet.Wish.ROAM


## Tool in use, such as "Edit · pet.gd".
func _activity(session: Dictionary) -> String:
	var tool: String = session.get("tool", "")
	var detail: String = session.get("detail", "")
	return tool if detail.is_empty() else "%s · %s" % [tool, detail]


## Text of the card shown while the mouse is over the pet.
func _card(session: Dictionary) -> String:
	var lines: PackedStringArray = []
	if not session.is_empty():
		var folder: String = session.cwd.replace(OS.get_environment("HOME"), "~")
		if folder.length() > PATH_MAX_LENGTH:
			folder = "…" + folder.right(PATH_MAX_LENGTH - 1)
		lines.append(folder)
		var lasted := _duration(_now() - session.since)
		match session.phase:
			&"working":
				lines.append("Travaille depuis %s" % lasted)
				if not _activity(session).is_empty():
					lines.append(_activity(session))
			&"waiting":
				lines.append("Attend ta réponse depuis %s" % lasted)
			_:
				lines.append("Au repos depuis %s" % lasted)
		if session.get("count", 0) > 0:
			lines.append("Sous-agents en cours : %d" % session.count)
		if not session.last_prompt.is_empty():
			lines.append("« %s »" % session.last_prompt.left(PROMPT_MAX_LENGTH).replace("\n", " "))
	match Focus.phase:
		Focus.Phase.FOCUS:
			lines.append("Focus : reste %d min" % Focus.minutes_left())
		Focus.Phase.BREAK:
			lines.append("Pause : reste %d min" % Focus.minutes_left())
	return "\n".join(lines)


func _tell_all(text: String, happy := false, worried := false) -> void:
	for key: String in pets.keys():
		var pet := pets.find(key)
		pet.say(text)
		if happy:
			pet.cheer()
		if worried:
			pet.worry()


## Rings the bell of the terminal that runs the session: its tab gets a mark.
## Linux only: writes to the terminal of the process.
func _ring_terminal(key: String) -> void:
	var terminal := FileAccess.open("/proc/%d/fd/0" % _sessions.get(key, {}).get("pid", 0), FileAccess.WRITE)
	if terminal:
		terminal.store_string("\a")


func _duration(seconds: float) -> String:
	if seconds < 60.0:
		return "%d s" % seconds
	if seconds < 3600.0:
		return "%d min" % (seconds / 60.0)
	return "%d h %02d" % [seconds / 3600.0, fmod(seconds, 3600.0) / 60.0]


func _now() -> float:
	return Time.get_unix_time_from_system()
