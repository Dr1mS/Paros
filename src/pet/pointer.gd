extends Node
## Mouse input of one pet window.
## Posts: pointer_tap, pointer_grab, pointer_drop, pointer_menu, each with {pet}.

@export var pet: Pet

const DRAG_THRESHOLD := 6.0

var _pressed := false
var _dragging := false
var _pressed_at := Vector2i.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			Events.post(&"pointer_menu", {"pet": pet})
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragging = false
				_pressed_at = DisplayServer.mouse_get_position()
			elif _pressed:
				_pressed = false
				Events.post(&"pointer_drop" if _dragging else &"pointer_tap", {"pet": pet})
	elif event is InputEventMouseMotion and _pressed and not _dragging:
		# Screen coordinates: the window itself moves during a drag.
		if (DisplayServer.mouse_get_position() - _pressed_at).length() > DRAG_THRESHOLD:
			_dragging = true
			Events.post(&"pointer_grab", {"pet": pet})
