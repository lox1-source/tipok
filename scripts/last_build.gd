extends Control
const MiniGameStyle = preload("res://scripts/minigame_skin.gd")

signal checkpoint_changed(data: Dictionary)
signal finished(result: Dictionary)
signal pause_requested

class WireVisual extends Control:
	const STRAIGHT_TEXTURE: Texture2D = preload("res://assets/ui/minigames/wire-straight.png")
	const ELBOW_TEXTURE: Texture2D = preload("res://assets/ui/minigames/wire-elbow.png")
	var ports: Array[int] = []
	var joined_ports: Array[int] = []
	var powered := false

	func set_wire(new_ports: Array[int], is_powered: bool, new_joined_ports: Array[int]) -> void:
		ports = new_ports.duplicate()
		joined_ports = new_joined_ports.duplicate()
		powered = is_powered
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var is_straight := ports.size() == 2 and (ports.has(0) and ports.has(2) or ports.has(1) and ports.has(3))
		var texture: Texture2D = STRAIGHT_TEXTURE if is_straight else ELBOW_TEXTURE
		var angle := 0.0
		if is_straight:
			if ports.has(0) and ports.has(2): angle = PI * 0.5
		else:
		# The full-cell elbow sprite joins the top and right edge at their centers.
			if ports.has(0) and ports.has(1): angle = 0.0
			elif ports.has(1) and ports.has(2): angle = PI * 0.5
			elif ports.has(2) and ports.has(3): angle = PI
			else: angle = PI * 1.5
		# Rotate the square sprite first, then fit it to this 4:3 tile. This
		# keeps all four ports on the edge midpoints after every quarter-turn.
		var scale_x := size.x / 96.0
		var scale_y := size.y / 96.0
		var cosine := cos(angle)
		var sine := sin(angle)
		var transform := Transform2D(
			Vector2(scale_x * cosine, scale_y * sine),
			Vector2(-scale_x * sine, scale_y * cosine),
			center
		)
		var sprite_rect := Rect2(-Vector2.ONE * 48.0, Vector2.ONE * 96.0)
		draw_set_transform_matrix(transform)
		if powered:
			draw_texture_rect(texture, sprite_rect, false, Color(0.40, 1.0, 0.83, 0.28))
		draw_texture_rect(texture, sprite_rect, false)
		if powered:
			draw_texture_rect(texture, sprite_rect, false, Color(0.48, 1.0, 0.82, 0.34))
		# Bridge only real neighbor connections. This covers the tile border at
		# the seam without making the source or door ends stick out of the board.
		var turns := posmod(roundi(angle / (PI * 0.5)), 4)
		for world_side in joined_ports:
			var local_side := posmod(world_side - turns, 4)
			var source_rect: Rect2
			var target_rect: Rect2
			var extension := 3.0 / (scale_y if local_side % 2 == 0 else scale_x)
			if is_straight:
				if local_side == 1:
					source_rect = Rect2(61, 26, 3, 12)
					target_rect = Rect2(48, -9, extension, 18)
				else:
					source_rect = Rect2(0, 26, 3, 12)
					target_rect = Rect2(-48 - extension, -9, extension, 18)
			elif local_side == 0:
				source_rect = Rect2(26, 0, 12, 3)
				target_rect = Rect2(-9, -48 - extension, 18, extension)
			else:
				source_rect = Rect2(61, 26, 3, 12)
				target_rect = Rect2(48, -9, extension, 18)
			draw_texture_rect_region(texture, target_rect, source_rect)
			if powered:
				draw_texture_rect_region(texture, target_rect, source_rect, Color(0.48, 1.0, 0.82, 0.34))
		draw_set_transform_matrix(Transform2D.IDENTITY)

const LEVELS := [
	{"name":"Питание двери","instruction":"Проведи питание через прямой участок к двери.","tiles":[{"cell":3,"type":"straight","rot":1},{"cell":4,"type":"straight","rot":1},{"cell":5,"type":"straight","rot":1}]},
	{"name":"Путь key.glb","instruction":"Обойди верхний узел и подключи ключ к двери.","tiles":[{"cell":3,"type":"elbow","rot":3},{"cell":0,"type":"elbow","rot":1},{"cell":1,"type":"straight","rot":1},{"cell":2,"type":"elbow","rot":2},{"cell":5,"type":"elbow","rot":0}]},
	{"name":"Резерв и авторство","instruction":"Собери цепь через резервную копию и манифест.","tiles":[{"cell":3,"type":"elbow","rot":2},{"cell":6,"type":"elbow","rot":0},{"cell":7,"type":"elbow","rot":3},{"cell":4,"type":"elbow","rot":1},{"cell":5,"type":"straight","rot":1}]},
	{"name":"Последняя схема","instruction":"Проведи сигнал через ключ, backup и проверку авторства.","tiles":[{"cell":3,"type":"elbow","rot":3},{"cell":0,"type":"elbow","rot":1},{"cell":1,"type":"elbow","rot":2},{"cell":4,"type":"elbow","rot":0},{"cell":5,"type":"straight","rot":1}]}
]

var level := 0
var rotations: Array[int] = []
var kinds: Array[String] = []
var turns := 0
var mistakes := 0
var tiles: Array[Button] = []
var wire_visuals: Array = []
var status_label: Label
var progress_label: Label
var verify_button: Button
var hint_stage := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	size = Vector2(960,540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("10131b")
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_label("ПОСЛЕДНЯЯ СБОРКА · МАРШРУТИЗАТОР",Vector2(30,14),Vector2(760,36),22,Color("e9d6be"))
	_button("Пауза",Vector2(850,16),Vector2(82,30),func(): pause_requested.emit())
	progress_label = _label("",Vector2(36,56),Vector2(880,30),15,Color("cbbbd8"))
	_label("Нажимай на плитку, чтобы повернуть провод. Соедини источник слева с дверью справа; подключённый путь светится зелёным.",Vector2(36,87),Vector2(888,32),13,Color("b8b3c2"))
	for i in range(9):
		var button := Button.new()
		button.position = Vector2(306 + float(i % 3) * 96,126 + float(i / 3) * 72)
		button.size = Vector2(96,72)
		button.clip_contents = false
		button.text = ""
		button.pressed.connect(func(index: int = i): _rotate_tile(index))
		add_child(button)
		tiles.append(button)
		var wire := WireVisual.new()
		wire.size = button.size
		wire.z_index = 2
		wire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wire.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(wire)
		wire_visuals.append(wire)
	_label("◀ ИСТОЧНИК",Vector2(124,218),Vector2(170,32),17,Color("f0c67d"))
	_label("ДВЕРЬ ▶",Vector2(656,218),Vector2(170,32),17,Color("f0c67d"))
	status_label = _label("",Vector2(70,415),Vector2(820,34),15,Color("d7c8e0"))
	_button("Подсказка",Vector2(140,462),Vector2(160,40),_hint)
	verify_button = _button("Проверить маршрут",Vector2(360,462),Vector2(240,40),_verify)
	_button("Сбросить схему",Vector2(660,462),Vector2(170,40),_reset_level)
	_load_level()
	MiniGameStyle.apply(self, Color("17252a"), Color("4e9a83"), Color("a8efb7"))

func open(snapshot: Dictionary = {}) -> void:
	level = clampi(int(snapshot.get("level",0)),0,LEVELS.size()-1)
	turns = clampi(int(snapshot.get("turns",0)),0,10000)
	mistakes = clampi(int(snapshot.get("mistakes",0)),0,10000)
	hint_stage = clampi(int(snapshot.get("hint_stage",0)),0,3)
	_load_level(snapshot.get("rotations",[]))
	show()
	checkpoint_changed.emit(snapshot())

func snapshot() -> Dictionary:
	return {"level":level,"rotations":rotations.duplicate(),"turns":turns,"mistakes":mistakes,"hint_stage":hint_stage}

func _load_level(saved_rotations: Variant = []) -> void:
	var level_data: Dictionary = LEVELS[level]
	kinds.resize(9)
	rotations.resize(9)
	for i in range(9):
		kinds[i] = "straight" if (i + level) % 2 == 0 else "elbow"
		rotations[i] = (i * 3 + level + 1) % 4
	for tile in level_data.tiles:
		kinds[int(tile.cell)] = str(tile.type)
		rotations[int(tile.cell)] = (int(tile.rot) + 1 + (level % 3)) % 4
	if saved_rotations is Array and saved_rotations.size() == 9:
		for i in range(9):
			rotations[i] = posmod(int(saved_rotations[i]),4)
	if is_instance_valid(status_label): status_label.text = ""
	_render()

func _rotate_tile(index: int) -> void:
	if index < 0 or index >= rotations.size(): return
	rotations[index] = (rotations[index] + 1) % 4
	turns += 1
	_render()
	checkpoint_changed.emit(snapshot())

func _verify() -> void:
	if _has_route():
		status_label.text = "Маршрут подключён: все провода до двери светятся."
		level += 1
		if level >= LEVELS.size():
			finished.emit({"levels":LEVELS.size(),"turns":turns,"mistakes":mistakes,"success":true})
			return
		hint_stage = 0
		_load_level()
		checkpoint_changed.emit(snapshot())
	else:
		mistakes += 1
		status_label.text = "Сигнал обрывается. Поверни следующий провод; зелёные участки уже подключены."
		status_label.add_theme_color_override("font_color",Color("e5c58e"))
		checkpoint_changed.emit(snapshot())

func _has_route() -> bool:
	var visited: Dictionary = {}
	var queue: Array[int] = []
	var first := 3
	if not _opens(first,3): return false
	queue.append(first)
	visited[first] = true
	var dirs := [{"dx":0,"dy":-1,"out":0,"back":2},{"dx":1,"dy":0,"out":1,"back":3},{"dx":0,"dy":1,"out":2,"back":0},{"dx":-1,"dy":0,"out":3,"back":1}]
	while not queue.is_empty():
		var cell: int = int(queue.pop_front())
		var x: int = cell % 3
		var y: int = int(cell / 3)
		if cell == 5 and _opens(cell,1): return true
		for direction in dirs:
			if not _opens(cell,int(direction.out)): continue
			var nx: int = x + int(direction.dx)
			var ny: int = y + int(direction.dy)
			if nx < 0 or nx >= 3 or ny < 0 or ny >= 3: continue
			var next: int = ny * 3 + nx
			if not visited.has(next) and _opens(next,int(direction.back)):
				visited[next] = true
				queue.append(next)
	return false

func _opens(cell: int, side: int) -> bool:
	var rotation := rotations[cell]
	if kinds[cell] == "straight": return side == (rotation % 2) or side == ((rotation + 2) % 4)
	return side == rotation or side == ((rotation + 1) % 4)

func _hint() -> void:
	hint_stage = mini(hint_stage + 1,3)
	var messages := ["Начни с провода слева по центру: он должен смотреть к источнику.","Поворачивай детали, чтобы их концы совпадали у соседних клеток.","Заверши путь проводом справа по центру, направленным к двери."]
	status_label.text = messages[hint_stage-1]
	checkpoint_changed.emit(snapshot())

func _reset_level() -> void:
	hint_stage = 0
	_load_level()
	status_label.text = "Схема сброшена. Поворачивай провода и смотри, как зелёный путь растёт от источника."
	checkpoint_changed.emit(snapshot())

func _render() -> void:
	if tiles.size() != 9 or rotations.size() != 9: return
	var connected := _connected_cells()
	progress_label.text = "Этап %d / %d · %s · поворотов: %d · проверок: %d" % [level+1,LEVELS.size(),str(LEVELS[level].name),turns,mistakes]
	for i in range(9):
		var style := StyleBoxFlat.new()
		var powered := connected.has(i)
		style.bg_color = Color("254132") if powered else Color("2a2632")
		style.border_color = Color("91d5a5") if powered else Color("af96c2")
		style.set_border_width_all(2 if powered else 1)
		style.set_corner_radius_all(4)
		tiles[i].add_theme_stylebox_override("normal",style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color("365943") if powered else Color("3a3345")
		tiles[i].add_theme_stylebox_override("hover",hover)
		tiles[i].tooltip_text = "Нажми, чтобы повернуть провод"
		var ports: Array[int] = []
		for side in range(4):
			if _opens(i,side): ports.append(side)
		var joined_ports: Array[int] = []
		var x := i % 3
		var y := int(i / 3)
		var directions := [
			{"dx":0,"dy":-1,"side":0,"back":2},
			{"dx":1,"dy":0,"side":1,"back":3},
			{"dx":0,"dy":1,"side":2,"back":0},
			{"dx":-1,"dy":0,"side":3,"back":1}
		]
		for direction in directions:
			var side: int = direction.side
			var nx: int = x + int(direction.dx)
			var ny: int = y + int(direction.dy)
			if _opens(i, side) and nx >= 0 and nx < 3 and ny >= 0 and ny < 3:
				var neighbor := ny * 3 + nx
				if _opens(neighbor, int(direction.back)):
					joined_ports.append(side)
		(wire_visuals[i] as WireVisual).set_wire(ports,powered,joined_ports)
	if _has_route():
		status_label.text = "Путь подключён до двери. Нажми «Проверить маршрут»."
		status_label.add_theme_color_override("font_color",Color("a8e6ba"))
		verify_button.text = "Маршрут готов ✓"
	else:
		status_label.text = "Питание дошло до %d из 9 деталей. Продолжай от зелёного провода." % connected.size()
		status_label.add_theme_color_override("font_color",Color("d7c8e0"))
		verify_button.text = "Проверить маршрут"

func _connected_cells() -> Dictionary:
	var connected: Dictionary = {}
	var first := 3
	if not _opens(first,3):
		return connected
	var queue: Array[int] = [first]
	connected[first] = true
	var dirs := [{"dx":0,"dy":-1,"out":0,"back":2},{"dx":1,"dy":0,"out":1,"back":3},{"dx":0,"dy":1,"out":2,"back":0},{"dx":-1,"dy":0,"out":3,"back":1}]
	while not queue.is_empty():
		var cell: int = int(queue.pop_front())
		var x: int = cell % 3
		var y: int = int(cell / 3)
		for direction in dirs:
			if not _opens(cell,int(direction.out)):
				continue
			var nx: int = x + int(direction.dx)
			var ny: int = y + int(direction.dy)
			if nx < 0 or nx >= 3 or ny < 0 or ny >= 3:
				continue
			var next: int = ny * 3 + nx
			if not connected.has(next) and _opens(next,int(direction.back)):
				connected[next] = true
				queue.append(next)
	return connected

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE,KEY_P]: pause_requested.emit(); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER: _verify(); get_viewport().set_input_as_handled()

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
