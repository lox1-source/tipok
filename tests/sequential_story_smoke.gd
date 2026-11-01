extends SceneTree

# One continuous story state from the first Grok conversation to credits.
# Individual minigame rules are exercised by their own smoke tests; here their
# completion signals test the real chapter transitions and ending gates.
var failures: Array[String] = []
var game: Variant
var save_path := "res://tests/sequential_story_temp.json"
var achievement_path := "res://tests/sequential_story_achievements_temp.json"
var preferred: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ", label)
	else:
		failures.append(label)
		push_error(label)

func drive_until(target_modes: Array[String] = []) -> void:
	var guard := 0
	while game.dialogue_open and guard < 500 and (target_modes.is_empty() or game.mode not in target_modes):
		guard += 1
		if game.vn.is_revealing():
			game.vn.advance()
			continue
		var choices: Array = game.vn.current_entry().get("choices", [])
		if choices.is_empty():
			game.vn.advance()
			continue
		var selected := 0
		for i in range(choices.size()):
			if str(choices[i].get("id", "")) in preferred:
				selected = i
				break
		game.vn.select_choice(selected)
	check(guard < 500, "Dialogue completes without a graph loop")

func launch_computer() -> void:
	game.nearby_object = "computer"
	game._interact()
	var card: Control = game.computer_panel.get_node_or_null("ChapterLaunchCard")
	check(card != null, "Computer shows the next chapter")
	if card == null: return
	for child in card.get_children():
		if child is Button:
			child.pressed.emit()
			break
	drive_until()

func route_preferences(route: String) -> Array[String]:
	var choices: Array[String] = ["purpose_person", "friend", "bios_date", "smart", "dream_honest", "care", "read_manual", "safe_food", "dinner_lights", "share_yes", "defender_slow", "artrey_terms", "c3_respect", "c3_peace", "c4_backup", "c5_grok_yes", "c5_jbt_yes", "c6_companion_grok"]
	choices.append("c5_lie" if route == "instrumental" else "c5_honest")
	choices.append("c6_trust" if route in ["artbay_bad", "instrumental"] else "c6_contract")
	match route:
		"grok", "jbt", "artbay":
			choices.append_array(["c7_page_relationships", "c7_artrey" if route == "artbay" else "c7_" + route])
		"team", "neutral":
			choices.append_array(["c7_page_project", "c7_solo" if route == "neutral" else "c7_team"])
		"ministry", "triple":
			choices.append_array(["c7_page_special", "c7_" + route])
		"artbay_bad", "instrumental":
			choices.append_array(["c7_page_special", "c7_page_risk", "c7_artrey_bad" if route == "artbay_bad" else "c7_instrument"])
	return choices

func run() -> void:
	var achievements: Variant = root.get_node("AchievementManager")
	var original_path: String = achievements.save_path
	var original_unlocked: Dictionary = achievements.unlocked.duplicate(true)
	var original_notifications: bool = achievements.notifications_enabled
	achievements.save_path = achievement_path
	achievements.unlocked.clear()
	achievements.notifications_enabled = false
	var routes: Array[String] = ["grok", "jbt", "artbay", "artbay_bad", "team", "ministry", "triple", "neutral", "instrumental"]
	for route in routes:
		preferred = route_preferences(route)
		await run_route(route)
	achievements.save_path = original_path
	achievements.unlocked = original_unlocked
	achievements.notifications_enabled = original_notifications
	print("SEQUENTIAL STORY RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func run_route(route: String) -> void:
	for path in [save_path, achievement_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game = load("res://Prologue.tscn").instantiate()
	game.save_path = save_path
	root.add_child(game)
	await process_frame
	game._reset_progress()
	game.call_event_schedule.clear()
	game.intro_seen = true
	game.step = 8 # Prologue is covered by prologue_smoke; this run begins at chapter 1.
	game.start_chapter_one()
	drive_until()
	check(game.chapter_one_stage == 1, "Chapter 1 reaches room evidence")
	for object_id in ["bed", "poster", "wardrobe", "pizza"]:
		game.nearby_object = object_id
		game._interact()
		drive_until()
	check(game.chapter_one_stage == 2, "Four pieces of evidence complete chapter 1")
	game.start_chapter_two()
	drive_until()
	check(game.mode == "hotdog_master", "BIOS reaches the outdoor kiosk")
	game.hotdog_master.player_position = Vector2(458, 405)
	game.hotdog_master._update_nearest()
	game.hotdog_master._interact()
	drive_until()
	if game.minigame_checkpoint.get("kind", "") == "brainstorm":
		game.Early.finish_brainstorm(game, ["prototype", "story", "test"], "prototype")
		drive_until()
	check(game.chapter_two_complete and game.story.get_value("artbay_intro_seen"), "Chapter 2 completes after meeting Artrey")
	game.start_chapter_three()
	check(game.chapter_computer_pending == 3, "Chapter 3 waits for computer")
	launch_computer()
	check(game.mode == "tab_war", "Chapter 3 reaches Tab War")
	game._finish_tab_war({"side": "grok", "won": true, "reason": "control"})
	drive_until()
	check(game.story.get_value("chapter_three_complete"), "Tab War result continues to chapter 4")
	game.start_chapter_four()
	check(game.chapter_computer_pending == 4, "Chapter 4 waits for computer")
	launch_computer()
	check(game.mode == "office_404", "Chapter 4 reaches queue")
	game._finish_office_queue({"approved": 3, "wrong_attempts": 0, "stamp_obtained": true, "stamp_stolen": false, "protocol": true, "authorship_proven": true})
	drive_until()
	check(game.story.get_value("chapter_four_complete"), "Queue result continues to court")
	game.start_chapter_five()
	check(game.chapter_computer_pending == 5, "Chapter 5 waits for computer")
	launch_computer()
	check(game.mode == "court_trial", "Chapter 5 reaches court")
	game._finish_court_trial({"quality": 3})
	drive_until()
	check(game.story.get_value("chapter_five_complete"), "Court result continues to archive")
	game.start_chapter_six()
	check(game.chapter_computer_pending == 6, "Chapter 6 waits for computer")
	launch_computer()
	check(game.mode == "digital_archaeology", "Chapter 6 reaches old projects")
	for pair in [[0, 1], [2, 3], [4, 5]]:
		game.digital_archaeology._inspect(pair[0])
		game.digital_archaeology._inspect(pair[1])
		game.digital_archaeology._connect()
	drive_until()
	check(game.story.get_value("chapter_six_complete") and game.story.get_value("artbay_evidence"), "Old projects prove authorship and complete chapter 6")
	check(bool(game.story.get_value("artbay_repaired")) == (route not in ["artbay_bad", "instrumental"]), "Artrey credit repair follows the chosen chapter 6 answer")
	game.start_chapter_seven()
	check(game.chapter_computer_pending == 7, "Chapter 7 waits for computer")
	launch_computer()
	check(game.mode == "last_build", "Chapter 7 reaches final wires")
	game._finish_last_build({"turns": 12})
	# Select the actual gated ending using choices earned in this playthrough.
	drive_until()
	check(game.story.get_value("final_ending") == route and game.mode == "ending", "Earned route " + route + " reaches its distinct ending card")
	game.show_credits()
	check(game.mode == "credits", "Route " + route + " reaches credits")
	game.queue_free()
	await process_frame
	for path in [save_path, achievement_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
