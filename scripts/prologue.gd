extends "res://scripts/main.gd"

# The original prototype remains in Main.tscn. The prologue uses Room.tscn.
enum Step { VOICE, PROJECT, BLENDER, HELP, SEARCH, COMPLAIN, PROMPT, GROK, COMPLETE }
@export var save_path := "user://grat_prologue_v1.json"
var step: int = Step.VOICE
var intro_seen := false
var consultations := 0
var flow := ""
var page := 0
var mode := "menu"
var goal_label: Label
var chapter_title: Label
var active_chapter := 0
var chapter_computer_pending := 0
var call_event_schedule: Array[Dictionary] = []
var call_event_completed: Array[String] = []
var call_event_pending := ""
var call_event_pending_chapter := 0
var call_event_schedule_initialized := false
var narrative_clock_minutes := 3 * 60 + 47
var narrative_day := 1
var clock_location := "консультаций: 0"
var previous_dialogue_duration := 0
var page_counter: Label
var sprite: AnimatedSprite2D
var search_input: LineEdit
var search_result: Label
var copied_code := false
var examined: Array[String] = []
var motion := Vector2.ZERO
var notebook_from_room := false
var vn: Control
var vn_entries: Array = []
var chapter_one_stage := 0
var chapter_two_complete := false
var bios_background: ColorRect
var chapter_one_evidence: Array[String] = []
var pending_evidence := ""
var pause_menu: Control
var phone_panel: Panel
var phone_notes_open := false
var phone_avatar_textures: Dictionary = {}
var phone_hud_hidden := false
var credits_screen: Control
var credits_label: RichTextLabel
var credits_roll: Tween
var credits_buttons: Array[Button] = []
var save_dirty := false
var saved_player_position := Vector2.ZERO
const SPAWN_POSITION := Vector2(450,340)
const Early = preload("res://scripts/early_content.gd")
const DoodleJump = preload("res://scripts/doodle_jump.gd")
var story = preload("res://scripts/story_state.gd").new()
var minigame_checkpoint: Dictionary = {}
var dialogue_resume: Dictionary = {}
var tab_war: Control
var doodle_jump_control: Control
var office_queue: Control
var court_trial: Control
var digital_archaeology: Control
var hotdog_master: Control
var last_build: Control
var hint_panel: Panel
var task_panel: Panel
var controls_list_label: Label
var notebook_hint_panel: Panel
var interaction_prompt: Panel
var interaction_key_label: Label
var interaction_action_label: Label
var interaction_target_label: Label
var polaroid_overlay: Control
var polaroid_dim: ColorRect
var polaroid_image: TextureRect

# Старт глав: пролог — день 1, 03:47; 1 — день 1, 04:15; 2 — день 1, 05:00;
# 3 — день 1, 06:00; 4 — день 2, 09:00; 5 — день 3, 10:00;
# 6 — день 5, 12:00 (после 48 часов); 7 — день 6, 19:00.
# Между строками время идёт по оценочной длине реплики, не по реальному времени чтения.
const CHAPTER_START_DAY := [1, 1, 1, 1, 2, 3, 5, 6]
const CHAPTER_START_MINUTES := [227, 255, 300, 360, 540, 600, 720, 1140]
const DIALOGUE_TIME := preload("res://scripts/story_dialogue.gd")

const FLOW := {
	"intro": [
		"[b]03:47. КОМНАТА 4fr.[/b]\nСегодня 4fr хочет запустить свою первую игру: комнату с запертой дверью. Осталось сделать ключ.",
		"[b]4fr[/b]\nКомната есть. Дверь есть. Ключ сделаю сейчас. Я вообще по идеям.",
		"[b]ТЕЛЕФОН[/b]\nСначала 4fr расскажет друзьям о проекте. Телефон лежит на тумбочке возле пиццы."
	],
	"voice": [
		"[b]4fr ЗАПИСЫВАЕТ ГОЛОСОВОЕ[/b]\n«Короче, делаю игру. Авторский проект. Всё сам».\nОн отправляет его в игровой чат друзей.",
		"[b]ВТОРОЙ МОНИТОР[/b]\nЖБТ: «Теперь нажми “Создать проект”».\n4fr аккуратно сворачивает окно. Чтобы не отвлекало от авторского проекта."
	],
	"project": [
		"[b]МОЯ ИГРА → ЗАПУСК[/b]\nПерсонаж доходит до двери. Она не открывается. На экране появляется ошибка.",
		"[b][color=#f2a1a1]ERROR: key.glb отсутствует[/color][/b]\nДля продолжения разработки создайте или импортируйте модель ключа.",
		"[b]4fr[/b]\nОдин сраный ключ. Сейчас сам сделаю. Где тут этот Blender?"
	],
	"blender": [
		"[b]4fr[/b]\nЭто куб.\n\n4fr некоторое время смотрит на куб. Куб смотрит в ответ.",
		"[b]4fr[/b]\nЯ вообще по идеям.\nОн закрывает Blender и открывает ЖБТ."
	],
	"help": [
		"[b]4fr → ЖБТ[/b]\nСделай ключ для игры. Обычный. Чтоб дверь открывал.",
		"[b]ЖБТ[/b]\nВот скрипт для Blender. Вставь его во вкладку Scripting и нажми Run Script.",
		"[b]4fr[/b]\nВставить код. Понял.\n4fr копирует скрипт и открывает поиск Windows."
	],
	"search": [
		"[b]ПОИСК[/b]\nПо вашему запросу ничего не найдено.\nПопробуйте изменить формулировку.",
		"[b]4fr[/b]\nНе работает. Ты опять хуйню дала.\n4fr пишет ЖБТ, не проверив, куда вставил код."
	],
	"complain": [
		"[b]4fr → ЖБТ[/b]\nЯ вставил код. Поиск ничего не нашёл.",
		"[b]ЖБТ[/b]\nКод нужно запускать в Blender. Это не поисковый запрос.",
		"[b]4fr[/b]\nЯсно. Это я не туда вставил.\nНо вместо Blender он опять открывает чат ЖБТ."
	],
	"prompt": [
		"[b]4fr → ЖБТ[/b]\nКак написать другой нейросети, чтобы она сделала нормально?",
		"[b]ЖБТ[/b]\nВот сообщение, которое можно отправить Grok:\n«Привет! Нужна 3D-модель обычного дверного ключа в формате GLB для моей игры». ",
		"[b]4fr[/b]\nВо. Другое дело.\n\nОн копирует весь ответ. Вместе с «Вот сообщение, которое можно отправить Grok»."
	],
	"grok": [
		"[b]НОВАЯ ВКЛАДКА[/b]\nСообщение готово. Осталось познакомиться.\n\n4fr поправляет футболку перед монитором.",
		"[b]4fr[/b]\nНу эта-то точно сделает.\n\nНа экране появляется надпись: «Grok печатает…»"
	]
}

func _ready() -> void:
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	install_character()
	# Restore the existing bed collider in this inherited scene only.
	$Bed/CollisionShape2D.disabled = false
	_build_ui()
	_create_vn()
	_create_pause_menu()
	var dev_call_event := SaveManager.consume_dev_call_event()
	if not dev_call_event.is_empty():
		_start_dev_call_event(dev_call_event)
		return
	var dev_minigame := SaveManager.consume_dev_minigame()
	if not dev_minigame.is_empty():
		_start_dev_minigame(dev_minigame)
		return
	if SaveManager.consume_dev_credits():
		_reset_progress()
		intro_seen = true
		step = Step.COMPLETE
		show_credits()
		return
	var dev_ending := SaveManager.consume_dev_ending()
	if not dev_ending.is_empty():
		_start_dev_ending(dev_ending)
		return
	var dev_chapter := SaveManager.consume_dev_chapter()
	if dev_chapter > 0:
		_start_dev_chapter(dev_chapter)
		return
	var launch_mode := SaveManager.consume_launch_mode()
	if launch_mode == "new":
		_reset_progress()
		refresh_goal()
		resume_game()
	elif launch_mode == "continue":
		if not load_progress():
			_reset_progress()
		refresh_goal()
		resume_game()
	else:
		load_progress()
		refresh_goal()
		show_menu()

func _start_dev_chapter(chapter: int) -> void:
	# Build a disposable in-memory story state; the regular user save is untouched.
	_reset_progress()
	intro_seen = true
	step = Step.COMPLETE
	chapter_one_stage = 2 if chapter >= 2 else 0
	chapter_two_complete = chapter >= 3
	var completed_chapters := ["chapter_three_complete", "chapter_four_complete", "chapter_five_complete", "chapter_six_complete"]
	for index in range(completed_chapters.size()):
		story.set_value(completed_chapters[index], chapter > index + 3)
	if chapter >= 3:
		story.set_value("tab_war_completed", true)
		story.set_value("tab_war_won", true)
		story.set_value("defused_tab_war", true)
	if chapter >= 4:
		story.set_value("grok_date_completed", true)
		story.set_value("key_txt_received", true)
		story.set_value("stamp_obtained", true)
		story.set_value("secret_protocol", true)
	if chapter >= 5:
		story.set_value("project_ownership_proven", true)
		story.set_value("affection_grok", 3)
		story.set_value("affection_gpt", 3)
		story.set_value("affection_artbay", 3)
	if chapter >= 6:
		story.set_value("artbay_evidence", true)
		story.set_value("artbay_contract_signed", true)
		story.set_value("gpt_boundaries", true)
		story.set_value("grok_without_key", true)
	if chapter >= 7:
		story.set_value("artbay_control_taken", true)
		story.set_value("lied_in_court", true)
		story.set_value("lies_count", 2)
		story.set_value("stamp_stolen", true)
		story.set_value("honest_final_choice", false)
	match chapter:
		1: start_chapter_one()
		2: start_chapter_two()
		3: start_chapter_three()
		4: start_chapter_four()
		5: start_chapter_five()
		6: start_chapter_six()
		7: start_chapter_seven()

func _start_dev_minigame(game_id: String) -> void:
	# Give each test run a disposable state and keep normal saves untouched.
	_reset_progress()
	intro_seen = true
	step = Step.COMPLETE
	chapter_one_stage = 2
	chapter_two_complete = true
	match game_id:
		"doodle_jump": show_doodle_jump()
		"tab_war": start_tab_war()
		"wire_puzzle": start_last_build()
		"digital_archaeology": start_digital_archaeology()
		"office_queue": start_office_queue()
		"court_trial": start_court_trial()
		"hotdog_master": start_hotdog_master()

func _start_dev_ending(ending_id: String) -> void:
	# Direct previews use disposable story data and must not unlock achievements.
	_reset_progress()
	intro_seen = true
	step = Step.COMPLETE
	story.set_value("chapter_seven_complete", true)
	story.set_value("final_ending", ending_id)
	story.decisions["ending_achievement_" + ending_id] = ending_id
	show_chapter_seven_ending()

func install_character() -> void:
	for child in player.get_children():
		if child is Polygon2D and child.name != "PlayerShadow":
			child.hide()
	sprite = AnimatedSprite2D.new()
	sprite.name = "GratSprite"
	sprite.sprite_frames = preload("res://assets/sprites/grat/grat-animations.tres")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0, -33.8)
	sprite.scale = Vector2(0.65,0.65)
	player.add_child(sprite)
	sprite.play("idle_down")
	$Player/CollisionShape2D.position = Vector2(0, -6)

func text_at(parent: Node, text: String, pos: Vector2, area: Vector2, size_px: int = 17, color := Color("eee5fa")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = area
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _multiline_text_at(parent: Node, value: String, pos: Vector2, area: Vector2, size_px: int = 17, color := Color("eee5fa")) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.text = value
	label.position = pos
	label.size = area
	label.bbcode_enabled = false
	label.fit_content = false
	label.scroll_active = false
	label.clip_contents = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", size_px)
	label.add_theme_color_override("default_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func button_at(parent: Node, text: String, pos: Vector2, area: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = ""
	if parent is Control:
		var bounds: Vector2 = parent.size
		area.x = minf(area.x, bounds.x - 16.0)
		area.y = minf(area.y, bounds.y - 16.0)
		pos.x = clampf(pos.x, 8.0, bounds.x - area.x - 8.0)
		pos.y = clampf(pos.y, 8.0, bounds.y - area.y - 8.0)
	b.position = pos
	b.size = area
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 16)
	UIButtons.apply(b)
	var label := Label.new()
	label.text = text
	label.position = Vector2(8, 3)
	label.size = Vector2(area.x - 16, area.y - 6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("eee5fa"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.clip_contents = true
	b.add_child(label)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _add_ending_actions(actions: Array, single_row_y: float = 330.0) -> void:
	if actions.is_empty():
		return
	var columns := actions.size() if actions.size() <= 3 else 2
	var gap := 12.0
	var margin := 24.0
	var button_height := 42.0 if actions.size() <= 3 else 36.0
	var start_y := single_row_y if actions.size() <= 3 else 314.0
	var button_width := (app_panel.size.x - margin * 2.0 - gap * (columns - 1)) / columns
	for index in range(actions.size()):
		var action: Dictionary = actions[index]
		var row := int(index / columns)
		var column := index % columns
		var position := Vector2(margin + column * (button_width + gap), start_y + row * (button_height + 8.0))
		button_at(app_panel, str(action.text), position, Vector2(button_width, button_height), action.callback)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	hint_panel = _make_panel(Vector2(18,12),Vector2(226,132),Color(0.045,0.035,0.075,0.94),Color("77628d"))
	UIButtons.apply_menu_panel(hint_panel)
	hint_panel.name = "PrologueControlsHint"
	ui_layer.add_child(hint_panel)
	text_at(hint_panel,"УПРАВЛЕНИЕ",Vector2(10,7),Vector2(206,20),12,Color("e4d2f2"))
	controls_list_label = text_at(hint_panel,"WASD / стрелки  ·  ходить\nE  ·  действие\nTAB  ·  блокнот\nESC  ·  меню",Vector2(10,29),Vector2(206,61),11,Color("cdbfdf"))
	controls_list_label.add_theme_constant_override("line_spacing", 2)
	controls_list_label.modulate.a = 0.58
	task_panel = _make_panel(Vector2(18,154),Vector2(226,106),Color(0.045,0.035,0.075,0.94),Color("77628d"))
	task_panel.name = "CurrentTaskPanel"
	var task_style := StyleBoxFlat.new()
	task_style.bg_color = Color(0.035, 0.027, 0.058, 0.48)
	task_style.set_border_width_all(0)
	task_style.set_corner_radius_all(8)
	task_style.content_margin_left = 8
	task_style.content_margin_right = 8
	task_style.content_margin_top = 6
	task_style.content_margin_bottom = 6
	task_panel.add_theme_stylebox_override("panel", task_style)
	ui_layer.add_child(task_panel)
	text_at(task_panel,"ТЕКУЩАЯ ЗАДАЧА",Vector2(10,7),Vector2(206,19),11,Color("e4d2f2"))
	hint_label = text_at(ui_layer,"",Vector2(150,484),Vector2(660,24),12,Color("d5c6f4"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.z_index = 80
	hint_label.hide()
	interaction_prompt = _build_interaction_prompt()
	ui_layer.add_child(interaction_prompt)
	chapter_title = text_at(ui_layer,"ТИПОЧЕК: КЛЮЧ · ПРОЛОГ",Vector2(22,520),Vector2(440,17),12,Color("d0c2de"))
	chapter_title.z_index = 120
	status_label = text_at(ui_layer,"",Vector2(620,17),Vector2(318,25),14,Color("bfaed6"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.z_index = 120
	notebook_hint_panel = _build_notebook_hint()
	ui_layer.add_child(notebook_hint_panel)
	goal_label = text_at(task_panel,"",Vector2(10,29),Vector2(206,68),12,Color("ddc396"))
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	computer_panel = _make_panel(Vector2(100,68),Vector2(760,405),Color("171322"),Color("706180"))
	UIButtons.apply_menu_panel(computer_panel)
	ui_layer.add_child(computer_panel)
	app_panel = _make_panel(Vector2(100,68),Vector2(760,405),Color("191524"),Color("8e78a7"))
	UIButtons.apply_menu_panel(app_panel)
	ui_layer.add_child(app_panel)
	inventory_panel = _make_panel(Vector2(200,120),Vector2(560,300),Color("191524"),Color("8e78a7"))
	UIButtons.apply_menu_panel(inventory_panel)
	ui_layer.add_child(inventory_panel)
	phone_panel = Panel.new()
	phone_panel.name = "FriendsChatPhone"
	phone_panel.position = Vector2(320,24)
	phone_panel.size = Vector2(320,492)
	phone_panel.z_index = 40
	var phone_style := StyleBoxFlat.new()
	phone_style.bg_color = Color("080a11")
	phone_style.border_color = Color("675b79")
	phone_style.set_border_width_all(3)
	phone_style.set_corner_radius_all(31)
	phone_style.shadow_color = Color(0, 0, 0, 0.45)
	phone_style.shadow_size = 12
	phone_panel.add_theme_stylebox_override("panel", phone_style)
	ui_layer.add_child(phone_panel)
	dialogue_panel = _make_panel(Vector2(100,310),Vector2(760,190),Color("100d1e"),Color("bba0cf"))
	ui_layer.add_child(dialogue_panel)
	dialogue_label = RichTextLabel.new()
	dialogue_label.position = Vector2(22,18)
	dialogue_label.size = Vector2(716,112)
	dialogue_label.bbcode_enabled = true
	dialogue_label.add_theme_font_size_override("normal_font_size",19)
	dialogue_label.add_theme_font_size_override("bold_font_size",18)
	dialogue_label.add_theme_color_override("default_color",Color("eee5fa"))
	dialogue_panel.add_child(dialogue_label)
	choices_box = VBoxContainer.new()
	choices_box.position = Vector2(22,139)
	choices_box.size = Vector2(716,34)
	dialogue_panel.add_child(choices_box)
	for panel in [computer_panel,app_panel,inventory_panel,phone_panel,dialogue_panel]:
		panel.hide()
	_build_polaroid_overlay()
	_refresh_hud_visibility()

func _build_polaroid_overlay() -> void:
	polaroid_overlay = Control.new()
	polaroid_overlay.name = "PolaroidEasterEggOverlay"
	polaroid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	polaroid_overlay.z_index = 130
	polaroid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	polaroid_overlay.hide()
	polaroid_dim = ColorRect.new()
	polaroid_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	polaroid_dim.color = Color("080711")
	polaroid_dim.modulate.a = 0.84
	polaroid_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	polaroid_overlay.add_child(polaroid_dim)
	polaroid_image = TextureRect.new()
	polaroid_image.name = "PolaroidPhoto"
	polaroid_image.texture = load("res://assets/sprites/furniture/poshalka.png") as Texture2D
	polaroid_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	polaroid_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	polaroid_image.size = Vector2(432,324)
	polaroid_image.position = Vector2(264,20)
	polaroid_image.pivot_offset = polaroid_image.size * 0.5
	polaroid_image.modulate.a = 0.0
	polaroid_image.scale = Vector2(0.92,0.92)
	polaroid_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	polaroid_overlay.add_child(polaroid_image)
	ui_layer.add_child(polaroid_overlay)

func _show_polaroid_easter_egg() -> void:
	var first_view: bool = not story.get_value("polaroid_easter_egg_seen")
	story.set_value("polaroid_easter_egg_seen",true)
	save_dirty = true
	AudioManager.set_walking(false)
	mode = "photo_reveal"
	nearby_object = ""
	interaction_prompt.hide()
	for control in [hint_panel,task_panel,chapter_title,status_label,notebook_hint_panel]:
		control.hide()
	polaroid_overlay.show()
	polaroid_dim.modulate.a = 0.0
	polaroid_image.modulate.a = 0.0
	polaroid_image.scale = Vector2(0.92,0.92)
	var reveal := create_tween()
	reveal.tween_property(polaroid_dim,"modulate:a",1.0,0.3)
	reveal.tween_interval(0.18)
	reveal.tween_property(polaroid_image,"modulate:a",1.0,0.38)
	reveal.parallel().tween_property(polaroid_image,"scale",Vector2.ONE,0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await reveal.finished
	await get_tree().create_timer(1.15).timeout
	if not is_inside_tree() or mode != "photo_reveal":
		return
	var entries: Array
	if first_view:
		entries = [
			{"speaker_id":"grat","speaker":"4fr","emotion":"surprised","text":"Как она вообще мне дала? У меня же ебануто воняет изо рта."},
			{"speaker_id":"jbt","speaker":"ЖБТ","emotion":"happy","text":"Может, она просто задержала дыхание."},
			{"speaker_id":"grat","speaker":"4fr","emotion":"embarrassed","text":"Вот это я понимаю — взаимность."}
		]
	else:
		entries = [
			{"speaker_id":"grat","speaker":"4fr","emotion":"neutral","text":"Снимок всё такой же. А запах, к счастью, внутрь не записался."}
		]
	flow = "polaroid_easter_egg"
	mode = "dialogue"
	vn.z_index = 140
	_start_dialogue_entries(entries)

func _build_notebook_hint() -> Panel:
	var panel := _make_panel(Vector2(880,10),Vector2(64,64),Color(0.045,0.035,0.075,0.97),Color("8e75a5"))
	UIButtons.apply_menu_panel(panel)
	panel.name = "NotebookTabHint"
	var cover := ColorRect.new()
	cover.position = Vector2(15,7)
	cover.size = Vector2(34,29)
	cover.color = Color("322640")
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cover)
	var page_left := ColorRect.new()
	page_left.position = Vector2(17,9)
	page_left.size = Vector2(14,25)
	page_left.color = Color("e4d6ed")
	page_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(page_left)
	var page_right := ColorRect.new()
	page_right.position = Vector2(33,9)
	page_right.size = Vector2(14,25)
	page_right.color = Color("cbb8dc")
	page_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(page_right)
	var spine := ColorRect.new()
	spine.position = Vector2(31,9)
	spine.size = Vector2(2,25)
	spine.color = Color("806b91")
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(spine)
	for x in [20.0, 36.0]:
		for y in [15.0, 21.0, 27.0]:
			var ruled_line := ColorRect.new()
			ruled_line.position = Vector2(x, y)
			ruled_line.size = Vector2(8,1)
			ruled_line.color = Color("a996bd")
			ruled_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(ruled_line)
	var tab := text_at(panel,"TAB",Vector2(6,41),Vector2(52,16),11,Color("f0e8ff"))
	tab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.z_index = 120
	return panel

func _build_interaction_prompt() -> Panel:
	var panel := Panel.new()
	panel.name = "PixelInteractionPrompt"
	panel.size = Vector2(174,42)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17121f")
	style.border_color = Color("d4b77b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0.01,0.005,0.02,0.75)
	style.shadow_size = 3
	style.shadow_offset = Vector2(2,2)
	panel.add_theme_stylebox_override("panel",style)
	var keycap := Panel.new()
	keycap.position = Vector2(6,7)
	keycap.size = Vector2(27,27)
	keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color("473750")
	key_style.border_color = Color("a98eb9")
	key_style.set_border_width_all(1)
	key_style.set_corner_radius_all(1)
	keycap.add_theme_stylebox_override("panel",key_style)
	panel.add_child(keycap)
	interaction_key_label = text_at(keycap,"E",Vector2.ZERO,Vector2(27,27),14,Color("f4dba7"))
	interaction_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_key_label.add_theme_font_size_override("font_size",14)
	interaction_key_label.add_theme_color_override("font_outline_color",Color("241b2d"))
	interaction_key_label.add_theme_constant_override("outline_size",1)
	interaction_action_label = text_at(panel,"ИСПОЛЬЗОВАТЬ",Vector2(39,5),Vector2(128,13),9,Color("d5bd8e"))
	interaction_action_label.add_theme_font_size_override("font_size",9)
	interaction_target_label = text_at(panel,"",Vector2(39,19),Vector2(128,17),11,Color("f0e8ff"))
	interaction_target_label.add_theme_font_size_override("font_size",11)
	interaction_target_label.clip_text = true
	panel.z_index = 80
	panel.hide()
	return panel

func _create_vn() -> void:
	vn = preload("res://scripts/vn_dialogue.gd").new()
	vn.name = "VNDialogue"
	vn.z_index = 100
	ui_layer.add_child(vn)
	vn.finished.connect(_close_dialogue)
	vn.line_changed.connect(_on_story_line_changed)
	vn.choice_selected.connect(_on_achievement_dialogue_choice)

func _on_achievement_dialogue_choice(choice_id: String) -> void:
	if flow == "hotdog_repeat" and choice_id in ["hotdog_show","hotdog_rest","hotdog_check","hotdog_wait"]:
		var effects := {"affection_artbay":1} if choice_id == "hotdog_show" else {"artbay_suspicion":1} if choice_id == "hotdog_check" else {}
		var decision_key := "hotdog_suspicion_choice" if choice_id in ["hotdog_check","hotdog_wait"] else "hotdog_trust_choice"
		var flags := {"hotdog_repeat_choice_seen":true,"hotdog_suspicion_choice_seen":true,"hotdog_suspicion_action":choice_id} if decision_key == "hotdog_suspicion_choice" else {"hotdog_repeat_choice_seen":true,"hotdog_trust_choice_seen":true}
		story.decide(decision_key,choice_id,effects,flags)
	if flow in ["chapter_three_intro", "chapter_three_outro", "chapter_three"]:
		var effects := {}
		var flags := {}
		var decision := "c3_relationship" if choice_id in ["c3_respect","c3_work","c3_compare"] else ("c3_windows" if choice_id in ["c3_keep","c3_memes","c3_close"] else "c3_resolution")
		match choice_id:
			"c3_respect": effects = {"affection_gpt":2}; flags = {"gpt_trust":true,"gpt_boundaries":true}
			"c3_work": effects = {"affection_gpt":1}; flags = {"gpt_boundaries":true}
			"c3_compare": effects = {"affection_gpt":-2,"comparison_count":1}; flags = {"gpt_trust":false}
			"c3_peace": effects = {"affection_grok":1,"affection_gpt":1}; flags = {"defused_tab_war":true}
			"c3_fun", "c3_memes": effects = {"affection_grok":-2,"affection_gpt":-2}
			"c3_delegate": effects = {"affection_artbay":1}
		story.decide(decision,choice_id,effects,flags)
	if flow.begins_with("chapter_four"):
		var c4_effects := {}
		var c4_flags := {}
		match choice_id:
			"c4_backup":
				c4_effects = {"affection_artbay":1}
				c4_flags = {"backup_candidate":true,"artbay_trust":true}
			"c4_decline":
				c4_flags = {"backup_candidate":false}
			"c4_access":
				c4_flags = {"project_access_shared":true,"backup_candidate":true,"artbay_suspicion":1}
		story.decide("chapter_four_backup",choice_id,c4_effects,c4_flags)
	if flow.begins_with("chapter_five"):
		var c5_effects := {}
		var c5_flags := {}
		var decision := ""
		match choice_id:
			"c5_honest":
				decision = "court_personal_answer"
				c5_effects = {"affection_grok":1,"affection_gpt":1}
			"c5_joke":
				decision = "court_personal_answer"
			"c5_lie":
				decision = "court_personal_answer"
				c5_flags = {"lied_in_court":true}
			"c5_grok_yes":
				decision = "court_grok_question"
				c5_effects = {"affection_grok":2}
				c5_flags = {"grok_without_key":true}
			"c5_grok_unsure": decision = "court_grok_question"
			"c5_jbt_yes":
				decision = "court_jbt_question"
				c5_effects = {"affection_gpt":2}
				c5_flags = {"gpt_trust":true,"gpt_boundaries":true}
			"c5_jbt_unsure": decision = "court_jbt_question"
		if decision != "": story.decide(decision,choice_id,c5_effects,c5_flags)
	if flow.begins_with("chapter_six"):
		if choice_id in ["c6_companion_grok","c6_companion_jbt","c6_companion_alone"]:
			var companion := choice_id.trim_prefix("c6_companion_")
			story.decide("archive_companion",companion,{}, {"old_projects_companion":companion})
		var c6_flags := {}
		match choice_id:
			"c6_contract":
				c6_flags = {"artbay_contract_signed":true,"artbay_control_taken":false,"artbay_trust":true,"artbay_repaired":bool(story.get_value("artbay_evidence"))}
				if bool(story.get_value("artbay_evidence")): c6_flags["project_ownership_proven"] = true
			"c6_cut": c6_flags = {"artbay_control_taken":false,"artbay_contract_signed":false}
			"c6_defer": c6_flags = {"artbay_control_taken":false,"artbay_contract_signed":false}
			"c6_trust": c6_flags = {"artbay_control_taken":true,"artbay_contract_signed":false,"project_access_shared":true}
		if not c6_flags.is_empty():
			story.decide("chapter_six_resolution",choice_id,{"affection_artbay":1 if choice_id == "c6_contract" else 0},c6_flags)
	if flow.begins_with("chapter_seven_outro"):
		var ending_id := ""
		match choice_id:
			"c7_grok": ending_id = "grok" if story.get_value("grok_date_completed") and story.get_value("grok_without_key") and int(story.get_value("affection_grok",0)) >= 3 and int(story.get_value("lies_count",0)) < 2 else "neutral"
			"c7_jbt": ending_id = "jbt" if story.get_value("gpt_boundaries") and int(story.get_value("affection_gpt",0)) >= 3 and not story.get_value("lied_in_court") else "neutral"
			"c7_artrey": ending_id = "artbay" if story.get_value("artbay_contract_signed") and story.get_value("project_ownership_proven") and story.get_value("artbay_repaired") else "neutral"
			"c7_artrey_bad": ending_id = "artbay_bad" if story.get_value("artbay_control_taken") else "neutral"
			"c7_team": ending_id = "team" if story.get_value("defused_tab_war") and not story.get_value("artbay_control_taken") else "neutral"
			"c7_instrument": ending_id = "instrumental" if int(story.get_value("lies_count",0)) >= 2 or (story.get_value("artbay_control_taken") and story.get_value("lied_in_court")) else "neutral"
			"c7_ministry": ending_id = "ministry" if story.get_value("secret_protocol") and (story.get_value("stamp_obtained") or story.get_value("stamp_stolen")) else "neutral"
			"c7_triple": ending_id = "triple" if story.get_value("defused_tab_war") and int(story.get_value("affection_grok",0)) >= 2 and int(story.get_value("affection_gpt",0)) >= 2 else "neutral"
			"c7_solo": ending_id = "neutral"
		if ending_id != "":
			story.set_value("final_ending",ending_id)
			story.decide("final_choice",choice_id)
			if choice_id == "c7_solo": story.set_value("honest_final_choice",true)
	if choice_id != "":
		AchievementManager.unlock_achievement("first_choice")
		Early.on_choice(self, choice_id)
		save_dirty = true

func _on_story_line_changed(new_index: int) -> void:
	dialogue_index = new_index
	if previous_dialogue_duration > 0:
		_advance_narrative_clock(previous_dialogue_duration)
	var entry: Dictionary = vn.current_entry()
	entry["timestamp"] = _clock_text()
	if new_index >= 0 and new_index < vn.entries.size():
		vn.entries[new_index] = entry
	previous_dialogue_duration = int(entry.get("duration_minutes", 1))
	_update_clock_display()
	var event: String = str(entry.get("story_event", ""))
	if event == "document_84_opened": AchievementManager.report_story_event(event)
	if event == "digital_archaeology":
		start_digital_archaeology()
		return
	if event == "last_build":
		start_last_build()
		return
	if event == "grok_personal_finished" and story.get_value("grok_without_key"):
		AchievementManager.report_story_event("grok_personal_scene")
	elif event == "bios_dinner_finished":
		var amd: bool = str(story.get_value("dinner_dish", "")) in ["paste_ram", "taste_paste"]
		story.decide("bios_dinner_finished", "done", {}, {"dinner_finished":true,"amd_chef_achievement":amd})
		if story.get_value("amd_chef_achievement"):
			AchievementManager.unlock_achievement("amd_chef")
	elif event == "bios_key_received":
		story.set_value("key_txt_received", true)
	if flow != "demo":
		save_progress()

func _create_pause_menu() -> void:
	pause_menu = preload("res://scripts/pause_menu.gd").new()
	pause_menu.name = "PauseMenu"
	pause_menu.z_index = 200
	ui_layer.add_child(pause_menu)
	pause_menu.setup(self)


func clear_panel(panel: Panel) -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

func _set_active_chapter(value: int) -> void:
	var next_chapter := clampi(value, 0, 7)
	if next_chapter != active_chapter:
		narrative_clock_minutes = CHAPTER_START_MINUTES[next_chapter]
		narrative_day = CHAPTER_START_DAY[next_chapter]
		previous_dialogue_duration = 0
	active_chapter = next_chapter
	refresh_goal()

func _clock_text() -> String:
	var minutes_of_day := posmod(narrative_clock_minutes, 24 * 60)
	return "ДЕНЬ %d · %02d:%02d" % [narrative_day, int(minutes_of_day / 60), minutes_of_day % 60]

func _time_of_day_text() -> String:
	var minutes_of_day := posmod(narrative_clock_minutes, 24 * 60)
	return "%02d:%02d" % [int(minutes_of_day / 60), minutes_of_day % 60]

func _advance_narrative_clock(minutes: int) -> void:
	narrative_clock_minutes += maxi(0, minutes)
	while narrative_clock_minutes >= 24 * 60:
		narrative_clock_minutes -= 24 * 60
		narrative_day += 1

func _update_clock_display() -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = "%s / %s" % [_clock_text(), clock_location]
	status_label.position = Vector2(560,17) if active_chapter > 0 else Vector2(620,17)
	status_label.size = Vector2(306,25) if active_chapter > 0 else Vector2(318,25)
	if is_instance_valid(vn):
		vn.set_clock_text(_time_of_day_text())

func _refresh_hud_visibility() -> void:
	if not is_instance_valid(hint_panel):
		return
	var prologue_controls := active_chapter == 0
	var show_task := not dialogue_open and not phone_hud_hidden
	hint_panel.visible = prologue_controls and show_task
	hint_label.visible = false
	task_panel.position = Vector2(18,154) if prologue_controls else Vector2(18,12)
	task_panel.visible = show_task
	notebook_hint_panel.visible = active_chapter > 0 and not phone_hud_hidden
	if dialogue_open or phone_hud_hidden or mode != "room":
		interaction_prompt.hide()

func _build_dialogue_timing(entries: Array) -> void:
	for entry in entries:
		if not entry is Dictionary:
			continue
		if not entry.has("duration_minutes"):
			entry["duration_minutes"] = DIALOGUE_TIME.estimate_minutes(str(entry.get("text", "")))
		entry.erase("timestamp")

func refresh_goal() -> void:
	chapter_title.text = "ТИПОЧЕК: КЛЮЧ · ПРОЛОГ" if active_chapter == 0 else "ТИПОЧЕК: КЛЮЧ · ГЛАВА %d" % active_chapter
	clock_location = "консультаций: %d" % consultations if active_chapter == 0 else ""
	if active_chapter == 3:
		goal_label.text = "Глава 3 завершена · получена повестка в Министерство" if story.get_value("chapter_three_complete") else ("Глава 3 · подойди к компьютеру и открой переписку" if chapter_computer_pending == 3 else "Глава 3 · разговор с ЖБТ и война вкладок")
		clock_location = "ЖБТ и Грок онлайн"
		_update_clock_display()
		_refresh_hud_visibility()
		return
	if active_chapter == 4:
		goal_label.text = "Глава 4 завершена · повестка в суд" if story.get_value("chapter_four_complete") else ("Глава 4 · подойди к компьютеру и открой повестку" if chapter_computer_pending == 4 else "Глава 4 · разберись с очередью Министерства")
		clock_location = "Министерство"
		_update_clock_display()
		_refresh_hud_visibility()
		return
	if active_chapter == 5:
		goal_label.text = "Глава 5 завершена · Артбей предлагает договор" if story.get_value("chapter_five_complete") else ("Глава 5 · подойди к компьютеру и подготовь дело" if chapter_computer_pending == 5 else "Глава 5 · ответь на обвинения суда")
		clock_location = "судья-принтер"
		_update_clock_display()
		_refresh_hud_visibility()
		return
	if active_chapter == 6:
		goal_label.text = "Глава 6 завершена · проект восстановлен" if story.get_value("chapter_six_complete") else ("Глава 6 · подойди к компьютеру и открой архив" if chapter_computer_pending == 6 else "Глава 6 · проверь историю файлов")
		clock_location = "архив проекта"
		_update_clock_display()
		_refresh_hud_visibility()
		return
	if active_chapter == 7:
		goal_label.text = "Глава 7 · подойди к компьютеру и открой последнюю сборку" if chapter_computer_pending == 7 else "Глава 7 · последняя сборка и решение о релизе"
		clock_location = "последняя сборка"
		_update_clock_display()
		_refresh_hud_visibility()
		return
	if active_chapter == 2:
		goal_label.text = "Глава 2 завершена · key.txt получен" if chapter_two_complete else ("Глава 2 · составь с Артбеем короткий план" if story.get_value("artbay_intro_seen") else "Глава 2 · встреться с Артбеем у киоска" if story.get_value("grok_date_completed") else "Глава 2 · подойди к компьютеру и открой BIOS" if chapter_computer_pending == 2 else "Глава 2 · свидание в BIOS")
		clock_location = "Артбей на связи" if story.get_value("grok_date_completed") else "BIOS"
		_update_clock_display()
		_refresh_hud_visibility()
		return
	if active_chapter == 1:
		goal_label.text = "Глава 1 · Доказательства: %d / 4 · кровать, постер, шкаф, пицца" % chapter_one_evidence.size() if chapter_one_stage < 2 else "Глава 1 завершена · следующее свидание — в BIOS"
		clock_location = "Грок онлайн"
		_update_clock_display()
		_refresh_hud_visibility()
		return
	var goals := ["Записать голосовое друзьям · телефон возле пиццы", "Подойти к компьютеру и запустить свою игру", "Открыть Blender и сделать ключ самому", "Попросить ЖБТ сделать модель ключа", "Вставить скрипт в поиск", "Сообщить ЖБТ, что код не работает", "Спросить ЖБТ, как написать Грок", "Открыть вкладку Grok", "Пролог завершён · продолжение следует"]
	goal_label.text = goals[step]
	clock_location = "консультаций: %d" % consultations
	_update_clock_display()
	_refresh_hud_visibility()

func show_menu() -> void:
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("menu")
	mode = "menu"
	computer_open = true
	computer_panel.hide()
	dialogue_panel.hide()
	app_panel.show()
	clear_panel(app_panel)
	text_at(app_panel,"ПРОЛОГ",Vector2(32,28),Vector2(680,25),14,Color("bca1cd"))
	text_at(app_panel,"Творческий директор",Vector2(32,77),Vector2(690,58),32)
	text_at(app_panel,"Одна комната. Одна дверь. Один отсутствующий key.glb.\n4fr делает свою первую игру. Всё сам. Почти.",Vector2(32,161),Vector2(680,100),19)
	button_at(app_panel,"Начать" if not intro_seen else "Продолжить",Vector2(32,302),Vector2(212,46),resume_game)
	if intro_seen:
		button_at(app_panel,"С начала",Vector2(264,302),Vector2(180,46),confirm_restart)
	button_at(app_panel,"Демо диалогов",Vector2(32,359),Vector2(212,40),start_vn_demo)
	_show_hint("WASD / стрелки — ходить · E — действие · Tab — блокнот · Esc — меню")

func start_vn_demo() -> void:
	flow = "demo"
	mode = "dialogue"
	computer_panel.hide()
	app_panel.hide()
	inventory_panel.hide()
	var demo: Array = [
		{"speaker_id":"grat", "speaker":"4fr", "emotion":"neutral", "side":"left", "text":"ЖБТ, смотри: я наконец-то собрал сцену. Даже свет включил.", "portraits":{"left":{"speaker_id":"grat", "emotion":"neutral"}, "right":{"speaker_id":"jbt", "emotion":"happy"}}},
		{"speaker_id":"jbt", "speaker":"ЖБТ", "emotion":"happy", "side":"right", "text":"Вижу! Теперь выбери, что делать с ключом.", "portraits":{"left":{"speaker_id":"grat", "emotion":"happy"}, "right":{"speaker_id":"jbt", "emotion":"happy"}}, "choices":[{"text":"Сделать его самому", "id":"self", "next":2}, {"text":"Спросить Грока", "id":"grok", "next":3}]},
		{"speaker_id":"grat", "speaker":"4fr", "emotion":"embarrassed", "side":"left", "text":"Сам. Конечно сам. Просто сначала посмотрю один туториал…", "portraits":{"left":{"speaker_id":"grat", "emotion":"embarrassed"}, "right":{"speaker_id":"jbt", "emotion":"neutral"}}},
		{"speaker_id":"grok", "speaker":"Грок", "emotion":"surprised", "side":"right", "text":"О, вы всё-таки позвали меня? Я уже приготовила дерзкий ответ и нормальный пайплайн.", "portraits":{"left":{"speaker_id":"grat", "emotion":"afraid"}, "right":{"speaker_id":"grok", "emotion":"surprised"}}, "choices":[{"text":"Попросить спокойно", "id":"calm", "next":4}, {"text":"Сделать вид, что так и планировал", "id":"bluff", "next":5}]},
		{"speaker_id":"jbt", "speaker":"ЖБТ", "emotion":"happy", "side":"right", "text":"Хороший выбор. Я подсвечу следующий шаг, а не буду делать его за тебя.", "portraits":{"left":{"speaker_id":"grat", "emotion":"happy"}, "right":{"speaker_id":"jbt", "emotion":"happy"}}},
		{"speaker_id":"grat", "speaker":"4fr", "emotion":"afraid", "side":"left", "text":"Я это с самого начала и планировал. Просто план был… гибкий.", "portraits":{"left":{"speaker_id":"grat", "emotion":"afraid"}, "right":{"speaker_id":"grok", "emotion":"angry"}}},
		{"speaker_id":"grok", "speaker":"Грок", "emotion":"happy", "side":"right", "text":"Вот теперь разговор. Портреты сменяются плавно, кнопки работают, а история остаётся за тобой.", "portraits":{"left":{"speaker_id":"grat", "emotion":"happy"}, "right":{"speaker_id":"grok", "emotion":"happy"}}}
	]
	_start_dialogue_entries(demo)

func resume_game() -> void:
	app_panel.hide()
	computer_open = false
	mode = "room"
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("room")
	if not dialogue_resume.is_empty():
		var checkpoint := dialogue_resume.duplicate(true)
		dialogue_resume.clear()
		flow = str(checkpoint.get("flow", "optional"))
		pending_evidence = str(checkpoint.get("pending_evidence", ""))
		mode = "dialogue"
		if flow == "chapter_two": _build_bios_background()
		if flow in ["chapter_two_artrey", "hotdog_taste", "hotdog_poisoning", "hotdog_repeat"]: _show_hotdog_background_for_dialogue()
		_start_dialogue_entries(checkpoint.entries, int(checkpoint.get("index", 0)))
	elif minigame_checkpoint.get("kind", "") == "tab_war":
		start_tab_war()
	elif minigame_checkpoint.get("kind", "") == "office_404":
		start_office_queue()
	elif minigame_checkpoint.get("kind", "") == "court_trial":
		start_court_trial()
	elif minigame_checkpoint.get("kind", "") == "digital_archaeology":
		start_digital_archaeology()
	elif minigame_checkpoint.get("kind", "") == "hotdog_master":
		start_hotdog_master()
	elif minigame_checkpoint.get("kind", "") == "last_build":
		start_last_build()
	elif minigame_checkpoint.get("kind", "") == "blender":
		Early.show_blender_game(self)
	elif minigame_checkpoint.get("kind", "") == "brainstorm":
		_set_active_chapter(2)
		Early.show_brainstorm(self)
	elif not call_event_pending.is_empty():
		_start_call_event(call_event_pending, call_event_pending_chapter)
	elif chapter_computer_pending in [3,4,5,6,7]:
		refresh_goal()
	elif not intro_seen:
		begin_flow("intro")
	elif active_chapter == 3:
		if story.get_value("chapter_three_complete"): show_chapter_three_ending()
		else: start_chapter_three()
	elif active_chapter == 4:
		if story.get_value("chapter_four_complete"): show_chapter_four_ending()
		else: start_chapter_four()
	elif active_chapter == 5:
		if story.get_value("chapter_five_complete"): show_chapter_five_ending()
		else: start_chapter_five()
	elif active_chapter == 6:
		if story.get_value("chapter_six_complete"): show_chapter_six_ending()
		else: start_chapter_six()
	elif active_chapter == 7:
		if story.get_value("chapter_seven_complete"): show_chapter_seven_ending()
		else: start_chapter_seven()
	elif active_chapter == 2:
		if chapter_two_complete: show_chapter_two_ending()
		else: start_chapter_two()
	elif active_chapter == 1:
		show_chapter_one_checkpoint()
	elif step == Step.COMPLETE:
		show_ending()

func confirm_restart() -> void:
	clear_panel(app_panel)
	text_at(app_panel,"Начать пролог заново?",Vector2(32,50),Vector2(680,55),28)
	text_at(app_panel,"Текущий прогресс пролога будет заменён.",Vector2(32,130),Vector2(680,70),18)
	button_at(app_panel,"Начать заново",Vector2(32,277),Vector2(220,45),func():
		_reset_progress()
		save_progress()
		refresh_goal()
		resume_game())
	button_at(app_panel,"Назад",Vector2(274,277),Vector2(180,45),show_menu)

func _physics_process(_delta: float) -> void:
	motion = Vector2.ZERO
	if mode == "room" and not dialogue_open:
		motion = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))).normalized()
		player.velocity = motion * PLAYER_SPEED * (1.4 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		player.move_and_slide()
		if player.velocity.length() > 1.0:
			save_dirty = true
		nearby_object = _get_nearby_object()
		_show_hint("")
		_update_interaction_prompt(nearby_object)
	else:
		player.velocity=Vector2.ZERO
		_update_interaction_prompt("")
	AudioManager.set_walking(mode == "room" and not dialogue_open and player.velocity.length() > 1.0)
	if motion != Vector2.ZERO:
		facing=motion
	var direction := "down"
	if absf(facing.x)>absf(facing.y):
		direction="left" if facing.x<0 else "right"
	else:
		direction="up" if facing.y<0 else "down"
	sprite.speed_scale=1.4 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	sprite.play(("walk_" if player.velocity.length()>1 else "idle_")+direction)
	update_computer_screen()

func update_computer_screen() -> void:
	# The supplied atlas is two proximity states, not a blinking loop.
	var monitor := $Computer/DeskSprite as AnimatedSprite2D
	monitor.stop()
	monitor.frame = 1 if _get_nearby_object()=="computer" else 0
	var wardrobe := $Wardrobe/WardrobeSprite as AnimatedSprite2D
	wardrobe.stop()
	wardrobe.frame = 1 if _get_nearby_object()=="wardrobe" else 0

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if mode in ["tab_war","office_404","court_trial","digital_archaeology","last_build","hotdog_master"]: return
	if mode == "credits":
		if key == KEY_ESCAPE:
			show_chapter_seven_ending()
		elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
			if credits_roll != null and credits_roll.is_valid():
				credits_roll.set_speed_scale(3.0)
		get_viewport().set_input_as_handled()
		return
	if dialogue_open:
		if vn != null and vn.handle_key(key):
			get_viewport().set_input_as_handled()
		return
	if key==KEY_ESCAPE:
		if mode == "credits":
			show_chapter_seven_ending()
		elif mode=="room":
			pause_menu.open_pause()
		elif mode=="desktop" or mode=="menu" or mode=="ending":
			_close_computer()
		else:
			go_back()
	elif key==KEY_E and mode=="room":
		_interact()
	elif key==KEY_TAB and mode=="room":
		show_notebook()
	elif mode=="notebook" and key in [KEY_LEFT,KEY_RIGHT]:
		page=clampi(page+(-1 if key==KEY_LEFT else 1),0,3)
		show_notebook()
	get_viewport().set_input_as_handled()

func _object_name(id: String) -> String:
	return {"computer":"компьютер", "phone":"телефон", "bed":"кровать", "poster":"постер", "pizza":"пицца", "wardrobe":"шкаф", "plant":"растение", "drafts":"черновики", "polaroid":"снимок"}.get(id,id)

func _interaction_prompt_offset(id: String) -> Vector2:
	# Anchors are above the visible sprite, while interaction distance still uses
	# the object's physical footprint.
	return {
		"computer": Vector2(0,-77),
		"phone": Vector2(0,-34),
		"pizza": Vector2(0,-40),
		"bed": Vector2(0,-125),
		"wardrobe": Vector2(0,-111),
		"poster": Vector2(0,-86),
		"plant": Vector2(0,-36),
		"drafts": Vector2(0,-25),
		"polaroid": Vector2(0,-32)
	}.get(id, Vector2(0,-48))

func _update_interaction_prompt(object_id: String) -> void:
	if not is_instance_valid(interaction_prompt):
		return
	# The polaroid is an intentional secret: E still works, but there's no marker.
	if object_id.is_empty() or object_id == "polaroid" or mode != "room" or dialogue_open or phone_hud_hidden:
		interaction_prompt.hide()
		return
	var target: Node2D
	for candidate in get_tree().get_nodes_in_group("interactable"):
		if is_ancestor_of(candidate) and str(candidate.get_meta("object_id", "")) == object_id:
			target = candidate as Node2D
			break
	if not is_instance_valid(target):
		interaction_prompt.hide()
		return
	interaction_target_label.text = _object_name(object_id).to_upper()
	var world_anchor := target.global_position + _interaction_prompt_offset(object_id)
	var screen_anchor := get_viewport().get_canvas_transform() * world_anchor
	var viewport_size := get_viewport().get_visible_rect().size
	var prompt_size := interaction_prompt.size
	var prompt_position := screen_anchor - Vector2(prompt_size.x * 0.5, prompt_size.y + 8.0)
	prompt_position.x = clampf(prompt_position.x, 6.0, viewport_size.x - prompt_size.x - 6.0)
	prompt_position.y = clampf(prompt_position.y, 6.0, viewport_size.y - prompt_size.y - 6.0)
	interaction_prompt.position = Vector2(roundf(prompt_position.x), roundf(prompt_position.y))
	interaction_prompt.show()

func _get_nearby_object() -> String:
	# Use the closest point on the physical footprint, not a tall sprite's
	# visual centre. The desk remains reachable from its front and sides.
	var closest := ""
	var best := 40.0
	var feet_position := player.global_position + Vector2(0,-6)
	for obj in get_tree().get_nodes_in_group("interactable"):
		if not is_ancestor_of(obj):
			continue
		var point: Vector2 = obj.global_position
		var collision := obj.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null and collision.shape is RectangleShape2D:
			var half: Vector2 = collision.shape.size/2
			point = feet_position.clamp(collision.global_position-half,collision.global_position+half)
		var distance := feet_position.distance_to(point)
		if distance<best:
			best=distance
			closest=str(obj.get_meta("object_id",""))
	return closest

func _interact() -> void:
	if chapter_one_stage == 0 and nearby_object != "":
		if not examined.has(nearby_object):
			examined.append(nearby_object)
			save_dirty = true
		if ["bed", "poster", "pizza", "wardrobe", "phone", "computer"].all(func(item: String) -> bool: return examined.has(item)):
			AchievementManager.unlock_achievement("room_explorer")
	if chapter_one_stage == 1 and preload("res://scripts/chapter_one.gd").EVIDENCE.has(nearby_object):
		if chapter_one_evidence.has(nearby_object):
			optional(["[b]4fr[/b]\nЭто доказательство уже приобщено к делу. Виноватым остался я."])
		else:
			pending_evidence = nearby_object
			play_chapter_scene("chapter_one_evidence", preload("res://scripts/chapter_one.gd").evidence(nearby_object))
		return
	if nearby_object=="computer":
		AudioManager.play_pc_sfx()
		show_desktop()
		if chapter_computer_pending == active_chapter and active_chapter in [3,4,5,6,7]:
			_show_chapter_launch_action()
	elif nearby_object=="phone":
		if story.get_value("grok_date_completed") and not chapter_two_complete:
			if minigame_checkpoint.get("kind", "") == "brainstorm": Early.show_brainstorm(self)
			else: start_artrey()
		elif step==Step.VOICE:
			begin_flow("voice")
		else:
			show_friends_chat()
	elif nearby_object=="polaroid":
		_show_polaroid_easter_egg()
	elif nearby_object!="":
		if not examined.has(nearby_object):
			examined.append(nearby_object)
			save_dirty = true
		play_chapter_scene("room_optional", Early.room_entries(self, nearby_object))

func begin_flow(id: String) -> void:
	_set_active_chapter(0)
	AudioManager.set_walking(false)
	AudioManager.play_music("dialogue")
	flow=id
	mode="dialogue"
	computer_panel.hide()
	app_panel.hide()
	inventory_panel.hide()
	var lines: Array[String]=[]
	for line in FLOW[id]:
		lines.append(line)
	_start_dialogue(lines)

func optional(lines: Array[String]) -> void:
	AudioManager.set_walking(false)
	AudioManager.play_music("dialogue")
	flow="optional"
	mode="dialogue"
	computer_panel.hide()
	app_panel.hide()
	_start_dialogue(lines)

func _start_dialogue(lines: Array[String]) -> void:
	current_lines = lines
	dialogue_index = 0
	dialogue_open = true
	dialogue_panel.hide()
	vn_entries = _entries_from_lines(lines)
	_start_dialogue_entries(vn_entries)

func _start_dialogue_entries(entries_to_play: Array, start_index: int = 0) -> void:
	if flow.begins_with("chapter_three"):
		_set_active_chapter(3)
	elif flow.begins_with("chapter_four"):
		_set_active_chapter(4)
	elif flow.begins_with("chapter_five"):
		_set_active_chapter(5)
	elif flow.begins_with("chapter_six"):
		_set_active_chapter(6)
	elif flow.begins_with("chapter_seven"):
		_set_active_chapter(7)
	elif flow.begins_with("chapter_two") or flow == "artrey_plan_done":
		_set_active_chapter(2)
	elif flow.begins_with("chapter_one"):
		_set_active_chapter(1)
	AudioManager.set_walking(false)
	AudioManager.play_music("hotdog_master" if flow in ["chapter_two_artrey", "hotdog_taste", "hotdog_poisoning", "hotdog_repeat"] else "dialogue")
	var dialogue_entries: Array = entries_to_play.duplicate(true)
	for entry_index in range(dialogue_entries.size()):
		var entry: Variant = dialogue_entries[entry_index]
		if entry is Dictionary:
			entry["text"] = _compact_dialogue_text(str(entry.get("text", "")))
			dialogue_entries[entry_index] = entry
	_build_dialogue_timing(dialogue_entries)
	previous_dialogue_duration = 0
	current_lines = []
	for item in dialogue_entries:
		if item is Dictionary:
			if str(item.get("speaker", "")).begins_with("Артбей"):
				item["speaker_id"] = "artrey"
			current_lines.append(str(item.get("text", "")))
	vn_entries = dialogue_entries
	dialogue_index = start_index
	dialogue_open = true
	dialogue_panel.hide()
	phone_panel.hide()
	task_panel.hide()
	interaction_prompt.hide()
	_refresh_hud_visibility()
	var use_phone_chat := _is_artrey_phone_conversation(dialogue_entries) and flow not in ["chapter_two_artrey", "hotdog_taste", "hotdog_poisoning", "hotdog_repeat"]
	var is_call := flow.begins_with("phone_call_")
	_set_phone_chat_hud(use_phone_chat or is_call)
	if is_call:
		vn.set_phone_call_mode(_call_caller_name(flow), flow.ends_with("call_drx"))
		if start_index == 0:
			var call_event_id := flow.trim_prefix("phone_call_").trim_prefix("dev_")
			AudioManager.play_call_sfx(call_event_id)
	else:
		vn.set_phone_call_mode("", false)
		vn.set_phone_chat_mode(use_phone_chat)
	vn.start(dialogue_entries, start_index)
	_show_hint("E / Enter — показать реплику · ещё раз — продолжить")
	hint_label.hide()

func _compact_dialogue_text(value: String) -> String:
	var compact := value.replace("\r\n", "\n")
	while compact.contains("\n\n"):
		compact = compact.replace("\n\n", "\n")
	return compact

func _is_artrey_phone_conversation(entries: Array) -> bool:
	var has_artrey := false
	for item in entries:
		if not item is Dictionary:
			continue
		var speaker_id := str(item.get("speaker_id", ""))
		var speaker_name := str(item.get("speaker", ""))
		if speaker_id == "artrey" or speaker_name.begins_with("Артбей"):
			has_artrey = true
		if speaker_id in ["grok", "jbt"] or speaker_name.begins_with("Грок") or speaker_name.begins_with("ЖБТ"):
			return false
	return has_artrey

func _call_caller_name(call_flow: String) -> String:
	var event_id := call_flow.trim_prefix("phone_call_").trim_prefix("dev_")
	match event_id:
		"call_drx": return "workersgoincrazy@outlook.com"
		"call_tables": return "mlff"
		"call_palych": return "Палыч"
	return "Неизвестный номер"

func _entries_from_lines(lines: Array[String]) -> Array:
	var result: Array = []
	for raw in lines:
		var parsed := str(raw)
		var parts := parsed.split("\n", true, 1)
		var header := "СЦЕНА"
		var body := parsed
		if parts.size() == 2:
			header = parts[0].replace("[b]", "").replace("[/b]", "")
			body = parts[1]
		var upper := header.to_upper()
		var speaker_id := "narrator"
		var speaker_name := "СЦЕНА"
		var side := "left"
		if "ГРОК" in upper:
			speaker_id = "grok"
			speaker_name = "Грок"
			side = "right"
		elif "ЖБТ" in upper:
			speaker_id = "jbt"
			speaker_name = "ЖБТ"
			side = "right"
		elif "4FR" in upper or "ГРАТ" in upper:
			speaker_id = "grat"
			speaker_name = "4fr"
			side = "left"
		var emotion := "neutral"
		if "хуйню" in body.to_lower() or "не работает" in body.to_lower() or "ноль" in body.to_lower():
			emotion = "angry"
		elif "точно" in body.to_lower() or "конечно" in body.to_lower() or "хорош" in body.to_lower():
			emotion = "happy"
		elif "ошиб" in body.to_lower() or "отсутств" in body.to_lower():
			emotion = "afraid"
		var portraits := {}
		if speaker_id != "narrator":
			portraits[side] = {"speaker_id": speaker_id, "emotion": emotion}
			if speaker_id == "jbt":
				portraits["left"] = {"speaker_id":"grat", "emotion":"neutral"}
			elif speaker_id == "grat" and ("ЖБТ" in upper or "→" in upper):
				portraits["right"] = {"speaker_id":"jbt", "emotion":"neutral"}
		result.append({"speaker_id":speaker_id, "speaker":speaker_name, "emotion":emotion, "side":side, "text":body, "portraits":portraits})
	return result

func _display_current_line() -> void:
	clear_choices()
	if dialogue_index>=current_lines.size():
		_close_dialogue()
		return
	dialogue_label.text=_compact_dialogue_text(current_lines[dialogue_index])
	var b := Button.new()
	b.text="Продолжить  ·  E / Enter    %d / %d" % [dialogue_index+1,current_lines.size()]
	b.focus_mode=Control.FOCUS_NONE
	b.custom_minimum_size=Vector2(716,34)
	b.pressed.connect(_advance_dialogue)
	choices_box.add_child(b)

func clear_choices() -> void:
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()

func _advance_dialogue() -> void:
	if vn != null and vn.visible:
		vn.advance()

func _close_dialogue() -> void:
	dialogue_open=false
	hint_label.show()
	dialogue_panel.hide()
	if vn != null:
		vn.close()
	if phone_hud_hidden:
		_set_phone_chat_hud(false)
		refresh_goal()
	elif not task_panel.visible:
		task_panel.show()
		refresh_goal()
	if previous_dialogue_duration > 0:
		_advance_narrative_clock(previous_dialogue_duration)
		previous_dialogue_duration = 0
		_update_clock_display()
	_refresh_hud_visibility()
	var completed_flow := flow
	if completed_flow.begins_with("phone_call_dev_"):
		_finish_dev_call_event()
		return
	if completed_flow == "polaroid_easter_egg":
		flow = ""
		mode = "room"
		vn.z_index = 100
		polaroid_overlay.hide()
		AudioManager.play_music("room")
		AchievementManager.unlock_achievement("polaroid_secret")
		refresh_goal()
		save_progress()
		return
	if completed_flow.begins_with("phone_call_"):
		_finish_call_event(completed_flow.trim_prefix("phone_call_"))
		return
	flow=""
	if completed_flow == "chapter_computer_boot":
		_start_chapter_opening_dialogue(active_chapter)
		return
	if completed_flow == "chapter_three_intro":
		start_tab_war()
		return
	if completed_flow in ["chapter_three_outro", "chapter_three"]:
		story.set_value("chapter_three_complete", true)
		refresh_goal()
		save_progress()
		show_chapter_three_ending()
		return
	if completed_flow == "chapter_four_intro":
		start_office_queue()
		return
	if completed_flow == "chapter_four_outro":
		story.set_value("chapter_four_complete",true)
		refresh_goal()
		save_progress()
		show_chapter_four_ending()
		return
	if completed_flow == "chapter_five_intro":
		start_court_trial()
		return
	if completed_flow == "chapter_five_outro":
		story.set_value("chapter_five_complete",true)
		if str(story.decisions.get("court_jbt_question", "")) == "c5_jbt_yes" and bool(story.get_value("gpt_boundaries")) and bool(story.get_value("gpt_trust")) and int(story.get_value("affection_gpt")) >= 3 and not bool(story.get_value("lied_in_court")):
			AchievementManager.report_story_event("jbt_route_respected")
		refresh_goal()
		save_progress()
		show_chapter_five_ending()
		return
	if completed_flow == "chapter_six_outro":
		story.set_value("chapter_six_complete",true)
		refresh_goal()
		save_progress()
		show_chapter_six_ending()
		return
	if completed_flow == "chapter_seven_outro":
		story.set_value("chapter_seven_complete",true)
		refresh_goal()
		save_progress()
		show_chapter_seven_ending()
		return
	if completed_flow == "voice":
		step = Step.PROJECT
		save_progress()
		refresh_goal()
		show_friends_chat()
		return
	if completed_flow == "chapter_two":
		story.set_value("grok_date_completed", true)
		AchievementManager.unlock_achievement("grok_date")
		if is_instance_valid(bios_background):
			bios_background.queue_free()
		refresh_goal()
		save_progress()
		start_hotdog_master()
		return
	if completed_flow == "chapter_two_artrey":
		story.set_value("artbay_intro_seen", true)
		story.set_value("hotdog_first_visit_seen", true)
		story.set_value("hotdog_order_stage", 1)
		story.set_value("hotdog_order_choice", "master")
		if is_instance_valid(hotdog_master): hotdog_master.hide()
		AchievementManager.report_story_event("artbay_first_chat")
		start_hotdog_master(true)
		return
	if completed_flow == "hotdog_taste":
		story.set_value("hotdog_order_stage", 3)
		play_chapter_scene("hotdog_poisoning", Early.hotdog_poisoning(str(story.decisions.get("artrey_cooperation", "")) == "artrey_refuse", str(story.get_value("hotdog_order_choice", "master"))))
		save_progress()
		return
	if completed_flow == "hotdog_poisoning":
		story.set_value("hotdog_order_stage", 4)
		if is_instance_valid(hotdog_master): hotdog_master.hide()
		if str(story.decisions.get("artrey_cooperation", "")) != "artrey_refuse":
			Early.show_brainstorm(self)
		else:
			_finish_chapter_two()
		return
	if completed_flow == "artrey_plan_done":
		AchievementManager.report_story_event("artbay_brainstorm")
		_finish_chapter_two()
		return
	if completed_flow == "hotdog_repeat":
		flow = ""
		start_hotdog_master(true)
		return
	if completed_flow == "chapter_one_evidence":
		if pending_evidence != "" and not chapter_one_evidence.has(pending_evidence):
			chapter_one_evidence.append(pending_evidence)
		pending_evidence = ""
		refresh_goal()
		save_progress()
		if chapter_one_evidence.size() == 4:
			play_chapter_scene("chapter_one_ending", preload("res://scripts/chapter_one.gd").ending())
		else:
			_close_computer()
		return
	if completed_flow == "chapter_one_ending":
		chapter_one_stage = 2
		refresh_goal()
		save_progress()
		show_chapter_one_checkpoint()
		return
	if completed_flow == "chapter_one_intro":
		chapter_one_stage = 1
		save_progress()
		AudioManager.play_music("room")
		show_chapter_one_checkpoint()
		return
	if completed_flow != "optional":
		save_dirty = true
	match completed_flow:
		"intro": intro_seen=true
		"voice": step=Step.PROJECT
		"project": step=Step.BLENDER
		"blender": step=Step.HELP
		"blender_training": step=Step.HELP
		"help":
			step=Step.SEARCH
			consultations+=1
			copied_code=true
			AchievementManager.unlock_achievement("jbt_help")
		"search": step=Step.COMPLAIN
		"complain":
			step=Step.PROMPT
			consultations+=1
		"prompt":
			step=Step.GROK
			consultations+=1
		"grok": step=Step.COMPLETE
		"demo":
			mode="menu"
			computer_open=true
	if completed_flow not in ["optional", "demo"]:
		save_progress()
	refresh_goal()
	if completed_flow=="grok":
		AudioManager.play_music("room")
		show_ending()
	elif completed_flow=="demo":
		show_menu()
	elif completed_flow in ["project","blender","blender_training","blender_replay","help","search","complain","prompt"]:
		AudioManager.play_music("room")
		show_desktop()
	else:
		AudioManager.play_music("room")
		mode="room"
		computer_open=false

func _close_computer() -> void:
	_clear_credits_screen()
	for panel in [app_panel,computer_panel,inventory_panel]:
		panel.hide()
	computer_open=false
	mode="room"
	player.velocity=Vector2.ZERO
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("room")
	if chapter_one_stage == 0 and not dialogue_open and examined.size() >= 3:
		var bonuses: Array = Early.room_entries(self, "")
		if not bonuses.is_empty(): play_chapter_scene("room_optional", bonuses)

func show_desktop() -> void:
	AudioManager.set_walking(false)
	AudioManager.play_music("room")
	mode="desktop"
	computer_open=true
	app_panel.hide()
	computer_panel.show()
	clear_panel(computer_panel)
	var wallpaper := TextureRect.new()
	wallpaper.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.texture=load("res://assets/ui/desktop/wallpaper.png")
	wallpaper.position=Vector2(4,4)
	wallpaper.size=Vector2(752,397)
	wallpaper.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wallpaper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	computer_panel.add_child(wallpaper)
	var top_bar := ColorRect.new()
	top_bar.position=Vector2(4,4)
	top_bar.size=Vector2(752,36)
	top_bar.color=Color(0.05,0.04,0.09,0.85)
	top_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	computer_panel.add_child(top_bar)
	text_at(computer_panel,"4fr OS",Vector2(18,11),Vector2(150,24),17)
	text_at(computer_panel,"Личный компьютер / Творческий директор",Vector2(168,14),Vector2(480,24),12,Color("b8adc7"))
	button_at(computer_panel,"×",Vector2(714,7),Vector2(32,29),_close_computer)
	var apps := [["МОЯ ИГРА","project"],["Blender","blender"],["ЖБТ","jbt"],["Поиск","search"],["Блокнот","notebook"],["Grok","grok"]]
	for i in range(apps.size()):
		desktop_shortcut(apps[i][0],apps[i][1],i,Vector2(20+(i%2)*116,49+floori(float(i)/2.0)*95))
	var taskbar := ColorRect.new()
	taskbar.position=Vector2(4,345)
	taskbar.size=Vector2(752,56)
	taskbar.color=Color(0.055,0.045,0.09,0.94)
	taskbar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	computer_panel.add_child(taskbar)
	var start_button := button_at(computer_panel,"Пуск",Vector2(13,355),Vector2(77,36),show_doodle_jump)
	start_button.name = "StartButton"
	start_button.tooltip_text = "Запустить мини-игру «Прыжки 4fr»"
	text_at(computer_panel,"СЕЙЧАС: "+goal_label.text,Vector2(106,355),Vector2(544,40),13,Color("d7c6b1"))
	text_at(computer_panel,"03:47",Vector2(682,360),Vector2(65,25),17)
	_show_hint("Мышь — выбрать приложение · Esc — выйти из компьютера")

func _show_chapter_launch_action() -> void:
	var labels := {
		3: ["ПЕРЕПИСКА И ВКЛАДКИ", "Открыть переписку главы 3 →"],
		4: ["ПОВЕСТКА МИНИСТЕРСТВА", "Открыть материалы дела →"],
		5: ["МАТЕРИАЛЫ СУДА", "Подготовить дело к слушанию →"],
		6: ["ИСТОРИЯ ПРОЕКТА", "Открыть архив проекта →"],
		7: ["ПОСЛЕДНЯЯ СБОРКА", "Открыть рабочую сборку →"]
	}
	var label_pair: Array = labels.get(chapter_computer_pending, ["ПРОДОЛЖИТЬ ГЛАВУ", "Открыть материалы →"])
	var card := _make_panel(Vector2(215,111),Vector2(440,158),Color(0.055,0.045,0.09,0.96),Color("b99acb"))
	card.name = "ChapterLaunchCard"
	computer_panel.add_child(card)
	text_at(card,str(label_pair[0]),Vector2(20,22),Vector2(400,28),19,Color("e9d7b3"))
	text_at(card,"4fr проверит проект и подготовит всё к следующему разговору.",Vector2(20,62),Vector2(400,40),13,Color("d5c6df"))
	button_at(card,str(label_pair[1]),Vector2(20,108),Vector2(400,38),_launch_pending_chapter)

func _launch_pending_chapter() -> void:
	var chapter := chapter_computer_pending
	if chapter not in [3,4,5,6,7]:
		return
	chapter_computer_pending = 0
	computer_open = false
	var boot_text := {
		3: "4fr открывает рабочий проект, проверяет сохранение и сворачивает лишние вкладки. На этот раз сначала поговорит с людьми, потом разберётся с окнами.",
		4: "4fr находит повестку, сверяет номер талона и открывает список документов. В Министерство он пойдёт хотя бы с понятным планом.",
		5: "4fr раскладывает на рабочем столе переписки и документы по делу. Теперь надо объяснить, зачем он просил помощи и кому принадлежит проект.",
		6: "4fr делает отдельную копию проекта и открывает историю файлов. В этот раз он проверит, кто и когда менял материалы.",
		7: "4fr открывает сохранённый проект, проверяет файлы и запускает последнюю сборку. Перед релизом нужно убедиться, что дверь наконец работает."
	}
	play_chapter_scene("chapter_computer_boot", [DIALOGUE_TIME.line("narrator","neutral",str(boot_text[chapter]))])

func _start_chapter_opening_dialogue(chapter: int) -> void:
	match chapter:
		3: play_chapter_scene("chapter_three_intro", preload("res://scripts/chapter_three.gd").opening(story.values))
		4: play_chapter_scene("chapter_four_intro", preload("res://scripts/chapter_four.gd").opening(story.values))
		5: play_chapter_scene("chapter_five_intro", preload("res://scripts/chapter_five.gd").opening(story.values))
		6: play_chapter_scene("chapter_six_intro", preload("res://scripts/chapter_six.gd").opening(story.values))
		7: play_chapter_scene("chapter_seven_intro", preload("res://scripts/chapter_seven.gd").opening(story.values))

func desktop_shortcut(title: String, id: String, index: int, pos: Vector2) -> void:
	var shortcut := Button.new()
	shortcut.name="Shortcut_"+id
	shortcut.position=pos
	shortcut.size=Vector2(110,91)
	shortcut.focus_mode=Control.FOCUS_NONE
	shortcut.tooltip_text="Открыть: "+title
	shortcut.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color=Color.TRANSPARENT
	style.set_corner_radius_all(5)
	shortcut.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color=Color(0.5,0.4,0.7,0.35)
	hover.border_color=Color(0.75,0.65,0.9,0.6)
	hover.set_border_width_all(1)
	shortcut.add_theme_stylebox_override("hover",hover)
	shortcut.add_theme_stylebox_override("pressed",hover)
	shortcut.pressed.connect(func(): _open_app(id))
	computer_panel.add_child(shortcut)
	var atlas := AtlasTexture.new()
	atlas.atlas=load("res://assets/ui/desktop/icons.png")
	atlas.region=Rect2((index%3)*512,floori(float(index)/3.0)*512,512,512)
	var icon := TextureRect.new()
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.texture=atlas
	icon.position=Vector2(21,0)
	icon.size=Vector2(68,68)
	icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shortcut.add_child(icon)
	var caption := text_at(shortcut,title,Vector2(0,67),Vector2(110,22),14)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_shadow_color",Color("080611"))
	caption.add_theme_constant_override("shadow_offset_x",1)
	caption.add_theme_constant_override("shadow_offset_y",2)

func _open_app(id: String) -> void:
	match id:
		"notebook": show_notebook()
		"project":
			if step==Step.PROJECT:
				begin_flow("project")
			else:
				show_info("МОЯ ИГРА", "МОЯ ИГРА/\n   новая папка/\n   новая папка (2)/\n   идеи_финал.txt\n   key.glb — отсутствует", "Сначала голосовое друзьям. Они должны знать." if step==Step.VOICE else "Ошибка никуда не делась.")
		"blender":
			if step>=Step.BLENDER:
				show_blender()
			else:
				show_info("Blender", "Куб на месте.\nКомпетенции — в процессе загрузки.", "4fr: «У меня сейчас другая задача».")
		"jbt":
			if step in [Step.HELP,Step.COMPLAIN,Step.PROMPT]:
				begin_flow({Step.HELP:"help",Step.COMPLAIN:"complain",Step.PROMPT:"prompt"}[step])
			else:
				show_info("ЖБТ", "Теперь нажми «Создать проект».", "История чата заботливо хранит авторский вклад 4fr.")
		"search":
			if step==Step.SEARCH:
				show_search()
			else:
				show_info("Поиск", "Введите название файла или приложения.", "key.glb не найден.")
		"grok":
			_open_grok_app()

func _open_grok_app() -> void:
	# A completed Grok route is global story state; it must never route a later
	# chapter back to the Chapter 2 checkpoint.
	if active_chapter == 0:
		if step == Step.GROK:
			begin_flow("grok")
		elif step == Step.COMPLETE:
			show_ending()
		else:
			show_info("Новая вкладка", "4fr: «Сначала сам попробую.\nНу, с ЖБТ. Но это считается».", "До Грок ещё дойдём.")
		return
	match active_chapter:
		1:
			if chapter_one_stage >= 2:
				show_chapter_one_checkpoint()
			else:
				show_info("Грок · сообщения", "Переписка с Грок сохранена. Сейчас 4fr разбирается с уликами в своей комнате.", "Текущая глава не сброшена · Назад — к рабочему столу.")
		2:
			if chapter_two_complete:
				show_chapter_two_ending()
			else:
				show_info("Грок · история BIOS", "Свидание и получение key.txt уже записаны в истории. Сначала закончи оставшиеся дела главы.", "Текущая глава не сброшена · Назад — к рабочему столу.")
		3:
			if story.get_value("chapter_three_complete"):
				show_chapter_three_ending()
			else:
				_show_grok_archive_for_chapter(3)
		_:
			_show_grok_archive_for_chapter(active_chapter)

func _show_grok_archive_for_chapter(chapter: int) -> void:
	show_info("Грок · архив переписки", "Последние сообщения сохранены. Сейчас открыта глава %d; возвращаться к старому маршруту не нужно." % chapter, "Текущая глава остаётся активной · Назад — к рабочему столу.")

func show_doodle_jump() -> void:
	AchievementManager.unlock_achievement("doodle_jump_found")
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("doodle_jump")
	app_header("ПУСК · ПРЫЖКИ 4fr")
	mode = "doodle_jump"
	text_at(app_panel, "A / D или ← / → — двигаться · Esc — назад", Vector2(27, 55), Vector2(690, 24), 12, Color("c3abd7"))
	doodle_jump_control = DoodleJump.new()
	doodle_jump_control.name = "DoodleJumpMinigame"
	doodle_jump_control.position = Vector2(25, 82)
	doodle_jump_control.size = Vector2(710, 295)
	doodle_jump_control.focus_mode = Control.FOCUS_ALL
	app_panel.add_child(doodle_jump_control)
	doodle_jump_control.grab_focus()

func app_header(title: String) -> void:
	mode="app"
	computer_panel.hide()
	app_panel.show()
	clear_panel(app_panel)
	text_at(app_panel,title,Vector2(26,20),Vector2(580,45),25)
	button_at(app_panel,"Назад",Vector2(620,18),Vector2(112,36),go_back)

func go_back() -> void:
	if mode == "friends_chat":
		_close_friends_chat()
	elif mode=="notebook" and notebook_from_room:
		_close_computer()
	else:
		if mode == "doodle_jump": AudioManager.play_pc_sfx()
		show_desktop()

func show_friends_chat(page: String = "artrey") -> void:
	if active_chapter == 0:
		page = "artrey"
	phone_notes_open = page.begins_with("draft_")
	AudioManager.set_walking(false)
	AudioManager.play_music("room")
	computer_panel.hide()
	app_panel.hide()
	inventory_panel.hide()
	dialogue_panel.hide()
	phone_panel.show()
	clear_panel(phone_panel)
	_set_phone_chat_hud(true)
	phone_panel.clip_contents = true
	mode = "friends_chat"
	computer_open = false
	var screen := Panel.new()
	screen.position = Vector2(7, 7)
	screen.size = Vector2(306, 478)
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = Color("f4f0e8") if phone_notes_open else Color("111522")
	screen_style.set_corner_radius_all(25)
	screen.add_theme_stylebox_override("panel", screen_style)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_panel.add_child(screen)
	var wallpaper := ColorRect.new()
	wallpaper.position = Vector2(9, 177)
	wallpaper.size = Vector2(302, 273)
	wallpaper.color = Color("f4f0e8") if phone_notes_open else Color("171827")
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_panel.add_child(wallpaper)
	var notch := Panel.new()
	notch.position = Vector2(123, 8)
	notch.size = Vector2(74, 12)
	var notch_style := StyleBoxFlat.new()
	notch_style.bg_color = Color("06070c")
	notch_style.set_corner_radius_all(7)
	notch.add_theme_stylebox_override("panel",notch_style)
	notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_panel.add_child(notch)
	text_at(phone_panel,_time_of_day_text(),Vector2(23,25),Vector2(62,18),12,Color("3b3740") if phone_notes_open else Color("e9e3ef"))
	text_at(phone_panel,"▂▄▆  ◖●◗  ▰",Vector2(220,25),Vector2(77,18),10,Color("3b3740") if phone_notes_open else Color("e9e3ef"))
	var header := Panel.new()
	header.position = Vector2(9,53)
	header.size = Vector2(302,68)
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color("f4f0e8") if phone_notes_open else Color("1c2030")
	header_style.set_corner_radius_all(0)
	header.add_theme_stylebox_override("panel",header_style)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_panel.add_child(header)
	if phone_notes_open:
		_phone_button("‹",Vector2(15,68),Vector2(34,38),show_friends_chat.bind(page.trim_prefix("draft_")),25)
		text_at(phone_panel,"Заметки",Vector2(61,68),Vector2(218,27),18,Color("2d2a30"))
		text_at(phone_panel,"На моём телефоне",Vector2(61,94),Vector2(218,17),10,Color("8b857e"))
		var divider := ColorRect.new()
		divider.position = Vector2(22,121)
		divider.size = Vector2(276,1)
		divider.color = Color("d9d1c4")
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phone_panel.add_child(divider)
	else:
		_phone_button("‹",Vector2(15,68),Vector2(34,38),_close_friends_chat,25,true)
		var contact := page if page in ["artrey", "grok", "jbt"] else "artrey"
		_phone_contact_avatar(contact)
		var display_contact := "Грок" if contact == "grok" else "ЖБТ" if contact == "jbt" else "Артбей"
		text_at(phone_panel,display_contact,Vector2(110,68),Vector2(180,27),17,Color("f4edf9"))
		text_at(phone_panel,"в сети · сообщения",Vector2(110,94),Vector2(180,17),10,Color("9dcab4"))
	if active_chapter > 0 and not phone_notes_open:
		var pages := [
			["Артбей", "artrey"], ["Грок", "grok"], ["ЖБТ", "jbt"], ["Чернов.", "draft_grok"]
		]
		for index in range(pages.size()):
			var selected := page == str(pages[index][1]) or page.begins_with("draft_") and index == 3
			_phone_button(str(pages[index][0]), Vector2(17 + index * 73, 133), Vector2(68, 32), show_friends_chat.bind(str(pages[index][1])), 10, selected)
	if page.begins_with("draft_"):
		_show_phone_draft(page.trim_prefix("draft_"))
	else:
		_show_phone_conversation(page)
	var home_bar := Panel.new()
	home_bar.position = Vector2(119,472)
	home_bar.size = Vector2(82,4)
	var home_style := StyleBoxFlat.new()
	home_style.bg_color = Color("aaa49d") if phone_notes_open else Color("b1aabc")
	home_style.set_corner_radius_all(3)
	home_bar.add_theme_stylebox_override("panel",home_style)
	home_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_panel.add_child(home_bar)
	_show_hint("E — открыть телефон · Esc — закрыть чат")

func _phone_contact_avatar(contact: String) -> void:
	var crops := {
		"artrey": Rect2(160, 20, 800, 800),
		"grok": Rect2(35, 3, 260, 260),
		"jbt": Rect2(18, 0, 275, 275),
	}
	var backing := Panel.new()
	backing.position = Vector2(60,67)
	backing.size = Vector2(40,40)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing_style := StyleBoxFlat.new()
	backing_style.bg_color = Color("554267") if contact == "grok" else Color("3b5760") if contact == "jbt" else Color("4a415f")
	backing_style.border_color = Color("8d7a9d")
	backing_style.set_border_width_all(1)
	backing_style.set_corner_radius_all(20)
	backing.add_theme_stylebox_override("panel", backing_style)
	phone_panel.add_child(backing)
	if not phone_avatar_textures.has(contact):
		var source_path := "res://assets/portraits/artrey-portrait.png" if contact == "artrey" else "res://assets/portraits/" + contact + "-emotions.png"
		var source: Texture2D = load(source_path)
		var region: Rect2i = Rect2i(crops[contact])
		phone_avatar_textures[contact] = ImageTexture.create_from_image(source.get_image().get_region(region))
	var photo := TextureRect.new()
	photo.name = "ContactAvatar"
	photo.position = Vector2(61,68)
	photo.size = Vector2(38,38)
	photo.texture = phone_avatar_textures[contact]
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_SCALE
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://assets/ui/phone_avatar.gdshader")
	photo.material = mask
	phone_panel.add_child(photo)

func _phone_button(caption: String, pos: Vector2, area: Vector2, action: Callable, font_size: int, selected: bool = false) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = area
	button.text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (Color("eddaae") if state == "pressed" or selected else Color("f7ead0") if state == "hover" or state == "focus" else Color("fffaf1")) if phone_notes_open else (Color("514066") if state == "pressed" or selected else Color("313247") if state == "hover" or state == "focus" else Color("242738"))
		style.border_color = (Color("b98e42") if state == "focus" or selected else Color("ded5c6")) if phone_notes_open else (Color("a790bb") if state == "focus" else Color("6e5b82") if selected else Color(0,0,0,0))
		style.set_border_width_all(1 if phone_notes_open or state == "focus" or selected else 0)
		style.set_corner_radius_all(13)
		button.add_theme_stylebox_override(state, style)
	var label := Label.new()
	label.text = caption
	label.position = Vector2(5,2)
	label.size = area - Vector2(10,4)
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("44382b") if phone_notes_open else Color("f4edf9"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	phone_panel.add_child(button)
	return button

func _show_phone_conversation(contact: String) -> void:
	var sender: String = str({"artrey":"Артбей", "grok":"Грок", "jbt":"ЖБТ"}.get(contact, "Артбей"))
	var outgoing := "▶  0:07\n«Делаю игру. Авторский проект. Всё сам»"
	var incoming := "Ну что, творческий директор, когда покажешь что-нибудь рабочее?"
	if contact == "artrey":
		if story.get_value("artbay_betrayal", false):
			outgoing = "Я нашёл копию и даты. Поговорим без презентации?"
			incoming = "Поговорим лично. В чате это только хуже выглядит."
		elif story.get_value("old_project_notes_found", false):
			outgoing = "В старой папке остались версии и журнал доступа."
			incoming = "Вижу. Давай сверим даты и разберёмся, кто что сделал."
		elif story.get_value("artbay_intro_seen", false):
			outgoing = "После киоска покажу рабочую сборку, не обещания."
			incoming = "Вот это уже разговор. Я тоже принесу свои файлы."
	elif contact == "grok":
		outgoing = "Ключ пока не готов. Я всё ещё собираю игру."
		incoming = "Покажи конкретную проблему. И не называй один скрин всей сборкой."
		if story.get_value("grok_trust", false):
			incoming = "Я могу посмотреть. Только сначала расскажи, что уже сделал сам."
	elif contact == "jbt":
		outgoing = "Я снова открыл проект. С чего начать?"
		incoming = "С одного проверяемого шага. Сохрани копию, потом покажи ошибку."
		if story.get_value("old_project_notes_found", false):
			incoming = "В старых версиях есть порядок изменений. Сверь его с датами файлов."
	var draft_answer := str(story.decisions.get("phone_draft_" + contact, ""))
	if draft_answer == "honest":
		outgoing = "Я застрял и боюсь снова бросить игру. Поможешь разобраться, не делая всё за меня?"
		incoming = "Покажи одну проблему. Дальше решим вместе." if contact == "grok" else "Да. Начнём с того, что ты уже проверил."
	elif draft_answer == "joke":
		outgoing = "Срочный баг: автор проекта внезапно должен работать." if contact == "grok" else "Если проект упадёт, виновата табуретка."
		incoming = "Редкий баг. Покажи сборку." if contact == "grok" else "Сначала сохрани проект, потом обвиняй мебель."
	var date_label := text_at(phone_panel,"СЕГОДНЯ · " + _time_of_day_text(),Vector2(20,177),Vector2(280,17),10,Color("8f91a4"))
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_friends_chat_bubble("Фотик", outgoing, Vector2(76,203), Vector2(220,78), true)
	_add_friends_chat_bubble(str(sender), incoming, Vector2(24,290), Vector2(241,89), false)
	text_at(phone_panel,"✓✓  Доставлено",Vector2(205,382),Vector2(90,15),9,Color("aca1ba"))
	if contact == "artrey" and story.get_value("hotdog_first_visit_seen",false):
		_phone_button("К киоску · Артбей  →",Vector2(18,414),Vector2(284,43),func():
			_close_friends_chat()
			start_hotdog_master(true),12,true)
	elif contact in ["grok", "jbt"] and active_chapter > 0:
		_phone_button("Написать " + str(sender),Vector2(18,414),Vector2(284,43),show_friends_chat.bind("draft_" + contact),12,true)
	else:
		var composer := Panel.new()
		composer.position = Vector2(18,414)
		composer.size = Vector2(284,43)
		var composer_style := StyleBoxFlat.new()
		composer_style.bg_color = Color("242738")
		composer_style.set_corner_radius_all(17)
		composer.add_theme_stylebox_override("panel",composer_style)
		composer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phone_panel.add_child(composer)
		text_at(composer,"Ответить позже…",Vector2(15,12),Vector2(225,20),12,Color("9394a6"))

func _show_phone_draft(contact: String) -> void:
	if contact not in ["grok", "jbt"]:
		contact = "grok"
	text_at(phone_panel,"Черновик разговора",Vector2(23,139),Vector2(274,28),18,Color("2d2a30"))
	text_at(phone_panel,"Сегодня, " + _time_of_day_text() + "  ·  Не отправлено",Vector2(23,170),Vector2(274,17),10,Color("888178"))
	text_at(phone_panel,"КОМУ НАПИСАТЬ",Vector2(23,189),Vector2(260,16),10,Color("82796e"))
	_phone_button("Грок",Vector2(18,211),Vector2(137,32),show_friends_chat.bind("draft_grok"),11,contact == "grok")
	_phone_button("ЖБТ",Vector2(165,211),Vector2(137,32),show_friends_chat.bind("draft_jbt"),11,contact == "jbt")
	var chosen := str(story.decisions.get("phone_draft_" + contact, ""))
	var addressee := "Грок" if contact == "grok" else "ЖБТ"
	var draft := "Я застрял и боюсь снова бросить игру. Поможешь разобраться, не делая всё за меня?"
	var joke := "Срочный баг: автор проекта внезапно должен работать." if contact == "grok" else "Если проект упадёт, виновата табуретка."
	if chosen.is_empty():
		_add_friends_chat_bubble("ДЛЯ " + addressee.to_upper(), "Написать прямо или снова спрятаться за шуткой?", Vector2(18,254), Vector2(284,88), true)
		_phone_button("Написать честно  →",Vector2(18,350),Vector2(284,45),_phone_send_draft.bind(contact,"honest"),12,true)
		_phone_button("Отправить шутку",Vector2(18,404),Vector2(284,45),_phone_send_draft.bind(contact,"joke"),12)
	else:
		_add_friends_chat_bubble("ОТПРАВЛЕНО · " + addressee.to_upper(),draft if chosen == "honest" else joke,Vector2(18,254),Vector2(284,108),true)
		text_at(phone_panel,"Сообщение отправлено · выбор сохранён",Vector2(23,370),Vector2(274,24),11,Color("687d6d"))
		_phone_button("Вернуться к переписке  →",Vector2(18,406),Vector2(284,43),show_friends_chat.bind(contact),12,true)

func _phone_send_draft(contact: String, choice: String) -> void:
	if active_chapter <= 0 or contact not in ["grok", "jbt"] or choice not in ["honest", "joke"]:
		return
	if story.decide("phone_draft_" + contact, choice):
		save_progress()
	show_friends_chat(contact)

func _add_friends_chat_bubble(sender: String, message: String, pos: Vector2, area: Vector2, outgoing: bool) -> void:
	var bubble := Panel.new()
	bubble.position = pos
	bubble.size = area
	bubble.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fffaf1") if phone_notes_open else Color("514368") if outgoing else Color("2b2c3c")
	if phone_notes_open:
		style.border_color = Color("ddd4c6")
		style.set_border_width_all(1)
	style.set_corner_radius_all(17)
	if outgoing:
		style.corner_radius_bottom_right = 5
	else:
		style.corner_radius_bottom_left = 5
	bubble.add_theme_stylebox_override("panel",style)
	phone_panel.add_child(bubble)
	text_at(bubble,sender,Vector2(12,8),Vector2(area.x-24,17),10,Color("a1804a") if phone_notes_open else Color("d8bdec") if outgoing else Color("b9cfcd"))
	var body := RichTextLabel.new()
	body.position = Vector2(12,27)
	body.size = Vector2(area.x-24,area.y-32)
	body.text = message
	body.bbcode_enabled = false
	body.fit_content = false
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("normal_font_size",11)
	body.add_theme_color_override("default_color",Color("35312e") if phone_notes_open else Color("f0eaf7"))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(body)

func _close_friends_chat() -> void:
	phone_panel.hide()
	mode = "room"
	computer_open = false
	player.velocity = Vector2.ZERO
	AudioManager.play_music("room")
	_set_phone_chat_hud(false)
	refresh_goal()
	if step == Step.PROJECT:
		_show_hint("Сообщение отправлено · теперь запусти игру на компьютере")

func _set_phone_chat_hud(hidden: bool) -> void:
	phone_hud_hidden = hidden
	for control in [chapter_title, status_label, task_panel, hint_panel, notebook_hint_panel, interaction_prompt]:
		if is_instance_valid(control):
			control.visible = not hidden
	_refresh_hud_visibility()

func show_info(title: String, body: String, caption: String) -> void:
	app_header(title)
	text_at(app_panel,body,Vector2(28,94),Vector2(696,190),20)
	text_at(app_panel,caption,Vector2(28,317),Vector2(696,60),16,Color("c3abd7"))

func show_blender() -> void:
	if minigame_checkpoint.get("kind", "") == "blender":
		Early.show_blender_game(self)
		return
	app_header("Blender  /  стартовая сцена")
	text_at(app_panel,"Scene Collection\n   Camera\n   Cube\n   Light",Vector2(25,100),Vector2(195,160),16,Color("bbaec8"))
	var cube := Polygon2D.new()
	cube.position=Vector2(444,190)
	cube.color=Color("9b95a5")
	cube.polygon=PackedVector2Array([Vector2(-64,-39),Vector2(0,-73),Vector2(64,-39),Vector2(64,37),Vector2(0,73),Vector2(-64,37)])
	app_panel.add_child(cube)
	var side := Polygon2D.new()
	side.color=Color("655e73")
	side.polygon=PackedVector2Array([Vector2(0,0),Vector2(64,-39),Vector2(64,37),Vector2(0,73)])
	cube.add_child(side)
	button_at(app_panel,"Посмотреть на куб",Vector2(250,317),Vector2(300,38),func(): Early.observe_model(self))
	button_at(app_panel,"Попробовать создать ключ →",Vector2(250,362),Vector2(300,32),func(): Early.show_blender_game(self))
	_show_hint("Самый обычный куб. Очень сложный собеседник.")

func show_search() -> void:
	app_header("Поиск")
	text_at(app_panel,"Найти файл или приложение",Vector2(28,90),Vector2(696,35),20)
	search_input=LineEdit.new()
	search_input.position=Vector2(28,147)
	search_input.size=Vector2(704,45)
	search_input.placeholder_text="Введите запрос…"
	search_input.add_theme_font_size_override("font_size",17)
	app_panel.add_child(search_input)
	search_input.text_submitted.connect(func(_value): submit_search())
	button_at(app_panel,"Вставить скрипт",Vector2(28,220),Vector2(218,44),func(): search_input.text="import bpy; bpy.ops.mesh.primitive_cylinder_add(vertices=16)")
	button_at(app_panel,"Найти",Vector2(265,220),Vector2(160,44),submit_search)
	search_result=text_at(app_panel,"Скрипт из ЖБТ скопирован.",Vector2(28,304),Vector2(704,65),18,Color("c6b1db"))

func submit_search() -> void:
	if search_input.text.strip_edges().is_empty():
		search_result.text="4fr даже запрос пока не вставил."
	elif "bpy" not in search_input.text:
		search_result.text="Ничего не найдено. Попробуйте вставить скрипт из ЖБТ."
	else:
		begin_flow("search")

func show_notebook() -> void:
	if mode!="notebook":
		notebook_from_room=mode=="room"
	app_header("Блокнот 4fr")
	mode="notebook"
	var pages := ["Хочу игру с глубоким смыслом.","Спросить у ЖБТ, каким.","Нужно: комната, дверь, ключ.\n\nИз этого списка ключ пока сложнее всего.","ЖБТ → "+("Grok. Запрос готов. С заголовком." if step>=Step.GROK else "поможет. Наверное.")]
	text_at(app_panel,pages[page],Vector2(34,116),Vector2(690,145),24)
	button_at(app_panel,"Файлы и резервная копия",Vector2(34,275),Vector2(340,32),show_project_files)
	var left := button_at(app_panel,"← Назад",Vector2(34,320),Vector2(165,42),func(): page=maxi(0,page-1); show_notebook())
	left.disabled=page==0
	var right := button_at(app_panel,"Дальше →",Vector2(560,320),Vector2(165,42),func(): page=mini(3,page+1); show_notebook())
	right.disabled=page==3
	text_at(app_panel,"%d / 4" % (page+1),Vector2(345,329),Vector2(100,30),16)

func show_project_files() -> void:
	app_header("МОЯ ИГРА / исходники и копии")
	var backed: bool = bool(story.get_value("game_backup_created"))
	text_at(app_panel,"Автор: 4fr\nКомната и тест двери · версия 0.1\nkey.glb — отсутствует\n\n" + ("Резервная копия: исходная_комната — сохранена." if backed else "Резервной копии пока нет."),Vector2(28,85),Vector2(695,180),20)
	text_at(app_panel,"Копия: исходная_комната / Только чтение. Исходники остаются у тебя.",Vector2(28,270),Vector2(695,45),14,Color("c3abd7"))
	var copy := button_at(app_panel,"Проверить копию" if backed else "Создать резервную копию",Vector2(28,330),Vector2(340,40),func():
		if not story.get_value("game_backup_created"):
			story.set_value("game_backup_created", true)
			story.set_value("project_backup_snapshot", {"version":"0.1","author":"4fr","scene":"room","door_test":true,"key_missing":true,"created_at":Time.get_datetime_string_from_system()})
			save_progress()
		AchievementManager.report_story_event("project_backup")
		show_project_files()
	)
	copy.tooltip_text = "Сохранить состояние виртуального проекта отдельно от его рабочей версии."

func show_ending() -> void:
	_set_active_chapter(0)
	app_header("ПРОЛОГ ЗАВЕРШЁН")
	mode="ending"
	# Replace desktop navigation: this is the review boundary before chapter 1.
	for child in app_panel.get_children():
		if child is Button:
			child.hide()
	text_at(app_panel,"Творческий директор",Vector2(30,92),Vector2(690,55),32)
	text_at(app_panel,"Сделано ключей: 0\nКонсультаций с ЖБТ: 3\nУверенность в собственных силах: непоколебимая.",Vector2(30,171),Vector2(690,114),20)
	text_at(app_panel,"Grok печатает…\nПродолжение следует.",Vector2(30,290),Vector2(460,44),18,Color("d8b29f"))
	button_at(app_panel,"В комнату",Vector2(532,350),Vector2(195,42),_close_computer)
	button_at(app_panel,"Глава 1 →",Vector2(30,350),Vector2(260,42),start_chapter_one)

func start_chapter_one() -> void:
	_set_active_chapter(1)
	if chapter_one_stage >= 1:
		show_chapter_one_checkpoint()
		return
	flow = "chapter_one_intro"
	mode = "dialogue"
	app_panel.hide()
	computer_panel.hide()
	inventory_panel.hide()
	var script := preload("res://scripts/chapter_one.gd")
	AchievementManager.unlock_achievement("grok_first_chat")
	_start_dialogue_entries(script.opening())

func play_chapter_scene(id: String, entries: Array) -> void:
	flow = id
	mode = "dialogue"
	app_panel.hide()
	computer_panel.hide()
	inventory_panel.hide()
	_start_dialogue_entries(entries)

func show_chapter_one_checkpoint() -> void:
	_set_active_chapter(1)
	app_header("ГЛАВА 1 · АЛЬТУШКА НА ПРОВОДЕ")
	mode = "ending"
	AudioManager.play_music("room")
	text_at(app_panel,"Доказательства невиновности" if chapter_one_stage == 1 else "Приглашение принято",Vector2(30,90),Vector2(690,55),28)
	var body := "Осмотри кровать, постер, шкаф и коробку пиццы. Грок ждёт доказательств.\n\nНайдено: %d / 4" % chapter_one_evidence.size()
	if chapter_one_stage == 2:
		body = "Грок согласилась сделать ключ. Условие: свидание в BIOS.\n\nГЛАВА 1 ЗАВЕРШЕНА\nПродолжение — во второй главе."
	text_at(app_panel,body,Vector2(30,161),Vector2(690,145),20)
	var actions: Array = [{"text":"В комнату","callback":_close_computer}]
	if chapter_one_stage == 2:
		actions.append({"text":"Глава 2 →","callback":start_chapter_two})
	if chapter_one_stage == 2 and chapter_two_complete:
		actions.append({"text":"Повторить главу 2","callback":start_chapter_two})
	_add_ending_actions(actions)

func start_chapter_three() -> void:
	if minigame_checkpoint.get("kind", "") == "tab_war":
		start_tab_war()
		return
	if _maybe_start_call_event(3): return
	_prepare_chapter_computer_start(3)

func _prepare_chapter_computer_start(chapter: int) -> void:
	_set_active_chapter(chapter)
	if chapter >= 3 and minigame_checkpoint.get("kind", "") == "hotdog_master" and chapter_two_complete:
		minigame_checkpoint.clear()
	chapter_computer_pending = chapter
	flow = ""
	dialogue_open = false
	computer_open = false
	mode = "room"
	player.velocity = Vector2.ZERO
	player.position = SPAWN_POSITION
	if is_instance_valid(vn): vn.close()
	for panel in [app_panel, computer_panel, inventory_panel, dialogue_panel]: panel.hide()
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("room")
	refresh_goal()
	save_progress()

func start_tab_war() -> void:
	_set_active_chapter(3)
	chapter_computer_pending = 0
	dialogue_open = false
	flow = ""
	vn.close()
	for panel in [app_panel,computer_panel,inventory_panel,dialogue_panel]: panel.hide()
	hint_label.hide()
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("tab_war")
	mode = "tab_war"
	if not is_instance_valid(tab_war):
		tab_war = preload("res://scripts/tab_war.gd").new()
		tab_war.name = "TabWar"
		tab_war.z_index = 150
		ui_layer.add_child(tab_war)
		tab_war.checkpoint_changed.connect(_save_tab_war)
		tab_war.finished.connect(_finish_tab_war)
		tab_war.pause_requested.connect(func(): pause_menu.open_pause())
	var raw: Variant = minigame_checkpoint.get("state", {})
	tab_war.open(raw if raw is Dictionary else {})

func _save_tab_war(snapshot: Dictionary) -> void:
	minigame_checkpoint = {"kind":"tab_war","state":snapshot}
	if snapshot.get("phase", "") == "result": AchievementManager.report_story_event("tab_war_finished")
	save_dirty = true
	save_progress()

func _finish_tab_war(result: Dictionary) -> void:
	minigame_checkpoint.clear()
	tab_war.hide()
	var deltas := {}
	if bool(result.get("won",false)):
		deltas["affection_grok" if result.get("side") == "grok" else "affection_gpt"] = 1
	story.decide("tab_war_result",str(result.get("side","grok")),deltas,{"tab_war_completed":true,"tab_war_won":bool(result.get("won",false)),"tab_war_result":result.duplicate(true)})
	AchievementManager.report_story_event("tab_war_finished")
	play_chapter_scene("chapter_three_outro",preload("res://scripts/chapter_three.gd").after_tab_war(result,story.values))

func show_chapter_three_ending() -> void:
	_set_active_chapter(3)
	app_header("ГЛАВА 3 ЗАВЕРШЕНА")
	mode = "ending"
	AudioManager.play_music("room")
	text_at(app_panel,"ЖБТ наносит ответный удар",Vector2(30,90),Vector2(690,60),28)
	text_at(app_panel,"Война вкладок завершена.\nПришла повестка в Министерство Ключевых Дел.\n\nПродолжение — в главе 4.",Vector2(30,170),Vector2(690,140),20)
	_add_ending_actions([
		{"text":"В комнату","callback":_close_computer},
		{"text":"Повторить главу 3","callback":start_chapter_three},
		{"text":"Война вкладок","callback":start_tab_war},
		{"text":"Глава 4 →","callback":start_chapter_four}
	])

func start_chapter_four() -> void:
	_set_active_chapter(4)
	if minigame_checkpoint.get("kind", "") == "office_404":
		start_office_queue()
		return
	if story.get_value("chapter_four_complete"):
		show_chapter_four_ending()
		return
	if _maybe_start_call_event(4): return
	_prepare_chapter_computer_start(4)

func start_office_queue() -> void:
	_set_active_chapter(4)
	chapter_computer_pending = 0
	dialogue_open = false
	flow = ""
	vn.close()
	for panel in [app_panel,computer_panel,inventory_panel,dialogue_panel]: panel.hide()
	hint_label.hide()
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("queue_and_trial")
	mode = "office_404"
	if not is_instance_valid(office_queue):
		office_queue = preload("res://scripts/office_queue.gd").new()
		office_queue.name = "OfficeQueue"
		office_queue.z_index = 150
		ui_layer.add_child(office_queue)
		office_queue.checkpoint_changed.connect(_save_office_queue)
		office_queue.finished.connect(_finish_office_queue)
		office_queue.pause_requested.connect(func(): pause_menu.open_pause())
	var raw: Variant = minigame_checkpoint.get("state",{})
	office_queue.open(raw if raw is Dictionary else {})

func _save_office_queue(snapshot: Dictionary) -> void:
	minigame_checkpoint = {"kind":"office_404","state":snapshot}
	save_dirty = true
	save_progress()

func _finish_office_queue(result: Dictionary) -> void:
	minigame_checkpoint.clear()
	if is_instance_valid(office_queue): office_queue.hide()
	if int(result.get("approved",0)) >= 3:
		AchievementManager.report_story_event("ministry_complete")
	if bool(result.get("stamp_obtained",false)) or bool(result.get("stamp_stolen",false)):
		AchievementManager.report_story_event("ministry_stamp")
	var flags := {
		"stamp_obtained":bool(result.get("stamp_obtained",false)),
		"stamp_stolen":bool(result.get("stamp_stolen",false)),
		"secret_protocol":bool(result.get("protocol",false)),
		"project_ownership_proven":bool(result.get("authorship_proven",false))
	}
	if not story.decisions.has("chapter_four_queue_result"):
		story.decide("chapter_four_queue_result","stolen" if flags.stamp_stolen else ("legal" if flags.stamp_obtained else "refused"),{},flags)
	play_chapter_scene("chapter_four_outro",preload("res://scripts/chapter_four.gd").after_queue(result,story.values))

func show_chapter_four_ending() -> void:
	_set_active_chapter(4)
	app_header("ГЛАВА 4 ЗАВЕРШЕНА")
	mode = "ending"
	AudioManager.play_music("room")
	text_at(app_panel,"Государство против ключа",Vector2(30,90),Vector2(690,55),28)
	var result := "Печать получена законно." if story.get_value("stamp_obtained") else ("Печать украдена; суд это заметит." if story.get_value("stamp_stolen") else "Министерство выдало отказ, но очередь пережита.")
	if story.get_value("secret_protocol"): result += "\nНайден Протокол 0 — доступна скрытая улика."
	text_at(app_panel,result + "\nСледом — суд.",Vector2(30,160),Vector2(690,120),20)
	_add_ending_actions([
		{"text":"В комнату","callback":_close_computer},
		{"text":"Переиграть главу 4","callback":func():
			minigame_checkpoint.clear()
			_prepare_chapter_computer_start(4)},
		{"text":"Глава 5 → Суд","callback":start_chapter_five}
	])

func start_chapter_five() -> void:
	_set_active_chapter(5)
	if minigame_checkpoint.get("kind","") == "court_trial":
		start_court_trial()
		return
	if story.get_value("chapter_five_complete"):
		show_chapter_five_ending()
		return
	if _maybe_start_call_event(5): return
	_prepare_chapter_computer_start(5)

func start_court_trial() -> void:
	_set_active_chapter(5)
	chapter_computer_pending = 0
	dialogue_open = false
	flow = ""
	vn.close()
	for panel in [app_panel,computer_panel,inventory_panel,dialogue_panel]: panel.hide()
	hint_label.hide()
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("queue_and_trial")
	mode = "court_trial"
	if not is_instance_valid(court_trial):
		court_trial = preload("res://scripts/court_trial.gd").new()
		court_trial.name = "CourtTrial"
		court_trial.z_index = 150
		ui_layer.add_child(court_trial)
		court_trial.checkpoint_changed.connect(_save_court_trial)
		court_trial.finished.connect(_finish_court_trial)
		court_trial.pause_requested.connect(func(): pause_menu.open_pause())
	var raw: Variant = minigame_checkpoint.get("state",{})
	court_trial.open(raw if raw is Dictionary else {},story.values)

func _save_court_trial(snapshot: Dictionary) -> void:
	minigame_checkpoint = {"kind":"court_trial","state":snapshot}
	save_dirty = true
	save_progress()

func _finish_court_trial(result: Dictionary) -> void:
	minigame_checkpoint.clear()
	if is_instance_valid(court_trial): court_trial.hide()
	AchievementManager.report_story_event("printer_judge")
	var quality := int(result.get("quality",0))
	story.decide("chapter_five_evidence","trial",{}, {"court_evidence_quality":quality})
	play_chapter_scene("chapter_five_outro",preload("res://scripts/chapter_five.gd").after_trial(result,story.values))

func show_chapter_five_ending() -> void:
	_set_active_chapter(5)
	app_header("ГЛАВА 5 ЗАВЕРШЕНА")
	mode = "ending"
	AudioManager.play_music("room")
	text_at(app_panel,"Альтушка устраивает суд",Vector2(30,90),Vector2(690,55),28)
	var summary := "Улики приняты: %d / 3." % int(story.get_value("court_evidence_quality",0))
	if story.get_value("lied_in_court"): summary += "\nСуд зафиксировал ложь."
	text_at(app_panel,summary + "\nАртбей ждёт разговора о договоре.",Vector2(30,160),Vector2(690,120),20)
	_add_ending_actions([
		{"text":"В комнату","callback":_close_computer},
		{"text":"Переиграть суд","callback":func():
			minigame_checkpoint.clear()
			_prepare_chapter_computer_start(5)},
		{"text":"Глава 6 → Архив","callback":start_chapter_six}
	])

func start_chapter_six() -> void:
	_set_active_chapter(6)
	if minigame_checkpoint.get("kind","") == "digital_archaeology":
		start_digital_archaeology()
		return
	if story.get_value("chapter_six_complete"):
		show_chapter_six_ending()
		return
	if _maybe_start_call_event(6): return
	_prepare_chapter_computer_start(6)

func start_digital_archaeology() -> void:
	_set_active_chapter(6)
	chapter_computer_pending = 0
	dialogue_open = false
	flow = ""
	vn.close()
	for panel in [app_panel,computer_panel,inventory_panel,dialogue_panel]: panel.hide()
	hint_label.hide()
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("old_projects")
	mode = "digital_archaeology"
	if not is_instance_valid(digital_archaeology):
		digital_archaeology = preload("res://scripts/digital_archaeology.gd").new()
		digital_archaeology.name = "DigitalArchaeology"
		digital_archaeology.z_index = 150
		ui_layer.add_child(digital_archaeology)
		digital_archaeology.checkpoint_changed.connect(_save_digital_archaeology)
		digital_archaeology.finished.connect(_finish_digital_archaeology)
		digital_archaeology.pause_requested.connect(func(): pause_menu.open_pause())
	var raw: Variant = minigame_checkpoint.get("state",{})
	digital_archaeology.open(raw if raw is Dictionary else {},story.values)

func _save_digital_archaeology(snapshot: Dictionary) -> void:
	minigame_checkpoint = {"kind":"digital_archaeology","state":snapshot}
	save_progress()

func _finish_digital_archaeology(result: Dictionary) -> void:
	minigame_checkpoint.clear()
	if is_instance_valid(digital_archaeology): digital_archaeology.hide()
	var has_proof := int(result.get("links",0)) >= 3
	story.set_value("artbay_evidence",has_proof)
	story.set_value("artbay_betrayal",true)
	story.set_value("archive_used_backup",not has_proof)
	if has_proof: story.set_value("project_ownership_proven",true)
	var archive_companion := str(story.get_value("old_projects_companion","alone"))
	if has_proof and archive_companion in ["grok","jbt"]:
		var companion_trusted := bool(story.get_value("grok_trust",false)) and int(story.get_value("lies_count",0)) < 2 if archive_companion == "grok" else bool(story.get_value("gpt_boundaries",false)) and not bool(story.get_value("lied_in_court",false))
		var bond_delta := {"affection_grok":1} if archive_companion == "grok" else {"affection_gpt":1}
		story.decide("archive_companion_help",archive_companion,bond_delta if companion_trusted else {},{"archive_companion_bond":archive_companion if companion_trusted else ""})
	if int(result.get("found",0)) > 0: AchievementManager.report_story_event("artbay_suspicion")
	if has_proof: AchievementManager.report_story_event("digital_detective")
	if has_proof and int(result.get("errors",0)) == 0:
		AchievementManager.report_story_event("no_extra_files")
	AchievementManager.report_story_event("artbay_reveal")
	play_chapter_scene("chapter_six_outro",preload("res://scripts/chapter_six.gd").after_archaeology(result,story.values))

func show_chapter_six_ending() -> void:
	_set_active_chapter(6)
	app_header("ГЛАВА 6 ЗАВЕРШЕНА")
	mode = "ending"
	AudioManager.play_music("room")
	text_at(app_panel,"Друг, который всё устроил",Vector2(30,90),Vector2(690,55),28)
	var summary := "Граф доказательств собран: авторство подтверждено." if story.get_value("artbay_evidence") else "Рабочую копию удалось восстановить, но доказательств для договора не хватило."
	if story.get_value("artbay_control_taken"): summary += "\nАртбей получил контроль над публикацией."
	elif story.get_value("artbay_contract_signed"): summary += "\nПодписан договор с прозрачными ролями и титрами."
	else: summary += "\nРешение о публикации остаётся за 4fr."
	text_at(app_panel,summary + "\n\nНаступил вечер последней сборки.",Vector2(30,160),Vector2(690,120),19)
	_add_ending_actions([
		{"text":"В комнату","callback":_close_computer},
		{"text":"Переиграть","callback":func():
			minigame_checkpoint.clear()
			_prepare_chapter_computer_start(6)},
		{"text":"Глава 7 →","callback":start_chapter_seven}
	])

func start_chapter_seven() -> void:
	_set_active_chapter(7)
	if minigame_checkpoint.get("kind","") == "last_build":
		start_last_build()
		return
	if story.get_value("chapter_seven_complete"):
		show_chapter_seven_ending()
		return
	if _maybe_start_call_event(7): return
	_prepare_chapter_computer_start(7)

func start_last_build() -> void:
	_set_active_chapter(7)
	chapter_computer_pending = 0
	dialogue_open = false
	flow = ""
	vn.close()
	for panel in [app_panel,computer_panel,inventory_panel,dialogue_panel]: panel.hide()
	hint_label.hide()
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("wire_puzzle")
	mode = "last_build"
	if not is_instance_valid(last_build):
		last_build = preload("res://scripts/last_build.gd").new()
		last_build.name = "LastBuild"
		last_build.z_index = 150
		ui_layer.add_child(last_build)
		last_build.checkpoint_changed.connect(_save_last_build)
		last_build.finished.connect(_finish_last_build)
		last_build.pause_requested.connect(func(): pause_menu.open_pause())
	var raw: Variant = minigame_checkpoint.get("state",{})
	last_build.open(raw if raw is Dictionary else {})

func _save_last_build(snapshot: Dictionary) -> void:
	minigame_checkpoint = {"kind":"last_build","state":snapshot}
	save_progress()

func _finish_last_build(result: Dictionary) -> void:
	minigame_checkpoint.clear()
	if is_instance_valid(last_build): last_build.hide()
	story.set_value("last_build_turns",int(result.get("turns",0)))
	play_chapter_scene("chapter_seven_outro",preload("res://scripts/chapter_seven.gd").final_choice(story.values))

func show_chapter_seven_ending() -> void:
	_clear_credits_screen()
	_set_active_chapter(7)
	app_header("ТИПОЧЕК: КЛЮЧ · ФИНАЛ")
	mode = "ending"
	AudioManager.play_music("room")
	var ending_id := str(story.get_value("final_ending","neutral"))
	var illustration_names := {
		"grok":"grok",
		"jbt":"jbt",
		"artbay":"artrey",
		"artbay_bad":"artrey_bad",
		"team":"team",
		"ministry":"ministry",
		"triple":"triple",
		"instrumental":"instrumental",
		"neutral":"solo"
	}
	var illustration_name := str(illustration_names.get(ending_id,"solo"))
	var illustration := load("res://assets/ui/endings/%s.png" % illustration_name) as Texture2D
	if illustration:
		var illustration_frame := Panel.new()
		illustration_frame.name = "EndingIllustrationFrame"
		illustration_frame.position = Vector2(426,82)
		illustration_frame.size = Vector2(308,198)
		illustration_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color("100d18")
		frame_style.border_color = Color("8e78a7")
		frame_style.set_border_width_all(2)
		frame_style.set_corner_radius_all(8)
		illustration_frame.add_theme_stylebox_override("panel",frame_style)
		app_panel.add_child(illustration_frame)
		var illustration_view := TextureRect.new()
		illustration_view.name = "EndingIllustration"
		illustration_view.position = Vector2(4,4)
		illustration_view.size = Vector2(300,190)
		illustration_view.texture = illustration
		illustration_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illustration_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		illustration_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		illustration_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		illustration_frame.add_child(illustration_view)
	text_at(app_panel,"ПОСЛЕДНЯЯ СБОРКА",Vector2(30,90),Vector2(380,48),27)
	_multiline_text_at(app_panel,preload("res://scripts/chapter_seven.gd").ending_text(ending_id,story.values),Vector2(30,155),Vector2(380,135),16,Color("d7c6df"))
	text_at(app_panel,"Финал: " + preload("res://scripts/chapter_seven.gd").ending_title(ending_id) + " · Поворотов узлов: %d" % int(story.get_value("last_build_turns",0)),Vector2(30,300),Vector2(690,34),15,Color("e2c791"))
	_add_ending_actions([
		{"text":"В комнату","callback":_close_computer},
		{"text":"Переиграть финал","callback":func():
			minigame_checkpoint.clear()
			story.set_value("chapter_seven_complete",false)
			start_chapter_seven()},
		{"text":"Титры →","callback":show_credits}
	], 342.0)
	if not story.decisions.has("ending_achievement_" + ending_id):
		story.decide("ending_achievement_" + ending_id,ending_id)
	AchievementManager.report_story_event("ending",{"id":ending_id})

func show_credits() -> void:
	_clear_credits_screen()
	mode = "credits"
	AudioManager.play_music("credits")
	for panel in [app_panel,computer_panel,inventory_panel,dialogue_panel]:
		panel.hide()
	credits_screen = Control.new()
	credits_screen.name = "CreditsScreen"
	credits_screen.size = Vector2(960,540)
	credits_screen.z_index = 300
	credits_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(credits_screen)
	var background := ColorRect.new()
	background.color = Color("08070d")
	background.size = credits_screen.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	credits_screen.add_child(background)
	var viewport := Control.new()
	viewport.name = "CreditsRollViewport"
	viewport.position = Vector2.ZERO
	viewport.size = credits_screen.size
	viewport.clip_contents = true
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_screen.add_child(viewport)
	credits_label = RichTextLabel.new()
	credits_label.position = Vector2(90,credits_screen.size.y)
	credits_label.size = Vector2(780,460)
	credits_label.bbcode_enabled = true
	credits_label.fit_content = false
	credits_label.scroll_active = false
	credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_label.clip_contents = true
	credits_label.add_theme_font_size_override("normal_font_size",16)
	credits_label.add_theme_color_override("default_color",Color("d7c6df"))
	credits_label.text = "[center][font_size=25][color=#eee5fa][b]ТИПОЧЕК: КЛЮЧ[/b][/color][/font_size]\n\n[color=#e2c791][b]Авторы игры[/b][/color]\nмясник вайбкодер & 2poi_no_vibecoder\n\n[color=#e2c791][b]Визуальное оформление[/b][/color]\nмясник вайбкодер & 2poi_no_vibecoder\n\n[color=#e2c791][b]Сюжетные главы, диалоги и игровые системы[/b][/color]\nмясник вайбкодер & 2poi_no_vibecoder\n\n[color=#e2c791][b]Помощь в разработке[/b][/color]\nChatGPT / Codex\n\n[color=#e2c791][b]Движок[/b][/color]\nGodot Engine\n\n[color=#e2c791][b]пошел нахуй[/b][/color]\nпрохождение стоило 2 аккаунта Codex по 600 рублей[/center]"
	viewport.add_child(credits_label)
	credits_buttons.clear()
	credits_buttons.append(button_at(credits_screen,"Назад к финалу",Vector2(130,480),Vector2(220,42),show_chapter_seven_ending))
	credits_buttons.append(button_at(credits_screen,"В комнату",Vector2(370,480),Vector2(220,42),_close_computer))
	credits_buttons.append(button_at(credits_screen,"Главное меню",Vector2(610,480),Vector2(220,42),func():
		get_tree().change_scene_to_file("res://MainMenu.tscn")))
	for button in credits_buttons:
		button.hide()
	await get_tree().process_frame
	credits_roll = credits_screen.create_tween()
	credits_roll.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	credits_roll.set_trans(Tween.TRANS_LINEAR)
	credits_roll.tween_property(credits_label,"position",Vector2(90,-credits_label.size.y),11.333333)
	credits_roll.finished.connect(_reveal_credits_buttons)

func _reveal_credits_buttons() -> void:
	if mode != "credits": return
	for button in credits_buttons:
		if is_instance_valid(button): button.show()

func _finish_credits_roll() -> void:
	if credits_roll != null and credits_roll.is_valid():
		credits_roll.kill()
	if is_instance_valid(credits_label):
		credits_label.position.y = -credits_label.size.y
	_reveal_credits_buttons()

func _clear_credits_screen() -> void:
	if credits_roll != null and credits_roll.is_valid():
		credits_roll.kill()
	credits_roll = null
	if is_instance_valid(credits_screen):
		credits_screen.queue_free()
	credits_screen = null
	credits_label = null
	credits_buttons.clear()

func start_chapter_two() -> void:
	_set_active_chapter(2)
	if minigame_checkpoint.get("kind", "") == "hotdog_master":
		start_hotdog_master()
		return
	if minigame_checkpoint.get("kind", "") == "brainstorm":
		Early.show_brainstorm(self)
		return
	if story.get_value("grok_date_completed") and not story.get_value("artbay_intro_seen"):
		start_hotdog_master()
		return
	if story.get_value("grok_date_completed") and story.get_value("artbay_intro_seen") and not story.get_value("brainstorm_completed"):
		if int(story.get_value("hotdog_order_stage",0)) in [1,2,3]:
			start_hotdog_master(true)
			return
		if str(story.decisions.get("artrey_cooperation", "")) == "artrey_refuse": _finish_chapter_two()
		else: Early.show_brainstorm(self)
		return
	if _maybe_start_call_event(2): return
	_continue_chapter_two_start()

func _continue_chapter_two_start() -> void:
	_build_bios_background()
	play_chapter_scene("chapter_two", preload("res://scripts/chapter_two.gd").opening(story.values))

const CALL_EVENT_IDS := ["call_drx", "call_tables", "call_palych"]

func _start_dev_call_event(event_id: String) -> void:
	if event_id not in CALL_EVENT_IDS:
		return
	_reset_progress()
	intro_seen = true
	active_chapter = 2
	flow = "phone_call_dev_" + event_id
	mode = "dialogue"
	play_chapter_scene(flow, _call_event_dialogue(event_id))

func _finish_dev_call_event() -> void:
	flow = ""
	mode = "menu"
	SaveManager.request_dev_picker_reopen()
	AudioManager.set_walking(false)
	AudioManager.play_music("menu")
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _make_call_event_schedule(chapters: Array[int]) -> Array[Dictionary]:
	var available := chapters.duplicate()
	available.shuffle()
	var events: Array[String] = []
	for event_id in CALL_EVENT_IDS:
		events.append(str(event_id))
	events.shuffle()
	var result: Array[Dictionary] = []
	for index in range(mini(events.size(), available.size())):
		result.append({"chapter":available[index], "id":events[index]})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.chapter) < int(b.chapter))
	return result

func _initialize_call_event_schedule() -> void:
	call_event_schedule = _make_call_event_schedule([2, 3, 4, 5, 6, 7])
	call_event_completed.clear()
	call_event_pending = ""
	call_event_pending_chapter = 0
	call_event_schedule_initialized = true

func _maybe_start_call_event(chapter: int) -> bool:
	if SaveManager.is_dev_session() or dialogue_open or mode in ["tab_war", "office_404", "court_trial", "digital_archaeology", "last_build", "credits", "transition"]:
		return false
	if not call_event_pending.is_empty():
		if call_event_pending_chapter == chapter:
			_start_call_event(call_event_pending, chapter)
			return true
		return false
	for event in call_event_schedule:
		if int(event.get("chapter", 0)) == chapter and str(event.get("id", "")) not in call_event_completed:
			_start_call_event(str(event.id), chapter)
			return true
	return false

func _start_call_event(event_id: String, chapter: int) -> void:
	if event_id not in CALL_EVENT_IDS:
		return
	call_event_schedule_initialized = true
	call_event_pending = event_id
	call_event_pending_chapter = chapter
	_set_active_chapter(chapter)
	chapter_computer_pending = 0
	mode = "dialogue"
	flow = "phone_call_" + event_id
	save_progress()
	play_chapter_scene(flow, _call_event_dialogue(event_id))

func _call_event_dialogue(event_id: String) -> Array:
	match event_id:
		"call_drx":
			return [
				{"speaker_id":"caller", "speaker":"workersgoincrazy@outlook.com", "text":"Алло, это обма сумаше. Есть предложение: будешь воркать DRX — созваниваться с американцами и проводить с ними сделки на кредиты.", "side":"left"},
				{"speaker_id":"grat", "speaker":"4fr", "text":"Подожди. То есть я теперь международный специалист?", "side":"right"},
				{"speaker_id":"caller", "speaker":"workersgoincrazy@outlook.com", "text":"Ну… примерно. Главное — уверенно говорить «договорились».", "side":"left"},
				{"speaker_id":"grat", "speaker":"4fr", "text":"Я уже вижу строчку в резюме. «Работал с Америкой». Звучит мощно.", "side":"right"},
				{"speaker_id":"caller", "speaker":"workersgoincrazy@outlook.com", "text":"Прости… ахах—", "side":"left"},
				{"speaker_id":"grat", "speaker":"4fr", "text":"Алло? Связь оборвалась. Наверное, там уже очередь из американцев.", "side":"right"}
			]
		"call_tables":
			return [
				{"speaker_id":"caller", "speaker":"mlff", "text":"Слушай, есть вариант. Будешь воркать столы.", "side":"left"},
				{"speaker_id":"grat", "speaker":"4fr", "text":"Столы… Это которые перспективные?", "side":"right"},
				{"speaker_id":"caller", "speaker":"mlff", "text":"Очень. Там столы.", "side":"left"},
				{"speaker_id":"grat", "speaker":"4fr", "text":"Я так и думал. Сколько там направлений? Я могу быстро освоиться.", "side":"right"},
				{"speaker_id":"grat", "speaker":"4fr", "text":"Когда начинать?", "side":"right"},
				{"speaker_id":"caller", "speaker":"mlff", "text":"АХАХА…", "side":"left"},
				{"speaker_id":"grat", "speaker":"4fr", "text":"Сбросил. Наверное, пошёл оформлять. Я почти устроился.", "side":"right"}
			]
		"call_palych":
			return [
				{"speaker_id":"caller", "speaker":"Палыч", "text":"4fr, иди работать на Wildberries.", "side":"left"},
				{"speaker_id":"grat", "speaker":"4fr", "text":"Ахуенно.", "side":"right"},
				{"speaker_id":"caller", "speaker":"Палыч", "text":"Вот и договорились. Всё, пока.", "side":"left"},
				{"speaker_id":"grat", "speaker":"4fr", "text":"Пока.", "side":"right"}
			]
	return []

func _finish_call_event(event_id: String) -> void:
	flow = ""
	call_event_pending = ""
	var chapter := call_event_pending_chapter
	call_event_pending_chapter = 0
	if event_id in CALL_EVENT_IDS and event_id not in call_event_completed:
		call_event_completed.append(event_id)
		AchievementManager.unlock_achievement(event_id)
	save_progress()
	_continue_chapter_after_call(chapter)

func _continue_chapter_after_call(chapter: int) -> void:
	match chapter:
		2: _continue_chapter_two_start()
		3, 4, 5, 6, 7: _prepare_chapter_computer_start(chapter)

func _build_bios_background() -> void:
	if is_instance_valid(bios_background): bios_background.queue_free()
	bios_background = ColorRect.new()
	bios_background.color = Color("071d70")
	bios_background.size = Vector2(960,540)
	bios_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(bios_background)
	text_at(bios_background,"BIOS SETUP UTILITY  /  ROMANTIC EDITION",Vector2(35,20),Vector2(900,40),24)
	text_at(bios_background,"CPU: INTEL · HEART: NOT DETECTED\n\n[ SYSTEM PROCESSES ]    [ DINNER.EXE ]    [ DEFENDER ]\n\nInitializing relationship...\nPress any compliment to continue",Vector2(45,90),Vector2(860,220),19,Color("9edbff"))

func start_artrey() -> void:
	start_hotdog_master()

func _show_hotdog_background_for_dialogue() -> void:
	if not is_instance_valid(hotdog_master):
		hotdog_master = preload("res://HotdogMasterLocation.tscn").instantiate()
		hotdog_master.name = "HotdogMasterLocation"
		hotdog_master.z_index = 90
		ui_layer.add_child(hotdog_master)
		hotdog_master.checkpoint_changed.connect(_save_hotdog_master)
		hotdog_master.interaction_requested.connect(_on_hotdog_master_interaction)
		hotdog_master.order_confirmed.connect(_on_hotdog_order_confirmed)
		hotdog_master.pause_requested.connect(func(): pause_menu.open_pause())
		hotdog_master.return_requested.connect(_leave_hotdog_master)
	# The location covers the whole viewport. Keep it behind the VN widget in
	# scene-tree input order as well as draw order, so choice buttons receive clicks.
	if hotdog_master.get_index() > vn.get_index():
		ui_layer.move_child(hotdog_master, vn.get_index())
	var raw: Variant = minigame_checkpoint.get("state",{}) if minigame_checkpoint.get("kind", "") == "hotdog_master" else {}
	hotdog_master.open(raw if raw is Dictionary else {},not bool(story.get_value("hotdog_first_visit_seen",false)),false)
	hotdog_master.hide_order_menu()
	hotdog_master.set_dialogue_backdrop(true)
	hotdog_master.z_index = 90
	hotdog_master.set_process(false)
	hotdog_master.set_process_unhandled_key_input(false)

func start_hotdog_master(returning: bool = false) -> void:
	if not story.get_value("hotdog_first_visit_seen",false): _set_active_chapter(2)
	chapter_computer_pending = 0
	dialogue_open = false
	flow = ""
	if is_instance_valid(vn): vn.close()
	for panel in [app_panel,computer_panel,inventory_panel,dialogue_panel]: panel.hide()
	if is_instance_valid(phone_panel): phone_panel.hide()
	hint_label.hide()
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("hotdog_master")
	mode = "hotdog_master"
	if not is_instance_valid(hotdog_master):
		hotdog_master = preload("res://HotdogMasterLocation.tscn").instantiate()
		hotdog_master.name = "HotdogMasterLocation"
		hotdog_master.z_index = 150
		ui_layer.add_child(hotdog_master)
		hotdog_master.checkpoint_changed.connect(_save_hotdog_master)
		hotdog_master.interaction_requested.connect(_on_hotdog_master_interaction)
		hotdog_master.order_confirmed.connect(_on_hotdog_order_confirmed)
		hotdog_master.pause_requested.connect(func(): pause_menu.open_pause())
		hotdog_master.return_requested.connect(_leave_hotdog_master)
	if hotdog_master.get_index() > vn.get_index():
		ui_layer.move_child(hotdog_master, vn.get_index())
	var restoring: bool = minigame_checkpoint.get("kind","") == "hotdog_master"
	var raw: Variant = minigame_checkpoint.get("state",{}) if restoring else {}
	hotdog_master.z_index = 150
	hotdog_master.set_process(true)
	hotdog_master.set_process_unhandled_key_input(true)
	hotdog_master.open(raw if raw is Dictionary else {},not bool(story.get_value("hotdog_first_visit_seen",false)))
	var order_stage := int(story.get_value("hotdog_order_stage",0))
	if order_stage == 1:
		hotdog_master.show_order_menu()
	else:
		hotdog_master.hide_order_menu()
	if order_stage in [2,3]:
		hotdog_master.set_dialogue_backdrop(true)
		hotdog_master.z_index = 90
		hotdog_master.set_process(false)
		hotdog_master.set_process_unhandled_key_input(false)
		var ordered_item := str(story.get_value("hotdog_order_choice", "master"))
		play_chapter_scene("hotdog_taste" if order_stage == 2 else "hotdog_poisoning",Early.hotdog_taste(ordered_item) if order_stage == 2 else Early.hotdog_poisoning(str(story.decisions.get("artrey_cooperation", "")) == "artrey_refuse", ordered_item))
		save_progress()
		return
	if not returning and not restoring:
		story.set_value("hotdog_visit_count",int(story.get_value("hotdog_visit_count",0))+1)
	_refresh_hud_visibility()
	refresh_goal()
	save_progress()

func _save_hotdog_master(snapshot: Dictionary) -> void:
	minigame_checkpoint = {"kind":"hotdog_master","state":snapshot.duplicate(true),"return_chapter":active_chapter}
	save_dirty = true
	save_progress()

func _on_hotdog_master_interaction(id: String) -> void:
	if id != "artrey":
		return
	hotdog_master.z_index = 90
	hotdog_master.set_dialogue_backdrop(true)
	hotdog_master.set_process(false)
	hotdog_master.set_process_unhandled_key_input(false)
	if not story.get_value("artbay_intro_seen"):
		play_chapter_scene("chapter_two_artrey",Early.hotdog_first_chat(story.values))
	else:
		play_chapter_scene("hotdog_repeat",Early.hotdog_repeat_visit(story.values))

func _on_hotdog_order_confirmed(item_id: String = "master") -> void:
	if int(story.get_value("hotdog_order_stage",0)) != 1:
		return
	if item_id not in ["single", "double", "master", "signature"]:
		return
	story.set_value("hotdog_order_choice", item_id)
	story.set_value("hotdog_order_stage",2)
	AchievementManager.unlock_achievement("hotdog_order")
	hotdog_master.z_index = 90
	hotdog_master.set_dialogue_backdrop(true)
	hotdog_master.set_process(false)
	hotdog_master.set_process_unhandled_key_input(false)
	play_chapter_scene("hotdog_taste",Early.hotdog_taste(item_id))
	save_progress()

func _leave_hotdog_master() -> void:
	if is_instance_valid(hotdog_master): hotdog_master.hide()
	minigame_checkpoint.clear()
	mode = "room"
	flow = ""
	AudioManager.play_music("room")
	refresh_goal()
	save_progress()

func _finish_chapter_two() -> void:
	if is_instance_valid(hotdog_master): hotdog_master.hide()
	if mode == "hotdog_master": mode = "room"
	chapter_two_complete = true
	minigame_checkpoint.clear()
	refresh_goal()
	save_progress()
	show_chapter_two_ending()

func show_chapter_two_ending() -> void:
	_set_active_chapter(2)
	AudioManager.play_music("room")
	app_header("ГЛАВА 2 ЗАВЕРШЕНА")
	mode = "ending"
	text_at(app_panel,"Свидание в BIOS",Vector2(30,90),Vector2(690,55),28)
	var dinner_result := "Шеф-повар AMD" if story.get_value("amd_chef_achievement") else "Ужин без технических ингредиентов"
	var friend_result := "План с Артбеем готов." if story.get_value("brainstorm_completed") else ("Артбей остаётся на связи." if story.get_value("artbay_intro_seen") else "Артбей прислал сообщение.")
	_multiline_text_at(app_panel,"Получено: key.txt\nКлючей: 0 · " + dinner_result + "\n" + friend_result + "\n\nСледующий шаг — показать файл ЖБТ.\nГлава 3 доступна по кнопке ниже.",Vector2(30,155),Vector2(690,160),17)
	var actions: Array = [{"text":"В комнату","callback":_close_computer}]
	if not story.get_value("artbay_intro_seen"):
		actions.append({"text":"Чат с Артбеем","callback":start_artrey})
	elif not story.get_value("brainstorm_completed"):
		actions.append({"text":"План с Артбеем","callback":func(): Early.show_brainstorm(self)})
	actions.append({"text":"Глава 3 →","callback":start_chapter_three})
	_add_ending_actions(actions, 346.0)

func _reset_progress() -> void:
	if is_instance_valid(hotdog_master):
		hotdog_master.hide()
		hotdog_master.queue_free()
	hotdog_master = null
	active_chapter = 0
	narrative_day = CHAPTER_START_DAY[0]
	narrative_clock_minutes = CHAPTER_START_MINUTES[0]
	previous_dialogue_duration = 0
	if is_instance_valid(tab_war):
		tab_war.hide()
		tab_war.queue_free()
	tab_war = null
	if is_instance_valid(office_queue):
		office_queue.hide()
		office_queue.queue_free()
	office_queue = null
	if is_instance_valid(court_trial):
		court_trial.hide()
		court_trial.queue_free()
	court_trial = null
	story.reset()
	minigame_checkpoint.clear()
	dialogue_resume.clear()
	pending_evidence = ""
	dialogue_open = false
	if is_instance_valid(vn): vn.close()
	if is_instance_valid(bios_background): bios_background.queue_free()
	step = Step.VOICE
	intro_seen = false
	consultations = 0
	flow = ""
	page = 0
	copied_code = false
	chapter_one_stage = 0
	chapter_two_complete = false
	chapter_computer_pending = 0
	chapter_one_evidence.clear()
	_initialize_call_event_schedule()
	examined.clear()
	player.position = SPAWN_POSITION
	saved_player_position = player.position
	save_dirty = false

func _save_data() -> Dictionary:
	if mode == "tab_war" and is_instance_valid(tab_war) and tab_war.visible:
		minigame_checkpoint = {"kind":"tab_war","state":tab_war._snapshot()}
	if mode == "office_404" and is_instance_valid(office_queue) and office_queue.visible:
		minigame_checkpoint = {"kind":"office_404","state":office_queue.state.snapshot()}
	if mode == "court_trial" and is_instance_valid(court_trial) and court_trial.visible:
		minigame_checkpoint = {"kind":"court_trial","state":court_trial._snapshot()}
	if mode == "digital_archaeology" and is_instance_valid(digital_archaeology) and digital_archaeology.visible:
		minigame_checkpoint = {"kind":"digital_archaeology","state":digital_archaeology.snapshot()}
	if mode == "hotdog_master" and is_instance_valid(hotdog_master) and hotdog_master.visible:
		minigame_checkpoint = {"kind":"hotdog_master","state":hotdog_master.snapshot(),"return_chapter":active_chapter}
	if mode == "last_build" and is_instance_valid(last_build) and last_build.visible:
		minigame_checkpoint = {"kind":"last_build","state":last_build.snapshot()}
	var checkpoint := {}
	if dialogue_open and is_instance_valid(vn) and vn.visible and flow != "demo":
		checkpoint = {"flow":flow,"entries":vn.entries,"index":vn.index,"pending_evidence":pending_evidence}
	return {
		"version": 2,
		"active_chapter": active_chapter,
		"chapter_computer_pending": chapter_computer_pending,
		"scene": "res://Prologue.tscn",
		"player_position": {"x": player.position.x, "y": player.position.y},
		"step": step,
		"intro_seen": intro_seen,
		"consultations": consultations,
		"examined": examined,
		"copied_code": copied_code,
		"chapter_one_stage": chapter_one_stage,
		"chapter_two_complete": chapter_two_complete,
		"chapter_one_evidence": chapter_one_evidence,
		"call_event_schedule": call_event_schedule.duplicate(true),
		"call_event_completed": call_event_completed.duplicate(),
		"call_event_pending": call_event_pending,
		"call_event_pending_chapter": call_event_pending_chapter,
		"call_event_schedule_initialized": call_event_schedule_initialized,
		"notebook_page": page,
		"narrative_clock_minutes": narrative_clock_minutes,
		"narrative_day": narrative_day,
		"story": story.export_data(),
		"dialogue_checkpoint": checkpoint,
		"minigame_checkpoint": minigame_checkpoint.duplicate(true)
	}

func save_progress() -> bool:
	var saved := false
	var data := _save_data()
	if save_path == SaveManager.save_path:
		saved = SaveManager.save_game(data)
	else:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(data, "\t"))
			file.flush()
			saved = true
	if saved:
		saved_player_position = player.position
		save_dirty = false
	return saved

func load_progress() -> bool:
	var data: Dictionary = {}
	if save_path == SaveManager.save_path:
		data = SaveManager.load_game()
	else:
		if not FileAccess.file_exists(save_path):
			return false
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if parsed is Dictionary:
			data = parsed
	if data.is_empty():
		return false
	var version := int(data.get("version", 0))
	if version not in [1, 2]:
		return false
	var call_schedule_migrated := not bool(data.get("call_event_schedule_initialized", false))
	step=clampi(int(data.get("step",0)),0,Step.COMPLETE)
	intro_seen=bool(data.get("intro_seen",false))
	consultations=clampi(int(data.get("consultations",0)),0,3)
	examined.clear()
	for item in data.get("examined",[]):
		if item is String and item not in examined:
			examined.append(item)
	copied_code = bool(data.get("copied_code", step >= Step.SEARCH))
	chapter_one_stage = clampi(int(data.get("chapter_one_stage", 0)), 0, 2)
	chapter_two_complete = bool(data.get("chapter_two_complete", false))
	chapter_computer_pending = clampi(int(data.get("chapter_computer_pending", 0)), 0, 7)
	call_event_schedule.clear()
	var raw_schedule: Variant = data.get("call_event_schedule", [])
	if raw_schedule is Array:
		var scheduled_chapters: Array[int] = []
		var scheduled_ids: Array[String] = []
		for raw_event in raw_schedule:
			if not raw_event is Dictionary:
				continue
			var event_chapter := int(raw_event.get("chapter", 0))
			var event_id := str(raw_event.get("id", ""))
			if event_chapter < 2 or event_chapter > 7 or event_id not in CALL_EVENT_IDS:
				continue
			if event_chapter in scheduled_chapters or event_id in scheduled_ids:
				continue
			scheduled_chapters.append(event_chapter)
			scheduled_ids.append(event_id)
			call_event_schedule.append({"chapter":event_chapter, "id":event_id})
	call_event_completed.clear()
	var raw_completed: Variant = data.get("call_event_completed", [])
	if raw_completed is Array:
		for raw_id in raw_completed:
			var event_id := str(raw_id)
			if event_id in CALL_EVENT_IDS and event_id not in call_event_completed:
				call_event_completed.append(event_id)
	call_event_pending = str(data.get("call_event_pending", ""))
	call_event_pending_chapter = clampi(int(data.get("call_event_pending_chapter", 0)), 0, 7)
	if call_event_pending not in CALL_EVENT_IDS or call_event_pending_chapter < 2:
		call_event_pending = ""
		call_event_pending_chapter = 0
	call_event_schedule_initialized = bool(data.get("call_event_schedule_initialized", false))
	story.import_data(data.get("story", {}))
	if not data.has("story") and chapter_two_complete:
		# Old saves ended at key.txt; preserve that completion and add the new postscript.
		story.set_value("grok_date_completed", true)
		story.set_value("key_txt_received", true)
		story.set_value("dinner_finished", true)
		story.set_value("amd_chef_achievement", true)
		chapter_two_complete = false
	dialogue_resume = _read_dialogue_checkpoint(data.get("dialogue_checkpoint", {}))
	if dialogue_resume.get("flow", "") == "chapter_three":
		var old_index := mini(int(dialogue_resume.get("index",0)),14)
		dialogue_resume = {"flow":"chapter_three_intro","entries":preload("res://scripts/chapter_three.gd").opening(),"index":old_index,"pending_evidence":""}
	minigame_checkpoint.clear()
	var saved_game: Variant = data.get("minigame_checkpoint", {})
	if saved_game is Dictionary and saved_game.get("kind", "") in ["blender", "brainstorm", "tab_war", "office_404", "court_trial", "digital_archaeology", "last_build", "hotdog_master"]:
		minigame_checkpoint = saved_game.duplicate(true)
		if minigame_checkpoint.get("kind") == "brainstorm":
			var raw_picks: Variant = minigame_checkpoint.get("picks", [])
			var clean_picks: Array = []
			if raw_picks is Array:
				for item in raw_picks:
					if item in ["prototype","story","test","ad","meme","donate","sale"] and not clean_picks.has(item) and clean_picks.size() < 3: clean_picks.append(item)
			minigame_checkpoint["picks"] = clean_picks
			if clean_picks.size() != 3: minigame_checkpoint["phase"] = "pick"
	chapter_one_evidence.clear()
	for item in data.get("chapter_one_evidence", []):
		if item is String and preload("res://scripts/chapter_one.gd").EVIDENCE.has(item) and not chapter_one_evidence.has(item):
			chapter_one_evidence.append(item)
	page = clampi(int(data.get("notebook_page", 0)), 0, 3)
	_restore_active_chapter(data)
	if not call_event_schedule_initialized:
		var remaining_chapters: Array[int] = []
		if chapter_computer_pending in [3,4,5,6,7] and dialogue_resume.is_empty() and minigame_checkpoint.is_empty():
			remaining_chapters.append(chapter_computer_pending)
		for chapter in range(maxi(active_chapter + 1, 2), 8):
			if chapter not in remaining_chapters:
				remaining_chapters.append(chapter)
		call_event_schedule = _make_call_event_schedule(remaining_chapters)
		call_event_schedule_initialized = true
		call_event_completed.clear()
		call_event_pending = ""
		call_event_pending_chapter = 0
	narrative_clock_minutes = int(data.get("narrative_clock_minutes", CHAPTER_START_MINUTES[active_chapter]))
	narrative_day = int(data.get("narrative_day", CHAPTER_START_DAY[active_chapter]))
	previous_dialogue_duration = 0
	if version >= 2:
		var position_data = data.get("player_position", {})
		if position_data is Dictionary and position_data.has("x") and position_data.has("y"):
			player.position = Vector2(float(position_data.x), float(position_data.y))
			player.position.x = clampf(player.position.x, 264.0, 696.0)
			player.position.y = clampf(player.position.y, 198.0, 406.0)
	saved_player_position = player.position
	save_dirty = false
	_sync_saved_achievements()
	if call_schedule_migrated:
		save_progress()
	return true

func _restore_active_chapter(data: Dictionary) -> void:
	# A checkpoint is stronger evidence than a completed chapter, including in old saves.
	var saved_flow := str(dialogue_resume.get("flow", ""))
	var kind := str(minigame_checkpoint.get("kind", ""))
	if not call_event_pending.is_empty(): active_chapter = call_event_pending_chapter
	elif chapter_computer_pending in [3,4,5,6,7]: active_chapter = chapter_computer_pending
	elif saved_flow == "chapter_computer_boot": active_chapter = clampi(int(data.get("active_chapter", 0)), 0, 7)
	elif saved_flow.begins_with("chapter_seven") or kind == "last_build": active_chapter = 7
	elif saved_flow.begins_with("chapter_six") or kind == "digital_archaeology": active_chapter = 6
	elif saved_flow.begins_with("chapter_five") or kind == "court_trial": active_chapter = 5
	elif saved_flow.begins_with("chapter_four") or kind == "office_404": active_chapter = 4
	elif saved_flow.begins_with("chapter_three") or kind == "tab_war": active_chapter = 3
	elif saved_flow in ["hotdog_repeat","hotdog_taste","hotdog_poisoning"] or kind == "hotdog_master" and story.get_value("hotdog_first_visit_seen",false): active_chapter = clampi(int(minigame_checkpoint.get("return_chapter",data.get("active_chapter",2))),2,7)
	elif saved_flow.begins_with("chapter_two") or saved_flow == "artrey_plan_done" or kind == "brainstorm": active_chapter = 2
	elif saved_flow.begins_with("chapter_one"): active_chapter = 1
	elif saved_flow in FLOW: active_chapter = 0
	elif data.get("active_chapter") is float or data.get("active_chapter") is int:
		active_chapter = clampi(int(data.active_chapter),0,7)
	elif story.get_value("chapter_seven_complete"): active_chapter = 7
	elif story.get_value("chapter_six_complete"): active_chapter = 6
	elif story.get_value("chapter_five_complete"): active_chapter = 5
	elif story.get_value("chapter_four_complete"): active_chapter = 4
	elif story.get_value("chapter_three_complete"): active_chapter = 3
	elif story.get_value("grok_date_completed"): active_chapter = 2
	elif chapter_one_stage >= 1: active_chapter = 1
	else: active_chapter = 0
	refresh_goal()

func _read_dialogue_checkpoint(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("entries") is Array: return {}
	var allowed := ["intro","voice","project","blender","blender_training","blender_replay","help","search","complain","prompt","grok","chapter_one_intro","chapter_one_evidence","chapter_one_ending","chapter_two","chapter_two_artrey","hotdog_repeat","hotdog_taste","hotdog_poisoning","chapter_computer_boot","chapter_three","chapter_three_intro","chapter_three_outro","chapter_four_intro","chapter_four_outro","chapter_five_intro","chapter_five_outro","chapter_six_intro","chapter_six_outro","chapter_seven_intro","chapter_seven_outro","polaroid_easter_egg","artrey_plan_done","room_optional","optional","phone_call_call_drx","phone_call_call_tables","phone_call_call_palych"]
	if str(raw.get("flow", "")) not in allowed: return {}
	var entries: Array = raw.entries
	if entries.is_empty() or entries.size() > 512: return {}
	for entry in entries:
		if not entry is Dictionary or not entry.get("text") is String: return {}
		if entry.has("next") and (not (entry.next is float or entry.next is int) or int(entry.next) < 0 or int(entry.next) > entries.size()): return {}
		if not entry.get("choices", []) is Array: return {}
		for option in entry.get("choices", []):
			if not option is Dictionary or not option.get("text") is String: return {}
			if option.has("next") and (not (option.next is float or option.next is int) or int(option.next) < 0 or int(option.next) > entries.size()): return {}
	return {"flow":str(raw.flow),"entries":entries.duplicate(true),"index":clampi(int(raw.get("index",0)),0,entries.size()-1),"pending_evidence":str(raw.get("pending_evidence",""))}

func _sync_saved_achievements() -> void:
	if intro_seen:
		AchievementManager.unlock_achievement("first_launch")
	if step >= Step.SEARCH:
		AchievementManager.unlock_achievement("jbt_help")
	if chapter_one_stage >= 1:
		AchievementManager.unlock_achievement("grok_first_chat")
		AchievementManager.unlock_achievement("first_choice")
	if story.get_value("grok_date_completed"):
		AchievementManager.unlock_achievement("grok_date")
	if story.get_value("amd_chef_achievement"):
		AchievementManager.unlock_achievement("amd_chef")
	if story.get_value("model_game_completed"):
		AchievementManager.unlock_achievement("first_model_game")
	if story.get_value("artbay_intro_seen"):
		AchievementManager.unlock_achievement("artbay_first_chat")
	if int(story.get_value("hotdog_order_stage", 0)) >= 2:
		AchievementManager.unlock_achievement("hotdog_order")
	if story.get_value("brainstorm_completed"):
		AchievementManager.unlock_achievement("artbay_brainstorm")
	for call_id in call_event_completed:
		AchievementManager.unlock_achievement(call_id)

func has_unsaved_progress() -> bool:
	return save_dirty or player.position.distance_to(saved_player_position) > 0.5

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress()
