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
var selected_category := "Все"
var selected_state := "Все"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_build_background()
	_build_menu()
	_build_settings()
	_build_achievements()
	AchievementManager.achievements_changed.connect(_refresh_achievements_if_open)
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("menu")
	_refresh_continue()

func _build_background() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("090814")
	add_child(background)
	var moon_glow := ColorRect.new()
	moon_glow.position = Vector2(0, 0)
	moon_glow.size = Vector2(960, 150)
	moon_glow.color = Color(0.13, 0.12, 0.24, 0.72)
	background.add_child(moon_glow)
	for y in range(190, 541, 32):
		var strip := ColorRect.new()
		strip.position = Vector2(0, y)
		strip.size = Vector2(960, 2)
		strip.color = Color(0.24, 0.19, 0.31, 0.18)
		background.add_child(strip)
	var title := Label.new()
	title.text = "ТИПОЧЕК"
	title.position = Vector2(86, 92)
	title.size = Vector2(520, 78)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("f0e8ff"))
	title.add_theme_color_override("font_shadow_color", Color("4b365f"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	background.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "КЛЮЧ  ·  ПРОЛОГ И ГЛАВЫ 1–3"
	subtitle.position = Vector2(91, 164)
	subtitle.size = Vector2(520, 28)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("bea9ce"))
	background.add_child(subtitle)

func _build_menu() -> void:
	menu_panel = Panel.new()
	menu_panel.position = Vector2(575, 72)
	menu_panel.size = Vector2(300, 440)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.06, 0.12, 0.94)
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
	status_label = Label.new()
	status_label.position = Vector2(24, 344)
	status_label.size = Vector2(252, 66)
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
	achievement_count_label = _achievement_label("0 / 33", Vector2(438, 16), Vector2(120, 25), 16, Color("e4d2f2"))
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
	_refresh_achievements()
	achievements_panel.show()

func _close_achievements() -> void:
	achievements_panel.hide()
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
	AchievementManager.unlock_achievement("first_launch")
	SaveManager.set_launch_mode("new")
	get_tree().change_scene_to_file("res://Prologue.tscn")

func _open_settings() -> void:
	menu_panel.hide()
	settings_panel.open()

func _close_settings() -> void:
	settings_panel.hide()
	menu_panel.show()
	continue_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and achievements_panel.visible:
		_close_achievements()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and settings_panel.visible:
		_close_settings()
		get_viewport().set_input_as_handled()
