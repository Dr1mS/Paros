extends PopupMenu
## Right-click menu. Only way to quit: the window has no title bar.

enum Item { LOCATE, FOCUS, SETTINGS, QUIT }

@export var pet: Pet


func _ready() -> void:
	id_pressed.connect(_on_id_pressed)
	Events.sensed.connect(_on_sensed)


func _on_sensed(event: StringName, data: Dictionary) -> void:
	if event == &"pointer_menu" and data.pet == pet:
		_fill()
		position = DisplayServer.mouse_get_position()
		popup()


# Filled at each opening: the entries depend on the pet and on the focus timer.
func _fill() -> void:
	clear()
	if not pet.key.is_empty():
		add_item("Faire sonner son terminal", Item.LOCATE)
	match Focus.phase:
		Focus.Phase.OFF:
			add_item("Démarrer un focus (%d min)" % Settings.value("focus", "minutes"), Item.FOCUS)
		Focus.Phase.FOCUS:
			add_item("Arrêter le focus (reste %d min)" % Focus.minutes_left(), Item.FOCUS)
		Focus.Phase.BREAK:
			add_item("Arrêter la pause (reste %d min)" % Focus.minutes_left(), Item.FOCUS)
	add_separator()
	add_item("Réglages…", Item.SETTINGS)
	add_item("Quitter", Item.QUIT)


func _on_id_pressed(id: int) -> void:
	match id:
		Item.LOCATE:
			Events.post(&"locate_requested", {"pet": pet})
		Item.FOCUS:
			Focus.toggle()
		Item.SETTINGS:
			Events.post(&"settings_requested")
		Item.QUIT:
			get_tree().quit()
