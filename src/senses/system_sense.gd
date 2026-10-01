extends Node
## Posts: cpu_hot {celsius}, battery_low {percent}.
## Reads Linux sysfs. On other systems the files do not exist and this sense
## stays silent.

const POLL_SECONDS := 30.0
const HOT_CELSIUS := 92.0
const LOW_BATTERY_PERCENT := 15
## Seconds before the same alert is posted again.
const REPEAT_SECONDS := 600.0
const THERMAL := "/sys/class/thermal"
const POWER := "/sys/class/power_supply"

## Event -> time of its last post, in seconds.
var _posted := {}


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = POLL_SECONDS
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)


func _poll() -> void:
	var hottest := 0.0
	for zone in DirAccess.get_directories_at(THERMAL):
		# Millidegrees.
		hottest = maxf(hottest, _read(THERMAL.path_join(zone).path_join("temp")).to_float() / 1000.0)
	if hottest >= HOT_CELSIUS:
		_post(&"cpu_hot", {"celsius": roundi(hottest)})

	for supply in DirAccess.get_directories_at(POWER):
		var folder := POWER.path_join(supply)
		if _read(folder.path_join("type")) != "Battery" or _read(folder.path_join("status")) != "Discharging":
			continue
		var percent := _read(folder.path_join("capacity")).to_int()
		if percent <= LOW_BATTERY_PERCENT:
			_post(&"battery_low", {"percent": percent})


func _post(event: StringName, data: Dictionary) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _posted.get(event, -REPEAT_SECONDS) >= REPEAT_SECONDS:
		_posted[event] = now
		Events.post(event, data)


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path).strip_edges()
