extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error(description)

func run() -> void:
	var save_manager: Node = root.get_node("SaveManager")
	var old_dev_session: bool = save_manager.dev_session
	var achievements: Variant = root.get_node("AchievementManager")
	var old_notifications: bool = achievements.notifications_enabled
	var old_achievement_path: String = achievements.save_path
	var old_unlocked: Dictionary = achievements.unlocked.duplicate(true)
	achievements.save_path = "res://tests/kiosk_dialogue_mouse_achievements_temp.json"
	achievements.notifications_enabled = false
	achievements.unlocked.clear()
	save_manager.set_dev_minigame("hotdog_master")
	var game = load("res://Prologue.tscn").instantiate()
	game.save_path = "res://tests/kiosk_dialogue_mouse_temp.json"
	root.add_child(game)
	await process_frame
	var kiosk: Control = game.hotdog_master
	check(kiosk.walk_area_polygon.position == Vector2.ZERO, "Полигон прохода не смещён относительно фона")
	check(kiosk._constrain_to_walk_area(Vector2(42, 340)) == Vector2(42, 340), "Верхний левый край прохода совпадает с вершиной полигона")
	check(kiosk._constrain_to_walk_area(Vector2(918, 402)) == Vector2(918, 402), "Нижний правый край прохода совпадает с вершиной полигона")
	check(kiosk._constrain_to_walk_area(Vector2(0, 0)) == Vector2(42, 340), "Грат не выходит за левый верхний край тротуара")
	check(game.hotdog_master.get_index() < game.vn.get_index(), "Киоск расположен ниже диалога в порядке ввода")
	check(root.get_node("AudioManager").current_music_state() == "hotdog_master", "На киоске звучит его тема")
	game._on_hotdog_master_interaction("artrey")
	check(root.get_node("AudioManager").current_music_state() == "hotdog_master", "Разговор с Артреем сохраняет тему киоска")
	for step in range(30):
		if not game.vn.choice_buttons.is_empty():
			break
		game.vn.advance()
	check(game.vn.choice_buttons.size() == 3, "У киоска открылись три ответа")
	if game.vn.choice_buttons.size() == 3:
		var selected := [""]
		game.vn.choice_selected.connect(func(id: String): selected[0] = id)
		var target: Button = game.vn.choice_buttons[1]
		var point: Vector2 = target.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, true)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = true
		root.push_input(click, true)
		click.pressed = false
		root.push_input(click, true)
		check(selected[0] == "artrey_terms", "Клик мышью выбирает второй ответ Артрею")
		var guard := 0
		while game.flow == "chapter_two_artrey" and game.dialogue_open and guard < 60:
			guard += 1
			game.vn.advance()
		check(kiosk.order_overlay != null and kiosk.order_overlay.visible, "После разговора открывается меню заказа")
		var order_button: Button = null
		for candidate in kiosk.order_overlay.find_children("*","Button",true,false):
			if str(candidate.name) == "Order_master":
				order_button = candidate
				break
		check(order_button != null,"В меню есть «Мастер сосиска»")
		if order_button != null:
			await process_frame
			check(order_button.has_focus(),"Заказ по умолчанию имеет фокус для клавиатуры")
			var skip := InputEventKey.new()
			skip.keycode = KEY_SPACE
			skip.pressed = true
			root.push_input(skip,true)
			skip.pressed = false
			root.push_input(skip,true)
			check(kiosk.order_overlay.visible and int(game.story.get_value("hotdog_order_stage",0)) == 1,"Пробел не подтверждает заказ")
			var order_point: Vector2 = order_button.get_global_rect().get_center()
			motion.position = order_point
			motion.global_position = order_point
			root.push_input(motion,true)
			click.position = order_point
			click.global_position = order_point
			click.pressed = true
			root.push_input(click,true)
			click.pressed = false
			root.push_input(click,true)
			check(game.flow == "hotdog_taste","Мышь заказывает «Мастер сосиску»")
	game.queue_free()
	await process_frame
	var save_path := "res://tests/kiosk_dialogue_mouse_temp.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if FileAccess.file_exists(achievements.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(achievements.save_path))
	save_manager.dev_session = old_dev_session
	achievements.unlocked = old_unlocked
	achievements.save_path = old_achievement_path
	achievements.notifications_enabled = old_notifications
	print("KIOSK DIALOGUE MOUSE: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
