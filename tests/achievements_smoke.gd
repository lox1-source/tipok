extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error(message)

func run() -> void:
	var manager: Variant = root.get_node("AchievementManager")
	var previous_unlocked: Dictionary = manager.unlocked.duplicate(true)
	var previous_path: String = manager.save_path
	var previous_notifications: bool = manager.notifications_enabled
	var temp_path := "res://tests/achievement_smoke_%d.json" % Time.get_ticks_usec()
	manager.notifications_enabled = false
	manager.save_path = temp_path
	manager.unlocked.clear()
	check(manager.get_total_count() == 34, "каталог содержит 33 запрошенных достижения и дополнительную концовку")
	check(manager.unlock_achievement("first_choice"), "достижение открывается один раз")
	check(not manager.unlock_achievement("first_choice"), "повторно достижение не выдаётся")
	check(not manager.get_unlocked_at("first_choice").is_empty(), "сохраняется дата получения")
	manager.unlocked.clear()
	manager._load_progress()
	check(manager.has_achievement("first_choice"), "прогресс загружается из отдельного JSON")
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	file.store_string("{ damaged")
	file.close()
	manager._load_progress()
	check(manager.unlocked.is_empty(), "повреждённый файл не ломает менеджер")

	var menu: Variant = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var achievements_button_found := false
	for child in menu.menu_panel.get_children():
		if child is Button and child.text == "Мои достижения":
			achievements_button_found = true
	check(achievements_button_found, "главное меню содержит кнопку достижений")
	var regions := {}
	for definition in manager.get_catalog():
		var icon: Texture2D = manager.get_icon(str(definition.id))
		check(icon is AtlasTexture and icon.get_size().x > 0, "иконка загружается: " + str(definition.id))
		if icon is AtlasTexture: regions[str(icon.region)] = true
	check(regions.size() == manager.get_total_count(), "все достижения имеют разные ячейки атласа")
	check(manager.get_icon("approved_ending",true).region != manager.get_icon("approved_ending").region, "секретная иконка скрыта до получения")
	menu._open_achievements()
	check(menu.achievements_panel.visible, "экран достижений открывается")
	check(menu.achievements_panel.find_child("AchievementScroll", true, false) is ScrollContainer, "список достижений прокручивается")
	check(menu.achievements_panel.find_child("AchievementCategories", true, false) is HBoxContainer, "категории созданы")
	check(menu.achievements_panel.find_child("AchievementFilters", true, false) is HBoxContainer, "фильтры созданы")
	menu.selected_category = "Артрей"
	menu._refresh_achievements()
	check(menu.achievement_rows.get_child_count() == 4, "категория Артрея фильтрует список")
	manager.unlock_achievement("first_choice")
	menu.selected_category = "Все"
	menu.selected_state = "Полученные"
	menu._refresh_achievements()
	check(menu.achievement_rows.get_child_count() == 1, "фильтр полученных показывает только открытое достижение")
	menu.selected_state = "Не полученные"
	menu._refresh_achievements()
	check(menu.achievement_rows.get_child_count() == 33, "фильтр закрытых исключает открытое достижение")
	manager.report_story_event("ending", {"id":"not_an_ending"})
	check(not manager.has_achievement("any_ending"), "неизвестная концовка не выдаёт достижение")
	for ending in ["grok", "jbt", "artbay", "artbay_bad", "neutral", "team", "instrumental"]:
		manager.report_story_event("ending", {"id":ending})
	check(manager.has_achievement("all_endings"), "все основные концовки открывают общее достижение")
	check(not manager.has_achievement("platinum"), "платина не открывается до остальных достижений")
	for definition in manager.get_catalog():
		if str(definition.id) != "platinum":
			manager.unlock_achievement(str(definition.id))
	check(manager.has_achievement("platinum"), "платина открывается после всех остальных, без цикла")
	menu._close_achievements()
	check(not menu.achievements_panel.visible and menu.menu_panel.visible, "назад возвращает в главное меню")
	manager.unlocked.clear()
	manager.notifications_enabled = true
	manager.unlock_achievement("first_choice")
	manager.unlock_achievement("jbt_help")
	check(manager._toast_running and manager._toast_queue.size() == 1, "уведомления выстраиваются в очередь")
	await create_timer(7.5).timeout
	check(not manager._toast_running and manager._toast_queue.is_empty(), "очередь уведомлений завершается")
	check(manager._toast_panel.modulate.a == 0.0, "уведомление исчезает")
	if DisplayServer.get_name() != "headless":
		manager.notifications_enabled = false
		manager.unlock_achievement("first_launch")
		manager.unlock_achievement("room_explorer")
		menu.selected_category = "Все"
		menu.selected_state = "Все"
		menu._open_achievements()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/my-achievements.png")

	manager.unlocked = previous_unlocked
	manager.save_path = previous_path
	manager.notifications_enabled = previous_notifications
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	if not failures.is_empty():
		push_error("ACHIEVEMENTS SMOKE: %d failure(s)" % failures.size())
		quit(1)
	else:
		print("ACHIEVEMENTS SMOKE: PASS")
		quit(0)

