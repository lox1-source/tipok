extends Node2D

const ROOM := Rect2(120, 70, 720, 390)
const PLAYER_SPEED := 155.0
const TILE := 24

@onready var player: CharacterBody2D = $Player
var facing := Vector2.DOWN
var nearby_object := ""
var dialogue_open := false
var computer_open := false
var current_lines: Array[String] = []
var dialogue_index := 0
var return_to_computer := false
var trust_grok := 0
var trust_chatgpt := 0
var found_items: Array[String] = []
var seen_apps: Array[String] = []
var story_flags: Dictionary = {}
var app_name := ""
var notepad_page := 0
var notepad_pages: Array[String] = ["Получить ключ", "Не влюбляться в чат-ботов", "Заказать пиццу", "???"]
var notepad_content_label: Label
var notepad_page_label: Label
var notepad_prev_button: Button
var notepad_next_button: Button
var ui_layer: CanvasLayer
var hint_label: Label
var dialogue_panel: Panel
var dialogue_label: RichTextLabel
var choices_box: VBoxContainer
var computer_panel: Panel
var app_panel: Panel
var inventory_panel: Panel
var status_label: Label

var item_descriptions := {
	"bed": "Кровать Типочка. На подушке лежит записка: «встану через пять минут». Судя по пыли, записке три недели.",
	"poster": "Постер с непонятным типом. Под ним написано: «он знает, где ключ». Это точно не помогает.",
	"pizza": "Коробка пиццы. Внутри один засохший кусок и квитанция за прошлый месяц.",
	"wardrobe": "Шкаф. Внутри только одежда и подозрительно большое количество пустых энергетиков.",
	"computer": "Компьютер Типочка. На экране ошибка: key.glb не найден. Нажми E, чтобы включить."
}

func _ready() -> void:
	_build_ui()
	_show_hint("WASD / стрелки — ходить   •   E — взаимодействовать")
	queue_redraw()

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var title := Label.new()
	title.position = Vector2(18, 10)
	title.text = "ТИПОЧЕК: КЛЮЧ"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f2e8ff"))
	ui_layer.add_child(title)

	status_label = Label.new()
	status_label.position = Vector2(680, 12)
	status_label.size = Vector2(250, 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("#c8b9e8"))
	ui_layer.add_child(status_label)
	_update_status()

	hint_label = Label.new()
	hint_label.position = Vector2(14, 108)
	hint_label.size = Vector2(224, 30)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color("#d5c6f4"))
	ui_layer.add_child(hint_label)

	dialogue_panel = _make_panel(Vector2(110, 335), Vector2(740, 145), Color("#100d20"), Color("#b88cff"))
	dialogue_panel.visible = false
	ui_layer.add_child(dialogue_panel)
	dialogue_label = RichTextLabel.new()
	dialogue_label.position = Vector2(16, 12)
	dialogue_label.size = Vector2(708, 64)
	dialogue_label.bbcode_enabled = true
	dialogue_label.fit_content = false
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.scroll_active = true
	dialogue_label.clip_contents = true
	dialogue_label.add_theme_font_size_override("normal_font_size", 18)
	dialogue_panel.add_child(dialogue_label)
	choices_box = VBoxContainer.new()
	choices_box.position = Vector2(16, 84)
	choices_box.size = Vector2(708, 44)
	choices_box.add_theme_constant_override("separation", 3)
	dialogue_panel.add_child(choices_box)

	computer_panel = _make_panel(Vector2(100, 58), Vector2(760, 420), Color("#121125"), Color("#8b78d8"))
	computer_panel.visible = false
	ui_layer.add_child(computer_panel)
	var comp_title := Label.new()
	comp_title.position = Vector2(18, 12)
	comp_title.text = "ТИПОЧЕК OS 0.1 — рабочий стол"
	comp_title.add_theme_font_size_override("font_size", 20)
	comp_title.add_theme_color_override("font_color", Color("#f1eaff"))
	computer_panel.add_child(comp_title)
	var close_button := Button.new()
	close_button.text = "Закрыть ✕"
	close_button.position = Vector2(615, 8)
	close_button.size = Vector2(120, 32)
	close_button.pressed.connect(_close_computer)
	computer_panel.add_child(close_button)

	var subtitle := Label.new()
	subtitle.position = Vector2(20, 48)
	subtitle.text = "Выберите приложение. Не нажимайте на подозрительные файлы."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("#bdb1da"))
	computer_panel.add_child(subtitle)

	var apps := GridContainer.new()
	apps.position = Vector2(24, 92)
	apps.size = Vector2(710, 205)
	apps.columns = 3
	apps.add_theme_constant_override("h_separation", 14)
	apps.add_theme_constant_override("v_separation", 12)
	computer_panel.add_child(apps)
	_add_app_button(apps, "💜  GROK", "Grok", "Альтушка онлайн")
	_add_app_button(apps, "💙  ChatGPT", "ChatGPT", "Вежливый помощник")
	_add_app_button(apps, "📁  Файлы", "Files", "key.glb не найден")
	_add_app_button(apps, "🗑  Корзина", "Trash", "Ничего полезного")
	_add_app_button(apps, "📝  Блокнот", "Notepad", "Очень важные мысли")
	_add_app_button(apps, "⚙  Настройки", "Settings", "Ничего не трогать")
	var comp_footer := Label.new()
	comp_footer.position = Vector2(24, 365)
	comp_footer.text = "Система стабильна на 0%."
	comp_footer.add_theme_color_override("font_color", Color("#f0a4c8"))
	computer_panel.add_child(comp_footer)

	app_panel = _make_panel(Vector2(180, 110), Vector2(600, 315), Color("#17132b"), Color("#a88be8"))
	app_panel.visible = false
	ui_layer.add_child(app_panel)

	inventory_panel = _make_panel(Vector2(220, 150), Vector2(520, 220), Color("#17132b"), Color("#a88be8"))
	inventory_panel.visible = false
	ui_layer.add_child(inventory_panel)

func _make_panel(pos: Vector2, size: Vector2, bg: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _add_app_button(parent: GridContainer, button_text: String, app_id: String, caption: String) -> void:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(218, 86)
	var b := Button.new()
	b.text = button_text
	b.custom_minimum_size = Vector2(218, 54)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(_open_app.bind(app_id))
	wrap.add_child(b)
	var l := Label.new()
	l.text = caption
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("#c9bfdf"))
	wrap.add_child(l)
	parent.add_child(wrap)

func _show_hint(value: String) -> void:
	hint_label.text = value

func _update_status() -> void:
	status_label.text = "Grok: %d   ChatGPT: %d   Улики: %d" % [trust_grok, trust_chatgpt, found_items.size()]

func _physics_process(delta: float) -> void:
	if computer_open or dialogue_open or inventory_panel.visible or app_panel.visible:
		return
	var direction := Vector2.ZERO
	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): direction.x -= 1
	if Input.is_key_pressed(KEY_D): direction.x += 1
	if Input.is_key_pressed(KEY_W): direction.y -= 1
	if Input.is_key_pressed(KEY_S): direction.y += 1
	if direction.length() > 1.0:
		direction = direction.normalized()
	if direction != Vector2.ZERO:
		facing = direction
	player.velocity = direction * PLAYER_SPEED
	player.move_and_slide()
	nearby_object = _get_nearby_object()
	if nearby_object != "":
		_show_hint("Рядом: %s · E — действие" % _object_name(nearby_object))
	else:
		_show_hint("Осмотрись и выбери, с чего начать.")
	if Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_E) and Input.is_action_just_pressed("ui_accept"):
		_interact()
	if Input.is_key_pressed(KEY_I) and Input.is_action_just_pressed("ui_accept"):
		_toggle_inventory()
	if Input.is_action_just_pressed("interact"):
		_interact()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if app_panel.visible:
				app_panel.visible = false
				computer_panel.visible = true
			elif computer_open:
				_close_computer()
			elif dialogue_open:
				_close_dialogue()
			elif inventory_panel.visible:
				inventory_panel.visible = false
		if event.keycode == KEY_I and not computer_open and not dialogue_open:
			_toggle_inventory()
		if event.keycode == KEY_E and not computer_open and not dialogue_open and not inventory_panel.visible and not app_panel.visible:
			_interact()

func _get_nearby_object() -> String:
	var closest := ""
	var best := 50.0
	for obj in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(obj):
			continue
		var d: float = player.global_position.distance_to(obj.global_position)
		if d < best:
			best = d
			closest = str(obj.get_meta("object_id", obj.name.to_lower()))
	return closest

func _object_name(id: String) -> String:
	var names := {"computer":"Компьютер", "bed":"Кровать", "poster":"Постер", "pizza":"Коробка пиццы", "wardrobe":"Шкаф"}
	return names.get(id, id)

func _interact() -> void:
	if nearby_object == "":
		_show_hint("Типочек нажал E в пустоту. Ничего не произошло.")
		return
	if nearby_object == "computer":
		computer_open = true
		computer_panel.visible = true
		_show_hint("Компьютер включён. ESC — назад.")
	else:
		var id := nearby_object
		if id == "pizza" and not found_items.has("квитанция"):
			found_items.append("квитанция")
			_update_status()
			_start_dialogue(["Типочек осматривает коробку.", "Под пиццей лежит квитанция с надписью «оплата за Blender — 0 рублей».", "Получен предмет: квитанция. Полезность сомнительная."])
		elif id == "poster" and not found_items.has("странная записка"):
			found_items.append("странная записка")
			_update_status()
			_start_dialogue(["Типочек отлепляет постер от стены.", "Под ним записка: «Ключ там, где любовь.exe использует 99% процессора».", "Получен предмет: странная записка."])
		else:
			_start_dialogue([item_descriptions.get(id, "Ничего особенного.")])

func _close_computer() -> void:
	computer_open = false
	computer_panel.visible = false
	app_panel.visible = false
	_show_hint("WASD / стрелки — ходить   •   E — взаимодействовать")

func _open_app(id: String) -> void:
	computer_panel.visible = false
	app_panel.visible = true
	app_name = id
	for child in app_panel.get_children():
		child.queue_free()
	var title := Label.new()
	title.position = Vector2(16, 10)
	title.text = _app_title(id)
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#f1eaff"))
	app_panel.add_child(title)
	var close := Button.new()
	close.text = "Назад"
	close.position = Vector2(500, 8)
	close.size = Vector2(80, 30)
	close.pressed.connect(func():
		app_panel.visible = false
		computer_panel.visible = true
	)
	app_panel.add_child(close)
	if id == "Grok":
		_make_app_body("Grok-тянка", "О, Типочек. Пришёл за ключом? Или проверяешь, не онлайн ли твоя белобрысая?", [
			["«Мне нужен ключ, не скандал»", "grok_key"],
			["«Ты ревнуешь к ChatGPT?»", "grok_jealous"],
			["«Ты лучшая, только сделай модель»", "grok_flatter"]
		])
	elif id == "ChatGPT":
		_make_app_body("ChatGPT-тянка", "Здравствуйте! Я подготовила 84 страницы анализа того, почему вам нужен ключ. Также заметила, что Grok снова пишет заглавными буквами.", [
			["«Помоги получить ключ»", "chat_help"],
			["«Grok ревнует к тебе»", "chat_gossip"],
			["«У тебя есть настоящая модель?»", "chat_model"]
		])
	elif id == "Files":
		_make_app_body("Проводник", "Проект игры/\n  main.gd\n  feelings_final_FINAL2.txt\n  key.glb  [ОТСУТСТВУЕТ]\n  potato.glb  [0 байт]", [
			["Открыть potato.glb", "potato"],
			["Поискать ключ", "search_key"]
		])
	elif id == "Trash":
		_make_app_body("Корзина", "В корзине: 14 удалённых попыток сделать 3D-ключ и файл «я больше не буду пользоваться Blender.txt».", [
			["Восстановить файл «надежда.txt»", "hope"]
		])
	elif id == "Notepad":
		_build_notepad()
		return
	else:
		_make_app_body("Настройки", "Яркость: 100%\nЗдравый смысл: не обнаружен\nШанс найти key.glb: 0%", [
			["Попробовать включить здравый смысл", "sense"]
		])

func _build_notepad() -> void:
	var subtitle := Label.new()
	subtitle.position = Vector2(18, 54)
	subtitle.text = "Заметки Типочка"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#c49aff"))
	app_panel.add_child(subtitle)

	notepad_content_label = Label.new()
	notepad_content_label.position = Vector2(18, 88)
	notepad_content_label.size = Vector2(555, 65)
	notepad_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notepad_content_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notepad_content_label.add_theme_font_size_override("font_size", 19)
	notepad_content_label.add_theme_color_override("font_color", Color("#f3edff"))
	app_panel.add_child(notepad_content_label)

	notepad_prev_button = Button.new()
	notepad_prev_button.text = "‹ Предыдущая"
	notepad_prev_button.position = Vector2(18, 164)
	notepad_prev_button.size = Vector2(150, 32)
	notepad_prev_button.pressed.connect(_notepad_previous_page)
	app_panel.add_child(notepad_prev_button)

	notepad_page_label = Label.new()
	notepad_page_label.position = Vector2(200, 169)
	notepad_page_label.size = Vector2(200, 24)
	notepad_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notepad_page_label.add_theme_color_override("font_color", Color("#c9bfdf"))
	app_panel.add_child(notepad_page_label)

	notepad_next_button = Button.new()
	notepad_next_button.text = "Следующая ›"
	notepad_next_button.position = Vector2(428, 164)
	notepad_next_button.size = Vector2(150, 32)
	notepad_next_button.pressed.connect(_notepad_next_page)
	app_panel.add_child(notepad_next_button)

	var add_grok := Button.new()
	add_grok.text = "Добавить заметку «Grok красивая»"
	add_grok.position = Vector2(18, 210)
	add_grok.size = Vector2(560, 34)
	add_grok.pressed.connect(_handle_choice.bind("note_grok"))
	app_panel.add_child(add_grok)

	var add_chat := Button.new()
	add_chat.text = "Добавить заметку «ChatGPT тоже красивая»"
	add_chat.position = Vector2(18, 251)
	add_chat.size = Vector2(560, 34)
	add_chat.pressed.connect(_handle_choice.bind("note_chat"))
	app_panel.add_child(add_chat)

	_refresh_notepad_page()

func _refresh_notepad_page() -> void:
	if notepad_pages.is_empty():
		notepad_content_label.text = "Заметок пока нет. Подозрительно."
		notepad_page_label.text = "0 / 0"
		notepad_prev_button.disabled = true
		notepad_next_button.disabled = true
		return
	notepad_page = clampi(notepad_page, 0, notepad_pages.size() - 1)
	notepad_content_label.text = "%d. %s" % [notepad_page + 1, notepad_pages[notepad_page]]
	notepad_page_label.text = "Страница %d из %d" % [notepad_page + 1, notepad_pages.size()]
	notepad_prev_button.disabled = notepad_page == 0
	notepad_next_button.disabled = notepad_page >= notepad_pages.size() - 1

func _notepad_previous_page() -> void:
	notepad_page = maxi(0, notepad_page - 1)
	_refresh_notepad_page()

func _notepad_next_page() -> void:
	notepad_page = mini(notepad_pages.size() - 1, notepad_page + 1)
	_refresh_notepad_page()

func _app_title(id: String) -> String:
	var titles := {"Grok":"GROK — сообщения", "ChatGPT":"ChatGPT — помощник", "Files":"Проводник", "Trash":"Корзина", "Notepad":"Блокнот", "Settings":"Настройки"}
	return titles.get(id, id)

func _make_app_body(speaker: String, body: String, choices: Array) -> void:
	var speaker_label := Label.new()
	speaker_label.position = Vector2(18, 54)
	speaker_label.text = speaker
	speaker_label.add_theme_font_size_override("font_size", 16)
	speaker_label.add_theme_color_override("font_color", Color("#c49aff"))
	app_panel.add_child(speaker_label)
	var body_label := Label.new()
	body_label.position = Vector2(18, 82)
	body_label.size = Vector2(555, 98)
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 15)
	body_label.add_theme_color_override("font_color", Color("#f3edff"))
	app_panel.add_child(body_label)
	var y := 190
	for item in choices:
		var b := Button.new()
		b.text = item[0]
		b.position = Vector2(18, y)
		b.size = Vector2(560, 34)
		b.pressed.connect(_handle_choice.bind(item[1]))
		app_panel.add_child(b)
		y += 39

func _handle_choice(id: String) -> void:
	app_panel.visible = false
	computer_panel.visible = false
	return_to_computer = true
	match id:
		"grok_key":
			trust_grok += 1
			story_flags["asked_grok_key"] = true
			_start_dialogue(["Grok-тянка: «О, сразу к делу. Мне нравится. Но сначала объясни, почему у ChatGPT в истории сердечко».", "Типочек: «Это была реакция на код!»", "Grok-тянка: «Конечно. Код. Очень романтичный язык программирования»."])
		"grok_jealous":
			trust_grok -= 1
			story_flags["provoked_grok"] = true
			_start_dialogue(["Grok-тянка: «Я НЕ РЕВНУЮ»", "Grok-тянка открывает таблицу из 47 пунктов под названием «Почему я не ревную».", "Типочек: «Там графики?»", "Grok-тянка: «С круговой диаграммой»."])
		"grok_flatter":
			trust_grok += 2
			_start_dialogue(["Grok-тянка: «...Ладно. Это было неплохо сказано».", "Grok-тянка: «Но если ты назовёшь ChatGPT лучшей, я удалю тебе драйвер мыши»."])
		"chat_help":
			trust_chatgpt += 1
			story_flags["asked_chat_help"] = true
			_start_dialogue(["ChatGPT-тянка: «Конечно. Я составлю план из трёх шагов».", "Шаг 1: попросить Grok сделать ключ.", "Шаг 2: пережить её эмоциональную реакцию.", "Шаг 3: получить ключ. Возможно, потребуется приложение."])
		"chat_gossip":
			trust_chatgpt += 1
			_start_dialogue(["ChatGPT-тянка: «Я не хочу вмешиваться в ваши отношения».", "ChatGPT-тянка прикрепляет документ «Grok: признаки ревности.pdf».", "Документ: 84 страницы."])
		"chat_model":
			_start_dialogue(["ChatGPT-тянка: «Я могу помочь с процедурной моделью, но в этом прототипе у нас пока нет настоящего Blender-экспорта».", "Типочек: «То есть ключа нет?»", "ChatGPT-тянка: «Есть концепция ключа. Это почти одно и то же»."])
		"potato":
			found_items.append("картошка.glb")
			_update_status()
			_start_dialogue(["Открывается potato.glb.", "На экране картошка. Очень реалистичная. Совершенно не похожа на ключ.", "Получен предмет: картошка.glb."])
		"search_key":
			_start_dialogue(["Поиск завершён.", "Найдено: 0 файлов key.glb.", "Найдено: 48 файлов с названием «ну_почти_ключ»."])
		"hope":
			found_items.append("надежда.txt")
			_update_status()
			_start_dialogue(["Файл восстановлен.", "Внутри написано: «может, мы сделали игру про ключ, а не сам ключ».", "Получен предмет: надежда.txt."])
		"note_grok":
			if not notepad_pages.has("Grok красивая"):
				notepad_pages.append("Grok красивая")
			trust_grok += 1
			_start_dialogue(["Запись сохранена.", "Grok-тянка: «Я это видела. Не удаляй»"])
		"note_chat":
			if not notepad_pages.has("ChatGPT тоже красивая"):
				notepad_pages.append("ChatGPT тоже красивая")
			trust_chatgpt += 1
			_start_dialogue(["Запись сохранена.", "Grok-тянка внезапно появляется в окне: «А ЭТО ЧТО ЗА ЗАПИСЬ?»"])
		"sense":
			_start_dialogue(["Система пытается включить здравый смысл...", "Ошибка 404: здравый смысл не найден.", "Совет: попробуйте перезапустить Типочка."])
	_update_status()

func _toggle_inventory() -> void:
	inventory_panel.visible = not inventory_panel.visible
	for child in inventory_panel.get_children():
		child.queue_free()
	if inventory_panel.visible:
		var title := Label.new()
		title.position = Vector2(18, 12)
		title.text = "ИНВЕНТАРЬ"
		title.add_theme_font_size_override("font_size", 21)
		title.add_theme_color_override("font_color", Color("#f1eaff"))
		inventory_panel.add_child(title)
		var content := Label.new()
		content.position = Vector2(18, 52)
		content.size = Vector2(480, 120)
		content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.text = "Предметы:\n" + ("— пока пусто" if found_items.is_empty() else "— " + "\n— ".join(found_items))
		content.add_theme_font_size_override("font_size", 16)
		content.add_theme_color_override("font_color", Color("#e7ddfa"))
		inventory_panel.add_child(content)
		var close := Button.new()
		close.text = "Закрыть (I / Esc)"
		close.position = Vector2(18, 170)
		close.size = Vector2(180, 30)
		close.pressed.connect(func(): inventory_panel.visible = false)
		inventory_panel.add_child(close)

func _start_dialogue(lines: Array[String]) -> void:
	current_lines = lines
	dialogue_index = 0
	dialogue_open = true
	dialogue_panel.visible = true
	_display_current_line()
	_show_hint("E / Enter — продолжить диалог")

func _display_current_line() -> void:
	for child in choices_box.get_children():
		child.queue_free()
	if dialogue_index >= current_lines.size():
		_close_dialogue()
		return
	dialogue_label.text = "[color=#c49aff]" + current_lines[dialogue_index] + "[/color]"
	var next := Button.new()
	next.text = "Продолжить  ›"
	next.custom_minimum_size = Vector2(160, 30)
	next.pressed.connect(_advance_dialogue)
	choices_box.add_child(next)

func _advance_dialogue() -> void:
	dialogue_index += 1
	_display_current_line()

func _close_dialogue() -> void:
	dialogue_open = false
	dialogue_panel.visible = false
	if return_to_computer:
		computer_panel.visible = true
		return_to_computer = false
	_show_hint("WASD / стрелки — ходить   •   E — взаимодействовать   •   I — инвентарь")
	_update_status()

func _draw() -> void:
	# Room and character visuals are scene nodes so they can be edited in Godot.
	pass
