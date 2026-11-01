extends SceneTree

var failures: Array[String] = []
var archive_result: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error(description)

func _on_archive_finished(result: Dictionary) -> void:
	archive_result = result

func run() -> void:
	var manager: Variant = root.get_node("AchievementManager")
	var original_unlocked: Dictionary = manager.unlocked.duplicate(true)
	var original_path: String = manager.save_path
	var original_notifications: bool = manager.notifications_enabled
	var suffix := str(Time.get_ticks_usec())
	var achievement_path := "res://tests/achievement_reachability_%s.json" % suffix
	var game_path := "res://tests/achievement_reachability_game_%s.json" % suffix
	manager.save_path = achievement_path
	manager.notifications_enabled = false
	manager.unlocked.clear()

	var game: Node = load("res://Prologue.tscn").instantiate()
	game.save_path = game_path
	root.add_child(game)
	await process_frame
	game.call_event_schedule.clear()

	var queue_state: RefCounted = load("res://scripts/office_queue_state.gd").new()
	check(not manager.has_achievement("ministry_complete") and not manager.has_achievement("ministry_stamp"), "награды Министерства закрыты до очереди")
	for index in range(queue_state.CASES.size()):
		queue_state.select_ticket(index)
		queue_state.toggle_document(str(queue_state.CASES[index].document))
		check(queue_state.submit(str(queue_state.CASES[index].window)), "очередь принимает правильный талон %d" % (index + 1))
	check(queue_state.finished, "очередь завершается после трёх одобренных дел")
	game._finish_office_queue(queue_state.result("legal"))
	check(manager.has_achievement("ministry_complete"), "завершение очереди выдаёт «Бюрократия побеждена»")
	check(manager.has_achievement("ministry_stamp"), "получение печати выдаёт «Печать решает всё»")
	manager.reset_achievement("ministry_stamp")
	game._finish_office_queue(queue_state.result("leave"))
	check(not manager.has_achievement("ministry_stamp"), "уход без печати не выдаёт награду за неё")

	var trial_state: RefCounted = load("res://scripts/court_trial_state.gd").new()
	for index in range(trial_state.ROUNDS.size()):
		trial_state.select_card(str(trial_state.current_round().correct))
		check(trial_state.submit(), "суд принимает правильную улику %d" % (index + 1))
	check(trial_state.finished, "суд завершается после трёх пунктов")
	game._finish_court_trial(trial_state.result())
	check(manager.has_achievement("printer_judge"), "завершение суда выдаёт «Судья — принтер»")

	var archive: Control = load("res://scripts/digital_archaeology.gd").new()
	root.add_child(archive)
	archive.finished.connect(_on_archive_finished)
	archive.open()
	for index in range(0, 6, 2):
		archive._inspect(index)
		archive._inspect(index + 1)
		archive._connect()
	check(int(archive_result.get("links", 0)) == 3 and int(archive_result.get("errors", -1)) == 0, "архив допускает восстановление без ошибок")
	game._finish_digital_archaeology(archive_result)
	check(manager.has_achievement("digital_detective"), "восстановление проекта выдаёт «Цифровой детектив»")
	check(manager.has_achievement("no_extra_files"), "чистое восстановление выдаёт «Ни одного лишнего файла»")
	manager.reset_achievement("no_extra_files")
	var archive_with_error: Dictionary = archive_result.duplicate(true)
	archive_with_error.errors = 1
	game._finish_digital_archaeology(archive_with_error)
	check(not manager.has_achievement("no_extra_files"), "восстановление с ошибкой не выдаёт награду за чистый проход")

	manager.reset_achievement("jbt_boundaries")
	game.flow = "chapter_three_intro"
	game._on_achievement_dialogue_choice("c3_respect")
	game.flow = "chapter_five_outro"
	game._on_achievement_dialogue_choice("c5_jbt_yes")
	game.story.set_value("lied_in_court", true)
	game._close_dialogue()
	check(not manager.has_achievement("jbt_boundaries"), "ложь в суде закрывает награду за уважение границ ЖБТ")
	game.flow = "chapter_five_outro"
	game.story.set_value("lied_in_court", false)
	game._close_dialogue()
	check(manager.has_achievement("jbt_boundaries"), "уважительный маршрут ЖБТ выдаёт «Границы соблюдены»")

	manager.unlocked["all_endings"] = "test"
	manager.unlocked["platinum"] = "test"
	manager.unlocked["neutral_ending"] = "test"
	check(manager.reset_achievement("neutral_ending"), "DEV сбрасывает отдельную концовку")
	check(not manager.has_achievement("all_endings") and not manager.has_achievement("platinum"), "сброс концовки также закрывает зависимые награды")
	game.story.decisions["ending_achievement_neutral"] = "neutral"
	game.story.set_value("final_ending", "neutral")
	game.show_chapter_seven_ending()
	check(manager.has_achievement("neutral_ending"), "повторный просмотр финала восстанавливает сброшенную награду")

	manager.unlocked = original_unlocked
	manager.save_path = original_path
	manager.notifications_enabled = original_notifications
	for path in [achievement_path, game_path]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute_path)
	archive.queue_free()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("ACHIEVEMENT REACHABILITY SMOKE: PASS")
		quit(0)
	else:
		push_error("ACHIEVEMENT REACHABILITY SMOKE: %d failure(s)" % failures.size())
		quit(1)
