extends Control

var menu_panel: Panel
var settings_panel: Panel
var continue_button: Button
var status_label: Label
var new_game_confirmation: ConfirmationDialog
var achievements_panel: Panel
var achievement_rows: VBoxContainer
var achievement_count_label: Label
var achievement_percent_label: Label
var dev_chapter_panel: Panel
var selected_category := "Все"
var selected_state := "Все"
var background_art: TextureRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_build_background()
	_build_menu()
	_build_settings()
	_build_achievements()
	_build_dev_chapter_picker()
	AchievementManager.achievements_changed.connect(_refresh_achievements_if_open)
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("menu")
	_refresh_continue()
	if SaveManager.consume_dev_picker_reopen():
		_open_dev_chapter_picker()

func _build_background() -> void:
	background_art = TextureRect.new()
	background_art.name = "MainMenuArtwork"
	background_art.texture = load("res://assets/ui/main-menu-keyart.png") as Texture2D
	background_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_SCALE
	background_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_art)
	move_child(background_art, 0)
	var title_plate := Panel.new()
	title_plate.name = "TitlePlate"
	title_plate.position = Vector2(40, 12)
	title_plate.size = Vector2(300, 104)
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.035, 0.025, 0.055, 0.62)
	plate_style.border_color = Color(0.58, 0.46, 0.68, 0.32)
	plate_style.set_border_width_all(1)
	plate_style.set_corner_radius_all(7)
	plate_style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	plate_style.shadow_size = 8
	title_plate.add_theme_stylebox_override("panel", plate_style)
	add_child(title_plate)
	var rubik_base := load("res://assets/ui/fonts/Rubik-Variable.ttf") as FontFile
	var title_font := FontVariation.new()
	title_font.base_font = rubik_base
	title_font.variation_opentype = {"wght": 700.0}
	var subtitle_font := FontVariation.new()
	subtitle_font.base_font = rubik_base
	subtitle_font.variation_opentype = {"wght": 500.0}
	var title := Label.new()
	title.text = "ТИПОЧЕК"
	title.position = Vector2(56, 20)
	title.size = Vector2(520, 64)
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("f0e8ff"))
	title.add_theme_color_override("font_shadow_color", Color("4b365f"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "КЛЮЧ  ·  ПРОЛОГ И ГЛАВЫ 1–7"
	subtitle.position = Vector2(61, 77)
	subtitle.size = Vector2(520, 28)
	subtitle.add_theme_font_override("font", subtitle_font)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("bea9ce"))
	add_child(subtitle)

func _build_menu() -> void:
	menu_panel = Panel.new()
	menu_panel.position = Vector2(575, 72)
	menu_panel.size = Vector2(300, 440)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.06, 0.12, 1.0)
	style.border_color = Color("79668f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	menu_panel.add_theme_stylebox_override("panel", style)
	add_child(menu_panel)
	var caption := Label.new()
	caption.text = "03:47  /  КОМНАТА ГРАТА"
	caption.position = Vector2(24, 22)
	caption.size = Vector2(255, 30)
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color("b8a6ca"))
	menu_panel.add_child(caption)
	continue_button = _menu_button("Продолжить", 66, _continue_game)
	_menu_button("Новая игра", 119, _new_game_pressed)
	_menu_button("Мои достижения", 172, _open_achievements)
	_menu_button("Настройки", 225, _open_settings)
	_menu_button("Выйти из игры", 278, func(): get_tree().quit())
	_menu_button("Выбор главы · DEV", 331, _open_dev_chapter_picker)
	status_label = Label.new()
	status_label.position = Vector2(24, 383)
	status_label.size = Vector2(252, 40)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("c9b6d7"))
	menu_panel.add_child(status_label)
	new_game_confirmation = ConfirmationDialog.new()
	new_game_confirmation.title = "Новая игра"
	new_game_confirmation.dialog_text = "Существующее сохранение будет удалено. Начать заново?"
	new_game_confirmation.ok_button_text = "Начать заново"
	new_game_confirmation.cancel_button_text = "Отмена"
	new_game_confirmation.confirmed.connect(_start_new_game)
	add_child(new_game_confirmation)

func _menu_button(text: String, y: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(24, y)
	button.size = Vector2(252, 43)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	menu_panel.add_child(button)
	return button

func _build_settings() -> void:
	settings_panel = preload("res://scripts/settings_panel.gd").new()
	add_child(settings_panel)
	settings_panel.closed.connect(_close_settings)

func _build_achievements() -> void:
	achievements_panel = Panel.new()
	achievements_panel.name = "AchievementsPanel"
	achievements_panel.position = Vector2(126, 24)
	achievements_panel.size = Vector2(708, 492)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.09, 0.98)
	style.border_color = Color("857099")
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	achievements_panel.add_theme_stylebox_override("panel", style)
	achievements_panel.hide()
	add_child(achievements_panel)
	var title := _achievement_label("Мои достижения", Vector2(24, 14), Vector2(390, 38), 27, Color("f0e8ff"))
	achievements_panel.add_child(title)
	achievement_count_label = _achievement_label("0 / 35", Vector2(438, 16), Vector2(120, 25), 16, Color("e4d2f2"))
	achievements_panel.add_child(achievement_count_label)
	achievement_percent_label = _achievement_label("0%", Vector2(585, 16), Vector2(86, 25), 16, Color("c8b49a"))
	achievement_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	achievements_panel.add_child(achievement_percent_label)
	var categories := HBoxContainer.new()
	categories.name = "AchievementCategories"
	categories.position = Vector2(18, 58)
	categories.size = Vector2(672, 35)
	categories.add_theme_constant_override("separation", 4)
	achievements_panel.add_child(categories)
	var category_group := ButtonGroup.new()
	for category in ["Все"] + AchievementManager.CATEGORIES:
		var category_button := Button.new()
		category_button.toggle_mode = true
		category_button.button_group = category_group
		category_button.button_pressed = category == "Все"
		category_button.text = category
		category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_button.custom_minimum_size.y = 31
		category_button.add_theme_font_size_override("font_size", 10)
		category_button.pressed.connect(func():
			selected_category = category
			_refresh_achievements()
		)
		categories.add_child(category_button)
	var filters := HBoxContainer.new()
	filters.name = "AchievementFilters"
	filters.position = Vector2(20, 99)
	filters.size = Vector2(350, 33)
	filters.add_theme_constant_override("separation", 8)
	achievements_panel.add_child(filters)
	var filter_group := ButtonGroup.new()
	for state in ["Все", "Полученные", "Не полученные"]:
		var state_button := Button.new()
		state_button.toggle_mode = true
		state_button.button_group = filter_group
		state_button.button_pressed = state == "Все"
		state_button.text = state
		state_button.custom_minimum_size = Vector2(106, 30)
		state_button.add_theme_font_size_override("font_size", 12)
		state_button.pressed.connect(func():
			selected_state = state
			_refresh_achievements()
		)
		filters.add_child(state_button)
	var scroll := ScrollContainer.new()
	scroll.name = "AchievementScroll"
	scroll.position = Vector2(18, 140)
	scroll.size = Vector2(672, 294)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	achievements_panel.add_child(scroll)
	achievement_rows = VBoxContainer.new()
	achievement_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_rows.add_theme_constant_override("separation", 7)
	scroll.add_child(achievement_rows)
	var back := Button.new()
	back.text = "Назад"
	back.position = Vector2(536, 446)
	back.size = Vector2(140, 34)
	back.pressed.connect(_close_achievements)
	achievements_panel.add_child(back)
	_refresh_achievements()

func _build_dev_chapter_picker() -> void:
	dev_chapter_panel = Panel.new()
	dev_chapter_panel.name = "DevChapterPicker"
	dev_chapter_panel.position = Vector2(126, 24)
	dev_chapter_panel.size = Vector2(708, 492)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.09, 0.98)
	style.border_color = Color("857099")
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	dev_chapter_panel.add_theme_stylebox_override("panel", style)
	dev_chapter_panel.hide()
	add_child(dev_chapter_panel)
	dev_chapter_panel.add_child(_achievement_label("ЗАПУСК ГЛАВЫ · DEV", Vector2(24, 18), Vector2(560, 42), 27, Color("f0e8ff")))
	dev_chapter_panel.add_child(_achievement_label("Тестовый запуск не перезаписывает основное сохранение.", Vector2(26, 62), Vector2(650, 26), 14, Color("c9b6d7")))
	dev_chapter_panel.add_child(_achievement_label("ЗВОНКИ · ТЕСТОВЫЕ СОБЫТИЯ", Vector2(24, 330), Vector2(650, 24), 14, Color("e4d2f2")))
	var names := [
		"Глава 1 · Альтушка на проводе",
		"Глава 2 · Свидание в BIOS",
		"Глава 3 · Война вкладок",
		"Глава 4 · Министерство",
		"Глава 5 · Суд",
		"Глава 6 · Архив проекта",
		"Глава 7 · Последняя сборка"
	]
	for index in range(names.size()):
		var chapter := index + 1
		var button := Button.new()
		button.text = names[index]
		button.position = Vector2(24 + (index % 2) * 330, 106 + int(index / 2) * 55)
		button.size = Vector2(310, 48)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_launch_dev_chapter.bind(chapter))
		dev_chapter_panel.add_child(button)
	var call_events := [
		{"id":"call_drx", "title":"Звонок · DRX"},
		{"id":"call_tables", "title":"Звонок · столы"},
		{"id":"call_palych", "title":"Звонок · Палыч / WB"}
	]
	for index in range(call_events.size()):
		var call_button := Button.new()
		call_button.text = str(call_events[index].title)
		call_button.position = Vector2(24 + index * 220, 354)
		call_button.size = Vector2(210, 52)
		call_button.add_theme_font_size_override("font_size", 14)
		call_button.pressed.connect(_launch_dev_call.bind(str(call_events[index].id)))
		dev_chapter_panel.add_child(call_button)
	var back := Button.new()
	back.text = "Назад"
	back.position = Vector2(536, 438)
	back.size = Vector2(140, 34)
	back.pressed.connect(_close_dev_chapter_picker)
	dev_chapter_panel.add_child(back)

func _open_dev_chapter_picker() -> void:
	menu_panel.hide()
	settings_panel.hide()
	achievements_panel.hide()
	dev_chapter_panel.show()

func _close_dev_chapter_picker() -> void:
	dev_chapter_panel.hide()
	menu_panel.show()
	continue_button.grab_focus()

func _launch_dev_chapter(chapter: int) -> void:
	SaveManager.set_dev_chapter(chapter)
	get_tree().change_scene_to_file("res://Prologue.tscn")

func _launch_dev_call(event_id: String) -> void:
	SaveManager.set_dev_call_event(event_id)
	get_tree().change_scene_to_file("res://Prologue.tscn")

func _achievement_label(value: String, pos: Vector2, area: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = area
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _refresh_achievements_if_open() -> void:
	if is_instance_valid(achievements_panel) and achievements_panel.visible:
		_refresh_achievements()

func _refresh_achievements() -> void:
	if not is_instance_valid(achievement_rows):
		return
	achievement_count_label.text = "%d / %d" % [AchievementManager.get_unlocked_count(), AchievementManager.get_total_count()]
	achievement_percent_label.text = "%d%%" % AchievementManager.get_completion_percent()
	for child in achievement_rows.get_children():
		achievement_rows.remove_child(child)
		child.queue_free()
	for definition in AchievementManager.get_catalog():
		if selected_category != "Все" and str(definition.category) != selected_category:
			continue
		var is_unlocked := AchievementManager.has_achievement(str(definition.id))
		if selected_state == "Полученные" and not is_unlocked:
			continue
		if selected_state == "Не полученные" and is_unlocked:
			continue
		var card := _achievement_card(definition, is_unlocked)
		achievement_rows.add_child(card)

func _achievement_card(definition: Dictionary, is_unlocked: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 68)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.17, 0.13, 0.22, 0.96) if is_unlocked else Color(0.09, 0.075, 0.12, 0.92)
	card_style.border_color = Color("ad8cc1") if is_unlocked else Color("4b4256")
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(5)
	card_style.content_margin_left = 10
	card_style.content_margin_right = 8
	card_style.content_margin_top = 5
	card_style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", card_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.name = "AchievementIcon"
	icon.texture = AchievementManager.get_icon(str(definition.id), bool(definition.get("secret", false)) and not is_unlocked)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color.WHITE if is_unlocked else Color(0.48, 0.44, 0.53, 0.9)
	row.add_child(icon)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 1)
	row.add_child(text_column)
	var secret_locked := bool(definition.get("secret", false)) and not is_unlocked
	var title := Label.new()
	title.text = str(definition.name) if is_unlocked or not secret_locked else "???"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("f1e7d4") if is_unlocked else Color("aaa3b0"))
	text_column.add_child(title)
	var description := Label.new()
	description.text = str(definition.get("secret_description", "Скрытое достижение")) if secret_locked else str(definition.description)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 30
	description.max_lines_visible = 2
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", Color("c5b9cf") if is_unlocked else Color("827b8b"))
	text_column.add_child(description)
	var state := Label.new()
	state.text = "ОТКРЫТО" if is_unlocked else "ЗАКРЫТО"
	state.custom_minimum_size.x = 72
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", 10)
	state.add_theme_color_override("font_color", Color("d7b870") if is_unlocked else Color("77717e"))
	row.add_child(state)
	if is_unlocked:
		var date_label := Label.new()
		date_label.text = AchievementManager.get_unlocked_at(str(definition.id)).replace("T", " ")
		date_label.custom_minimum_size.x = 124
		date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		date_label.add_theme_font_size_override("font_size", 9)
		date_label.add_theme_color_override("font_color", Color("a99ab4"))
		row.add_child(date_label)
	return card

func _open_achievements() -> void:
	menu_panel.hide()
	settings_panel.hide()
	for child in get_children():
		if child is Control and child != achievements_panel and child != settings_panel and child != dev_chapter_panel:
			child.hide()
	_refresh_achievements()
	achievements_panel.show()

func _close_achievements() -> void:
	achievements_panel.hide()
	for child in get_children():
		if child is Control and child != achievements_panel and child != settings_panel and child != dev_chapter_panel:
			child.show()
	menu_panel.show()
	continue_button.grab_focus()

func _refresh_continue() -> void:
	var valid := SaveManager.has_valid_save()
	continue_button.disabled = not valid
	if SaveManager.has_save() and not valid:
		status_label.text = SaveManager.last_error + "\nМожно начать новую игру."
	elif valid:
		status_label.text = "Последнее сохранение найдено."
	else:
		status_label.text = "Сохранений пока нет."

func _continue_game() -> void:
	if not SaveManager.has_valid_save():
		_refresh_continue()
		return
	SaveManager.set_launch_mode("continue")
	get_tree().change_scene_to_file("res://Prologue.tscn")

func _new_game_pressed() -> void:
	if SaveManager.has_save():
		new_game_confirmation.popup_centered()
	else:
		_start_new_game()

func _start_new_game() -> void:
	if not SaveManager.clear_save():
		status_label.text = SaveManager.last_error
		return
	SaveManager.set_launch_mode("new")
	AchievementManager.unlock_achievement("first_launch")
	get_tree().change_scene_to_file("res://Prologue.tscn")

func _open_settings() -> void:
	menu_panel.hide()
	settings_panel.open()

func _close_settings() -> void:
	settings_panel.hide()
	menu_panel.show()
	continue_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and dev_chapter_panel.visible:
		_close_dev_chapter_picker()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and achievements_panel.visible:
		_close_achievements()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and settings_panel.visible:
		_close_settings()
		get_viewport().set_input_as_handled()
