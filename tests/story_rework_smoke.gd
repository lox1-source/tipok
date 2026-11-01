extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition: print("PASS: ",description)
	else:
		failures.append(description)
		push_error(description)

func run() -> void:
	var story = load("res://scripts/story_state.gd").new()
	check(story.relationship_state("artrey") == "знакомство","Отношения начинаются без готового партнёрства")
	check(story.decide("kiosk_talk","honest",{"affection_artbay":3}),"Первый выбор применяется")
	check(not story.decide("kiosk_talk","honest",{"affection_artbay":3}) and int(story.get_value("affection_artbay")) == 3,"Повтор разговора не начисляет симпатию")
	check(story.relationship_state("artrey") == "дружба","Дружба возникает постепенно")
	story.set_value("artbay_betrayal",true)
	check(story.relationship_state("artrey") == "конфликт","Предательство сильнее накопленной симпатии")
	var restored_story = load("res://scripts/story_state.gd").new()
	restored_story.import_data(JSON.parse_string(JSON.stringify(story.export_data())))
	check(restored_story.relationship_state("artrey") == "конфликт" and not restored_story.decide("kiosk_talk","honest",{"affection_artbay":3}),"Решения и конфликт переживают сохранение")

	var kiosk = load("res://scripts/hotdog_master_location.gd").new()
	root.add_child(kiosk)
	await process_frame
	kiosk.open({},true)
	var conversations := [0]
	kiosk.interaction_requested.connect(func(_id: String): conversations[0] += 1)
	var return_count := [0]
	kiosk.return_requested.connect(func(): return_count[0] += 1)
	kiosk._request_return()
	check(return_count[0] == 0 and kiosk.status_label.text.contains("поговори"),"До первого разговора нельзя пропустить обязательную встречу у киоска")
	kiosk.player_position = Vector2(458,405)
	kiosk._update_nearest()
	var interact_key := InputEventKey.new()
	interact_key.keycode = KEY_E
	interact_key.pressed = true
	kiosk._unhandled_key_input(interact_key)
	check(conversations[0] == 1,"С Артреем можно поговорить у киоска")
	kiosk.chapter_first_visit = false
	kiosk._request_return()
	check(return_count[0] == 1,"Повторный визит позволяет вернуться в комнату")
	kiosk.player_position = Vector2(290,385)
	kiosk._update_nearest()
	kiosk._interact()
	var kiosk_save: Dictionary = JSON.parse_string(JSON.stringify(kiosk.snapshot()))
	kiosk.open(kiosk_save,false)
	check(kiosk.observed.has("drinks") and kiosk.player_position.distance_to(Vector2(290,385)) < 1.0,"Осмотр и положение у киоска восстанавливаются")
	var held_right := InputEventKey.new()
	held_right.physical_keycode = KEY_D
	held_right.pressed = true
	Input.parse_input_event(held_right)
	kiosk._process(10.0)
	held_right.pressed = false
	Input.parse_input_event(held_right)
	check(kiosk.player_position.x <= kiosk.WALK_AREA.end.x and kiosk.player_position.y >= kiosk.WALK_AREA.position.y,"Грат не выходит за границу прогулочной зоны киоска")
	kiosk.hide()
	kiosk.queue_free()
	await process_frame

	var archive = load("res://scripts/digital_archaeology.gd").new()
	root.add_child(archive)
	await process_frame
	archive.open({}, {"old_projects_companion":"jbt"})
	check(archive.companion == "jbt" and archive.status_label.text.to_lower().contains("осмотри"),"Архив получает выбранного спутника и инструкцию")
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = archive.POINTS[0]
	archive._gui_input(click_event)
	check(archive.found.is_empty(),"Удалённый клик не собирает улику")
	archive.explorer_pos = archive.POINTS[0]
	archive._gui_input(click_event)
	check(archive.found.has("prototype") and archive.status_label.text.contains("ЖБТ"),"Близкий осмотр раскрывает улику и реакцию спутника")
	archive._inspect(1)
	archive._connect()
	check(archive.links.size() == 1,"Подтверждённая пара добавляется в граф")
	var archive_save: Dictionary = JSON.parse_string(JSON.stringify(archive.snapshot()))
	archive.open(archive_save,{"old_projects_companion":"jbt"})
	check(archive.links.size() == 1 and archive.found.size() == 2 and archive.explorer_pos.distance_to(archive.POINTS[0]) < 1.0,"Улики, связь и положение восстанавливаются")
	archive.explorer_pos = archive.POINTS[0]
	held_right.pressed = true
	Input.parse_input_event(held_right)
	archive._process(10.0)
	held_right.pressed = false
	Input.parse_input_event(held_right)
	check(archive.explorer_pos.x <= archive.EXPLORER_MAX.x and archive.explorer_pos.y <= archive.EXPLORER_MAX.y,"Грат остаётся над нижней подсказкой архива")
	archive.open({"player":{"x":300,"y":435}},{"old_projects_companion":"jbt"})
	check(archive.explorer_pos.y <= archive.EXPLORER_MAX.y,"Старое сохранение не ставит Грата поверх текста")
	archive.open({}, {"old_projects_companion":"grok","grok_trust":true})
	archive._inspect_optional("door")
	var trusted_door: String = archive.status_label.text
	archive.open({}, {"old_projects_companion":"grok","lies_count":2})
	archive._inspect_optional("door")
	check(trusted_door != archive.status_label.text and trusted_door.contains("Грок"),"Доверие и конфликт дают разные разговоры у старой двери")
	archive.open({}, {"old_projects_companion":"jbt","gpt_boundaries":true})
	archive._inspect(2)
	check(archive.status_label.text.contains("План Артрея") or archive.status_label.text.contains("План показа"),"ЖБТ признаёт вклад Артрея в показ")
	archive.hide()
	archive.queue_free()
	await process_frame

	var queue = load("res://scripts/office_queue.gd").new()
	root.add_child(queue)
	await process_frame
	queue.open({})
	check(queue.tutorial_panel.visible and queue.tutorial_continue.disabled,"Очередь начинается с тренировки")
	queue._tutorial_action(2)
	check(queue.tutorial_step == 0 and queue.tutorial_feedback.text.contains("Сначала"),"Неверный порядок объясняется без штрафа")
	for action in range(3): queue._tutorial_action(action)
	queue._start_tutorial()
	check(queue.state.tutorial_seen and not queue.tutorial_panel.visible,"Тренировка открывает настоящую очередь")
	var queue_save: Dictionary = JSON.parse_string(JSON.stringify(queue.state.snapshot()))
	queue.open(queue_save)
	check(not queue.tutorial_panel.visible,"Пройденное обучение очереди не повторяется после загрузки")
	queue.hide()
	queue.queue_free()
	await process_frame

	var court = load("res://scripts/court_trial.gd").new()
	root.add_child(court)
	await process_frame
	court.open({})
	check(court.tutorial.visible and court.tutorial_continue.disabled,"Суд начинает с выбора тренировочной улики")
	for child in court.tutorial.get_children():
		if child is Button and child.text == "Один файл key.txt": child.pressed.emit()
	check(not court.tutorial_done and court.tutorial_feedback.text.contains("не весь разговор"),"Неверная улика объясняется")
	for child in court.tutorial.get_children():
		if child is Button and child.text == "Полная переписка": child.pressed.emit()
	court._finish_tutorial()
	check(court.tutorial_seen and not court.tutorial.visible,"Верная улика открывает суд")
	var court_save: Dictionary = JSON.parse_string(JSON.stringify(court._snapshot()))
	court.open(court_save)
	check(not court.tutorial.visible,"Обучение суда сохраняется")
	court.hide()
	court.queue_free()
	await process_frame

	var wires = load("res://scripts/last_build.gd").new()
	root.add_child(wires)
	await process_frame
	wires.open({})
	check(wires.tutorial.visible and wires.tutorial_continue.disabled,"Провода показывают поворот до уровня")
	for child in wires.tutorial.get_children():
		if child is Button and child.text == "": child.pressed.emit()
	wires._finish_tutorial()
	check(wires.tutorial_seen and not wires.tutorial.visible,"Поворот включает контакты и открывает уровень")
	var wire_save: Dictionary = JSON.parse_string(JSON.stringify(wires.snapshot()))
	wires.open(wire_save)
	check(not wires.tutorial.visible,"Обучение проводов сохраняется")
	wires.queue_free()
	await process_frame

	# The actual game controller must restore both location checkpoints, not just the scene objects.
	var save_path := "res://tests/story_rework_temp.json"
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var game = load("res://Prologue.tscn").instantiate()
	game.save_path = save_path
	root.add_child(game)
	await process_frame
	game.call_event_schedule.clear()
	game.story.set_value("hotdog_first_visit_seen",true)
	game.active_chapter = 4
	game.start_hotdog_master()
	game.hotdog_master.player_position = Vector2(290,385)
	game.hotdog_master._update_nearest()
	game.hotdog_master._interact()
	check(game.save_progress(),"Игра сохраняется на повторном посещении киоска")
	game.queue_free()
	await process_frame
	game = load("res://Prologue.tscn").instantiate()
	game.save_path = save_path
	root.add_child(game)
	await process_frame
	check(game.load_progress(),"Продолжение читает отдельное тестовое сохранение")
	game.resume_game()
	check(game.mode == "hotdog_master" and game.active_chapter == 4 and game.hotdog_master.observed.has("drinks"),"Киоск, точка возврата и осмотр восстанавливаются через основной сейв")
	game._leave_hotdog_master()
	check(game.mode == "room" and game.active_chapter == 4,"Выход из киоска возвращает в прежнюю главу")
	game.story.set_value("old_projects_companion","grok")
	game.start_digital_archaeology()
	game.digital_archaeology.explorer_pos = game.digital_archaeology.POINTS[0]
	game.digital_archaeology._inspect(0)
	check(game.save_progress(),"Игра сохраняется внутри старых проектов")
	game.queue_free()
	await process_frame
	game = load("res://Prologue.tscn").instantiate()
	game.save_path = save_path
	root.add_child(game)
	await process_frame
	check(game.load_progress(),"Продолжение читает архивный checkpoint")
	game.resume_game()
	check(game.mode == "digital_archaeology" and game.active_chapter == 6 and game.digital_archaeology.found.has("prototype") and game.digital_archaeology.explorer_pos.distance_to(game.digital_archaeology.POINTS[0]) < 1.0,"Архив, спутник, находка и положение восстанавливаются в игре")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	print("STORY REWORK SMOKE: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
