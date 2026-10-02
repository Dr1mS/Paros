extends "res://tests/test_case.gd"
## The rules: what each sensed event does to the pets.

var pets: Pets
var brain: Node


func before_each() -> void:
	pets = Pets.new()
	add_child(pets)
	pets.set_process(false)
	brain = load("res://src/brain/brain.gd").new()
	brain.pets = pets
	add_child(brain)


func after_each() -> void:
	Events.post(&"day")
	Focus.phase = Focus.Phase.OFF
	DisplayServer.screen_set_keep_on(false)


## Opens a session and returns its pet, standing still.
func open(session: String, name := "Alpha", color := "") -> Pet:
	Events.post(&"session_opened", {
		"session": session, "name": name, "color": color, "cwd": "/work/" + name, "last_prompt": "", "pid": 0, "context": 0,
	})
	var pet := pets.find(session)
	freeze(pet)
	return pet


func set_phase(session: String, phase: StringName, seconds_ago := 0.0) -> void:
	Events.post(&"session_phase", {"session": session, "phase": phase, "since": Time.get_unix_time_from_system() - seconds_ago})


func test_one_unnamed_pet_without_session() -> void:
	check_equal(pets.keys(), [""], "one pet")
	check_equal(pets.find("").label, "", "no name")


func test_one_pet_per_session() -> void:
	var first := open("s1", "Alpha", "red")
	check_equal(pets.keys(), ["s1"], "the unnamed pet left")
	check_equal(first.label, "Alpha", "named after the session")
	check_equal(first.color, brain.COLORS["red"], "colored after the session")
	open("s2", "Beta")
	check_equal(pets.keys().size(), 2, "two pets")
	check_equal(pets.find("s2").color, Pet.DEFAULT_COLOR, "default color")
	Events.post(&"session_closed", {"session": "s1"})
	Events.post(&"session_closed", {"session": "s2"})
	check_equal(pets.keys(), [""], "the unnamed pet is back")


func test_rename_and_recolor() -> void:
	var pet := open("s1")
	Events.post(&"session_changed", {
		"session": "s1", "name": "Gamma", "color": "blue", "cwd": "/work/Alpha", "last_prompt": "", "pid": 0, "context": 0,
	})
	check_equal(pet.label, "Gamma", "new name")
	check_equal(pet.color, brain.COLORS["blue"], "new color")


func test_phase_sets_the_wish() -> void:
	var pet := open("s1")
	set_phase("s1", &"working")
	check_equal(pet.wish, Pet.Wish.THINK, "working")
	set_phase("s1", &"waiting")
	check_equal(pet.wish, Pet.Wish.ALERT, "waiting")
	set_phase("s1", &"idle")
	check_equal(pet.wish, Pet.Wish.ROAM, "idle")


func test_sleeps_at_night_unless_busy() -> void:
	var resting := open("s1")
	var busy := open("s2", "Beta")
	set_phase("s2", &"working")
	Events.post(&"night")
	check_equal(resting.wish, Pet.Wish.SLEEP, "resting session sleeps")
	check_equal(busy.wish, Pet.Wish.THINK, "busy session thinks")
	Events.post(&"day")
	check_equal(resting.wish, Pet.Wish.ROAM, "awake by day")


func test_sleeps_when_the_user_is_away_but_not_on_the_lock_screen() -> void:
	var pet := open("s1")
	Events.post(&"user_idle")
	check_equal(pet.wish, Pet.Wish.SLEEP, "user away")
	Events.post(&"screen_locked", {"locked": true})
	check_equal(pet.wish, Pet.Wish.ROAM, "stays up to be seen")
	check(pet.discreet, "no text on the lock screen")
	check(brain._screen_held, "screen held on")
	check(not pets.unseen, "seen")
	Events.post(&"screen_locked", {"locked": false})
	check(not pet.discreet, "text is back")
	check(not brain._screen_held, "screen released")
	Events.post(&"user_active")
	check_equal(pet.wish, Pet.Wish.ROAM, "user back")


func test_unseen_once_the_screen_hold_is_over() -> void:
	open("s1")
	Events.post(&"screen_locked", {"locked": true})
	brain._screen_held_until = 0.0
	brain._tick()
	check(pets.unseen, "nobody watches")
	check(not brain._screen_held, "screen released")


func test_repo_state_dresses_the_pet() -> void:
	var pet := open("s1")
	for case: Array in [[0, 0], [1, 1], [60, 2], [400, 3]]:
		Events.post(&"repo_state", {"session": "s1", "branch": "main", "dirty": case[0], "behind": 0, "conflict": false})
		check_equal(pet.baggage, case[1], "baggage for %d lines" % case[0])
	check_equal(pet.label, "Alpha · main", "branch in the name tag")
	check_equal(pet.dispute, "", "same folder and branch as nobody: no rival")
	check(not pet.hard_hat and not pet.lost, "nothing special")
	Events.post(&"repo_state", {"session": "s1", "branch": "main", "dirty": 0, "behind": 2, "conflict": true})
	check(pet.hard_hat, "hard hat during a merge")
	check(pet.lost, "lost when behind")


func test_context_fills_the_head() -> void:
	var pet := open("s1")
	Events.post(&"session_changed", {
		"session": "s1", "name": "Alpha", "color": "", "cwd": "/work/Alpha", "last_prompt": "", "pid": 0, "context": 800000,
	})
	check_near(pet.fullness, 0.8, 0.001, "800 k tokens of 1000 k")


func test_quiet_work_taps_then_meditates() -> void:
	var pet := open("s1")
	set_phase("s1", &"working")
	Events.post(&"session_quiet", {"session": "s1", "level": 1})
	check(pet.tapping and not pet.meditating, "taps its foot")
	Events.post(&"session_quiet", {"session": "s1", "level": 2})
	check(pet.meditating and not pet.tapping, "meditates")
	Events.post(&"session_quiet", {"session": "s1", "level": 0})
	check(not pet.meditating and not pet.tapping, "back to plain thinking")


func test_activity_shows_while_working_only() -> void:
	var pet := open("s1")
	set_phase("s1", &"working")
	Events.post(&"session_activity", {"session": "s1", "tool": "Edit", "detail": "pet.gd"})
	check_equal(pet.caption, "Edit · pet.gd", "caption")
	Events.post(&"session_activity", {"session": "s1", "tool": "Glob", "detail": ""})
	check_equal(pet.caption, "Glob", "tool alone")
	set_phase("s1", &"idle")
	check_equal(pet.caption, "", "cleared at rest")


func test_subagents_show_as_small_pets() -> void:
	var pet := open("s1")
	Events.post(&"session_subagents", {"session": "s1", "count": 3})
	check_equal(pet.minis, 3, "three small pets")


func test_reactions_to_results() -> void:
	var pet := open("s1")
	Events.post(&"session_tests_passed", {"session": "s1"})
	check_equal(pet.state, Pet.State.CHEER, "cheers for green tests")
	stand(pet)
	Events.post(&"session_tool_failed", {"session": "s1", "tool": "Bash", "detail": "", "kind": ""})
	check_equal(pet.state, Pet.State.WORRY, "worries on a failure")
	stand(pet)
	Events.post(&"session_finished", {"session": "s1"})
	check_equal(pet.state, Pet.State.CHEER, "cheers at the end of a turn")
	stand(pet)
	Events.post(&"repo_cleaned", {"session": "s1"})
	check_equal(pet.state, Pet.State.SWEEP, "sweeps after a clean commit")
	check(pet.cool, "sunglasses")


func test_hot_machine_lights_the_campfire() -> void:
	var pet := open("s1")
	Events.post(&"cpu_hot")
	check_equal(pet.state, Pet.State.ROAST, "roasts")
	stand(pet)
	Settings.set_value("system", "alerts", false)
	Events.post(&"cpu_hot")
	Settings.set_value("system", "alerts", true)
	check_equal(pet.state, Pet.State.IDLE, "not when alerts are off")


func test_pace_follows_the_load() -> void:
	var pet := open("s1")
	Events.post(&"system_load", {"load": 0.0})
	check_near(pet.pace, brain.PACE_RANGE.x, 0.001, "strolls")
	Events.post(&"system_load", {"load": 2.0})
	check_near(pet.pace, brain.PACE_RANGE.y, 0.001, "trots, and no faster")


func test_headlamp_at_night() -> void:
	var pet := open("s1")
	set_phase("s1", &"working")
	Events.post(&"night")
	check(pet.headlamp, "lamp on")
	Events.post(&"day")
	check(not pet.headlamp, "lamp off")


func test_turn_that_leaves_a_task_running_is_a_wait() -> void:
	var pet := open("s1")
	set_phase("s1", &"working")
	Events.post(&"session_background", {"session": "s1", "background": 1})
	check_equal(pet.wish, Pet.Wish.THINK, "still thinks while it works")
	set_phase("s1", &"idle", 200.0)
	Events.post(&"session_finished", {"session": "s1"})
	check_equal(pet.state, Pet.State.IDLE, "no cheer: not done")
	check_equal(pet.wish, Pet.Wish.WAIT, "waits")
	check(not brain._rests(pet), "not at rest for the tower")
	pet.hovered = true
	brain._refresh()
	check("background task" in pet.get_node("../Bubble").card, "the card says so")
	Events.post(&"session_background", {"session": "s1", "background": 0})
	check_equal(pet.wish, Pet.Wish.ROAM, "the task ended")
	Events.post(&"session_finished", {"session": "s1"})
	check_equal(pet.state, Pet.State.CHEER, "done for good")


func test_grooves_to_the_music() -> void:
	var pet := open("s1")
	Events.post(&"music", {"playing": true})
	check(pet.grooving, "grooves while a player plays")
	Settings.set_value("pet", "groove", false)
	check(not pet.grooving, "not when the setting is off")
	Settings.set_value("pet", "groove", true)
	Events.post(&"music", {"playing": false})
	check(not pet.grooving, "stops with the music")


func test_leaves_covered_screens() -> void:
	var pet := open("s1")
	var screen := Rect2(0, 0, 1920, 1080)
	var covered: Array[Rect2] = [screen]
	Events.post(&"desktop_state", {"active": screen, "fullscreen": true, "pid": 7, "covered": covered})
	check_equal(pet.avoid, covered, "keeps off the covered screen")
	check_equal(pet.perch, Rect2(), "no perch on a full screen window")
	Settings.set_value("desktop", "leave_fullscreen", false)
	check_equal(pet.avoid.size(), 0, "not when the setting is off")
	Settings.set_value("desktop", "leave_fullscreen", true)


func test_active_window_is_a_perch() -> void:
	var pet := open("s1")
	var window := Rect2(100, 200, 800, 600)
	var none: Array[Rect2] = []
	Events.post(&"desktop_state", {"active": window, "fullscreen": false, "pid": 7, "covered": none})
	check_equal(pet.perch, window, "may stand on the focused window")


func test_long_wait_gets_a_reminder() -> void:
	var pet := open("s1")
	set_phase("s1", &"waiting", 200.0)
	brain._tick()
	check(pet.urgent, "urgent after two minutes")
	set_phase("s1", &"working")
	check(not pet.urgent, "calm again")


func test_knocks_when_the_terminal_is_not_focused() -> void:
	var pet := open("s1")
	set_phase("s1", &"waiting", 30.0)
	brain._sessions["s1"].unfocused_since = Time.get_unix_time_from_system() - 30.0
	brain._tick()
	check(pet.state in [Pet.State.WALK, Pet.State.KNOCK], "goes to knock")
	var first: float = brain._sessions["s1"].knocked
	stand(pet)
	brain._sessions["s1"].unfocused_since = Time.get_unix_time_from_system() - 30.0
	brain._tick()
	check_equal(brain._sessions["s1"].knocked, first, "not again before the repeat time")


func test_no_knock_when_the_terminal_is_focused() -> void:
	var pet := open("s1")
	brain._sessions["s1"].lineage = [4242] as Array[int]
	var none: Array[Rect2] = []
	Events.post(&"desktop_state", {"active": Rect2(), "fullscreen": false, "pid": 4242, "covered": none})
	set_phase("s1", &"waiting", 300.0)
	brain._sessions["s1"].unfocused_since = 0.0
	brain._tick()
	check_equal(pet.state, Pet.State.IDLE, "stays where it is")
	check(not pet.urgent, "no reminder either")


func test_resting_sessions_build_a_tower_that_a_prompt_brings_down() -> void:
	var base := open("s1")
	var top := open("s2", "Beta")
	set_phase("s1", &"idle", 200.0)
	set_phase("s2", &"idle", 200.0)
	brain._grow_tower()
	check_equal(brain._tower.size(), 2, "tower of two")
	check(base.rooted, "the first one is the base")
	check(not top.is_free(), "the second one is on its way")
	set_phase("s2", &"working")
	brain._grow_tower()
	check_equal(brain._tower.size(), 0, "tower down")
	check(not base.rooted, "base freed")


func test_no_tower_for_a_session_that_just_stopped() -> void:
	open("s1")
	open("s2", "Beta")
	set_phase("s1", &"idle", 200.0)
	set_phase("s2", &"idle", 5.0)
	brain._grow_tower()
	check_equal(brain._tower.size(), 0, "one pet is not a tower")


func test_nearest_pet_sleeps_by_the_still_pointer() -> void:
	var near := open("s1")
	var far := open("s2", "Beta")
	far._window_pos.x = near._window_pos.x + 900.0
	Events.post(&"pointer_idle", {"position": Vector2(near.feet().x + 200.0, 500)})
	check_equal(near.wish, Pet.Wish.SLEEP, "the nearest one goes to sleep there")
	check_equal(near.state, Pet.State.WALK, "after walking to the pointer")
	check_equal(far.wish, Pet.Wish.ROAM, "the other one roams")
	Events.post(&"pointer_moved")
	check_equal(near.wish, Pet.Wish.ROAM, "wakes when the pointer moves")


func test_focus_messages_reach_every_pet() -> void:
	var pet := open("s1")
	Events.post(&"focus_finished")
	check_equal(pet.state, Pet.State.CHEER, "cheers for the break")
	check(pet.get_node("../Bubble")._message.begins_with("Break!"), "says so")


func test_dropped_files_go_to_the_clipboard() -> void:
	var pet := open("s1")
	Events.post(&"files_dropped", {"pet": pet, "files": PackedStringArray(["/tmp/a b.png", "/tmp/c.log"])})
	check(pet.get_node("../Bubble")._message.begins_with("Path copied"), "says so")
	# No clipboard without a display.
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		check_equal(DisplayServer.clipboard_get(), "'/tmp/a b.png' '/tmp/c.log'", "quoted paths")


func test_card_shows_while_hovered() -> void:
	var pet := open("s1")
	set_phase("s1", &"working", 125.0)
	Events.post(&"session_activity", {"session": "s1", "tool": "Edit", "detail": "pet.gd"})
	pet.hovered = true
	Events.post(&"pointer_enter", {"pet": pet})
	var card: String = pet.get_node("../Bubble").card
	check("/work/Alpha" in card, "folder")
	check("Working for 2 min" in card, "phase and its duration")
	check("Edit · pet.gd" in card, "tool in use")
	pet.hovered = false
	Events.post(&"pointer_leave", {"pet": pet})
	check_equal(pet.get_node("../Bubble").card, "", "gone when the mouse leaves")


func test_message_between_sessions_is_a_letter() -> void:
	var sender := open("s1", "Alpha")
	var reader := open("s2", "Beta")
	set_phase("s2", &"working")
	Events.post(&"session_message_sent", {"session": "s1", "to": "Beta [1a2b3c]"})
	check_equal(sender.state, Pet.State.THROW, "the sender throws")
	var letter := pets._letters[0]
	check_equal(letter.recipient(), reader, "the letter flies to the pet of that name")
	Events.post(&"session_mail", {"session": "s2", "mail": 1})
	check_equal(reader.mail, 0, "not in the mailbox while it flies")
	letter._process(Letter.SECONDS_RANGE.y)
	check_equal(reader.mail, 1, "in the mailbox once landed")
	check_equal(reader.state, Pet.State.IDLE, "not read: the session is busy")
	reader.hovered = true
	brain._refresh()
	check("Letters to read: 1" in reader.get_node("../Bubble").card, "the card says so")
	Events.post(&"session_mail", {"session": "s2", "mail": 0})
	check_equal(reader.mail, 0, "mailbox gone")
	check_equal(reader.state, Pet.State.READ, "reads the letter")


func test_letter_taken_before_it_lands_is_read_on_landing() -> void:
	open("s1", "Alpha")
	var reader := open("s2", "Beta")
	Events.post(&"session_message_sent", {"session": "s1", "to": "Beta"})
	Events.post(&"session_mail", {"session": "s2", "mail": 1})
	Events.post(&"session_mail", {"session": "s2", "mail": 0})
	check_equal(reader.state, Pet.State.IDLE, "nothing to read yet")
	pets._letters[0]._process(Letter.SECONDS_RANGE.y)
	check_equal(reader.state, Pet.State.READ, "reads when the letter lands")
	check_equal(reader.mail, 0, "no mailbox")


func test_message_to_an_unknown_name_sends_no_letter() -> void:
	var sender := open("s1", "Alpha")
	Events.post(&"session_message_sent", {"session": "s1", "to": "Nobody"})
	Events.post(&"session_message_sent", {"session": "s1", "to": "Alpha"})
	check_equal(sender.state, Pet.State.IDLE, "no throw")
	check(pets._letters.is_empty(), "no letter")


func test_letter_from_a_session_without_pet_goes_to_the_mailbox() -> void:
	var reader := open("s1")
	set_phase("s1", &"working")
	Events.post(&"session_mail", {"session": "s1", "mail": 2})
	check_equal(reader.mail, 2, "two letters wait")


func test_turn_asked_by_another_session_ends_without_cheer() -> void:
	var pet := open("s1")
	Events.post(&"session_turn", {"session": "s1", "origin": &"peer", "from": "Beta"})
	set_phase("s1", &"idle")
	Events.post(&"session_finished", {"session": "s1"})
	check_equal(pet.state, Pet.State.NOD, "nods: the user asked nothing")
	stand(pet)
	Events.post(&"session_turn", {"session": "s1", "origin": &"human", "from": ""})
	Events.post(&"session_finished", {"session": "s1"})
	check_equal(pet.state, Pet.State.CHEER, "cheers for a turn of the user")


func test_session_that_wrote_to_another_waits_for_its_answer() -> void:
	var asker := open("s1", "Alpha")
	var answerer := open("s2", "Beta")
	answerer._window_pos.x = asker._window_pos.x - 600.0
	Events.post(&"session_turn", {"session": "s1", "origin": &"human", "from": ""})
	set_phase("s1", &"working")
	Events.post(&"session_message_sent", {"session": "s1", "to": "Beta"})
	set_phase("s2", &"working")
	set_phase("s1", &"idle")
	Events.post(&"session_finished", {"session": "s1"})
	check_equal(asker.wish, Pet.Wish.WAIT, "waits for the answer")
	check_equal(asker.state, Pet.State.THROW, "no cheer: not done")
	stand(asker)
	brain._refresh()
	check_equal(asker.facing, -1.0, "turned toward the other pet")
	check(not brain._rests(asker), "not at rest for the tower")
	asker.hovered = true
	brain._refresh()
	check("Waiting for the answer of Beta" in asker.get_node("../Bubble").card, "the card says so")

	Events.post(&"session_turn", {"session": "s1", "origin": &"peer", "from": "Beta"})
	set_phase("s1", &"working")
	set_phase("s1", &"idle")
	stand(asker)
	Events.post(&"session_finished", {"session": "s1"})
	check_equal(asker.state, Pet.State.CHEER, "the answer came: done for the user, at last")
	check_equal(asker.wish, Pet.Wish.ROAM, "no more wait")


func test_no_wait_for_a_session_that_stopped_working() -> void:
	var asker := open("s1", "Alpha")
	open("s2", "Beta")
	Events.post(&"session_message_sent", {"session": "s1", "to": "Beta"})
	set_phase("s2", &"working")
	set_phase("s1", &"idle")
	check_equal(asker.wish, Pet.Wish.WAIT, "waits while the other works")
	set_phase("s2", &"idle")
	check_equal(asker.wish, Pet.Wish.ROAM, "the other stopped without an answer")


func test_server_left_running_is_not_a_wait() -> void:
	var pet := open("s1")
	set_phase("s1", &"working")
	Events.post(&"session_background", {"session": "s1", "background": 0, "servers": 1})
	set_phase("s1", &"idle")
	Events.post(&"session_finished", {"session": "s1"})
	check_equal(pet.state, Pet.State.CHEER, "done: nobody waits for a server")
	check_equal(pet.wish, Pet.Wish.ROAM, "no hourglass")
	check(pet.serving, "carries the antenna")
	pet.hovered = true
	brain._refresh()
	check("Servers running: 1" in pet.get_node("../Bubble").card, "the card says so")
	Events.post(&"session_background", {"session": "s1", "background": 0, "servers": 0})
	check(not pet.serving, "antenna gone with the server")


func test_collision_on_a_file_makes_rivals() -> void:
	var victim := open("s1", "Alpha")
	var writer := open("s2", "Beta")
	writer._window_pos.x = victim._window_pos.x + 700.0
	check_equal(victim.dispute, "", "same folder is not a fight")
	Events.post(&"session_collision", {"session": "s1", "other": "s2", "file": "pet.gd", "path": "/work/src/pet.gd"})
	check_equal([victim.state, writer.state], [Pet.State.GLARE, Pet.State.GLARE], "glare at each other, even from afar")
	check_equal([victim.facing, writer.facing], [1.0, -1.0], "face to face")
	check_equal(victim.get_node("../Bubble")._message, "pet.gd: also changed by Beta", "the bubble names the file and the other session")
	check_equal([victim.dispute, writer.dispute], ["/work/src/pet.gd", "/work/src/pet.gd"], "rivals when they meet")
	brain._sessions["s1"].dispute_until = 0.0
	brain._refresh()
	check_equal(victim.dispute, "", "forgotten after a while")
