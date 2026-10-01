extends Node
## Pomodoro timer: a focus period, then a break, then off.
## Posts: focus_started, focus_finished, break_finished.

enum Phase { OFF, FOCUS, BREAK }

var phase := Phase.OFF

var _ends_at := 0.0


func _process(_delta: float) -> void:
	if phase == Phase.OFF or _now() < _ends_at:
		return
	if phase == Phase.FOCUS:
		_begin(Phase.BREAK, Settings.value("focus", "break_minutes"))
		Events.post(&"focus_finished")
	else:
		phase = Phase.OFF
		Events.post(&"break_finished")


## Starts a focus period, or stops the running period.
func toggle() -> void:
	if phase != Phase.OFF:
		phase = Phase.OFF
		return
	_begin(Phase.FOCUS, Settings.value("focus", "minutes"))
	Events.post(&"focus_started")


func minutes_left() -> int:
	return ceili(maxf(_ends_at - _now(), 0.0) / 60.0)


func _begin(next: Phase, minutes: float) -> void:
	phase = next
	_ends_at = _now() + minutes * 60.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
