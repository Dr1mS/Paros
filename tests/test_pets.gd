extends "res://tests/test_case.gd"
## What takes two pets: meetings, shared celebrations. And the frame rate.

var pets: Pets
var a: Pet
var b: Pet


func before_each() -> void:
	pets = Pets.new()
	add_child(pets)
	pets.set_process(false)
	a = pets.add("a")
	b = pets.add("b")
	for pet: Pet in [a, b]:
		freeze(pet)
	b._window_pos.x = a._window_pos.x + 100.0


func test_finds_and_removes_by_key() -> void:
	check_equal(pets.find("a"), a, "found")
	check_equal(a.key, "a", "the pet knows its key")
	pets.remove("a")
	check_equal(pets.find("a"), null, "gone")
	check_equal(pets.keys(), ["b"], "one left")


func test_two_free_pets_greet_once() -> void:
	pets._process(0.016)
	check_equal(a.state, Pet.State.GREET, "a greets")
	check_equal(b.state, Pet.State.GREET, "b greets")
	check_equal([a.facing, b.facing], [1.0, -1.0], "face to face")
	stand(a)
	stand(b)
	pets._process(0.016)
	check_equal(a.state, Pet.State.IDLE, "not twice in a row")


func test_rivals_glare() -> void:
	a.repo = "/work@main"
	b.repo = "/work@main"
	pets._process(0.016)
	check_equal([a.state, b.state], [Pet.State.GLARE, Pet.State.GLARE], "glare")


func test_no_meeting_when_far_or_busy() -> void:
	b._window_pos.x = a._window_pos.x + 400.0
	pets._process(0.016)
	check_equal(a.state, Pet.State.IDLE, "too far")
	b._window_pos.x = a._window_pos.x + 100.0
	b.wish = Pet.Wish.THINK
	pets._process(0.016)
	check_equal(a.state, Pet.State.IDLE, "b is busy")


func test_no_meeting_when_the_setting_is_off() -> void:
	Settings.set_value("pet", "greetings", false)
	pets._process(0.016)
	check_equal(a.state, Pet.State.IDLE, "no greeting")
	Settings.set_value("pet", "greetings", true)


func test_two_close_successes_make_a_high_five() -> void:
	pets.celebrate(a)
	check_equal(a.state, Pet.State.IDLE, "alone: nothing")
	pets.celebrate(b)
	check_equal([a.state, b.state], [Pet.State.HIGH_FIVE, Pet.State.HIGH_FIVE], "high five")


func test_no_high_five_from_afar() -> void:
	b._window_pos.x = a._window_pos.x + 600.0
	pets.celebrate(a)
	pets.celebrate(b)
	check_equal(b.state, Pet.State.IDLE, "too far")


func test_frame_rate_follows_the_pets() -> void:
	Settings.set_value("pet", "greetings", false)
	pets._process(0.016)
	check_equal(Engine.max_fps, Pets.CALM_FPS, "calm")
	a.cheer()
	pets._process(0.016)
	check_equal(Engine.max_fps, Pets.LIVELY_FPS, "lively")
	pets.unseen = true
	pets._process(0.016)
	check_equal(Engine.max_fps, Pets.UNSEEN_FPS, "unseen")
	Settings.set_value("pet", "greetings", true)
