class_name Pet
extends Node2D
## State machine of the pet. The pet does not move inside the window:
## the whole OS window moves across the desktop. One window per pet.

enum State {
	IDLE, SIT, WALK, SLEEP, STRETCH, THINK, ALERT, CHEER, GREET, GLARE, HIGH_FIVE, WORRY, ROAST,
	KNOCK, SWEEP, CLIMB, CARRIED, FALL,
}
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
	State.GLARE: 1.8,
	State.HIGH_FIVE: 1.3,
	State.WORRY: 1.5,
	State.ROAST: 7.0,
	State.KNOCK: 1.2,
	State.SWEEP: 2.2,
	State.CLIMB: 0.7,
}
## States slow enough for a low frame rate.
const CALM: Array[State] = [State.IDLE, State.SIT, State.SLEEP, State.THINK]
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
## A fall from higher than this opens the umbrella, which caps the fall speed.
const UMBRELLA_HEIGHT := 350.0
const UMBRELLA_SPEED := 220.0
## Share of the walk speed lost per level of baggage.
const BAGGAGE_DRAG := 0.2
## Chance, each time the pet becomes idle, to jump onto the perch.
const PERCH_CHANCE := 0.2
const PERCH_CHANCE_THINKING := 0.6
## Chance, each time the pet becomes idle on the perch, to jump off it.
const PERCH_LEAVE_CHANCE := 0.1
const PERCH_MIN_WIDTH := 200.0
const CLIMB_ARC := 120.0
## Seconds, from the start of the knock, of each blow on the glass. A blow
## shakes the window sideways for a moment.
const KNOCK_BLOWS: Array[float] = [0.25, 0.65]
const KNOCK_SHAKE_SECONDS := 0.12
const KNOCK_SHAKE_PIXELS := 2.0
## Speed of the run to the glass, against the walk speed.
const KNOCK_HURRY := 2.4
## Landing speed from which the fall is heard.
const THUD_SPEED := 500.0
const HIDING_PLACE := Vector2i(-20000, -20000)
## Clickable region in window coordinates. Clicks outside reach the desktop.
const HIT_CENTER := Vector2(150, 192)
const HIT_RADIUS := Vector2(72, 70)
## Height of the feet in the window, from its top.
const FEET_Y := 246.0
## Empty window width on each side of the mascot. The window may overflow the
## screen by this much, so the mascot itself reaches the screen edge.
const SIDE_MARGIN := 78.0
## Seconds between two readings of the screen layout. Reading it asks the
## display server, too slow for every frame.
const AREA_REFRESH_SECONDS := 0.25

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
## How full the head is, 0 to 1. Smokes when nearly full.
var fullness := 0.0
## Size of the pile of folders carried, 0 to 3. Slows the walk.
var baggage := 0
## Wears a hard hat, next to a warning sign.
var hard_hat := false
## Looks at a map and scratches its head when it stands still.
var lost := false
## Taps its foot while it thinks.
var tapping := false
## What the pet works on. Two pets with the same one are rivals.
var repo := ""
## True while the umbrella is open.
var umbrella := false
## Walk speed and step rate, against the normal ones.
var pace := 1.0
## Stays where it is, sitting: no walk, no jump. Part of a tower.
var rooted := false
## Floats cross-legged while it thinks.
var meditating := false
## Lights the ground ahead.
var headlamp := false
## Wears sunglasses.
var cool := false
## Screens to keep off, in screen coordinates: those under a full screen
## window. The pet moves to another screen. With none left, it hides.
var avoid: Array[Rect2] = []
## Shows no text: no name, no caption, no bubble. For the lock screen.
var discreet := false:
	set(value):
		discreet = value
		if discreet:
			_bubble.hush()
## Top edge of a window the pet may stand on, in screen coordinates. No size: none.
var perch := Rect2():
	set(value):
		if value != perch:
			perch = value
			# The window moved or lost the focus: the pet falls off.
			_perched = false

var _window_pos := Vector2.ZERO
var _area := Rect2()
var _area_age := 0.0
var _velocity := Vector2.ZERO
var _timer := 0.0
var _grab_offset := Vector2i.ZERO
var _size := 1.0
var _walk_speed := 0.0
var _perched := false
var _wants_perch := false
var _climb_from := Vector2.ZERO
var _climb_to := Vector2.ZERO
## Window x to walk to, whatever the wish. NAN: none.
var _errand_x := NAN
## What the pet does once there, and how fast it goes.
var _errand_then := State.IDLE
var _errand_hurry := 1.0
var _knock_side := 1.0
var _hidden := false

@onready var _window := get_window()
@onready var _bubble: Bubble = $"../Bubble"
## Window size at scale 1.
@onready var _base_size := _window.size


func _ready() -> void:
	_apply_settings()
	Settings.changed.connect(_apply_settings)
	var area := _area
	_window_pos = Vector2(randf_range(area.position.x, area.end.x), area.end.y)
	_window.position = Vector2i(_window_pos)
	_enter(State.IDLE)


func _process(delta: float) -> void:
	_area_age += delta
	if _area_age >= AREA_REFRESH_SECONDS:
		_area = _walk_area()
		_area_age = 0.0
		_hidden = _free_screens().is_empty()
	var area := _ground()
	state_time += delta
	match state:
		State.IDLE:
			_timer -= delta
			if rooted and wish == Wish.ROAM:
				_enter(State.SIT)
			elif _wants_perch and wish in [Wish.ROAM, Wish.THINK] and (_perched or _can_climb()):
				_wants_perch = false
				if _perched:
					_perched = false
				else:
					_start_climb()
			elif wish != Wish.ROAM:
				_enter(WISH_STATE[wish])
			elif _timer <= 0.0:
				_enter(State.SIT if randf() < SIT_CHANCE else State.WALK)
		State.SIT:
			_timer -= delta
			if wish != Wish.ROAM or (_timer <= 0.0 and not rooted):
				_enter(State.IDLE)
		State.WALK:
			_walk(delta, area)
		State.SLEEP:
			if wish != Wish.SLEEP:
				_enter(State.STRETCH)
		State.THINK, State.ALERT:
			if WISH_STATE.get(wish) != state:
				_enter(State.IDLE)
		State.STRETCH, State.CHEER, State.GLARE, State.HIGH_FIVE, State.WORRY, State.ROAST, State.KNOCK, State.SWEEP:
			if state_time >= TIMED[state]:
				_enter(State.IDLE)
		State.GREET:
			if state_time >= TIMED[state]:
				# Walk away from the other pet, so the two do not stay stacked.
				var away := -facing
				_enter(State.WALK)
				facing = away
		State.CLIMB:
			var progress := minf(state_time / TIMED[state], 1.0)
			_window_pos = _climb_from.lerp(_climb_to, progress) - Vector2(0, sin(progress * PI) * CLIMB_ARC * _size)
			if progress >= 1.0:
				_perched = true
				_enter(State.IDLE)
		State.CARRIED:
			var target := Vector2(DisplayServer.mouse_get_position() - _grab_offset)
			# Smoothed hand speed: becomes the throw speed on release.
			_velocity = _velocity.lerp((target - _window_pos) / maxf(delta, 0.001), 0.35)
			_window_pos = target
		State.FALL:
			_fly(delta, area)

	# The ground may have changed above: the pet reached its perch, or left it.
	area = _ground()
	if state != State.CARRIED and state != State.CLIMB:
		_window_pos.x = clampf(_window_pos.x, area.position.x, area.end.x)
		if state != State.FALL:
			# The floor is lower: taller screen, or the perch is gone.
			if _window_pos.y < area.end.y - 1.0:
				_velocity = Vector2.ZERO
				_enter(State.FALL)
			else:
				_window_pos.y = area.end.y

	var target_pos := Vector2i(_window_pos.round())
	if state == State.KNOCK:
		for blow in KNOCK_BLOWS:
			if state_time >= blow and state_time < blow + KNOCK_SHAKE_SECONDS:
				target_pos.x += roundi(KNOCK_SHAKE_PIXELS * (1.0 if sin((state_time - blow) * 90.0) >= 0.0 else -1.0))
	if _hidden:
		# Parked off every screen. Hiding the window would destroy it.
		target_pos = HIDING_PLACE
	if target_pos != _window.position:
		_window.position = target_pos


func _walk(delta: float, area: Rect2) -> void:
	var on_errand := not is_nan(_errand_x)
	if on_errand:
		facing = signf(_errand_x - _window_pos.x)
	var speed := _walk_speed * _size * pace * (1.0 - BAGGAGE_DRAG * baggage)
	if on_errand:
		# An errand goes on whatever the wish, until the pet is there.
		_window_pos.x = move_toward(_window_pos.x, clampf(_errand_x, area.position.x, area.end.x), speed * _errand_hurry * delta)
		if is_equal_approx(_window_pos.x, clampf(_errand_x, area.position.x, area.end.x)):
			_enter(_errand_then)
		return
	_window_pos.x += facing * speed * delta
	if _window_pos.x <= area.position.x:
		facing = 1.0
	elif _window_pos.x >= area.end.x:
		facing = -1.0
	_timer -= delta
	if wish != Wish.ROAM or _timer <= 0.0:
		_enter(State.IDLE)


## Free flight after a drop or a throw: gravity, bounce on the sides and the floor.
func _fly(delta: float, area: Rect2) -> void:
	_velocity.y += GRAVITY * _size * delta
	if _velocity.y > 0.0 and area.end.y - _window_pos.y > UMBRELLA_HEIGHT * _size:
		umbrella = true
	if umbrella:
		_velocity.y = minf(_velocity.y, UMBRELLA_SPEED * _size)
	_window_pos += _velocity * delta
	if _window_pos.x < area.position.x or _window_pos.x > area.end.x:
		_velocity.x = -_velocity.x * BOUNCE
	if absf(_velocity.x) > 1.0:
		facing = signf(_velocity.x)
	if _window_pos.y < area.end.y:
		return
	_window_pos.y = area.end.y
	if _velocity.y > THUD_SPEED * _size:
		Events.post(&"pet_landed", {"pet": self})
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
	_area = _walk_area()
	# The window grows downward: put the feet back on the floor.
	if not is_airborne():
		_window_pos.y = _ground().end.y


func is_airborne() -> bool:
	return state == State.CARRIED or state == State.FALL


## True when the pet moves fast enough to need smooth frames.
func is_lively() -> bool:
	return hovered or state not in CALM


## True when the pet is free to stop for another pet.
func is_free() -> bool:
	return wish == Wish.ROAM and not rooted and is_nan(_errand_x) and state in [State.IDLE, State.SIT, State.WALK]


func is_perched() -> bool:
	return _perched


## Feet position on the desktop, in screen coordinates.
func feet() -> Vector2:
	return _window_pos + Vector2(_window.size.x / 2.0, FEET_Y * _size)


func scale_factor() -> float:
	return _size


func say(text: String) -> void:
	if not discreet:
		_bubble.say(text)


## Text shown as long as no other bubble is up. Empty: none.
func show_card(text: String) -> void:
	_bubble.card = "" if discreet else text


func cheer() -> void:
	_play(State.CHEER)


func worry() -> void:
	_play(State.WORRY)


## Sits by a campfire and roasts a marshmallow.
func roast() -> void:
	_play(State.ROAST)


## Waves at a pet standing on the given side (-1 left, 1 right).
func greet(side: float) -> void:
	facing = side
	_play(State.GREET)


## Stares down a rival standing on the given side.
func glare(side: float) -> void:
	facing = side
	_play(State.GLARE)


## Claps hands with a pet standing on the given side.
func high_five(side: float) -> void:
	facing = side
	_play(State.HIGH_FIVE)


## Sweeps the floor in front of itself.
func sweep() -> void:
	_play(State.SWEEP)


## Walks until its feet are at the given screen x, whatever the wish, then
## enters the given state. Does nothing in the air or on a perch.
func walk_to(feet_x: float, then := State.IDLE, hurry := 1.0) -> void:
	if _perched or is_airborne() or state == State.CLIMB:
		return
	_enter(State.WALK)
	_errand_x = feet_x - _window.size.x / 2.0
	_errand_then = then
	_errand_hurry = hurry


## Runs until its feet are at the given screen x, then knocks twice on the
## screen edge on the given side (-1 left, 1 right). On a perch or in the air:
## knocks where it is.
func knock_at(feet_x: float, side: float) -> void:
	_knock_side = side
	if _perched:
		_play(State.KNOCK)
	else:
		walk_to(feet_x, State.KNOCK, KNOCK_HURRY)


## Jumps onto the given top edge and stands at its middle.
func climb_onto(edge: Rect2) -> void:
	perch = edge
	_start_climb(true)


func grab() -> void:
	_grab_offset = DisplayServer.mouse_get_position() - _window.position
	_velocity = Vector2.ZERO
	_perched = false
	_enter(State.CARRIED)


func release() -> void:
	if state == State.CARRIED:
		_velocity = _velocity.limit_length(MAX_THROW_SPEED)
		_enter(State.FALL)


## Starts a short act, unless the pet is in the air.
func _play(act: State) -> void:
	if not is_airborne() and state != State.CLIMB:
		_enter(act)


func _enter(next: State) -> void:
	state = next
	state_time = 0.0
	umbrella = false
	if next != State.WALK:
		_errand_x = NAN
	if next == State.KNOCK:
		facing = _knock_side
		Events.post(&"pet_knocked", {"pet": self})
	match next:
		State.IDLE:
			_timer = randf_range(2.0, 6.0)
			var chance := PERCH_CHANCE_THINKING if wish == Wish.THINK else PERCH_CHANCE
			_wants_perch = randf() < (PERCH_LEAVE_CHANCE if _perched else chance)
		State.SIT:
			_timer = randf_range(4.0, 9.0)
		State.WALK:
			_timer = randf_range(3.0, 8.0)
			if randf() < 0.5:
				facing = -facing


## True when the perch is wide enough, on screen, and above the floor.
func _can_climb() -> bool:
	if not Settings.value("desktop", "perch") or perch.size.x < PERCH_MIN_WIDTH * _size:
		return false
	var top := perch.position.y - FEET_Y * _size
	return top >= _area.position.y - 100.0 * _size and top < _area.end.y - 100.0 * _size


func _start_climb(centered := false) -> void:
	_climb_from = _window_pos
	var spot := _perch_ground()
	_climb_to = Vector2(randf_range(spot.position.x, spot.end.x), spot.end.y)
	if centered:
		_climb_to.x = spot.get_center().x
	facing = signf(_climb_to.x - _climb_from.x)
	_enter(State.CLIMB)


## Valid top-left positions of the window where the pet stands. The bottom
## edge is the floor: the screen floor, or the top of the perch.
func _ground() -> Rect2:
	return _perch_ground() if _perched else _area


func _perch_ground() -> Rect2:
	var margin := SIDE_MARGIN * _size
	var top := perch.position.y - FEET_Y * _size
	return Rect2(perch.position.x - margin, _area.position.y, perch.size.x - _window.size.x + margin * 2.0, top - _area.position.y)


## Valid top-left positions of the window on the screens. The bottom edge is
## the floor of the current screen. The width spans every screen placed side
## by side with it.
func _walk_area() -> Rect2:
	var screens := _free_screens()
	if screens.is_empty():
		return _area
	var current := _window.current_screen
	if current not in screens:
		# Its screen is taken by a full screen window: go to the nearest free one.
		var from := _screen_rect(current).get_center()
		screens.sort_custom(func(a: int, b: int) -> bool:
			return from.distance_squared_to(_screen_rect(a).get_center()) < from.distance_squared_to(_screen_rect(b).get_center()))
		current = screens[0]
	var usable := DisplayServer.screen_get_usable_rect(current)
	var row := _screen_rect(current)
	var left := usable.position.x
	var right := usable.end.x
	var others := screens.duplicate()
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


## Screens not under a full screen window.
func _free_screens() -> Array:
	return range(DisplayServer.get_screen_count()).filter(func(screen: int) -> bool:
		var rect := Rect2(_screen_rect(screen))
		for zone in avoid:
			# Covered for the most part.
			if rect.intersection(zone).get_area() * 2.0 >= rect.get_area():
				return false
		return true)


func _screen_rect(screen: int) -> Rect2i:
	return Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))


func _hit_polygon() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * i / 24.0
		points.append((HIT_CENTER + Vector2(cos(angle), sin(angle)) * HIT_RADIUS) * _size)
	return points
