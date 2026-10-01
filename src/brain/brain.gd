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
## Uncommitted lines from which the pile of folders gains a level.
const BAGGAGE_LEVELS: Array[int] = [1, 50, 300]
## Distance kept from the pointer by the pet that sleeps beside it, at size 1.
const CUDDLE_GAP := 70.0

@export var pets: Pets

var _night := false
var _user_idle := false
## Session id -> what the senses told about it: name, color, cwd, last_prompt,
## pid, context, phase, since, tool, detail, count, stalled, branch, dirty,
## behind, conflict. Plus "nagged". Times are Unix times.
var _sessions := {}
## Frame of the focused window. No size: none, or not known.
var _active_window := Rect2()
## Pet that sleeps beside the still pointer. Null: none.
var _cuddler: Pet = null


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
		&"pointer_double":
			_go_to_terminal(pet.key)
		&"pointer_grab":
			pet.grab()
		&"pointer_drop":
			pet.release()
		&"files_dropped":
			# Typing into another terminal is not allowed: the paths go to the clipboard.
			DisplayServer.clipboard_set(" ".join(Array(data.files).map(func(path: String) -> String: return "'%s'" % path)))
			pet.say("Chemin copié : colle-le dans le terminal")
		&"locate_requested":
			Desktop.ring_terminal(_sessions.get(pet.key, {}).get("pid", 0))
		&"night":
			_night = true
		&"day":
			_night = false
		&"user_idle":
			_user_idle = true
		&"user_active":
			_user_idle = false
		&"session_closed":
			pets.remove(data.session)
			_sessions.erase(data.session)
			if pets.keys().is_empty():
				pets.add(NO_SESSION)
		&"session_phase":
			pet.urgent = false
		&"session_finished":
			pet.cheer()
			pet.say("Tâche finie !")
			pets.celebrate(pet)
		&"session_needs_you":
			pet.say(data.detail if not data.detail.is_empty() else "Claude attend ta réponse")
		&"session_tests_passed":
			pet.cheer()
			pet.say("Tests verts !")
			pets.celebrate(pet)
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
				for key: String in pets.keys():
					pets.find(key).roast()
		&"battery_low":
			if Settings.value("system", "alerts"):
				_tell_all("Batterie faible : %d %%" % data.percent)
		&"desktop_state":
			# A full screen window has no top edge to stand on.
			_active_window = Rect2() if data.fullscreen else data.active
		&"pointer_idle":
			_send_cuddler(data.position)
		&"pointer_moved":
			_cuddler = null
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


## Sets what follows from the whole state: look, wish, caption and card of
## each pet.
func _refresh() -> void:
	for key: String in pets.keys():
		var pet := pets.find(key)
		var session: Dictionary = _sessions.get(key, {})
		var phase: StringName = session.get("phase", &"idle")
		if not session.is_empty():
			_dress(pet, session)
		pet.perch = _active_window
		pet.wish = Pet.Wish.SLEEP if pet == _cuddler else _wish(phase)
		pet.tapping = session.get("stalled", false)
		pet.caption = _activity(session) if phase == &"working" and Settings.value("claude", "show_activity") else ""
		pet.show_card(_card(session) if pet.hovered else "")


## Look of the pet, from what is known of its session.
func _dress(pet: Pet, session: Dictionary) -> void:
	var branch: String = session.get("branch", "")
	pet.label = session.name if branch.is_empty() else "%s · %s" % [session.name, branch]
	pet.color = COLORS.get(session.color, Pet.DEFAULT_COLOR)
	# From the name: the same session keeps its accessory.
	pet.accessory = posmod(hash(session.name), Pet.ACCESSORY_COUNT)
	pet.fullness = session.context / (Settings.value("claude", "context_window_k") * 1000.0)
	pet.baggage = BAGGAGE_LEVELS.filter(func(level: int) -> bool: return session.get("dirty", 0) >= level).size()
	pet.hard_hat = session.get("conflict", false)
	pet.lost = session.get("behind", 0) > 0
	# Same folder, same branch: same work.
	pet.repo = "" if branch.is_empty() else "%s@%s" % [session.cwd, branch]


## Highest priority first.
func _wish(phase: StringName) -> Pet.Wish:
	if phase == &"waiting":
		return Pet.Wish.ALERT
	if phase == &"working":
		return Pet.Wish.THINK
	if _night or _user_idle:
		return Pet.Wish.SLEEP
	return Pet.Wish.ROAM


## Sends the nearest free pet to sleep beside the still pointer.
func _send_cuddler(pointer: Vector2) -> void:
	if not Settings.value("desktop", "cuddle"):
		return
	var nearest: Pet = null
	for key: String in pets.keys():
		var pet := pets.find(key)
		if pet.is_free() and not pet.is_perched() and (nearest == null or absf(pet.feet().x - pointer.x) < absf(nearest.feet().x - pointer.x)):
			nearest = pet
	if nearest:
		_cuddler = nearest
		var side := signf(nearest.feet().x - pointer.x)
		nearest.walk_to(pointer.x + side * CUDDLE_GAP * nearest.scale_factor())


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
		if session.context > 0:
			lines.append("Contexte : %d k tokens (%d %%)" % [session.context / 1000, pets.find(session.session).fullness * 100.0])
		lines.append_array(_repo_lines(session))
		if not session.last_prompt.is_empty():
			lines.append("« %s »" % session.last_prompt.left(PROMPT_MAX_LENGTH).replace("\n", " "))
	match Focus.phase:
		Focus.Phase.FOCUS:
			lines.append("Focus : reste %d min" % Focus.minutes_left())
		Focus.Phase.BREAK:
			lines.append("Pause : reste %d min" % Focus.minutes_left())
	return "\n".join(lines)


func _repo_lines(session: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	if session.get("conflict", false):
		lines.append("Fusion ou rebase à terminer")
	if session.get("dirty", 0) > 0:
		lines.append("Non commité : %d lignes" % session.dirty)
	if session.get("behind", 0) > 0:
		lines.append("En retard de %d commits sur origin" % session.behind)
	return lines


func _tell_all(text: String, happy := false) -> void:
	for key: String in pets.keys():
		pets.find(key).say(text)
		if happy:
			pets.find(key).cheer()


## Brings the terminal of the session to the front, and rings its bell: when
## the session is in a background tab, the bell marks which one.
func _go_to_terminal(key: String) -> void:
	var session: Dictionary = _sessions.get(key, {})
	if session.is_empty():
		return
	Desktop.focus_terminal(session.pid, session.name)
	Desktop.ring_terminal(session.pid)


func _duration(seconds: float) -> String:
	if seconds < 60.0:
		return "%d s" % seconds
	if seconds < 3600.0:
		return "%d min" % (seconds / 60.0)
	return "%d h %02d" % [seconds / 3600.0, fmod(seconds, 3600.0) / 60.0]


func _now() -> float:
	return Time.get_unix_time_from_system()
