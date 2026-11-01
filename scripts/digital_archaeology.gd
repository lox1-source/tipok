extends Control
const MiniGameStyle = preload("res://scripts/minigame_skin.gd")

signal checkpoint_changed(data: Dictionary)
signal finished(result: Dictionary)
signal pause_requested

const CLUES := [
	{"id":"prototype", "title":"Комната · v0.1", "body":"Ранняя комната 4fr: дверь уже движется, но всё ещё вылетает за стену. Файл создан до общего доступа."},
	{"id":"manifest", "title":"Автор · v0.1", "body":"В исходном файле проекта автор — 4fr. Рядом три его попытки исправить дверь."},
	{"id":"pitch", "title":"Питч · v0.2", "body":"Артбей подготовил план показа и список игровых пабликов. Это его работа, но не создание игры."},
	{"id":"metadata", "title":"Правка автора", "body":"В копии для презентации поле «Автор» изменили с 4fr на Артбея. Исходная комната та же."},
	{"id":"access", "title":"История доступа", "body":"Артбей открыл копию для питча раньше, чем 4fr разрешил просмотр. Время записано в истории файлов."},
	{"id":"chat", "title":"Сообщение 4fr", "body":"4fr позже согласился показать копию только для чтения. Разрешения менять автора в переписке нет."}
]
const LINKS := [{"a":"prototype","b":"manifest"},{"a":"pitch","b":"metadata"},{"a":"access","b":"chat"}]
const GROUP_TITLES := ["1 · КТО СОЗДАЛ ПРОТОТИП", "2 · КТО ЧТО ДОБАВИЛ", "3 · БЫЛО ЛИ РАЗРЕШЕНИЕ"]

var found: Array[String] = []
var links: Array[String] = []
var selection: Array[String] = []
var optional_seen: Array[String] = []
var errors := 0
var companion := "alone"
var access_shared := false
var grok_trust := false
var grok_conflict := false
var jbt_trust := false
var tutorial_seen := false
var clue_buttons: Array[Button] = []
var group_header_labels: Array[Label] = []
var status_label: Label
var journal_label: Label
var nearby_label: Label
var connect_button: Button
var explorer: AnimatedSprite2D
var explorer_pos := Vector2(330,265)
const EXPLORER_MIN := Vector2(45,130)
const EXPLORER_MAX := Vector2(590,392)
const POINTS := [Vector2(110,190),Vector2(285,190),Vector2(470,190),Vector2(110,365),Vector2(285,365),Vector2(470,365)]
const LOCATION_NAMES := ["Первая комната", "Старый манифест", "Копия питча", "Разница версий", "Журнал доступа", "Сохранённый чат"]
const OPTIONAL_POINTS := [
	{"id":"door", "point":Vector2(552,165), "text":"На двери «СДЕЛАТЬ ПОТОМ». Рядом три заметки о починке. 4fr: «Я говорил, что надоело. А сам трижды возвращался»."},
	{"id":"abandoned", "point":Vector2(552,365), "text":"Забытый персонаж: «Привет». Других реплик нет. 4fr: «Ты всё ещё здесь. В следующий раз допишу ответ»."}
]
const FLOOR = preload("res://assets/sprites/room/environment_floor.png")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	size = Vector2(960,540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0,0,0,0)
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_label("СТАРЫЕ ПРОЕКТЫ · НЕДОДЕЛАННЫЙ МИР",Vector2(32,14),Vector2(690,36),22,Color("e7d5f1"))
	_button("Как искать?",Vector2(730,16),Vector2(110,30),_show_help)
	_button("Пауза",Vector2(850,16),Vector2(82,30),func(): pause_requested.emit())
	_label("Найди раннюю комнату и историю копии · WASD / стрелки — идти · E — осмотреть",Vector2(36,57),Vector2(590,31),14,Color("c7b8d1"))
	_label("НАЙДЕННЫЕ ИСТОЧНИКИ",Vector2(642,70),Vector2(280,22),13,Color("e1c9a4"))
	_label("Нажми на карточки, чтобы раскрыть две улики",Vector2(642,88),Vector2(290,17),9,Color("c7b8d1"))
	for i in range(POINTS.size()):
		var marker := _label(LOCATION_NAMES[i],POINTS[i]+Vector2(-55,8),Vector2(110,36),10,Color("e1c9a4"))
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var door_note := _label("СДЕЛАТЬ\nПОТОМ",Vector2(536,144),Vector2(37,30),7,Color("f1d2b0"))
	door_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label("NPC?",Vector2(527,372),Vector2(55,20),10,Color("b8c5ce"))
	for i in range(CLUES.size()):
		var x := 638.0
		var group_index := floori(float(i) / 2.0)
		var item_index := i % 2
		if item_index == 0:
			group_header_labels.append(_label(str(GROUP_TITLES[group_index]),Vector2(642,105.0 + group_index * 94.0),Vector2(280,16),9,Color("e1c9a4")))
		var y := 121.0 + float(group_index) * 94.0 + float(item_index) * 37.0
		var button := Button.new()
		button.position = Vector2(x,y)
		button.size = Vector2(290,33)
		button.clip_contents = true
		button.clip_text = true
		button.add_theme_font_size_override("font_size",12)
		button.pressed.connect(func(index: int = i): _toggle_source_selection(index))
		add_child(button)
		clue_buttons.append(button)
		var caption := Label.new()
		caption.name = "Caption"
		caption.position = Vector2(12,6)
		caption.size = Vector2(270,23)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size",12)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)
	journal_label = _label("",Vector2(642,390),Vector2(280,45),11,Color("d7c7e3"))
	nearby_label = _label("",Vector2(36,420),Vector2(570,28),13,Color("f2d9a1"))
	status_label = _label("Осмотри источники по текущему вопросу. Полные сведения появятся после сравнения пары.",Vector2(36,450),Vector2(570,72),12,Color("e5c98f"))
	connect_button = _button("Сопоставить источники",Vector2(642,438),Vector2(280,35),_connect)
	_button("Забрать копию и уйти",Vector2(642,480),Vector2(280,34),_leave_with_backup)
	explorer = AnimatedSprite2D.new()
	explorer.sprite_frames = preload("res://assets/sprites/4fr/4fr-animations.tres")
	explorer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	explorer.scale = Vector2(0.5,0.5)
	explorer.position = explorer_pos
	add_child(explorer)
	explorer.play("idle_down")
	_render()
	MiniGameStyle.apply(self, Color("1a2634"), Color("6b8eae"), Color("c3dfef"))

func open(snapshot: Dictionary = {}, values: Dictionary = {}) -> void:
	found.clear()
	links.clear()
	selection.clear()
	optional_seen.clear()
	errors = 0
	companion = str(values.get("old_projects_companion","alone"))
	if companion not in ["grok","jbt","alone"]: companion = "alone"
	access_shared = bool(values.get("project_access_shared",false))
	grok_trust = bool(values.get("grok_trust",false))
	grok_conflict = int(values.get("lies_count",0)) >= 2
	jbt_trust = bool(values.get("gpt_boundaries",false)) and not bool(values.get("lied_in_court",false))
	tutorial_seen = bool(snapshot.get("tutorial_seen",false))
	if snapshot.has("found"):
		for id in snapshot.found:
			if id is String and _clue_index(id) >= 0 and not found.has(id): found.append(id)
	if snapshot.has("links"):
		for id in snapshot.links:
			if id is String and _link_index(id) >= 0 and not links.has(id): links.append(id)
	if snapshot.get("selection",[]) is Array:
		for id in snapshot.get("selection",[]):
			if id is String and found.has(id) and not selection.has(id) and selection.size() < 2: selection.append(id)
	if snapshot.get("optional_seen",[]) is Array:
		for id in snapshot.get("optional_seen",[]):
			if id is String and id in ["door","abandoned"] and not optional_seen.has(id): optional_seen.append(id)
	errors = clampi(int(snapshot.get("errors",0)),0,999)
	var pos: Variant = snapshot.get("player",{})
	if pos is Dictionary and pos.has("x") and pos.has("y"):
		explorer_pos = Vector2(clampf(float(pos.x),EXPLORER_MIN.x,EXPLORER_MAX.x),clampf(float(pos.y),EXPLORER_MIN.y,EXPLORER_MAX.y))
	else: explorer_pos = Vector2(330,265)
	explorer.position = explorer_pos
	show()
	if not tutorial_seen:
		_show_help()
	else:
		status_label.text = "Копия уже доступна. Сравни источники, чтобы собрать доказательства, или забери частичную копию." if found.size() >= 3 else "Подойди к источнику текущего вопроса и нажми E. После этого выбери его карточку справа."
	_update_nearby()
	_render()
	checkpoint_changed.emit(snapshot())

func snapshot() -> Dictionary:
	return {"found":found.duplicate(),"links":links.duplicate(),"selection":selection.duplicate(),"optional_seen":optional_seen.duplicate(),"errors":errors,"tutorial_seen":tutorial_seen,"player":{"x":explorer_pos.x,"y":explorer_pos.y}}

func _show_help() -> void:
	tutorial_seen = true
	status_label.text = "Ищи предметы в любом порядке и осматривай клавишей E. Справа открой две карточки и сравни их. При выборе новой пары прежние названия снова скроются."
	checkpoint_changed.emit(snapshot())

func _leave_with_backup() -> void:
	if found.size() < 3:
		status_label.text = "Для рабочей копии найди хотя бы три предмета. Связывать их необязательно."
		return
	finished.emit({"evidence":links.size() == LINKS.size(),"links":links.size(),"errors":errors,"found":found.size(),"backup":true})

func _inspect(index: int) -> void:
	if index < 0 or index >= CLUES.size(): return
	var id := str(CLUES[index].id)
	if not found.has(id): found.append(id)
	if selection.size() >= 2 or selection.has(id): selection.clear()
	selection.append(id)
	var clue_text := "4fr передал пароль позже. Разрешения менять автора он не давал." if id == "chat" and access_shared else str(CLUES[index].body)
	status_label.text = clue_text + "\n" + _companion_reaction(index)
	_render()
	checkpoint_changed.emit(snapshot())

func _toggle_source_selection(index: int) -> void:
	if index < 0 or index >= CLUES.size(): return
	var id := str(CLUES[index].id)
	if not found.has(id): return
	if selection.has(id):
		selection.erase(id)
	else:
		if selection.size() >= 2: selection.clear()
		selection.append(id)
	status_label.text = "Выбрано %d из 2 источников. Когда выберешь пару, нажми «Сопоставить источники»." % selection.size()
	_render()
	checkpoint_changed.emit(snapshot())

func _connect() -> void:
	if selection.size() != 2:
		status_label.text = "Выбери справа два найденных источника для одного вывода."
		return
	var key := _pair_key(selection[0],selection[1])
	var index := _link_index(key)
	if index >= 0:
		if not links.has(key):
			links.append(key)
			status_label.text = ["Вывод 1 подтверждён: ранняя комната и манифест показывают, что прототип начал 4fr.\n" + _companion_reaction(0),"Вывод 2 подтверждён: план показа — работа Артбея, а поле автора в копии меняли отдельно.\n" + _companion_reaction(2),"Вывод 3 подтверждён: копию открыли раньше разрешения; переписка не разрешает менять авторство.\n" + _companion_reaction(4)][index]
		else:
			status_label.text = "Этот вывод уже подтверждён. Выбери другую пару."
	else:
		errors += 1
		status_label.text = "Эти два источника пока не дают общего вывода. Попробуй другую пару."
	selection.clear()
	_render()
	checkpoint_changed.emit(snapshot())
	if links.size() == LINKS.size():
		finished.emit({"evidence":true,"links":links.size(),"errors":errors,"found":found.size(),"backup":true})

func _companion_reaction(index: int) -> String:
	if companion == "grok":
		if grok_conflict:
			return ["Грок: «Ты говорил, что бросил это. А дверь трижды переделывал».","Грок: «Файл твой. Наш спор сейчас подождёт».","Грок: «Его вклад вижу. Твой тоже».","Грок: «Вот это покажи Артбею, без шуток».","Грок: «Скрин сохраню. Доверие — потом».","Грок: «Свою ложь ты исправишь сам. Чужую — не прикрывай»."][index]
		return ["Грок: «Ты возвращался к этой двери. Не называй это пустой тратой времени».","Грок: «Твоё имя здесь с первой версии».","Грок: «План показа он сделал хорошо. Только игру делал ты».","Грок: «Вот здесь тебя заменили. Сохрани обе версии».","Грок: «Я сниму экран с датами».","Грок: «Теперь можно говорить с ним. Я рядом, если хочешь»."][index] if grok_trust else ["Грок: «Три попытки. Значит, тебе было важно».","Грок: «Имя сохранилось».","Грок: «Он помог с показом, это видно».","Грок: «А это уже чужое имя в твоей игре».","Грок: «Дата не сходится».","Грок: «Решение всё равно твоё»."][index]
	if companion == "jbt":
		return ["ЖБТ: «Сохраним v0.1 отдельно. Здесь начинается цепочка».","ЖБТ: «Автор записан до появления копии. Это проверяемо».","ЖБТ: «План Артбея тоже оставим. В споре нельзя стирать его работу».","ЖБТ: «Сравни только поле автора. Остальной проект тот же».","ЖБТ: «Я сверю время с сообщением».","ЖБТ: «Теперь факты собраны. Вывод скажешь ему сам»."][index] if jbt_trust else ["ЖБТ: «Сначала сохраним оригинал».","ЖБТ: «Исходное имя читается».","ЖБТ: «План показа отделим от кода».","ЖБТ: «Изменение автора зафиксировано».","ЖБТ: «Порядок событий важен».","ЖБТ: «Я не буду решать за тебя»."][index]
	if index == 0: return "4fr: «Я три раза правил эту дверь. Думал, просто надоела игра»."
	if index == 2: return "4fr: «Артбей правда придумал, как это показывать. Я этого не делал»."
	return ""

func _render() -> void:
	if clue_buttons.size() != CLUES.size(): return
	var pair_colors := [Color("8b70a2"),Color("6e9790"),Color("a48261")]
	var active_group := _active_group()
	for group_index in range(GROUP_TITLES.size()):
		var key := _pair_key(str(LINKS[group_index].a),str(LINKS[group_index].b))
		var state_text := " · ГОТОВО" if links.has(key) else " · ИЩИ УЛИКИ"
		group_header_labels[group_index].text = GROUP_TITLES[group_index] + state_text
		group_header_labels[group_index].add_theme_color_override("font_color",Color("e1c9a4") if group_index == active_group else (Color("9fc9b9") if links.has(key) else Color("9b91a5")))
	for i in range(CLUES.size()):
		var clue: Dictionary = CLUES[i]
		var id := str(clue.id)
		var is_found := found.has(id)
		var selected := selection.has(id)
		var group_index := floori(float(i) / 2.0)
		var pair_slot := "А" if i % 2 == 0 else "Б"
		clue_buttons[i].get_node("Caption").text = (pair_slot + " · ✓ " + str(clue.title)) if selected else (pair_slot + " · ??? · нажми, чтобы раскрыть" if is_found else pair_slot + " · ??? · найти в коридоре")
		clue_buttons[i].disabled = not is_found
		var style := StyleBoxFlat.new()
		style.bg_color = Color("45364e") if selected else (Color("292333") if is_found else Color("1b1923"))
		style.border_color = Color("d4a9ef") if selected else pair_colors[floori(float(i) / 2.0)]
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(5)
		clue_buttons[i].add_theme_stylebox_override("normal",style)
		clue_buttons[i].add_theme_stylebox_override("hover",style)
	journal_label.text = "Вопрос %s / 3 · найдено: %d / 6\nВыводов собрано: %d / 3 · выбрано: %d / 2" % [str(mini(active_group + 1,3)),found.size(),links.size(),selection.size()]
	connect_button.disabled = selection.size() != 2
	queue_redraw()

func _active_group() -> int:
	for group_index in range(LINKS.size()):
		var key := _pair_key(str(LINKS[group_index].a),str(LINKS[group_index].b))
		if not links.has(key): return group_index
	return LINKS.size()

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(explorer): return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))).normalized()
	if direction != Vector2.ZERO:
		explorer_pos += direction * 150.0 * delta
		explorer_pos.x = clampf(explorer_pos.x,EXPLORER_MIN.x,EXPLORER_MAX.x)
		explorer_pos.y = clampf(explorer_pos.y,EXPLORER_MIN.y,EXPLORER_MAX.y)
		explorer.position = explorer_pos
		explorer.play("walk_left" if direction.x < 0 else "walk_right" if direction.x > 0 else "walk_up" if direction.y < 0 else "walk_down")
	else: explorer.play("idle_down")
	_update_nearby()
	queue_redraw()

func _update_nearby() -> void:
	if not is_instance_valid(nearby_label): return
	var nearest := -1
	var distance := 60.0
	for i in range(POINTS.size()):
		var d: float = explorer_pos.distance_to(POINTS[i])
		if d < distance: nearest = i; distance = d
	var optional_name := ""
	for item in OPTIONAL_POINTS:
		var d: float = explorer_pos.distance_to(item.point)
		if d < distance: optional_name = "дверь" if str(item.id) == "door" else "забытый персонаж"; distance = d; nearest = -1
	nearby_label.text = "E · " + (str(LOCATION_NAMES[nearest]) if nearest >= 0 else optional_name) if nearest >= 0 or not optional_name.is_empty() else ""

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0d0d19"))
	draw_rect(Rect2(24,99,590,349),Color("080914"))
	draw_rect(Rect2(42,126,218,305),Color("443645"))
	draw_texture_rect(FLOOR,Rect2(43,155,215,273),false,Color("a79bae"))
	draw_rect(Rect2(42,126,217,28),Color("554458"))
	draw_rect(Rect2(43,126,214,5),Color("7b6379"))
	# The intact corner is recognisably Grat's old room: a bed, wall and a faulty door.
	draw_rect(Rect2(58,232,74,98),Color("211c29"))
	draw_rect(Rect2(63,237,64,88),Color("5a4c57"))
	draw_rect(Rect2(68,241,54,24),Color("b4aeb8"))
	draw_rect(Rect2(68,269,54,50),Color("373244"))
	draw_rect(Rect2(178,173,51,103),Color("191822"))
	draw_rect(Rect2(183,177,42,95),Color("57475b"))
	draw_rect(Rect2(220,224,4,5),Color("e8c393"))
	draw_line(Vector2(176,271),Vector2(232,279),Color("e8a381"),2.0)
	draw_rect(Rect2(258,154,276,235),Color("282a38"))
	for y in range(178,387,32):
		draw_rect(Rect2(258,y,276,2),Color("3b3f50"))
	for x in range(281,524,47):
		draw_rect(Rect2(x,154,2,234),Color("34384b"))
	# Unpainted grid fades towards the void; all six sources remain reachable.
	for x in range(284,525,48):
		draw_rect(Rect2(x,388,20,34),Color("85828e"))
		draw_rect(Rect2(x+3,391,14,27),Color("aaa5af"))
	draw_rect(Rect2(534,215,57,133),Color("0a0b19"))
	draw_line(Vector2(534,213),Vector2(534,347),Color("8c8198"),2.0)
	draw_rect(Rect2(522,194,13,34),Color("3d394d"))
	draw_rect(Rect2(523,331,12,35),Color("3d394d"))
	# A prototype corridor stops at an unpainted void, with two unfinished props.
	draw_rect(Rect2(527,133,51,65),Color("151421"))
	draw_rect(Rect2(533,138,40,55),Color("4e4656"))
	draw_rect(Rect2(537,142,32,45),Color("211e2d"))
	draw_rect(Rect2(551,165,5,5),Color("c5a478"))
	draw_rect(Rect2(536,329,32,39),Color("777784"))
	draw_rect(Rect2(540,335,24,29),Color("9d9daa"))
	draw_rect(Rect2(544,340,16,18),Color("585864"))
	for i in range(POINTS.size()):
		var point: Vector2 = POINTS[i]
		var collected := found.has(str(CLUES[i].id))
		_draw_artifact(i,point,collected)

func _draw_artifact(index: int, point: Vector2, collected: bool) -> void:
	var ink := Color("aaa3ae") if collected else Color("f2d9a1")
	var shadow := Color("1b1b29")
	if not collected:
		draw_rect(Rect2(point-Vector2(25,37),Vector2(50,40)),Color(0.92,0.72,0.43,0.12))
	match index:
		0: # A playable scrap of the earliest room.
			draw_rect(Rect2(point-Vector2(23,27),Vector2(46,31)),shadow)
			draw_rect(Rect2(point-Vector2(20,24),Vector2(40,25)),Color("5b4b59"))
			draw_rect(Rect2(point-Vector2(15,18),Vector2(15,14)),Color("342f40"))
			draw_rect(Rect2(point+Vector2(8,-19),Vector2(8,18)),ink)
		1: # The original project manifest.
			draw_rect(Rect2(point-Vector2(17,27),Vector2(34,35)),shadow)
			draw_rect(Rect2(point-Vector2(14,24),Vector2(28,29)),Color("d3c8bd"))
			for y in [point.y-18,point.y-12,point.y-6]: draw_line(Vector2(point.x-9,y),Vector2(point.x+9,y),Color("554b5c"),2.0)
		2: # Artrey's pitch board.
			draw_rect(Rect2(point-Vector2(22,23),Vector2(44,28)),shadow)
			draw_rect(Rect2(point-Vector2(19,20),Vector2(38,22)),Color("66536e"))
			draw_rect(Rect2(point-Vector2(13,15),Vector2(9,9)),ink)
			draw_line(point+Vector2(0,-12),point+Vector2(14,-12),Color("d2bac8"),2.0)
		3: # Three repair notes beside a broken door.
			for n in range(3):
				draw_rect(Rect2(point+Vector2(-18+n*9,-25+n*5),Vector2(23,28)),shadow)
				draw_rect(Rect2(point+Vector2(-16+n*9,-23+n*5),Vector2(19,24)),Color("b5a7ad"))
			draw_line(point+Vector2(2,-5),point+Vector2(13,-5),ink,2.0)
		4: # Access history on an old terminal.
			draw_rect(Rect2(point-Vector2(22,27),Vector2(44,34)),shadow)
			draw_rect(Rect2(point-Vector2(19,24),Vector2(38,25)),Color("273747"))
			draw_line(point+Vector2(-13,-17),point+Vector2(12,-17),ink,2.0)
			draw_line(point+Vector2(-13,-10),point+Vector2(6,-10),ink,2.0)
		5: # A saved message, separate from the access history.
			draw_rect(Rect2(point-Vector2(22,25),Vector2(44,30)),shadow)
			draw_rect(Rect2(point-Vector2(19,22),Vector2(38,24)),Color("63566a"))
			draw_line(point+Vector2(-13,-15),point+Vector2(12,-15),ink,2.0)
			draw_line(point+Vector2(-13,-8),point+Vector2(4,-8),ink,2.0)

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
	elif visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		var best := -1
		var distance := 65.0
		for i in range(POINTS.size()):
			var d: float = explorer_pos.distance_to(POINTS[i])
			if d < distance: best = i; distance = d
		var optional_id := ""
		for item in OPTIONAL_POINTS:
			var d: float = explorer_pos.distance_to(item.point)
			if d < distance: optional_id = str(item.id); distance = d; best = -1
		if best >= 0: _inspect(best)
		elif not optional_id.is_empty(): _inspect_optional(optional_id)
		else: status_label.text = "Подойди ближе к мерцающему предмету."
		get_viewport().set_input_as_handled()

func _inspect_optional(id: String) -> void:
	for item in OPTIONAL_POINTS:
		if str(item.id) == id:
			status_label.text = str(item.text)
			if id == "door" and companion == "grok":
				status_label.text = "4fr: «Я говорил, что дверь надоела. Но исправлял её трижды».\n" + ("Грок: «Я видела каждый скрин. Можешь не притворяться, что тебе всё равно»." if grok_trust and not grok_conflict else "Грок: «Это твоя работа. Наш спор её не отменяет».")
			elif id == "door" and companion == "jbt":
				status_label.text = "Три версии одной двери.\nЖБТ: «В каждой есть исправление. Ты возвращался к проблеме, а не просто копировал папку»."
			elif id == "abandoned" and companion == "grok":
				status_label.text = "Забытый персонаж: «Привет».\nГрок: «Он ждёт ответа. Как и я иногда». 4fr: «Я услышал»." if grok_trust and not grok_conflict else "Забытый персонаж: «Привет».\nГрок: «Ему тоже не хватило разговора»."
			elif id == "abandoned" and companion == "jbt":
				status_label.text = "Забытый персонаж: «Привет».\nЖБТ: «Ответ так и не записан. Добавим в список после релиза? Не обязательно сейчас»."
			if not optional_seen.has(id): optional_seen.append(id)
			checkpoint_changed.emit(snapshot())
			return

func _gui_input(event: InputEvent) -> void:
	if not visible or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	for i in range(POINTS.size()):
		if event.position.distance_to(POINTS[i]) < 26.0:
			if explorer_pos.distance_to(POINTS[i]) < 65.0: _inspect(i)
			else: status_label.text = "Сначала подойди к этому предмету."
			accept_event()
			return

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

