extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(file_name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/" + file_name)

func run() -> void:
	var game: Node = load("res://Prologue.tscn").instantiate()
	var save_path := "res://tests/phone_chat_capture_progress.json"
	game.save_path = save_path
	root.add_child(game)
	await process_frame
	game.show_friends_chat()
	await capture("phone-friends-chat.png")
	var entries: Array = load("res://scripts/early_content.gd").artrey_intro()
	game.flow = "chapter_two_artrey"
	game._start_dialogue_entries(entries, 1)
	if not game.vn.phone_chat_mode:
		push_error("Диалог с Артреем должен открываться в стиле телефона")
		quit(1)
		return
	for _i in range(30): await process_frame
	await capture("phone-artrey-message.png")
	game.vn.advance()
	game._start_dialogue_entries(entries, 10)
	game.vn.advance()
	await capture("phone-artrey-choices.png")
	game.vn.close()
	game.dialogue_open = false
	game.call_event_schedule_initialized = true
	game._start_call_event("call_drx", 2)
	await capture("phone-call-discord.png")
	game.vn.close()
	game.dialogue_open = false
	game.call_event_pending = ""
	game._start_call_event("call_tables", 3)
	await capture("phone-call-regular.png")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit()
