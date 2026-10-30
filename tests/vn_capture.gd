extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://Prologue.tscn").instantiate()
	game.save_path = "res://tests/vn_capture_progress.json"
	root.add_child(game)
	await process_frame
	game.start_vn_demo()
	if game.vn.phone_chat_mode:
		push_error("Диалог с ЖБТ и Гроком ошибочно переключился в режим телефона")
		quit(1)
		return
	await process_frame
	game.vn.advance()
	for _i in range(24):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/vn-demo.png")
	game.vn.advance()
	await process_frame
	game.vn.advance()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/vn-demo-choices.png")
	game.vn.select_choice(1)
	game.vn.advance()
	for _i in range(24):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/vn-demo-grok.png")
	DirAccess.remove_absolute(game.save_path)
	quit(0)
