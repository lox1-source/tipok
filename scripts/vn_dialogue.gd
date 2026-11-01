extends Control

const UIButtons = preload("res://scripts/ui_buttons.gd")
const DisplayNames = preload("res://scripts/display_names.gd")
const CALL_AVATARS := {
	"workersgoincrazy@outlook.com": preload("res://assets/ui/call_avatars/worker_drx.png"),
	"mlff": preload("res://assets/ui/call_avatars/mlff.png"),
	"Палыч": preload("res://assets/ui/call_avatars/palych.png"),
}

## Reusable visual-novel dialogue widget.
## Entries are dictionaries with speaker_id, speaker, emotion, side, text and
## an optional choices array: [{"text": "...", "id": "...", "next": 2}].

signal finished
signal line_changed(index: int)
signal choice_selected(id: String)

const LOGICAL_SIZE := Vector2(960, 540)
const PANEL_RECT := Rect2(18, 322, 924, 198)
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
var _choice_layer: Control
var _theme_font := ThemeDB.fallback_font
var _shadow_material: ShaderMaterial
var _inactive_portrait_shader: Shader
var _silhouette_shadows := {}
var _dialogue_window_layer: Panel
var _active_dialogue_rect := PANEL_RECT
var _line_has_portraits := false
var phone_chat_mode := false
var phone_call_mode := false
var phone_call_caller := ""
var phone_call_discord := false
var _call_avatar: TextureRect
var _chat_avatar: TextureRect
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
	_create_call_avatar()
	_create_chat_avatar()
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
		if phone_call_mode:
			_draw_phone_call()
			return
		# Keep story chats visually consistent with the redesigned phone app used
		# in the room. This was previously a separate, older VN-only phone skin.
		draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color(0.025, 0.018, 0.055, 0.40))
		var phone := StyleBoxFlat.new()
		phone.bg_color = Color("77708d")
		phone.set_corner_radius_all(29)
		phone.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
		phone.shadow_size = 12
		phone.shadow_offset = Vector2(0, 5)
		draw_style_box(phone, PHONE_RECT)
		var screen := StyleBoxFlat.new()
		screen.bg_color = Color("111522")
		screen.set_corner_radius_all(24)
		draw_style_box(screen, Rect2(333, 33, 294, 474))
		draw_rect(Rect2(337, 132, 286, 360), Color("171827"))
		var notch := StyleBoxFlat.new()
		notch.bg_color = Color("393944")
		notch.set_corner_radius_all(5)
		draw_style_box(notch, Rect2(445, 37, 70, 8))
		var header := StyleBoxFlat.new()
		header.bg_color = Color("1c2030")
		header.set_corner_radius_all(13)
		draw_style_box(header, Rect2(343, 73, 274, 54))
		var bubble_rect := _phone_bubble_rect()
		var bubble := StyleBoxFlat.new()
		bubble.bg_color = Color("51416d") if str(current_entry().get("speaker_id", "narrator")) == "grat" else Color("2b2c3c")
		bubble.set_corner_radius_all(17)
		draw_style_box(bubble, bubble_rect)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(350, 51), current_clock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c9c3d1"))
		draw_string(font, Vector2(548, 51), "● ● ●  ▰", HORIZONTAL_ALIGNMENT_RIGHT, 68, 11, Color("c9c3d1"))
		draw_circle(Vector2(371, 100), 20, Color("4a415f"))
		draw_arc(Vector2(371, 100), 20, 0.0, TAU, 40, Color("8d7a9d"), 1.0)
		draw_string(font, Vector2(397, 97), "Артбей", HORIZONTAL_ALIGNMENT_LEFT, 180, 15, Color("f4edf9"))
		draw_string(font, Vector2(398, 116), "в сети · сообщения", HORIZONTAL_ALIGNMENT_LEFT, 180, 10, Color("9dcab4"))
		draw_string(font, Vector2(350, 148), "СЕГОДНЯ · " + current_clock_text, HORIZONTAL_ALIGNMENT_CENTER, 260, 9, Color("8f91a4"))
		draw_line(Vector2(348, 451), Vector2(612, 451), Color("30303e"), 1.0)
		# Keep the home indicator clear of the dialogue-choice instructions.
		if current_entry().get("choices", []).is_empty():
			draw_line(Vector2(447, 499), Vector2(513, 499), Color("b1aabc"), 3.0)
		return
	# Keep the room legible while the textured VN window sits above the portraits.
	draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color(0.025, 0.018, 0.055, 0.22))

func _draw_phone_call() -> void:
	# The call uses the same rounded shell and notch as the room phone. Discord
	# keeps its own dark charcoal and blurple accents inside that shell.
	draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color(0.025, 0.018, 0.055, 0.43))
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color("77708d")
	shell.set_corner_radius_all(29)
	draw_style_box(shell, PHONE_RECT)
	var screen := StyleBoxFlat.new()
	screen.bg_color = Color("1e1f22") if phone_call_discord else Color("111522")
	screen.set_corner_radius_all(24)
	draw_style_box(screen, Rect2(333, 33, 294, 474))
	var notch := StyleBoxFlat.new()
	notch.bg_color = Color("393944")
	notch.set_corner_radius_all(4)
	draw_style_box(notch, Rect2(445, 37, 70, 7))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(351, 62), current_clock_text, HORIZONTAL_ALIGNMENT_LEFT, 90, 11, Color("cbc9d3"))
	draw_string(font, Vector2(539, 62), "● ● ●  ▰", HORIZONTAL_ALIGNMENT_RIGHT, 67, 10, Color("cbc9d3"))
	if phone_call_discord:
		draw_circle(Vector2(356, 86), 10, Color("5865f2"))
		draw_circle(Vector2(352, 86), 1.6, Color.WHITE)
		draw_circle(Vector2(360, 86), 1.6, Color.WHITE)
		draw_string(font, Vector2(373, 91), "Discord", HORIZONTAL_ALIGNMENT_LEFT, 120, 15, Color("f3f4fb"))
	else:
		draw_string(font, Vector2(350, 91), "ТЕЛЕФОН", HORIZONTAL_ALIGNMENT_LEFT, 200, 12, Color("d9d5e4"))
	var avatar_back := Color("343648") if phone_call_discord else Color("30273d")
	draw_circle(Vector2(480, 153), 49, avatar_back)
	draw_arc(Vector2(480, 153), 50, 0.0, TAU, 64, Color("858cf4") if phone_call_discord else Color("b494ca"), 2.0)
	draw_string(font, Vector2(350, 219), phone_call_caller, HORIZONTAL_ALIGNMENT_CENTER, 260, 11 if phone_call_discord else 16, Color("f2edf7"))
	draw_string(font, Vector2(350, 239), "ГОЛОСОВОЙ ВЫЗОВ" if phone_call_discord else "ВХОДЯЩИЙ ЗВОНОК", HORIZONTAL_ALIGNMENT_CENTER, 260, 10, Color("aeb2c6"))
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = Color("2b2d36") if phone_call_discord else Color("292534")
	bubble.set_corner_radius_all(10)
	draw_style_box(bubble, _phone_bubble_rect())
	draw_line(Vector2(353, 454), Vector2(607, 454), Color("52515e"), 1.0)
	draw_string(font, Vector2(354, 451), "РАЗГОВОР", HORIZONTAL_ALIGNMENT_LEFT, 180, 9, Color("aeb2c6"))

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
	UIButtons.apply_panel(dialogue_panel)
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialogue_panel)

func _create_dialogue_controls() -> void:
	_speaker_label = Label.new()
	_speaker_label.position = Vector2(42, 332)
	_speaker_label.size = Vector2(270, 34)
	_speaker_label.add_theme_font_size_override("font_size", 20)
	_speaker_label.add_theme_color_override("font_color", Color("ffe0a9"))
	_speaker_label.add_theme_color_override("font_outline_color", Color(0.035, 0.018, 0.07, 0.98))
	_speaker_label.add_theme_constant_override("outline_size", 5)
	_speaker_label.add_theme_color_override("font_shadow_color", Color(0.03, 0.01, 0.07, 0.9))
	_speaker_label.add_theme_constant_override("shadow_offset_x", 2)
	_speaker_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_speaker_label)

	_text = RichTextLabel.new()
	_text.position = Vector2(43, 380)
	_text.size = Vector2(872, 78)
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

	_choice_layer = Control.new()
	_choice_layer.position = Vector2(72, 414)
	_choice_layer.size = Vector2(816, 98)
	_choice_layer.clip_contents = true
	_choice_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_choice_layer)

	_continue = Button.new()
	_continue.name = "ContinueButton"
	_continue.position = Vector2(716, 468)
	_continue.size = Vector2(196, 38)
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_continue.add_theme_font_size_override("font_size", 15)
	_continue.pressed.connect(advance)
	_apply_button_style(_continue, Color("443258"), Color("745888"), Color("9b79af"))
	add_child(_continue)

	_hint = Label.new()
	_hint.position = Vector2(44, 481)
	_hint.size = Vector2(630, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color("bcb0cc"))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_counter = Label.new()
	_counter.clip_text = true
	_counter.position = Vector2(740, 333)
	_counter.size = Vector2(172, 26)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.add_theme_font_size_override("font_size", 14)
	_counter.add_theme_color_override("font_color", Color("d8b47d"))
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_counter)
	# The dialogue array contains branches the player never sees. A line number
	# based on the full array falsely suggests a linear, much longer conversation.
	# Chapter/location context is already shown by the HUD, so omit this counter.
	_counter.hide()

func _create_call_avatar() -> void:
	_call_avatar = TextureRect.new()
	_call_avatar.name = "CallAvatar"
	_call_avatar.position = Vector2(437, 110)
	_call_avatar.size = Vector2(86, 86)
	_call_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_call_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_call_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_call_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://assets/ui/phone_avatar.gdshader")
	_call_avatar.material = mask
	add_child(_call_avatar)
	_call_avatar.hide()

func _create_chat_avatar() -> void:
	_chat_avatar = TextureRect.new()
	_chat_avatar.name = "ChatContactAvatar"
	_chat_avatar.position = Vector2(353, 82)
	_chat_avatar.size = Vector2(36, 36)
	_chat_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chat_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_chat_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_chat_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/portraits/artrey-portrait.png") as Texture2D
	# The portrait file has more space around the head than the emotion sheet,
	# so the circular icon shows the whole hairstyle and chin instead of a fragment.
	atlas.region = Rect2(160, 20, 800, 800)
	_chat_avatar.texture = atlas
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://assets/ui/phone_avatar.gdshader")
	_chat_avatar.material = mask
	add_child(_chat_avatar)
	_chat_avatar.hide()

func _apply_button_style(button: Button, normal_color: Color, hover_color: Color, pressed_color: Color) -> void:
	UIButtons.apply(button)

func _style_call_continue() -> void:
	var discord := phone_call_discord
	var base := StyleBoxFlat.new()
	base.bg_color = Color("454d91") if discord else Color("513c65")
	base.border_color = Color("8990cf") if discord else Color("a385b7")
	base.set_border_width_all(1)
	base.set_corner_radius_all(9)
	base.shadow_color = Color(0.01, 0.01, 0.03, 0.48)
	base.shadow_size = 4
	base.shadow_offset = Vector2(0, 2)
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color("5963af") if discord else Color("67507c")
	hover.border_color = Color("b4bbf2") if discord else Color("d2b5df")
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("333b76") if discord else Color("392a4d")
	pressed.shadow_size = 1
	pressed.shadow_offset = Vector2.ZERO
	_continue.add_theme_stylebox_override("normal", base)
	_continue.add_theme_stylebox_override("hover", hover)
	_continue.add_theme_stylebox_override("pressed", pressed)
	_continue.add_theme_stylebox_override("focus", hover)
	_continue.add_theme_color_override("font_color", Color("f5f1fb"))
	_continue.add_theme_color_override("font_hover_color", Color.WHITE)
	_continue.add_theme_color_override("font_pressed_color", Color("e2ddf2"))
	_continue.add_theme_font_size_override("font_size", 14)

func _style_phone_chat_continue() -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color("242738")
	base.border_color = Color("6e5b82")
	base.set_border_width_all(1)
	base.set_corner_radius_all(13)
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color("313247")
	hover.border_color = Color("a790bb")
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("514066")
	_continue.add_theme_stylebox_override("normal", base)
	_continue.add_theme_stylebox_override("hover", hover)
	_continue.add_theme_stylebox_override("pressed", pressed)
	_continue.add_theme_stylebox_override("focus", hover)
	_continue.add_theme_color_override("font_color", Color("f4edf9"))
	_continue.add_theme_color_override("font_hover_color", Color.WHITE)
	_continue.add_theme_color_override("font_pressed_color", Color("e2ddf2"))
	_continue.add_theme_font_size_override("font_size", 13)

func _reset_continue_style() -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		_continue.remove_theme_stylebox_override(state)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		_continue.remove_theme_color_override(state)
	_continue.add_theme_font_size_override("font_size", 15)

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
	if enabled:
		_style_phone_chat_continue()
	else:
		_reset_continue_style()
	_call_avatar.hide()
	_chat_avatar.visible = enabled
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
	if phone_call_mode:
		_style_call_continue()
	else:
		_reset_continue_style()
	_call_avatar.texture = CALL_AVATARS.get(caller) if phone_call_mode else null
	_call_avatar.visible = phone_call_mode and _call_avatar.texture != null
	_chat_avatar.hide()
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
	if phone_call_mode:
		return Rect2(343, 254, 274, 184)
	if not current_entry().get("choices", []).is_empty():
		if str(current_entry().get("speaker_id", "narrator")) == "grat":
			return Rect2(382, 160, 235, 136)
		return Rect2(343, 160, 274, 136)
	if str(current_entry().get("speaker_id", "narrator")) == "grat":
		return Rect2(382, 160, 235, 218)
	return Rect2(343, 160, 274, 218)

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
		_text.add_theme_font_size_override("normal_font_size", 14)
		_text.add_theme_font_size_override("bold_font_size", 14)
		_choice_layer.position = Vector2(342, 316)
		_choice_layer.size = Vector2(276, 164)
		_choice_layer.clip_contents = true
		_choice_layer.add_theme_constant_override("separation", 5)
		_continue.position = Vector2(360, 461) if phone_call_mode else Vector2(348, 463)
		_continue.size = Vector2(240, 36) if phone_call_mode else Vector2(264, 32)
		_hint.position = Vector2(344, 482)
		_hint.size = Vector2(272, 17)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.add_theme_font_size_override("font_size", 9)
		_counter.position = Vector2(548, 82)
		_counter.size = Vector2(60, 18)
		_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_counter.add_theme_font_size_override("font_size", 11)
		_line_has_portraits = false
		return
	_speaker_label.position = Vector2(42, 332)
	_speaker_label.size = Vector2(270, 34)
	_speaker_label.add_theme_font_size_override("font_size", 20)
	_speaker_label.add_theme_color_override("font_color", Color("ffe0a9"))
	_speaker_label.add_theme_color_override("font_outline_color", Color(0.035, 0.018, 0.07, 0.98))
	_speaker_label.add_theme_constant_override("outline_size", 5)
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.position = Vector2(43, 380)
	_text.size = Vector2(872, 78)
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_font_size_override("bold_font_size", 19)
	_choice_layer.position = Vector2(72, 414)
	_choice_layer.size = Vector2(816, 98)
	_choice_layer.add_theme_constant_override("separation", 7)
	_continue.position = Vector2(716, 468)
	_continue.size = Vector2(196, 38)
	_hint.position = Vector2(44, 481)
	_hint.size = Vector2(630, 24)
	_hint.add_theme_font_size_override("font_size", 13)
	_counter.position = Vector2(740, 333)
	_counter.size = Vector2(172, 26)
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
		# A choice is a decision, never an implicit continue action.
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
	if not choice_buttons.is_empty():
		if key in [KEY_SPACE, KEY_E]:
			return true
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
		if key in [KEY_ENTER, KEY_KP_ENTER]:
			_select_choice(choice_index)
			return true
		return false
	if key in [KEY_E, KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
		advance()
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
	_speaker_label.text = "Фотик" if phone_chat_mode and not phone_call_mode and speaker_id == "grat" else DisplayNames.normalize(speaker_name)
	var displayed_text: String = DisplayNames.normalize(str(entry.get("text", "")))
	if phone_chat_mode and not phone_call_mode:
		displayed_text = displayed_text.replace("4fr", "Фотик")
	_text.text = _compact_dialogue_text(displayed_text)
	_layout_current_line()
	_fit_dialogue_text()
	_text.visible_characters = 0
	character_progress = 0.0
	revealing = true
	_counter.text = ""
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

func _fit_dialogue_text() -> void:
	# Choice rows reduce the text area height after the line has loaded, so fit
	# again whenever that layout changes, using the font and metrics actually rendered.
	var font_size := 15 if phone_chat_mode else 19
	var minimum_font_size := 9 if phone_chat_mode else 12
	var dialogue_font: Font = _text.get_theme_font("normal_font")
	while font_size > minimum_font_size:
		_text.add_theme_font_size_override("normal_font_size", font_size)
		_text.add_theme_font_size_override("bold_font_size", font_size)
		var measured_height := dialogue_font.get_multiline_string_size(_text.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, _text.size.x, font_size).y
		if measured_height <= _text.size.y and _text.get_content_height() <= _text.size.y:
			break
		font_size -= 1
	_text.add_theme_font_size_override("normal_font_size", font_size)
	_text.add_theme_font_size_override("bold_font_size", font_size)

func _show_choices() -> void:
	_clear_choices()
	var choices: Array = current_entry().get("choices", [])
	if choices.is_empty():
		return
	choice_index = 0
	var choice_height := 48.0
	var choice_separation := 4.0
	if not phone_chat_mode:
		if choices.size() >= 5:
			_active_dialogue_rect = Rect2(18, 240, 924, 280)
			_speaker_label.position = Vector2(42, 250)
			_counter.position = Vector2(740, 251)
			_hint.position = Vector2(326, 256)
			_text.position = Vector2(43, 297)
			_text.size = Vector2(872, 40)
			_choice_layer.position = Vector2(72, 344)
			_choice_layer.size = Vector2(816, 170)
		elif choices.size() == 4:
			_active_dialogue_rect = Rect2(18, 276, 924, 244)
			_speaker_label.position = Vector2(42, 286)
			_counter.position = Vector2(740, 287)
			_hint.position = Vector2(326, 292)
			_text.position = Vector2(43, 333)
			_text.size = Vector2(872, 42)
			_choice_layer.position = Vector2(72, 380)
			_choice_layer.size = Vector2(816, 134)
		else:
			_text.position = Vector2(43, 380)
			_text.size = Vector2(872, 42)
			_choice_layer.position = Vector2(72, 422)
			_choice_layer.size = Vector2(816, 88)
			_hint.position = Vector2(326, 338)
		if _active_dialogue_rect != PANEL_RECT:
			_dialogue_window_layer.position = _active_dialogue_rect.position
			_dialogue_window_layer.size = _active_dialogue_rect.size
		_fit_dialogue_text()
		choice_separation = 4.0
	else:
		choice_separation = 5.0
	choice_height = maxf(1.0, (_choice_layer.size.y - choice_separation * (choices.size() - 1)) / choices.size())
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button := Button.new()
		var choice_text := "%d. %s" % [i + 1, DisplayNames.normalize(str(choice.get("text", "Ответить")))]
		button.text = ""
		button.position = Vector2(0, i * (choice_height + choice_separation))
		button.size = Vector2(_choice_layer.size.x, choice_height)
		button.custom_minimum_size = Vector2(_choice_layer.size.x, choice_height)
		button.clip_contents = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 13 if phone_chat_mode else 15)
		if phone_chat_mode:
			_apply_button_style(button, Color(0.12, 0.09, 0.19, 0.96), Color(0.32, 0.22, 0.42, 0.98), Color(0.49, 0.32, 0.54, 1.0))
		else:
			UIButtons.apply_choice(button)
		var label := RichTextLabel.new()
		label.text = choice_text
		label.position = Vector2(10, 3) if phone_chat_mode else Vector2(14, 2)
		label.size = Vector2(_choice_layer.size.x - 20, choice_height - 6) if phone_chat_mode else Vector2(_choice_layer.size.x - 28, choice_height - 4)
		label.bbcode_enabled = false
		label.fit_content = false
		label.scroll_active = false
		label.clip_contents = true
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var label_font_size := 14
		if phone_chat_mode:
			var text_length := choice_text.length()
			label_font_size = 13 if text_length <= 40 else (12 if text_length <= 58 else 11)
			if choice_height < 40.0:
				label_font_size = mini(label_font_size, 10)
			# Long answers can wrap to three lines on the phone. Shrink only as
			# much as needed so every rendered line fits inside its button.
			while label_font_size > 9 and _theme_font.get_multiline_string_size(choice_text, HORIZONTAL_ALIGNMENT_CENTER, label.size.x, label_font_size).y > label.size.y - 2.0:
				label_font_size -= 1
			label.add_theme_font_size_override("normal_font_size", label_font_size)
			label.add_theme_color_override("default_color", Color("f0eaf7"))
		else:
			label.add_theme_font_size_override("normal_font_size", label_font_size)
			label.add_theme_color_override("default_color", Color("f0eaf7"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		button.pressed.connect(_select_choice.bind(i))
		_choice_layer.add_child(button)
		choice_buttons.append(button)
	if not phone_chat_mode:
		_hint.size = Vector2(390, 22)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.add_theme_font_size_override("font_size", 11)
	_update_choice_focus()
	_hint.text = "↑ / ↓ или 1–%d — выбрать · Enter — ответить" % choices.size()

func _clear_choices() -> void:
	for child in _choice_layer.get_children():
		child.queue_free()
	choice_buttons.clear()
	if is_instance_valid(_dialogue_window_layer) and _active_dialogue_rect != PANEL_RECT:
		_active_dialogue_rect = PANEL_RECT
		_dialogue_window_layer.position = PANEL_RECT.position
		_dialogue_window_layer.size = PANEL_RECT.size
		_speaker_label.position = Vector2(42, 332)
		_counter.position = Vector2(740, 333)
		_hint.position = Vector2(326, 338)
		_text.position = Vector2(43, 380)
		_text.size = Vector2(872, 78)

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
	var display_size := Vector2(PORTRAIT_SIZE.x, 258.0) if speaker_id == "artrey" else PORTRAIT_SIZE
	portrait.size = display_size
	spare.size = display_size
	portrait.pivot_offset = display_size * 0.5
	spare.pivot_offset = display_size * 0.5
	# Grok's lower edge sits exactly on the dialogue panel's upper border.
	var layout_position := Vector2(18 if side == "left" else 650, PANEL_RECT.position.y - display_size.y if speaker_id in ["grok", "artrey"] else PORTRAIT_TOP)
	portrait.position = layout_position
	spare.position = layout_position
	var silhouette: TextureRect = _silhouette_shadows[side]
	silhouette.size = display_size
	silhouette.pivot_offset = display_size * 0.5
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
		portrait.position.y = PANEL_RECT.position.y - display_size.y if speaker_id == "artrey" else maxf(PANEL_RECT.position.y - fitted_height, 0.0)
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
		if atlas_texture != null:
			var source_size := atlas_texture.atlas.get_size()
			var region := atlas_texture.region
			var region_padding := Vector2.ONE / source_size
			var inactive_material := _inactive_materials[side] as ShaderMaterial
			inactive_material.set_shader_parameter("region_uv_min", region.position / source_size + region_padding)
			inactive_material.set_shader_parameter("region_uv_max", region.end / source_size - region_padding)
			portrait.material = inactive_material
		else:
			portrait.material = null
		portrait.modulate = Color(0.88, 0.88, 0.92, 1.0)
	_slot_active[side] = active

func _portrait_texture(speaker_id: String, emotion: String, side: String) -> Texture2D:
	if speaker_id == "artrey":
		var artrey_sheet := load("res://assets/portraits/artrey-emotions.png") as Texture2D
		if artrey_sheet == null:
			return null
		var expression := EMOTIONS.find(emotion)
		if expression < 0:
			expression = 0
		var cell := artrey_sheet.get_size() / Vector2(4.0, 2.0)
		var column := expression % 4
		var row := 1 if expression >= 4 else 0
		var artrey_frame := AtlasTexture.new()
		artrey_frame.atlas = artrey_sheet
		artrey_frame.region = Rect2(Vector2(column, row) * cell + Vector2(3, 3), cell - Vector2(6, 6))
		artrey_frame.filter_clip = true
		return artrey_frame
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
	return {"grat": "4fr", "grok": "Грок", "jbt": "ЖБТ", "artrey": "Артбей", "narrator": "СЦЕНА"}.get(speaker_id, "СЦЕНА")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var active_rect := PHONE_RECT if phone_chat_mode else _active_dialogue_rect
		if not active_rect.has_point(event.position) and choice_buttons.is_empty():
			advance()
			accept_event()
