extends Node
## Event bus between senses and the brain. Senses post, the brain listens.
## Neither side knows the other, so a sense can be added or removed alone.

signal sensed(event: StringName, data: Dictionary)


func post(event: StringName, data: Dictionary = {}) -> void:
	sensed.emit(event, data)
