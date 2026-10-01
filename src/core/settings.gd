extends Node
## User settings, stored in user://settings.cfg. Missing keys are written back
## with their default, so the file always lists every option.

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"pet": {
		"size": 1.0, "walk_speed": 70.0, "show_name": true, "accessories": true, "greetings": true,
		"tower": true, "headlamp": true,
	},
	"sound": {"enabled": true, "volume": 50},
	"sleep": {"night_start_hour": 23, "night_end_hour": 7, "idle_minutes": 5.0},
	"bubble": {"enabled": true, "seconds": 4.0},
	"claude": {"show_activity": true, "nag_minutes": 2.0, "context_window_k": 1000, "knock": true},
	"git": {"enabled": true},
	"desktop": {"perch": true, "cuddle": true, "leave_fullscreen": true, "lock_screen_minutes": 10.0},
	"focus": {"minutes": 25.0, "break_minutes": 5.0},
	"system": {"alerts": true},
}

var _config := ConfigFile.new()


func _init() -> void:
	_config.load(PATH)
	for section: String in DEFAULTS:
		for key: String in DEFAULTS[section]:
			if not _config.has_section_key(section, key):
				_config.set_value(section, key, DEFAULTS[section][key])
	_config.save(PATH)


func value(section: String, key: String) -> Variant:
	return _config.get_value(section, key, DEFAULTS[section][key])


## Saves at once. The value takes the type of the default.
func set_value(section: String, key: String, new_value: Variant) -> void:
	_config.set_value(section, key, type_convert(new_value, typeof(DEFAULTS[section][key])))
	_config.save(PATH)
	changed.emit()
