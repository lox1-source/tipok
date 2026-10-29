extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: print("PASS: ",text)
	else:
		failures.append(text)
		push_error(text)
func drive_dialogue(game: Variant) -> void:
	var guard := 0
	while game.dialogue_open and guard < 200:
		guard += 1
		game.vn.advance()
	check(guard < 200,"Dialogue terminates")
func run() -> void:
	var model = load("res://scripts/tab_war_state.gd").new()
	model.start("grok")
	check(model.count("grok") == 4 and model.count("jbt") == 6,"Both sides have initial tabs")
	check(model.spawn_own() == 2,"Well-timed press creates two tabs")
	check(model.spawn_own() == 0,"Cooldown prevents spamming")
	model.tick(2.0)
	check(model.spawn_own() == 1,"Late press opens one tab")
	var enemy_index: int = model.cells.find(model.enemy())
	check(model.close_tab(enemy_index) and model.closed_enemy == 1,"Foreign tab close frees a slot")
	check(not model.close_tab(enemy_index),"Closing an empty slot gives no credit")
	var own_index: int = model.cells.find(model.side)
	model.close_tab(own_index)
	check(model.closed_own == 1,"Accidental own close is tracked")
	var restored = load("res://scripts/tab_war_state.gd").new()
	restored.restore(JSON.parse_string(JSON.stringify(model.snapshot())))
	check(restored.cells == model.cells and is_equal_approx(restored.elapsed,model.elapsed),"Model round-trips through JSON")
	model.tick(1.9)
	restored.tick(1.9)
	check(model.cells == restored.cells,"Restored random state reproduces the next spawn")
	var bot_wins := 0
	for side in ["grok","jbt"]:
		for seed_value in range(1,7):
			var bot = load("res://scripts/tab_war_state.gd").new()
			bot.rng.seed = seed_value
			bot.start(side)
			var close_clock := 0.0
			for step in range(1801):
				if bot.phase != "running": break
				bot.tick(0.1)
				close_clock += 0.1
				if close_clock >= 0.6:
					close_clock = 0.0
					var slot: int = bot.cells.find(bot.enemy())
					if slot >= 0: bot.close_tab(slot)
				bot.spawn_own()
			if bot.won: bot_wins += 1
	check(bot_wins == 12,"Both sides can win across 12 seeds with moderate input")
	model.start("jbt")
	for i in range(1801): model.tick(0.1)
	check(model.phase == "result" and not model.won and model.reason == "timeout","No input reaches a loss at the three-minute deadline")

	var achievements: Variant = root.get_node("AchievementManager")
	var old_path: String = achievements.save_path
	var old_unlocked: Dictionary = achievements.unlocked.duplicate(true)
	achievements.save_path = "res://tests/tab_war_achievement_temp.json"
	achievements.notifications_enabled = false
	achievements.unlocked.clear()
	var game: Variant = load("res://Prologue.tscn").instantiate()
	game.save_path = "res://tests/tab_war_progress_temp.json"
	root.add_child(game)
	game.start_chapter_three()
	drive_dialogue(game)
	check(game.mode == "tab_war" and game.tab_war.state.phase == "select","Chapter introduction opens side selection")
	check(not achievements.has_achievement("tab_war"),"Dialogue alone does not award the minigame achievement")
	for child in game.tab_war.selection.get_children():
		if child is Button and child.text.begins_with("2 ·"): child.pressed.emit(); break
	check(game.tab_war.state.side == "jbt" and game.tab_war.state.phase == "running","Side button starts a real round")
	var foreign: int = game.tab_war.state.cells.find("grok")
	game.tab_war.tile_close[foreign].pressed.emit()
	check(game.tab_war.state.closed_enemy == 1,"Cross button closes the foreign tab")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	game.tab_war._unhandled_input(key)
	check(game.tab_war.state.opened == 2,"Space creates tabs")
	game.tab_war.pause_requested.emit()
	var paused_elapsed: float = game.tab_war.state.elapsed
	await create_timer(0.2,true).timeout
	check(paused and is_equal_approx(paused_elapsed,game.tab_war.state.elapsed),"Shared pause freezes the round clock")
	game.pause_menu.close_pause()
	game.tab_war._process(0.1)
	game.save_progress()
	var cells: Array = game.tab_war.state.cells.duplicate()
	var time: float = game.tab_war.state.elapsed
	game.queue_free()
	await process_frame
	game = load("res://Prologue.tscn").instantiate()
	game.save_path = "res://tests/tab_war_progress_temp.json"
	root.add_child(game)
	game.resume_game()
	check(game.mode == "tab_war" and game.tab_war.state.cells == cells and is_equal_approx(time,game.tab_war.state.elapsed),"Continue restores the grid, role and remaining time")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/tab-war.png")
	game.tab_war.state.finish(false,"surrender")
	game.tab_war._changed()
	check(achievements.has_achievement("tab_war"),"Completed round awards the achievement")
	game.tab_war._continue_story()
	check(game.flow == "chapter_three_outro","Result returns to the chapter dialogue")
	drive_dialogue(game)
	check(game.story.get_value("chapter_three_complete") and game.story.get_value("tab_war_completed"),"Losing still allows chapter completion")
	check(game.story.get_value("defused_tab_war"),"After-match peace choice still works")
	check(game.load_progress() and game.story.get_value("tab_war_completed"),"Outcome survives the story save")
	game.queue_free()
	await process_frame
	for filename in ["res://tests/tab_war_progress_temp.json",achievements.save_path]:
		if FileAccess.file_exists(filename): DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	achievements.save_path = old_path
	achievements.unlocked = old_unlocked
	achievements.notifications_enabled = true
	print("TAB WAR RESULT: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
