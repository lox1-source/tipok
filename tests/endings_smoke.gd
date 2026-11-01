extends SceneTree

var failures: Array[String] = []
var game: Node
const CHAPTER = preload("res://scripts/chapter_seven.gd")

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error(message)

func _select_id(identifier: String) -> bool:
	var entry: Dictionary = game.vn.current_entry()
	var choices: Array = entry.get("choices", [])
	for index in range(choices.size()):
		if str(choices[index].get("id", "")) == identifier:
			game.vn.select_choice(index)
			return true
	return false

func _reach_choice() -> bool:
	var guard := 0
	while game.vn.choice_buttons.is_empty() and game.dialogue_open and guard < 120:
		guard += 1
		game.vn.advance()
	return not game.vn.choice_buttons.is_empty()

func _walk_dialogue_to_end() -> bool:
	var guard := 0
	while game.dialogue_open and guard < 180:
		guard += 1
		if not game.vn.choice_buttons.is_empty():
			game.vn.select_choice(0)
		else:
			game.vn.advance()
	return not game.dialogue_open

func _route_values(id: String) -> Dictionary:
	var values := {"grok_date_completed":true,"grok_without_key":true,"gpt_boundaries":true,"defused_tab_war":true,"affection_grok":2,"affection_gpt":2,"affection_artbay":2,"secret_protocol":true,"stamp_obtained":true,"lies_count":2,"game_backup_created":true}
	if id == "artrey":
		values["artbay_contract_signed"] = true
		values["project_ownership_proven"] = true
		values["artbay_repaired"] = true
	if id == "grok":
		values["lies_count"] = 0
		values["affection_grok"] = 3
	if id == "jbt":
		values["affection_gpt"] = 3
	if id == "artbay_bad":
		values["artbay_control_taken"] = true
	if id == "instrumental":
		values["artbay_control_taken"] = true
		values["lied_in_court"] = true
	return values

func _path_for(id: String) -> Array[String]:
	match id:
		"grok", "jbt", "artrey": return ["c7_page_relationships", "c7_" + id]
		"team": return ["c7_page_project", "c7_team"]
		"solo": return ["c7_page_project", "c7_solo"]
		"ministry": return ["c7_page_special", "c7_ministry"]
		"triple": return ["c7_page_special", "c7_triple"]
		"artbay_bad": return ["c7_page_special", "c7_page_risk", "c7_artrey_bad"]
		"instrumental": return ["c7_page_special", "c7_page_risk", "c7_instrument"]
	return []

func _ending_line_count(entries: Array, key: String) -> int:
	var labels := {}
	for index in range(entries.size()):
		if entries[index].has("key"):
			labels[str(entries[index].key)] = index
	var cursor := int(labels.get(key, entries.size()))
	var count := 0
	while cursor >= 0 and cursor < entries.size() and count < 40:
		count += 1
		cursor = int(entries[cursor].get("next", entries.size()))
	return count

func run() -> void:
	var manager: Variant = root.get_node("AchievementManager")
	var original_unlocked: Dictionary = manager.unlocked.duplicate(true)
	var original_path: String = manager.save_path
	var original_notifications: bool = manager.notifications_enabled
	var suffix := str(Time.get_ticks_usec())
	var achievement_path := "res://tests/endings_smoke_achievements_%s.json" % suffix
	var game_path := "res://tests/endings_smoke_game_%s.json" % suffix
	manager.save_path = achievement_path
	manager.unlocked.clear()
	manager.notifications_enabled = false
	game = load("res://Prologue.tscn").instantiate()
	game.save_path = game_path
	root.add_child(game)
	await process_frame
	game.call_event_schedule.clear()
	var routes := ["grok", "jbt", "artrey", "artbay_bad", "team", "ministry", "triple", "solo", "instrumental"]
	for route in routes:
		game.story.reset()
		var synthetic_values := _route_values(route)
		for flag in synthetic_values:
			game.story.set_value(str(flag), synthetic_values[flag])
		var entries: Array = CHAPTER.final_choice(game.story.values)
		var path := _path_for(route)
		check(not path.is_empty(), route + " has a test selection path")
		var expected_scene_key: String = "artrey" if route == "artrey" else ("solo" if route == "solo" else str(route))
		var line_count := _ending_line_count(entries, expected_scene_key)
		check(line_count >= 15 and line_count <= 25 or route == "triple" and line_count < 15, route + " has a distinct ending scene with expected length (" + str(line_count) + " lines)")
		var expected_id: String = "artbay" if route == "artrey" else ("neutral" if route == "solo" else str(route))
		game.play_chapter_scene("chapter_seven_outro", entries)
		for choice_id in path:
			check(_reach_choice(), route + " reaches choice " + choice_id)
			check(_select_id(choice_id), route + " selects choice " + choice_id)
			if choice_id.begins_with("c7_page_"):
				check(str(game.story.get_value("final_ending", "")) == "", route + " paging does not commit an ending early")
		check(_walk_dialogue_to_end(), route + " dialogue completes and opens its ending card")
		check(str(game.story.get_value("final_ending", "")) == expected_id, route + " stores the intended final ending id")
		check(bool(game.story.get_value("chapter_seven_complete", false)), route + " marks chapter seven complete")
		check(game.mode == "ending", route + " reaches the existing ending screen")
		var achievement_by_ending := {"grok":"grok_good_ending", "jbt":"jbt_good_ending", "artbay":"artbay_good_ending", "artbay_bad":"artbay_bad_ending", "team":"team_ending", "ministry":"approved_ending", "triple":"triple_affection_ending", "neutral":"neutral_ending", "instrumental":"instrumental_ending"}
		check(manager.has_achievement(str(achievement_by_ending[expected_id])), route + " unlocks its own ending achievement")
		var title := CHAPTER.ending_title(expected_id)
		check(title != "" and CHAPTER.ending_text(expected_id, game.story.values).length() > 20, route + " has a named epilogue")
		game.show_credits()
		await process_frame
		var continue_key := InputEventKey.new()
		continue_key.pressed = true
		continue_key.physical_keycode = KEY_ENTER
		game._unhandled_input(continue_key)
		check(game.mode == "credits" and game.credits_roll != null and game.credits_roll.is_valid(), route + " Enter keeps the credits scrolling")
		var buttons_still_hidden := true
		for button in game.credits_buttons:
			buttons_still_hidden = buttons_still_hidden and not button.visible
		check(buttons_still_hidden, route + " Enter does not replace the credits with the end screen")
		game._finish_credits_roll()
		check(game.mode == "credits" and is_instance_valid(game.credits_screen), route + " opens the existing credits")
		check(game.credits_buttons.size() == 3, route + " credits retain return navigation")
		game.credits_buttons[0].pressed.emit()
		await process_frame
		check(game.mode == "ending", route + " can return from credits to its ending")
		game.vn.close()
		game.dialogue_open = false
		game.story.set_value("chapter_seven_complete", false)
	check(manager.has_achievement("any_ending"), "any ending unlocks its shared achievement")
	check(manager.has_achievement("all_endings"), "all seven main ending routes unlock the collection achievement")
	game.queue_free()
	await process_frame
	manager.unlocked = original_unlocked
	manager.save_path = original_path
	manager.notifications_enabled = original_notifications
	for path in [achievement_path, game_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("ENDINGS SMOKE: PASS")
		quit(0)
	else:
		push_error("ENDINGS SMOKE: %d failure(s)" % failures.size())
		quit(1)
