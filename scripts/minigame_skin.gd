extends RefCounted

static func apply(root: Control, surface: Color, accent: Color, focus: Color) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children(): stack.append(child)
		if node is Panel:
			var box := StyleBoxFlat.new()
			box.bg_color = surface
			box.border_color = Color(accent, 0.58)
			box.set_border_width_all(1)
			box.set_corner_radius_all(7)
			box.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
			box.shadow_size = 3
			node.add_theme_stylebox_override("panel", box)
		elif node is Button:
			var normal := _button_box(surface.lightened(0.08), accent.darkened(0.32))
			var hover := _button_box(surface.lightened(0.2), focus)
			var pressed := _button_box(surface.darkened(0.14), focus.lightened(0.08))
			var disabled := _button_box(surface.darkened(0.12), Color(accent, 0.24))
			node.add_theme_stylebox_override("normal", normal)
			node.add_theme_stylebox_override("hover", hover)
			node.add_theme_stylebox_override("pressed", pressed)
			node.add_theme_stylebox_override("disabled", disabled)
			node.add_theme_stylebox_override("focus", hover)
			node.add_theme_color_override("font_color", Color("e7dfef"))
			node.add_theme_color_override("font_hover_color", focus.lightened(0.18))
			node.add_theme_color_override("font_pressed_color", Color("fff0ce"))
			node.add_theme_color_override("font_disabled_color", Color(0.65, 0.62, 0.69, 0.58))

static func _button_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color(edge, 0.8)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box
