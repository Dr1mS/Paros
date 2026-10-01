class_name Bubble
extends Node2D
## Speech bubble above the mascot. A message shows for a few seconds.
## A card shows as long as it is set and no message is up.

const MAX_TEXT_WIDTH := 264.0
const PADDING := Vector2(10, 7)
const MESSAGE_FONT_SIZE := 14
const CARD_FONT_SIZE := 12
const BORDER := 3.0
const TAIL := 8.0
## Tip of the tail, in window coordinates: above the head, clear of the cheer hop.
const ANCHOR := Vector2(150, 132)

const PAPER := Color("#fffdf8")
const INK := Color("#1f1e1d")

## Text shown while no message is up. Empty: none.
var card := "":
	set(text):
		card = text
		queue_redraw()

var _message := ""
var _seconds_left := 0.0

@onready var _font := ThemeDB.fallback_font


func say(text: String) -> void:
	if not Settings.value("bubble", "enabled"):
		return
	_message = text
	_seconds_left = Settings.value("bubble", "seconds")
	queue_redraw()


## Removes what is shown at once.
func hush() -> void:
	_message = ""
	_seconds_left = 0.0
	card = ""


func _process(delta: float) -> void:
	if _seconds_left <= 0.0:
		return
	_seconds_left -= delta
	if _seconds_left <= 0.0:
		_message = ""
		queue_redraw()


func _draw() -> void:
	var text := card if _message.is_empty() else _message
	if text.is_empty():
		return
	var font_size := CARD_FONT_SIZE if _message.is_empty() else MESSAGE_FONT_SIZE
	var text_size := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, MAX_TEXT_WIDTH, font_size)
	var box := Rect2(Vector2.ZERO, text_size + PADDING * 2.0)
	box.position = (ANCHOR - Vector2(box.size.x / 2.0, box.size.y + BORDER + TAIL)).round()
	# A tall card would leave the window by the top: let it cover the head instead.
	box.position.y = maxf(box.position.y, BORDER)
	draw_rect(Rect2(ANCHOR.x - TAIL / 2.0, box.end.y, TAIL, BORDER + TAIL), INK)
	draw_rect(box.grow(BORDER), INK)
	draw_rect(box, PAPER)
	var baseline := box.position + PADDING + Vector2(0, _font.get_ascent(font_size))
	draw_multiline_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, MAX_TEXT_WIDTH, font_size, -1, INK)
