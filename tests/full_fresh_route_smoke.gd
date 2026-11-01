extends SceneTree

var failures: Array[String] = []
var game: Variant
var choices_preferred := ["purpose_person", "friend", "bios_date", "smart", "dream_honest", "care", "read_manual", "safe_food", "dinner_lights", "share_yes", "defender_slow", "artrey_terms", "c3_respect", "c3_peace", "c4_backup", "c5_grok_yes", "c5_jbt_yes", "c6_companion_grok", "c5_honest", "c6_contract", "c7_page_project", "c7_solo"]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures.append(message)
		push_error(message)

func drive_dialogue(limit: int = 500) -> void:
	var guard := 0
	while game.dialogue_open and guard < limit:
		guard += 1
		if game.vn.is_revealing():
			game.vn.advance()
			continue
		var options: Array = game.vn.current_entry().get("choices", [])
		if options.is_empty():
			game.vn.advance()
			continue
		var selected := 0
		for i in range(options.size()):
			if str(options[i].get("id", "")) in choices_preferred:
				selected = i
				break
		game.vn.select_choice(selected)
	check(guard < limit, "Диалог завершается без зацикливания")

func press_key(key: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	return event

func launch_computer_chapter(chapter: int) -> void:
	game.nearby_object = "computer"
	game._interact()
	var card: Control = game.computer_panel.get_node_or_null("ChapterLaunchCard")
	if card != null:
		for child in card.get_children():
			if child is Button:
				child.pressed.emit()
				break
	await drive_dialogue()
	check(game.active_chapter == chapter, "Запуск главы %d с компьютера" % chapter)

func run() -> void:
	var save_path := "res://tests/full_fresh_route_temp.json"
	var achievement_path := "res://tests/full_fresh_route_achievements_temp.json"
	var achievements: Variant = root.get_node("AchievementManager")
	var original_achievement_path: String = achievements.save_path
	var original_unlocked: Dictionary = achievements.unlocked.duplicate(true)
	var original_notifications: bool = achievements.notifications_enabled
	achievements.save_path = achievement_path
	achievements.unlocked.clear()
	achievements.notifications_enabled = false
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if FileAccess.file_exists(achievement_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(achievement_path))
	game = load("res://Prologue.tscn").instantiate()
	game.save_path = save_path
	root.add_child(game)
	await process_frame
	check(game.mode == "menu" and game.step == 0, "Новая игра начинается с пролога")
	game.resume_game()
	await drive_dialogue()
	game.nearby_object = "phone"
	game._unhandled_input(press_key(KEY_E))
	await drive_dialogue()
	game._unhandled_input(press_key(KEY_ESCAPE))
	game.nearby_object = "computer"
	game._unhandled_input(press_key(KEY_E))
	game._open_app("grok")
	game.show_desktop()
	game._open_app("project")
	await drive_dialogue()
	game._open_app("blender")
	game.begin_flow("blender")
	await drive_dialogue()
	game._open_app("jbt")
	await drive_dialogue()
	game._open_app("search")
	game.search_input.text = "import bpy; bpy.ops.mesh.primitive_cylinder_add(vertices=16)"
	game.submit_search()
	await drive_dialogue()
	game._open_app("jbt")
	await drive_dialogue()
	game._open_app("jbt")
	await drive_dialogue()
	game._open_app("grok")
	await drive_dialogue()
	check(game.step == 8 and game.mode == "ending", "Пролог завершается штатным игровым маршрутом")
	game.start_chapter_one()
	await drive_dialogue()
	for object_id in ["bed", "poster", "wardrobe", "pizza"]:
		game.nearby_object = object_id
		game._interact()
		await drive_dialogue()
	check(game.chapter_one_stage == 2, "Четыре улики ведут из пролога к завершению главы 1")
	game.start_chapter_two()
	await drive_dialogue()
	check(game.mode == "hotdog_master", "Глава 2 направляет к сюжетному киоску")
	game.hotdog_master.player_position = Vector2(458, 405)
	game.hotdog_master._update_nearest()
	game.hotdog_master._interact()
	await drive_dialogue()
	if game.minigame_checkpoint.get("kind", "") == "brainstorm":
		game.Early.finish_brainstorm(game, ["prototype", "story", "test"], "prototype")
		await drive_dialogue()
	check(game.chapter_two_complete and game.story.get_value("artbay_intro_seen"), "Встреча у киоска возвращает в продолжение главы")
	game.start_chapter_three()
	await launch_computer_chapter(3)
	check(game.mode == "tab_war", "После компьютера глава 3 открывает войну вкладок")
	game._finish_tab_war({"side":"grok", "won":true, "reason":"control"})
	await drive_dialogue()
	game.start_chapter_four()
	await launch_computer_chapter(4)
	game._finish_office_queue({"approved":3,"wrong_attempts":0,"stamp_obtained":true,"stamp_stolen":false,"protocol":true,"authorship_proven":true})
	await drive_dialogue()
	game.start_chapter_five()
	await launch_computer_chapter(5)
	game._finish_court_trial({"quality":3})
	await drive_dialogue()
	game.start_chapter_six()
	await launch_computer_chapter(6)
	check(game.mode == "digital_archaeology", "Глава 6 открывает архив старых проектов")
	for pair in [[0,1],[2,3],[4,5]]:
		game.digital_archaeology._inspect(pair[0])
		game.digital_archaeology._inspect(pair[1])
		game.digital_archaeology._connect()
	await drive_dialogue()
	game.start_chapter_seven()
	await launch_computer_chapter(7)
	check(game.mode == "last_build", "Глава 7 завершается маршрутизатором сборки")
	game._finish_last_build({"turns":12})
	await drive_dialogue()
	check(game.mode == "ending" and game.story.get_value("final_ending") == "neutral", "Полный свежий маршрут доходит до выбранной концовки")
	game.show_credits()
	check(game.mode == "credits", "Финал открывает титры")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if FileAccess.file_exists(achievement_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(achievement_path))
	achievements.save_path = original_achievement_path
	achievements.unlocked = original_unlocked
	achievements.notifications_enabled = original_notifications
	print("FULL FRESH ROUTE RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
