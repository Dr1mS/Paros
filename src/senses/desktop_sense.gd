extends Node
## Posts: desktop_state {active: Rect2, fullscreen: bool, pid: int, covered:
## Array[Rect2]}, pointer_at
## {position: Vector2}, pointer_idle {position: Vector2}, pointer_moved,
## screen_locked {locked: bool}.
## active: frame of the focused window, in screen coordinates. Empty: none.
## pid: process that owns the focused window. -1: not known.
## covered: screens under a full screen window, such as a game or a video.
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
var _pid := -1
var _covered: Array[Rect2] = []
var _locked := false
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
	var locked: bool = state is Dictionary and state.get("locked", false)
	if locked != _locked:
		_locked = locked
		Events.post(&"screen_locked", {"locked": locked})
	if not state is Dictionary:
		_set_active(Rect2(), false, -1, [])
		return

	var window: Variant = state.get("active")
	var active := Rect2()
	var fullscreen := false
	if window is Dictionary:
		active = Rect2(window.x, window.y, window.width, window.height)
		fullscreen = window.fullscreen
	var covered: Array[Rect2] = []
	if state.has("covered"):
		for area: Array in state.covered:
			covered.append(Rect2(area[0], area[1], area[2], area[3]))
	elif fullscreen:
		# Older extension: only the focused window is known.
		covered.append(active)
	_set_active(active, fullscreen, int(window.get("pid", -1)) if window is Dictionary else 0, covered)

	var pointer := Vector2(state.pointer[0], state.pointer[1])
	if pointer != _pointer:
		_pointer = pointer
		_still_for = 0.0
		Events.post(&"pointer_at", {"position": pointer})
		if _idle:
			_idle = false
			Events.post(&"pointer_moved")
		return
	_still_for += POLL_SECONDS
	if not _idle and _still_for >= IDLE_AFTER_SECONDS:
		_idle = true
		Events.post(&"pointer_idle", {"position": _pointer})


func _set_active(active: Rect2, fullscreen: bool, pid: int, covered: Array[Rect2]) -> void:
	if active != _active or fullscreen != _fullscreen or pid != _pid or covered != _covered:
		_active = active
		_fullscreen = fullscreen
		_pid = pid
		_covered = covered
		Events.post(&"desktop_state", {"active": active, "fullscreen": fullscreen, "pid": pid, "covered": covered})
