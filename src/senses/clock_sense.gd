extends Node
## Posts: night, day. Posts once at start, then on each change.

const CHECK_SECONDS := 60.0

var _was_night := false


func _ready() -> void:
	_was_night = _is_night()
	Events.post(&"night" if _was_night else &"day")
	var timer := Timer.new()
	timer.wait_time = CHECK_SECONDS
	timer.autostart = true
	timer.timeout.connect(_check)
	add_child(timer)
	Settings.changed.connect(_check)


func _check() -> void:
	var night := _is_night()
	if night != _was_night:
		_was_night = night
		Events.post(&"night" if night else &"day")


func _is_night() -> bool:
	var hour: int = Time.get_time_dict_from_system().hour
	var start: int = Settings.value("sleep", "night_start_hour")
	var end: int = Settings.value("sleep", "night_end_hour")
	# The night may or may not span midnight.
	if start > end:
		return hour >= start or hour < end
	return hour >= start and hour < end
