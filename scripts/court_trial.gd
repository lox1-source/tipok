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
	_label(self,"ВЫБЕРИ ЛУЧШУЮ УЛИКУ · ошибка не портит дело, после двух промахов будет подсказка",Vector2(38,211),Vector2(880,28),13,Color("b8b3c2"))
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
	present_button = _button(self,"Предъявить улику",Vector2(350,401),Vector2(260,48),_submit)
	status_label = _label(self,"",Vector2(44,464),Vector2(870,42),15,Color("d8c8e4"))
	_render()
	MiniGameStyle.apply(self, Color("292126"), Color("98735f"), Color("e9d6be"))

func open(snapshot: Dictionary = {}, context: Dictionary = {}) -> void:
	story_context = context.duplicate(true)
	if snapshot.is_empty(): state.reset()
	else: state.restore(snapshot)
	show()
	_render()
	checkpoint_changed.emit(state.snapshot())

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
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
	checkpoint_changed.emit(state.snapshot())

func _submit() -> void:
	state.submit()
	_render()
	checkpoint_changed.emit(state.snapshot())
	if state.finished: finished.emit(state.result())

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
			detail = "Проверено в Министерстве: первоначальные файлы созданы Гратом."
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
