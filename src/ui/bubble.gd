class_name Bubble
extends Node2D
## Speech bubble above the mascot. Shows one short text for a few seconds.

const MAX_TEXT_WIDTH := 250.0
const PADDING := Vector2(10, 7)
const FONT_SIZE := 14
const BORDER := 3.0
const TAIL := 8.0
## Tip of the tail, in window coordinates: above the head, clear of the cheer hop.
const ANCHOR := Vector2(150, 132)

const PAPER := Color("#fffdf8")
const INK := Color("#1f1e1d")

var _text := ""
var _seconds_left := 0.0

@onready var _font := ThemeDB.fallback_font


func say(text: String) -> void:
	if not Settings.value("bubble", "enabled"):
		return
	_text = text
	_seconds_left = Settings.value("bubble", "seconds")
	queue_redraw()


func _process(delta: float) -> void:
	if _seconds_left <= 0.0:
		return
	_seconds_left -= delta
	if _seconds_left <= 0.0:
		_text = ""
		queue_redraw()


func _draw() -> void:
	if _text.is_empty():
		return
	var text_size := _font.get_multiline_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, MAX_TEXT_WIDTH, FONT_SIZE)
	var box := Rect2(Vector2.ZERO, text_size + PADDING * 2.0)
	box.position = (ANCHOR - Vector2(box.size.x / 2.0, box.size.y + BORDER + TAIL)).round()
	draw_rect(Rect2(ANCHOR.x - TAIL / 2.0, box.end.y, TAIL, BORDER + TAIL), INK)
	draw_rect(box.grow(BORDER), INK)
	draw_rect(box, PAPER)
	var baseline := box.position + PADDING + Vector2(0, _font.get_ascent(FONT_SIZE))
	draw_multiline_string(_font, baseline, _text, HORIZONTAL_ALIGNMENT_LEFT, MAX_TEXT_WIDTH, FONT_SIZE, -1, INK)
