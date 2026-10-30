extends Control

signal confirmed

var title: String = "":
	set(value):
		title = value
		if is_instance_valid(title_label): title_label.text = value

var dialog_text: String = "":
	set(value):
		dialog_text = value
		if is_instance_valid(message_label): message_label.text = value

var ok_button_text: String = "Подтвердить":
	set(value):
		ok_button_text = value
		if is_instance_valid(confirm_button): confirm_button.text = value

var cancel_button_text: String = "Отмена":
	set(value):
		cancel_button_text = value
		if is_instance_valid(cancel_button): cancel_button.text = value

var title_label: Label
var message_label: Label
var confirm_button: Button
var cancel_button: Button
var close_button: Button

func _init() -> void:
	name = "MenuConfirmation"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	hide()

func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.012, 0.009, 0.025, 0.66)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel := Panel.new()
	panel.name = "ConfirmPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -115)
	panel.size = Vector2(600, 230)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.027, 0.058, 0.99)
	box.border_color = Color(0.63, 0.51, 0.73, 0.95)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.shadow_color = Color(0, 0, 0, 0.48)
	box.shadow_size = 14
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	title_label = Label.new()
	title_label.text = title
	title_label.position = Vector2(34, 20)
	title_label.size = Vector2(500, 42)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("f0e8ff"))
	panel.add_child(title_label)
	close_button = Button.new()
	close_button.text = "×"
	close_button.position = Vector2(544, 10)
	close_button.size = Vector2(38, 38)
	close_button.add_theme_font_size_override("font_size", 25)
	_style_button(close_button, false)
	close_button.pressed.connect(_cancel)
	panel.add_child(close_button)
	message_label = Label.new()
	message_label.text = dialog_text
	message_label.position = Vector2(28, 78)
	message_label.size = Vector2(544, 54)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color("d8cde2"))
	panel.add_child(message_label)
	confirm_button = Button.new()
	confirm_button.text = ok_button_text
	confirm_button.position = Vector2(70, 158)
	confirm_button.size = Vector2(210, 46)
	_style_button(confirm_button, true)
	confirm_button.pressed.connect(_confirm)
	panel.add_child(confirm_button)
	cancel_button = Button.new()
	cancel_button.text = cancel_button_text
	cancel_button.position = Vector2(320, 158)
	cancel_button.size = Vector2(210, 46)
	_style_button(cancel_button, false)
	cancel_button.pressed.connect(_cancel)
	panel.add_child(cancel_button)

func _style_button(button: Button, is_primary: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.17, 0.12, 0.23, 0.98)
	normal.border_color = Color("d4b77b") if is_primary else Color(0.55, 0.43, 0.65, 0.8)
	normal.set_border_width_all(2 if is_primary else 1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.26, 0.19, 0.34, 1.0)
	hover.border_color = Color("f0d39a") if is_primary else Color("c5a5dc")
	hover.set_border_width_all(2)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.1, 0.075, 0.15, 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("e9e0ef"))
	button.add_theme_color_override("font_hover_color", Color("fff0ce"))
	button.add_theme_font_size_override("font_size", 17)

func get_ok_button() -> Button:
	return confirm_button

func get_cancel_button() -> Button:
	return cancel_button

func popup_centered(_size: Vector2i = Vector2i.ZERO) -> void:
	show()
	confirm_button.grab_focus()

func _confirm() -> void:
	hide()
	confirmed.emit()

func _cancel() -> void:
	hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()
