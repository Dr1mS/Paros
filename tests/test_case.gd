extends Node
## Base of a test file. Every method whose name starts with "test_" is a test.
## A test fails when one of its checks fails.

## Floor and walls given to the pets of the tests.
const AREA := Rect2(0, 0, 2000, 800)

var failures: PackedStringArray = []

var _events: Array = []


## Runs before each test.
func before_each() -> void:
	pass


## Runs after each test.
func after_each() -> void:
	pass


func check(condition: bool, what: String) -> void:
	if not condition:
		failures.append(what)


func check_equal(actual: Variant, wanted: Variant, what: String) -> void:
	if actual != wanted:
		failures.append("%s: got %s, wanted %s" % [what, actual, wanted])


func check_near(actual: float, wanted: float, margin: float, what: String) -> void:
	if absf(actual - wanted) > margin:
		failures.append("%s: got %s, wanted %s within %s" % [what, actual, wanted, margin])


## Starts recording the events posted on the bus.
func record_events() -> void:
	_events.clear()
	if not Events.sensed.is_connected(_on_sensed):
		Events.sensed.connect(_on_sensed)


## Names of the events recorded so far.
func event_names() -> Array:
	return _events.map(func(event: Array) -> StringName: return event[0])


## Data of the last recorded event of the given name. Empty: none recorded.
func last_event(event: StringName) -> Dictionary:
	for i in range(_events.size() - 1, -1, -1):
		if _events[i][0] == event:
			return _events[i][1]
	return {}


## A pet in its window, standing still on the floor of AREA. Nothing moves by
## itself: the test advances the time with step().
func make_pet(parent: Node = self) -> Pet:
	var window: Window = load("res://src/pet/pet_window.tscn").instantiate()
	parent.add_child(window)
	var pet: Pet = window.get_node("Pet")
	freeze(pet)
	return pet


## Stops the pet from moving by itself, and puts it on the floor of AREA.
func freeze(pet: Pet) -> void:
	for node: Node in [pet, pet.get_node("Body"), pet.get_node("../Bubble")]:
		node.set_process(false)
	pet._area = AREA
	# Never read the real screens again.
	pet._area_age = -INF
	pet._window_pos = Vector2(500, AREA.end.y)
	stand(pet)


## Puts the pet in the idle state, with nothing planned for a long time.
func stand(pet: Pet) -> void:
	pet._enter(Pet.State.IDLE)
	pet._timer = 999.0
	pet._wants_perch = false


## Advances the pet by the given time, in small steps.
func step(pet: Pet, seconds: float, tick := 0.05) -> void:
	for i in roundi(seconds / tick):
		pet._process(tick)


func _on_sensed(event: StringName, data: Dictionary) -> void:
	_events.append([event, data])
