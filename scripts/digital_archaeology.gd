extends Control

signal checkpoint_changed(data: Dictionary)
signal finished(result: Dictionary)
signal pause_requested

const CLUES := [
	{"id":"prototype", "title":"prototype_room", "body":"Первая тестовая комната. Создана до появления общего доступа."},
	{"id":"manifest", "title":"project_manifest", "body":"В исходном манифесте автор и разработчик — Грат."},
	{"id":"pitch", "title":"artbay_pitch_copy", "body":"Копия проекта для презентации. Дата создания: до согласованного договора."},
	{"id":"metadata", "title":"metadata_diff", "body":"В презентационной копии поле «Автор» изменено на Артрея."},
	{"id":"access", "title":"access_log", "body":"Журнал: Артрей открыл копию до сообщения с разрешением на просмотр."},
	{"id":"chat", "title":"chat_export", "body":"Переписка: Грат согласился лишь на read-only копию позже."}
]
const LINKS := [{"a":"prototype","b":"manifest"},{"a":"pitch","b":"metadata"},{"a":"access","b":"chat"}]

var found: Array[String] = []
var links: Array[String] = []
var selection: Array[String] = []
var errors := 0
var clue_buttons: Array[Button] = []
var status_label: Label
var journal_label: Label
var connect_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	size = Vector2(960,540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("100e18")
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_label("ЦИФРОВОЙ АРХЕОЛОГ · АРХИВ ПРОЕКТА",Vector2(32,14),Vector2(740,36),22,Color("e7d5f1"))
	_button("Пауза",Vector2(850,16),Vector2(82,30),func(): pause_requested.emit())
	_label("Открой записи, затем выбери две связанные улики. Ошибка оставит гипотезу, но ничего не удалит.",Vector2(36,57),Vector2(880,31),14,Color("c7b8d1"))
	for i in range(CLUES.size()):
		var x := 36.0 + float(i % 3) * 300.0
		var y := 106.0 + float(i / 3) * 132.0
		var button := Button.new()
		button.position = Vector2(x,y)
		button.size = Vector2(282,112)
		button.clip_contents = true
		button.clip_text = true
		button.add_theme_font_size_override("font_size",12)
		button.pressed.connect(func(index: int = i): _inspect(index))
		add_child(button)
		clue_buttons.append(button)
		var caption := Label.new()
		caption.name = "Caption"
		caption.position = Vector2(12,10)
		caption.size = Vector2(258,92)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size",12)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)
	journal_label = _label("Найдено источников: 0 / 6\nСвязей подтверждено: 0 / 3",Vector2(42,386),Vector2(360,66),15,Color("d7c7e3"))
	status_label = _label("Сначала открой несколько записей.",Vector2(420,386),Vector2(500,45),14,Color("e5c98f"))
	connect_button = _button("Связать выбранные улики",Vector2(348,451),Vector2(264,42),_connect)
	_render()

func open(snapshot: Dictionary = {}) -> void:
	found.clear()
	links.clear()
	selection.clear()
	errors = 0
	if snapshot.has("found"):
		for id in snapshot.found:
			if id is String and _clue_index(id) >= 0 and not found.has(id): found.append(id)
	if snapshot.has("links"):
		for id in snapshot.links:
			if id is String and _link_index(id) >= 0 and not links.has(id): links.append(id)
	errors = clampi(int(snapshot.get("errors",0)),0,999)
	show()
	_render()
	checkpoint_changed.emit(snapshot())

func snapshot() -> Dictionary:
	return {"found":found.duplicate(),"links":links.duplicate(),"errors":errors}

func _inspect(index: int) -> void:
	if index < 0 or index >= CLUES.size(): return
	var id := str(CLUES[index].id)
	if not found.has(id): found.append(id)
	if selection.size() >= 2 or selection.has(id): selection.clear()
	selection.append(id)
	status_label.text = str(CLUES[index].body)
	_render()
	checkpoint_changed.emit(snapshot())

func _connect() -> void:
	if selection.size() != 2:
		status_label.text = "Выбери ровно два открытых источника."
		return
	var key := _pair_key(selection[0],selection[1])
	var index := _link_index(key)
	if index >= 0:
		if not links.has(key):
			links.append(key)
			status_label.text = "Связь подтверждена источниками. Записал её в граф."
		else:
			status_label.text = "Эта связь уже есть в графе."
	else:
		errors += 1
		status_label.text = "Пока только гипотеза: источники не подтверждают эту связь. Попробуй другую пару."
	selection.clear()
	_render()
	checkpoint_changed.emit(snapshot())
	if links.size() == LINKS.size():
		finished.emit({"evidence":true,"links":links.size(),"errors":errors,"found":found.size()})

func _render() -> void:
	if clue_buttons.size() != CLUES.size(): return
	for i in range(CLUES.size()):
		var clue: Dictionary = CLUES[i]
		var id := str(clue.id)
		var is_found := found.has(id)
		var selected := selection.has(id)
		clue_buttons[i].get_node("Caption").text = ("✓ " if is_found else "◻ ") + str(clue.title) + ("\n\n" + str(clue.body) if is_found else "\n\nОткрыть запись")
		var style := StyleBoxFlat.new()
		style.bg_color = Color("45364e") if selected else (Color("292333") if is_found else Color("1b1923"))
		style.border_color = Color("d4a9ef") if selected else Color("5a4e63")
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(5)
		clue_buttons[i].add_theme_stylebox_override("normal",style)
		clue_buttons[i].add_theme_stylebox_override("hover",style)
	journal_label.text = "Найдено источников: %d / 6\nСвязей подтверждено: %d / 3\nОшибочных гипотез: %d" % [found.size(),links.size(),errors]
	connect_button.disabled = selection.size() != 2

func _pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

func _link_index(key: String) -> int:
	for i in range(LINKS.size()):
		if _pair_key(str(LINKS[i].a),str(LINKS[i].b)) == key: return i
	return -1

func _clue_index(id: String) -> int:
	for i in range(CLUES.size()):
		if str(CLUES[i].id) == id: return i
	return -1

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_P]:
		pause_requested.emit()
		get_viewport().set_input_as_handled()

func _label(value: String, pos: Vector2, area: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = area
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(value: String, pos: Vector2, area: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = area
	button.add_theme_font_size_override("font_size",15)
	button.pressed.connect(callback)
	add_child(button)
	return button

