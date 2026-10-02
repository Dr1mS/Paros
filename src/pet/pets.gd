class_name Pets
extends Node
## The pets on the desktop, one window each, found by key.
## Also handles what takes two pets: meetings, shared celebrations, letters,
## and room for each to be seen. And sets the frame rate.

const PET_WINDOW := preload("res://src/pet/pet_window.tscn")
const LETTER_WINDOW := preload("res://src/pet/letter_window.tscn")
## Feet distance under which two pets meet, at size 1.
const MEET_DISTANCE := 150.0
## Seconds before the same two pets meet again.
const MEET_COOLDOWN := 45.0
## Two pets that succeed this close in space and time clap hands.
const HIGH_FIVE_DISTANCE := 200.0
const HIGH_FIVE_SECONDS := 20.0
## Two pets that stay in place closer than this hide each other, at size 1.
const CROWD_DISTANCE := 120.0
## Seconds they may stay so, then one of them walks this far from the other.
const CROWD_SECONDS := 2.0
const CROWD_GAP := 170.0
## States of a pet that stays in place.
const SETTLED: Array[Pet.State] = [
	Pet.State.IDLE, Pet.State.SIT, Pet.State.SLEEP, Pet.State.THINK, Pet.State.ALERT, Pet.State.WAIT,
]
## The pet that moves is the one with the wish that comes first here: a
## sleeping pet stays asleep, and so on.
const CROWD_MOVERS: Array[Pet.Wish] = [Pet.Wish.ROAM, Pet.Wish.WAIT, Pet.Wish.THINK, Pet.Wish.ALERT, Pet.Wish.SLEEP]
## Frames per second. Rendering is the main CPU cost: slow down while every pet
## is calm (still, asleep or thinking).
const LIVELY_FPS := 30
const CALM_FPS := 12
## While nobody can see the pets: screen off behind the lock screen.
const UNSEEN_FPS := 2
## Nodes of this group ask for smooth frames while they are visible.
const SMOOTH_GROUP := &"smooth_frames"

## Key -> Pet.
var _pets := {}
## Pair of pets -> time of their last meeting, in seconds.
var _met := {}
## Pet -> time of its last success, in seconds.
var _succeeded := {}
## Pair of pets that hide each other -> time since when, in seconds.
var _crowded := {}
## Letters, in flight or at rest. One at rest serves again.
var _letters: Array[Letter] = []
## True while nobody can see the pets. They barely draw.
var unseen := false


# Godot cannot hide its main window. It stays empty: park it off screen, and let
# clicks through in case the window manager brings it back.
# Its vertical sync is off in the project settings: off screen, a synced frame
# waits a full second.
func _ready() -> void:
	var main := get_window()
	main.position = -main.size * 4
	main.mouse_passthrough_polygon = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])


func _process(_delta: float) -> void:
	var all: Array = _pets.values()
	var lively := all.any(func(pet: Pet) -> bool: return pet.is_lively())
	for node in get_tree().get_nodes_in_group(SMOOTH_GROUP):
		lively = lively or node.visible
	lively = lively or _letters.any(func(letter: Letter) -> bool: return letter.is_flying())
	Engine.max_fps = UNSEEN_FPS if unseen else (LIVELY_FPS if lively else CALM_FPS)

	_spread(all)
	if not Settings.value("pet", "greetings"):
		return
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Pet = all[i]
			var b: Pet = all[j]
			if not (a.is_free() and b.is_free()) or not _are_near(a, b, MEET_DISTANCE):
				continue
			var pair := [a.get_instance_id(), b.get_instance_id()]
			if _now() - _met.get(pair, -MEET_COOLDOWN) < MEET_COOLDOWN:
				continue
			_met[pair] = _now()
			var side := _side(a, b)
			# Two pets on the same work are rivals.
			if not a.repo.is_empty() and a.repo == b.repo:
				a.glare(side)
				b.glare(-side)
			else:
				a.greet(side)
				b.greet(-side)


## Two pets may cross, and stop on the same spot. But not for long: one of
## them then steps aside, so that none stays hidden behind another.
func _spread(all: Array) -> void:
	var crowded := {}
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Pet = all[i]
			var b: Pet = all[j]
			# Pets of a tower sit on each other on purpose.
			if a.rooted or b.rooted or a.state not in SETTLED or b.state not in SETTLED:
				continue
			var apart := (b.feet() - a.feet()).abs()
			var size := a.scale_factor()
			# On the same level: one on a perch does not hide one on the floor.
			if apart.x >= CROWD_DISTANCE * size or apart.y >= CROWD_DISTANCE * size / 2.0:
				continue
			var pair := [a.get_instance_id(), b.get_instance_id()]
			crowded[pair] = _crowded.get(pair, _now())
			if _now() - crowded[pair] < CROWD_SECONDS:
				continue
			if CROWD_MOVERS.find(b.wish) < CROWD_MOVERS.find(a.wish):
				b.step_aside(a.feet().x, CROWD_GAP * size)
			else:
				a.step_aside(b.feet().x, CROWD_GAP * size)
	_crowded = crowded


func add(key: String) -> Pet:
	var window := PET_WINDOW.instantiate()
	add_child(window)
	# No vertical sync: a synced frame waits for the screen, and a window that
	# is not shown gets about one frame per second. The lock screen shows
	# copies of the windows, not the windows. The frame rate is capped anyway.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, window.get_window_id())
	var pet: Pet = window.get_node("Pet")
	pet.key = key
	_pets[key] = pet
	return pet


## The first pet throws a letter, which flies to the second one. Its landing
## posts letter_landed {pet}, with the second pet.
func send_letter(from: Pet, to: Pet) -> void:
	from.throw_letter(_side(from, to))
	var letter: Letter = null
	for other in _letters:
		if not other.is_flying():
			letter = other
	if letter == null:
		var window := LETTER_WINDOW.instantiate()
		add_child(window)
		# No vertical sync, as for a pet window.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, window.get_window_id())
		letter = window.get_node("Letter")
		_letters.append(letter)
	letter.send(from, to)


func remove(key: String) -> void:
	if _pets.has(key):
		_succeeded.erase(_pets[key])
		for letter in _letters:
			if letter.recipient() == _pets[key]:
				letter.stop()
		_pets[key].get_window().queue_free()
		_pets.erase(key)


func find(key: String) -> Pet:
	return _pets.get(key)


func keys() -> Array:
	return _pets.keys()


## Notes a success of the pet. Claps hands with a near pet that also succeeded
## a moment ago.
func celebrate(pet: Pet) -> void:
	for other: Pet in _succeeded:
		if other != pet and _now() - _succeeded[other] <= HIGH_FIVE_SECONDS and _are_near(pet, other, HIGH_FIVE_DISTANCE):
			var side := _side(pet, other)
			pet.high_five(side)
			other.high_five(-side)
			_succeeded.erase(other)
			return
	_succeeded[pet] = _now()


func _are_near(a: Pet, b: Pet, distance: float) -> bool:
	return (b.feet() - a.feet()).length() <= distance * a.scale_factor()


## Side of b seen from a: -1 left, 1 right.
func _side(a: Pet, b: Pet) -> float:
	return 1.0 if b.feet().x >= a.feet().x else -1.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
