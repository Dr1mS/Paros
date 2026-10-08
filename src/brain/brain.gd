extends Node
## Turns sensed events into pet behavior. All rules live here, but the games
## of the small pets: see small_pets.gd.
## One pet per Claude Code session. With no session, one pet with no name.
## One small pet per running subagent, beside the pet of its session.
## One boss beside a pet whose session asks the advisor.

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
const SUMMARY_MAX_LENGTH := 220
## Uncommitted lines from which the pile of folders gains a level.
const BAGGAGE_LEVELS: Array[int] = [1, 50, 300]
## Distance kept from the pointer by the pet that sleeps beside it, at size 1.
const CUDDLE_GAP := 70.0
## A session waits and its terminal is not focused for this long: its pet
## knocks on the screen edge. Then again at each repeat.
const KNOCK_AFTER_SECONDS := 20.0
const KNOCK_REPEAT_SECONDS := 30.0
## Distance from the screen edge to the feet of a knocking pet, at size 1.
const KNOCK_REACH := 72.0
## Walk pace when the machine does nothing, and when every core is busy.
const PACE_RANGE := Vector2(0.7, 1.6)
## Sessions at rest for this long gather in a tower.
const TOWER_AFTER_SECONDS := 90.0
## Height of one sitting pet, and width of the head a pet stands on, at size 1.
const TOWER_LEVEL := 72.0
const TOWER_WIDTH := 200.0
## Seconds two pets stay rivals after their sessions wrote the same file.
const RIVAL_SECONDS := 600.0
## Seconds of sunglasses after a commit that leaves nothing to commit.
const COOL_SECONDS := 60.0
## The boss: the advisor a session asks, as a bigger pet with a word on its
## belly and a top hat. Its key from the key of the session, its body size
## against a normal pet, and its accessory.
const BOSS_KEY := "%s/boss"
const BOSS_STATURE := 1.5
const BOSS_BADGE := "BOSS"
const BOSS_HAT := 1
## Distance from the pet where the boss stands, and from where it walks in,
## at size 1.
const BOSS_GAP := 230.0
const BOSS_ENTRY := 460.0
const BOSS_HURRY := 2.0
## The boss stays at least this long, so that a quick answer is seen. And no
## longer than that: the answer of the advisor may be missed.
const BOSS_MIN_SECONDS := 5.0
const BOSS_MAX_SECONDS := 300.0
## Once it answered, the boss walks off the screen. It is removed there, or
## after this many seconds: it may be held back on its way.
const BOSS_LEAVE_SECONDS := 30.0
const SmallPets := preload("res://src/brain/small_pets.gd")

@export var pets: Pets

var _night := false
var _user_idle := false
## True while a media player plays.
var _music := false
## Session id -> what the senses told about it: name, color, cwd, last_prompt,
## pid, context, summary, phase, since, tool, detail, count, agents, stalled, branch, dirty,
## behind, conflict, level, background, servers, mail. Plus "nagged", "knocked",
## "unfocused_since", "cool_until", "lineage", "inbound" (letters that fly to
## its pet), "origin" and "from" (what started its turn), "dispute" and "dispute_until" (file it fights
## over with another session, and until when), "asked" (id of the
## session it wrote to in that turn), "owed" (a cheer held back by a turn that
## ended on a wait), "boss" (&"asked" while its boss reads, &"leaving" once it
## answered), "boss_since", "boss_done" (when the boss answers) and
## "boss_gone" (when it is removed). Times are Unix times.
var _sessions := {}
## Frame of the focused window. No size: none, or not known.
var _active_window := Rect2()
## Process that owns the focused window. -1: not known.
var _active_pid := -1
## Screens under a full screen window.
var _covered: Array[Rect2] = []
## Last known pointer position, in screen coordinates.
var _pointer := Vector2.ZERO
var _pointer_known := false
## Pet that sleeps beside the still pointer. Null: none.
var _cuddler: Pet = null
## Pets stacked on each other, the one on the ground first.
var _tower: Array[Pet] = []
## Runnable tasks per core. 1: every core busy.
var _load := 0.0
## True while the lock screen is up. The pets show on it, without any text.
var _locked := false
## Unix time until which the screen is held on, once locked.
var _screen_held_until := 0.0
var _screen_held := false
var _small := SmallPets.new()


func _ready() -> void:
	Events.sensed.connect(_on_sensed)
	# A setting applies at once, not at the next event.
	Settings.changed.connect(_refresh)
	_small.pets = pets
	add_child(_small)
	pets.add(NO_SESSION)
	var timer := Timer.new()
	timer.wait_time = TICK_SECONDS
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)


func _on_sensed(event: StringName, data: Dictionary) -> void:
	# Session events: keep what was told, then find the pet.
	var pet: Pet = data.get("pet")
	var mail_before := 0
	if data.has("session"):
		if event == &"session_opened":
			pets.remove(NO_SESSION)
			pets.add(data.session)
			_sessions[data.session] = {
				"phase": &"idle", "since": _now(), "nagged": 0.0, "knocked": 0.0, "unfocused_since": _now(),
				"lineage": Desktop.lineage(data.pid),
					# Windows: the list of processes may come after the session. Asked again later.
					"lineage_pending": OS.get_name() == "Windows" and Desktop.lineage(data.pid).size() < 2,
			}
		if not _sessions.has(data.session):
			return
		mail_before = _sessions[data.session].get("mail", 0)
		_sessions[data.session].merge(data, true)
		pet = pets.find(data.session)

	match event:
		&"pointer_at":
			# Comes twice a second while the pointer moves: nothing else to update.
			_pointer = data.position
			_pointer_known = true
			return
		&"pet_landed":
			Sound.play(&"thud")
		&"pet_knocked":
			Sound.play(&"knock")
		&"system_load":
			_load = data.load
		&"music":
			_music = data.playing
		&"screen_locked":
			_locked = data.locked
			_screen_held_until = _now() + Settings.value("desktop", "lock_screen_minutes") * 60.0
			_hold_screen()
		&"repo_cleaned":
			pet.sweep()
			_sessions[data.session].cool_until = _now() + COOL_SECONDS
		&"pointer_tap":
			pet.cheer()
		&"pointer_double":
			_go_to_terminal(_small.session_of(pet))
		&"pointer_grab":
			pet.grab()
		&"pointer_drop":
			pet.release()
		&"files_dropped":
			# Typing into another terminal is not allowed: the paths go to the clipboard.
			DisplayServer.clipboard_set(" ".join(Array(data.files).map(func(path: String) -> String: return "'%s'" % path)))
			pet.say(tr("Path copied: paste it in the terminal"))
		&"locate_requested":
			Desktop.ring_terminal(_sessions.get(_small.session_of(pet), {}).get("pid", 0))
		&"night":
			_night = true
		&"day":
			_night = false
		&"user_idle":
			_user_idle = true
		&"user_active":
			_user_idle = false
		&"session_closed":
			if pet in _tower:
				_fell_tower()
			_small.drop(data.session)
			pets.remove(BOSS_KEY % data.session)
			pets.remove(data.session)
			_sessions.erase(data.session)
			if pets.keys().is_empty():
				pets.add(NO_SESSION)
		&"session_phase":
			pet.urgent = false
		&"session_advisor":
			if data.asking:
				_call_boss(data.session)
			else:
				_boss_answers(data.session)
		&"session_finished":
			var session: Dictionary = _sessions[data.session]
			# The turn is over: so is the question to the advisor.
			_boss_answers(data.session)
			# A turn started by another session is not something the user asked.
			var for_user: bool = session.get("origin", &"human") != &"peer" or session.get("owed", false)
			if _awaits(session):
				# A turn that leaves a task running, or a question to another
				# session, is a pause, not the end. The cheer comes later.
				session.owed = for_user
			elif for_user:
				session.owed = false
				pet.cheer()
				pet.say(tr("Task done!"))
				pets.celebrate(pet)
				Sound.play(&"success")
			else:
				# An answer to another session: nothing the user waits for.
				pet.nod()
		&"session_collision":
			var other := pets.find(data.other)
			var side := 1.0 if other.feet().x >= pet.feet().x else -1.0
			pet.glare(side)
			other.glare(-side)
			pet.say(tr("%s: also changed by %s") % [data.file, _sessions[data.other].name])
			Sound.play(&"failure")
			for key: String in [data.session, data.other]:
				_sessions[key].dispute = data.path
				_sessions[key].dispute_until = _now() + RIVAL_SECONDS
		&"session_turn":
			# A new turn: what the last one asked is answered, or dropped.
			_sessions[data.session].erase("asked")
		&"session_message_sent":
			var recipient := _session_named(data.to, data.session)
			if not recipient.is_empty():
				_sessions[data.session].asked = recipient
				_sessions[recipient].inbound = _sessions[recipient].get("inbound", 0) + 1
				pets.send_letter(pet, pets.find(recipient))
		&"session_mail":
			# A letter left the mailbox: the session reads it. One that still
			# flies is read when it lands.
			if data.mail < mail_before and _sessions[data.session].get("inbound", 0) == 0:
				pet.read_letter()
		&"letter_landed":
			# No letter waits: the session took it already.
			var reader: Dictionary = _sessions.get(pet.key, {})
			reader.inbound = maxi(reader.get("inbound", 0) - 1, 0)
			if reader.get("mail", 0) == 0:
				pet.read_letter()
			if _sessions.get(pet.key.trim_suffix(BOSS_KEY % ""), {}).get("boss") == &"asked" and pet.badge == BOSS_BADGE:
				# The boss reads on, until the advisor answers.
				pet.wish = Pet.Wish.READ
		&"session_needs_you":
			pet.say(data.detail if not data.detail.is_empty() else tr("Claude is waiting for you"))
		&"session_tests_passed":
			pet.cheer()
			pet.say(tr("Green tests!"))
			pets.celebrate(pet)
			Sound.play(&"success")
		&"session_tool_failed":
			var agent: String = data.get("agent", "")
			var small := _small.find(data.session, agent)
			if small:
				# The failure of a subagent: its own small pet worries, without a sound.
				small.worry()
			elif agent.is_empty():
				pet.worry()
				Sound.play(&"failure")
				if data.kind == "test":
					pet.say(tr("Red tests"))
		&"focus_started":
			_tell_all(tr("Focus: %d min") % Settings.value("focus", "minutes"))
		&"focus_finished":
			_tell_all(tr("Break! %d min") % Settings.value("focus", "break_minutes"), true)
		&"break_finished":
			_tell_all(tr("Break is over. Back to it?"))
		&"cpu_hot":
			if Settings.value("system", "alerts"):
				for key: String in pets.keys():
					pets.find(key).roast()
		&"battery_low":
			if Settings.value("system", "alerts"):
				_tell_all(tr("Low battery: %d %%") % data.percent)
		&"desktop_state":
			# A full screen window has no top edge to stand on.
			_active_window = Rect2() if data.fullscreen else data.active
			_active_pid = data.pid
			_covered = data.covered
		&"pointer_idle":
			_send_cuddler(data.position)
		&"pointer_moved":
			_cuddler = null
	_refresh()


## Every second: cards show durations, a long wait gets a reminder and a
## knock, the tower grows.
func _tick() -> void:
	var nag_after: float = Settings.value("claude", "nag_minutes") * 60.0
	for key: String in _sessions:
		var session: Dictionary = _sessions[key]
		var waited: float = _now() - session.since
		# Windows: the process list may not have been there when the session opened.
		if session.get("lineage_pending", false):
			var lineage := Desktop.lineage(session.pid)
			if lineage.size() > 1:
				session.lineage = lineage
				session.lineage_pending = false
		if session.phase != &"waiting" or _active_pid in session.lineage:
			session.unfocused_since = _now()
			continue
		if waited >= nag_after and _now() - session.nagged >= NAG_REPEAT_SECONDS:
			session.nagged = _now()
			pets.find(key).urgent = true
			pets.find(key).say(tr("Claude has been waiting for %s") % _duration(waited))
		if (
			Settings.value("claude", "knock")
			and _now() - session.unfocused_since >= KNOCK_AFTER_SECONDS
			and _now() - session.knocked >= KNOCK_REPEAT_SECONDS
		):
			session.knocked = _now()
			_send_to_knock(pets.find(key))
	_hold_screen()
	_grow_tower()
	_refresh()


## Sets what follows from the whole state: look, wish, caption and card of
## each pet.
func _refresh() -> void:
	_run_bosses()
	for key: String in pets.keys():
		var pet := pets.find(key)
		var session: Dictionary = _sessions.get(key, {})
		var phase: StringName = session.get("phase", &"idle")
		if not session.is_empty():
			_dress(pet, session)
		var level := _tower.find(pet)
		pet.perch = _tower_edge(level) if level > 0 else _active_window
		pet.wish = Pet.Wish.SLEEP if pet == _cuddler else _wish(session)
		pet.tapping = session.get("level", 0) == 1
		pet.meditating = session.get("level", 0) == 2
		pet.pace = lerpf(PACE_RANGE.x, PACE_RANGE.y, clampf(_load, 0.0, 1.0))
		pet.headlamp = _night and Settings.value("pet", "headlamp")
		pet.cool = _now() < session.get("cool_until", 0.0)
		pet.grooving = _music and Settings.value("pet", "groove")
		if _awaits_peer(session):
			pet.look_toward(pets.find(session.asked).feet().x)
		pet.serving = session.get("servers", 0) > 0
		# A letter that still flies is not in the mailbox yet.
		pet.mail = maxi(session.get("mail", 0) - session.get("inbound", 0), 0)
		pet.discreet = _locked
		var no_screen: Array[Rect2] = []
		pet.avoid = _covered if Settings.value("desktop", "leave_fullscreen") else no_screen
		var shown: bool = Settings.value("claude", "show_activity")
		pet.caption = _activity(session) if phase == &"working" and shown else ""
		var boss := pets.find(BOSS_KEY % key)
		if boss:
			boss.discreet = pet.discreet
			boss.avoid = pet.avoid
			boss.headlamp = pet.headlamp
			if session.get("boss") == &"asked":
				pet.look_toward(boss.feet().x)
				if not pet.caption.is_empty():
					pet.caption = tr("Asks the boss")
		pet.show_card(_card(session) if pet.hovered else "")
		var agents: Array = session.get("agents", [])
		var texts := {}
		for agent: Dictionary in agents:
			texts[agent.id] = [_activity(agent) if Settings.value("subagents", "show_activity") else "", _agent_line(agent)]
		_small.sync(key, agents)
		_small.dress(key, texts)


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
	pet.dispute = session.get("dispute", "") if _now() < session.get("dispute_until", 0.0) else ""


## Highest priority first.
func _wish(session: Dictionary) -> Pet.Wish:
	var phase: StringName = session.get("phase", &"idle")
	if phase == &"waiting":
		return Pet.Wish.ALERT
	if phase == &"working":
		return Pet.Wish.THINK
	if _awaits(session):
		return Pet.Wish.WAIT
	# Locked, the user is idle by definition: the pets stay up to be seen.
	if _night or (_user_idle and not _locked):
		return Pet.Wish.SLEEP
	return Pet.Wish.ROAM


## True when the turn is over and the session waits, but not for the user: for
## a task it started and that still runs, or for another session.
func _awaits(session: Dictionary) -> bool:
	return session.get("phase") == &"idle" and (session.get("background", 0) > 0 or _awaits_peer(session))


## True when the turn is over and the session it wrote to still works: the
## answer is to come.
func _awaits_peer(session: Dictionary) -> bool:
	var asked: Dictionary = _sessions.get(session.get("asked", ""), {})
	return session.get("phase") == &"idle" and asked.get("phase") == &"working"


## Id of the session with the given name, other than the given one. Empty: none.
## The name may end with a reference in brackets, as in "Alpha [1a2b3c]".
func _session_named(name: String, but: String) -> String:
	var wanted := name.get_slice(" [", 0)
	for key: String in _sessions:
		if key != but and _sessions[key].get("name", "") == wanted:
			return key
	return ""


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


## The session asks the advisor: the boss walks in beside its pet, which
## throws it a letter. The boss reads it until the answer comes.
func _call_boss(key: String) -> void:
	var session: Dictionary = _sessions[key]
	if not Settings.value("claude", "boss") or session.get("boss") == &"asked":
		return
	var pet := pets.find(key)
	var boss := pets.find(BOSS_KEY % key)
	if boss:
		# Asked again on its way out: it comes back.
		boss.exit_side = 0.0
		boss.walk_to(pet.feet().x + signf(boss.feet().x - pet.feet().x) * BOSS_GAP * pet.scale_factor(), Pet.State.IDLE, BOSS_HURRY)
	else:
		var size := pet.scale_factor()
		# On the side of the pet where the screen has more room.
		var screen := Desktop.screen_at(pet.feet())
		var side := -1.0 if screen.has_area() and pet.feet().x > screen.get_center().x else 1.0
		boss = pets.add_guest(BOSS_KEY % key, BOSS_STATURE)
		boss.badge = BOSS_BADGE
		boss.accessory = BOSS_HAT
		boss.place_at(pet.feet() + Vector2(side * BOSS_ENTRY * size, 0))
		boss.walk_to(pet.feet().x + side * BOSS_GAP * size, Pet.State.IDLE, BOSS_HURRY)
	session.boss = &"asked"
	session.boss_since = _now()
	session.boss_done = INF
	pets.send_letter(pet, boss)


## The advisor answered, or the turn ended: the boss answers too, but not
## before it was seen.
func _boss_answers(key: String) -> void:
	var session: Dictionary = _sessions[key]
	if session.get("boss") == &"asked":
		session.boss_done = minf(session.boss_done, maxf(_now(), session.boss_since + BOSS_MIN_SECONDS))


## The boss throws its answer back when it is time, then walks off the screen.
func _run_bosses() -> void:
	for key: String in _sessions:
		var session: Dictionary = _sessions[key]
		var boss := pets.find(BOSS_KEY % key)
		if boss == null:
			session.boss = &""
			continue
		match session.get("boss", &""):
			&"asked":
				if _now() >= minf(session.boss_done, session.boss_since + BOSS_MAX_SECONDS):
					session.boss = &"leaving"
					session.boss_gone = _now() + BOSS_LEAVE_SECONDS
					boss.wish = Pet.Wish.ROAM
					pets.send_letter(boss, pets.find(key))
			&"leaving":
				if boss.is_off() or _now() >= session.boss_gone:
					pets.remove(BOSS_KEY % key)
					session.boss = &""
				elif boss.is_free():
					boss.walk_off(BOSS_HURRY)


## GNOME turns the monitors off as soon as the screen is locked, and again
## each time the user stops moving the mouse there. For a while after locking,
## turn them back on every second, so that the pets are seen. Then let go.
func _hold_screen() -> void:
	var hold := _locked and _now() < _screen_held_until
	if hold:
		Desktop.set_screen_power(true)
	elif _screen_held and _locked:
		# GNOME thinks the monitors are off already: it will not do it again.
		Desktop.set_screen_power(false)
	_screen_held = hold
	# Also keeps the session from going to sleep meanwhile.
	DisplayServer.screen_set_keep_on(hold)
	pets.unseen = _locked and not hold


## Sends the pet to knock on the screen edge nearest to the pointer. Without
## the pointer: nearest to the pet.
func _send_to_knock(pet: Pet) -> void:
	var near := _pointer if _pointer_known else pet.feet()
	var screen := Desktop.screen_at(near)
	if not screen.has_area():
		pet.knock_at(pet.feet().x, pet.facing)
		return
	var side := -1.0 if near.x - screen.position.x < screen.end.x - near.x else 1.0
	var edge := screen.position.x if side < 0.0 else screen.end.x
	pet.knock_at(edge - side * KNOCK_REACH * pet.scale_factor(), side)


## Builds the tower of the sessions at rest, one pet per second, and brings
## it down when one of them is no longer at rest.
func _grow_tower() -> void:
	var standing: bool = not (_night or _user_idle) and Settings.value("pet", "tower")
	for pet in _tower:
		standing = standing and _rests(pet) and not pet.is_airborne()
	if not standing:
		_fell_tower()
		return

	if _tower.is_empty():
		for key: String in _sessions:
			var pet := pets.find(key)
			if _rests(pet) and pet.is_free() and not pet.is_perched():
				_tower.append(pet)
		if _tower.size() < 2:
			_tower.clear()
			return
		_tower[0].rooted = true
	for level in range(1, _tower.size()):
		var pet := _tower[level]
		if pet.is_perched():
			pet.rooted = true
		if pet.rooted:
			continue
		# One at a time: the pet below must be in place.
		if level > 1 and not _tower[level - 1].is_perched():
			return
		var base_x := _tower[0].feet().x
		if absf(pet.feet().x - base_x) > 12.0 * pet.scale_factor():
			if pet.is_free():
				pet.walk_to(base_x)
		elif pet.is_free():
			pet.rooted = true
			pet.climb_onto(_tower_edge(level))
		return


## Frees the pets of the tower: those above the ground fall.
func _fell_tower() -> void:
	for pet in _tower:
		pet.rooted = false
	_tower.clear()


## True when the session of the pet has been at rest long enough for the tower.
func _rests(pet: Pet) -> bool:
	var session: Dictionary = _sessions.get(pet.key, {})
	return session.get("phase") == &"idle" and not _awaits(session) and _now() - session.since >= TOWER_AFTER_SECONDS


## Head of the pet below, for the pet at the given level of the tower.
func _tower_edge(level: int) -> Rect2:
	var base := _tower[0]
	var size := base.scale_factor()
	var feet := base.feet().round()
	return Rect2(feet.x - TOWER_WIDTH * size / 2.0, feet.y - level * TOWER_LEVEL * size, TOWER_WIDTH * size, 0)


## Tool in use, such as "Edit · pet.gd".
func _activity(session: Dictionary) -> String:
	var tool: String = session.get("tool", "")
	var detail: String = session.get("detail", "")
	return tool if detail.is_empty() else "%s · %s" % [tool, detail]


## A subagent on one line: its name, then the tool it uses.
func _agent_line(agent: Dictionary) -> String:
	var parts := [agent.get("name", ""), _activity(agent)].filter(func(part: String) -> bool: return not part.is_empty())
	return ": ".join(parts)


## Text of the card shown while the mouse is over the pet.
func _card(session: Dictionary) -> String:
	var lines: PackedStringArray = []
	if not session.is_empty():
		var folder: String = session.cwd.replace(Desktop.home(), "~")
		if folder.length() > PATH_MAX_LENGTH:
			folder = "…" + folder.right(PATH_MAX_LENGTH - 1)
		lines.append(folder)
		var lasted := _duration(_now() - session.since)
		match session.phase:
			&"working":
				lines.append(tr("Working for %s") % lasted)
				if session.get("boss") == &"asked":
					lines.append(tr("Asks the boss for %s") % _duration(_now() - session.boss_since))
				elif not _activity(session).is_empty():
					lines.append(_activity(session))
			&"waiting":
				lines.append(tr("Waiting for you for %s") % lasted)
			_ when _awaits_peer(session):
				lines.append(tr("Waiting for the answer of %s for %s") % [_sessions[session.asked].name, lasted])
			_:
				lines.append(tr("Waiting for a background task for %s" if _awaits(session) else "At rest for %s") % lasted)
		if session.get("count", 0) > 0:
			lines.append(tr("Subagents running: %d") % session.count)
			for agent: Dictionary in session.get("agents", []):
				if not _agent_line(agent).is_empty():
					lines.append("  " + _agent_line(agent))
		if session.get("servers", 0) > 0:
			lines.append(tr("Servers running: %d") % session.servers)
		if session.get("mail", 0) > 0:
			lines.append(tr("Letters to read: %d") % session.mail)
		if session.context > 0:
			lines.append(tr("Context: %d k tokens (%d %%)") % [session.context / 1000, pets.find(session.session).fullness * 100.0])
		lines.append_array(_repo_lines(session))
		var summary: String = session.get("summary", "")
		if not summary.is_empty():
			# Tells more than the start of the prompt.
			lines.append(summary if summary.length() <= SUMMARY_MAX_LENGTH else summary.left(SUMMARY_MAX_LENGTH - 1) + "…")
		elif not session.last_prompt.is_empty():
			lines.append(tr("“%s”") % session.last_prompt.left(PROMPT_MAX_LENGTH).replace("\n", " "))
	match Focus.phase:
		Focus.Phase.FOCUS:
			lines.append(tr("Focus: %d min left") % Focus.minutes_left())
		Focus.Phase.BREAK:
			lines.append(tr("Break: %d min left") % Focus.minutes_left())
	return "\n".join(lines)


func _repo_lines(session: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	if session.get("conflict", false):
		lines.append(tr("Merge or rebase to finish"))
	if session.get("dirty", 0) > 0:
		lines.append(tr("Uncommitted: %d lines") % session.dirty)
	if session.get("behind", 0) > 0:
		lines.append(tr("%d commits behind origin") % session.behind)
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
