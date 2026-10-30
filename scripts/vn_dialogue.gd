extends Control

## Reusable visual-novel dialogue widget.
## Entries are dictionaries with speaker_id, speaker, emotion, side, text and
## an optional choices array: [{"text": "...", "id": "...", "next": 2}].

signal finished
signal line_changed(index: int)
signal choice_selected(id: String)

const LOGICAL_SIZE := Vector2(960, 540)
const PANEL_RECT := Rect2(20, 358, 920, 162)
const PORTRAIT_SIZE := Vector2(292, 286)
const PORTRAIT_TOP := 78.0
const TYPE_SPEED := 46.0
const EMOTIONS := ["neutral", "happy", "sad", "angry", "surprised", "afraid", "embarrassed"]

var entries: Array = []
var index := 0
var character_progress := 0.0
var revealing := false
var choice_buttons: Array[Button] = []
var choice_index := 0
var _slots := {"left": [], "right": []}
var _slot_active := {"left": false, "right": false}
var _inactive_materials := {}
var _current_side := "left"
var _speaker_label: Label
var _text: RichTextLabel
var _continue: Button
var _counter: Label
var _hint: Label
var _choice_layer: VBoxContainer
var _theme_font := ThemeDB.fallback_font
var _shadow_material: ShaderMaterial
var _inactive_portrait_shader: Shader
var _silhouette_shadows := {}
var _dialogue_window_layer: Panel
var _line_has_portraits := false
var phone_chat_mode := false
var phone_call_mode := false
var phone_call_caller := ""
var phone_call_discord := false
var current_clock_text := "03:48"

const PHONE_RECT := Rect2(328, 28, 304, 484)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = LOGICAL_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_create_portrait_slots()
	_create_dialogue_controls()
	hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	if not revealing:
		return
	character_progress += TYPE_SPEED * delta
	_text.visible_characters = mini(int(character_progress), _text.get_total_character_count())
	if _text.visible_characters >= _text.get_total_character_count():
		revealing = false
		_show_choices()
		_update_continue_text()
		queue_redraw()

func _draw() -> void:
	if not visible:
		return
	if phone_chat_mode:
		draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color(0.025, 0.018, 0.055, 0.34))
		var phone := StyleBoxFlat.new()
		phone.bg_color = Color("11131c")
		phone.border_color = Color("88739a")
		phone.set_border_width_all(3)
		phone.set_corner_radius_all(22)
		draw_style_box(phone, PHONE_RECT)
		var header := StyleBoxFlat.new()
		header.bg_color = Color("303452") if phone_call_discord else (Color("292437") if not phone_call_mode else Color("30283a"))
		header.set_corner_radius_all(8)
		draw_style_box(header, Rect2(343, 73, 274, 54))
		var bubble_rect := _phone_bubble_rect()
		var bubble := StyleBoxFlat.new()
		bubble.bg_color = Color("51416d") if str(current_entry().get("speaker_id", "narrator")) == "grat" else Color("282633")
		bubble.set_corner_radius_all(10)
		draw_style_box(bubble, bubble_rect)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(350, 51), current_clock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c9c3d1"))
		draw_string(font, Vector2(548, 51), "● ● ●  ▰", HORIZONTAL_ALIGNMENT_RIGHT, 68, 11, Color("c9c3d1"))
		if phone_call_mode:
			if phone_call_discord:
				# A small controller-shaped mark distinguishes the Discord call card.
				draw_rect(Rect2(350, 84, 20, 13), Color("8e91ee"))
				draw_circle(Vector2(356, 91), 1.5, Color("f5f1ff"))
				draw_circle(Vector2(364, 91), 1.5, Color("f5f1ff"))
				draw_string(font, Vector2(377, 96), "DISCORD · ВХОДЯЩИЙ", HORIZONTAL_ALIGNMENT_LEFT, 232, 10, Color("f0eaf7"))
			else:
				draw_string(font, Vector2(354, 96), "ВХОДЯЩИЙ ЗВОНОК", HORIZONTAL_ALIGNMENT_LEFT, 250, 11, Color("f0eaf7"))
			draw_string(font, Vector2(354, 117), phone_call_caller, HORIZONTAL_ALIGNMENT_LEFT, 250, 9 if phone_call_discord else 11, Color("d0b8e6"))
		else:
			draw_string(font, Vector2(380, 98), "ДРУЗЬЯ", HORIZONTAL_ALIGNMENT_LEFT, 170, 16, Color("f0eaf7"))
			draw_string(font, Vector2(381, 117), "Артрей · в сети", HORIZONTAL_ALIGNMENT_LEFT, 170, 11, Color("9bc8a9"))
		return
	# A cool transparent veil keeps the room visible while making faces/text read.
	draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color(0.025, 0.018, 0.055, 0.22))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.055, 0.038, 0.10, 0.97)
	panel.border_color = Color(0.66, 0.52, 0.78, 0.92)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
	panel.shadow_color = Color(0.01, 0.005, 0.025, 0.75)
	panel.shadow_size = 12
	draw_style_box(panel, PANEL_RECT)
	# Gold separator gives the text box a visual anchor without hiding the scene.
	draw_line(Vector2(42, 405), Vector2(918, 405), Color(0.75, 0.62, 0.82, 0.22), 1.0)

func _create_portrait_slots() -> void:
	var shadow_shader := Shader.new()
	shadow_shader.code = "shader_type canvas_item; void fragment() { vec4 c = texture(TEXTURE, UV); COLOR = vec4(0.025, 0.018, 0.04, c.a * 0.38); }"
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = shadow_shader
	_inactive_portrait_shader = Shader.new()
	_inactive_portrait_shader.code = """
	shader_type canvas_item;
	uniform vec2 region_uv_min = vec2(0.0, 0.0);
	uniform vec2 region_uv_max = vec2(1.0, 1.0);
	uniform float blur_radius = 1.2;
	void fragment() {
		vec2 step_uv = TEXTURE_PIXEL_SIZE * blur_radius;
		vec4 color = texture(TEXTURE, UV) * 0.4;
		color += texture(TEXTURE, clamp(UV + vec2(step_uv.x, 0.0), region_uv_min, region_uv_max)) * 0.15;
		color += texture(TEXTURE, clamp(UV - vec2(step_uv.x, 0.0), region_uv_min, region_uv_max)) * 0.15;
		color += texture(TEXTURE, clamp(UV + vec2(0.0, step_uv.y), region_uv_min, region_uv_max)) * 0.15;
		color += texture(TEXTURE, clamp(UV - vec2(0.0, step_uv.y), region_uv_min, region_uv_max)) * 0.15;
		COLOR = color * COLOR;
	}
	"""
	for side in ["left", "right"]:
		var slots: Array = []
		var inactive_material := ShaderMaterial.new()
		inactive_material.shader = _inactive_portrait_shader
		_inactive_materials[side] = inactive_material
		var silhouette := TextureRect.new()
		silhouette.name = "%sSilhouetteShadow" % side.capitalize()
		silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		silhouette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		silhouette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		silhouette.material = _shadow_material
		silhouette.position = Vector2(18 if side == "left" else 650, PORTRAIT_TOP + 7)
		silhouette.size = PORTRAIT_SIZE
		silhouette.pivot_offset = PORTRAIT_SIZE * 0.5
		silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		silhouette.modulate.a = 0.0
		add_child(silhouette)
		_silhouette_shadows[side] = silhouette
		for layer in range(2):
			var portrait := TextureRect.new()
			portrait.name = "%sPortrait%d" % [side.capitalize(), layer]
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			portrait.position = Vector2(18 if side == "left" else 650, PORTRAIT_TOP)
			portrait.size = PORTRAIT_SIZE
			portrait.pivot_offset = PORTRAIT_SIZE * 0.5
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.modulate = Color(1, 1, 1, 0)
			add_child(portrait)
			slots.append(portrait)
		_slots[side] = slots
	# Draw the opaque dialogue panel over the lower edge of the portraits.
	var dialogue_panel := Panel.new()
	_dialogue_window_layer = dialogue_panel
	dialogue_panel.name = "DialogueWindowLayer"
	dialogue_panel.position = PANEL_RECT.position
	dialogue_panel.size = PANEL_RECT.size
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.038, 0.10, 0.99)
	panel_style.border_color = Color(0.66, 0.52, 0.78, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialogue_panel)

func _create_dialogue_controls() -> void:
	_speaker_label = Label.new()
	_speaker_label.position = Vector2(42, 367)
	_speaker_label.size = Vector2(270, 38)
	_speaker_label.add_theme_font_size_override("font_size", 20)
	_speaker_label.add_theme_color_override("font_color", Color("ffe0a9"))
	_speaker_label.add_theme_color_override("font_outline_color", Color(0.035, 0.018, 0.07, 0.98))
	_speaker_label.add_theme_constant_override("outline_size", 5)
	_speaker_label.add_theme_color_override("font_shadow_color", Color(0.03, 0.01, 0.07, 0.9))
	_speaker_label.add_theme_constant_override("shadow_offset_x", 2)
	_speaker_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_speaker_label)

	_text = RichTextLabel.new()
	_text.position = Vector2(43, 414)
	_text.size = Vector2(850, 57)
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = true
	_text.clip_contents = true
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_font_size_override("bold_font_size", 19)
	_text.add_theme_color_override("default_color", Color("f3ecff"))
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_text)

	_choice_layer = VBoxContainer.new()
	_choice_layer.position = Vector2(324, 164)
	_choice_layer.size = Vector2(312, 174)
	_choice_layer.add_theme_constant_override("separation", 7)
	_choice_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_choice_layer)

	_continue = Button.new()
	_continue.name = "ContinueButton"
	_continue.position = Vector2(705, 474)
	_continue.size = Vector2(205, 32)
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_continue.add_theme_font_size_override("font_size", 15)
	_continue.pressed.connect(advance)
	_apply_button_style(_continue, Color("443258"), Color("745888"), Color("9b79af"))
	add_child(_continue)

	_hint = Label.new()
	_hint.position = Vector2(44, 481)
	_hint.size = Vector2(590, 24)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color("bcb0cc"))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_counter = Label.new()
	_counter.clip_text = true
	_counter.position = Vector2(748, 367)
	_counter.size = Vector2(164, 26)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.add_theme_font_size_override("font_size", 14)
	_counter.add_theme_color_override("font_color", Color("d8b47d"))
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_counter)

func _apply_button_style(button: Button, normal_color: Color, hover_color: Color, pressed_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = normal_color
	normal.border_color = Color(0.72, 0.62, 0.82, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	normal.set_content_margin_all(7)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover_color
	hover.border_color = Color("dfb8f2")
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = pressed_color
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.18, 0.14, 0.24, 0.75)
	button.add_theme_stylebox_override("disabled", disabled)

func start(new_entries: Array, start_index: int = 0) -> void:
	entries = new_entries.duplicate(true)
	index = clampi(start_index, 0, maxi(0, entries.size() - 1))
	show()
	grab_focus()
	_load_line()

func set_phone_chat_mode(enabled: bool) -> void:
	phone_call_mode = false
	phone_call_caller = ""
	phone_call_discord = false
	phone_chat_mode = enabled
	if is_instance_valid(_dialogue_window_layer):
		_dialogue_window_layer.visible = not enabled
	queue_redraw()
	if visible and index < entries.size():
		_layout_current_line()
		_update_portraits(current_entry())

func set_phone_call_mode(caller: String, discord: bool) -> void:
	phone_call_mode = not caller.is_empty()
	phone_call_caller = caller
	phone_call_discord = discord
	phone_chat_mode = phone_call_mode
	if is_instance_valid(_dialogue_window_layer):
		_dialogue_window_layer.visible = not phone_chat_mode
	queue_redraw()
	if visible and index < entries.size():
		_layout_current_line()
		_update_portraits(current_entry())

func set_clock_text(value: String) -> void:
	current_clock_text = value
	queue_redraw()

func _phone_bubble_rect() -> Rect2:
	if str(current_entry().get("speaker_id", "narrator")) == "grat":
		return Rect2(384, 138, 233, 168)
	return Rect2(343, 138, 274, 168)

func _layout_current_line() -> void:
	if phone_chat_mode:
		var bubble := _phone_bubble_rect()
		_speaker_label.position = bubble.position + Vector2(12, 10)
		_speaker_label.size = Vector2(bubble.size.x - 24, 20)
		var is_long_call_name := phone_call_mode and str(current_entry().get("speaker_id", "")) == "caller"
		_speaker_label.add_theme_font_size_override("font_size", 9 if is_long_call_name else (13 if not phone_call_mode else 12))
		_speaker_label.clip_text = true
		_speaker_label.add_theme_color_override("font_color", Color("cfb9e9") if str(current_entry().get("speaker_id", "")) == "grat" else Color("c8c2d0"))
		_speaker_label.add_theme_color_override("font_outline_color", Color(0,0,0,0))
		_speaker_label.add_theme_constant_override("outline_size", 0)
		_speaker_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0))
		_speaker_label.add_theme_constant_override("shadow_offset_x", 0)
		_speaker_label.add_theme_constant_override("shadow_offset_y", 0)
		_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_text.position = bubble.position + Vector2(12, 34)
		_text.size = Vector2(bubble.size.x - 24, bubble.size.y - 45)
		_text.add_theme_font_size_override("normal_font_size", 15)
		_text.add_theme_font_size_override("bold_font_size", 15)
		_choice_layer.position = Vector2(342, 316)
		_choice_layer.size = Vector2(276, 164)
		_choice_layer.clip_contents = true
		_choice_layer.add_theme_constant_override("separation", 5)
		_continue.position = Vector2(348, 463)
		_continue.size = Vector2(264, 32)
		_hint.position = Vector2(346, 495)
		_hint.size = Vector2(268, 15)
		_hint.add_theme_font_size_override("font_size", 10)
		_counter.position = Vector2(548, 82)
		_counter.size = Vector2(60, 18)
		_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_counter.add_theme_font_size_override("font_size", 11)
		_line_has_portraits = false
		return
	_speaker_label.position = Vector2(42, 367)
	_speaker_label.size = Vector2(270, 38)
	_speaker_label.add_theme_font_size_override("font_size", 20)
	_speaker_label.add_theme_color_override("font_color", Color("ffe0a9"))
	_speaker_label.add_theme_color_override("font_outline_color", Color(0.035, 0.018, 0.07, 0.98))
	_speaker_label.add_theme_constant_override("outline_size", 5)
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.position = Vector2(43, 414)
	_text.size = Vector2(850, 57)
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_font_size_override("bold_font_size", 19)
	_choice_layer.position = Vector2(324, 164)
	_choice_layer.size = Vector2(312, 174)
	_choice_layer.add_theme_constant_override("separation", 7)
	_continue.position = Vector2(705, 474)
	_continue.size = Vector2(205, 32)
	_hint.position = Vector2(44, 481)
	_hint.size = Vector2(590, 24)
	_hint.add_theme_font_size_override("font_size", 13)
	_counter.position = Vector2(748, 367)
	_counter.size = Vector2(164, 26)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.add_theme_font_size_override("font_size", 14)

func close() -> void:
	revealing = false
	hide()
	_clear_choices()

func is_revealing() -> bool:
	return revealing

func current_entry() -> Dictionary:
	if index < 0 or index >= entries.size():
		return {}
	return entries[index] as Dictionary

func advance() -> void:
	if not visible:
		return
	if revealing:
		character_progress = float(_text.get_total_character_count())
		_text.visible_characters = -1
		revealing = false
		_show_choices()
		_update_continue_text()
		return
	if not choice_buttons.is_empty():
		_select_choice(choice_index)
		return
	index = int(current_entry().get("next", index + 1))
	if index >= entries.size():
		finished.emit()
		return
	_load_line()

func select_choice(number: int) -> void:
	if choice_buttons.is_empty() or number < 0 or number >= choice_buttons.size():
		return
	_select_choice(number)

func _select_choice(number: int) -> void:
	var entry := current_entry()
	var choices: Array = entry.get("choices", [])
	if number < 0 or number >= choices.size():
		return
	var choice: Dictionary = choices[number]
	choice_selected.emit(str(choice.get("id", "")))
	_clear_choices()
	var next_value = choice.get("next", null)
	if next_value == null:
		index += 1
	else:
		index = int(next_value)
	if index >= entries.size():
		finished.emit()
	else:
		_load_line()

func handle_key(key: int) -> bool:
	if not visible:
		return false
	if key in [KEY_E, KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
		advance()
		return true
	if not choice_buttons.is_empty():
		if key in [KEY_UP, KEY_W]:
			choice_index = posmod(choice_index - 1, choice_buttons.size())
			_update_choice_focus()
			return true
		if key in [KEY_DOWN, KEY_S]:
			choice_index = posmod(choice_index + 1, choice_buttons.size())
			_update_choice_focus()
			return true
		if key >= KEY_1 and key <= KEY_9:
			var selected := key - KEY_1
			if selected < choice_buttons.size():
				_select_choice(selected)
			return true
	return false

func _load_line() -> void:
	_clear_choices()
	if index >= entries.size():
		finished.emit()
		return
	var entry := current_entry()
	var speaker_id := str(entry.get("speaker_id", "grat")).to_lower()
	var speaker_name := str(entry.get("speaker", _display_name(speaker_id)))
	_speaker_label.text = speaker_name
	_text.text = _compact_dialogue_text(str(entry.get("text", "")))
	_layout_current_line()
	# Keep longer early-story replies within the existing panel and portrait boundary.
	var font_size := 15 if phone_chat_mode else 19
	var minimum_font_size := 12 if phone_chat_mode else 15
	while font_size > minimum_font_size and _theme_font.get_multiline_string_size(_text.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, _text.size.x, font_size).y > _text.size.y:
		font_size -= 1
	_text.add_theme_font_size_override("normal_font_size", font_size)
	_text.add_theme_font_size_override("bold_font_size", font_size)
	_text.visible_characters = 0
	character_progress = 0.0
	revealing = true
	_counter.text = "%d / %d" % [index + 1, entries.size()] if phone_chat_mode else "Реплика %d / %d" % [index + 1, entries.size()]
	_hint.text = "E / Enter — показать реплику · ещё раз — продолжить"
	_hint.visible = not phone_chat_mode
	_update_portraits(entry)
	line_changed.emit(index)
	queue_redraw()

func _compact_dialogue_text(value: String) -> String:
	var compact := value.replace("\r\n", "\n")
	while compact.contains("\n\n"):
		compact = compact.replace("\n\n", "\n")
	return compact

func _show_choices() -> void:
	_clear_choices()
	var choices: Array = current_entry().get("choices", [])
	if choices.is_empty():
		return
	choice_index = 0
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button := Button.new()
		var choice_text := "%d. %s" % [i + 1, str(choice.get("text", "Ответить"))]
		button.text = "" if phone_chat_mode else choice_text
		button.custom_minimum_size = Vector2(276, 48) if phone_chat_mode else Vector2(312, 36 if choices.size() >= 4 else 39)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 13 if phone_chat_mode else 15)
		_apply_button_style(button, Color(0.12, 0.09, 0.19, 0.96), Color(0.32, 0.22, 0.42, 0.98), Color(0.49, 0.32, 0.54, 1.0))
		if phone_chat_mode:
			var label := Label.new()
			label.text = choice_text
			label.position = Vector2(10, 4)
			label.size = Vector2(256, 40)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 13)
			label.add_theme_color_override("font_color", Color("f0eaf7"))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(label)
		button.pressed.connect(_select_choice.bind(i))
		_choice_layer.add_child(button)
		choice_buttons.append(button)
	_update_choice_focus()
	_hint.text = "↑ / ↓ или 1–%d — выбрать · Enter — ответить" % choices.size()

func _clear_choices() -> void:
	for child in _choice_layer.get_children():
		child.queue_free()
	choice_buttons.clear()

func _update_choice_focus() -> void:
	for i in range(choice_buttons.size()):
		choice_buttons[i].modulate = Color(1.0, 0.93, 0.86, 1.0) if i == choice_index else Color.WHITE

func _update_continue_text() -> void:
	if not choice_buttons.is_empty():
		_continue.hide()
		_hint.visible = not phone_chat_mode or not _hint.text.is_empty()
	else:
		_continue.show()
		_continue.text = "Продолжить · E  ›" if phone_chat_mode else "Продолжить  ›"
		_hint.visible = not phone_chat_mode

func _update_portraits(entry: Dictionary) -> void:
	if phone_chat_mode:
		_line_has_portraits = false
		for side in ["left", "right"]:
			_set_portrait(side, {}, false)
		return
	var portrait_data: Dictionary = entry.get("portraits", {})
	_line_has_portraits = not portrait_data.is_empty()
	for side in ["left", "right"]:
		var data: Dictionary = portrait_data.get(side, {})
		if data.is_empty() and str(entry.get("side", "left")) == side:
			data = {"speaker_id": entry.get("speaker_id", "grat"), "emotion": entry.get("emotion", "neutral")}
		var show_portrait := not data.is_empty() and str(data.get("speaker_id", "")) != "narrator"
		_set_portrait(side, data if show_portrait else {}, side == str(entry.get("side", "left")) and show_portrait)

func _set_portrait(side: String, data: Dictionary, active: bool) -> void:
	var slots: Array = _slots[side]
	var portrait: TextureRect = slots[0]
	var spare: TextureRect = slots[1]
	var speaker_id := str(data.get("speaker_id", ""))
	# Grok's lower edge sits exactly on the dialogue panel's upper border.
	var layout_position := Vector2(18 if side == "left" else 650, PANEL_RECT.position.y - PORTRAIT_SIZE.y if speaker_id == "grok" else PORTRAIT_TOP)
	portrait.position = layout_position
	spare.position = layout_position
	var silhouette: TextureRect = _silhouette_shadows[side]
	silhouette.position = layout_position + Vector2(0, 7)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	spare.stretch_mode = portrait.stretch_mode
	portrait.material = null
	spare.material = null
	spare.modulate = Color(1, 1, 1, 0)
	spare.texture = null
	var texture: Texture2D = _portrait_texture(speaker_id, str(data.get("emotion", "neutral")), side) if not data.is_empty() else null
	if texture != null:
		silhouette.texture = texture
		silhouette.modulate.a = 1.0
		var fitted_height := PORTRAIT_SIZE.x * texture.get_height() / texture.get_width()
		portrait.position.y = maxf(PANEL_RECT.position.y - fitted_height, 0.0)
		spare.position.y = portrait.position.y
		silhouette.position = portrait.position + Vector2(0, 7)
	if texture == null:
		silhouette.texture = null
		silhouette.modulate.a = 0.0
		portrait.texture = null
		portrait.modulate = Color(1, 1, 1, 0)
		portrait.scale = Vector2.ONE
		silhouette.scale = Vector2.ONE
		_slot_active[side] = false
		return
	portrait.texture = texture
	var portrait_scale := 1.0 if active else 0.97
	portrait.scale = Vector2.ONE * portrait_scale
	silhouette.scale = portrait.scale
	if active:
		portrait.material = null
		portrait.modulate = Color(0.96, 0.96, 0.98, 1.0)
	else:
		var atlas_texture := texture as AtlasTexture
		var source_size := atlas_texture.atlas.get_size()
		var region := atlas_texture.region
		var region_padding := Vector2.ONE / source_size
		var inactive_material := _inactive_materials[side] as ShaderMaterial
		inactive_material.set_shader_parameter("region_uv_min", region.position / source_size + region_padding)
		inactive_material.set_shader_parameter("region_uv_max", region.end / source_size - region_padding)
		portrait.material = inactive_material
		portrait.modulate = Color(0.88, 0.88, 0.92, 1.0)
	_slot_active[side] = active

func _portrait_texture(speaker_id: String, emotion: String, side: String) -> Texture2D:
	if speaker_id not in ["grat", "grok", "jbt"]:
		return null
	if emotion not in EMOTIONS:
		emotion = "neutral"
	var texture_path := "res://assets/portraits/%s-emotions.png" % speaker_id
	var atlas_source := load(texture_path) as Texture2D
	if atlas_source == null:
		return null
	var frame := EMOTIONS.find(emotion)
	var row := 0 if side == "left" else 2
	if frame >= 4:
		row += 1
		frame -= 4
	var cell_size := atlas_source.get_size() / 4.0
	var atlas := AtlasTexture.new()
	atlas.atlas = atlas_source
	if speaker_id == "grok":
		# Keep each crop inside the new atlas cell. Equal row spacing avoids
		# including the lower edge of the previous portrait at the top.
		var row_edges := [0.0, 300.0, 600.0, 900.0, atlas_source.get_height()]
		var column_starts := [5.0, 325.0, 643.0, 961.0]
		var region_height: float = float(row_edges[row + 1]) - float(row_edges[row]) - 6.0
		atlas.region = Rect2(column_starts[frame], row_edges[row] + 3.0, 318.0, region_height)
		atlas.filter_clip = true
		return atlas
	# Inset a couple of source pixels so linear filtering never bleeds a
	# neighbour's emotion/background into the current portrait.
	var top_inset := 0.0 if speaker_id == "grok" else 8.0
	atlas.region = Rect2(Vector2(frame, row) * cell_size + Vector2(3, top_inset), cell_size - Vector2(6, top_inset + 5.0))
	return atlas

func _display_name(speaker_id: String) -> String:
	return {"grat": "Грат", "grok": "Грок", "jbt": "ЖБТ", "artrey": "Артрей", "narrator": "СЦЕНА"}.get(speaker_id, "СЦЕНА")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var active_rect := PHONE_RECT if phone_chat_mode else PANEL_RECT
		if not active_rect.has_point(event.position) and choice_buttons.is_empty():
			advance()
			accept_event()
