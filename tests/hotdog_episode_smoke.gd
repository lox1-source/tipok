extends SceneTree

const SAVE := "res://tests/hotdog_episode_temp_save.json"
const ACHIEVEMENTS := "res://tests/hotdog_episode_temp_achievements.json"
var failures: Array[String] = []
var achievement_manager: Variant
var previous_achievement_path: String
var previous_achievements: Dictionary

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ",message)
	else:
		failures.append(message)
		push_error(message)

func make_game() -> Variant:
	var game: Variant = load("res://Prologue.tscn").instantiate()
	game.save_path = SAVE
	root.add_child(game)
	return game

func drive(game: Variant) -> void:
	var guard := 0
	while game.dialogue_open and guard < 100:
		guard += 1
		game.vn.advance()
	check(guard < 100,"Episode dialogue terminates")

func run() -> void:
	achievement_manager = root.get_node("AchievementManager")
	previous_achievement_path = achievement_manager.save_path
	previous_achievements = achievement_manager.unlocked.duplicate(true)
	achievement_manager.save_path = ACHIEVEMENTS
	achievement_manager.notifications_enabled = false
	achievement_manager.unlocked.clear()
	var game: Variant = make_game()
	await process_frame
	game._reset_progress()
	game.intro_seen = true
	game.story.set_value("grok_date_completed",true)
	game.story.set_value("artbay_intro_seen",true)
	game.story.set_value("hotdog_first_visit_seen",true)
	game.story.set_value("hotdog_order_stage",1)
	game._set_active_chapter(2)
	game.start_hotdog_master(true)
	check(game.hotdog_master.order_overlay.visible,"Order menu is visible after the first chat")
	var place: Variant = game.hotdog_master
	place.player_position = Vector2(458,360)
	place._update_depth_order()
	check(place.player.z_index < place.artrey_sprite.z_index,"Grat is behind Artrey when walking above him")
	place.player_position = Vector2(458,398)
	place._update_depth_order()
	check(place.player.z_index > place.artrey_sprite.z_index,"Grat is in front of Artrey when walking below him")
	for point in [Vector2(-200,-200),Vector2(1400,900),Vector2(42,402),Vector2(918,340)]:
		var limited: Vector2 = place._constrain_to_walk_area(point)
		check(limited.x >= 42.0 and limited.x <= 918.0 and limited.y >= 340.0 and limited.y <= 402.0,"Walk boundary contains %s" % str(point))
	check(game.save_progress(),"Kiosk order checkpoint saves")
	game.queue_free()
	await process_frame
	game = make_game()
	await process_frame
	game.resume_game()
	check(int(game.story.get_value("hotdog_order_stage",0)) == 1 and game.hotdog_master.order_overlay.visible,"Loading the kiosk restores the pending order")
	game.hotdog_master._order_item_pressed(1)
	check(game.flow == "hotdog_taste" and int(game.story.get_value("hotdog_order_stage",0)) == 2,"Order starts tasting and saves its stage")
	check(game.story.get_value("hotdog_order_choice","") == "double","Double hot dog choice is saved")
	game.queue_free()
	await process_frame
	game = make_game()
	await process_frame
	check(game.dialogue_resume.get("flow","") == "hotdog_taste","Mid-scene save retains tasting dialogue")
	game.resume_game()
	check(game.flow == "hotdog_taste" and game.dialogue_open,"Tasting dialogue resumes without reordering")
	check(game.story.get_value("hotdog_order_choice","") == "double","Loading keeps the selected hot dog")
	var guard := 0
	while game.flow == "hotdog_taste" and game.dialogue_open and guard < 30:
		guard += 1
		game.vn.advance()
	check(guard < 30,"Tasting ends and switches scenes")
	check(game.flow == "hotdog_poisoning" and game.dialogue_open,"Poisoning follows tasting")
	game.queue_free()
	await process_frame
	game = make_game()
	await process_frame
	game.resume_game()
	check(game.flow == "hotdog_poisoning" and game.dialogue_open,"Poisoning dialogue resumes from save")
	drive(game)
	check(int(game.story.get_value("hotdog_order_stage",0)) == 4,"Episode completion persists")
	game.queue_free()
	await process_frame
	game = make_game()
	await process_frame
	check(int(game.story.get_value("hotdog_order_stage",0)) == 4,"Completed episode stays complete after loading")
	for path in [SAVE,ACHIEVEMENTS]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	achievement_manager.unlocked = previous_achievements
	achievement_manager.save_path = previous_achievement_path
	achievement_manager.notifications_enabled = true
	game.queue_free()
	await process_frame
	print("HOTDOG EPISODE RESULT: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
