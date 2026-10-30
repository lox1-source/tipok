extends RefCounted

const KEY_NORMAL: Texture2D = preload("res://assets/ui/buttons/key-grabber.svg")
const KEY_HOVER: Texture2D = preload("res://assets/ui/buttons/key-grabber-hover.svg")
const KEY_PRESSED: Texture2D = preload("res://assets/ui/buttons/key-grabber-pressed.svg")

static func apply(button: Button) -> void:
	# Keep this compatibility hook for existing button builders; native Godot styles are used.
	pass

static func apply_menu_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("e7dfef"))
	button.add_theme_color_override("font_hover_color", Color("fff0ce"))
	button.add_theme_color_override("font_pressed_color", Color("e0c9f0"))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.54, 0.63, 0.65))
	button.add_theme_color_override("font_focus_color", Color("fff0ce"))
	var normal := _menu_button_style(Color(0.13, 0.105, 0.18, 0.94), Color(0.48, 0.39, 0.57, 0.56), 1)
	var hover := _menu_button_style(Color(0.23, 0.18, 0.30, 0.98), Color(0.76, 0.63, 0.84, 0.95), 2)
	var pressed := _menu_button_style(Color(0.09, 0.07, 0.13, 1.0), Color(0.78, 0.66, 0.84, 0.95), 2)
	var disabled := _menu_button_style(Color(0.075, 0.065, 0.095, 0.82), Color(0.35, 0.31, 0.40, 0.42), 1)
	var focus := _menu_button_style(Color(0.16, 0.12, 0.22, 0.98), Color("e0c07b"), 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_constant_override("h_separation", 8)

static func _menu_button_style(fill: Color, edge: Color, edge_width: int) -> StyleBoxFlat:
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

static func menu_panel_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.027, 0.058, 0.95)
	style.border_color = Color(0.63, 0.51, 0.73, 0.76)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func apply_menu_panel(panel: Control) -> void:
	panel.add_theme_stylebox_override("panel", menu_panel_box())

static func apply_choice(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.09, 0.19, 0.96)
	normal.border_color = Color(0.72, 0.62, 0.82, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	normal.set_content_margin_all(7)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.22, 0.42, 0.98)
	hover.border_color = Color("dfb8f2")
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.49, 0.32, 0.54, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.18, 0.14, 0.24, 0.75)
	button.add_theme_stylebox_override("disabled", disabled)

static func apply_panel(panel: Control, tint: Color = Color.WHITE) -> void:
	panel.add_theme_stylebox_override("panel", panel_box(tint))

static func apply_dialog(dialog: ConfirmationDialog) -> void:
	var theme := Theme.new()
	theme.default_font = ThemeDB.get_default_theme().default_font
	theme.default_font_size = ThemeDB.get_default_theme().default_font_size
	var panel_style := menu_panel_box()
	panel_style.bg_color = Color(0.035, 0.027, 0.058, 0.985)
	panel_style.border_color = Color(0.63, 0.51, 0.73, 0.92)
	panel_style.set_border_width_all(2)
	# Embedded Window draws the grey frame seen around the dialog content.
	theme.set_stylebox("embedded_border", "Window", panel_style)
	# Keep AcceptDialog content transparent so it does not create a second panel.
	theme.set_stylebox("panel", "Panel", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "AcceptDialog", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "ConfirmationDialog", StyleBoxEmpty.new())
	theme.set_color("title_color", "Window", Color("f0e8ff"))
	theme.set_color("font_color", "Label", Color("e7dfef"))
	theme.set_color("font_color", "Button", Color("e7dfef"))
	theme.set_color("font_hover_color", "Button", Color("fff0ce"))
	theme.set_color("font_pressed_color", "Button", Color("e0c9f0"))
	theme.set_color("font_focus_color", "Button", Color("fff0ce"))
	dialog.theme = theme
	dialog.size = Vector2i(600, 230)

static func panel_box(_tint: Color = Color.WHITE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.038, 0.10, 0.97)
	style.border_color = Color(0.66, 0.52, 0.78, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func choice_box(tint: Color = Color.WHITE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(8)
	return style

static func apply_slider(slider: HSlider) -> void:
	var track := StyleBoxLine.new()
	track.color = Color("392d49")
	track.thickness = 5.0
	track.grow_begin = -2.0
	track.grow_end = -2.0
	var active_track := StyleBoxLine.new()
	active_track.color = Color("c69e62")
	active_track.thickness = 4.0
	active_track.grow_begin = -2.0
	active_track.grow_end = -2.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", active_track)
	slider.add_theme_stylebox_override("grabber_area_highlight", active_track)
	slider.add_theme_icon_override("grabber", KEY_NORMAL)
	slider.add_theme_icon_override("grabber_highlight", KEY_HOVER)
	slider.add_theme_icon_override("grabber_pressed", KEY_PRESSED)
	slider.add_theme_constant_override("grabber_offset", 16)
	slider.gui_input.connect(_slider_gui_input.bind(slider))

static func _slider_gui_input(event: InputEvent, slider: HSlider) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			slider.add_theme_icon_override("grabber_highlight", KEY_PRESSED)
		else:
			slider.add_theme_icon_override("grabber_highlight", KEY_HOVER if Rect2(Vector2.ZERO, slider.size).has_point(event.position) else KEY_NORMAL)
	elif event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		slider.add_theme_icon_override("grabber_highlight", KEY_HOVER if Rect2(Vector2.ZERO, slider.size).has_point(event.position) else KEY_NORMAL)
