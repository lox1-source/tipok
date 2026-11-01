extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures.append(message)
		push_error(message)

func run() -> void:
	var save_manager: Variant = root.get_node("SaveManager")
	var achievement_manager: Variant = root.get_node("AchievementManager")
	var old_dev_session: bool = save_manager.dev_session
	var old_achievement_path: String = achievement_manager.save_path
	var old_unlocked: Dictionary = achievement_manager.unlocked.duplicate(true)
	var old_notifications: bool = achievement_manager.notifications_enabled
	save_manager.dev_session = true
	achievement_manager.save_path = "res://tests/dev_menu_achievements_temp.json"
	achievement_manager.unlocked.clear()
	achievement_manager.notifications_enabled = false

	var menu: Node = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._show_dev_page("minigames")
	var minigame_ids := ["doodle_jump", "tab_war", "wire_puzzle", "office_queue", "court_trial"]
	check(menu.get_node_or_null("DevPage_locations/DevPageScroll_locations/DevPageBody_locations/DevGrid_locations/DevLocation_digital_archaeology") != null,
		"DEV-локации показывают Старые проекты")
	for minigame_id in minigame_ids:
		check(menu.get_node_or_null("DevPage_minigames/DevPageScroll_minigames/DevPageBody_minigames/DevGrid_minigames/DevMinigame_" + minigame_id) != null,
			"DEV-список показывает мини-игру " + minigame_id)
	for minigame_id in minigame_ids + ["digital_archaeology", "hotdog_master"]:
		save_manager.set_dev_minigame(minigame_id)
		var game: Node = load("res://Prologue.tscn").instantiate()
		game.save_path = "res://tests/dev_menu_progress_temp.json"
		root.add_child(game)
		await process_frame
		var expected_modes := {"doodle_jump":"doodle_jump", "tab_war":"tab_war", "wire_puzzle":"last_build", "digital_archaeology":"digital_archaeology", "hotdog_master":"hotdog_master", "office_queue":"office_404", "court_trial":"court_trial"}
		var expected_mode: String = expected_modes[minigame_id]
		check(save_manager.dev_minigame.is_empty() and game.mode == expected_mode,
			"Прямой запуск " + minigame_id + " открывает режим " + expected_mode)
		var new_music := {"doodle_jump":"doodle_jump", "digital_archaeology":"old_projects", "hotdog_master":"hotdog_master"}
		if new_music.has(minigame_id):
			check(root.get_node("AudioManager").current_music_state() == new_music[minigame_id],
				"Прямой запуск " + minigame_id + " включает свою музыку")
		if minigame_id == "doodle_jump":
			game.go_back()
			check(root.get_node("AudioManager").current_music_state() == "room", "Выход из Прыжков возвращает музыку комнаты")
		game.queue_free()
		await process_frame

	for page_id in ["chapters", "calls", "endings"]:
		menu._show_dev_page(page_id)
		var prefix := "DevChapter_" if page_id == "chapters" else ("DevCall_" if page_id == "calls" else "DevEnding_")
		var ids := ["1", "2", "3", "4", "5", "6", "7"] if page_id == "chapters" else (["call_drx", "call_tables", "call_palych"] if page_id == "calls" else ["grok", "jbt", "artbay", "artbay_bad", "team", "ministry", "triple", "neutral", "instrumental"])
		var grid_name: String = "DevGrid_" + page_id
		var grid: Node = menu.get_node("DevPage_%s/DevPageScroll_%s/DevPageBody_%s/%s" % [page_id,page_id,page_id,grid_name])
		for item_id in ids:
			check(grid.get_node_or_null(prefix + item_id) != null, "DEV-раздел %s содержит %s" % [page_id,item_id])
		if page_id == "endings":
			check(menu.get_node_or_null("DevPage_endings/DevPageScroll_endings/DevPageBody_endings/DevGrid_endings/DevEnding_credits") != null, "DEV-раздел содержит прямой запуск титров")

	menu._show_dev_page("achievements")
	check(menu.get_node_or_null("DevPage_achievements/DevPageScroll_achievements/DevPageBody_achievements/DevAchievementRow_first_launch") != null, "DEV-раздел достижений показывает награды по одной")
	menu._unlock_dev_achievement("first_launch")
	check(achievement_manager.has_achievement("first_launch"), "DEV-кнопка открывает одно выбранное достижение")
	menu._reset_dev_achievement("first_launch")
	check(not achievement_manager.has_achievement("first_launch"), "DEV-кнопка сбрасывает выбранное достижение")

	for chapter in range(1, 8):
		save_manager.set_dev_chapter(chapter)
		var game: Node = load("res://Prologue.tscn").instantiate()
		game.save_path = "res://tests/dev_menu_progress_temp.json"
		root.add_child(game)
		await process_frame
		check(save_manager.dev_chapter == 0 and game.active_chapter == chapter, "DEV-запуск главы %d потребляется правильно" % chapter)
		game.queue_free()
		await process_frame

	for call_id in ["call_drx", "call_tables", "call_palych"]:
		save_manager.set_dev_call_event(call_id)
		var game: Node = load("res://Prologue.tscn").instantiate()
		game.save_path = "res://tests/dev_menu_progress_temp.json"
		root.add_child(game)
		await process_frame
		check(save_manager.dev_call_event.is_empty() and game.mode == "dialogue" and game.flow == "phone_call_dev_" + call_id,
			"DEV-запуск события %s открывает звонок" % call_id)
		game.queue_free()
		await process_frame

	for ending_id in ["grok", "jbt", "artbay", "artbay_bad", "team", "ministry", "triple", "neutral", "instrumental"]:
		save_manager.set_dev_ending(ending_id)
		var game: Node = load("res://Prologue.tscn").instantiate()
		game.save_path = "res://tests/dev_menu_progress_temp.json"
		root.add_child(game)
		await process_frame
		check(save_manager.dev_ending.is_empty() and game.mode == "ending" and game.story.get_value("final_ending") == ending_id,
			"DEV-запуск финала %s открывает нужную карточку" % ending_id)
		game.queue_free()
		await process_frame

	save_manager.set_dev_credits()
	var credits_game: Node = load("res://Prologue.tscn").instantiate()
	credits_game.save_path = "res://tests/dev_menu_progress_temp.json"
	root.add_child(credits_game)
	await process_frame
	check(not save_manager.dev_credits and credits_game.mode == "credits", "DEV-кнопка титров открывает титры напрямую")
	credits_game.queue_free()
	await process_frame
	menu.queue_free()
	await process_frame

	achievement_manager.save_path = old_achievement_path
	achievement_manager.unlocked = old_unlocked
	achievement_manager.notifications_enabled = old_notifications
	save_manager.dev_session = old_dev_session
	for path in ["res://tests/dev_menu_progress_temp.json", "res://tests/dev_menu_achievements_temp.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("DEV MENU SMOKE: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
