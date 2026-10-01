class_name Pets
extends Node
## The pets on the desktop, one window each, found by key.
## Also makes two pets greet when they meet.

const PET_WINDOW := preload("res://src/pet/pet_window.tscn")
## Feet distance under which two pets meet, at size 1.
const MEET_DISTANCE := 150.0
## Seconds before the same two pets greet again.
const GREET_COOLDOWN := 45.0

## Key -> Pet.
var _pets := {}
## Pair of pets -> time of their last greeting, in seconds.
var _greeted := {}


# Godot cannot hide its main window. It stays empty: park it off screen, and let
# clicks through in case the window manager brings it back.
func _ready() -> void:
	var main := get_window()
	main.position = -main.size * 4
	main.mouse_passthrough_polygon = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])


func _process(_delta: float) -> void:
	if not Settings.value("pet", "greetings"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var all: Array = _pets.values()
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
