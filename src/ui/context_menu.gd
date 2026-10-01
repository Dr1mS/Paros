extends PopupMenu
## Right-click menu. Only way to quit: the window has no title bar.

enum Item { SETTINGS, QUIT }

@export var pet: Pet


func _ready() -> void:
	add_item("Réglages…", Item.SETTINGS)
	add_item("Quitter", Item.QUIT)
	id_pressed.connect(_on_id_pressed)
	Events.sensed.connect(_on_sensed)


func _on_sensed(event: StringName, data: Dictionary) -> void:
	if event == &"pointer_menu" and data.pet == pet:
		position = DisplayServer.mouse_get_position()
		popup()


func _on_id_pressed(id: int) -> void:
	match id:
		Item.SETTINGS:
			Events.post(&"settings_requested")
		Item.QUIT:
			get_tree().quit()
