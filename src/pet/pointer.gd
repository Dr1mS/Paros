extends Node
## Mouse input of one pet window.
## Posts, each with {pet}: pointer_tap, pointer_grab, pointer_drop, pointer_menu,
## pointer_double, pointer_enter, pointer_leave, files_dropped {files}.

const DRAG_THRESHOLD := 6.0

@export var pet: Pet

var _pressed := false
var _dragging := false
var _pressed_at := Vector2i.ZERO


func _ready() -> void:
	# Windows: the click shape is made by hand, see _process.
	if OS.get_name() == "Windows":
		return
	get_window().mouse_entered.connect(_on_hover.bind(true))
	get_window().mouse_exited.connect(_on_hover.bind(false))
	get_window().files_dropped.connect(func(files: PackedStringArray) -> void:
		Events.post(&"files_dropped", {"pet": pet, "files": files}))


## Windows only. A window region would cut the drawing, so the window takes
## every click and lets them through itself, except over the body (or while a
## button is held: the drag must not lose the window).
func _process(_delta: float) -> void:
	if OS.get_name() != "Windows" or pet == null:
		return
	var inside := pet.hit_test(Vector2(DisplayServer.mouse_get_position()))
	get_window().mouse_passthrough = not inside and not _pressed
	if inside != pet.hovered and not _pressed:
		_on_hover(inside)


func _on_hover(inside: bool) -> void:
	pet.hovered = inside
	Events.post(&"pointer_enter" if inside else &"pointer_leave", {"pet": pet})


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			Events.post(&"pointer_menu", {"pet": pet})
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and event.double_click:
				Events.post(&"pointer_double", {"pet": pet})
			elif event.pressed:
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
