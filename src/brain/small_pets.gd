extends Node
## The small pets of the subagents: one per running subagent, in a zone around
## the pet of the session. A subagent tells little of its work, so its pet
## plays like a child: it jumps, runs to another one, and they build pyramids.
## The brain tells which subagents run, and what each pet shows.

const TICK_SECONDS := 0.25
## How far a small pet goes from the pet of the session, at size 1: with one
## small pet, then more for each other one.
const REACH := 140.0
const REACH_PER_PET := 30.0
## A newborn runs this far from the pet of the session, at size 1.
const BIRTH_RUN := Vector2(60.0, 130.0)
const HURRY := 2.2
## Chances, at each tick: of a jump and of a run to another one, for a free
## small pet. Of a pyramid, for a session with enough free small pets.
const JUMP_CHANCE := 0.04
const VISIT_CHANCE := 0.015
const PYRAMID_CHANCE := 0.006
## Distance kept from the small pet it runs to, against a normal pet at size 1.
const VISIT_GAP := 200.0
## Distance between two neighbors of a pyramid row, and height of a row,
## against a normal pet at size 1. The row above stands on the heads.
const PYRAMID_STEP := 160.0
const PYRAMID_LEVEL := 72.0
const PYRAMID_HEAD := 200.0
## Seconds a finished pyramid stands, and seconds to build it before giving up.
const PYRAMID_HOLD_SECONDS := 8.0
const PYRAMID_BUILD_SECONDS := 25.0
## A small pet stands this near its spot, at size 1, before it sits or climbs.
const SPOT_MARGIN := 3.0
## Seconds a small pet has to run back once its subagent stopped.
const LEAVE_SECONDS := 6.0

var pets: Pets

## Session id -> its small pets, oldest first: {id: subagent id, key: key of
## the pet in Pets, pet}.
var _groups := {}
## Session id -> its pyramid: {members: pets from the bottom row up, spots:
## for each one, x from the middle of the pyramid then row, middle: screen x,
## floor: screen y, deadline, until (NAN while it is built)}.
var _pyramids := {}
## Small pets whose subagent stopped: {key, pet, session, until, going}.
var _leaving: Array[Dictionary] = []
var _tick_in := 0.0


func _process(delta: float) -> void:
	_tick_in -= delta
	if _tick_in <= 0.0:
		_tick_in = TICK_SECONDS
		_tick()


## Tells the subagents that run in the session: [{id}], oldest first. New
## ones get a small pet, which leaves the pet of the session with its sheet
## of paper. The small pet of a stopped one cheers and runs back. The
## settings tell how many small pets a session may have: the subagents
## beyond get none.
func sync(session: String, agents: Array) -> void:
	var parent := pets.find(session)
	if parent == null:
		return
	var group: Array = _groups.get(session, [])
	var most: int = Settings.value("subagents", "max") if Settings.value("subagents", "show") else 0
	var ids := agents.map(func(agent: Dictionary) -> String: return agent.id)
	var newest_first := group.duplicate()
	newest_first.reverse()
	for small: Dictionary in newest_first:
		if small.id not in ids or group.size() > most:
			group.erase(small)
			_dismiss(session, small)
	for id: String in ids:
		if group.size() >= most:
			break
		if group.any(func(small: Dictionary) -> bool: return small.id == id):
			continue
		var key := "%s/%s" % [session, id]
		# Its former small pet may still be on its way out.
		for leaver in _leaving.duplicate():
			if leaver.key == key:
				pets.remove(key)
				_leaving.erase(leaver)
		var pet := pets.add(key, true)
		pet.place_at(parent.feet())
		pet.sheet = true
		var side := 1.0 if randf() < 0.5 else -1.0
		pet.walk_to(parent.feet().x + side * randf_range(BIRTH_RUN.x, BIRTH_RUN.y) * parent.scale_factor(), Pet.State.IDLE, HURRY)
		group.append({"id": id, "key": key, "pet": pet})
	if group.is_empty():
		_groups.erase(session)
	else:
		_groups[session] = group
	_follow(session)


## Removes at once the small pets of a session that closed.
func drop(session: String) -> void:
	_collapse(session)
	for small: Dictionary in _groups.get(session, []):
		pets.remove(small.key)
	_groups.erase(session)
	for leaver in _leaving.duplicate():
		if leaver.session == session:
			pets.remove(leaver.key)
			_leaving.erase(leaver)


## Gives the small pets of the session the look of its pet, and their texts:
## subagent id -> [caption, card].
func dress(session: String, texts: Dictionary) -> void:
	var parent := pets.find(session)
	for small: Dictionary in _groups.get(session, []):
		var pet: Pet = small.pet
		var text: Array = texts.get(small.id, ["", ""])
		pet.color = parent.color.lightened(0.15)
		pet.caption = text[0]
		pet.show_card(text[1] if pet.hovered else "")
		pet.discreet = parent.discreet
		pet.avoid = parent.avoid
		pet.pace = parent.pace
		pet.headlamp = parent.headlamp
		pet.grooving = parent.grooving


## The small pets of the session, oldest first.
func pets_of(session: String) -> Array:
	return _groups.get(session, []).map(func(small: Dictionary) -> Pet: return small.pet)


## The small pet of the subagent. Null: none.
func find(session: String, id: String) -> Pet:
	for small: Dictionary in _groups.get(session, []):
		if small.id == id:
			return small.pet
	return null


## Session of the pet: its own for a normal pet, the one it belongs to for a
## small one.
func session_of(pet: Pet) -> String:
	for session: String in _groups:
		if pet in pets_of(session):
			return session
	return pet.key


func _tick() -> void:
	for session: String in _groups.keys():
		if pets.find(session) == null:
			drop(session)
			continue
		_follow(session)
		if _pyramids.has(session) and not Settings.value("subagents", "pyramid"):
			_collapse(session)
		if _pyramids.has(session):
			_build(session)
		else:
			_play(session)
	_see_off()


## Keeps the zone of the small pets around the pet of the session.
func _follow(session: String) -> void:
	var parent := pets.find(session)
	var group: Array = _groups.get(session, [])
	for small: Dictionary in group:
		var pet: Pet = small.pet
		pet.home_x = parent.feet().x
		pet.home_reach = (REACH + REACH_PER_PET * group.size()) * parent.scale_factor()
		# The sheet is put away once the first run is over.
		pet.sheet = pet.sheet and not pet.is_free()


func _play(session: String) -> void:
	var free: Array = pets_of(session).filter(func(pet: Pet) -> bool: return pet.is_free() and not pet.is_perched())
	if free.size() >= 2 and Settings.value("subagents", "pyramid") and randf() < PYRAMID_CHANCE:
		_start_pyramid(session)
		return
	if not Settings.value("subagents", "games"):
		return
	for pet: Pet in free:
		var luck := randf()
		if luck < JUMP_CHANCE:
			pet.jump()
		elif luck < JUMP_CHANCE + VISIT_CHANCE and free.size() >= 2:
			# Runs up to another one, and waves.
			var other: Pet = free[randi() % free.size()]
			if other != pet:
				var side := signf(other.feet().x - pet.feet().x)
				pet.walk_to(other.feet().x - side * VISIT_GAP * pet.scale_factor(), Pet.State.GREET, HURRY)


## Rows of the widest pyramid the free small pets can build: 1 on 2, on 3,
## on 4. Two of them: one on the other.
func _start_pyramid(session: String) -> void:
	var free: Array = pets_of(session).filter(func(pet: Pet) -> bool: return pet.is_free() and not pet.is_perched())
	if free.size() < 2:
		return
	var rows := 1
	while (rows + 1) * (rows + 2) / 2 <= free.size():
		rows += 1
	var spots: Array[Vector2] = []
	for row in rows:
		for i in rows - row:
			spots.append(Vector2(i - (rows - row - 1) / 2.0, row))
	if rows == 1:
		spots.append(Vector2(0, 1))
	var members := free.slice(0, spots.size())
	# The bottom row from left to right: nobody crosses.
	var bottom := members.slice(0, rows)
	bottom.sort_custom(func(a: Pet, b: Pet) -> bool: return a.feet().x < b.feet().x)
	for i in rows:
		members[i] = bottom[i]
	var first: Pet = members[0]
	var half := (rows - 1) / 2.0 * PYRAMID_STEP * first.scale_factor()
	var reach := maxf(first.home_reach - half, 0.0)
	_pyramids[session] = {
		"members": members, "spots": spots,
		"middle": clampf(bottom[rows / 2].feet().x, first.home_x - reach, first.home_x + reach),
		"floor": roundf(first.feet().y), "deadline": _now() + PYRAMID_BUILD_SECONDS, "until": NAN,
	}


## One step of the pyramid: the bottom row walks to its spots and sits, then
## each of the others climbs in turn. Once built it stands a moment, then falls.
func _build(session: String) -> void:
	var pyramid: Dictionary = _pyramids[session]
	var members: Array = pyramid.members
	var over: float = pyramid.deadline if is_nan(pyramid.until) else pyramid.until
	if _now() >= over or members.any(func(pet: Pet) -> bool: return pet not in pets_of(session) or _fell(pet)):
		_collapse(session)
		return
	var settled := true
	for i in members.size():
		var pet: Pet = members[i]
		var spot: Vector2 = pyramid.spots[i]
		var size := pet.scale_factor()
		if spot.y > 0.0 and not settled:
			# The rows below must be in place first. Then one at a time.
			return
		if pet.rooted:
			settled = settled and (spot.y == 0.0 or pet.is_perched())
			continue
		settled = false
		var x: float = pyramid.middle + spot.x * PYRAMID_STEP * size
		if absf(pet.feet().x - x) > SPOT_MARGIN * size:
			if pet.is_free():
				pet.walk_to(x, Pet.State.IDLE, HURRY)
		elif pet.is_free():
			pet.rooted = true
			if spot.y > 0.0:
				pet.climb_onto(Rect2(x - PYRAMID_HEAD * size / 2.0, pyramid.floor - spot.y * PYRAMID_LEVEL * size, PYRAMID_HEAD * size, 0))
	if settled and is_nan(pyramid.until):
		pyramid.until = _now() + PYRAMID_HOLD_SECONDS
		# The one at the top shows off.
		members[-1].cheer()


## True when a member of a pyramid was taken off it: carried, or thrown.
func _fell(pet: Pet) -> bool:
	return pet.rooted and pet.is_airborne()


## Frees the members of the pyramid: those above the ground fall.
func _collapse(session: String) -> void:
	if not _pyramids.has(session):
		return
	for pet in _pyramids[session].members:
		if is_instance_valid(pet):
			pet.rooted = false
			pet.perch = Rect2()
	_pyramids.erase(session)


## The subagent stopped: its small pet cheers, then runs back to the pet of
## the session.
func _dismiss(session: String, small: Dictionary) -> void:
	if _pyramids.has(session) and small.pet in _pyramids[session].members:
		_collapse(session)
	var pet: Pet = small.pet
	pet.caption = ""
	pet.sheet = false
	pet.cheer()
	_leaving.append({"key": small.key, "pet": pet, "session": session, "until": _now() + LEAVE_SECONDS, "going": false})


func _see_off() -> void:
	for leaver in _leaving.duplicate():
		var pet: Pet = leaver.pet
		var parent := pets.find(leaver.session)
		if parent == null or _now() >= leaver.until or (leaver.going and pet.is_free()):
			pets.remove(leaver.key)
			_leaving.erase(leaver)
		elif not leaver.going and pet.is_free():
			pet.walk_to(parent.feet().x, Pet.State.IDLE, HURRY)
			leaver.going = pet.state == Pet.State.WALK


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
