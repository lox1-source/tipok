extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game=load("res://Prologue.tscn").instantiate()
	game.save_path="res://tests/desktop_test_progress.json"
	root.add_child(game)
	game.intro_seen=true
	game.step=1
	game.refresh_goal()
	game.show_desktop()
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/desktop.png")
	var cases := [["project",1,"dialogue"],["blender",2,"app"],["jbt",3,"dialogue"],["search",4,"app"],["notebook",4,"notebook"],["grok",7,"dialogue"]]
	var failed := false
	for item in cases:
		game.dialogue_open=false
		game.dialogue_panel.hide()
		game.step=item[1]
		game.show_desktop()
		var button=game.computer_panel.get_node("Shortcut_"+item[0])
		button.pressed.emit()
		if game.mode!=item[2]:
			failed=true
			push_error("Shortcut failed: "+item[0])
		else:
			print("PASS: shortcut ",item[0])
	game.queue_free()
	await process_frame
	print("DESKTOP RESULT: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
