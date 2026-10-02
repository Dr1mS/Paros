extends Node
## Root of the main scene. Chores of the start.


func _enter_tree() -> void:
	# This start only hands over to its copy (see input_method.gd): build
	# nothing, so that no window shows before it leaves.
	if InputMethod.leaving:
		for child in get_children():
			child.free()


func _ready() -> void:
	if not InputMethod.leaving:
		Autostart.refresh()
