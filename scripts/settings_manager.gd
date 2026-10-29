extends Node

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := false
var resolution := Vector2i(1280, 720)
var monitor := -1
var settings_path := SETTINGS_PATH

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	monitor = int(config.get_value("display", "monitor", -1))
	var loaded_resolution = config.get_value("display", "resolution", resolution)
	if loaded_resolution is Vector2i and RESOLUTIONS.has(loaded_resolution):
		resolution = loaded_resolution

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "monitor", monitor)
	var error := config.save(settings_path)
	if error != OK:
		push_error("Could not save settings: %s" % error_string(error))

func apply_all() -> void:
	AudioManager.set_music_volume(music_volume)
	AudioManager.set_sfx_volume(sfx_volume)
	_apply_display()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_music_volume(music_volume)
	save_settings()
	settings_changed.emit()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_sfx_volume(sfx_volume)
	save_settings()
	settings_changed.emit()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_display()
	save_settings()
	settings_changed.emit()

func set_resolution(value: Vector2i) -> void:
	if not RESOLUTIONS.has(value):
		return
	resolution = value
	_apply_display()
	save_settings()
	settings_changed.emit()

func set_monitor(value: int) -> void:
	monitor = value
	_apply_display()
	save_settings()
	settings_changed.emit()

func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var target := monitor
	if target < 0 or target >= DisplayServer.get_screen_count():
		target = DisplayServer.get_primary_screen()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_current_screen(target)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
		var usable := DisplayServer.screen_get_usable_rect(target)
		DisplayServer.window_set_position(usable.position + (usable.size - resolution) / 2)
