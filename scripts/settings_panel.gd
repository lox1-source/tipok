extends Panel

signal closed

var music_slider: HSlider
var sfx_slider: HSlider
var fullscreen_check: CheckButton
var resolution_option: OptionButton
var monitor_option: OptionButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(210, 40)
	size = Vector2(540, 460)
	_build()
	hide()

func _label(text: String, pos: Vector2, area: Vector2, font_size: int = 18, color := Color("eee5fa")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = area
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171322")
	style.border_color = Color("8e78a7")
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	add_theme_stylebox_override("panel", style)
	_label("НАСТРОЙКИ", Vector2(28, 20), Vector2(480, 38), 27)
	_label("Музыка", Vector2(30, 77), Vector2(150, 28), 17, Color("d8c8e8"))
	music_slider = _slider(Vector2(190, 75))
	music_slider.value_changed.connect(func(value: float): SettingsManager.set_music_volume(value / 100.0))
	_label("Звуки", Vector2(30, 127), Vector2(150, 28), 17, Color("d8c8e8"))
	sfx_slider = _slider(Vector2(190, 125))
	sfx_slider.value_changed.connect(func(value: float): SettingsManager.set_sfx_volume(value / 100.0))
	var separator := HSeparator.new()
	separator.position = Vector2(28, 179)
	separator.size = Vector2(484, 8)
	add_child(separator)
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Полноэкранный режим"
	fullscreen_check.position = Vector2(25, 205)
	fullscreen_check.size = Vector2(300, 38)
	fullscreen_check.add_theme_font_size_override("font_size", 17)
	fullscreen_check.toggled.connect(func(value: bool): SettingsManager.set_fullscreen(value))
	add_child(fullscreen_check)
	_label("Разрешение окна", Vector2(30, 261), Vector2(185, 31), 17, Color("d8c8e8"))
	resolution_option = OptionButton.new()
	resolution_option.position = Vector2(230, 255)
	resolution_option.size = Vector2(270, 40)
	resolution_option.add_theme_font_size_override("font_size", 16)
	for resolution in SettingsManager.RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
		resolution_option.set_item_metadata(resolution_option.item_count - 1, resolution)
	resolution_option.item_selected.connect(func(index: int): SettingsManager.set_resolution(resolution_option.get_item_metadata(index)))
	add_child(resolution_option)
	_label("Монитор", Vector2(30, 311), Vector2(185, 31), 17, Color("d8c8e8"))
	monitor_option = OptionButton.new()
	monitor_option.position = Vector2(230, 305)
	monitor_option.size = Vector2(270, 40)
	monitor_option.add_theme_font_size_override("font_size", 15)
	monitor_option.item_selected.connect(func(index: int): SettingsManager.set_monitor(int(monitor_option.get_item_metadata(index))))
	add_child(monitor_option)
	var hint := _label("Внутренняя сцена остаётся 960 × 540 — пиксели не растягиваются.", Vector2(30, 359), Vector2(480, 42), 13, Color("a99ab8"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := Button.new()
	back.text = "Назад"
	back.position = Vector2(30, 405)
	back.size = Vector2(150, 40)
	back.add_theme_font_size_override("font_size", 17)
	back.pressed.connect(func(): closed.emit())
	add_child(back)

func _slider(pos: Vector2) -> HSlider:
	var slider := HSlider.new()
	slider.position = pos
	slider.size = Vector2(310, 35)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.tick_count = 5
	slider.ticks_on_borders = true
	add_child(slider)
	return slider

func open() -> void:
	_sync()
	show()
	music_slider.grab_focus()

func _sync() -> void:
	monitor_option.clear()
	monitor_option.add_item("Основной монитор")
	monitor_option.set_item_metadata(0, -1)
	for screen in range(DisplayServer.get_screen_count()):
		var dimensions := DisplayServer.screen_get_size(screen)
		monitor_option.add_item("Монитор %d · %d × %d" % [screen + 1, dimensions.x, dimensions.y])
		monitor_option.set_item_metadata(screen + 1, screen)
	monitor_option.select(0)
	for index in range(monitor_option.item_count):
		if int(monitor_option.get_item_metadata(index)) == SettingsManager.monitor:
			monitor_option.select(index)
			break
	music_slider.set_value_no_signal(SettingsManager.music_volume * 100.0)
	sfx_slider.set_value_no_signal(SettingsManager.sfx_volume * 100.0)
	fullscreen_check.set_pressed_no_signal(SettingsManager.fullscreen)
	for index in range(resolution_option.item_count):
		if resolution_option.get_item_metadata(index) == SettingsManager.resolution:
			resolution_option.select(index)
			break
