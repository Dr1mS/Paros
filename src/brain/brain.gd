extends Node
## Turns sensed events into pet behavior. All rules live here.
## One pet per Claude Code session. With no session, one pet with no name.

## Key of the pet shown when no session exists.
const NO_SESSION := ""
## Claude Code session colors (/color).
const COLORS := {
	"red": Color("#e5484d"),
	"blue": Color("#4a90e2"),
	"green": Color("#46a758"),
	"yellow": Color("#e2b93b"),
	"purple": Color("#8e6fd8"),
	"orange": Color("#f08c3a"),
	"pink": Color("#e86aa6"),
	"cyan": Color("#3bb8c4"),
}

@export var pets: Pets

var _night := false
var _user_idle := false
## Session id -> &"idle", &"working" or &"waiting".
var _phases := {}


func _ready() -> void:
	Events.sensed.connect(_on_sensed)
	pets.add(NO_SESSION)


func _on_sensed(event: StringName, data: Dictionary) -> void:
	match event:
		&"pointer_tap":
			data.pet.cheer()
		&"pointer_grab":
			data.pet.grab()
		&"pointer_drop":
			data.pet.release()
		&"night":
			_night = true
		&"day":
			_night = false
		&"user_idle":
			_user_idle = true
		&"user_active":
			_user_idle = false
		&"session_opened":
			pets.remove(NO_SESSION)
			_dress(pets.add(data.session), data)
		&"session_changed":
			_dress(pets.find(data.session), data)
		&"session_closed":
			pets.remove(data.session)
			_phases.erase(data.session)
			if pets.keys().is_empty():
				pets.add(NO_SESSION)
		&"session_phase":
			_phases[data.session] = data.phase
		&"session_finished":
			pets.find(data.session).cheer()
			pets.find(data.session).say("Tâche finie !")
		&"session_needs_you":
			pets.find(data.session).say("Claude attend ta réponse")
	for key: String in pets.keys():
		pets.find(key).wish = _wish(_phases.get(key, &"idle"))


func _dress(pet: Pet, data: Dictionary) -> void:
	pet.label = data.name
	pet.color = COLORS.get(data.color, Pet.DEFAULT_COLOR)


## Highest priority first.
func _wish(phase: StringName) -> Pet.Wish:
	if phase == &"waiting":
		return Pet.Wish.ALERT
	if phase == &"working":
		return Pet.Wish.THINK
	if _night or _user_idle:
		return Pet.Wish.SLEEP
	return Pet.Wish.ROAM
