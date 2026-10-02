extends Node2D
## Draws the Claude mascot from code as blocks on a pixel grid, no image assets.
## Reads the state of the parent Pet.

## Size of one grid unit, in pixels.
const UNIT := 9.0
## Bottom center of the feet, in window coordinates. Origin of the grid.
const GROUND := Vector2(150, Pet.FEET_Y)

# Shapes in grid units, Y negative upward.
const BODY := Rect2(-6, -10, 12, 8)
const ARMS: Array[Rect2] = [Rect2(-8, -6, 2, 2), Rect2(6, -6, 2, 2)]
const EYES: Array[Rect2] = [Rect2(-4, -8, 1, 2), Rect2(3, -8, 1, 2)]
const LEG_COLUMNS: Array[float] = [-5, -3, 2, 4]
const LEG_HEIGHT := 2.0

const EYE := Color("#1f1e1d")
const PAPER := Color("#fffdf8")
const HEART := Color("#ff5d73")
const GOLD := Color("#f2c230")
const SWEAT := Color("#7fd0ff")
const SMOKE := Color("#a8a8a8")
const WOOD := Color("#8a5a33")
const MANILA := Color("#e8c98a")
const FLAME := Color("#ff8a2a")
const STRAW := Color("#d9b24a")
const LIGHT := Color(1.0, 0.93, 0.45, 0.3)
const SHADOW := Color(0, 0, 0, 0.18)

## Worn on the head. "room": grid units taken above the head, so that the
## signs drawn there (dots, "!") move up. "blocks": shape then color.
const ACCESSORIES: Array[Dictionary] = [
	{"room": 0.0, "blocks": []},
	# Top hat.
	{"room": 4.0, "blocks": [
		[Rect2(-4.5, -11, 9, 1), EYE], [Rect2(-3, -14, 6, 3), EYE], [Rect2(-3, -12, 6, 1), HEART],
	]},
	# Crown.
	{"room": 3.5, "blocks": [
		[Rect2(-4, -11.5, 8, 1.5), GOLD], [Rect2(-4, -13, 1.5, 1.5), GOLD],
		[Rect2(-0.75, -13.5, 1.5, 2), GOLD], [Rect2(2.5, -13, 1.5, 1.5), GOLD],
	]},
	# Cap.
	{"room": 2.0, "blocks": [
		[Rect2(-4, -12, 8, 2), Color("#3b6fd4")], [Rect2(3, -11, 4.5, 1), Color("#2b4f9a")],
	]},
	# Bow.
	{"room": 2.0, "blocks": [
		[Rect2(1.5, -12, 1.5, 2), HEART], [Rect2(4, -12, 1.5, 2), HEART], [Rect2(3, -11.5, 1, 1), Color("#c93a55")],
	]},
	# Glasses. Wide enough for the eyes to look left and right inside.
	{"room": 0.0, "blocks": [
		[Rect2(-5.9, -8.8, 4.2, 0.5), EYE], [Rect2(-5.9, -5.7, 4.2, 0.5), EYE],
		[Rect2(-5.9, -8.8, 0.5, 3.6), EYE], [Rect2(-2.2, -8.8, 0.5, 3.6), EYE],
		[Rect2(1.7, -8.8, 4.2, 0.5), EYE], [Rect2(1.7, -5.7, 4.2, 0.5), EYE],
		[Rect2(1.7, -8.8, 0.5, 3.6), EYE], [Rect2(5.4, -8.8, 0.5, 3.6), EYE],
		[Rect2(-1.7, -7.6, 3.4, 0.5), EYE],
	]},
	# Flower.
	{"room": 3.5, "blocks": [
		[Rect2(-0.25, -12.5, 0.5, 2.5), Color("#46a758")], [Rect2(-1.25, -14, 2.5, 2), HEART],
		[Rect2(-0.5, -13.5, 1, 1), GOLD],
	]},
]
## Replaces the accessory while a merge or a rebase is not finished.
const HARD_HAT := {"room": 3.5, "blocks": [
	[Rect2(-4, -12.5, 8, 2.5), GOLD], [Rect2(-5, -10.5, 10, 0.8), Color("#c99a12")],
	[Rect2(-0.5, -13, 1, 3), Color("#ffe27a")],
]}
## Warning sign planted beside the pet, with the hard hat.
const SIGN: Array[Array] = [
	[Rect2(8.7, -6.5, 0.5, 6.5), Color("#8a8a8a")], [Rect2(7.4, -9.6, 3.1, 3.1), GOLD],
	[Rect2(8.7, -9.1, 0.5, 1.4), EYE], [Rect2(8.7, -7.4, 0.5, 0.5), EYE],
]
## Shapes drawn on the right side. Mirrored when the pet faces left.
const UMBRELLA: Array[Array] = [
	[Rect2(-0.25, -15.5, 0.5, 5.5), EYE], [Rect2(-6.5, -16.5, 13, 1.2), HEART],
	[Rect2(-5, -17.5, 10, 1), HEART], [Rect2(-3, -18.3, 6, 0.8), HEART],
]
const CAMPFIRE_X := 10.0
## Hourglass a waiting pet watches: middle of its base from the feet, in grid
## units, then half its height and the half width of each row of a bulb, from
## the neck out.
const HOURGLASS_X := 10.5
const HOURGLASS_HALF := 2.6
const HOURGLASS_ROWS: Array[float] = [0.3, 0.7, 1.1, 1.4]
## Seconds the sand takes to run down, then the hourglass to turn over.
const HOURGLASS_RUN := 5.0
const HOURGLASS_TURN := 0.7
## Mailbox on the ground, on the left of the pet: post, box, slot, a letter
## that sticks out, and the raised flag.
const MAILBOX: Array[Array] = [
	[Rect2(-11.9, -4.5, 0.7, 4.5), WOOD], [Rect2(-13.6, -7.5, 4.1, 3.0), Color("#3b6fd4")],
	[Rect2(-13.6, -7.9, 4.1, 0.4), Color("#2b4f9a")], [Rect2(-12.6, -7.2, 2.1, 0.7), PAPER],
	[Rect2(-13.0, -6.6, 2.9, 0.4), EYE], [Rect2(-9.5, -9.4, 0.4, 2.9), HEART], [Rect2(-10.7, -9.4, 1.2, 0.9), HEART],
]
## Middle of the mailbox from the feet, and top of the tag with the number of
## letters, in grid units.
const MAILBOX_X := 11.5
const MAILBOX_TAG_Y := -12.0
## Letter held out in front of a pet that reads it.
const SHEET: Array[Array] = [
	[Rect2(6.5, -9.0, 3.0, 3.4), PAPER], [Rect2(7.0, -8.3, 2.0, 0.3), SMOKE],
	[Rect2(7.0, -7.5, 2.0, 0.3), SMOKE], [Rect2(7.0, -6.7, 1.3, 0.3), SMOKE],
]
const SHADES: Array[Array] = [
	[Rect2(-5.6, -8.2, 4.2, 2.4), EYE], [Rect2(1.4, -8.2, 4.2, 2.4), EYE], [Rect2(-1.4, -7.8, 2.8, 0.6), EYE],
	[Rect2(-5.0, -7.8, 1.0, 0.5), PAPER], [Rect2(2.0, -7.8, 1.0, 0.5), PAPER],
]
## Lamp on the forehead, on the side the pet faces, and its strap.
const HEADLAMP: Array[Array] = [[Rect2(-6, -9.5, 12, 0.5), EYE], [Rect2(4.4, -9.9, 1.4, 1.3), GOLD]]
## Light of the lamp on the ground ahead: lamp, far end, near end. Grid units.
const BEAM: Array[Vector2] = [Vector2(5.8, -9.2), Vector2(16, 0.4), Vector2(8.5, 0.4)]
## Signs that circle a meditating pet.
const MANTRA: PackedStringArray = ["π", "∑", "√", "∞"]
const LEVITATION := 5.0

const HEART_ROWS: PackedStringArray = [
	".XX.XX.",
	"XXXXXXX",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	"...X...",
]
const HEART_PIXEL := 3.0
const NOTE_ROWS: PackedStringArray = [
	"..XXX",
	"..X..",
	"..X..",
	"XXX..",
	"XXX..",
]
const NOTE_PIXEL := 3.0
## Nods per second of a pet that grooves, then the height of a nod and the
## width of the sway, in pixels.
const GROOVE_BEATS := 2.0
const GROOVE_NOD := 2.5
const GROOVE_SWAY := 1.5

const BLINK_SECONDS := 0.12
## Animation steps per second while the pet is calm. Between two steps the
## picture is the same, so nothing is drawn: drawing is the main CPU cost.
const CALM_STEPS := 6.0
const TAG_FONT_SIZE := 11
const LABEL_MAX_LENGTH := 28
## The caption wraps on lines of this width, in pixels, and stops after a
## number of characters.
const CAPTION_WIDTH := 280.0
const CAPTION_MAX_LENGTH := 110
## The head smokes from this fullness on.
const SMOKE_FROM := 0.75
## Small pets: size against the main one, and feet positions from GROUND.
const MINI_SCALE := 0.28
const MINI_SPOTS: Array[Vector2] = [Vector2(-120, 0), Vector2(120, 0), Vector2(-120, -36), Vector2(120, -36)]
## Seconds a new small pet takes to run from the big one to its spot.
const MINI_RUN_SECONDS := 0.7

var _time := 0.0
var _blink_in := 3.0
## What the last picture showed of the pet. A change draws at once.
var _shown := 0
## Time of arrival of each small pet.
var _mini_born: Array[float] = []

@onready var _pet: Pet = get_parent()
@onready var _font := ThemeDB.fallback_font


func _init() -> void:
	assert(ACCESSORIES.size() == Pet.ACCESSORY_COUNT)


func _ready() -> void:
	Settings.changed.connect(func() -> void: _shown = 0)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var shown := _look()
	if not _pet.is_lively():
		# Calm: time moves by steps. The steps fall at the same instants for
		# every pet, so that they draw in the same frames.
		now = floorf(now * CALM_STEPS) / CALM_STEPS
		if now == _time and shown == _shown:
			return
	_shown = shown
	_blink_in -= now - _time
	_time = now
	if _blink_in < -BLINK_SECONDS:
		_blink_in = randf_range(2.0, 5.0)
	while _mini_born.size() < _pet.minis:
		_mini_born.append(_time)
	_mini_born.resize(mini(_pet.minis, _mini_born.size()))
	queue_redraw()


## Everything of the pet that the picture depends on, time aside.
func _look() -> int:
	return [
		_pet.state, _pet.facing, _pet.label, _pet.color, _pet.accessory, _pet.caption, _pet.minis,
		_pet.urgent, _pet.hovered, _pet.fullness >= SMOKE_FROM, _pet.baggage, _pet.hard_hat, _pet.lost,
		_pet.tapping, _pet.umbrella, _pet.meditating, _pet.headlamp, _pet.cool, _pet.discreet,
		_pet.rooted, _pet.is_perched(), _pet.grooving, _pet.mail, _pet.mailbox_side(),
	].hash()


func _draw() -> void:
	var state := _pet.state
	var airborne := _pet.is_airborne() or state == Pet.State.CLIMB
	var meditating := state == Pet.State.THINK and _pet.meditating
	var seated := meditating or state in [Pet.State.SLEEP, Pet.State.SIT, Pet.State.ROAST, Pet.State.WAIT]
	var still := state in [Pet.State.IDLE, Pet.State.SIT]
	var grooving := _pet.grooving and (still or state == Pet.State.WAIT or (state == Pet.State.THINK and not meditating))
	# Index of the arm on the side the pet faces, and of the other one.
	var front := 1 if _pet.facing > 0.0 else 0
	# Pixels. hop lifts the whole mascot, rise lifts only the body (legs stretch).
	var hop := 0.0
	var rise := (sin(_time * 2.0) * 0.5 + 0.5) * 2.0
	var shake := 0.0
	# Grid units, left arm then right arm.
	var arm_raise: Array[float] = [0.0, 0.0]
	match state:
		Pet.State.WALK:
			rise = absf(sin(_time * 9.0 * _pet.pace)) * 3.0
		Pet.State.KNOCK:
			# The arm in front goes up for each blow.
			for blow in Pet.KNOCK_BLOWS:
				if absf(_pet.state_time - blow) < 0.12:
					arm_raise[front] = 2.0
		Pet.State.SWEEP:
			arm_raise[front] = 0.5
		Pet.State.STRETCH:
			rise = sin(minf(_pet.state_time / Pet.TIMED[state], 1.0) * PI) * 12.0
			arm_raise = [2.0, 2.0]
		Pet.State.ALERT:
			hop = absf(sin(_time * 8.0)) * (18.0 if _pet.urgent else 6.0)
			# Waving arms rise in turn.
			for i in 2:
				arm_raise[i] = 2.0 * float(sin(_time * 10.0 + i * PI) > 0.0)
		Pet.State.CHEER:
			hop = absf(sin(_time * 10.0)) * 18.0
			arm_raise = [2.0, 2.0]
		Pet.State.GREET:
			hop = absf(sin(_time * 8.0)) * 4.0
			arm_raise[front] = 1.0 + float(sin(_time * 14.0) > 0.0)
		Pet.State.GLARE:
			shake = sin(_time * 30.0)
		Pet.State.HIGH_FIVE:
			hop = sin(minf(_pet.state_time / Pet.TIMED[state], 1.0) * PI) * 12.0
			arm_raise[front] = 3.0
		Pet.State.WORRY:
			shake = sin(_time * 45.0) * 2.5
		Pet.State.ROAST, Pet.State.READ:
			arm_raise[front] = 0.5
		Pet.State.THROW:
			# The arm in front goes up, and the pet rises with it.
			hop = sin(minf(_pet.state_time / Pet.TIMED[state], 1.0) * PI) * 6.0
			arm_raise[front] = 3.0
		Pet.State.NOD:
			# The body dips twice.
			rise = -absf(sin(_pet.state_time / Pet.TIMED[state] * TAU)) * 5.0
		Pet.State.CLIMB, Pet.State.CARRIED, Pet.State.FALL:
			arm_raise = [2.0, 2.0]
	if seated:
		# On the ground: the legs fold under the body.
		rise = (sin(_time * 1.2) * 0.5 + 0.5) * 2.0 - LEG_HEIGHT * UNIT
	if grooving:
		# Nods on each beat, and leans to one side then the other.
		rise += absf(sin(_time * PI * GROOVE_BEATS)) * GROOVE_NOD
		shake = sin(_time * PI * GROOVE_BEATS) * GROOVE_SWAY
	if _pet.lost and still:
		# Scratches its head.
		arm_raise[1 - front] = 2.0 + 0.5 * float(sin(_time * 8.0) > 0.0)
	if meditating:
		# Floats above the ground.
		hop = LEVITATION + sin(_time * 1.5) * 2.0
	var body_offset := Vector2(shake, -hop - rise)

	# Stacked on another pet: no name tag and no shadow over its face.
	var stacked := _pet.rooted and _pet.is_perched()
	if Settings.value("pet", "show_name") and not stacked and not _pet.discreet:
		_draw_tag(_pet.label.left(LABEL_MAX_LENGTH), GROUND + Vector2(0, 7), _pet.color)
	if not airborne and not stacked:
		var width := 13.0 * UNIT * (1.0 - hop * 0.015)
		draw_rect(Rect2(GROUND + Vector2(-width / 2.0, 0), Vector2(width, 4)), SHADOW)
	if _pet.hard_hat and not airborne:
		_blocks(SIGN, Vector2.ZERO, false)
	if _pet.mail > 0 and not airborne and not stacked:
		_draw_mailbox()
	for i in mini(_mini_born.size(), MINI_SPOTS.size()):
		_draw_mini(i)

	if _pet.headlamp and state != Pet.State.SLEEP and not airborne:
		var beam := PackedVector2Array()
		for point in BEAM:
			beam.append(GROUND + Vector2(point.x * signf(_pet.facing), point.y) * UNIT + (body_offset if point.y < 0.0 else Vector2.ZERO))
		draw_colored_polygon(beam, LIGHT)
	if meditating:
		_draw_mantra(body_offset, false)
	if not seated:
		_draw_legs(state, body_offset, hop, airborne)
	_draw_baggage(body_offset)
	_block(BODY, body_offset, _pet.color)
	for i in ARMS.size():
		_block(ARMS[i], body_offset - Vector2(0, arm_raise[i] * UNIT), _pet.color)
	if _pet.cool:
		# The eyes move, and would show past the edge of the lenses.
		_blocks(SHADES, body_offset, false)
	else:
		_draw_eyes(state, body_offset, meditating)
	if _pet.headlamp and state != Pet.State.SLEEP:
		_blocks(HEADLAMP, body_offset, true)
	if state == Pet.State.SWEEP:
		_draw_broom()
	if meditating:
		_draw_mantra(body_offset, true)

	var worn: Dictionary = HARD_HAT
	if not _pet.hard_hat:
		worn = ACCESSORIES[_pet.accessory if Settings.value("pet", "accessories") else 0]
	_blocks(worn.blocks, body_offset, false)
	if _pet.umbrella:
		_blocks(UMBRELLA, body_offset, false)
	if state == Pet.State.ROAST:
		_draw_campfire(body_offset)
	if state == Pet.State.WAIT:
		_draw_hourglass()
	if state == Pet.State.READ:
		_blocks(SHEET, body_offset, true)
	if _pet.lost and still:
		# A map held out in front.
		_blocks([[Rect2(6.5, -8.5, 3, 2.4), PAPER], [Rect2(7, -7.8, 2, 0.4), Color("#46a758")], [Rect2(7.6, -7.1, 1.2, 0.4), HEART]], body_offset, true)

	# Signs above the head sit over what is worn.
	var over_head := body_offset - Vector2(0, worn.room * UNIT)
	var body_top := GROUND + over_head + Vector2(0, BODY.position.y * UNIT)
	match state:
		Pet.State.SLEEP:
			_draw_snore(body_top + Vector2(BODY.end.x * UNIT, 0))
		Pet.State.THINK:
			# Three dots that fill up in a loop.
			for i in int(_time * 2.5) % 4:
				_block(Rect2(-2.4 + i * 2.0, -12.5, 0.8, 0.8), over_head, _pet.color)
			if not _pet.discreet:
				_draw_caption(_pet.caption.left(CAPTION_MAX_LENGTH), body_top - Vector2(0, 4.2 * UNIT))
		Pet.State.ALERT:
			if fmod(_time, 0.6) < 0.4:
				_block(Rect2(-0.5, -15.5, 1, 2.5), over_head, HEART)
				_block(Rect2(-0.5, -12.5, 1, 1), over_head, HEART)
		Pet.State.GLARE:
			# Anger mark.
			_blocks([[Rect2(5, -13, 2.4, 0.6), HEART], [Rect2(5.9, -13.9, 0.6, 2.4), HEART]], over_head, true)
		Pet.State.HIGH_FIVE:
			if fmod(_time, 0.2) < 0.12:
				_blocks([[Rect2(8.5, -15, 1, 1), GOLD], [Rect2(10, -13.5, 0.8, 0.8), GOLD], [Rect2(9.6, -16.6, 0.8, 0.8), GOLD]], body_offset, true)
		Pet.State.WORRY:
			_block(Rect2(6.6, -10.5, 0.8, 1.6), body_offset, SWEAT)
		Pet.State.CHEER:
			_draw_hearts(body_top)
	if _pet.lost and still and fmod(_time, 1.2) < 0.8:
		draw_string(_font, body_top + Vector2(-5, -8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, _pet.color)
	if _pet.fullness >= SMOKE_FROM and state != Pet.State.SLEEP:
		_draw_smoke(body_top)
	if grooving:
		_draw_note(body_top)


func _draw_legs(state: Pet.State, body_offset: Vector2, hop: float, airborne: bool) -> void:
	var top := GROUND.y - LEG_HEIGHT * UNIT + body_offset.y
	# The leg in front, on the side the pet faces.
	var front_leg := LEG_COLUMNS.size() - 1 if _pet.facing > 0.0 else 0
	for i in LEG_COLUMNS.size():
		var x := GROUND.x + LEG_COLUMNS[i] * UNIT + body_offset.x
		var bottom := GROUND.y - hop
		if state == Pet.State.WALK:
			# Legs step in two alternating pairs.
			bottom -= maxf(0.0, sin(_time * 9.0 * _pet.pace + (i % 2) * PI)) * UNIT * 0.8
		elif airborne:
			x += sin(_time * 6.0 + i) * 2.0
		elif state == Pet.State.THINK and _pet.tapping and i == front_leg:
			bottom -= maxf(0.0, sin(_time * 12.0)) * UNIT * 0.7
		draw_rect(Rect2(x, top, UNIT, bottom - top), _pet.color)


func _draw_eyes(state: Pet.State, body_offset: Vector2, meditating: bool) -> void:
	var closed := meditating or (_blink_in < 0.0 and not _pet.is_airborne())
	var wide := _pet.is_airborne()
	var look := Vector2(_pet.facing, 0)
	match state:
		Pet.State.SLEEP, Pet.State.STRETCH:
			look = Vector2.ZERO
			closed = true
		Pet.State.SIT:
			# Looks around.
			look = Vector2(signf(sin(_time * 0.9)), 0)
		Pet.State.THINK:
			# Up while thinking, down at its foot while it taps.
			look = Vector2(_pet.facing * 0.5, 0.5) if _pet.tapping else Vector2(0, -0.6)
		Pet.State.WAIT:
			# Down at the hourglass.
			look = Vector2(_pet.facing, 0.6)
		Pet.State.READ:
			# At the letter.
			look = Vector2(_pet.facing, 0.3)
		Pet.State.WORRY:
			look = Vector2.ZERO
			wide = true
	if _pet.hovered and not closed:
		# Follows the mouse while it is over the pet.
		var head := GROUND + body_offset + Vector2(0, -7.0 * UNIT)
		look = ((get_local_mouse_position() - head) / (UNIT * 3.0)).limit_length(1.0)
	for eye in EYES:
		var shape := eye
		shape.position += look
		if closed:
			shape = Rect2(shape.position.x - 0.25, shape.get_center().y, 1.5, 0.4)
		elif state == Pet.State.GLARE:
			# Narrowed: only the lower half stays open.
			shape = Rect2(shape.position.x - 0.2, shape.position.y + 1.0, 1.4, 1.0)
		elif wide:
			shape = shape.grow(0.3)
		_block(shape, body_offset, EYE)


## Broom held in front, three strokes over the floor, with dust.
func _draw_broom() -> void:
	var stroke := sin(_pet.state_time / Pet.TIMED[Pet.State.SWEEP] * TAU * 3.0)
	var x := 8.6 + stroke * 1.4
	_blocks([
		[Rect2(x, -7.5, 0.4, 6.5), WOOD], [Rect2(x - 0.9, -1.3, 2.2, 1.3), STRAW],
		[Rect2(x + 2.0 * signf(stroke), -1.0 - absf(stroke), 0.6, 0.6), SMOKE],
		[Rect2(x + 3.0 * signf(stroke), -0.6 - absf(stroke) * 1.8, 0.5, 0.5), SMOKE],
	], Vector2.ZERO, true)


## Mailbox beside the pet, with the number of letters when more than one waits.
func _draw_mailbox() -> void:
	var side := _pet.mailbox_side()
	for entry: Array in MAILBOX:
		var shape: Rect2 = entry[0]
		if side > 0.0:
			shape.position.x = -shape.end.x
		_block(shape, Vector2.ZERO, entry[1])
	if _pet.mail > 1 and not _pet.discreet:
		_draw_tag(str(_pet.mail), GROUND + Vector2(side * MAILBOX_X, MAILBOX_TAG_Y) * UNIT, HEART)


## Signs that circle the pet, behind it then in front. Draws those of one
## half of the circle: the back half goes under the pet, the front half over it.
func _draw_mantra(body_offset: Vector2, in_front: bool) -> void:
	var center := GROUND + body_offset + Vector2(0, -6.0 * UNIT)
	for i in MANTRA.size():
		var angle := _time * 1.1 + TAU * i / MANTRA.size()
		if (sin(angle) >= 0.0) != in_front:
			continue
		var at := center + Vector2(cos(angle) * 9.5 * UNIT, sin(angle) * 2.2 * UNIT)
		# Smaller and paler at the back of the circle.
		var depth := sin(angle) * 0.5 + 0.5
		draw_string(_font, at, MANTRA[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 + depth * 7), Color(GOLD, 0.45 + depth * 0.55))


## Pile of folders carried on the back arm.
func _draw_baggage(body_offset: Vector2) -> void:
	for i in _pet.baggage:
		var folder := Rect2(-8.8, -7.3 - i * 1.4, 2.8, 1.2)
		_blocks([[folder, MANILA], [Rect2(folder.position.x, folder.position.y - 0.3, 1.2, 0.3), MANILA.darkened(0.2)]], body_offset, true)


## Fire in front of the pet, and a marshmallow on a stick that browns.
func _draw_campfire(body_offset: Vector2) -> void:
	var flames: Array[Array] = [[Rect2(CAMPFIRE_X - 1.5, -0.8, 3.6, 0.8), WOOD]]
	for i in 3:
		var height := 1.4 + absf(sin(_time * 7.0 + i * 2.1)) * 1.6
		flames.append([Rect2(CAMPFIRE_X - 1.1 + i, -0.8 - height, 1, height), FLAME if i != 1 else GOLD])
	_blocks(flames, Vector2.ZERO, true)
	var done := minf(_pet.state_time / Pet.TIMED[Pet.State.ROAST], 1.0)
	_blocks([
		[Rect2(7.5, -6.2, CAMPFIRE_X - 7.2, 0.3), WOOD],
		[Rect2(CAMPFIRE_X - 0.1, -6.8, 1.3, 1.3), PAPER.lerp(WOOD, done * 0.8)],
	], body_offset, true)


## Hourglass on the ground in front of the pet. The sand runs down, then the
## hourglass turns over and it runs again.
func _draw_hourglass() -> void:
	var moment := fmod(_time, HOURGLASS_RUN + HOURGLASS_TURN)
	var run := minf(moment / HOURGLASS_RUN, 1.0)
	var turn := maxf(moment - HOURGLASS_RUN, 0.0) / HOURGLASS_TURN
	var center := GROUND + Vector2(HOURGLASS_X * signf(_pet.facing), -HOURGLASS_HALF - 0.5) * UNIT
	# Drawn around its middle, so that it turns on itself. Upside down it looks
	# the same, with the sand back at the top.
	draw_set_transform(center, turn * PI)
	var row := HOURGLASS_HALF / HOURGLASS_ROWS.size()
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(Vector2(-1.8, side * (HOURGLASS_HALF + 0.25) - 0.25) * UNIT, Vector2(3.6, 0.5) * UNIT), WOOD)
		# Sand left in the top bulb, against the neck. Sand fallen in the bottom
		# one, against the base. Height from the middle, in grid units.
		var sand := Vector2(0.0, (1.0 - run) * HOURGLASS_HALF) if side < 0.0 else Vector2((1.0 - run) * HOURGLASS_HALF, HOURGLASS_HALF)
		for i in HOURGLASS_ROWS.size():
			var half_width := HOURGLASS_ROWS[i]
			var from := i * row
			_draw_band(side, from, from + row, half_width, Color(PAPER, 0.85))
			_draw_band(side, maxf(from, sand.x), minf(from + row, sand.y), half_width, GOLD)
	if run > 0.0 and run < 1.0:
		# The thread of sand that falls.
		draw_rect(Rect2(Vector2(-0.1, 0.0) * UNIT, Vector2(0.2, (1.0 - run) * HOURGLASS_HALF) * UNIT), GOLD)
	draw_set_transform(Vector2.ZERO)


## Band of a bulb of the hourglass, between two heights from its middle, in
## grid units. side: -1 for the top bulb, 1 for the bottom one.
func _draw_band(side: float, from: float, to: float, half_width: float, color: Color) -> void:
	if to > from:
		draw_rect(Rect2(Vector2(-half_width, from if side > 0.0 else -to) * UNIT, Vector2(half_width * 2.0, to - from) * UNIT), color)


func _draw_smoke(body_top: Vector2) -> void:
	for i in 4:
		var phase := fmod(_time * 0.5 + i / 4.0, 1.0)
		var size := (0.7 + phase * 0.9) * UNIT
		var at := body_top + Vector2((i - 1.5) * 16.0 + sin(_time * 2.0 + i * 1.3) * 5.0, -4.0 - phase * 34.0)
		draw_rect(Rect2(at - Vector2(size, size) / 2.0, Vector2(size, size)), Color(SMOKE, sin(phase * PI) * 0.8))


func _draw_snore(from: Vector2) -> void:
	for i in 3:
		var phase := fmod(_time * 0.4 + i / 3.0, 1.0)
		var at := from + Vector2(-10.0 + phase * 20.0, -6.0 - phase * 45.0)
		draw_string(_font, at, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 + phase * 12), Color(_pet.color.darkened(0.2), sin(phase * PI)))


func _draw_hearts(body_top: Vector2) -> void:
	for i in 3:
		var phase := fmod(_time * 0.9 + i / 3.0, 1.0)
		var center := body_top + Vector2((i - 1) * 40.0 + sin(_time * 4.0 + i) * 4.0, -16.0 - phase * 36.0)
		_draw_pixels(HEART_ROWS, HEART_PIXEL, center, Color(HEART, sin(phase * PI)))


## One note at a time, that rises beside the head: right, then left.
func _draw_note(body_top: Vector2) -> void:
	var phase := fmod(_time * 0.5, 1.0)
	var side := 1.0 if int(_time * 0.5) % 2 == 0 else -1.0
	var center := body_top + Vector2(side * (BODY.end.x + 2.5) * UNIT + sin(_time * 3.0) * 3.0, -phase * 26.0)
	_draw_pixels(NOTE_ROWS, NOTE_PIXEL, center, Color(_pet.color.darkened(0.2), sin(phase * PI)))


## Fills the "X" of the rows with squares of the given size, around a center.
func _draw_pixels(rows: PackedStringArray, pixel: float, center: Vector2, color: Color) -> void:
	var size := Vector2(rows[0].length(), rows.size()) * pixel
	for row in rows.size():
		for column in rows[row].length():
			if rows[row][column] == "X":
				draw_rect(Rect2(center - size / 2.0 + Vector2(column, row) * pixel, Vector2.ONE * pixel), color)


## Small copy of the mascot, one per running subagent. A new one runs from the
## big pet to its spot, with the sheet of paper it was handed.
func _draw_mini(index: int) -> void:
	var arrived := minf((_time - _mini_born[index]) / MINI_RUN_SECONDS, 1.0)
	var spot := MINI_SPOTS[index] * arrived
	var pace := 5.0 if arrived >= 1.0 else 16.0
	var bob := Vector2(0, -absf(sin(_time * pace + index * 1.7)) * 3.0 / MINI_SCALE)
	draw_set_transform(GROUND + spot, 0.0, Vector2.ONE * MINI_SCALE)
	var shapes: Array[Rect2] = [BODY, ARMS[0], ARMS[1]]
	for column in LEG_COLUMNS:
		shapes.append(Rect2(column, -LEG_HEIGHT, 1, LEG_HEIGHT))
	for shape in shapes:
		draw_rect(Rect2(shape.position * UNIT + bob, shape.size * UNIT), _pet.color.lightened(0.15))
	for eye in EYES:
		draw_rect(Rect2(eye.position * UNIT + bob, eye.size * UNIT), EYE)
	if arrived < 1.0:
		draw_rect(Rect2(Vector2(-3, -15) * UNIT + bob, Vector2(6, 4) * UNIT), PAPER)
	draw_set_transform(Vector2.ZERO)


## Dark tag with light text on several lines, standing on its bottom middle point.
func _draw_caption(text: String, bottom_center: Vector2) -> void:
	if text.is_empty():
		return
	var text_size := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, CAPTION_WIDTH, TAG_FONT_SIZE)
	var box := Rect2(bottom_center - Vector2(text_size.x / 2.0 + 5.0, text_size.y + 2.0), text_size + Vector2(10, 2))
	draw_rect(box, EYE)
	draw_rect(Rect2(box.position, Vector2(4, box.size.y)), _pet.color)
	var baseline := box.position + Vector2(7, 1 + _font.get_ascent(TAG_FONT_SIZE))
	draw_multiline_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, CAPTION_WIDTH, TAG_FONT_SIZE, -1, PAPER)


## Small dark tag with light text, centered on its top middle point.
func _draw_tag(text: String, top_center: Vector2, edge: Color) -> void:
	if text.is_empty():
		return
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT_SIZE)
	var box := Rect2(top_center.x - text_size.x / 2.0 - 5.0, top_center.y, text_size.x + 10.0, text_size.y + 2.0)
	draw_rect(box, EYE)
	draw_rect(Rect2(box.position, Vector2(4, box.size.y)), edge)
	var baseline := box.position + Vector2(7, 1 + _font.get_ascent(TAG_FONT_SIZE))
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT_SIZE, PAPER)


## Fills a shape given in grid units.
func _block(shape: Rect2, offset: Vector2, color: Color) -> void:
	draw_rect(Rect2(GROUND + shape.position * UNIT + offset, shape.size * UNIT), color)


## Fills a list of [shape, color]. Shapes are given for a pet that faces right.
## sided: mirror them when the pet faces left.
func _blocks(list: Array, offset: Vector2, sided: bool) -> void:
	for entry: Array in list:
		var shape: Rect2 = entry[0]
		if sided and _pet.facing < 0.0:
			shape.position.x = -shape.end.x
		_block(shape, offset, entry[1])
