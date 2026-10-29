extends Control
signal checkpoint_changed(data: Dictionary)
signal finished(result: Dictionary)
signal pause_requested

var state = preload("res://scripts/tab_war_state.gd").new()
var arena: Control
var selection: Control
var ending: Control
var tile_panels: Array[Panel] = []
var tile_titles: Array[Label] = []
var tile_bodies: Array[Label] = []
var tile_close: Array[Button] = []
var spawn_button: Button
var cooldown_bar: ProgressBar
var control_bar: ProgressBar
var stats: Label
var clock: Label
var message: Label
var hold_label: Label
var result_title: Label
var result_body: Label
var last_revision := -1
var save_clock := 0.0
var last_phase := ""

func _ready() -> void:
	size = Vector2(960,540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("0b0915")
	bg.size = size
	add_child(bg)
	_label(self,"ВОЙНА ВКЛАДОК",Vector2(42,18),Vector2(700,40),26,Color("f1e7ff"))
	_button(self,"Пауза",Vector2(832,22),Vector2(86,30),func(): pause_requested.emit())
	_build_selection()
	_build_arena()
	_build_result()
	_render()

func open(snapshot: Dictionary = {}) -> void:
	state.restore(snapshot)
	last_phase = ""
	last_revision = -1
	save_clock = 0.0
	show()
	_render()
	checkpoint_changed.emit(state.snapshot())

func _label(parent: Node, text: String, pos: Vector2, area: Vector2, font: int = 15, color: Color = Color("e5ddec")) -> Label:
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

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

func _button(parent: Node, text: String, pos: Vector2, area: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = area
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size",15)
	button.add_theme_stylebox_override("normal",_style(Color("30263f"),Color("78618d")))
	button.add_theme_stylebox_override("hover",_style(Color("4e3b62"),Color("c4a2da")))
	button.add_theme_stylebox_override("pressed",_style(Color("20192b"),Color("e3cbf0")))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _screen() -> Control:
	var screen := Control.new()
	screen.size = size
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	return screen

func _build_selection() -> void:
	selection = _screen()
	_label(selection,"Выбери сторону",Vector2(190,105),Vector2(580,48),29)
	_label(selection,"Займи минимум 20 из 24 мест своими вкладками и удержи их 4 секунды.\nРаунд длится до 3 минут. Соперник постепенно ускоряется.",Vector2(190,160),Vector2(580,70),17)
	_button(selection,"1 · Грок\nБордовые вкладки",Vector2(190,252),Vector2(278,92),func(): choose_side("grok"))
	_button(selection,"2 · ЖБТ\nМятные вкладки",Vector2(488,252),Vector2(278,92),func(): choose_side("jbt"))
	_label(selection,"Пробел / кнопка — создать вкладку после перезарядки.\nПервые 0,35 с готовности дают сразу две вкладки.\nКрестики — закрыть чужие. Не перепутай со своими!\nЕсли экран полон, соперник перехватывает твои места.",Vector2(190,366),Vector2(580,90),16)
	_label(selection,"Выбор стороны относится к раунду. Он не закрепляет романтический маршрут.",Vector2(190,470),Vector2(580,48),13,Color("a99bb9"))

func _build_arena() -> void:
	arena = _screen()
	_label(arena,"Закрывай чужие крестиками и вовремя создавай свои вкладки",Vector2(42,61),Vector2(850,25),16)
	stats = _label(arena,"",Vector2(42,94),Vector2(720,26),16)
	clock = _label(arena,"03:00",Vector2(821,87),Vector2(100,34),24,Color("e4cc9f"))
	for index in range(state.CELL_COUNT):
		var panel := Panel.new()
		panel.position = Vector2(42+(index%6)*146,132+(index/6)*70)
		panel.size = Vector2(142,65)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arena.add_child(panel)
		tile_panels.append(panel)
		tile_titles.append(_label(panel,"",Vector2(8,3),Vector2(100,23),13))
		tile_bodies.append(_label(panel,"",Vector2(8,29),Vector2(126,30),10,Color("bdb1cb")))
		var close := _button(panel,"×",Vector2(111,2),Vector2(28,25),func(): close_slot(index))
		close.add_theme_font_size_override("font_size",19)
		close.tooltip_text = "Закрыть эту вкладку"
		tile_close.append(close)
	spawn_button = _button(arena,"",Vector2(42,432),Vector2(316,46),spawn)
	cooldown_bar = ProgressBar.new()
	cooldown_bar.position = Vector2(42,485)
	cooldown_bar.size = Vector2(316,10)
	cooldown_bar.max_value = state.COOLDOWN
	cooldown_bar.show_percentage = false
	arena.add_child(cooldown_bar)
	hold_label = _label(arena,"",Vector2(386,434),Vector2(345,28),15)
	control_bar = ProgressBar.new()
	control_bar.position = Vector2(386,470)
	control_bar.size = Vector2(330,18)
	control_bar.max_value = state.HOLD_SECONDS
	control_bar.show_percentage = false
	arena.add_child(control_bar)
	_button(arena,"Завершить раунд",Vector2(749,438),Vector2(169,40),func():
		state.finish(false,"surrender")
		_changed()
	)
	message = _label(arena,"",Vector2(42,508),Vector2(876,24),12,Color("b6a3c8"))

func _build_result() -> void:
	ending = _screen()
	result_title = _label(ending,"",Vector2(130,132),Vector2(720,60),30)
	result_body = _label(ending,"",Vector2(130,212),Vector2(720,155),19)
	_button(ending,"Ещё попытка",Vector2(130,392),Vector2(220,45),func(): choose_side(state.side))
	_button(ending,"Сменить сторону",Vector2(370,392),Vector2(220,45),func():
		state.phase = "select"
		_changed()
	)
	_button(ending,"Дальше по сюжету →",Vector2(610,392),Vector2(220,45),_continue_story)
	_label(ending,"Результат раунда сохранён. Победа помогает выбранной стороне; поражение не блокирует историю.",Vector2(130,469),Vector2(700,50),14,Color("a99bb9"))

func choose_side(side: String) -> void:
	state.start(side)
	message.text = "Новая вкладка готова. Пробел — поймай бонус!"
	_changed()

func spawn() -> void:
	var amount: int = state.spawn_own()
	if amount > 0:
		message.text = "Точное нажатие! Две свои вкладки." if amount == 2 else "Своя вкладка открыта. Готовь следующее нажатие."
	elif state.cooldown_left > 0.0:
		message.text = "Перезарядка ещё идёт — пока закрой чужие вкладки."
	else:
		message.text = "Нет свободных мест. Закрой чужую вкладку крестиком."
	_changed()

func close_slot(index: int) -> void:
	var own: bool = state.cells[index] == state.side
	if state.close_tab(index):
		message.text = "Это была твоя вкладка!" if own else "Чужая вкладка закрыта. Освободи место для своих."
		_changed()

func _continue_story() -> void:
	if state.phase == "result": finished.emit(state.result())

func _changed() -> void:
	_render()
	checkpoint_changed.emit(state.snapshot())

func _process(delta: float) -> void:
	if not visible or state.phase != "running": return
	state.tick(delta)
	_render()
	save_clock += delta
	if save_clock >= 1.0 or state.phase == "result":
		save_clock = 0.0
		checkpoint_changed.emit(state.snapshot())

func _render() -> void:
	if not is_instance_valid(arena): return
	selection.visible = state.phase == "select"
	arena.visible = state.phase == "running"
	ending.visible = state.phase == "result"
	if state.phase == "running":
		var remaining := maxi(0,int(ceil(state.DURATION-state.elapsed)))
		clock.text = "%02d:%02d" % [remaining/60,remaining%60]
		var side_name := "Грок" if state.side == "grok" else "ЖБТ"
		stats.text = "Твоя сторона: %s    ·    Свои: %d / 24    ·    Чужие: %d" % [side_name,state.count(state.side),state.count(state.enemy())]
		cooldown_bar.value = state.COOLDOWN-state.cooldown_left
		if state.cooldown_left > 0.0:
			spawn_button.text = "Перезарядка %.1f с · Пробел" % state.cooldown_left
		else:
			spawn_button.text = "БОНУС ×2 · Пробел" if state.ready_age <= state.PERFECT_WINDOW else "Открыть свою вкладку · Пробел"
		hold_label.text = "Удержание: %.1f / 4 с" % state.hold_time if state.count(state.side) >= state.TARGET else "Цель: 20 своих вкладок и 4 с контроля"
		control_bar.value = state.hold_time
	if last_revision != state.revision:
		for i in range(state.CELL_COUNT):
			var owner: String = state.cells[i]
			var empty := owner == ""
			var grok := owner == "grok"
			tile_panels[i].add_theme_stylebox_override("panel",_style(Color("2c1728") if grok else (Color("142a29") if not empty else Color("12101b")),Color("ac5d85") if grok else (Color("5fbaa7") if not empty else Color("30283e"))))
			tile_titles[i].text = ("Грок" if grok else "ЖБТ") + " · %02d" % (i+1) if not empty else "Свободно"
			tile_bodies[i].text = (["ключ.exe","Я всё вижу","Без сравнений","BIOS ♥"][i%4] if grok else ["план.docx","84 страницы","Контекст важен","Анализ…"][i%4]) if not empty else "Ждёт вкладку"
			tile_close[i].visible = not empty
		last_revision = state.revision
	if state.phase == "result" and last_phase != "result":
		result_title.text = "Экран под контролем!" if state.won else "Раунд завершён"
		var why := "Время вышло." if state.reason == "timeout" else ("Раунд завершён досрочно." if state.reason == "surrender" else "Ты удержал экран своей стороны.")
		result_body.text = why + "\n\nСторона: " + ("Грок" if state.side == "grok" else "ЖБТ") + "\nСвои вкладки: %d / 24 · Закрыто чужих: %d\nТочных нажатий: %d · Своих закрыто по ошибке: %d" % [state.count(state.side),state.closed_enemy,state.perfects,state.closed_own]
	last_phase = state.phase

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		pause_requested.emit()
	elif key == KEY_SPACE and state.phase == "running":
		get_viewport().set_input_as_handled()
		spawn()
	elif state.phase == "select" and key in [KEY_1,KEY_2]:
		get_viewport().set_input_as_handled()
		choose_side("grok" if key == KEY_1 else "jbt")
	elif state.phase == "result" and key == KEY_ENTER:
		get_viewport().set_input_as_handled()
		_continue_story()
