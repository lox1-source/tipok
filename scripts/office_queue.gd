extends Control
const MiniGameStyle = preload("res://scripts/minigame_skin.gd")

signal checkpoint_changed(data: Dictionary)
signal finished(result: Dictionary)
signal pause_requested

const Model = preload("res://scripts/office_queue_state.gd")
var state = Model.new()
var ticket_buttons: Array[Button] = []
var document_buttons: Dictionary = {}
var window_buttons: Dictionary = {}
var info_label: Label
var case_detail_label: Label
var result_panel: Control
var tutorial_panel: Control
var result_summary: Label
var save_clock := 0.0
var steal_stamp := false
var tutorial_step := 0
var tutorial_feedback: Label
var tutorial_buttons: Array[Button] = []
var tutorial_continue: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	size = Vector2(960,540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("111018")
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_label(self,"МИНИСТЕРСТВО КЛЮЧЕВЫХ ДЕЛ · ОКОШКО 404",Vector2(32,14),Vector2(740,34),22,Color("f3d7ab"))
	_button(self,"Пауза",Vector2(850,16),Vector2(82,30),func(): pause_requested.emit())
	_label(self,"Всего три дела · каждый талон решается одним документом в одном окне",Vector2(34,51),Vector2(700,25),14,Color("b8b3c2"))
	_button(self,"Как играть?",Vector2(780,51),Vector2(145,27),_show_tutorial)
	for i in range(Model.CASES.size()):
		var b := Button.new()
		b.position = Vector2(150 + i * 220,86)
		b.size = Vector2(200,91)
		b.add_theme_font_size_override("font_size",13)
		b.pressed.connect(func(index: int = i): _select_ticket(index))
		add_child(b)
		ticket_buttons.append(b)
	case_detail_label = _label(self,"",Vector2(42,179),Vector2(876,22),13,Color("f0dba9"))
	_panel(self,Vector2(32,204),Vector2(896,82),Color("201c2a"))
	_label(self,"ДОКУМЕНТ · выбери один",Vector2(44,208),Vector2(300,20),12,Color("d7c5e8"))
	var doc_ids := ["error","key_txt","history"]
	for i in range(doc_ids.size()):
		var id: String = doc_ids[i]
		var b := Button.new()
		b.position = Vector2(180 + i * 210,239)
		b.size = Vector2(180,39)
		b.add_theme_font_size_override("font_size",12)
		b.pressed.connect(func(doc: String = id): _toggle_doc(doc))
		add_child(b)
		document_buttons[id] = b
	_panel(self,Vector2(32,294),Vector2(896,119),Color("1a2026"))
	_label(self,"ВЫБЕРИ ОКНО · на кнопке указаны его требования",Vector2(44,298),Vector2(580,20),12,Color("a9d6d0"))
	var windows := [
		{"id":"intake","title":"Окно 1","rule":"Скрин ERROR сюда"},
		{"id":"review","title":"Окно 2","rule":"key.txt сюда"},
		{"id":"permit","title":"Окно 3","rule":"История сюда"}
	]
	for i in range(windows.size()):
		var item: Dictionary = windows[i]
		var b := Button.new()
		b.position = Vector2(44 + i * 222,326)
		b.size = Vector2(207,51)
		b.text = item.title + "\n" + item.rule
		b.add_theme_font_size_override("font_size",12)
		b.pressed.connect(func(id: String = item.id): _submit(id))
		add_child(b)
		window_buttons[item.id] = b
	var archive := Button.new()
	archive.name = "ArchiveButton"
	archive.position = Vector2(710,326)
	archive.size = Vector2(204,51)
	archive.text = "Осмотреть архив (необязательно)"
	archive.add_theme_font_size_override("font_size",12)
	archive.pressed.connect(_inspect_archive)
	add_child(archive)
	_panel(self,Vector2(32,422),Vector2(896,74),Color("201c2a"))
	info_label = _label(self,"",Vector2(46,430),Vector2(860,57),14,Color("eee5fa"))
	_build_result()
	_build_tutorial()
	_render()
	MiniGameStyle.apply(self, Color("2b2027"), Color("a17b59"), Color("f3d7ab"))

func open(snapshot: Dictionary = {}) -> void:
	if snapshot.is_empty(): state.reset()
	else: state.restore(snapshot)
	steal_stamp = false
	save_clock = 0.0
	result_panel.hide()
	tutorial_step = 0
	tutorial_panel.visible = not state.tutorial_seen
	_update_tutorial()
	show()
	_render()
	if state.tutorial_seen: checkpoint_changed.emit(state.snapshot())

func _process(delta: float) -> void:
	if not visible or state.finished: return
	save_clock += delta
	if save_clock >= 2.0:
		save_clock = 0.0
		checkpoint_changed.emit(state.snapshot())

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if tutorial_panel.visible:
		if event.keycode in [KEY_ESCAPE,KEY_P]: pause_requested.emit()
		elif event.keycode in [KEY_ENTER,KEY_KP_ENTER]: _start_tutorial()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
		pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
		_select_ticket(event.keycode - KEY_1)
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_submit("intake" if state.selected == 0 else ("review" if state.selected in [1,2] else "permit"))

func _select_ticket(index: int) -> void:
	state.select_ticket(index)
	_render()

func _toggle_doc(id: String) -> void:
	state.toggle_document(id)
	_render()

func _submit(window_id: String) -> void:
	state.submit(window_id)
	_render()
	checkpoint_changed.emit(state.snapshot())

func _inspect_archive() -> void:
	if state.inspect_archive():
		_render()
		checkpoint_changed.emit(state.snapshot())

func _render() -> void:
	if ticket_buttons.is_empty(): return
	for i in range(ticket_buttons.size()):
		var ticket: Dictionary = state.tickets[i]
		var status := "ЖДЁТ ТЕБЯ" if ticket.status == "waiting" else "ПРИНЯТО ✓"
		ticket_buttons[i].text = "%s\n%s\n%s" % [ticket.title,status,"✓" if i == state.selected and ticket.status == "waiting" else ""]
		ticket_buttons[i].disabled = ticket.status != "waiting"
		var color := Color("453445") if i == state.selected and ticket.status == "waiting" else (Color("263b35") if ticket.status == "approved" else (Color("30282c") if ticket.status == "lost" else Color("282431")))
		ticket_buttons[i].add_theme_stylebox_override("normal",_style(color))
	for id in document_buttons:
		var b: Button = document_buttons[id]
		var available: bool = id in state.available_documents()
		b.disabled = not available
		b.text = Model.DOCUMENT_LABELS[id]
		if state.selected_documents.has(id): b.text = "✓ " + b.text
		b.add_theme_stylebox_override("normal",_style(Color("65513a") if state.selected_documents.has(id) else Color("302b38")))
	var ticket: Dictionary = state.tickets[state.selected]
	case_detail_label.text = "Требование: " + str(ticket.request)
	info_label.text = "Принято: %d / 3 · Ошибки: %d\n%s\nПротокол 0: %s" % [state.approved,state.wrong_attempts,state.message,"найден" if state.protocol_found else "не найден"]
	for id in window_buttons:
		window_buttons[id].disabled = state.finished or ticket.status != "waiting"
	if has_node("ArchiveButton"):
		get_node("ArchiveButton").disabled = state.protocol_found or state.finished
	if state.finished:
		result_panel.show()
		_render_result()

func _build_result() -> void:
	result_panel = Control.new()
	result_panel.name = "ResultPanel"
	result_panel.position = Vector2(0,0)
	result_panel.size = size
	result_panel.z_index = 20
	result_panel.hide()
	add_child(result_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.035,0.025,0.05,0.92)
	shade.size = size
	result_panel.add_child(shade)
	_label(result_panel,"ВИЗИТ В МИНИСТЕРСТВО ЗАВЕРШЁН",Vector2(180,139),Vector2(620,42),24,Color("f3d7ab"))
	_label(result_panel,"Три дела решены. Теперь выбери: получить разрешение, уйти или нарушить правила.",Vector2(150,197),Vector2(680,45),16,Color("e5ddec"))
	_button(result_panel,"Получить печать",Vector2(100,285),Vector2(220,48),func(): _finish("legal"))
	_button(result_panel,"Уйти с отказом",Vector2(370,285),Vector2(220,48),func(): _finish("leave"))
	_button(result_panel,"Украсть печать",Vector2(640,285),Vector2(220,48),func(): _finish("steal"))

func _build_tutorial() -> void:
	tutorial_panel = Control.new()
	tutorial_panel.name = "TutorialPanel"
	tutorial_panel.size = size
	tutorial_panel.z_index = 30
	tutorial_panel.visible = false
	add_child(tutorial_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.035,0.025,0.05,0.94)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_panel.add_child(shade)
	_panel(tutorial_panel,Vector2(104,66),Vector2(752,406),Color("211c2a"))
	_label(tutorial_panel,"ПОПРОБУЙ НА ТРЕНИРОВОЧНОМ ТАЛОНЕ",Vector2(142,87),Vector2(660,38),22,Color("f3d7ab"))
	_label(tutorial_panel,"Тут нет таймера и ошибок. Сначала выбери талон, затем документ и окно.",Vector2(142,137),Vector2(670,45),14,Color("e5ddec"))
	tutorial_feedback = _label(tutorial_panel,"",Vector2(142,194),Vector2(670,46),15,Color("f0dba9"))
	tutorial_buttons.append(_button(tutorial_panel,"Талон · ключ отсутствует",Vector2(142,254),Vector2(210,52),func(): _tutorial_action(0)))
	tutorial_buttons.append(_button(tutorial_panel,"Документ · скрин ERROR",Vector2(375,254),Vector2(210,52),func(): _tutorial_action(1)))
	tutorial_buttons.append(_button(tutorial_panel,"Окно 1 · принять",Vector2(608,254),Vector2(210,52),func(): _tutorial_action(2)))
	_label(tutorial_panel,"В настоящей очереди три дела. Неподходящий документ можно заменить; архив с Протоколом 0 необязателен.",Vector2(142,332),Vector2(670,55),13,Color("c9bfd5"))
	tutorial_continue = _button(tutorial_panel,"Перейти к очереди",Vector2(350,410),Vector2(260,44),_start_tutorial)

func _show_tutorial() -> void:
	tutorial_step = 0
	_update_tutorial()
	tutorial_panel.show()

func _tutorial_action(index: int) -> void:
	if index != tutorial_step:
		tutorial_feedback.text = "Сначала " + ["выбери талон.","приложи скрин ERROR.","подай его в Окно 1."][tutorial_step]
		return
	tutorial_step += 1
	_update_tutorial()

func _update_tutorial() -> void:
	if not is_instance_valid(tutorial_feedback): return
	tutorial_feedback.text = ["Шаг 1: нажми на тренировочный талон.","Шаг 2: выбери подходящий документ.","Шаг 3: подай документ в Окно 1.","Верно! Талон принят. Теперь попробуй три настоящих дела."][tutorial_step]
	for i in range(tutorial_buttons.size()): tutorial_buttons[i].disabled = i < tutorial_step
	tutorial_continue.disabled = tutorial_step < 3

func _start_tutorial() -> void:
	if tutorial_step < 3: return
	state.tutorial_seen = true
	tutorial_panel.hide()
	checkpoint_changed.emit(state.snapshot())

func _render_result() -> void:
	if not is_instance_valid(result_panel): return
	if result_summary == null:
		result_summary = _label(result_panel,"",Vector2(185,235),Vector2(620,30),14,Color("b9d7c8"))
		result_summary.name = "Summary"
	result_summary.text = "Принято дел: %d / 3 · ошибок: %d · архив: %s" % [state.approved,state.wrong_attempts,"осмотрен" if state.protocol_found else "не осмотрен"]

func _finish(outcome: String) -> void:
	steal_stamp = outcome == "steal"
	var data: Dictionary = state.result(outcome)
	finished.emit(data)

func _label(parent: Node, text: String, pos: Vector2, area: Vector2, font: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = area
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, pos: Vector2, area: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = area
	button.add_theme_font_size_override("font_size",15)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _panel(parent: Node, pos: Vector2, area: Vector2, color: Color) -> void:
	var panel := Panel.new()
	panel.position = pos
	panel.size = area
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",_style(color))
	parent.add_child(panel)

func _style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("594c62")
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box
