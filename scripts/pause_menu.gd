extends Control

var game: Node
var menu_panel: Panel
var settings_panel: Panel
var status_label: Label
var leave_confirmation: ConfirmationDialog
var game_hud_visibility: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()

func setup(game_node: Node) -> void:
	game = game_node

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.025, 0.02, 0.055, 0.83)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	menu_panel = Panel.new()
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.z_index = 1
	menu_panel.position = Vector2(300, 54)
	menu_panel.size = Vector2(360, 432)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171322")
	style.border_color = Color("9b82b4")
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	menu_panel.add_theme_stylebox_override("panel", style)
	add_child(menu_panel)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.position = Vector2(30, 20)
	title.size = Vector2(300, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("f0e8ff"))
	menu_panel.add_child(title)
	_pause_button("Продолжить", 75, close_pause)
	_pause_button("Настройки", 126, _open_settings)
	_pause_button("Сохранить игру", 177, _save_game)
	_pause_button("Главное меню", 228, _main_menu_pressed)
	_pause_button("Выйти из игры", 279, func(): get_tree().quit())
	status_label = Label.new()
	status_label.position = Vector2(30, 337)
	status_label.size = Vector2(300, 62)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("c8b8d5"))
	menu_panel.add_child(status_label)
	settings_panel = preload("res://scripts/settings_panel.gd").new()
	settings_panel.z_index = 2
	add_child(settings_panel)
	settings_panel.closed.connect(_close_settings)
	leave_confirmation = ConfirmationDialog.new()
	leave_confirmation.title = "Вернуться в главное меню?"
	leave_confirmation.dialog_text = "Есть несохранённые изменения. Выйти без сохранения?"
	leave_confirmation.ok_button_text = "Выйти без сохранения"
	leave_confirmation.cancel_button_text = "Отмена"
	leave_confirmation.confirmed.connect(_return_to_main_menu)
	add_child(leave_confirmation)

func _pause_button(text: String, y: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(30, y)
	button.size = Vector2(300, 40)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(action)
	menu_panel.add_child(button)
	return button

func open_pause() -> void:
	# GUI input follows sibling order, independently of z_index.
	move_to_front()
	if visible:
		return
	_set_game_hud_visible(false)
	status_label.text = "Esc — вернуться в игру"
	menu_panel.show()
	settings_panel.hide()
	show()
	AudioManager.set_walking(false)
	get_tree().paused = true

func close_pause() -> void:
	settings_panel.hide()
	hide()
	get_tree().paused = false
	_set_game_hud_visible(true)

func _set_game_hud_visible(should_show: bool) -> void:
	if game == null:
		return
	for property in ["chapter_title", "status_label", "goal_label", "hint_label"]:
		var node: Variant = game.get(property)
		if not node is CanvasItem:
			continue
		if should_show:
			if game_hud_visibility.has(property):
				node.visible = bool(game_hud_visibility[property])
		else:
			if not game_hud_visibility.has(property):
				game_hud_visibility[property] = node.visible
			node.hide()
	if should_show:
		game_hud_visibility.clear()

func _open_settings() -> void:
	menu_panel.hide()
	settings_panel.open()

func _close_settings() -> void:
	settings_panel.hide()
	menu_panel.show()

func _save_game() -> void:
	if game != null and game.has_method("save_progress"):
		var saved: bool = bool(game.call("save_progress"))
		status_label.text = "Игра сохранена." if saved else "Не удалось сохранить игру."
		if saved:
			AchievementManager.unlock_achievement("project_backup")

func _main_menu_pressed() -> void:
	if game != null and game.has_method("has_unsaved_progress") and bool(game.call("has_unsaved_progress")):
		leave_confirmation.popup_centered()
	else:
		_return_to_main_menu()

func _return_to_main_menu() -> void:
	_set_game_hud_visible(true)
	get_tree().paused = false
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("menu")
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if leave_confirmation.visible:
		leave_confirmation.hide()
	elif settings_panel.visible:
		_close_settings()
	else:
		close_pause()
	get_viewport().set_input_as_handled()

