extends Control

const UIButtons = preload("res://scripts/ui_buttons.gd")

func _ready() -> void:
	get_tree().paused = false
	AudioManager.play_music("disclaimer")
	var background := ColorRect.new()
	background.color = Color("0b0914")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(600, 0)
	stack.add_theme_constant_override("separation", 32)
	center.add_child(stack)
	var heading := Label.new()
	heading.text = "ДИСКЛЕЙМЕР"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color("e34b5b"))
	stack.add_child(heading)
	var notice := Label.new()
	notice.text = "Все персонажи и события вымышлены. Любые совпадения с реальными людьми, живыми или умершими, или событиями — чистая случайность. Игра вышла слишком душной"
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size", 28)
	notice.add_theme_color_override("font_color", Color("eadff1"))
	stack.add_child(notice)
	var button := Button.new()
	button.text = "Продолжить"
	button.custom_minimum_size = Vector2(240, 56)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 22)
	UIButtons.apply_menu_button(button)
	button.pressed.connect(func(): get_tree().change_scene_to_file("res://MainMenu.tscn"))
	stack.add_child(button)
	button.grab_focus()
