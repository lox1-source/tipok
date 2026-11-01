extends SceneTree
var failures := 0
func check(ok: bool, label: String):
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func _initialize():
	call_deferred("run")
func run():
	var scene = load("res://Prologue.tscn")
	var path := "res://tests/transfer_resume_temp.json"
	var game = scene.instantiate()
	game.save_path = path
	root.add_child(game)
	await process_frame
	game.start_digital_archaeology()
	game.digital_archaeology._inspect(0)
	game.digital_archaeology._inspect(1)
	game.digital_archaeology._connect()
	check(game.save_progress(), "Save chapter 6 to disk")
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	game.save_path = path
	root.add_child(game)
	await process_frame
	check(game.load_progress(), "Reload chapter 6 in new scene")
	game.resume_game()
	check(game.mode == "digital_archaeology" and game.digital_archaeology.links.size() == 1, "Chapter 6 evidence link survives reload")
	game.start_last_build()
	game.last_build._rotate_tile(3)
	var rotations: Array = game.last_build.rotations.duplicate()
	check(game.save_progress(), "Save chapter 7 to disk")
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	game.save_path = path
	root.add_child(game)
	await process_frame
	check(game.load_progress(), "Reload chapter 7 in new scene")
	game.resume_game()
	check(game.mode == "last_build" and game.last_build.rotations == rotations and game.last_build.turns == 1, "Chapter 7 rotations and turns survive reload")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if failures == 0 else 1)
