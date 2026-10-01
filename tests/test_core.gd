extends "res://tests/test_case.gd"
## Settings, focus timer, sound, bubble, autostart, desktop helpers.


func test_settings_keep_the_type_of_the_default() -> void:
	Settings.set_value("sleep", "night_start_hour", 21.0)
	check_equal(typeof(Settings.value("sleep", "night_start_hour")), TYPE_INT, "whole number")
	Settings.set_value("pet", "size", 2)
	check_equal(typeof(Settings.value("pet", "size")), TYPE_FLOAT, "decimal number")
	Settings.set_value("sleep", "night_start_hour", 23)
	Settings.set_value("pet", "size", 1.0)


func test_settings_tell_when_they_change() -> void:
	var told := [0]
	var listener := func() -> void: told[0] += 1
	Settings.changed.connect(listener)
	Settings.set_value("bubble", "seconds", 4.0)
	Settings.changed.disconnect(listener)
	check_equal(told[0], 1, "told once")


func test_every_setting_of_the_window_exists() -> void:
	var window: Window = load("res://src/ui/settings_window.gd").new()
	window.visible = false
	add_child(window)
	for field: Array in window.FIELDS:
		if field.size() > 1:
			check(Settings.DEFAULTS.get(field[0], {}).has(field[1]), "%s/%s has a default" % [field[0], field[1]])
	var shown: int = window.FIELDS.filter(func(field: Array) -> bool: return field.size() > 1).size()
	var known := 0
	for section: String in Settings.DEFAULTS:
		known += Settings.DEFAULTS[section].size()
	check_equal(shown, known, "every setting is in the window")


func test_focus_then_break_then_off() -> void:
	record_events()
	Focus.toggle()
	check_equal(Focus.phase, Focus.Phase.FOCUS, "focus")
	check_equal(Focus.minutes_left(), 25, "25 minutes")
	Focus._ends_at = 0.0
	Focus._process(0.1)
	check_equal(Focus.phase, Focus.Phase.BREAK, "break")
	check_equal(Focus.minutes_left(), 5, "5 minutes")
	Focus._ends_at = 0.0
	Focus._process(0.1)
	check_equal(Focus.phase, Focus.Phase.OFF, "off")
	check_equal(event_names(), [&"focus_started", &"focus_finished", &"break_finished"], "three events")


func test_focus_stops_on_demand() -> void:
	Focus.toggle()
	Focus.toggle()
	check_equal(Focus.phase, Focus.Phase.OFF, "stopped")


func test_tune_samples() -> void:
	var samples := Sound.synthesize(&"success")
	check_equal(samples.size(), int(0.09 * Sound.RATE) + int(0.16 * Sound.RATE), "length of the two notes")
	var loudest := 0.0
	for sample in samples:
		loudest = maxf(loudest, absf(sample))
	check(loudest > 0.0 and loudest <= Sound.LEVEL, "audible, under the level")
	Settings.set_value("sound", "volume", 0)
	check(Array(Sound.synthesize(&"knock")).all(func(sample: float) -> bool: return sample == 0.0), "silent at volume 0")
	Settings.set_value("sound", "volume", 50)


func test_wav_file() -> void:
	var samples := PackedFloat32Array([0.0, 1.0, -1.0, 2.0])
	var wav := Sound.to_wav(samples)
	check_equal(wav.size(), 44 + 8, "header plus two bytes per sample")
	check_equal(wav.slice(0, 4).get_string_from_ascii(), "RIFF", "RIFF")
	check_equal(wav.slice(8, 16).get_string_from_ascii(), "WAVEfmt ", "WAVE, format block")
	check_equal(wav.decode_u32(24), Sound.RATE, "sample rate")
	check_equal(wav.decode_u32(40), 8, "data size")
	check_equal(wav.decode_s16(46), 32767, "full scale")
	check_equal(wav.decode_s16(48), -32767, "negative full scale")
	check_equal(wav.decode_s16(50), 32767, "too loud is clipped")


func test_bubble_message_hides_the_card() -> void:
	var pet := make_pet()
	var bubble: Bubble = pet.get_node("../Bubble")
	bubble.card = "card"
	bubble.say("message")
	check_equal(bubble._message, "message", "message up")
	bubble.set_process(true)
	bubble._process(Settings.value("bubble", "seconds") + 0.1)
	check_equal(bubble._message, "", "message over")
	check_equal(bubble.card, "card", "card still there")
	Settings.set_value("bubble", "enabled", false)
	bubble.say("again")
	Settings.set_value("bubble", "enabled", true)
	check_equal(bubble._message, "", "nothing said when bubbles are off")


func test_body_draws_again_when_the_pet_changes() -> void:
	var pet := make_pet()
	var body: Node2D = pet.get_node("Body")
	var before: int = body._look()
	pet.caption = "Edit · pet.gd"
	check(body._look() != before, "a new caption is a new picture")
	check_equal(body.ACCESSORIES.size(), Pet.ACCESSORY_COUNT, "accessory count")


func test_autostart_file() -> void:
	if not Autostart.is_supported():
		return
	check(not Autostart.is_enabled(), "off at first")
	Autostart.set_enabled(true)
	check(Autostart.is_enabled(), "on")
	check("Exec=" in FileAccess.get_file_as_string(Autostart._path()), "has a command")
	Autostart.set_enabled(false)
	check(not Autostart.is_enabled(), "off again")


func test_process_lineage() -> void:
	if OS.get_name() != "Linux":
		return
	var lineage := Desktop.lineage(OS.get_process_id())
	check_equal(lineage[0], OS.get_process_id(), "starts with the process")
	check(lineage.size() > 1, "then its parents")
	check_equal(Desktop.lineage(0), [], "no process, no lineage")
	check(" " in Desktop.read_proc("/proc/loadavg"), "proc files are read")


func test_interface_language() -> void:
	check_equal(tr("Task done!"), "Task done!", "English as written")
	Settings.set_value("interface", "language", "fr")
	check_equal(tr("Task done!"), "Tâche finie !", "French")
	check_equal(tr("Focus: %d min") % 25, "Focus : 25 min", "French with a number")
	Settings.set_value("interface", "language", "en")
	check_equal(tr("Quit"), "Quit", "back to English")


func test_every_label_of_the_settings_has_a_french_text() -> void:
	var window: Window = load("res://src/ui/settings_window.gd").new()
	window.visible = false
	add_child(window)
	# Same word in both languages.
	var shared := ["Volume", "Claude Code", "Focus"]
	for field: Array in window.FIELDS:
		var label: String = field[0] if field.size() == 1 else field[2]
		check(Language.FRENCH.has(label) or label in shared, "\"%s\" is translated" % label)


func test_french_texts_keep_their_placeholders() -> void:
	var placeholder := RegEx.create_from_string("%[0-9]*[ds%]")
	for text: String in Language.FRENCH:
		var english := placeholder.search_all(text).map(func(found: RegExMatch) -> String: return found.get_string())
		var french := placeholder.search_all(Language.FRENCH[text]).map(func(found: RegExMatch) -> String: return found.get_string())
		check_equal(french, english, "placeholders of \"%s\"" % text)
