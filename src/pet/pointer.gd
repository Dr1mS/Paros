extends Node
## Mouse input of one pet window.
## Posts, each with {pet}: pointer_tap, pointer_grab, pointer_drop, pointer_menu,
## pointer_enter, pointer_leave.

const DRAG_THRESHOLD := 6.0

@export var pet: Pet

var _pressed := false
var _dragging := false
var _pressed_at := Vector2i.ZERO


func _ready() -> void:
	get_window().mouse_entered.connect(_on_hover.bind(true))
	get_window().mouse_exited.connect(_on_hover.bind(false))


func _on_hover(inside: bool) -> void:
	pet.hovered = inside
	Events.post(&"pointer_enter" if inside else &"pointer_leave", {"pet": pet})


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
