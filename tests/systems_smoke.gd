extends SceneTree

var failures: Array[String] = []
var test_save_path := "res://tests/test_system_save_%d.json" % Time.get_ticks_usec()
var test_settings_path := "res://tests/test_settings_%d.cfg" % Time.get_ticks_usec()
var audio_manager: Node
var save_manager: Node
var settings_manager: Node

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error(description)

func key_event(key: int, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	return event

func finish_dialogue(game: Node) -> void:
	var guard := 0
	while game.dialogue_open and guard < 30:
		game._advance_dialogue()
		guard += 1
	check(guard < 30, "Dialogue used by system test terminates")

func playing_music_players() -> int:
	var count := 0
	for child in audio_manager.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("Music") and child.playing:
			count += 1
	return count

func run() -> void:
	audio_manager = root.get_node("AudioManager")
	save_manager = root.get_node("SaveManager")
	settings_manager = root.get_node("SettingsManager")
	var original_save_path: String = save_manager.save_path
	var original_settings_path: String = settings_manager.settings_path
	save_manager.save_path = test_save_path
	settings_manager.settings_path = test_settings_path
	save_manager.clear_save()
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://MainMenu.tscn", "Project starts in the main menu")
	for path in ["res://assets/audio/main_menu.ogg", "res://assets/audio/room.ogg", "res://assets/audio/dialogues.ogg", "res://assets/audio/walk.ogg", "res://assets/audio/pc.ogg"]:
		check(ResourceLoader.exists(path), "Audio resource exists: " + path.get_file())
	var menu: Node = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(audio_manager.current_music_state() == "menu", "Main menu selects menu music")
	check(menu.continue_button.disabled, "Continue is disabled without a save")
	check(menu.settings_panel != null, "Main menu has working settings screen")
	menu._open_settings()
	check(menu.settings_panel.visible and not menu.menu_panel.visible, "Main menu opens settings")
	menu.settings_panel.closed.emit()
	check(not menu.settings_panel.visible and menu.menu_panel.visible, "Settings return to the main menu that opened them")
	menu.queue_free()
	await process_frame

	save_manager.set_launch_mode("new")
	var game: Node = load("res://Prologue.tscn").instantiate()
	game.save_path = test_save_path
	root.add_child(game)
	await process_frame
	check(game.dialogue_open, "New game opens the existing prologue introduction")
	check(audio_manager.current_music_state() == "dialogue", "New game crossfades to dialogue music")
	finish_dialogue(game)
	check(game.mode == "room", "Introduction returns to the room")
	check(audio_manager.current_music_state() == "room", "Dialogue end restores room music")

	game.player.position = Vector2(430, 340)
	Input.parse_input_event(key_event(KEY_D))
	await physics_frame
	await physics_frame
	check(audio_manager.is_walking_sfx_playing(), "Footsteps play during actual movement")
	Input.parse_input_event(key_event(KEY_D, false))
	await physics_frame
	await physics_frame
	check(not audio_manager.is_walking_sfx_playing(), "Footsteps stop when movement stops")
	game.nearby_object = "computer"
	game._interact()
	check(game.mode == "desktop", "Existing computer interaction still opens")
	check(audio_manager.is_pc_sfx_playing(), "Computer sound plays once on successful interaction")
	game._close_computer()
	var optional_lines: Array[String] = ["[b]ГРАТ[/b]\nТест аудиоперехода."]
	game.optional(optional_lines)
	check(audio_manager.current_music_state() == "dialogue", "Repeated dialogue switches to dialogue music")
	game._unhandled_input(key_event(KEY_ESCAPE))
	check(game.dialogue_open and not game.pause_menu.visible, "Escape does not conflict with an active dialogue")
	finish_dialogue(game)
	check(audio_manager.current_music_state() == "room", "Optional dialogue returns to room music")

	var before_pause: Vector2 = game.player.position
	game._unhandled_input(key_event(KEY_ESCAPE))
	check(paused and game.pause_menu.visible, "Escape opens one active pause menu and pauses SceneTree")
	game.pause_menu.open_pause()
	check(game.ui_layer.get_node_or_null("PauseMenu") == game.pause_menu, "Pause menu cannot create duplicate instances")
	check(audio_manager.current_music_state() == "room", "Pause preserves current music state")
	game.pause_menu._open_settings()
	check(game.pause_menu.settings_panel.visible and not game.pause_menu.menu_panel.visible, "Pause opens shared settings")
	game.pause_menu.settings_panel.closed.emit()
	check(not game.pause_menu.settings_panel.visible and game.pause_menu.menu_panel.visible, "Settings return to pause when opened from pause")
	Input.parse_input_event(key_event(KEY_D))
	await process_frame
	await process_frame
	check(game.player.position == before_pause, "Player does not move while paused")
	Input.parse_input_event(key_event(KEY_D, false))
	game.pause_menu._unhandled_input(key_event(KEY_ESCAPE))
	check(not paused and not game.pause_menu.visible, "Escape resumes from pause")

	game.player.position = Vector2(512, 348)
	game.step = game.Step.HELP
	game.consultations = 1
	check(game.save_progress(), "Pause-compatible game save writes successfully")
	check(save_manager.has_valid_save(), "SaveManager validates the written save")
	game.queue_free()
	await process_frame

	var menu_with_save: Node = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu_with_save)
	await process_frame
	check(not menu_with_save.continue_button.disabled, "Continue is enabled for a valid save")
	menu_with_save.queue_free()
	await process_frame
	save_manager.set_launch_mode("continue")
	var restored: Node = load("res://Prologue.tscn").instantiate()
	restored.save_path = test_save_path
	root.add_child(restored)
	await process_frame
	check(restored.player.position.distance_to(Vector2(512, 348)) < 0.1, "Continue restores player position")
	check(restored.step == restored.Step.HELP and restored.consultations == 1, "Continue restores story progress")
	restored.queue_free()
	await process_frame

	audio_manager.play_music("room", 0.05)
	audio_manager.play_music("dialogue", 0.05)
	audio_manager.play_music("room", 0.05)
	await create_timer(0.12).timeout
	check(audio_manager.current_music_state() == "room" and playing_music_players() == 1, "Interrupted crossfades finish with one music stream")

	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	settings_manager.set_music_volume(0.0)
	check(AudioServer.is_bus_mute(music_bus), "Music is fully muted at 0 percent")
	settings_manager.set_music_volume(0.5)
	check(not AudioServer.is_bus_mute(music_bus) and absf(AudioServer.get_bus_volume_db(music_bus) + 6.0206) < 0.05, "Music bus applies 50 percent once")
	settings_manager.set_music_volume(1.0)
	check(absf(AudioServer.get_bus_volume_db(music_bus)) < 0.01, "Music bus applies 100 percent")
	settings_manager.set_sfx_volume(0.0)
	check(AudioServer.is_bus_mute(sfx_bus), "SFX is fully muted at 0 percent")
	settings_manager.set_sfx_volume(0.5)
	check(not AudioServer.is_bus_mute(sfx_bus) and absf(AudioServer.get_bus_volume_db(sfx_bus) + 6.0206) < 0.05, "SFX bus applies 50 percent once")
	settings_manager.set_sfx_volume(1.0)
	check(absf(AudioServer.get_bus_volume_db(sfx_bus)) < 0.01, "SFX bus applies 100 percent")
	settings_manager.set_music_volume(0.37)
	settings_manager.set_sfx_volume(0.64)
	settings_manager.set_resolution(Vector2i(1600, 900))
	settings_manager.set_fullscreen(true)
	settings_manager.music_volume = 1.0
	settings_manager.sfx_volume = 1.0
	settings_manager.resolution = Vector2i(960, 540)
	settings_manager.fullscreen = false
	settings_manager.load_settings()
	check(absf(settings_manager.music_volume - 0.37) < 0.001 and absf(settings_manager.sfx_volume - 0.64) < 0.001, "Audio settings persist and reload")
	check(settings_manager.resolution == Vector2i(1600, 900), "Display resolution setting persists and reloads")
	check(settings_manager.fullscreen, "Fullscreen setting persists and reloads")

	var corrupt := FileAccess.open(test_save_path, FileAccess.WRITE)
	corrupt.store_string("{broken save")
	corrupt = null
	check(save_manager.load_game().is_empty() and not save_manager.last_error.is_empty(), "Corrupted save is rejected with a readable error")

	save_manager.clear_save()
	if FileAccess.file_exists(test_settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_settings_path))
	save_manager.save_path = original_save_path
	settings_manager.settings_path = original_settings_path
	print("SYSTEMS RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
