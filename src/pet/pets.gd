class_name Pets
extends Node
## The pets on the desktop, one window each, found by key.
## Also handles what takes two pets: meetings and shared celebrations. And sets
## the frame rate.

const PET_WINDOW := preload("res://src/pet/pet_window.tscn")
## Feet distance under which two pets meet, at size 1.
const MEET_DISTANCE := 150.0
## Seconds before the same two pets meet again.
const MEET_COOLDOWN := 45.0
## Two pets that succeed this close in space and time clap hands.
const HIGH_FIVE_DISTANCE := 200.0
const HIGH_FIVE_SECONDS := 20.0
## Frames per second. Rendering is the main CPU cost: slow down while every pet
## is calm (still, asleep or thinking).
const LIVELY_FPS := 30
const CALM_FPS := 12
## Nodes of this group ask for smooth frames while they are visible.
const SMOOTH_GROUP := &"smooth_frames"

## Key -> Pet.
var _pets := {}
## Pair of pets -> time of their last meeting, in seconds.
var _met := {}
## Pet -> time of its last success, in seconds.
var _succeeded := {}


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
	Engine.max_fps = LIVELY_FPS if lively else CALM_FPS

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


func add(key: String) -> Pet:
	var window := PET_WINDOW.instantiate()
	add_child(window)
	var pet: Pet = window.get_node("Pet")
	pet.key = key
	_pets[key] = pet
	return pet


func remove(key: String) -> void:
	if _pets.has(key):
		_succeeded.erase(_pets[key])
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
