extends Node2D
## Draws the Claude mascot from code as blocks on a pixel grid, no image assets.
## Reads the state of the parent Pet.

## Size of one grid unit, in pixels.
const UNIT := 9.0
## Bottom center of the feet, in window coordinates. Origin of the grid.
const GROUND := Vector2(150, 246)

# Shapes in grid units, Y negative upward.
const BODY := Rect2(-6, -10, 12, 8)
const ARMS: Array[Rect2] = [Rect2(-8, -6, 2, 2), Rect2(6, -6, 2, 2)]
const EYES: Array[Rect2] = [Rect2(-4, -8, 1, 2), Rect2(3, -8, 1, 2)]
const LEG_COLUMNS: Array[float] = [-5, -3, 2, 4]
const LEG_HEIGHT := 2.0

const HEART_ROWS: PackedStringArray = [
	".XX.XX.",
	"XXXXXXX",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	"...X...",
]
const HEART_PIXEL := 3.0

const EYE := Color("#1f1e1d")
const PAPER := Color("#fffdf8")
const HEART := Color("#ff5d73")
const SHADOW := Color(0, 0, 0, 0.18)

const BLINK_SECONDS := 0.12
const LABEL_FONT_SIZE := 11
const LABEL_MAX_LENGTH := 28

var _time := 0.0
var _blink_in := 3.0

@onready var _pet: Pet = get_parent()
@onready var _font := ThemeDB.fallback_font


func _process(delta: float) -> void:
	_time += delta
	_blink_in -= delta
	if _blink_in < -BLINK_SECONDS:
		_blink_in = randf_range(2.0, 5.0)
	queue_redraw()


func _draw() -> void:
	var state := _pet.state
	var airborne := _pet.is_airborne()
	# Pixels. hop lifts the whole mascot, rise lifts only the body (legs stretch).
	var hop := 0.0
	var rise := (sin(_time * 2.0) * 0.5 + 0.5) * 2.0
	var arm_raise := 0.0
	var arm_wave := 0.0
	match state:
		Pet.State.WALK:
			rise = absf(sin(_time * 9.0)) * 3.0
		Pet.State.SLEEP:
			# Sits on the ground: the legs fold under the body.
			rise = (sin(_time * 1.2) * 0.5 + 0.5) * 2.0 - LEG_HEIGHT * UNIT
		Pet.State.ALERT:
			hop = absf(sin(_time * 8.0)) * 6.0
			arm_wave = 2.0
		Pet.State.CHEER:
			hop = absf(sin(_time * 10.0)) * 18.0
			arm_raise = 2.0
		Pet.State.CARRIED, Pet.State.FALL:
			arm_raise = 2.0
	var body_offset := Vector2(0, -hop - rise)

	_draw_label()
	if not airborne:
		var width := 13.0 * UNIT * (1.0 - hop * 0.015)
		draw_rect(Rect2(GROUND + Vector2(-width / 2.0, 0), Vector2(width, 4)), SHADOW)

	if state != Pet.State.SLEEP:
		_draw_legs(state, body_offset.y, hop)
	_block(BODY, body_offset, _pet.color)
	for i in ARMS.size():
		# Waving arms rise in turn.
		var raise := arm_raise + arm_wave * float(sin(_time * 10.0 + i * PI) > 0.0)
		_block(ARMS[i], body_offset - Vector2(0, raise * UNIT), _pet.color)
	_draw_eyes(state, body_offset)

	var body_top := GROUND + body_offset + Vector2(0, BODY.position.y * UNIT)
	match state:
		Pet.State.SLEEP:
			_draw_snore(body_top + Vector2(BODY.end.x * UNIT, 0))
		Pet.State.THINK:
			# Three dots that fill up in a loop.
			for i in int(_time * 2.5) % 4:
				_block(Rect2(-2.4 + i * 2.0, -12.5, 0.8, 0.8), body_offset, _pet.color)
		Pet.State.ALERT:
			if fmod(_time, 0.6) < 0.4:
				_block(Rect2(-0.5, -15.5, 1, 2.5), body_offset, HEART)
				_block(Rect2(-0.5, -12.5, 1, 1), body_offset, HEART)
		Pet.State.CHEER:
			_draw_hearts(body_top)


func _draw_legs(state: Pet.State, body_shift: float, hop: float) -> void:
	var top := GROUND.y - LEG_HEIGHT * UNIT + body_shift
	for i in LEG_COLUMNS.size():
		var x := GROUND.x + LEG_COLUMNS[i] * UNIT
		var bottom := GROUND.y - hop
		match state:
			Pet.State.WALK:
				# Legs step in two alternating pairs.
				bottom -= maxf(0.0, sin(_time * 9.0 + (i % 2) * PI)) * UNIT * 0.8
			Pet.State.CARRIED, Pet.State.FALL:
				x += sin(_time * 6.0 + i) * 2.0
		draw_rect(Rect2(x, top, UNIT, bottom - top), _pet.color)


func _draw_eyes(state: Pet.State, body_offset: Vector2) -> void:
	var closed := state == Pet.State.SLEEP or (_blink_in < 0.0 and not _pet.is_airborne())
	var look := Vector2(_pet.facing, 0)
	match state:
		Pet.State.SLEEP:
			look = Vector2.ZERO
		Pet.State.THINK:
			look = Vector2(0, -0.6)
	for eye in EYES:
		var shape := eye
		shape.position += look
		if closed:
			shape = Rect2(shape.position.x - 0.25, shape.get_center().y, 1.5, 0.4)
		elif _pet.is_airborne():
			shape = shape.grow(0.3)
		_block(shape, body_offset, EYE)


func _draw_snore(from: Vector2) -> void:
	for i in 3:
		var phase := fmod(_time * 0.4 + i / 3.0, 1.0)
		var at := from + Vector2(-10.0 + phase * 20.0, -6.0 - phase * 45.0)
		draw_string(_font, at, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 + phase * 12), Color(_pet.color.darkened(0.2), sin(phase * PI)))


func _draw_hearts(body_top: Vector2) -> void:
	var size := Vector2(HEART_ROWS[0].length(), HEART_ROWS.size()) * HEART_PIXEL
	for i in 3:
		var phase := fmod(_time * 0.9 + i / 3.0, 1.0)
		var center := body_top + Vector2((i - 1) * 40.0 + sin(_time * 4.0 + i) * 4.0, -16.0 - phase * 36.0)
		var color := Color(HEART, sin(phase * PI))
		for row in HEART_ROWS.size():
			for column in HEART_ROWS[row].length():
				if HEART_ROWS[row][column] == "X":
					var at := center - size / 2.0 + Vector2(column, row) * HEART_PIXEL
					draw_rect(Rect2(at, Vector2.ONE * HEART_PIXEL), color)


## Name tag under the feet.
func _draw_label() -> void:
	if _pet.label.is_empty() or not Settings.value("pet", "show_name"):
		return
	var text := _pet.label.left(LABEL_MAX_LENGTH)
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var box := Rect2(GROUND.x - text_size.x / 2.0 - 5.0, GROUND.y + 7.0, text_size.x + 10.0, text_size.y + 2.0)
	draw_rect(box, EYE)
	draw_rect(Rect2(box.position, Vector2(4, box.size.y)), _pet.color)
	var baseline := box.position + Vector2(7, 1 + _font.get_ascent(LABEL_FONT_SIZE))
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, PAPER)


## Fills a shape given in grid units.
func _block(shape: Rect2, offset: Vector2, color: Color) -> void:
	draw_rect(Rect2(GROUND + shape.position * UNIT + offset, shape.size * UNIT), color)
