extends "res://scripts/main.gd"

# The playable story inherits Room.tscn; main.gd supplies shared gameplay methods.
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
var save_dirty := false
var saved_player_position := Vector2.ZERO
const SPAWN_POSITION := Vector2(450,340)
const Early = preload("res://scripts/early_content.gd")
var story = preload("res://scripts/story_state.gd").new()
var minigame_checkpoint: Dictionary = {}
var dialogue_resume: Dictionary = {}
var tab_war: Control
var office_queue: Control
var court_trial: Control

const FLOW := {
	"intro": [
		"[b]03:47. КОМНАТА ГРАТА.[/b]\nНа рабочем столе папка «МОЯ ИГРА». Внутри ещё четырнадцать папок. Ни одной игры.",
		"[b]ГРАТ[/b]\nСегодня точно сделаю. Там делов-то: комната, дверь, ключ. Я вообще по идеям.",
		"[b]ТЕЛЕФОН[/b]\nСначала надо сообщить друзьям, кто здесь творческий директор. Телефон лежит на тумбочке возле пиццы."
	],
	"voice": [
		"[b]ГРАТ ЗАПИСЫВАЕТ ГОЛОСОВОЕ[/b]\n«Короче, делаю игру. Авторский проект. Всё сам».\nОн отправляет его в игровой чат друзей.",
		"[b]ВТОРОЙ МОНИТОР[/b]\nЖБТ: «Теперь нажми “Создать проект”».\nГрат аккуратно сворачивает окно. Чтобы не отвлекало от авторского проекта."
	],
	"project": [
		"[b]МОЯ ИГРА → ЗАПУСК[/b]\nПерсонаж подходит к двери. Дверь не открывается. Зато открывается ошибка.",
		"[b][color=#f2a1a1]ERROR: key.glb отсутствует[/color][/b]\nДля продолжения разработки создайте или импортируйте модель ключа.",
		"[b]ГРАТ[/b]\nОдин сраный ключ. Сейчас сам сделаю. Где тут этот Blender?"
	],
	"blender": [
		"[b]ГРАТ[/b]\nЭто куб.\n\nГрат некоторое время смотрит на куб. Куб смотрит в ответ.",
		"[b]ГРАТ[/b]\nЯ вообще по идеям.\nОн закрывает Blender и открывает ЖБТ."
	],
	"help": [
		"[b]ГРАТ → ЖБТ[/b]\nСделай ключ для игры. Обычный. Чтоб дверь открывал.",
		"[b]ЖБТ[/b]\nКонечно! Вот Python-скрипт для Blender. Открой вкладку Scripting, вставь код и нажми Run Script.",
		"[b]ГРАТ[/b]\nАга, вставить код. Понял.\n\nСкрипт скопирован. Грат уже знает идеальное место, куда его вставить."
	],
	"search": [
		"[b]ПОИСК[/b]\nПо вашему запросу ничего не найдено.\nПопробуйте изменить формулировку.",
		"[b]ГРАТ[/b]\nНе работает. Ты опять хуйню дал.\n\nНужно немедленно сообщить об этом ЖБТ."
	],
	"complain": [
		"[b]ГРАТ → ЖБТ[/b]\nЯ вставил. Ноль результатов. Опять нерабочий код.",
		"[b]ЖБТ[/b]\nКод нужно запускать в Blender. Это не поисковый запрос.",
		"[b]ГРАТ[/b]\nВсё, уже не вывозит. Пойду к конкурентам.\n\nОн открывает новую вкладку. Потом возвращается в старую."
	],
	"prompt": [
		"[b]ГРАТ → ЖБТ[/b]\nКак написать другой нейросети, чтобы она сделала нормально?",
		"[b]ЖБТ[/b]\nВот сообщение, которое можно отправить Grok:\n«Привет! Нужна 3D-модель обычного дверного ключа в формате GLB для моей игры». ",
		"[b]ГРАТ[/b]\nВо. Другое дело.\n\nОн копирует весь ответ. Вместе с «Вот сообщение, которое можно отправить Grok»."
	],
	"grok": [
		"[b]НОВАЯ ВКЛАДКА[/b]\nСообщение готово. Осталось познакомиться.\n\nГрат поправляет футболку перед монитором.",
		"[b]ГРАТ[/b]\nНу эта-то точно сделает.\n\nНа экране появляется надпись: «Grok печатает…»"
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
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func button_at(parent: Node, text: String, pos: Vector2, area: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color("39314f")
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("68537b")
	b.add_theme_stylebox_override("hover", hover)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	chapter_title = text_at(ui_layer,"ГРАТ / ПРОЛОГ",Vector2(22,12),Vector2(500,35),23)
	status_label = text_at(ui_layer,"",Vector2(620,17),Vector2(318,25),14,Color("bfaed6"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal_label = text_at(ui_layer,"",Vector2(110,478),Vector2(740,28),16,Color("ddc396"))
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label = text_at(ui_layer,"",Vector2(50,512),Vector2(860,22),14,Color("cdbfdf"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	computer_panel = _make_panel(Vector2(100,68),Vector2(760,405),Color("171322"),Color("706180"))
	ui_layer.add_child(computer_panel)
	app_panel = _make_panel(Vector2(100,68),Vector2(760,405),Color("191524"),Color("8e78a7"))
	ui_layer.add_child(app_panel)
	inventory_panel = _make_panel(Vector2(200,120),Vector2(560,300),Color("191524"),Color("8e78a7"))
	ui_layer.add_child(inventory_panel)
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
	for panel in [computer_panel,app_panel,inventory_panel,dialogue_panel]:
		panel.hide()

func _create_vn() -> void:
	vn = preload("res://scripts/vn_dialogue.gd").new()
	vn.name = "VNDialogue"
	vn.z_index = 100
	ui_layer.add_child(vn)
	vn.finished.connect(_close_dialogue)
	vn.line_changed.connect(_on_story_line_changed)
	vn.choice_selected.connect(_on_achievement_dialogue_choice)

func _on_achievement_dialogue_choice(choice_id: String) -> void:
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
				c4_flags = {"project_access_shared":true,"backup_candidate":true}
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
	if choice_id != "":
		AchievementManager.unlock_achievement("first_choice")
		Early.on_choice(self, choice_id)
		save_dirty = true

func _on_story_line_changed(new_index: int) -> void:
	dialogue_index = new_index
	var event: String = str(vn.current_entry().get("story_event", ""))
	if event == "document_84_opened": AchievementManager.report_story_event(event)
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
	active_chapter = clampi(value, 0, 5)
	refresh_goal()

func refresh_goal() -> void:
	chapter_title.text = "ГРАТ / ПРОЛОГ" if active_chapter == 0 else "ГРАТ / ГЛАВА %d" % active_chapter
	if active_chapter == 3:
		goal_label.text = "Глава 3 завершена · получена повестка в Министерство" if story.get_value("chapter_three_complete") else "Глава 3 · разговор с ЖБТ и война вкладок"
		status_label.text = "03:47 / ЖБТ и Грок онлайн"
		return
	if active_chapter == 4:
		goal_label.text = "Глава 4 завершена · повестка в суд" if story.get_value("chapter_four_complete") else "Глава 4 · разберись с очередью Министерства"
		status_label.text = "03:47 / Министерство Ключевых Дел"
		return
	if active_chapter == 5:
		goal_label.text = "Глава 5 завершена · Артрей предлагает договор" if story.get_value("chapter_five_complete") else "Глава 5 · ответь на обвинения суда"
		status_label.text = "03:47 / Судья-принтер"
		return
	if active_chapter == 2:
		goal_label.text = "Глава 2 завершена · key.txt получен" if chapter_two_complete else ("Глава 2 · Артрей ждёт ответа на телефоне" if story.get_value("grok_date_completed") else "Глава 2 · свидание в BIOS")
		status_label.text = "03:47 / Артрей на связи" if story.get_value("grok_date_completed") else "03:47 / BIOS"
		return
	if active_chapter == 1:
		goal_label.text = "Глава 1 · Доказательства: %d / 4 · кровать, постер, шкаф, пицца" % chapter_one_evidence.size() if chapter_one_stage < 2 else "Глава 1 завершена · следующее свидание — в BIOS"
		status_label.text = "03:47 / Грок онлайн"
		return
	var goals := ["Записать голосовое друзьям · телефон возле пиццы", "Подойти к компьютеру и запустить свою игру", "Открыть Blender и сделать ключ самому", "Попросить ЖБТ сделать модель ключа", "Вставить скрипт в поиск", "Сообщить ЖБТ, что код не работает", "Спросить ЖБТ, как написать Грок", "Открыть вкладку Grok", "Пролог завершён · продолжение следует"]
	goal_label.text = goals[step]
	status_label.text = "03:47 / консультаций: %d" % consultations

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
	text_at(app_panel,"Одна комната. Одна дверь. Один отсутствующий key.glb.\nГрат делает свою первую игру. Всё сам. Почти.",Vector2(32,161),Vector2(680,100),19)
	button_at(app_panel,"Начать" if not intro_seen else "Продолжить",Vector2(32,302),Vector2(212,46),resume_game)
	if intro_seen:
		button_at(app_panel,"С начала",Vector2(264,302),Vector2(180,46),confirm_restart)
	_show_hint("WASD / стрелки — ходить · E — действие · Tab — блокнот · Esc — меню")

func start_vn_demo() -> void:
	flow = "demo"
	mode = "dialogue"
	computer_panel.hide()
	app_panel.hide()
	inventory_panel.hide()
	var demo: Array = [
		{"speaker_id":"grat", "speaker":"Грат", "emotion":"neutral", "side":"left", "text":"ЖБТ, смотри: я наконец-то собрал сцену. Даже свет включил.", "portraits":{"left":{"speaker_id":"grat", "emotion":"neutral"}, "right":{"speaker_id":"jbt", "emotion":"happy"}}},
		{"speaker_id":"jbt", "speaker":"ЖБТ", "emotion":"happy", "side":"right", "text":"Вижу! Теперь выбери, что делать с ключом.", "portraits":{"left":{"speaker_id":"grat", "emotion":"happy"}, "right":{"speaker_id":"jbt", "emotion":"happy"}}, "choices":[{"text":"Сделать его самому", "id":"self", "next":2}, {"text":"Спросить Грока", "id":"grok", "next":3}]},
		{"speaker_id":"grat", "speaker":"Грат", "emotion":"embarrassed", "side":"left", "text":"Сам. Конечно сам. Просто сначала посмотрю один туториал…", "portraits":{"left":{"speaker_id":"grat", "emotion":"embarrassed"}, "right":{"speaker_id":"jbt", "emotion":"neutral"}}},
		{"speaker_id":"grok", "speaker":"Грок", "emotion":"surprised", "side":"right", "text":"О, вы всё-таки позвали меня? Я уже приготовила дерзкий ответ и нормальный пайплайн.", "portraits":{"left":{"speaker_id":"grat", "emotion":"afraid"}, "right":{"speaker_id":"grok", "emotion":"surprised"}}, "choices":[{"text":"Попросить спокойно", "id":"calm", "next":4}, {"text":"Сделать вид, что так и планировал", "id":"bluff", "next":5}]},
		{"speaker_id":"jbt", "speaker":"ЖБТ", "emotion":"happy", "side":"right", "text":"Хороший выбор. Я подсвечу следующий шаг, а не буду делать его за тебя.", "portraits":{"left":{"speaker_id":"grat", "emotion":"happy"}, "right":{"speaker_id":"jbt", "emotion":"happy"}}},
		{"speaker_id":"grat", "speaker":"Грат", "emotion":"afraid", "side":"left", "text":"Я это с самого начала и планировал. Просто план был… гибкий.", "portraits":{"left":{"speaker_id":"grat", "emotion":"afraid"}, "right":{"speaker_id":"grok", "emotion":"angry"}}},
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
		_start_dialogue_entries(checkpoint.entries, int(checkpoint.get("index", 0)))
	elif minigame_checkpoint.get("kind", "") == "tab_war":
		start_tab_war()
	elif minigame_checkpoint.get("kind", "") == "office_404":
		start_office_queue()
	elif minigame_checkpoint.get("kind", "") == "court_trial":
		start_court_trial()
	elif minigame_checkpoint.get("kind", "") == "blender":
		Early.show_blender_game(self)
	elif minigame_checkpoint.get("kind", "") == "brainstorm":
		_set_active_chapter(2)
		Early.show_brainstorm(self)
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
	elif active_chapter == 2:
		if story.get_value("grok_date_completed"): show_chapter_two_ending()
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
		_show_hint("E — " + _object_name(nearby_object) if nearby_object != "" else "WASD / стрелки — ходить · Shift — бег · E — действие · Tab — блокнот")
	else:
		player.velocity=Vector2.ZERO
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
	if mode in ["tab_war","office_404","court_trial"]: return
	if dialogue_open:
		if vn != null and vn.handle_key(key):
			get_viewport().set_input_as_handled()
		return
	if key==KEY_ESCAPE:
		if mode=="room":
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
	return {"computer":"компьютер", "phone":"телефон", "bed":"кровать", "poster":"постер", "pizza":"пицца", "wardrobe":"шкаф", "plant":"растение", "drafts":"черновики", "books":"книги"}.get(id,id)

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
			optional(["[b]ГРАТ[/b]\nЭто доказательство уже приобщено к делу. Виноватым остался я."])
		else:
			pending_evidence = nearby_object
			play_chapter_scene("chapter_one_evidence", preload("res://scripts/chapter_one.gd").evidence(nearby_object))
		return
	if nearby_object=="computer":
		AudioManager.play_pc_sfx()
		show_desktop()
	elif nearby_object=="phone":
		if story.get_value("grok_date_completed") and not chapter_two_complete:
			if minigame_checkpoint.get("kind", "") == "brainstorm": Early.show_brainstorm(self)
			else: start_artrey()
		elif step==Step.VOICE:
			begin_flow("voice")
		else:
			optional(["[b]ТЕЛЕФОН[/b]\nГолосовое: «Авторский проект. Всё сам».\nПрослушано: 2. Ответов: 0."])
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
	elif flow.begins_with("chapter_two") or flow == "artrey_plan_done":
		_set_active_chapter(2)
	elif flow.begins_with("chapter_one"):
		_set_active_chapter(1)
	AudioManager.set_walking(false)
	AudioManager.play_music("dialogue")
	current_lines = []
	for item in entries_to_play:
		if item is Dictionary:
			current_lines.append(str(item.get("text", "")))
	vn_entries = entries_to_play
	dialogue_index = start_index
	dialogue_open = true
	dialogue_panel.hide()
	vn.start(entries_to_play, start_index)
	_show_hint("E / Enter — показать реплику · ещё раз — продолжить")
	hint_label.hide()

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
		elif "ГРАТ" in upper:
			speaker_id = "grat"
			speaker_name = "Грат"
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
		result.append({"speaker_id":speaker_id, "speaker":speaker_name, "emotion":emotion, "side":side, "text":body.replace("\n\n", "\n"), "portraits":portraits})
	return result

func _display_current_line() -> void:
	clear_choices()
	if dialogue_index>=current_lines.size():
		_close_dialogue()
		return
	dialogue_label.text=current_lines[dialogue_index]
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
	var completed_flow := flow
	flow=""
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
		refresh_goal()
		save_progress()
		show_chapter_five_ending()
		return
	if completed_flow == "chapter_two":
		story.set_value("grok_date_completed", true)
		AchievementManager.unlock_achievement("grok_date")
		if is_instance_valid(bios_background):
			bios_background.queue_free()
		refresh_goal()
		save_progress()
		if not story.get_value("artbay_intro_seen"):
			start_artrey()
		else:
			_finish_chapter_two()
		return
	if completed_flow == "chapter_two_artrey":
		story.set_value("artbay_intro_seen", true)
		AchievementManager.report_story_event("artbay_first_chat")
		if str(story.decisions.get("artrey_cooperation", "")) != "artrey_refuse":
			Early.show_brainstorm(self)
		else:
			_finish_chapter_two()
		return
	if completed_flow == "artrey_plan_done":
		AchievementManager.report_story_event("artbay_brainstorm")
		_finish_chapter_two()
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
	text_at(computer_panel,"ГРАТ OS",Vector2(18,11),Vector2(150,24),17)
	text_at(computer_panel,"Личный компьютер / Творческий директор",Vector2(168,14),Vector2(480,24),12,Color("b8adc7"))
	button_at(computer_panel,"×",Vector2(714,7),Vector2(32,29),_close_computer)
	var apps := [["МОЯ ИГРА","project"],["Blender","blender"],["ЖБТ","jbt"],["Поиск","search"],["Блокнот","notebook"],["Grok","grok"]]
	for i in range(apps.size()):
		desktop_shortcut(apps[i][0],apps[i][1],i,Vector2(20+(i%2)*116,49+(i/2)*95))
	var taskbar := ColorRect.new()
	taskbar.position=Vector2(4,345)
	taskbar.size=Vector2(752,56)
	taskbar.color=Color(0.055,0.045,0.09,0.94)
	taskbar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	computer_panel.add_child(taskbar)
	button_at(computer_panel,"Пуск",Vector2(13,355),Vector2(77,36),show_menu)
	text_at(computer_panel,"СЕЙЧАС: "+goal_label.text,Vector2(106,355),Vector2(544,40),13,Color("d7c6b1"))
	text_at(computer_panel,"03:47",Vector2(682,360),Vector2(65,25),17)
	_show_hint("Мышь — выбрать приложение · Esc — выйти из компьютера")

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
	atlas.region=Rect2((index%3)*512,(index/3)*512,512,512)
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
				show_info("Blender", "Куб на месте.\nКомпетенции — в процессе загрузки.", "Грат: «У меня сейчас другая задача».")
		"jbt":
			if step in [Step.HELP,Step.COMPLAIN,Step.PROMPT]:
				begin_flow({Step.HELP:"help",Step.COMPLAIN:"complain",Step.PROMPT:"prompt"}[step])
			else:
				show_info("ЖБТ", "Теперь нажми «Создать проект».", "История чата заботливо хранит авторский вклад Грата.")
		"search":
			if step==Step.SEARCH:
				show_search()
			else:
				show_info("Поиск", "Введите название файла или приложения.", "key.glb не найден.")
		"grok":
			if step==Step.GROK:
				begin_flow("grok")
			elif story.get_value("grok_date_completed"):
				if active_chapter == 3:
					if story.get_value("chapter_three_complete"): show_chapter_three_ending()
					else: start_chapter_three()
				else: show_chapter_two_ending()
			elif step==Step.COMPLETE:
				show_ending()
			else:
				show_info("Новая вкладка", "Грат: «Сначала сам попробую.\nНу, с ЖБТ. Но это считается».", "До Грок ещё дойдём.")

func app_header(title: String) -> void:
	mode="app"
	computer_panel.hide()
	app_panel.show()
	clear_panel(app_panel)
	text_at(app_panel,title,Vector2(26,20),Vector2(580,45),25)
	button_at(app_panel,"Назад",Vector2(620,18),Vector2(112,36),go_back)

func go_back() -> void:
	if mode=="notebook" and notebook_from_room:
		_close_computer()
	else:
		show_desktop()

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
		search_result.text="Грат даже запрос пока не вставил."
	elif "bpy" not in search_input.text:
		search_result.text="Ничего не найдено. Попробуйте вставить скрипт из ЖБТ."
	else:
		begin_flow("search")

func show_notebook() -> void:
	if mode!="notebook":
		notebook_from_room=mode=="room"
	app_header("Блокнот Грата")
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
	text_at(app_panel,"Автор: Грат\nКомната и тест двери · версия 0.1\nkey.glb — отсутствует\n\n" + ("Резервная копия: исходная_комната — сохранена." if backed else "Резервной копии пока нет."),Vector2(28,85),Vector2(695,180),20)
	text_at(app_panel,"Копия: исходная_комната / Только чтение. Исходники остаются у тебя.",Vector2(28,270),Vector2(695,45),14,Color("c3abd7"))
	var copy := button_at(app_panel,"Проверить копию" if backed else "Создать резервную копию",Vector2(28,330),Vector2(340,40),func():
		if not story.get_value("game_backup_created"):
			story.set_value("game_backup_created", true)
			story.set_value("project_backup_snapshot", {"version":"0.1","author":"Грат","scene":"room","door_test":true,"key_missing":true,"created_at":Time.get_datetime_string_from_system()})
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
	text_at(app_panel,"Grok печатает…\nПродолжение следует.",Vector2(30,298),Vector2(430,72),18,Color("d8b29f"))
	button_at(app_panel,"В комнату",Vector2(532,324),Vector2(195,42),_close_computer)
	button_at(app_panel,"Глава 1 →",Vector2(30,324),Vector2(260,42),start_chapter_one)

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
	button_at(app_panel,"В комнату",Vector2(30,324),Vector2(220,42),_close_computer)
	if chapter_one_stage == 2:
		button_at(app_panel,"Глава 2 →",Vector2(285,324),Vector2(220,42),start_chapter_two)
	if chapter_one_stage == 2 and chapter_two_complete:
		button_at(app_panel,"Повторить главу 2",Vector2(285,370),Vector2(260,32),start_chapter_two)

func start_chapter_three() -> void:
	if minigame_checkpoint.get("kind", "") == "tab_war":
		start_tab_war()
		return
	_set_active_chapter(3)
	play_chapter_scene("chapter_three_intro", preload("res://scripts/chapter_three.gd").opening())

func start_tab_war() -> void:
	_set_active_chapter(3)
	dialogue_open = false
	flow = ""
	vn.close()
	for panel in [app_panel,computer_panel,inventory_panel,dialogue_panel]: panel.hide()
	hint_label.hide()
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("dialogue")
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
	play_chapter_scene("chapter_three_outro",preload("res://scripts/chapter_three.gd").after_tab_war(result))

func show_chapter_three_ending() -> void:
	_set_active_chapter(3)
	app_header("ГЛАВА 3 ЗАВЕРШЕНА")
	mode = "ending"
	AudioManager.play_music("room")
	text_at(app_panel,"ЖБТ наносит ответный удар",Vector2(30,90),Vector2(690,60),28)
	text_at(app_panel,"Война вкладок завершена.\nПришла повестка в Министерство Ключевых Дел.\n\nПродолжение — в главе 4.",Vector2(30,170),Vector2(690,140),20)
	button_at(app_panel,"В комнату",Vector2(30,316),Vector2(335,36),_close_computer)
	button_at(app_panel,"Повторить главу 3",Vector2(395,316),Vector2(335,36),start_chapter_three)
	button_at(app_panel,"Война вкладок →",Vector2(30,362),Vector2(335,36),start_tab_war)
	button_at(app_panel,"Глава 4 →",Vector2(395,362),Vector2(335,36),start_chapter_four)

func start_chapter_four() -> void:
	_set_active_chapter(4)
	if minigame_checkpoint.get("kind", "") == "office_404":
		start_office_queue()
		return
	if story.get_value("chapter_four_complete"):
		show_chapter_four_ending()
		return
	play_chapter_scene("chapter_four_intro",preload("res://scripts/chapter_four.gd").opening(story.values))

func start_office_queue() -> void:
	_set_active_chapter(4)
	dialogue_open = false
	flow = ""
	vn.close()
	for panel in [app_panel,computer_panel,inventory_panel,dialogue_panel]: panel.hide()
	hint_label.hide()
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("dialogue")
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
	var flags := {
		"stamp_obtained":bool(result.get("stamp_obtained",false)),
		"stamp_stolen":bool(result.get("stamp_stolen",false)),
		"secret_protocol":bool(result.get("protocol",false)),
		"project_ownership_proven":bool(result.get("authorship_proven",false))
	}
	if not story.decisions.has("chapter_four_queue_result"):
		story.decide("chapter_four_queue_result","stolen" if flags.stamp_stolen else ("legal" if flags.stamp_obtained else "refused"),{},flags)
	play_chapter_scene("chapter_four_outro",preload("res://scripts/chapter_four.gd").after_queue(result))

func show_chapter_four_ending() -> void:
	_set_active_chapter(4)
	app_header("ГЛАВА 4 ЗАВЕРШЕНА")
	mode = "ending"
	AudioManager.play_music("room")
	text_at(app_panel,"Государство против ключа",Vector2(30,90),Vector2(690,55),28)
	var result := "Печать получена законно." if story.get_value("stamp_obtained") else ("Печать украдена; суд это заметит." if story.get_value("stamp_stolen") else "Министерство выдало отказ, но очередь пережита.")
	if story.get_value("secret_protocol"): result += "\nНайден Протокол 0 — доступна скрытая улика."
	text_at(app_panel,result + "\nСледом — суд.",Vector2(30,160),Vector2(690,120),20)
	button_at(app_panel,"В комнату",Vector2(30,324),Vector2(220,42),_close_computer)
	button_at(app_panel,"Переиграть главу 4",Vector2(270,324),Vector2(220,42),func():
		minigame_checkpoint.clear()
		play_chapter_scene("chapter_four_intro",preload("res://scripts/chapter_four.gd").opening(story.values)))
	button_at(app_panel,"Глава 5 → Суд",Vector2(510,324),Vector2(220,42),start_chapter_five)

func start_chapter_five() -> void:
	_set_active_chapter(5)
	if minigame_checkpoint.get("kind","") == "court_trial":
		start_court_trial()
		return
	if story.get_value("chapter_five_complete"):
		show_chapter_five_ending()
		return
	play_chapter_scene("chapter_five_intro",preload("res://scripts/chapter_five.gd").opening(story.values))

func start_court_trial() -> void:
	_set_active_chapter(5)
	dialogue_open = false
	flow = ""
	vn.close()
	for panel in [app_panel,computer_panel,inventory_panel,dialogue_panel]: panel.hide()
	hint_label.hide()
	AudioManager.set_walking(false)
	AudioManager.stop_pc_sfx()
	AudioManager.play_music("dialogue")
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
	text_at(app_panel,summary + "\nАртрей ждёт разговора о договоре.",Vector2(30,160),Vector2(690,120),20)
	button_at(app_panel,"В комнату",Vector2(30,324),Vector2(220,42),_close_computer)
	button_at(app_panel,"Переиграть суд",Vector2(280,324),Vector2(250,42),func():
		minigame_checkpoint.clear()
		play_chapter_scene("chapter_five_intro",preload("res://scripts/chapter_five.gd").opening(story.values)))

func start_chapter_two() -> void:
	_set_active_chapter(2)
	if minigame_checkpoint.get("kind", "") == "brainstorm":
		Early.show_brainstorm(self)
		return
	if story.get_value("grok_date_completed") and not story.get_value("artbay_intro_seen"):
		start_artrey()
		return
	_build_bios_background()
	play_chapter_scene("chapter_two", preload("res://scripts/chapter_two.gd").opening(story.values))

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
	_set_active_chapter(2)
	play_chapter_scene("chapter_two_artrey", Early.artrey_intro())

func _finish_chapter_two() -> void:
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
	button_at(app_panel,"Глава 3 →",Vector2(490,330),Vector2(230,42),start_chapter_three)
	text_at(app_panel,"Свидание в BIOS",Vector2(30,90),Vector2(690,55),28)
	var dinner_result := "Шеф-повар AMD" if story.get_value("amd_chef_achievement") else "Ужин без технических ингредиентов"
	var friend_result := "План с Артреем готов." if story.get_value("brainstorm_completed") else ("Артрей остаётся на связи." if story.get_value("artbay_intro_seen") else "Артрей прислал сообщение.")
	text_at(app_panel,"Получено: key.txt\nКлючей: 0 · " + dinner_result + "\n" + friend_result + "\n\nСледующий шаг — показать файл ЖБТ.\nГлава 3 доступна по кнопке ниже.",Vector2(30,155),Vector2(690,160),19)
	button_at(app_panel,"В комнату",Vector2(30,330),Vector2(220,42),_close_computer)
	if not story.get_value("artbay_intro_seen"):
		button_at(app_panel,"Прочитать сообщение Артрея",Vector2(280,330),Vector2(440,42),start_artrey)
	elif not story.get_value("brainstorm_completed"):
		button_at(app_panel,"Обсудить план с Артреем",Vector2(280,330),Vector2(440,42),func(): Early.show_brainstorm(self))

func _reset_progress() -> void:
	active_chapter = 0
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
	chapter_one_evidence.clear()
	examined.clear()
	player.position = SPAWN_POSITION
	saved_player_position = player.position
	save_dirty = false

func _save_data() -> Dictionary:
	if mode == "tab_war" and is_instance_valid(tab_war) and tab_war.visible:
		minigame_checkpoint = {"kind":"tab_war","state":tab_war.state.snapshot()}
	if mode == "office_404" and is_instance_valid(office_queue) and office_queue.visible:
		minigame_checkpoint = {"kind":"office_404","state":office_queue.state.snapshot()}
	if mode == "court_trial" and is_instance_valid(court_trial) and court_trial.visible:
		minigame_checkpoint = {"kind":"court_trial","state":court_trial.state.snapshot()}
	var checkpoint := {}
	if dialogue_open and is_instance_valid(vn) and vn.visible and flow != "demo":
		checkpoint = {"flow":flow,"entries":vn.entries,"index":vn.index,"pending_evidence":pending_evidence}
	return {
		"version": 2,
		"active_chapter": active_chapter,
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
		"notebook_page": page,
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
	if saved_game is Dictionary and saved_game.get("kind", "") in ["blender", "brainstorm", "tab_war", "office_404", "court_trial"]:
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
	if version >= 2:
		var position_data = data.get("player_position", {})
		if position_data is Dictionary and position_data.has("x") and position_data.has("y"):
			player.position = Vector2(float(position_data.x), float(position_data.y))
			player.position.x = clampf(player.position.x, 264.0, 696.0)
			player.position.y = clampf(player.position.y, 198.0, 406.0)
	saved_player_position = player.position
	save_dirty = false
	_sync_saved_achievements()
	return true

func _restore_active_chapter(data: Dictionary) -> void:
	# A checkpoint is stronger evidence than a completed chapter, including in old saves.
	var saved_flow := str(dialogue_resume.get("flow", ""))
	var kind := str(minigame_checkpoint.get("kind", ""))
	if saved_flow.begins_with("chapter_five") or kind == "court_trial": active_chapter = 5
	elif saved_flow.begins_with("chapter_four") or kind == "office_404": active_chapter = 4
	elif saved_flow.begins_with("chapter_three") or kind == "tab_war": active_chapter = 3
	elif saved_flow.begins_with("chapter_two") or saved_flow == "artrey_plan_done" or kind == "brainstorm": active_chapter = 2
	elif saved_flow.begins_with("chapter_one"): active_chapter = 1
	elif saved_flow in FLOW: active_chapter = 0
	elif data.get("active_chapter") is float or data.get("active_chapter") is int:
		active_chapter = clampi(int(data.active_chapter),0,5)
	elif story.get_value("chapter_five_complete"): active_chapter = 5
	elif story.get_value("chapter_four_complete"): active_chapter = 4
	elif story.get_value("chapter_three_complete"): active_chapter = 3
	elif story.get_value("grok_date_completed"): active_chapter = 2
	elif chapter_one_stage >= 1: active_chapter = 1
	else: active_chapter = 0
	refresh_goal()

func _read_dialogue_checkpoint(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("entries") is Array: return {}
	var allowed := ["intro","voice","project","blender","blender_training","blender_replay","help","search","complain","prompt","grok","chapter_one_intro","chapter_one_evidence","chapter_one_ending","chapter_two","chapter_two_artrey","chapter_three","chapter_three_intro","chapter_three_outro","chapter_four_intro","chapter_four_outro","chapter_five_intro","chapter_five_outro","artrey_plan_done","room_optional","optional"]
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
	if story.get_value("brainstorm_completed"):
		AchievementManager.unlock_achievement("artbay_brainstorm")

func has_unsaved_progress() -> bool:
	return save_dirty or player.position.distance_to(saved_player_position) > 0.5

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress()


