extends SceneTree
var failures: Array[String] = []
var game: Variant
func _initialize() -> void: call_deferred("run")
func check(chapter: int, context: String) -> void:
	game.refresh_goal()
	var expected := "ГРАТ / ПРОЛОГ" if chapter == 0 else "ГРАТ / ГЛАВА %d" % chapter
	if game.active_chapter == chapter and game.chapter_title.text == expected: print("PASS: ",context)
	else:
		failures.append(context)
		push_error(context+" -> "+str(game.chapter_title.text))
func reload_game() -> void:
	game.save_progress()
	var path: String = game.save_path
	game.queue_free()
	await process_frame
	game = load("res://Prologue.tscn").instantiate()
	game.save_path = path
	root.add_child(game)
	game.resume_game()
func run() -> void:
	var manager: Variant = root.get_node("AchievementManager")
	var original_path: String = manager.save_path
	var original_unlocked: Dictionary = manager.unlocked.duplicate(true)
	manager.save_path = "res://tests/chapter_label_ach_temp.json"
	manager.notifications_enabled = false
	game = load("res://Prologue.tscn").instantiate()
	game.save_path = "res://tests/chapter_label_temp.json"
	root.add_child(game)
	game._reset_progress()
	check(0,"New game shows prologue")
	game.intro_seen = true
	game.step = 8
	game.start_chapter_one()
	check(1,"Chapter 1 introduction shows chapter 1 immediately")
	await reload_game()
	check(1,"Chapter 1 dialogue reload keeps chapter 1")
	game.vn.close()
	game.dialogue_open = false
	game.flow = ""
	game.chapter_one_stage = 2
	game.show_chapter_one_checkpoint()
	check(1,"Chapter 1 completion shows chapter 1")
	game.start_chapter_two()
	check(2,"BIOS shows chapter 2 before its completion flag exists")
	await reload_game()
	check(2,"BIOS checkpoint reload keeps chapter 2")
	game.story.set_value("grok_date_completed",true)
	game.start_artrey()
	check(2,"Artrey postscript remains in chapter 2")
	game.chapter_two_complete = true
	game.start_chapter_three()
	check(3,"Chapter 3 introduction stays chapter 3 despite chapter 2 completion")
	await reload_game()
	check(3,"Chapter 3 introduction reload keeps chapter 3")
	game.start_tab_war()
	check(3,"Tab war belongs to chapter 3")
	await reload_game()
	check(3,"Minigame reload keeps chapter 3")
	game.tab_war.choose_side("grok")
	game.tab_war.state.finish(false,"surrender")
	game.tab_war._changed()
	game.tab_war._continue_story()
	check(3,"Postgame dialogue shows chapter 3")
	await reload_game()
	check(3,"Postgame dialogue reload shows chapter 3")
	game.vn.close()
	game.dialogue_open = false
	game.flow = ""
	game.story.set_value("chapter_three_complete",true)
	game.show_chapter_three_ending()
	game._close_computer()
	check(3,"Room after chapter 3 retains chapter 3")
	game.show_desktop()
	game._open_app("grok")
	check(3,"Opening Grok after chapter 3 does not fall back to chapter 2")
	game.show_chapter_one_checkpoint()
	check(1,"Revisiting chapter 1 overrides later completion flags")
	game.show_chapter_two_ending()
	check(2,"Revisiting chapter 2 overrides chapter 3 completion")
	await reload_game()
	check(2,"Revisited chapter 2 persists through reload")
	game.show_ending()
	check(0,"Prologue summary shows prologue even after later chapters")
	game.dialogue_resume = {"flow":"chapter_three_outro"}
	game._restore_active_chapter({})
	check(3,"Legacy dialogue checkpoint identifies chapter 3")
	game.dialogue_resume.clear()
	game._restore_active_chapter({})
	check(3,"Legacy completed save identifies chapter 3")
	game._reset_progress()
	check(0,"Restart resets chapter label")
	game.queue_free()
	await process_frame
	for path in ["res://tests/chapter_label_temp.json",manager.save_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	manager.save_path = original_path
	manager.unlocked = original_unlocked
	manager.notifications_enabled = true
	print("CHAPTER LABEL RESULT: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
