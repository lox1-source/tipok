extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/" + name)

func run() -> void:
	var game: Node = load("res://Prologue.tscn").instantiate()
	game.save_path = "res://tests/future_chapters_capture_save.json"
	root.add_child(game)
	await process_frame
	game.start_digital_archaeology()
	await capture("chapter-six-archaeology.png")
	game.start_last_build()
	await capture("chapter-seven-routing.png")
	game.last_build.hide()
	game.digital_archaeology.hide()
	var values := {"grok_date_completed":true,"grok_without_key":true,"gpt_boundaries":true,"artbay_contract_signed":true,"project_ownership_proven":true,"defused_tab_war":true,"affection_grok":2,"affection_gpt":2,"affection_artbay":2,"secret_protocol":true,"stamp_obtained":true}
	game.play_chapter_scene("chapter_seven_outro",load("res://scripts/chapter_seven.gd").final_choice(values))
	game.vn.advance()
	game.vn.advance()
	game.vn.advance()
	await capture("chapter-seven-final-choice.png")
	game.queue_free()
	await process_frame
	var save_path := "res://tests/future_chapters_capture_save.json"
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit()
