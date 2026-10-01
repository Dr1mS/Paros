extends PopupMenu
## Right-click menu. Only way to quit: the window has no title bar.

enum Item { GO, LOCATE, FOCUS, SETTINGS, QUIT }

@export var pet: Pet


func _ready() -> void:
	# The entries are translated when the menu is filled, not again when shown.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
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
		add_item(tr("Go to its terminal"), Item.GO)
		add_item(tr("Ring its terminal"), Item.LOCATE)
	match Focus.phase:
		Focus.Phase.OFF:
			add_item(tr("Start a focus (%d min)") % Settings.value("focus", "minutes"), Item.FOCUS)
		Focus.Phase.FOCUS:
			add_item(tr("Stop the focus (%d min left)") % Focus.minutes_left(), Item.FOCUS)
		Focus.Phase.BREAK:
			add_item(tr("Stop the break (%d min left)") % Focus.minutes_left(), Item.FOCUS)
	add_separator()
	add_item(tr("Settings…"), Item.SETTINGS)
	add_item(tr("Quit"), Item.QUIT)


func _on_id_pressed(id: int) -> void:
	match id:
		Item.GO:
			Events.post(&"pointer_double", {"pet": pet})
		Item.LOCATE:
			Events.post(&"locate_requested", {"pet": pet})
		Item.FOCUS:
			Focus.toggle()
		Item.SETTINGS:
			Events.post(&"settings_requested")
		Item.QUIT:
			get_tree().quit()
