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
	var settings: Node = root.get_node("SettingsManager")
	var original_path: String = settings.settings_path
	var original_fullscreen: bool = settings.fullscreen
	var original_resolution: Vector2i = settings.resolution
	var test_path := "res://tests/display_settings_test.cfg"
	settings.settings_path = test_path
	settings.set_fullscreen(true)
	await process_frame
	await process_frame
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen applies without restart")
	settings.set_fullscreen(false)
	settings.set_resolution(Vector2i(960, 540))
	await process_frame
	await process_frame
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Windowed mode applies without restart")
	check(DisplayServer.window_get_size() == Vector2i(960, 540), "Window resolution applies without restart")
	settings.set_resolution(original_resolution)
	settings.set_fullscreen(original_fullscreen)
	settings.settings_path = original_path
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("DISPLAY RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
