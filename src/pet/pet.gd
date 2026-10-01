class_name Pet
extends Node2D
## State machine of the pet. The pet does not move inside the window:
## the whole OS window moves across the desktop. One window per pet.

enum State { IDLE, SIT, WALK, SLEEP, STRETCH, THINK, ALERT, CHEER, GREET, WORRY, CARRIED, FALL }
## Standing order from the brain. The pet obeys as soon as it is idle.
enum Wish { ROAM, SLEEP, THINK, ALERT }

const WISH_STATE := {
	Wish.SLEEP: State.SLEEP,
	Wish.THINK: State.THINK,
	Wish.ALERT: State.ALERT,
}
## States that end on their own, with their duration in seconds.
const TIMED := {
	State.STRETCH: 1.2,
	State.CHEER: 1.6,
	State.GREET: 1.4,
	State.WORRY: 1.5,
}
const DEFAULT_COLOR := Color("#d97757")
## Number of entries in the accessory list of the body, "none" included.
const ACCESSORY_COUNT := 7
const GRAVITY := 2600.0
const SIT_CHANCE := 0.3
## Share of the speed kept after a bounce.
const BOUNCE := 0.5
## Below this landing speed the pet stays on the floor.
const MIN_BOUNCE_SPEED := 350.0
const MAX_THROW_SPEED := 3000.0
## Clickable region in window coordinates. Clicks outside reach the desktop.
const HIT_CENTER := Vector2(150, 192)
const HIT_RADIUS := Vector2(72, 70)
## Empty window width on each side of the mascot. The window may overflow the
## screen by this much, so the mascot itself reaches the screen edge.
const SIDE_MARGIN := 78.0

var state := State.IDLE
## Seconds since the state began.
var state_time := 0.0
var facing := 1.0
var wish := Wish.ROAM
## Key given by Pets: the Claude Code session id, or "".
var key := ""
## Name shown under the pet. Empty: no name tag.
var label := ""
var color := DEFAULT_COLOR
## Index in the accessory list of the body. 0: none.
var accessory := 0
## Short text above the head while thinking.
var caption := ""
## Number of small pets beside this one.
var minis := 0
## An urgent alert jumps higher.
var urgent := false
## True while the mouse is over the pet.
var hovered := false

var _window_pos := Vector2.ZERO
var _velocity := Vector2.ZERO
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
	state_time += delta
	match state:
		State.IDLE:
			_timer -= delta
			if wish != Wish.ROAM:
				_enter(WISH_STATE[wish])
			elif _timer <= 0.0:
				_enter(State.SIT if randf() < SIT_CHANCE else State.WALK)
		State.SIT:
			_timer -= delta
			if wish != Wish.ROAM or _timer <= 0.0:
				_enter(State.IDLE)
		State.WALK:
			_window_pos.x += facing * _walk_speed * _size * delta
			if _window_pos.x <= area.position.x:
				facing = 1.0
			elif _window_pos.x >= area.end.x:
				facing = -1.0
			_timer -= delta
			if wish != Wish.ROAM or _timer <= 0.0:
				_enter(State.IDLE)
		State.SLEEP:
			if wish != Wish.SLEEP:
				_enter(State.STRETCH)
		State.THINK, State.ALERT:
			if WISH_STATE.get(wish) != state:
				_enter(State.IDLE)
		State.STRETCH, State.CHEER, State.WORRY:
			if state_time >= TIMED[state]:
				_enter(State.IDLE)
		State.GREET:
			if state_time >= TIMED[state]:
				# Walk away from the other pet, so the two do not stay stacked.
				facing = -facing
				_enter(State.WALK)
		State.CARRIED:
			var target := Vector2(DisplayServer.mouse_get_position() - _grab_offset)
			# Smoothed hand speed: becomes the throw speed on release.
			_velocity = _velocity.lerp((target - _window_pos) / maxf(delta, 0.001), 0.35)
			_window_pos = target
		State.FALL:
			_fly(delta, area)

	if state != State.CARRIED:
		_window_pos.x = clampf(_window_pos.x, area.position.x, area.end.x)
		if state != State.FALL:
			# The floor is lower after walking onto a taller screen.
			if _window_pos.y < area.end.y - 1.0:
				_velocity = Vector2.ZERO
				_enter(State.FALL)
			else:
				_window_pos.y = area.end.y

	var target_pos := Vector2i(_window_pos.round())
	if target_pos != _window.position:
		_window.position = target_pos


## Free flight after a drop or a throw: gravity, bounce on the sides and the floor.
func _fly(delta: float, area: Rect2) -> void:
	_velocity.y += GRAVITY * _size * delta
	_window_pos += _velocity * delta
	if _window_pos.x < area.position.x or _window_pos.x > area.end.x:
		_velocity.x = -_velocity.x * BOUNCE
	if absf(_velocity.x) > 1.0:
		facing = signf(_velocity.x)
	if _window_pos.y < area.end.y:
		return
	_window_pos.y = area.end.y
	if _velocity.y > MIN_BOUNCE_SPEED * _size:
		_velocity = Vector2(_velocity.x * BOUNCE, -_velocity.y * BOUNCE)
	else:
		_enter(State.IDLE)


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


## True when the pet is free to stop for another pet.
func is_free() -> bool:
	return wish == Wish.ROAM and state in [State.IDLE, State.SIT, State.WALK]


## Feet position on the desktop, in screen coordinates.
func feet() -> Vector2:
	return _window_pos + Vector2(_window.size.x / 2.0, _window.size.y)


func scale_factor() -> float:
	return _size


func say(text: String) -> void:
	_bubble.say(text)


## Text shown as long as no other bubble is up. Empty: none.
func show_card(text: String) -> void:
	_bubble.card = text


func cheer() -> void:
	if not is_airborne():
		_enter(State.CHEER)


func worry() -> void:
	if not is_airborne():
		_enter(State.WORRY)


## Waves at a pet standing on the given side (-1 left, 1 right).
func greet(side: float) -> void:
	facing = side
	_enter(State.GREET)


func grab() -> void:
	_grab_offset = DisplayServer.mouse_get_position() - _window.position
	_velocity = Vector2.ZERO
	_enter(State.CARRIED)


func release() -> void:
	if state == State.CARRIED:
		_velocity = _velocity.limit_length(MAX_THROW_SPEED)
		_enter(State.FALL)


func _enter(next: State) -> void:
	state = next
	state_time = 0.0
	match next:
		State.IDLE:
			_timer = randf_range(2.0, 6.0)
		State.SIT:
			_timer = randf_range(4.0, 9.0)
		State.WALK:
			_timer = randf_range(3.0, 8.0)
			if randf() < 0.5:
				facing = -facing


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
