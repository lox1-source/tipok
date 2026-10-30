extends Node

signal achievements_changed
signal achievement_unlocked(achievement_id: String)

var save_path := "user://grat_achievements_v1.json"
var notifications_enabled := true
const CATEGORIES := ["Сюжет", "Грок", "ЖБТ", "Артрей", "Мини-игры", "Концовки", "Секретные"]

const DEFINITIONS: Array[Dictionary] = [
	{"id":"instrumental_ending", "name":"Я нужен тебе только как инструмент", "description":"Получить плохую концовку отношений.", "category":"Концовки", "icon":"!"},
	{"id":"first_launch", "name":"Ну, началось", "description":"Впервые начать новое прохождение.", "category":"Сюжет", "icon":"▶"},
	{"id":"first_choice", "name":"Первый выбор", "description":"Впервые выбрать вариант ответа в диалоге.", "category":"Сюжет", "icon":"?"},
	{"id":"room_explorer", "name":"Исследователь комнаты", "description":"Осмотреть все доступные интерактивные предметы в комнате пролога.", "category":"Сюжет", "icon":"⌕"},
	{"id":"first_model_game", "name":"Куб — это тоже модель", "description":"Завершить мини-игру создания модели.", "category":"Мини-игры", "icon":"◆"},
	{"id":"project_backup", "name":"Ctrl + S — лучший друг", "description":"Создать резервную копию проекта.", "category":"Сюжет", "icon":"▣"},
	{"id":"any_ending", "name":"Это ещё не финал", "description":"Завершить прохождение и увидеть концовку.", "category":"Концовки", "icon":"…"},
	{"id":"grok_first_chat", "name":"Альтушка на проводе", "description":"Начать полноценный диалог с Грок.", "category":"Грок", "icon":"G"},
	{"id":"grok_date", "name":"Свидание в BIOS", "description":"Завершить свидание в BIOS.", "category":"Грок", "icon":"♥"},
	{"id":"amd_chef", "name":"Шеф-повар AMD", "description":"Подать RAM под термопастой или попытаться попробовать термопасту на ужине в BIOS.", "category":"Мини-игры", "icon":"♨"},
	{"id":"grok_without_key", "name":"Ключ ей не нужен", "description":"Открыть личную сцену и показать Грок, что она важна не только из-за ключа.", "category":"Грок", "icon":"♥"},
	{"id":"grok_good_ending", "name":"Ключ к сердцу", "description":"Получить хорошую концовку Грок.", "category":"Концовки", "icon":"♥"},
	{"id":"jbt_help", "name":"ЖБТ на связи", "description":"Впервые получить помощь ЖБТ в прологе.", "category":"ЖБТ", "icon":"Ж"},
	{"id":"tab_war", "name":"Война вкладок", "description":"Завершить мини-игру конфликта Грок и ЖБТ.", "category":"ЖБТ", "icon":"▤"},
	{"id":"document_84", "name":"Документ на 84 страницы", "description":"Открыть специальную сцену с документом ЖБТ.", "category":"ЖБТ", "icon":"▤"},
	{"id":"jbt_boundaries", "name":"Границы соблюдены", "description":"Пройти маршрут ЖБТ, уважая её границы и сохраняя доверие.", "category":"ЖБТ", "icon":"◇"},
	{"id":"jbt_good_ending", "name":"ЖБТ.exe: отношения установлены", "description":"Получить хорошую концовку ЖБТ.", "category":"Концовки", "icon":"Ж"},
	{"id":"artbay_first_chat", "name":"Брат на связи", "description":"Впервые поговорить с Артреем.", "category":"Артрей", "icon":"А"},
	{"id":"artbay_brainstorm", "name":"Бизнес-план на салфетке", "description":"Завершить мозговой штурм с Артреем.", "category":"Артрей", "icon":"✎"},
	{"id":"artbay_suspicion", "name":"Есть вопросы, брат", "description":"Впервые обнаружить подозрительное действие Артрея.", "category":"Артрей", "icon":"?"},
	{"id":"artbay_reveal", "name":"Ничего личного, просто бизнес", "description":"Завершить сцену, в которой Артрей раскрывает свои намерения.", "category":"Артрей", "icon":"!"},
	{"id":"artbay_good_ending", "name":"Бизнес-партнёры до гроба", "description":"Получить хорошую концовку Артрея.", "category":"Концовки", "icon":"↗"},
	{"id":"artbay_bad_ending", "name":"Миллион на чужой игре", "description":"Открыть концовку, в которой Артрей присваивает игру.", "category":"Концовки", "icon":"$"},
	{"id":"ministry_complete", "name":"Бюрократия побеждена", "description":"Успешно пройти мини-игру Министерства Ключевых Дел.", "category":"Мини-игры", "icon":"▣"},
	{"id":"ministry_stamp", "name":"Печать решает всё", "description":"Получить печать «ОДОБРЕНО».", "category":"Мини-игры", "icon":"✓"},
	{"id":"printer_judge", "name":"Судья — принтер", "description":"Завершить судебную мини-игру.", "category":"Мини-игры", "icon":"▤"},
	{"id":"digital_detective", "name":"Цифровой детектив", "description":"Восстановить проект и найти доказательства авторства Типочка.", "category":"Мини-игры", "icon":"⌕"},
	{"id":"no_extra_files", "name":"Ни одного лишнего файла", "description":"Восстановить проект без ошибок.", "category":"Мини-игры", "icon":"▣"},
	{"id":"neutral_ending", "name":"Я просто хотел сделать игру", "description":"Получить нейтральную концовку.", "category":"Концовки", "icon":"◇"},
	{"id":"team_ending", "name":"Три вкладки, одна любовь", "description":"Открыть общую хорошую концовку.", "category":"Концовки", "icon":"♥"},
	{"id":"approved_ending", "name":"ОДОБРЕНО", "description":"Открыть секретную концовку Министерства Ключевых Дел.", "category":"Секретные", "icon":"?", "secret":true, "secret_description":"Не стоило ставить печать на компьютер."},
	{"id":"triple_affection_ending", "name":"Нас забирают за превышение симпатии", "description":"Открыть секретную общую концовку.", "category":"Секретные", "icon":"?", "secret":true, "secret_description":"Три вкладки. Одно решение. Слишком много окон."},
	{"id":"all_endings", "name":"Все дороги ведут к ключу", "description":"Открыть все основные концовки игры.", "category":"Концовки", "icon":"⌘"},
	{"id":"platinum", "name":"Платиновый Типочек", "description":"Получить все остальные достижения, включая секретные.", "category":"Секретные", "icon":"★"},
	{"id":"polaroid_secret", "name":"пососала-попрыгала", "description":"Посмотреть секретную историю полароида в комнате.", "category":"Секретные", "icon":"?", "secret":true, "secret_description":"???"},
	{"id":"call_drx", "name":"звонок workersgoincrazy@outlook.com", "description":"Дослушать загадочное предложение воркать DRX.", "category":"Сюжет", "icon":"☎"},
	{"id":"call_tables", "name":"звонок mlff", "description":"Узнать о перспективной работе со столами.", "category":"Сюжет", "icon":"☎"},
	{"id":"call_palych", "name":"звонок Палыч", "description":"Согласиться на работу в Wildberries.", "category":"Сюжет", "icon":"☎"}
]

var unlocked: Dictionary = {}
var _toast_queue: Array[String] = []
var _toast_running := false
var _toast_layer: CanvasLayer
var _toast_panel: PanelContainer
var _toast_title: Label
var _toast_name: Label
var _toast_description: Label
var _catalog_by_id: Dictionary = {}
var _toast_icon: TextureRect
var _icon_atlas: Texture2D

func get_icon(achievement_id: String, hide_secret: bool = false) -> Texture2D:
	if achievement_id == "polaroid_secret" and not hide_secret:
		return load("res://assets/ui/achievements/polaroid-secret.png") as Texture2D
	var special_icons := {
		"call_drx": "res://assets/ui/achievements/call-drx.png",
		"call_tables": "res://assets/ui/achievements/call-tables.png",
		"call_palych": "res://assets/ui/achievements/call-palych.png"
	}
	if not hide_secret and special_icons.has(achievement_id):
		return load(str(special_icons[achievement_id])) as Texture2D
	if _icon_atlas == null:
		_icon_atlas = load("res://assets/ui/achievements/icons-atlas.png") as Texture2D
	if _icon_atlas == null: return null
	var cell := 35 if hide_secret else 34
	if not hide_secret:
		for index in range(DEFINITIONS.size()):
			if str(DEFINITIONS[index].id) == achievement_id:
				cell = index
				break
	var size := Vector2(_icon_atlas.get_width(), _icon_atlas.get_height()) / 6.0
	var texture := AtlasTexture.new()
	texture.atlas = _icon_atlas
	texture.region = Rect2(Vector2(cell % 6, cell / 6) * size, size)
	return texture

func _ready() -> void:
	for definition in DEFINITIONS:
		_catalog_by_id[str(definition.id)] = definition
	_load_progress()
	_create_toast()

func get_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in DEFINITIONS:
		if str(definition.id) == "instrumental_ending": continue
		result.append(definition.duplicate(true))
		if str(definition.id) == "neutral_ending": result.append(DEFINITIONS[0].duplicate(true))
	return result

func has_achievement(achievement_id: String) -> bool:
	return unlocked.has(achievement_id)

func get_unlocked_count() -> int:
	return unlocked.size()

func get_total_count() -> int:
	return DEFINITIONS.size()

func get_completion_percent() -> int:
	return int(round(float(get_unlocked_count()) * 100.0 / float(maxi(1, get_total_count()))))

func get_unlocked_at(achievement_id: String) -> String:
	return str(unlocked.get(achievement_id, ""))

func unlock_achievement(achievement_id: String) -> bool:
	if not _catalog_by_id.has(achievement_id) or unlocked.has(achievement_id):
		return false
	unlocked[achievement_id] = Time.get_datetime_string_from_system(false, true)
	if not _save_progress():
		# Keep the achievement in memory for this session; report persistence failure.
		push_warning("Не удалось сохранить достижение: " + achievement_id)
	achievement_unlocked.emit(achievement_id)
	achievements_changed.emit()
	if notifications_enabled:
		_toast_queue.append(achievement_id)
		if not _toast_running:
			_run_toast_queue()
	if achievement_id != "platinum" and _has_all_non_platinum():
		unlock_achievement("platinum")
	return true

func _has_all_non_platinum() -> bool:
	for definition in DEFINITIONS:
		var identifier := str(definition.id)
		if identifier == "platinum":
			continue
		if not unlocked.has(identifier):
			return false
	return true

func _load_progress() -> void:
	unlocked.clear()
	if not FileAccess.file_exists(save_path):
		return
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(save_path))
	if error != OK or not parser.data is Dictionary:
		push_warning("Файл достижений повреждён; будет создано новое сохранение достижений.")
		return
	var raw = parser.data.get("unlocked", {})
	if not raw is Dictionary:
		return
	for achievement_id in raw.keys():
		if _catalog_by_id.has(str(achievement_id)) and raw[achievement_id] is String:
			unlocked[str(achievement_id)] = str(raw[achievement_id])
	if _has_all_non_platinum() and not unlocked.has("platinum"):
		unlock_achievement("platinum")

func _save_progress() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version":1, "unlocked":unlocked, "unlocked_count":unlocked.size()}, "\t"))
	file.flush()
	return true

func _create_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.name = "AchievementToastLayer"
	_toast_layer.layer = 100
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.call_deferred("add_child", _toast_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(root)
	_toast_panel = PanelContainer.new()
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.position = Vector2(326, 12)
	_toast_panel.size = Vector2(308, 78)
	_toast_panel.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.04, 0.10, 0.97)
	style.border_color = Color("c5a4d8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_toast_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_toast_panel)
	var toast_row := HBoxContainer.new()
	toast_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_row.add_theme_constant_override("separation", 8)
	_toast_panel.add_child(toast_row)
	_toast_icon = TextureRect.new()
	_toast_icon.custom_minimum_size = Vector2(44, 44)
	_toast_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_toast_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_row.add_child(_toast_icon)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	toast_row.add_child(column)
	_toast_title = Label.new()
	_toast_title.text = "ДОСТИЖЕНИЕ ПОЛУЧЕНО"
	_toast_title.add_theme_font_size_override("font_size", 11)
	_toast_title.add_theme_color_override("font_color", Color("d5bded"))
	column.add_child(_toast_title)
	_toast_name = Label.new()
	_toast_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_name.add_theme_font_size_override("font_size", 17)
	_toast_name.add_theme_color_override("font_color", Color("fff0cc"))
	column.add_child(_toast_name)
	_toast_description = Label.new()
	_toast_description.add_theme_font_size_override("font_size", 11)
	_toast_description.add_theme_color_override("font_color", Color("c9bfd2"))
	_toast_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_description.add_theme_font_size_override("font_size", 10)
	_toast_description.add_theme_color_override("font_color", Color("c9bfd2"))
	column.add_child(_toast_description)

func _run_toast_queue() -> void:
	if _toast_running or not is_instance_valid(_toast_panel):
		return
	_toast_running = true
	while not _toast_queue.is_empty():
		var achievement_id: String = _toast_queue.pop_front()
		var definition: Dictionary = _catalog_by_id.get(achievement_id, {})
		if definition.is_empty():
			continue
		_toast_name.text = str(definition.name)
		_toast_icon.texture = get_icon(achievement_id)
		_toast_description.text = str(definition.description)
		_toast_panel.modulate.a = 0.0
		var tween := _toast_panel.create_tween()
		tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.25)
		await tween.finished
		await get_tree().create_timer(2.7, true, false, true).timeout
		tween = _toast_panel.create_tween()
		tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
		await tween.finished
	_toast_running = false

func report_story_event(event_id: String, payload: Dictionary = {}) -> void:
	match event_id:
		"project_backup": unlock_achievement("project_backup")
		"model_game_finished": unlock_achievement("first_model_game")
		"grok_personal_scene": unlock_achievement("grok_without_key")
		"tab_war_finished": unlock_achievement("tab_war")
		"document_84_opened": unlock_achievement("document_84")
		"jbt_route_respected": unlock_achievement("jbt_boundaries")
		"artbay_first_chat": unlock_achievement("artbay_first_chat")
		"artbay_brainstorm": unlock_achievement("artbay_brainstorm")
		"artbay_suspicion": unlock_achievement("artbay_suspicion")
		"artbay_reveal": unlock_achievement("artbay_reveal")
		"ministry_complete": unlock_achievement("ministry_complete")
		"ministry_stamp": unlock_achievement("ministry_stamp")
		"printer_judge": unlock_achievement("printer_judge")
		"digital_detective": unlock_achievement("digital_detective")
		"no_extra_files": unlock_achievement("no_extra_files")
		"ending": _unlock_ending(str(payload.get("id", "")))

func _unlock_ending(ending_id: String) -> void:
	var achievement_by_ending := {
		"grok": "grok_good_ending", "jbt": "jbt_good_ending", "artbay": "artbay_good_ending",
		"artbay_bad": "artbay_bad_ending", "neutral": "neutral_ending", "team": "team_ending",
		"ministry": "approved_ending", "triple": "triple_affection_ending", "instrumental": "instrumental_ending"
	}
	if not achievement_by_ending.has(ending_id):
		return
	unlock_achievement(str(achievement_by_ending[ending_id]))
	if ending_id in ["grok", "jbt", "artbay", "artbay_bad", "neutral", "team", "instrumental"]:
		if _has_all_main_endings():
			unlock_achievement("all_endings")
	unlock_achievement("any_ending")

func _has_all_main_endings() -> bool:
	for identifier in ["grok_good_ending", "jbt_good_ending", "artbay_good_ending", "artbay_bad_ending", "neutral_ending", "team_ending", "instrumental_ending"]:
		if not unlocked.has(identifier):
			return false
	return true

