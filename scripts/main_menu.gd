extends Control

const UIButtons = preload("res://scripts/ui_buttons.gd")
const MenuConfirm = preload("res://scripts/menu_confirm_dialog.gd")

var menu_panel: Panel
var settings_panel: Panel
var continue_button: Button
var status_label: Label
var new_game_confirmation: Control
var exit_confirmation: Control
var achievements_panel: Panel
var achievement_rows: VBoxContainer
var achievement_count_label: Label
var achievement_percent_label: Label
var dev_chapter_panel: Panel
var dev_endings_panel: Panel
var dev_page_panels: Dictionary = {}
var dev_page_bodies: Dictionary = {}
var dev_achievement_rows: VBoxContainer
var dev_achievement_search: LineEdit
var dev_achievement_status: Label
var dev_active_page := "home"
var selected_category := "Все"
var selected_state := "Все"
var background_art: TextureRect
var menu_button_list: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_build_background()
	_build_menu()
	_build_settings()
	_build_achievements()
	if OS.is_debug_build():
		_build_dev_chapter_picker()
	AchievementManager.achievements_changed.connect(_refresh_achievements_if_open)
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("menu")
	_refresh_continue()
	if OS.is_debug_build() and SaveManager.consume_dev_picker_reopen():
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

func _build_menu() -> void:
	menu_panel = Panel.new()
	menu_panel.name = "MainMenuColumn"
	menu_panel.anchor_left = 0.71875
	menu_panel.anchor_top = 0.045
	menu_panel.anchor_right = 0.975
	menu_panel.anchor_bottom = 0.955
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.027, 0.058, 0.95)
	style.border_color = Color(0.63, 0.51, 0.73, 0.76)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 12
	menu_panel.add_theme_stylebox_override("panel", style)
	add_child(menu_panel)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 16
	content.offset_top = 14
	content.offset_right = -16
	content.offset_bottom = -12
	content.add_theme_constant_override("separation", 5)
	menu_panel.add_child(content)
	var caption := Label.new()
	caption.text = "03:47  /  КОМНАТА 4fr"
	caption.custom_minimum_size.y = 18
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("b8a6ca"))
	content.add_child(caption)
	var title := Label.new()
	title.text = "ТИПОЧЕК"
	title.custom_minimum_size.y = 33
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f0e8ff"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "КЛЮЧ  ·  ПРОЛОГ И ГЛАВЫ 1–7"
	subtitle.custom_minimum_size.y = 19
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color("bea9ce"))
	content.add_child(subtitle)
	var separator := HSeparator.new()
	separator.add_theme_color_override("color", Color(0.63, 0.51, 0.73, 0.32))
	content.add_child(separator)
	var button_stack := VBoxContainer.new()
	button_stack.add_theme_constant_override("separation", 6)
	content.add_child(button_stack)
	continue_button = _menu_button(button_stack, "Продолжить", _continue_game)
	_menu_button(button_stack, "Новая игра", _new_game_pressed)
	_menu_button(button_stack, "Мои достижения", _open_achievements)
	_menu_button(button_stack, "Настройки", _open_settings)
	_menu_button(button_stack, "Выйти из игры", _exit_pressed)
	if OS.is_debug_build():
		_menu_button(button_stack, "Инструменты разработчика", _open_dev_chapter_picker)
	status_label = Label.new()
	status_label.custom_minimum_size.y = 38
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color("c9b6d7"))
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(status_label)
	new_game_confirmation = MenuConfirm.new()
	new_game_confirmation.title = "Новая игра"
	new_game_confirmation.dialog_text = "Существующее сохранение будет удалено. Начать заново?"
	new_game_confirmation.ok_button_text = "Начать заново"
	new_game_confirmation.cancel_button_text = "Отмена"
	new_game_confirmation.confirmed.connect(_start_new_game)
	add_child(new_game_confirmation)
	exit_confirmation = MenuConfirm.new()
	exit_confirmation.title = "Выйти из игры?"
	exit_confirmation.dialog_text = "Несохранённый прогресс может быть потерян."
	exit_confirmation.ok_button_text = "Выйти"
	exit_confirmation.cancel_button_text = "Остаться"
	exit_confirmation.confirmed.connect(func(): get_tree().quit())
	add_child(exit_confirmation)

func _menu_button(parent: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("e7dfef"))
	button.add_theme_color_override("font_hover_color", Color("fff0ce"))
	button.add_theme_color_override("font_pressed_color", Color("e0c9f0"))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.54, 0.63, 0.65))
	UIButtons.apply_menu_button(button)
	button.pressed.connect(action)
	parent.add_child(button)
	menu_button_list.append(button)
	return button

func _menu_button_style(fill: Color, edge: Color, edge_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(edge_width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _build_settings() -> void:
	settings_panel = preload("res://scripts/settings_panel.gd").new()
	add_child(settings_panel)
	settings_panel.closed.connect(_close_settings)

func _build_achievements() -> void:
	achievements_panel = Panel.new()
	achievements_panel.name = "AchievementsPanel"
	achievements_panel.position = Vector2(126, 24)
	achievements_panel.size = Vector2(708, 492)
	UIButtons.apply_menu_panel(achievements_panel)
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
		UIButtons.apply_menu_button(category_button)
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
		UIButtons.apply_menu_button(state_button)
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
	UIButtons.apply_menu_button(back)
	back.text = "Назад"
	back.position = Vector2(536, 446)
	back.size = Vector2(140, 34)
	back.pressed.connect(_close_achievements)
	achievements_panel.add_child(back)
	_refresh_achievements()

func _build_dev_chapter_picker() -> void:
	dev_chapter_panel = Panel.new()
	dev_chapter_panel.name = "DevChapterPicker"
	dev_chapter_panel.position = Vector2(126, 10)
	dev_chapter_panel.size = Vector2(708, 520)
	UIButtons.apply_menu_panel(dev_chapter_panel)
	dev_chapter_panel.hide()
	add_child(dev_chapter_panel)
	dev_chapter_panel.add_child(_achievement_label("РАЗРАБОТЧИК · БЫСТРЫЙ ДОСТУП", Vector2(24, 14), Vector2(650, 36), 25, Color("f0e8ff")))
	dev_chapter_panel.add_child(_achievement_label("Запуски глав и тестовые действия собраны по разделам.", Vector2(26, 52), Vector2(650, 24), 13, Color("c9b6d7")))
	var categories := [
		{"id":"chapters", "title":"Главы", "detail":"Прямой запуск главы 1–7"},
		{"id":"minigames", "title":"Мини-игры", "detail":"Открыть нужную игру сразу"},
		{"id":"locations", "title":"Локации", "detail":"Открыть отдельную сцену напрямую"},
		{"id":"calls", "title":"События звонков", "detail":"Вызвать одно тестовое событие"},
		{"id":"endings", "title":"Финалы и титры", "detail":"Проверить концовки и скролл титров"},
		{"id":"achievements", "title":"Достижения", "detail":"Выдать по одному и проверить уведомление"}
	]
	var category_grid := GridContainer.new()
	category_grid.name = "DevCategoryGrid"
	category_grid.columns = 2
	category_grid.position = Vector2(24, 92)
	category_grid.size = Vector2(660, 350)
	category_grid.add_theme_constant_override("h_separation", 14)
	category_grid.add_theme_constant_override("v_separation", 10)
	dev_chapter_panel.add_child(category_grid)
	for category in categories:
		var button := Button.new()
		button.name = "DevCategory_%s" % str(category.id)
		button.text = "%s\n%s" % [str(category.title), str(category.detail)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(320, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color("eee5f5"))
		button.add_theme_color_override("font_hover_color", Color("fff0ce"))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIButtons.apply_menu_button(button)
		button.pressed.connect(_show_dev_page.bind(str(category.id)))
		category_grid.add_child(button)
	var back := Button.new()
	back.name = "DevBackToMenu"
	UIButtons.apply_menu_button(back)
	back.text = "В главное меню"
	back.position = Vector2(516, 463)
	back.size = Vector2(168, 34)
	back.pressed.connect(_close_dev_chapter_picker)
	dev_chapter_panel.add_child(back)

	_build_dev_chapters_page()
	_build_dev_minigames_page()
	_build_dev_locations_page()
	_build_dev_calls_page()
	_build_dev_endings_picker()
	_build_dev_achievements_page()

func _create_dev_page(page_id: String, title: String, description: String) -> Dictionary:
	var panel := Panel.new()
	panel.name = "DevPage_%s" % page_id
	panel.position = dev_chapter_panel.position
	panel.size = dev_chapter_panel.size
	UIButtons.apply_menu_panel(panel)
	panel.hide()
	add_child(panel)
	dev_page_panels[page_id] = panel
	if page_id == "endings":
		dev_endings_panel = panel
	panel.add_child(_achievement_label(title, Vector2(24, 14), Vector2(650, 36), 23, Color("f0e8ff")))
	panel.add_child(_achievement_label(description, Vector2(26, 52), Vector2(650, 24), 13, Color("c9b6d7")))
	var scroll := ScrollContainer.new()
	scroll.name = "DevPageScroll_%s" % page_id
	scroll.position = Vector2(22, 86)
	scroll.size = Vector2(664, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "DevPageBody_%s" % page_id
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	dev_page_bodies[page_id] = body
	var page_back := Button.new()
	page_back.name = "DevPageBack_%s" % page_id
	UIButtons.apply_menu_button(page_back)
	page_back.text = "Назад к разделам"
	page_back.position = Vector2(496, 463)
	page_back.size = Vector2(188, 34)
	page_back.pressed.connect(_return_dev_to_hub)
	panel.add_child(page_back)
	return {"panel": panel, "body": body, "scroll": scroll}

func _add_dev_grid(page_id: String, items: Array, action: Callable, button_prefix: String) -> void:
	var body: VBoxContainer = dev_page_bodies[page_id]
	var grid := GridContainer.new()
	grid.name = "DevGrid_%s" % page_id
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for item in items:
		var button := Button.new()
		button.name = "%s%s" % [button_prefix, str(item.id)]
		button.text = str(item.title)
		button.custom_minimum_size = Vector2(320, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIButtons.apply_menu_button(button)
		button.pressed.connect(action.bind(str(item.id)))
		grid.add_child(button)

func _build_dev_chapters_page() -> void:
	_create_dev_page("chapters", "DEV · ЗАПУСК ГЛАВЫ", "Тестовый запуск использует отдельный dev-маршрут.")
	var chapters := [
		{"id":"1", "title":"Глава 1 · Альтушка на проводе"},
		{"id":"2", "title":"Глава 2 · Свидание в BIOS"},
		{"id":"3", "title":"Глава 3 · Война вкладок"},
		{"id":"4", "title":"Глава 4 · Министерство"},
		{"id":"5", "title":"Глава 5 · Суд"},
		{"id":"6", "title":"Глава 6 · Архив проекта"},
		{"id":"7", "title":"Глава 7 · Последняя сборка"}
	]
	_add_dev_grid("chapters", chapters, func(id: String) -> void: _launch_dev_chapter(int(id)), "DevChapter_")

func _build_dev_minigames_page() -> void:
	_create_dev_page("minigames", "DEV · ПРЯМОЙ ЗАПУСК МИНИ-ИГР", "Откроется указанная мини-игра без прохождения главы.")
	var minigames := [
		{"id":"doodle_jump", "title":"Прыжки 4fr · Пуск"},
		{"id":"tab_war", "title":"Война вкладок"},
		{"id":"wire_puzzle", "title":"Провода · Последняя сборка"},
		{"id":"office_queue", "title":"Очередь · Окошко 404"},
		{"id":"court_trial", "title":"Судья-принтер"}
	]
	_add_dev_grid("minigames", minigames, _launch_dev_minigame, "DevMinigame_")

func _build_dev_locations_page() -> void:
	_create_dev_page("locations", "DEV · ПРЯМОЙ ЗАПУСК ЛОКАЦИИ", "Откроется игровая сцена с управлением, паузой и разговором.")
	var locations := [
		{"id":"hotdog_master", "title":"Киоск · Артбей / Хот-дог Мастер"},
		{"id":"digital_archaeology", "title":"Старые проекты · глава 6"}
	]
	_add_dev_grid("locations", locations, _launch_dev_minigame, "DevLocation_")

func _build_dev_calls_page() -> void:
	_create_dev_page("calls", "DEV · СОБЫТИЯ ЗВОНКОВ", "Запуск звонка не требует ждать случайного расписания.")
	var calls := [
		{"id":"call_drx", "title":"Звонок · DRX"},
		{"id":"call_tables", "title":"Звонок · столы"},
		{"id":"call_palych", "title":"Звонок · Палыч / WB"}
	]
	_add_dev_grid("calls", calls, _launch_dev_call, "DevCall_")

func _build_dev_endings_picker() -> void:
	_create_dev_page("endings", "DEV · ФИНАЛЫ И ТИТРЫ", "Тестовые маршруты не меняют обычное сохранение главы.")
	var endings := [
		{"id":"grok", "title":"Грок · рядом по выбору"},
		{"id":"jbt", "title":"ЖБТ · партнёрство"},
		{"id":"artbay", "title":"Артбей · договор"},
		{"id":"artbay_bad", "title":"Артбей · присвоение"},
		{"id":"team", "title":"Общая команда"},
		{"id":"ministry", "title":"Министерство · Протокол 0"},
		{"id":"triple", "title":"Превышение симпатии"},
		{"id":"neutral", "title":"Самостоятельный релиз"},
		{"id":"instrumental", "title":"Люди — не инструменты"}
	]
	_add_dev_grid("endings", endings, _launch_dev_ending, "DevEnding_")
	var credits_button := Button.new()
	credits_button.name = "DevEnding_credits"
	UIButtons.apply_menu_button(credits_button)
	credits_button.text = "Показать титры"
	credits_button.custom_minimum_size = Vector2(320, 54)
	credits_button.add_theme_font_size_override("font_size", 13)
	credits_button.pressed.connect(_launch_dev_credits)
	var endings_body: VBoxContainer = dev_page_bodies["endings"]
	endings_body.get_node("DevGrid_endings").add_child(credits_button)

func _build_dev_achievements_page() -> void:
	var page: Dictionary = _create_dev_page("achievements", "DEV · ВЫДАЧА ДОСТИЖЕНИЙ", "Выбирай одну награду; секреты раскрываются только в этом dev-списке.")
	var panel: Panel = page.panel
	dev_achievement_search = LineEdit.new()
	dev_achievement_search.name = "DevAchievementSearch"
	dev_achievement_search.placeholder_text = "Поиск по названию, категории или ID"
	dev_achievement_search.position = Vector2(22, 82)
	dev_achievement_search.size = Vector2(664, 32)
	dev_achievement_search.text_changed.connect(func(_text: String): _refresh_dev_achievement_rows())
	panel.add_child(dev_achievement_search)
	dev_achievement_status = _achievement_label("", Vector2(24, 116), Vector2(650, 21), 11, Color("d6c1a0"))
	panel.add_child(dev_achievement_status)
	var scroll: ScrollContainer = page.scroll
	scroll.position = Vector2(22, 142)
	scroll.size = Vector2(664, 304)
	dev_achievement_rows = page.body
	_refresh_dev_achievement_rows()

func _refresh_dev_achievement_rows(status_message: String = "") -> void:
	if not is_instance_valid(dev_achievement_rows):
		return
	var unlocked_count := AchievementManager.get_unlocked_count()
	dev_achievement_status.text = status_message if not status_message.is_empty() else "Открыто %d из %d · каждая кнопка выдаёт одну награду" % [unlocked_count, AchievementManager.get_total_count()]
	for child in dev_achievement_rows.get_children():
		dev_achievement_rows.remove_child(child)
		child.queue_free()
	var query := dev_achievement_search.text.strip_edges().to_lower()
	for definition in AchievementManager.get_catalog():
		var id := str(definition.id)
		var name := str(AchievementManager._catalog_by_id[id].name)
		var category := str(definition.category)
		if not query.is_empty() and not (name.to_lower().contains(query) or id.to_lower().contains(query) or category.to_lower().contains(query)):
			continue
		var is_unlocked := AchievementManager.has_achievement(id)
		var row := PanelContainer.new()
		row.name = "DevAchievementRow_%s" % id
		row.custom_minimum_size = Vector2(0, 58)
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.09, 0.075, 0.12, 0.92)
		row_style.border_color = Color("756287")
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(6)
		row_style.content_margin_left = 9
		row_style.content_margin_right = 8
		row_style.content_margin_top = 4
		row_style.content_margin_bottom = 4
		row.add_theme_stylebox_override("panel", row_style)
		var row_content := HBoxContainer.new()
		row_content.add_theme_constant_override("separation", 10)
		row.add_child(row_content)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		row_content.add_child(info)
		var title := Label.new()
		title.text = name
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", Color("eee5f5"))
		info.add_child(title)
		var meta := Label.new()
		meta.text = "%s · %s%s" % [category, id, " · секретное" if bool(AchievementManager._catalog_by_id[id].get("secret", false)) else ""]
		meta.add_theme_font_size_override("font_size", 9)
		meta.add_theme_color_override("font_color", Color("bcaacb"))
		info.add_child(meta)
		var unlock_button := Button.new()
		unlock_button.name = "DevReset_%s" % id if is_unlocked else "DevUnlock_%s" % id
		unlock_button.text = "Сброс" if is_unlocked else "Открыть"
		unlock_button.custom_minimum_size = Vector2(96, 40)
		UIButtons.apply_menu_button(unlock_button)
		row_content.add_child(unlock_button)
		if is_unlocked:
			unlock_button.pressed.connect(_reset_dev_achievement.bind(id))
		else:
			unlock_button.pressed.connect(_unlock_dev_achievement.bind(id))
		dev_achievement_rows.add_child(row)

func _unlock_dev_achievement(achievement_id: String) -> void:
	var was_unlocked := AchievementManager.unlock_achievement(achievement_id)
	var definition: Dictionary = AchievementManager._catalog_by_id.get(achievement_id, {})
	var status_message: String
	if was_unlocked:
		status_message = "Открыто: %s" % str(definition.get("name", achievement_id))
	else:
		status_message = "Уже получено: %s" % str(definition.get("name", achievement_id))
	_refresh_dev_achievement_rows(status_message)

func _reset_dev_achievement(achievement_id: String) -> void:
	var was_unlocked := AchievementManager.reset_achievement(achievement_id)
	var definition: Dictionary = AchievementManager._catalog_by_id.get(achievement_id, {})
	var status_message := "Снова закрыто: %s" % str(definition.get("name", achievement_id)) if was_unlocked else "Уже закрыто: %s" % str(definition.get("name", achievement_id))
	_refresh_dev_achievement_rows(status_message)

func _open_dev_chapter_picker() -> void:
	menu_panel.hide()
	settings_panel.hide()
	achievements_panel.hide()
	_show_dev_hub()

func _show_dev_hub() -> void:
	for page in dev_page_panels.values():
		(page as Control).hide()
	dev_active_page = "home"
	dev_chapter_panel.show()
	var first_button := dev_chapter_panel.get_node_or_null("DevCategory_chapters") as Button
	if first_button:
		first_button.grab_focus()

func _show_dev_page(page_id: String) -> void:
	if not dev_page_panels.has(page_id):
		return
	dev_chapter_panel.hide()
	for page in dev_page_panels.values():
		(page as Control).hide()
	dev_active_page = page_id
	var panel: Control = dev_page_panels[page_id]
	panel.show()
	if page_id == "achievements":
		_refresh_dev_achievement_rows()
		dev_achievement_search.grab_focus()
	else:
		var focus_target := _find_first_button(panel)
		if focus_target:
			focus_target.grab_focus()

func _find_first_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and not (child as Button).disabled:
			return child as Button
		var nested := _find_first_button(child)
		if nested:
			return nested
	return null

func _return_dev_to_hub() -> void:
	_show_dev_hub()

func _close_dev_chapter_picker() -> void:
	dev_chapter_panel.hide()
	for page in dev_page_panels.values():
		(page as Control).hide()
	dev_active_page = "home"
	menu_panel.show()
	continue_button.grab_focus()

func _open_dev_endings_picker() -> void:
	_show_dev_page("endings")

func _close_dev_endings_picker() -> void:
	_return_dev_to_hub()

func _launch_dev_chapter(chapter: int) -> void:
	SaveManager.set_dev_chapter(chapter)
	get_tree().change_scene_to_file("res://Prologue.tscn")

func _launch_dev_call(event_id: String) -> void:
	SaveManager.set_dev_call_event(event_id)
	get_tree().change_scene_to_file("res://Prologue.tscn")

func _launch_dev_minigame(game_id: String) -> void:
	SaveManager.set_dev_minigame(game_id)
	get_tree().change_scene_to_file("res://Prologue.tscn")

func _launch_dev_credits() -> void:
	SaveManager.set_dev_credits()
	get_tree().change_scene_to_file("res://Prologue.tscn")

func _launch_dev_ending(ending_id: String) -> void:
	SaveManager.set_dev_ending(ending_id)
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
	description.text = "???" if secret_locked else str(definition.description)
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
		if child is Control and child != background_art and child != achievements_panel and child != settings_panel and child != dev_chapter_panel and child != dev_endings_panel:
			child.hide()
	_refresh_achievements()
	achievements_panel.show()

func _close_achievements() -> void:
	achievements_panel.hide()
	menu_panel.show()
	_focus_first_available_menu_button()

func _refresh_continue() -> void:
	var valid := SaveManager.has_valid_save()
	continue_button.disabled = not valid
	if SaveManager.has_save() and not valid:
		status_label.text = SaveManager.last_error + "\nМожно начать новую игру."
	elif valid:
		status_label.text = "Последнее сохранение найдено."
	else:
		status_label.text = "Сохранений пока нет."
	if menu_panel.visible:
		_focus_first_available_menu_button()

func _focus_first_available_menu_button() -> void:
	for button in menu_button_list:
		if is_instance_valid(button) and not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			return

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

func _exit_pressed() -> void:
	exit_confirmation.popup_centered()

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
	if OS.is_debug_build() and event.is_action_pressed("ui_cancel") and dev_active_page != "home" and dev_page_panels.has(dev_active_page) and (dev_page_panels[dev_active_page] as Control).visible:
		_return_dev_to_hub()
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and event.is_action_pressed("ui_cancel") and is_instance_valid(dev_chapter_panel) and dev_chapter_panel.visible:
		_close_dev_chapter_picker()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and achievements_panel.visible:
		_close_achievements()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and settings_panel.visible:
		_close_settings()
		get_viewport().set_input_as_handled()
