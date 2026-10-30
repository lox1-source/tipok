extends SceneTree

var save_manager: Node
var capture_save := "res://tests/ui_capture_save.json"

func _initialize() -> void:
	call_deferred("run")

func capture(file_name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://screenshots/" + file_name)

func finish_dialogue(game: Node) -> void:
	var guard := 0
	while game.dialogue_open and guard < 30:
		game._advance_dialogue()
		guard += 1

func run() -> void:
	save_manager = root.get_node("SaveManager")
	var original_save_path: String = save_manager.save_path
	save_manager.save_path = capture_save
	save_manager.clear_save()
	var menu: Node = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	await capture("main-menu.png")
	menu._open_achievements()
	await capture("achievements-window.png")
	menu._close_achievements()
	menu._open_dev_chapter_picker()
	await capture("dev-chapter-window.png")
	menu._close_dev_chapter_picker()
	menu._exit_pressed()
	await capture("main-menu-exit-confirm.png")
	menu.exit_confirmation.hide()
	menu._open_settings()
	await capture("main-menu-settings.png")
	menu.queue_free()
	await process_frame
	save_manager.set_launch_mode("new")
	var game: Node = load("res://Prologue.tscn").instantiate()
	game.save_path = capture_save
	root.add_child(game)
	await process_frame
	finish_dialogue(game)
	await process_frame
	game.pause_menu.open_pause()
	await capture("pause-menu.png")
	game.pause_menu._exit_pressed()
	await capture("pause-exit-confirm.png")
	game.pause_menu.exit_confirmation.hide()
	game.pause_menu._open_settings()
	await capture("pause-settings.png")
	paused = false
	game.queue_free()
	await process_frame
	save_manager.clear_save()
	save_manager.save_path = original_save_path
	quit()
