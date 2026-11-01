extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error(description)

func run() -> void:
	# Keep the user's save and achievement files untouched.
	root.get_node("SaveManager").save_path = "user://names_startup_smoke_nonexistent.json"
	root.get_node("AchievementManager").unlocked["first_launch"] = true
	var names = preload("res://scripts/display_names.gd")
	check(names.normalize("Грат и Артреем") == "4fr и Артбеем", "old saved dialogue names are migrated for display")
	check(names.normalize("артрей, грат, переиграть") == "артбей, 4fr, переиграть", "lowercase names change without altering other words")
	var dialogue: Control = preload("res://scripts/vn_dialogue.gd").new()
	root.add_child(dialogue)
	dialogue.set_phone_chat_mode(true)
	dialogue.start([{"speaker_id":"grat", "speaker":"Грат", "text":"Артрей ответил Грату."}])
	check(dialogue.get("_speaker_label").text == "Фотик", "old saved chat shows the sender as Фотик")
	check(dialogue.get("_text").text == "Артбей ответил Фотик.", "old saved chat body uses new names")
	dialogue.queue_free()
	await process_frame
	var intro: Node = load("res://Disclaimer.tscn").instantiate()
	root.add_child(intro)
	current_scene = intro
	await process_frame
	var buttons: Array[Node] = intro.find_children("*", "Button", true, false)
	check(buttons.size() == 1 and buttons[0].text == "Продолжить", "startup disclaimer has one continue button")
	check(intro.find_children("*", "Label", true, false).any(func(label): return label.text.contains("Все персонажи вымышлены.")), "disclaimer text appears before menu")
	buttons[0].pressed.emit()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.name == "MainMenu", "disclaimer opens main menu")
	if current_scene != null and current_scene.name == "MainMenu":
		current_scene._new_game_pressed()
		await process_frame
		await process_frame
		check(current_scene != null and current_scene.name == "Prologue", "new game opens prologue")
	if current_scene != null and current_scene.name == "Prologue":
		current_scene.pause_menu._return_to_main_menu()
		await process_frame
		await process_frame
		check(current_scene != null and current_scene.name == "MainMenu", "return from game opens main menu")
	print("RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
