class_name Pets
extends Node
## The pets on the desktop, one window each, found by key.

const PET_WINDOW := preload("res://src/pet/pet_window.tscn")

## Key -> Pet.
var _pets := {}


# Godot cannot hide its main window. It stays empty: park it off screen, and let
# clicks through in case the window manager brings it back.
func _ready() -> void:
	var main := get_window()
	main.position = -main.size * 4
	main.mouse_passthrough_polygon = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])


func add(key: String) -> Pet:
	var window := PET_WINDOW.instantiate()
	add_child(window)
	var pet: Pet = window.get_node("Pet")
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
