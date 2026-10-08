extends "res://tests/test_case.gd"
## The state machine of one pet: orders, short acts, flight, errands, perch.

var pet: Pet


func before_each() -> void:
	pet = make_pet()


func test_obeys_the_wish_when_idle() -> void:
	pet.wish = Pet.Wish.THINK
	step(pet, 0.1)
	check_equal(pet.state, Pet.State.THINK, "thinks")
	pet.wish = Pet.Wish.ALERT
	step(pet, 0.2)
	check_equal(pet.state, Pet.State.ALERT, "alerts after passing by idle")
	pet.wish = Pet.Wish.ROAM
	step(pet, 0.1)
	check_equal(pet.state, Pet.State.IDLE, "back to idle")


func test_stretches_when_it_wakes_up() -> void:
	pet.wish = Pet.Wish.SLEEP
	step(pet, 0.1)
	check_equal(pet.state, Pet.State.SLEEP, "sleeps")
	pet.wish = Pet.Wish.ROAM
	step(pet, 0.1)
	check_equal(pet.state, Pet.State.STRETCH, "stretches first")
	step(pet, Pet.TIMED[Pet.State.STRETCH] + 0.1)
	check_equal(pet.state, Pet.State.IDLE, "then stands")


func test_short_acts_end_by_themselves() -> void:
	var acts := {
		Pet.State.CHEER: pet.cheer, Pet.State.WORRY: pet.worry, Pet.State.ROAST: pet.roast,
		Pet.State.SWEEP: pet.sweep, Pet.State.GLARE: pet.glare.bind(1.0), Pet.State.HIGH_FIVE: pet.high_five.bind(1.0),
	}
	for act: Pet.State in acts:
		stand(pet)
		acts[act].call()
		check_equal(pet.state, act, "starts %s" % Pet.State.keys()[act])
		step(pet, Pet.TIMED[act] + 0.1)
		check_equal(pet.state, Pet.State.IDLE, "%s is over" % Pet.State.keys()[act])


func test_walks_away_after_a_greeting() -> void:
	pet.greet(1.0)
	step(pet, Pet.TIMED[Pet.State.GREET] + 0.1)
	check_equal(pet.state, Pet.State.WALK, "walks")
	check_equal(pet.facing, -1.0, "away from the other pet")


func test_no_act_in_the_air() -> void:
	pet.grab()
	pet.cheer()
	check_equal(pet.state, Pet.State.CARRIED, "still carried")


func test_falls_to_the_floor_when_released() -> void:
	pet.grab()
	pet._window_pos = Vector2(500, AREA.end.y - 200)
	pet._velocity = Vector2.ZERO
	pet.release()
	check_equal(pet.state, Pet.State.FALL, "falls")
	step(pet, 2.0, 0.01)
	check_equal(pet.state, Pet.State.IDLE, "landed")
	check_equal(pet._window_pos.y, AREA.end.y, "on the floor")
	check(not pet.umbrella, "no umbrella for a short fall")


func test_bounces_after_a_hard_landing() -> void:
	pet._window_pos = Vector2(500, AREA.end.y - 5)
	pet._velocity = Vector2(0, 900)
	pet._enter(Pet.State.FALL)
	step(pet, 0.05, 0.01)
	check_equal(pet.state, Pet.State.FALL, "still in flight")
	check(pet._velocity.y < 0.0, "going up again")


func test_bounces_off_the_walls() -> void:
	pet._window_pos = Vector2(AREA.end.x - 5, AREA.end.y - 300)
	pet._velocity = Vector2(800, 0)
	pet._enter(Pet.State.FALL)
	step(pet, 0.1, 0.01)
	check(pet._velocity.x < 0.0, "sent back by the right wall")


func test_opens_the_umbrella_on_a_long_fall() -> void:
	pet._window_pos = Vector2(500, AREA.end.y - 600)
	pet._velocity = Vector2.ZERO
	pet._enter(Pet.State.FALL)
	step(pet, 0.5, 0.01)
	check(pet.umbrella, "umbrella open")
	check(pet._velocity.y <= Pet.UMBRELLA_SPEED, "fall slowed down")
	step(pet, 5.0, 0.01)
	check_equal(pet.state, Pet.State.IDLE, "landed softly, no bounce")
	check(not pet.umbrella, "umbrella closed")


func test_posts_a_landing_after_a_fast_fall() -> void:
	record_events()
	pet._window_pos = Vector2(500, AREA.end.y - 5)
	pet._velocity = Vector2(0, 900)
	pet._enter(Pet.State.FALL)
	step(pet, 0.05, 0.01)
	check(&"pet_landed" in event_names(), "landing posted")


func test_errand_reaches_its_target_whatever_the_wish() -> void:
	var target := pet.feet().x + 200.0
	pet.walk_to(target)
	pet.wish = Pet.Wish.SLEEP
	step(pet, 1.0)
	check_equal(pet.state, Pet.State.WALK, "keeps walking")
	step(pet, 5.0)
	check_near(pet.feet().x, target, 1.0, "arrived")
	check_equal(pet.state, Pet.State.SLEEP, "then obeys the wish")


func test_knocks_at_the_end_of_the_run() -> void:
	record_events()
	pet.knock_at(pet.feet().x - 150.0, -1.0)
	step(pet, 0.5)
	check_equal(pet.state, Pet.State.WALK, "runs first")
	step(pet, 1.0)
	check_equal(pet.state, Pet.State.KNOCK, "knocks")
	check_equal(pet.facing, -1.0, "faces the edge")
	check(&"pet_knocked" in event_names(), "knock posted")


func test_baggage_slows_the_walk() -> void:
	var loaded := make_pet()
	loaded.baggage = 3
	for walker: Pet in [pet, loaded]:
		walker.walk_to(walker.feet().x + 1000.0)
		step(walker, 1.0)
	var light: float = pet.feet().x - 650.0
	var heavy: float = loaded.feet().x - 650.0
	check_near(heavy / light, 1.0 - 3 * Pet.BAGGAGE_DRAG, 0.02, "speed with three folders")


func test_pace_changes_the_speed() -> void:
	var fast := make_pet()
	fast.pace = 1.6
	for walker: Pet in [pet, fast]:
		walker.walk_to(walker.feet().x + 1000.0)
		step(walker, 1.0)
	check_near((fast.feet().x - 650.0) / (pet.feet().x - 650.0), 1.6, 0.02, "speed ratio")


func test_rooted_pet_sits_and_stays() -> void:
	pet.rooted = true
	pet._timer = 0.0
	step(pet, 30.0)
	check_equal(pet.state, Pet.State.SIT, "sits")
	check_equal(pet._window_pos.x, 500.0, "did not move")
	check(not pet.is_free(), "not free for a meeting")


func test_climbs_onto_an_edge_and_falls_when_it_goes() -> void:
	var edge := Rect2(400, 300, 600, 0)
	pet.climb_onto(edge)
	check_equal(pet.state, Pet.State.CLIMB, "jumps")
	while pet.state == Pet.State.CLIMB:
		step(pet, 0.05)
	pet._wants_perch = false
	check(pet.is_perched(), "on the edge")
	check_equal(pet.feet().y, 300.0, "feet on the edge")
	pet.walk_to(900.0)
	check_equal(pet.state, Pet.State.IDLE, "no errand from a perch")

	pet.perch = Rect2()
	check(not pet.is_perched(), "edge gone")
	step(pet, 0.05)
	check_equal(pet.state, Pet.State.FALL, "falls")
	step(pet, 6.0, 0.01)
	check_equal(pet._window_pos.y, AREA.end.y, "back on the floor")


func test_same_edge_again_keeps_the_pet_on_it() -> void:
	pet.climb_onto(Rect2(400, 300, 600, 0))
	while pet.state == Pet.State.CLIMB:
		step(pet, 0.05)
	pet.perch = Rect2(400, 300, 600, 0)
	check(pet.is_perched(), "still on the edge")


func test_calm_and_lively_states() -> void:
	check(not pet.is_lively(), "idle is calm")
	pet.hovered = true
	check(pet.is_lively(), "hovered is lively")
	pet.hovered = false
	pet.cheer()
	check(pet.is_lively(), "cheering is lively")


func test_discreet_pet_shows_no_text() -> void:
	var bubble: Bubble = pet.get_node("../Bubble")
	pet.say("hello")
	check_equal(bubble._message, "hello", "speaks")
	pet.discreet = true
	check_equal(bubble._message, "", "hushed at once")
	pet.say("again")
	pet.show_card("card")
	check_equal(bubble._message, "", "no message")
	check_equal(bubble.card, "", "no card")


func test_keeps_its_area_when_every_screen_is_covered() -> void:
	pet.avoid = [Rect2(-100000, -100000, 200000, 200000)]
	check(pet._free_screens().is_empty(), "no screen left")
	check_equal(pet._walk_area(), AREA, "keeps its last area")
	pet._area_age = Pet.AREA_REFRESH_SECONDS
	step(pet, 0.1)
	check(pet._hidden, "hidden meanwhile")


func test_throws_then_reads_a_letter() -> void:
	pet.throw_letter(-1.0)
	check_equal(pet.state, Pet.State.THROW, "throws")
	check_equal(pet.facing, -1.0, "toward the other pet")
	step(pet, Pet.TIMED[Pet.State.THROW] + 0.1)
	check_equal(pet.state, Pet.State.IDLE, "done")
	pet.read_letter()
	check_equal(pet.state, Pet.State.READ, "reads")
	step(pet, Pet.TIMED[Pet.State.READ] + 0.1)
	check_equal(pet.state, Pet.State.IDLE, "done")


func test_mailbox_stands_where_the_ground_goes_on() -> void:
	check_equal(pet.mailbox_side(), -1.0, "on the left")
	pet._window_pos.x = AREA.position.x
	check_equal(pet.mailbox_side(), 1.0, "on the right at the left end of the ground")


func test_nods_and_looks_toward_a_point() -> void:
	pet.nod()
	check_equal(pet.state, Pet.State.NOD, "nods")
	pet.look_toward(pet.feet().x - 300.0)
	check_equal(pet.facing, 1.0, "does not turn in the middle of an act")
	step(pet, Pet.TIMED[Pet.State.NOD] + 0.1)
	check_equal(pet.state, Pet.State.IDLE, "done")
	pet.look_toward(pet.feet().x - 300.0)
	check_equal(pet.facing, -1.0, "turns while it stays in place")


func test_jump_lands_back() -> void:
	var pet := make_pet()
	var floor_y := pet.feet().y
	pet.jump()
	step(pet, 0.1)
	check(pet.is_airborne() and pet.feet().y < floor_y - 10.0, "off the ground")
	record_events()
	step(pet, 2.0)
	check_equal(pet.state, Pet.State.IDLE, "landed")
	check_near(pet.feet().y, floor_y, 0.5, "on the floor")
	check(&"pet_landed" not in event_names(), "without a thud")


func test_pet_hurries_back_to_its_zone() -> void:
	var pet := make_pet()
	pet.home_x = pet.feet().x + 600.0
	pet.home_reach = 100.0
	step(pet, 0.1)
	check_equal(pet.state, Pet.State.WALK, "walks at once")
	step(pet, 20.0)
	check(absf(pet.feet().x - pet.home_x) <= 101.0, "back in its zone")
	pet._timer = 0.0
	pet._enter(Pet.State.WALK)
	step(pet, 30.0)
	check(absf(pet.feet().x - pet.home_x) <= 101.0, "and stays there")


func test_small_pet_is_clicked_on_its_small_body() -> void:
	var window: Window = load("res://src/pet/pet_window.tscn").instantiate()
	var pet: Pet = window.get_node("Pet")
	add_child(window)
	pet.stature = 0.4
	freeze(pet)
	pet._window.position = Vector2i(pet._window_pos)
	check(pet.hit_test(pet.feet() - Vector2(0, 20)), "on the body")
	check(not pet.hit_test(pet.feet() - Vector2(0, 60)), "not above it, where a normal pet has its head")
	check_near(pet.scale_factor(), 0.4 * Settings.value("pet", "size"), 0.001, "distances follow the body")
	check_equal(pet.get_node("../Bubble").anchor.y > Bubble.ANCHOR.y, true, "the bubble comes down to its head")
