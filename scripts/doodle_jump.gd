extends Control

const GRAVITY := 760.0
const JUMP_SPEED := -360.0
const PLAYER_SIZE := Vector2(20, 25)
const PLATFORM_WIDTH := 68.0
const PLATFORM_GAP_MIN := 48.0
const PLATFORM_GAP_MAX := 56.0
const PLATFORM_MAX_DRIFT := 96.0
const GRAT_SPRITE := preload("res://assets/sprites/minigames/4fr-jump.png")
const GRAT_SOURCE_RECT := Rect2(236.0, 84.0, 804.0, 1044.0)

var _rng := RandomNumberGenerator.new()
var _platforms: Array[Rect2] = []
var _stars: Array[Vector2] = []
var _player := Vector2.ZERO
var _velocity := Vector2.ZERO
var _facing_left := false
var _camera_y := 0.0
var _highest_platform_y := 0.0
var _start_y := 0.0
var _score := 0
var _best_score := 0
var _game_over := false
var _play_area := Rect2()

func _ready() -> void:
	_rng.randomize()
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_reset_game()
	grab_focus()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _game_over:
		return
	var direction := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction += 1.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_x := get_local_mouse_position().x
		if mouse_x < size.x * 0.42:
			direction = -1.0
		elif mouse_x > size.x * 0.58:
			direction = 1.0
	if direction != 0.0:
		_facing_left = direction < 0.0
	_velocity.x = move_toward(_velocity.x, direction * 205.0, 1150.0 * delta)
	var previous_bottom := _player.y + PLAYER_SIZE.y
	_velocity.y += GRAVITY * delta
	_player += _velocity * delta
	var left_edge := _play_area.position.x
	var right_edge := _play_area.end.x - PLAYER_SIZE.x
	if _player.x < left_edge:
		_player.x = right_edge
	elif _player.x > right_edge:
		_player.x = left_edge
	if _velocity.y > 0.0:
		var next_bottom := _player.y + PLAYER_SIZE.y
		for platform in _platforms:
			var overlaps_x := _player.x + PLAYER_SIZE.x - 3.0 > platform.position.x and _player.x + 3.0 < platform.end.x
			if overlaps_x and previous_bottom <= platform.position.y + 2.0 and next_bottom >= platform.position.y:
				_player.y = platform.position.y - PLAYER_SIZE.y
				_velocity.y = JUMP_SPEED
				break
	if _player.y - _camera_y < _play_area.position.y + 82.0:
		_camera_y = _player.y - (_play_area.position.y + 82.0)
	_score = maxi(_score, int(maxf(0.0, _start_y - _player.y) / 8.0))
	_best_score = maxi(_best_score, _score)
	_generate_platforms()
	_platforms = _platforms.filter(func(platform: Rect2) -> bool: return platform.end.y - _camera_y < _play_area.end.y + 48.0)
	if _player.y - _camera_y > _play_area.end.y + 24.0:
		_game_over = true
	queue_redraw()

func _reset_game() -> void:
	_play_area = Rect2(8.0, 34.0, maxf(1.0, size.x - 16.0), maxf(1.0, size.y - 42.0))
	_platforms.clear()
	_stars.clear()
	_camera_y = 0.0
	_score = 0
	_game_over = false
	_facing_left = false
	_start_y = _play_area.end.y - 34.0
	_player = Vector2(size.x * 0.5 - PLAYER_SIZE.x * 0.5, _start_y - PLAYER_SIZE.y)
	_velocity = Vector2(0.0, JUMP_SPEED)
	var base := Rect2(size.x * 0.5 - 46.0, _start_y + 8.0, 92.0, 11.0)
	_platforms.append(base)
	_highest_platform_y = base.position.y
	var previous_platform := base
	for row in range(1, 5):
		var y := previous_platform.position.y - _rng.randf_range(PLATFORM_GAP_MIN, PLATFORM_GAP_MAX)
		previous_platform = _make_platform_above(previous_platform, y)
		_platforms.append(previous_platform)
		_highest_platform_y = minf(_highest_platform_y, previous_platform.position.y)
	for _index in range(35):
		_stars.append(Vector2(_rng.randf_range(15.0, size.x - 15.0), _rng.randf_range(38.0, size.y - 14.0)))
	_generate_platforms()
	grab_focus()
	queue_redraw()

func _generate_platforms() -> void:
	var target_top := _camera_y + _play_area.position.y - 76.0
	while _highest_platform_y > target_top:
		var previous_platform: Rect2 = _platforms.back()
		_highest_platform_y -= _rng.randf_range(PLATFORM_GAP_MIN, PLATFORM_GAP_MAX)
		_platforms.append(_make_platform_above(previous_platform, _highest_platform_y))

func _make_platform_above(previous: Rect2, y: float) -> Rect2:
	var min_x := _play_area.position.x + 6.0
	var max_x := _play_area.end.x - PLATFORM_WIDTH - 6.0
	var min_center := min_x + PLATFORM_WIDTH * 0.5
	var max_center := max_x + PLATFORM_WIDTH * 0.5
	var previous_center := previous.position.x + previous.size.x * 0.5
	var center_x := clampf(previous_center + _rng.randf_range(-PLATFORM_MAX_DRIFT, PLATFORM_MAX_DRIFT), min_center, max_center)
	var x := center_x - PLATFORM_WIDTH * 0.5
	return Rect2(x, y, PLATFORM_WIDTH, 9.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if _game_over and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_R]:
		_reset_game()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
		if _game_over:
			_reset_game()
			accept_event()

func _draw() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("100d1e")
	frame.border_color = Color("806991")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(8)
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	draw_rect(_play_area, Color("101629"), true)
	draw_rect(_play_area, Color("302845"), false, 1.0)
	for star in _stars:
		var screen_y := fposmod(star.y - _camera_y * 0.18, maxf(_play_area.size.y, 1.0)) + _play_area.position.y
		draw_rect(Rect2(Vector2(star.x, screen_y), Vector2(2, 2)), Color(0.68, 0.62, 0.81, 0.48), true)
	draw_string(ThemeDB.fallback_font, Vector2(20, 24), "4fr JUMP", HORIZONTAL_ALIGNMENT_LEFT, 180, 13, Color("e4d3f1"))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 110, 24), "ВЫСОТА %04d" % _score, HORIZONTAL_ALIGNMENT_RIGHT, 90, 11, Color("e4d3f1"))
	for platform in _platforms:
		var rect := Rect2(platform.position.x, platform.position.y - _camera_y, platform.size.x, platform.size.y)
		var shadow_rect := rect.grow(1.0)
		if shadow_rect.position.x < _play_area.position.x or shadow_rect.end.x > _play_area.end.x:
			continue
		if shadow_rect.position.y < _play_area.position.y or shadow_rect.end.y > _play_area.end.y:
			continue
		draw_rect(shadow_rect, Color("080b14"), true)
		draw_rect(rect, Color("6b537d"), true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), Color("b9a2cb"), true)
		draw_rect(Rect2(rect.position + Vector2(5, 4), Vector2(12, 2)), Color("8a718f"), true)
	var grat_draw_size := Vector2(26.0, 34.0)
	var grat_draw_position := Vector2(_player.x - 3.0, _player.y - _camera_y - 4.0)
	if _facing_left:
		draw_set_transform(grat_draw_position + Vector2(grat_draw_size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(GRAT_SPRITE, Rect2(Vector2.ZERO, grat_draw_size), GRAT_SOURCE_RECT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect_region(GRAT_SPRITE, Rect2(grat_draw_position, grat_draw_size), GRAT_SOURCE_RECT)
	if _game_over:
		draw_rect(_play_area, Color(0.025, 0.02, 0.05, 0.82), true)
		draw_string(ThemeDB.fallback_font, Vector2(0, _play_area.position.y + _play_area.size.y * 0.43), "ПРЫЖОК ОКОНЧЕН", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color("f0e8ff"))
		draw_string(ThemeDB.fallback_font, Vector2(0, _play_area.position.y + _play_area.size.y * 0.57), "Высота: %d   ·   Рекорд: %d" % [_score, _best_score], HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("d6c7e4"))
		draw_string(ThemeDB.fallback_font, Vector2(0, _play_area.position.y + _play_area.size.y * 0.70), "Пробел / R или клик — ещё раз", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("d6c7e4"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(_play_area.position.x + 10.0, _play_area.end.y - 8.0), "← / A", HORIZONTAL_ALIGNMENT_LEFT, 54, 11, Color("c4b3d3"))
		draw_string(ThemeDB.fallback_font, Vector2(_play_area.end.x - 62.0, _play_area.end.y - 8.0), "D / →", HORIZONTAL_ALIGNMENT_RIGHT, 54, 11, Color("c4b3d3"))

