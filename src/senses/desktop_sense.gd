extends Node
## Posts: desktop_state {active: Rect2, fullscreen: bool}, pointer_idle
## {position: Vector2}, pointer_moved.
## active: frame of the focused window, in screen coordinates. Empty: none.
## Reads the file written by the Paros GNOME Shell extension (gnome-extension/).
## Without the extension the file does not exist and this sense stays silent.

const POLL_SECONDS := 0.5
## The extension rewrites the file every 10 s at least. Older: it is gone.
const STALE_SECONDS := 30.0
## Seconds without pointer motion before pointer_idle.
const IDLE_AFTER_SECONDS := 60.0

var _path := OS.get_environment("XDG_RUNTIME_DIR").path_join("paros/desktop.json")
var _active := Rect2()
var _fullscreen := false
var _pointer := Vector2.ZERO
var _still_for := 0.0
var _idle := false


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = POLL_SECONDS
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)


func _poll() -> void:
	var state: Variant = null
	if Time.get_unix_time_from_system() - FileAccess.get_modified_time(_path) < STALE_SECONDS:
		state = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if not state is Dictionary:
		_set_active(Rect2(), false)
		return

	var window: Variant = state.get("active")
	if window is Dictionary:
		_set_active(Rect2(window.x, window.y, window.width, window.height), window.fullscreen)
	else:
		_set_active(Rect2(), false)

	var pointer := Vector2(state.pointer[0], state.pointer[1])
	if pointer != _pointer:
		_pointer = pointer
		_still_for = 0.0
		if _idle:
			_idle = false
			Events.post(&"pointer_moved")
		return
	_still_for += POLL_SECONDS
	if not _idle and _still_for >= IDLE_AFTER_SECONDS:
		_idle = true
		Events.post(&"pointer_idle", {"position": _pointer})


func _set_active(active: Rect2, fullscreen: bool) -> void:
	if active != _active or fullscreen != _fullscreen:
		_active = active
		_fullscreen = fullscreen
		Events.post(&"desktop_state", {"active": active, "fullscreen": fullscreen})
