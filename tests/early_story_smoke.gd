extends SceneTree
var failures: Array[String] = []
var path := "res://tests/early_story_temp.json"
var game: Variant

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if value: print("PASS: ",message)
	else:
		failures.append(message)
		push_error(message)
func make_game() -> Variant:
	var instance: Variant = load("res://Prologue.tscn").instantiate()
	instance.save_path = path
	root.add_child(instance)
	return instance
func click(text: String) -> void:
	for child in game.app_panel.get_children():
		if child is Button and child.text == text:
			child.pressed.emit()
			return
	check(false,"Button exists: "+text)
func finish() -> void:
	var guard := 0
	while game.dialogue_open and guard < 350:
		guard += 1
		if game.vn.is_revealing(): game.vn.advance(); continue
		var options: Array = game.vn.current_entry().get("choices",[])
		if options.is_empty(): game.vn.advance(); continue
		var selected := 0
		for i in range(options.size()):
			var id: String = str(options[i].get("id",""))
			if id in ["purpose_person","friend","jbt_room_respect","bios_date","care","safe_food","artrey_refuse"] or id.ends_with("_honest"): selected = i
		game.vn.select_choice(selected)
	check(guard < 350,"Conversation finishes")
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if game.dialogue_open and game.vn.is_revealing(): game.vn.advance()
	if name == "early-artrey":
		game.vn.advance()
		if game.vn.is_revealing(): game.vn.advance()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+name+".png")

func run() -> void:
	var achievements: Variant = root.get_node("AchievementManager")
	var old_path: String = achievements.save_path
	var old_unlocked: Dictionary = achievements.unlocked.duplicate(true)
	achievements.save_path = "res://tests/early_story_achievements_temp.json"
	achievements.notifications_enabled = false
	achievements.unlocked.clear()
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game = make_game()
	game._reset_progress()
	game.intro_seen = true
	game.step = 2
	game.Early.show_blender_game(game)
	click("Вставить команду в поиск")
	check(game.minigame_checkpoint.stage == 0 and game.minigame_checkpoint.errors == 1,"Wrong Blender action allows another attempt")
	click("Открыть Blender")
	await capture("early-blender")
	check(game.minigame_checkpoint.stage == 1,"Correct action advances the Blender sequence")
	game.queue_free()
	await process_frame
	game = make_game()
	game.resume_game()
	check(game.minigame_checkpoint.stage == 1 and game.mode == "app","Reload restores the minigame step")
	click("Меш: цилиндр")
	click("Уменьшить до масштаба двери")
	click("glTF Binary (.glb)")
	click("training_key.glb — меш найден")
	finish()
	check(game.story.get_value("learned_blender") and game.step == 3,"Successful model training preserves the prologue progression")
	check(achievements.has_achievement("first_model_game"),"Model minigame unlocks its achievement")
	game.step = 8
	game.show_blender()
	click("Посмотреть на куб")
	finish()
	check(game.step == 8,"Revisiting the cube does not roll back completed prologue progress")
	game.show_project_files()
	click("Создать резервную копию")
	check(game.story.get_value("game_backup_created") and not game.story.get_value("project_backup_snapshot",{}).is_empty(),"Project backup stores a separate narrative snapshot")
	game.save_progress()
	game.queue_free()
	await process_frame
	game = make_game()
	check(game.story.get_value("game_backup_created") and game.story.get_value("learned_blender"),"Backup and learned skills survive JSON round trip")

	# Save in a branching dialogue and resume the exact reaction.
	game.step = 8
	game.start_chapter_one()
	while game.vn.current_entry().get("key","") != "purpose": game.vn.advance()
	if game.vn.is_revealing(): game.vn.advance()
	game.vn.select_choice(1)
	var saved_key: String = str(game.vn.current_entry().get("key",""))
	var saved_affection: int = int(game.story.get_value("affection_grok"))
	game.queue_free()
	await process_frame
	game = make_game()
	game.resume_game()
	check(game.flow == "chapter_one_intro" and game.vn.current_entry().get("key","") == saved_key,"Reload resumes the selected reaction instead of the first line")
	check(int(game.story.get_value("affection_grok")) == saved_affection,"Reload preserves affection without showing its value to the player")
	finish()
	check(game.chapter_one_stage == 1,"Expanded introduction reaches room investigation")
	for object_id in ["bed","poster","wardrobe","pizza"]:
		game.nearby_object = object_id
		game._interact()
		finish()
	check(game.chapter_one_stage == 2 and game.chapter_one_evidence.size() == 4,"Four evidence conversations finish chapter 1")
	var affection_before: int = int(game.story.get_value("affection_grok"))
	game.flow = "chapter_one_intro"
	game.Early.on_choice(game,"purpose_person")
	check(int(game.story.get_value("affection_grok")) == affection_before,"Replaying the same relationship decision grants no extra points")
	game.flow = ""
	game.confirm_restart()
	click("Начать заново")
	check(game.chapter_one_stage == 0 and not game.chapter_two_complete and game.chapter_one_evidence.is_empty(),"Internal restart clears both chapters")
	check(game.story.decisions.is_empty() and not game.story.get_value("game_backup_created"),"Internal restart clears choices and narrative backup")
	finish()
	for object_id in ["bed","poster","wardrobe","pizza"]:
		game.nearby_object = object_id
		game._interact()
		finish()
	check(game.story.get_value("exploration_three_seen") and game.story.get_value("old_project_notes_found"),"Room exploration reveals the extra conversation and old project")
	check(game.story.get_value("gpt_trust") and game.story.get_value("gpt_boundaries"),"Respectful answer establishes JBT trust and boundaries")
	await capture("early-room")

	# Legacy save: BIOS finished, no new story state existed.
	var legacy: Dictionary = game._save_data()
	legacy.erase("story")
	legacy.erase("dialogue_checkpoint")
	legacy.erase("minigame_checkpoint")
	legacy.chapter_two_complete = true
	legacy.chapter_one_stage = 2
	legacy.step = 8
	legacy.intro_seen = true
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	game.queue_free()
	await process_frame
	game = make_game()
	game.resume_game()
	check(game.story.get_value("grok_date_completed") and not game.chapter_two_complete,"Legacy BIOS completion is preserved with a new postscript pending")
	game.start_chapter_two()
	check(game.flow == "chapter_two_artrey","Legacy continuation opens Artrey, not the entire BIOS date")
	await capture("early-artrey")
	finish()
	check(game.chapter_two_complete and not game.story.get_value("brainstorm_completed"),"Declining cooperation completes the chapter without forcing the minigame")
	game.Early.show_brainstorm(game)
	click("□ Закончить короткий пролог")
	click("□ История и заметная механика")
	click("□ Проверить сборку с другом")
	check(game.minigame_checkpoint.picks.size() == 3,"Brainstorm buttons select three actual ideas")
	click("Определить первый шаг →")
	await capture("early-brainstorm")
	click("Закончить короткий пролог")
	finish()
	check(game.story.get_value("brainstorm_completed"),"Brainstorm remains available after declining the first offer")
	game.queue_free()
	await process_frame
	for filename in [path,achievements.save_path]:
		if FileAccess.file_exists(filename): DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	achievements.save_path = old_path
	achievements.unlocked = old_unlocked
	achievements.notifications_enabled = true
	print("EARLY STORY RESULT: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
