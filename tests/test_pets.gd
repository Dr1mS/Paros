extends "res://tests/test_case.gd"
## What takes two pets: meetings, shared celebrations, room to be seen. And
## the frame rate.

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
	a.dispute = "/work/pet.gd"
	b.dispute = "/work/pet.gd"
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


## Makes the pets that hide each other do so for a long time already.
func wait_crowded() -> void:
	pets._process(0.016)
	for pair: Array in pets._crowded:
		pets._crowded[pair] -= Pets.CROWD_SECONDS


func test_hidden_pet_steps_aside() -> void:
	for pet: Pet in [a, b]:
		pet.wish = Pet.Wish.THINK
	b._window_pos.x = a._window_pos.x + 10.0
	pets._process(0.016)
	check_equal([a.state, b.state], [Pet.State.IDLE, Pet.State.IDLE], "allowed for a moment")
	wait_crowded()
	pets._process(0.016)
	check_equal([a.state, b.state], [Pet.State.WALK, Pet.State.IDLE], "then one walks away")
	step(a, 6.0)
	check_near(b.feet().x - a.feet().x, Pets.CROWD_GAP, 1.0, "far enough to be seen, on its side")
	a.wish = Pet.Wish.ROAM
	stand(a)
	pets._process(0.016)
	check(pets._crowded.is_empty(), "no longer hidden")


func test_the_less_busy_pet_steps_aside() -> void:
	a.wish = Pet.Wish.ALERT
	b.wish = Pet.Wish.THINK
	b._window_pos.x = a._window_pos.x + 10.0
	wait_crowded()
	pets._process(0.016)
	check_equal([a.state, b.state], [Pet.State.IDLE, Pet.State.WALK], "the one that thinks, not the one that calls")


func test_steps_to_the_other_side_at_the_edge() -> void:
	for pet: Pet in [a, b]:
		pet.wish = Pet.Wish.THINK
	a._window_pos.x = a._area.position.x
	b._window_pos.x = a._window_pos.x + 10.0
	wait_crowded()
	pets._process(0.016)
	step(a, 6.0)
	check_near(a.feet().x - b.feet().x, Pets.CROWD_GAP, 1.0, "no room on the left: goes right")


func test_pets_far_apart_or_in_a_tower_stay() -> void:
	for pet: Pet in [a, b]:
		pet.wish = Pet.Wish.THINK
	b._window_pos.x = a._window_pos.x + 200.0
	pets._process(0.016)
	check(pets._crowded.is_empty(), "far apart")
	b._window_pos.x = a._window_pos.x
	a.rooted = true
	pets._process(0.016)
	check(pets._crowded.is_empty(), "in a tower")


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


## Advances the letters by the given time, in small steps.
func fly(seconds: float) -> void:
	for i in roundi(seconds / 0.05):
		for letter in pets._letters:
			letter._process(0.05)


func test_letter_flies_from_a_pet_to_another() -> void:
	record_events()
	pets.send_letter(a, b)
	var letter := pets._letters[0]
	check_equal(a.state, Pet.State.THROW, "a throws")
	check_equal(a.facing, 1.0, "toward b")
	check_equal(letter.recipient(), b, "in flight to b")
	pets._process(0.016)
	check_equal(Engine.max_fps, Pets.LIVELY_FPS, "smooth frames for the flight")
	fly(Letter.SECONDS_RANGE.y + 0.1)
	check_equal(last_event(&"letter_landed").get("pet"), b, "landed at b")
	check(not letter.is_flying(), "at rest")
	check_equal(letter.get_window().position, Pet.HIDING_PLACE, "parked off screen")
	pets.send_letter(b, a)
	check_equal(pets._letters.size(), 1, "the same letter serves again")
	pets.send_letter(b, a)
	check_equal(pets._letters.size(), 2, "a second one while the first flies")


func test_letter_to_a_removed_pet_is_dropped() -> void:
	record_events()
	pets.send_letter(a, b)
	pets.remove("b")
	check(not pets._letters[0].is_flying(), "flight ended")
	fly(Letter.SECONDS_RANGE.y + 0.1)
	check(&"letter_landed" not in event_names(), "no landing")
