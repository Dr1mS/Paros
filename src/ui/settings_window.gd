extends Window
## Settings dialog, opened from the right-click menu. Every change applies and
## saves at once.

## One entry: a heading. Else: section, key, label, then for numbers: minimum,
## maximum, step, unit.
const FIELDS := [
	["Personnage"],
	["pet", "size", "Taille", 0.5, 3.0, 0.1, "×"],
	["pet", "walk_speed", "Vitesse de marche", 10.0, 300.0, 5.0, "px/s"],
	["pet", "show_name", "Afficher le nom de session"],
	["pet", "accessories", "Accessoires"],
	["pet", "greetings", "Les personnages se saluent"],
	["pet", "tower", "Tour des sessions au repos"],
	["pet", "headlamp", "Lampe frontale la nuit"],
	["Sons"],
	["sound", "enabled", "Activer les sons"],
	["sound", "volume", "Volume", 0, 100, 5, "%"],
	["Bulles"],
	["bubble", "enabled", "Afficher les bulles"],
	["bubble", "seconds", "Durée des bulles", 1.0, 30.0, 0.5, "s"],
	["Claude Code"],
	["claude", "show_activity", "Afficher l'outil en cours"],
	["claude", "nag_minutes", "Insister après une attente de", 0.5, 60.0, 0.5, "min"],
	["claude", "knock", "Toquer quand le terminal n'a pas le focus"],
	["claude", "context_window_k", "Contexte du modèle, en milliers de tokens", 100, 2000, 100, "k"],
	["git", "enabled", "Suivre l'état git des dossiers"],
	["Bureau (extension GNOME)"],
	["desktop", "perch", "Grimper sur la fenêtre active"],
	["desktop", "cuddle", "Dormir contre le curseur immobile"],
	["desktop", "leave_fullscreen", "Quitter l'écran d'une app en plein écran"],
	["desktop", "lock_screen_minutes", "Écran allumé après verrouillage", 0.0, 240.0, 1.0, "min"],
	["Sommeil"],
	["sleep", "night_start_hour", "Début de la nuit", 0, 23, 1, "h"],
	["sleep", "night_end_hour", "Fin de la nuit", 0, 23, 1, "h"],
	["sleep", "idle_minutes", "Sommeil après inactivité", 1.0, 120.0, 1.0, "min"],
	["Focus"],
	["focus", "minutes", "Durée d'un focus", 1.0, 120.0, 1.0, "min"],
	["focus", "break_minutes", "Durée d'une pause", 1.0, 60.0, 1.0, "min"],
	["Système"],
	["system", "alerts", "Alertes batterie et température"],
]
const MARGIN := 18
const HEADING := Color("#d97757")
## Tallest the window gets, as a share of the usable screen height. Past it,
## the settings scroll.
const MAX_SCREEN_SHARE := 0.8

var _scroll := ScrollContainer.new()
var _content := MarginContainer.new()
var _autostart := CheckBox.new()


func _ready() -> void:
	title = "Paros — Réglages"
	add_to_group(Pets.SMOOTH_GROUP)
	close_requested.connect(hide)
	Events.sensed.connect(_on_sensed)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	for side: String in ["left", "top", "right", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, MARGIN)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)

	for field: Array in FIELDS:
		if field.size() == 1:
			_add_heading(grid, field[0])
		else:
			_add_row(grid, field[2], _editor(field))
	if Autostart.is_supported():
		_autostart.toggled.connect(Autostart.set_enabled)
		_add_row(grid, "Lancer au démarrage", _autostart)


func _on_sensed(event: StringName, _data: Dictionary) -> void:
	if event == &"settings_requested":
		_autostart.set_pressed_no_signal(Autostart.is_enabled())
		_fit_screen()
		show()
		grab_focus()


## As tall as the settings, up to a share of the screen. Then they scroll, and
## the window widens by the scroll bar.
func _fit_screen() -> void:
	var wanted := _content.get_combined_minimum_size()
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_WITH_MOUSE_FOCUS)
	var tallest := screen.size.y * MAX_SCREEN_SHARE
	if wanted.y > tallest:
		wanted = Vector2(wanted.x + _scroll.get_v_scroll_bar().get_combined_minimum_size().x, tallest)
	size = Vector2i(wanted)


func _add_heading(grid: GridContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADING)
	grid.add_child(label)
	# Fills the second column of the row.
	grid.add_child(Control.new())


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
