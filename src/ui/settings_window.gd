extends Window
## Settings dialog, opened from the right-click menu. Every change applies and
## saves at once.

## Section, key, label, then for numbers: minimum, maximum, step, unit.
const FIELDS := [
	["pet", "size", "Taille", 0.5, 3.0, 0.1, "×"],
	["pet", "walk_speed", "Vitesse de marche", 10.0, 300.0, 5.0, "px/s"],
	["pet", "show_name", "Afficher le nom de session"],
	["bubble", "enabled", "Afficher les bulles"],
	["bubble", "seconds", "Durée des bulles", 1.0, 30.0, 0.5, "s"],
	["sleep", "night_start_hour", "Début de la nuit", 0, 23, 1, "h"],
	["sleep", "night_end_hour", "Fin de la nuit", 0, 23, 1, "h"],
	["sleep", "idle_minutes", "Sommeil après inactivité", 1.0, 120.0, 1.0, "min"],
]
const MARGIN := 18

var _panel := PanelContainer.new()
var _autostart := CheckBox.new()


func _ready() -> void:
	title = "Paros — Réglages"
	close_requested.connect(hide)
	Events.sensed.connect(_on_sensed)

	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	_panel.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	margin.add_child(grid)

	for field: Array in FIELDS:
		_add_row(grid, field[2], _editor(field))
	if Autostart.is_supported():
		_autostart.toggled.connect(Autostart.set_enabled)
		_add_row(grid, "Lancer au démarrage", _autostart)


func _on_sensed(event: StringName, _data: Dictionary) -> void:
	if event == &"settings_requested":
		_autostart.set_pressed_no_signal(Autostart.is_enabled())
		size = Vector2i(_panel.get_combined_minimum_size())
		show()
		grab_focus()


func _add_row(grid: GridContainer, text: String, editor: Control) -> void:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	editor.size_flags_horizontal = Control.SIZE_SHRINK_END
	grid.add_child(editor)


## Check box for a yes/no setting, number box for the others.
func _editor(field: Array) -> Control:
	var section: String = field[0]
	var key: String = field[1]
	var current: Variant = Settings.value(section, key)
	var save := func(new_value: Variant) -> void: Settings.set_value(section, key, new_value)
	if current is bool:
		var check := CheckBox.new()
		check.button_pressed = current
		check.toggled.connect(save)
		return check
	var box := SpinBox.new()
	box.min_value = field[3]
	box.max_value = field[4]
	box.step = field[5]
	box.suffix = field[6]
	box.value = current
	box.value_changed.connect(save)
	return box
