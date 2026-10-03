class_name Letter
extends Node2D
## A letter that flies from a pet to another, in its own small window. At rest
## the window is parked off every screen, and serves again for the next letter.

## Envelope, around the middle of the window.
const ENVELOPE := Vector2(36, 24)
const BORDER := 2.0
## Flight speed in pixels per second, at size 1. The flight lasts no less and
## no more than these seconds.
const SPEED := 700.0
const SECONDS_RANGE := Vector2(0.7, 1.8)
## Height of the arc: this share of the distance, and no more than this, at size 1.
const ARC_SHARE := 0.25
const ARC_MAX := 220.0
## Height above the feet where the letter leaves a pet and reaches one, at size 1.
const HAND_HEIGHT := 70.0
## The envelope rocks by this angle, in radians.
const ROCK := 0.18

const PAPER := Color("#fffdf8")
const INK := Color("#1f1e1d")

## Pet the letter flies to. Null: at rest.
var _to: Pet = null
var _from_point := Vector2.ZERO
var _seconds := 1.0
var _time := 0.0
## The seal has the color of the pet that sent the letter.
var _seal := Pet.DEFAULT_COLOR

@onready var _window := get_window()
## Window size at scale 1.
@onready var _base_size := _window.size


func _ready() -> void:
	# Clicks go through to the desktop.
	if OS.get_name() == "Windows":
		# A polygon would cut the drawing there: the whole window lets clicks through.
		_window.mouse_passthrough = true
	else:
		_window.mouse_passthrough_polygon = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	stop()


func _process(delta: float) -> void:
	if _to == null:
		return
	_time += delta
	var progress := minf(_time / _seconds, 1.0)
	# The pet may walk meanwhile: aim at where it is now.
	var target := _hand(_to)
	var arc := minf(_from_point.distance_to(target) * ARC_SHARE, ARC_MAX * _to.scale_factor())
	_place(_from_point.lerp(target, progress) - Vector2(0, sin(progress * PI) * arc))
	queue_redraw()
	if progress >= 1.0:
		var reached := _to
		stop()
		Events.post(&"letter_landed", {"pet": reached})


func _draw() -> void:
	draw_set_transform(Vector2(_base_size) / 2.0, sin(_time * 9.0) * ROCK)
	var box := Rect2(-ENVELOPE / 2.0, ENVELOPE)
	draw_rect(box.grow(BORDER), INK)
	draw_rect(box, PAPER)
	# The flap, then the seal on its tip.
	draw_polyline([box.position, Vector2(0, 2), Vector2(box.end.x, box.position.y)], INK, BORDER)
	draw_rect(Rect2(-3, -1, 6, 6), _seal)
	draw_set_transform(Vector2.ZERO)


## Flies from the first pet to the second, then posts letter_landed {pet}.
func send(from: Pet, to: Pet) -> void:
	var size := to.scale_factor()
	_window.size = Vector2i(Vector2(_base_size) * size)
	_window.content_scale_factor = size
	_to = to
	_seal = from.color
	_time = 0.0
	_from_point = _hand(from)
	_seconds = clampf(_from_point.distance_to(_hand(to)) / (SPEED * size), SECONDS_RANGE.x, SECONDS_RANGE.y)
	_place(_from_point)
	queue_redraw()


## Ends the flight at once, with no landing. Hiding the window would destroy it.
func stop() -> void:
	_to = null
	_window.position = Pet.HIDING_PLACE


func is_flying() -> bool:
	return _to != null


## Pet the letter flies to. Null: at rest.
func recipient() -> Pet:
	return _to


func _hand(pet: Pet) -> Vector2:
	return pet.feet() - Vector2(0, HAND_HEIGHT * pet.scale_factor())


## Puts the middle of the window at the given point of the desktop.
func _place(point: Vector2) -> void:
	_window.position = Vector2i((point - Vector2(_window.size) / 2.0).round())
