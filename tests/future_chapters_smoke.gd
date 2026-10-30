extends SceneTree

var failures: Array[String] = []
var completed_archaeology: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: print("PASS: ",message)
	else:
		failures.append(message)
		push_error(message)

func _on_archaeology_finished(result: Dictionary) -> void:
	completed_archaeology = result

func _graph_is_valid(entries: Array) -> bool:
	var pending: Array[int] = [0]
	var visited := {}
	while not pending.is_empty():
		var index: int = pending.pop_back()
		if index == entries.size() or visited.has(index): continue
		if index < 0 or index >= entries.size(): return false
		visited[index] = true
		var entry: Dictionary = entries[index]
		var choices: Array = entry.get("choices",[])
		if choices.is_empty(): pending.append(int(entry.get("next",index+1)))
		else:
			for option in choices: pending.append(int(option.get("next",index+1)))
	return true

func launch_chapter_from_computer(game: Variant) -> void:
	game.nearby_object = "computer"
	game._interact()
	var card: Control = game.computer_panel.get_node_or_null("ChapterLaunchCard")
	if card != null:
		for child in card.get_children():
			if child is Button:
				child.pressed.emit()
				break
	var guard := 0
	while game.flow == "chapter_computer_boot" and guard < 8:
		guard += 1
		game.vn.advance()
	check(guard < 8,"computer boot scene hands off to chapter dialogue")

func finish_intro_to_minigame(game: Variant, expected_mode: String) -> void:
	var guard := 0
	while game.dialogue_open and game.mode != expected_mode and guard < 180:
		guard += 1
		if game.vn.is_revealing():
			game.vn.advance()
		elif not game.vn.current_entry().get("choices",[]).is_empty():
			game.vn.select_choice(0)
		else:
			game.vn.advance()
	check(guard < 180 and game.mode == expected_mode,"chapter intro leads to " + expected_mode + " only after its dialogue")

func run() -> void:
	var archaeology: Control = load("res://scripts/digital_archaeology.gd").new()
	root.add_child(archaeology)
	archaeology.finished.connect(_on_archaeology_finished)
	archaeology.open()
	archaeology._inspect(0)
	archaeology._inspect(1)
	archaeology._connect()
	check(archaeology.links.size() == 1,"первая связь графа собирается из двух найденных источников")
	archaeology._inspect(2)
	archaeology._inspect(3)
	archaeology._connect()
	archaeology._inspect(4)
	archaeology._inspect(5)
	archaeology._connect()
	check(bool(completed_archaeology.get("evidence",false)),"три доказательные связи завершают расследование")
	check(archaeology.snapshot().links.size() == 3,"прогресс расследования сериализуется для сохранения")
	var build: Control = load("res://scripts/last_build.gd").new()
	root.add_child(build)
	build.open()
	for level_index in range(build.LEVELS.size()):
		build.level = level_index
		build._load_level()
		check(not build._has_route(),"стартовая схема этапа %d требует решения" % (level_index+1))
		for tile in build.LEVELS[level_index].tiles:
			build.rotations[int(tile.cell)] = int(tile.rot)
		check(build._has_route(),"схема этапа %d соединяет источник с дверью" % (level_index+1))
	build._rotate_tile(3)
	check(int(build.snapshot().get("turns",0)) == 1,"поворот узла учитывается и сохраняется")
	var game: Node = load("res://Prologue.tscn").instantiate()
	game.save_path = "res://tests/future_chapters_save.json"
	root.add_child(game)
	await process_frame
	game.call_event_schedule.clear()
	game.story.set_value("chapter_three_complete",true)
	game.start_chapter_four()
	check(game.mode == "room" and game.chapter_computer_pending == 4,"глава 4 начинается с возвращения в комнату")
	launch_chapter_from_computer(game)
	finish_intro_to_minigame(game,"office_404")
	game.office_queue.hide()
	game.minigame_checkpoint.clear()
	game.vn.close()
	game.dialogue_open = false
	game.story.set_value("chapter_four_complete",true)
	game.start_chapter_five()
	check(game.mode == "room" and game.chapter_computer_pending == 5,"глава 5 ждёт запуска материалов с компьютера")
	launch_chapter_from_computer(game)
	finish_intro_to_minigame(game,"court_trial")
	game.court_trial.hide()
	game.minigame_checkpoint.clear()
	game.vn.close()
	game.dialogue_open = false
	game.story.set_value("chapter_five_complete",true)
	game.start_chapter_six()
	check(game.active_chapter == 6 and game.mode == "room" and game.chapter_computer_pending == 6,"глава 6 подключена через комнату после главы 5")
	launch_chapter_from_computer(game)
	check(game.flow == "chapter_six_intro","после запуска архива идёт сюжетное вступление главы 6")
	for _i in range(5):
		game.vn.advance()
		game.vn.advance()
		if game.mode == "digital_archaeology": break
	check(game.mode == "digital_archaeology" and is_instance_valid(game.digital_archaeology),"сюжетная реплика открывает мини-игру расследования")
	game._save_digital_archaeology({"found":["prototype"],"links":[],"errors":0})
	check(str(game.minigame_checkpoint.get("kind","")) == "digital_archaeology","археология записывает отдельную контрольную точку")
	var endings: Array = load("res://scripts/chapter_seven.gd").final_choice({"grok_date_completed":true,"grok_without_key":true,"gpt_boundaries":true,"artbay_contract_signed":true,"project_ownership_proven":true,"defused_tab_war":true,"affection_grok":2,"affection_gpt":2,"affection_artbay":2,"secret_protocol":true,"stamp_obtained":true})
	check(_graph_is_valid(endings),"каждый финальный маршрут ведёт к завершению диалога")
	check(_graph_is_valid(load("res://scripts/chapter_six.gd").after_archaeology({"links":3},{"artbay_trust":true})),"все три решения главы 6 ведут к завершению сцены")
	var choice_counts: Array[int] = []
	for entry in endings:
		if entry.has("choices"): choice_counts.append(entry.choices.size())
	check(not choice_counts.is_empty() and choice_counts.max() <= 4,"финальный выбор разбит на компактные страницы диалогов")
	game.story.set_value("chapter_six_complete",true)
	game.start_chapter_seven()
	check(game.mode == "room" and game.chapter_computer_pending == 7,"глава 7 тоже ждёт подхода к компьютеру")
	launch_chapter_from_computer(game)
	for _i in range(5):
		game.vn.advance()
		game.vn.advance()
		if game.mode == "last_build": break
	check(game.mode == "last_build" and is_instance_valid(game.last_build),"сюжетная реплика открывает финальную головоломку")
	for level_index in range(game.last_build.LEVELS.size()):
		game.last_build.level = level_index
		game.last_build._load_level()
		for tile in game.last_build.LEVELS[level_index].tiles:
			game.last_build.rotations[int(tile.cell)] = int(tile.rot)
		game.last_build._verify()
	check(game.flow == "chapter_seven_outro" and not game.vn.phone_chat_mode,"после четырёх схем открывается обычный новелльный финальный выбор")
	game.vn.advance()
	game.vn.advance()
	game.vn.advance()
	check(game.vn.choice_buttons.size() == 2,"первый экран финального выбора показывает две категории")
	game.vn.select_choice(1)
	game.vn.advance()
	check(game.vn.choice_buttons.size() <= 4,"страница решений проекта помещается в диалоговую панель")
	game.vn.select_choice(0)
	for _i in range(120):
		if not game.dialogue_open: break
		if not game.vn.choice_buttons.is_empty(): game.vn.select_choice(0)
		else: game.vn.advance()
	check(game.story.get_value("chapter_seven_complete") and game.story.get_value("final_ending") == "neutral","прохождение завершает главу и фиксирует выбранный финал")
	game.queue_free()
	archaeology.queue_free()
	build.queue_free()
	await process_frame
	var save_file := ProjectSettings.globalize_path("res://tests/future_chapters_save.json")
	if FileAccess.file_exists("res://tests/future_chapters_save.json"): DirAccess.remove_absolute(save_file)
	if failures.is_empty():
		print("FUTURE CHAPTERS SMOKE: PASS")
		quit(0)
	else:
		push_error("FUTURE CHAPTERS SMOKE: %d failure(s)" % failures.size())
		quit(1)
