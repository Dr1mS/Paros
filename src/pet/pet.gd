class_name Pet
extends Node2D
## State machine of the pet. The pet does not move inside the window:
## the whole OS window moves across the desktop. One window per pet.

enum State { IDLE, WALK, SLEEP, THINK, ALERT, CHEER, CARRIED, FALL }
## Standing order from the brain. The pet obeys as soon as it is idle.
enum Wish { ROAM, SLEEP, THINK, ALERT }

const WISH_STATE := {
	Wish.SLEEP: State.SLEEP,
	Wish.THINK: State.THINK,
	Wish.ALERT: State.ALERT,
}
const DEFAULT_COLOR := Color("#d97757")
const GRAVITY := 2600.0
const CHEER_SECONDS := 1.6
## Clickable region in window coordinates. Clicks outside reach the desktop.
const HIT_CENTER := Vector2(150, 192)
const HIT_RADIUS := Vector2(72, 70)
## Empty window width on each side of the mascot. The window may overflow the
## screen by this much, so the mascot itself reaches the screen edge.
const SIDE_MARGIN := 78.0

var state := State.IDLE
var facing := 1.0
var wish := Wish.ROAM
## Name shown under the pet. Empty: no name tag.
var label := ""
var color := DEFAULT_COLOR

var _window_pos := Vector2.ZERO
var _fall_speed := 0.0
var _timer := 0.0
var _grab_offset := Vector2i.ZERO
var _size := 1.0
var _walk_speed := 0.0

@onready var _window := get_window()
@onready var _bubble: Bubble = $"../Bubble"
## Window size at scale 1.
@onready var _base_size := _window.size


func _ready() -> void:
	_apply_settings()
	Settings.changed.connect(_apply_settings)
	var area := _walk_area()
	_window_pos = Vector2(randf_range(area.position.x, area.end.x), area.end.y)
	_window.position = Vector2i(_window_pos)
	_enter(State.IDLE)


func _process(delta: float) -> void:
	var area := _walk_area()
	match state:
		State.IDLE:
			_timer -= delta
			if wish != Wish.ROAM:
				_enter(WISH_STATE[wish])
			elif _timer <= 0.0:
				_enter(State.WALK)
		State.WALK:
			_window_pos.x += facing * _walk_speed * _size * delta
			if _window_pos.x <= area.position.x:
				facing = 1.0
			elif _window_pos.x >= area.end.x:
				facing = -1.0
			_timer -= delta
			if wish != Wish.ROAM or _timer <= 0.0:
				_enter(State.IDLE)
		State.SLEEP, State.THINK, State.ALERT:
			if WISH_STATE.get(wish) != state:
				_enter(State.IDLE)
		State.CHEER:
			_timer -= delta
			if _timer <= 0.0:
				_enter(State.IDLE)
		State.CARRIED:
			_window_pos = Vector2(DisplayServer.mouse_get_position() - _grab_offset)
		State.FALL:
			_fall_speed += GRAVITY * _size * delta
			_window_pos.y += _fall_speed * delta
			if _window_pos.y >= area.end.y:
				_enter(State.IDLE)

	if state != State.CARRIED:
		_window_pos.x = clampf(_window_pos.x, area.position.x, area.end.x)
		if state != State.FALL:
			# The floor is lower after walking onto a taller screen.
			if _window_pos.y < area.end.y - 1.0:
				_enter(State.FALL)
			else:
				_window_pos.y = area.end.y

	var target := Vector2i(_window_pos.round())
	if target != _window.position:
		_window.position = target


func _apply_settings() -> void:
	_walk_speed = Settings.value("pet", "walk_speed")
	_size = Settings.value("pet", "size")
	_window.size = Vector2i(Vector2(_base_size) * _size)
	_window.content_scale_factor = _size
	_window.mouse_passthrough_polygon = _hit_polygon()
	# The window grows downward: put the feet back on the floor.
	if not is_airborne():
		_window_pos.y = _walk_area().end.y


func is_airborne() -> bool:
	return state == State.CARRIED or state == State.FALL


func say(text: String) -> void:
	_bubble.say(text)


func cheer() -> void:
	if not is_airborne():
		_enter(State.CHEER)


func grab() -> void:
	_grab_offset = DisplayServer.mouse_get_position() - _window.position
	_enter(State.CARRIED)


func release() -> void:
	if state == State.CARRIED:
		_enter(State.FALL)


func _enter(next: State) -> void:
	state = next
	match next:
		State.IDLE:
			_timer = randf_range(2.0, 6.0)
		State.WALK:
			_timer = randf_range(3.0, 8.0)
			if randf() < 0.5:
				facing = -facing
		State.CHEER:
			_timer = CHEER_SECONDS
		State.FALL:
			_fall_speed = 0.0


## Valid top-left positions of the window. The bottom edge is the floor of the
## current screen. The width spans every screen placed side by side with it.
func _walk_area() -> Rect2:
	var current := _window.current_screen
	var usable := DisplayServer.screen_get_usable_rect(current)
	var row := _screen_rect(current)
	var left := usable.position.x
	var right := usable.end.x
	var others := range(DisplayServer.get_screen_count())
	others.erase(current)
	var grown := true
	while grown:
		grown = false
		for screen: int in others.duplicate():
			var rect := _screen_rect(screen)
			# Grown sideways by 1: touching edges do not count as intersecting.
			if not rect.grow_individual(1, 0, 1, 0).intersects(row):
				continue
			var screen_usable := DisplayServer.screen_get_usable_rect(screen)
			left = mini(left, screen_usable.position.x)
			right = maxi(right, screen_usable.end.x)
			row = row.merge(Rect2i(rect.position.x, row.position.y, rect.size.x, row.size.y))
			others.erase(screen)
			grown = true
	var margin := SIDE_MARGIN * _size
	return Rect2(left - margin, usable.position.y, right - left - _window.size.x + margin * 2.0, usable.size.y - _window.size.y)


func _screen_rect(screen: int) -> Rect2i:
	return Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))


func _hit_polygon() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * i / 24.0
		points.append((HIT_CENTER + Vector2(cos(angle), sin(angle)) * HIT_RADIUS) * _size)
	return points
