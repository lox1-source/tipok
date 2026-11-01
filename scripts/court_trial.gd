extends Control
const MiniGameStyle = preload("res://scripts/minigame_skin.gd")

signal checkpoint_changed(data: Dictionary)
signal finished(result: Dictionary)
signal pause_requested

const Model = preload("res://scripts/court_trial_state.gd")
var state = Model.new()
var story_context: Dictionary = {}
var card_buttons: Array[Button] = []
var card_title_labels: Array[Label] = []
var card_detail_labels: Array[Label] = []
var prompt_label: Label
var progress_label: Label
var status_label: Label
var present_button: Button
var tutorial: Control
var tutorial_seen := false
var tutorial_done := false
var tutorial_feedback: Label
var tutorial_continue: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	size = Vector2(960,540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("100f18")
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_label(self,"СУДЬЯ-ПРИНТЕР · РАССМОТРЕНИЕ ДЕЛА",Vector2(32,16),Vector2(730,34),22,Color("e9d6be"))
	_button(self,"Пауза",Vector2(850,18),Vector2(82,30),func(): pause_requested.emit())
	progress_label = _label(self,"",Vector2(38,62),Vector2(880,28),15,Color("cbbbd8"))
	_panel(self,Vector2(32,102),Vector2(896,99),Color("211d2b"))
	prompt_label = _label(self,"",Vector2(54,120),Vector2(850,66),20,Color("f4e8fb"))
	_label(self,"Сопоставь обвинение с тем, что улика действительно доказывает. После двух ошибок будет подсказка.",Vector2(38,211),Vector2(730,28),12,Color("b8b3c2"))
	_button(self,"Как играть?",Vector2(781,209),Vector2(145,27),_show_tutorial)
	for i in range(3):
		var b := Button.new()
		b.position = Vector2(34 + i * 300,253)
		b.size = Vector2(286,128)
		b.text = ""
		b.pressed.connect(func(index: int = i): _select_card(index))
		add_child(b)
		card_buttons.append(b)
		var title := _label(b,"",Vector2(10,10),Vector2(266,40),13,Color("f1e5f5"))
		var detail := _label(b,"",Vector2(10,54),Vector2(266,64),11,Color("d0c4d8"))
		card_title_labels.append(title)
		card_detail_labels.append(detail)
	present_button = _button(self,"Предъявить выбранную улику",Vector2(350,401),Vector2(260,48),_submit)
	status_label = _label(self,"",Vector2(44,464),Vector2(870,42),15,Color("d8c8e4"))
	_build_tutorial()
	_render()
	MiniGameStyle.apply(self, Color("292126"), Color("98735f"), Color("e9d6be"))

func open(snapshot: Dictionary = {}, context: Dictionary = {}) -> void:
	story_context = context.duplicate(true)
	if snapshot.is_empty(): state.reset()
	else: state.restore(snapshot)
	tutorial_seen = bool(snapshot.get("tutorial_seen",false)) or state.round > 0 or not state.selected_card.is_empty()
	tutorial_done = false
	tutorial.visible = not tutorial_seen
	_update_tutorial()
	show()
	_render()
	checkpoint_changed.emit(_snapshot())

func _snapshot() -> Dictionary:
	var data: Dictionary = state.snapshot()
	data["tutorial_seen"] = tutorial_seen
	return data

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if tutorial.visible:
		if event.keycode in [KEY_ESCAPE,KEY_P]: pause_requested.emit()
		elif event.keycode in [KEY_ENTER,KEY_KP_ENTER] and tutorial_done: _finish_tutorial()
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_ESCAPE,KEY_P]:
		pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_1,KEY_2,KEY_3]:
		_select_card(event.keycode - KEY_1)
	elif event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
		_submit()
		get_viewport().set_input_as_handled()

func _select_card(index: int) -> void:
	if index < 0 or index >= 3: return
	var cards: Array = state.current_round().cards
	state.select_card(str(cards[index].id))
	_render()
	checkpoint_changed.emit(_snapshot())

func _submit() -> void:
	state.submit()
	_render()
	checkpoint_changed.emit(_snapshot())
	if state.finished: finished.emit(state.result())

func _build_tutorial() -> void:
	tutorial = Control.new()
	tutorial.name = "CourtPractice"
	tutorial.size = size
	tutorial.z_index = 30
	add_child(tutorial)
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.045,0.03,0.06,0.96)
	tutorial.add_child(shade)
	_label(tutorial,"ТРЕНИРОВКА ПЕРЕД СУДОМ",Vector2(148,78),Vector2(660,42),24,Color("f2debe"))
	_label(tutorial,"Обвинение: «4fr просил помощи только ради ключа». Что покажет весь разговор?",Vector2(148,141),Vector2(664,64),16,Color("eee6f4"))
	_button(tutorial,"Полная переписка",Vector2(148,232),Vector2(315,56),func():
		tutorial_done = true
		_update_tutorial())
	_button(tutorial,"Один файл key.txt",Vector2(497,232),Vector2(315,56),func():
		tutorial_feedback.text = "Файл показывает результат, но не весь разговор. Попробуй другую улику.")
	tutorial_feedback = _label(tutorial,"",Vector2(148,316),Vector2(664,56),15,Color("e8cc9f"))
	tutorial_continue = _button(tutorial,"К настоящему делу",Vector2(343,408),Vector2(275,43),_finish_tutorial)
	_update_tutorial()

func _show_tutorial() -> void:
	tutorial_done = false
	_update_tutorial()
	tutorial.show()

func _update_tutorial() -> void:
	if not is_instance_valid(tutorial_feedback): return
	tutorial_feedback.text = "Верно: целый разговор даёт контекст. Теперь предъявляй улики в настоящем деле." if tutorial_done else "Выбери одну из двух тренировочных улик. Таймера нет."
	tutorial_continue.disabled = not tutorial_done

func _finish_tutorial() -> void:
	if not tutorial_done: return
	tutorial_seen = true
	tutorial.hide()
	checkpoint_changed.emit(_snapshot())

func _render() -> void:
	if not is_instance_valid(prompt_label): return
	if state.finished:
		prompt_label.text = "Дело рассмотрено."
		for b in card_buttons: b.hide()
		present_button.hide()
		status_label.text = "Подготовлены улики: %d из 3 · ошибок: %d" % [state.correct_count,state.total_mistakes]
		return
	var current: Dictionary = state.current_round()
	progress_label.text = "Пункт %d из 3 · принятых улик: %d" % [state.round + 1,state.correct_count]
	prompt_label.text = str(current.title)
	for i in range(3):
		var card: Dictionary = current.cards[i]
		var detail := str(card.detail)
		if card.id == "project_history" and bool(story_context.get("project_ownership_proven",false)):
			detail = "Проверено в Министерстве: первоначальные файлы созданы 4fr."
		elif card.id == "ministry_stamp" and bool(story_context.get("stamp_stolen",false)):
			detail = "Печать украдена: подтверждает нарушение, не авторство."
		elif card.id == "protocol" and bool(story_context.get("secret_protocol",false)):
			detail = "Протокол 0: зарегистрированный ключ — не то же самое, что рабочая дверь."
		card_title_labels[i].text = str(card.title)
		card_detail_labels[i].text = detail
		card_buttons[i].show()
		card_buttons[i].add_theme_stylebox_override("normal",_style(Color("51423d") if state.selected_card == card.id else Color("292431")))
	present_button.show()
	present_button.disabled = state.selected_card == ""
	status_label.text = state.message

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
	box.border_color = Color("62556b")
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	return box
