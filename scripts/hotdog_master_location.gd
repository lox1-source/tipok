@tool
extends Control

signal checkpoint_changed(data: Dictionary)
signal interaction_requested(id: String)
signal pause_requested
signal return_requested
signal order_confirmed(item_id: String)

const ORDER_IDS := ["single", "double", "master", "signature"]
const ORDER_ICON_REGIONS := [
	Rect2(360, 50, 480, 370), Rect2(935, 45, 480, 380),
	Rect2(360, 460, 480, 380), Rect2(935, 460, 480, 380)
]
const ORDER_ICONS := preload("res://assets/ui/hotdog/menu-items.png")
const KIOSK_EMBLEM := preload("res://assets/ui/hotdog/hotdog-master-emblem.png")

const WALK_SPEED := 220.0
const INTERACTION_RADIUS := 78.0
const WALK_AREA := Rect2(42.0,340.0,876.0,62.0)
const PLAYER_SPAWN := Vector2(160,402)
const ARTREY_POSITION := Vector2(458,380)
const HOTSPOTS := [
	{"id":"window", "name":"Окно заказа", "position":Vector2(495, 354)},
	{"id":"menu", "name":"Меню у окна", "position":Vector2(692, 354)},
	{"id":"drinks", "name":"Холодильник с напитками", "position":Vector2(290, 385)},
	{"id":"bench", "name":"Лавка у тротуара", "position":Vector2(128, 405)},
	{"id":"artrey", "name":"поговорить с Артбеем", "position":Vector2(458, 405)}
]

var player_position := PLAYER_SPAWN
var player: AnimatedSprite2D
var artrey_sprite: Sprite2D
var walk_area_polygon: Polygon2D
var order_overlay: Control
var order_feedback: Label
var kiosk_hud_nodes: Array[CanvasItem] = []
var dialogue_backdrop := false
var nearest_id := ""
var status_label: Label
var prompt_label: Label
var chapter_first_visit := true
var observed: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	size = Vector2(960, 540)
	walk_area_polygon = get_node_or_null("WalkAreaPolygon") as Polygon2D
	if not is_instance_valid(walk_area_polygon):
		walk_area_polygon = Polygon2D.new()
		walk_area_polygon.name = "WalkAreaPolygon"
		walk_area_polygon.polygon = PackedVector2Array([Vector2(42,340),Vector2(918,340),Vector2(918,402),Vector2(42,402)])
		walk_area_polygon.color = Color(0.2,0.85,1,0.24)
		walk_area_polygon.z_index = 200
		add_child(walk_area_polygon)
	walk_area_polygon.visible = Engine.is_editor_hint()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := Sprite2D.new()
	background.texture = preload("res://assets/sprites/locations/hotdog_master_night.png")
	background.position = size * 0.5
	background.scale = Vector2(0.625,0.625)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.025, 0.07, 0.18)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var top_card := Panel.new()
	top_card.position = Vector2(22, 16)
	top_card.size = Vector2(600, 72)
	top_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_card.add_theme_stylebox_override("panel", _style(Color(0.045,0.03,0.08,0.88),Color("8e70a2")))
	add_child(top_card)
	kiosk_hud_nodes.append(top_card)
	_label(top_card,"ПОСЛЕ BIOS · У КИОСКА «ХОТ-ДОГ МАСТЕР»",Vector2(18,9),Vector2(566,28),18,Color("ffe2ac"))
	_label(top_card,"WASD / стрелки — идти · E — осмотреться и поговорить · Esc — пауза",Vector2(18,39),Vector2(566,22),12,Color("e1d4eb"))
	kiosk_hud_nodes.append(_button("Пауза",Vector2(846,20),Vector2(92,34),func(): pause_requested.emit()))
	kiosk_hud_nodes.append(_button("В комнату",Vector2(734,20),Vector2(102,34),_request_return))
	var sign_label := _label(self,"ХОТ-ДОГ\nМАСТЕР",Vector2(476,145),Vector2(170,51),14,Color("ffe0a2"))
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_label.add_theme_color_override("font_outline_color",Color("25131d"))
	sign_label.add_theme_constant_override("outline_size",3)
	artrey_sprite = Sprite2D.new()
	artrey_sprite.texture = preload("res://assets/sprites/locations/artbey_kiosk.png")
	artrey_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	artrey_sprite.scale = Vector2(0.16,0.16)
	artrey_sprite.position = ARTREY_POSITION
	add_child(artrey_sprite)
	var npc_marker := _label(self,"АРТБЕЙ",ARTREY_POSITION + Vector2(-41,-95),Vector2(82,21),13,Color("fff0c7"))
	npc_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kiosk_hud_nodes.append(npc_marker)
	status_label = _label(self,"Свежий воздух. Не BIOS. Даже очередь пока человеческая.",Vector2(24,481),Vector2(650,29),15,Color("f1e8f8"))
	prompt_label = _label(self,"",Vector2(505,481),Vector2(430,29),15,Color("ffe0a2"))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kiosk_hud_nodes.append(status_label)
	kiosk_hud_nodes.append(prompt_label)
	player = AnimatedSprite2D.new()
	player.name = "GratAtKiosk"
	player.sprite_frames = preload("res://assets/sprites/4fr/4fr-animations.tres")
	player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.scale = Vector2(1.6,1.6)
	player.position = player_position
	add_child(player)
	player.play("idle_down")
	_update_depth_order()
	_update_nearest()
	queue_redraw()

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _label(parent: Node, value: String, pos: Vector2, area: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = area
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(value: String, pos: Vector2, area: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = area
	button.add_theme_font_size_override("font_size",13)
	button.pressed.connect(action)
	button.add_theme_stylebox_override("normal",_style(Color("21182b"),Color("715985")))
	button.add_theme_stylebox_override("hover",_style(Color("39294a"),Color("c3a2d5")))
	button.add_theme_stylebox_override("pressed",_style(Color("130f1b"),Color("e5c982")))
	add_child(button)
	return button

func open(checkpoint: Dictionary = {}, first_visit: bool = true, record_checkpoint: bool = true) -> void:
	set_dialogue_backdrop(false)
	chapter_first_visit = first_visit
	observed.clear()
	var raw_observed: Variant = checkpoint.get("observed",[])
	if raw_observed is Array:
		for raw_id in raw_observed:
			var id := str(raw_id)
			if _hotspot_index(id) >= 0 and id != "artrey" and id not in observed:
				observed.append(id)
	# First-visit saves may contain a stale point from an earlier scene layout.
	# Start at the left side so both characters are separated and the meeting is clear.
	if first_visit:
		player_position = _constrain_to_walk_area(PLAYER_SPAWN)
	else:
		var raw_position: Variant = checkpoint.get("player",{})
		if raw_position is Dictionary and raw_position.has("x") and raw_position.has("y"):
			player_position = Vector2(float(raw_position.x),float(raw_position.y))
		player_position = _constrain_to_walk_area(player_position)
		# Old checkpoints can leave Grat standing inside Artrey's enlarged sprite.
		if player_position.distance_to(HOTSPOTS[_hotspot_index("artrey")].position) < 150.0:
			player_position = _constrain_to_walk_area(PLAYER_SPAWN)
	player.position = player_position
	_update_depth_order()
	status_label.text = "Первый выход из BIOS. Подойди к Артбею и нажми E, чтобы поговорить." if first_visit else "Вернулся к киоску. Подойди к Артбею или осмотрись вокруг."
	show()
	_update_nearest()
	if record_checkpoint:
		checkpoint_changed.emit(snapshot())

func set_dialogue_backdrop(value: bool) -> void:
	dialogue_backdrop = value
	for item in kiosk_hud_nodes:
		item.visible = not value
	queue_redraw()

func snapshot() -> Dictionary:
	return {"player":{"x":player_position.x,"y":player_position.y},"observed":observed.duplicate()}

func _process(delta: float) -> void:
	if not visible:
		return
	if Engine.is_editor_hint():
		return
	if is_instance_valid(order_overlay) and order_overlay.visible:
		return
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if move != Vector2.ZERO:
		player_position += move.normalized() * WALK_SPEED * delta
		player_position = _constrain_to_walk_area(player_position)
		player.position = player_position
		_update_depth_order()
		player.play("walk_right" if move.x > 0.0 else "walk_left" if move.x < 0.0 else "walk_down" if move.y > 0.0 else "walk_up")
	else:
		player.play("idle_right" if player.animation == "walk_right" else "idle_left" if player.animation == "walk_left" else "idle_down")
	_update_nearest()
	queue_redraw()

func _update_depth_order() -> void:
	# Both sprites use their feet as the depth cue. Grat passes behind Artrey
	# above him on the pavement and in front below him.
	artrey_sprite.z_index = 2
	player.z_index = 1 if player_position.y < ARTREY_POSITION.y else 3

func show_order_menu() -> void:
	if is_instance_valid(order_overlay):
		order_overlay.show()
		return
	order_overlay = Control.new()
	order_overlay.name = "HotdogOrderMenu"
	order_overlay.size = size
	order_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	order_overlay.z_index = 20
	add_child(order_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.015,0.035,0.7)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	order_overlay.add_child(dim)
	var board := Panel.new()
	board.position = Vector2(150,66)
	board.size = Vector2(660,414)
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.add_theme_stylebox_override("panel",_style(Color("c99c58"),Color("8b3830")))
	order_overlay.add_child(board)
	_label(board,"ХОТ-ДОГ МАСТЕР · МЕНЮ",Vector2(24,16),Vector2(550,35),22,Color("662b2a"))
	var emblem := Sprite2D.new()
	var emblem_crop := AtlasTexture.new()
	emblem_crop.atlas = KIOSK_EMBLEM
	emblem_crop.region = Rect2(300,110,740,1000)
	emblem.texture = emblem_crop
	emblem.position = Vector2(602,38)
	emblem.scale = Vector2(0.052,0.052)
	emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.add_child(emblem)
	_label(board,"Артбей уже взял два. Выбери хот-дог для 4fr.",Vector2(24,51),Vector2(608,25),13,Color("4d2b28"))
	var items := [
		["Одинарный", "65 ₽", "Классика без сюрпризов."],
		["Двойной", "82 ₽", "Две сосиски, один вопрос."],
		["Мастер сосиска", "99 ₽", "Фирменный. Последний в наличии."],
		["Фирменный", "85 ₽", "Соус по секретному рецепту."]
	]
	for i in range(items.size()):
		var item: Array = items[i]
		var x := 24.0 + float(i % 2) * 312.0
		var y := 91.0 + float(i / 2) * 114.0
		var pick := Button.new()
		pick.name = "Order_" + ORDER_IDS[i]
		pick.position = Vector2(x,y)
		pick.size = Vector2(296,82)
		pick.text = ""
		pick.add_theme_color_override("font_color",Color("572b26"))
		pick.add_theme_color_override("font_hover_color",Color("3d171a"))
		pick.add_theme_color_override("font_focus_color",Color("4a211f"))
		pick.add_theme_color_override("font_pressed_color",Color("4a211f"))
		pick.add_theme_stylebox_override("normal",_style(Color("edcb82"),Color("985744")))
		pick.add_theme_stylebox_override("hover",_style(Color("ffe2a0"),Color("702f2a")))
		pick.add_theme_stylebox_override("pressed",_style(Color("d5a661"),Color("54201f")))
		pick.pressed.connect(_order_item_pressed.bind(i))
		board.add_child(pick)
		var crop := AtlasTexture.new()
		crop.atlas = ORDER_ICONS
		crop.region = ORDER_ICON_REGIONS[i]
		var icon := Sprite2D.new()
		icon.texture = crop
		icon.position = Vector2(51,41)
		icon.scale = Vector2(0.19,0.19)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pick.add_child(icon)
		_label(pick,"%s  %s" % [item[0],item[1]],Vector2(100,13),Vector2(187,27),15,Color("572b26"))
		_label(pick,str(item[2]),Vector2(100,43),Vector2(188,28),11,Color("653b31"))
		if i == 2:
			pick.grab_focus.call_deferred()
	order_feedback = _label(board,"Выбери любую позицию. Артбей свои два уже взял.",Vector2(24,327),Vector2(608,54),14,Color("542823"))

func hide_order_menu() -> void:
	if is_instance_valid(order_overlay):
		order_overlay.hide()

func _order_item_pressed(index: int) -> void:
	if index < 0 or index >= ORDER_IDS.size() or not is_instance_valid(order_overlay) or not order_overlay.visible:
		return
	hide_order_menu()
	order_confirmed.emit(ORDER_IDS[index])

func _update_nearest() -> void:
	nearest_id = ""
	var nearest_distance := INTERACTION_RADIUS
	for item in HOTSPOTS:
		var distance := player_position.distance_to(item.position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_id = str(item.id)
	if is_instance_valid(prompt_label):
		prompt_label.text = "E · " + str(HOTSPOTS[_hotspot_index(nearest_id)].name) if not nearest_id.is_empty() else ""

func _interact() -> void:
	if nearest_id.is_empty():
		status_label.text = "Подойди ближе к окну, меню или лавке."
		return
	if nearest_id == "artrey":
		interaction_requested.emit("artrey")
		return
	var first_time := nearest_id not in observed
	if first_time:
		observed.append(nearest_id)
	match nearest_id:
		"window": status_label.text = "Заказ без квеста: хот-дог можно взять, но для сюжета это необязательно."
		"menu": status_label.text = "Артбей снова заказал «как обычно». Продавец спросил, что именно это значит."
		"drinks": status_label.text = "Холодильник гудит громче компьютера. Хорошо хоть пароль не спрашивает."
		"bench": status_label.text = "На лавке Артбей обычно рассказывает про идеи. Сегодня можно говорить и не о проекте."
	if not first_time:
		status_label.text += " Это место ты уже осматривал."
	checkpoint_changed.emit(snapshot())
	queue_redraw()

func _request_return() -> void:
	if chapter_first_visit:
		status_label.text = "Перед возвращением поговори с Артбеем у окна. Он ждёт тебя после BIOS."
		return
	return_requested.emit()

func _input(event: InputEvent) -> void:
	# A focused Button treats Space as ui_accept before _unhandled_key_input.
	# The order must require an explicit click or Enter, not dialogue skipping.
	if not Engine.is_editor_hint() and visible and is_instance_valid(order_overlay) and order_overlay.visible and event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if is_instance_valid(order_overlay) and order_overlay.visible:
		if key in [KEY_ESCAPE,KEY_P]:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if key in [KEY_ESCAPE,KEY_P]:
		pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif key in [KEY_E,KEY_ENTER,KEY_KP_ENTER]:
		_interact()
		get_viewport().set_input_as_handled()

func _hotspot_index(id: String) -> int:
	for i in range(HOTSPOTS.size()):
		if str(HOTSPOTS[i].id) == id:
			return i
	return -1

func _constrain_to_walk_area(point: Vector2) -> Vector2:
	var polygon := PackedVector2Array()
	for vertex in walk_area_polygon.polygon:
		polygon.append(walk_area_polygon.transform * vertex)
	if polygon.size() < 3:
		return point
	if Geometry2D.is_point_in_polygon(point,polygon):
		return point
	var closest := polygon[0]
	var closest_distance := INF
	for index in range(polygon.size()):
		var candidate := Geometry2D.get_closest_point_to_segment(point,polygon[index],polygon[(index + 1) % polygon.size()])
		var distance := point.distance_squared_to(candidate)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest

func _draw() -> void:
	if dialogue_backdrop:
		return
	for item in HOTSPOTS:
		var id := str(item.id)
		var point: Vector2 = item.position
		var active := id == nearest_id
		var tint := Color("ffd784",0.95) if active else Color("f0dfbd",0.56)
		draw_rect(Rect2(point-Vector2(4,13),Vector2(8,8)),tint)
		if id in observed:
			draw_rect(Rect2(point-Vector2(7,16),Vector2(14,14)),Color("93d2a2",0.6),false,1.0)
	if not nearest_id.is_empty():
		var point: Vector2 = HOTSPOTS[_hotspot_index(nearest_id)].position
		draw_rect(Rect2(point-Vector2(18,29),Vector2(36,36)),Color("f1d27b",0.65),false,1.5)
