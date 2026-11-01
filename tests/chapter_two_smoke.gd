extends SceneTree
var failures: Array[String] = []
var game: Variant
var choices := {"hub":"bios_date","compliment":"smart","dream":"dream_honest","vulnerable":"care","manual":"read_manual","dish":"paste_ram","decorate":"dinner_lights","share":"share_yes","defender_choice":"defender_slow","offer":"artrey_terms"}

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if value: print("PASS: ",message)
	else:
		failures.append(message)
		push_error(message)

func drive() -> void:
	var guard := 0
	while game.dialogue_open and guard < 350:
		guard += 1
		if game.vn.is_revealing(): game.vn.advance(); continue
		var entry: Dictionary = game.vn.current_entry()
		var options: Array = entry.get("choices",[])
		if options.is_empty(): game.vn.advance(); continue
		var desired: String = str(choices.get(str(entry.get("key","")), ""))
		var selected := 0
		for i in range(options.size()):
			if str(options[i].get("id","")) == desired: selected = i
		game.vn.select_choice(selected)
	check(guard < 350,"Dialogue graph terminates without a loop")

func run() -> void:
	var achievements: Variant = root.get_node("AchievementManager")
	var previous_path: String = achievements.save_path
	var previous_unlocked: Dictionary = achievements.unlocked.duplicate(true)
	achievements.save_path = "res://tests/chapter_two_achievement_temp.json"
	achievements.notifications_enabled = false
	achievements.unlocked.clear()
	game = load("res://Prologue.tscn").instantiate()
	game.save_path = "res://tests/chapter_two_temp_save.json"
	root.add_child(game)
	await process_frame
	game._reset_progress()
	game.call_event_schedule.clear()
	game.intro_seen = true
	game.step = 8
	game.chapter_one_stage = 2
	game.start_chapter_two()
	var texts := ""
	for entry in game.vn.entries: texts += str(entry.text)
	check("Это точно продукты" in texts and "Прояви фантазию" in texts,"Dinner includes the formerly skipped lines")
	# Advance to serving, then verify award before the end of the date.
	var guard := 0
	while str(game.vn.current_entry().get("key","")) != "serve" and guard < 250:
		guard += 1
		if game.vn.is_revealing(): game.vn.advance(); continue
		var entry: Dictionary = game.vn.current_entry()
		var options: Array = entry.get("choices",[])
		if options.is_empty(): game.vn.advance(); continue
		var selected := 0
		for i in range(options.size()):
			if str(options[i].get("id","")) == str(choices.get(str(entry.get("key","")),"")): selected = i
		game.vn.select_choice(selected)
	check(achievements.has_achievement("amd_chef") and not game.story.get_value("grok_date_completed"),"AMD unlocks at dinner, before the date finishes")
	check(game.story.get_value("dinner_read_manual"),"Manual choice is stored")
	check(game.story.get_value("grok_without_key"),"Personal scene establishes interest beyond the model")
	drive()
	check(game.story.get_value("grok_date_completed") and game.story.get_value("key_txt_received"),"Date and key.txt are saved facts")
	check(game.mode == "hotdog_master","After BIOS the kiosk opens")
	game.hotdog_master.player_position = Vector2(458,405)
	game.hotdog_master._update_nearest()
	game.hotdog_master._interact()
	drive()
	check(game.story.get_value("artbay_intro_seen") and not game.chapter_two_complete,"Artrey appears before chapter 2 completes")
	check(int(game.story.get_value("hotdog_order_stage",0)) == 1 and game.hotdog_master.order_overlay.visible,"First chat opens the hot-dog order")
	game.hotdog_master._order_item_pressed(0)
	check(game.flow == "hotdog_taste" and game.story.get_value("hotdog_order_choice","") == "single","Single hot dog starts its own tasting scene")
	drive()
	check(int(game.story.get_value("hotdog_order_stage",0)) == 4,"Tasting and poisoning scenes finish once")
	check(game.minigame_checkpoint.get("kind","") == "brainstorm","Cooperation opens the brainstorm game")
	game.Early.finish_brainstorm(game,["prototype","story","test"],"prototype")
	drive()
	check(game.chapter_two_complete,"Chapter 2 finishes after Artrey and brainstorm")
	check(achievements.has_achievement("artbay_first_chat") and achievements.has_achievement("artbay_brainstorm"),"Artrey achievements come from completed scenes")
	check(game.story.get_value("brainstorm_first","") == "prototype","The first task in the plan persists")
	var before: int = int(game.story.get_value("affection_grok"))
	game.flow = "chapter_two"
	game.Early.on_choice(game,"care")
	check(int(game.story.get_value("affection_grok")) == before,"Repeating a choice cannot farm affection")
	game.flow = ""
	game._reset_progress()
	game.call_event_schedule.clear()
	game.intro_seen = true
	game.step = 8
	game.chapter_one_stage = 2
	achievements.unlocked.clear()
	choices["dish"] = "safe_food"
	choices["vulnerable"] = "only_key"
	choices["offer"] = "artrey_refuse"
	game.start_chapter_two()
	drive()
	check(game.mode == "hotdog_master","The second route also reaches the kiosk")
	game.hotdog_master.player_position = Vector2(458,405)
	game.hotdog_master._update_nearest()
	game.hotdog_master._interact()
	drive()
	check(int(game.story.get_value("hotdog_order_stage",0)) == 1,"Refusal route still reaches the order")
	game.hotdog_master._order_item_pressed(3)
	check(game.story.get_value("hotdog_order_choice","") == "signature","Signature hot dog is selectable")
	drive()
	check(game.chapter_two_complete and game.story.get_value("dinner_finished"),"Safe dinner and refusing collaboration still finish the chapter")
	check(int(game.story.get_value("hotdog_order_stage",0)) == 4,"Refusal route records the completed kiosk episode")
	check(not achievements.has_achievement("amd_chef"),"Safe food does not grant the thermal-paste achievement")
	check(not game.story.get_value("grok_without_key"),"Instrumental answer does not establish personal interest")
	for path in [game.save_path,achievements.save_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	achievements.unlocked = previous_unlocked
	achievements.save_path = previous_path
	achievements.notifications_enabled = true
	game.queue_free()
	await process_frame
	print("CHAPTER TWO RESULT: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
