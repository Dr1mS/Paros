class_name Pets
extends Node
## The pets on the desktop, one window each, found by key.
## Also makes two pets greet when they meet, and sets the frame rate.

const PET_WINDOW := preload("res://src/pet/pet_window.tscn")
## Feet distance under which two pets meet, at size 1.
const MEET_DISTANCE := 150.0
## Seconds before the same two pets greet again.
const GREET_COOLDOWN := 45.0
## Frames per second. Rendering is the main CPU cost: slow down while every pet
## is calm (still, asleep or thinking).
const LIVELY_FPS := 30
const CALM_FPS := 12
## Nodes of this group ask for smooth frames while they are visible.
const SMOOTH_GROUP := &"smooth_frames"

## Key -> Pet.
var _pets := {}
## Pair of pets -> time of their last greeting, in seconds.
var _greeted := {}


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
	var now := Time.get_ticks_msec() / 1000.0
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Pet = all[i]
			var b: Pet = all[j]
			var gap := b.feet() - a.feet()
			if gap.length() > MEET_DISTANCE * a.scale_factor() or not (a.is_free() and b.is_free()):
				continue
			var pair := [a.get_instance_id(), b.get_instance_id()]
			if now - _greeted.get(pair, -GREET_COOLDOWN) < GREET_COOLDOWN:
				continue
			_greeted[pair] = now
			var side := 1.0 if gap.x >= 0.0 else -1.0
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
		_pets[key].get_window().queue_free()
		_pets.erase(key)


func find(key: String) -> Pet:
	return _pets.get(key)


func keys() -> Array:
	return _pets.keys()
