extends Node

const SAVE_PATH := "user://grat_prologue_v1.json"
const CURRENT_VERSION := 2

var launch_mode := "direct"
var dev_chapter := 0
var dev_session := false
var dev_call_event := ""
var dev_minigame := ""
var dev_credits := false
var dev_ending := ""
var reopen_dev_picker := false
var last_error := ""
var save_path := SAVE_PATH

func set_launch_mode(value: String) -> void:
	launch_mode = value if value in ["new", "continue", "direct"] else "direct"
	dev_session = false

func consume_launch_mode() -> String:
	var value := launch_mode
	launch_mode = "direct"
	return value

func set_dev_chapter(chapter: int) -> void:
	dev_chapter = clampi(chapter, 0, 7)
	dev_call_event = ""
	dev_minigame = ""
	dev_credits = false
	dev_ending = ""
	dev_session = dev_chapter > 0
	launch_mode = "direct"

func consume_dev_chapter() -> int:
	var value := dev_chapter
	dev_chapter = 0
	return value

func set_dev_call_event(event_id: String) -> void:
	dev_chapter = 0
	dev_minigame = ""
	dev_credits = false
	dev_ending = ""
	dev_call_event = event_id if event_id in ["call_drx", "call_tables", "call_palych"] else ""
	dev_session = not dev_call_event.is_empty()
	launch_mode = "direct"

func consume_dev_call_event() -> String:
	var value := dev_call_event
	dev_call_event = ""
	return value

func set_dev_minigame(game_id: String) -> void:
	dev_chapter = 0
	dev_call_event = ""
	dev_credits = false
	dev_ending = ""
	dev_minigame = game_id if game_id in ["doodle_jump", "tab_war", "wire_puzzle", "digital_archaeology", "office_queue", "court_trial", "hotdog_master"] else ""
	dev_session = not dev_minigame.is_empty()
	launch_mode = "direct"

func consume_dev_minigame() -> String:
	var value := dev_minigame
	dev_minigame = ""
	return value

func set_dev_credits() -> void:
	dev_chapter = 0
	dev_call_event = ""
	dev_minigame = ""
	dev_ending = ""
	dev_credits = true
	dev_session = true
	launch_mode = "direct"

func consume_dev_credits() -> bool:
	var value := dev_credits
	dev_credits = false
	return value

func set_dev_ending(ending_id: String) -> void:
	dev_chapter = 0
	dev_call_event = ""
	dev_minigame = ""
	dev_credits = false
	dev_ending = ending_id if ending_id in ["grok", "jbt", "artbay", "artbay_bad", "team", "ministry", "triple", "neutral", "instrumental"] else ""
	dev_session = not dev_ending.is_empty()
	launch_mode = "direct"

func consume_dev_ending() -> String:
	var value := dev_ending
	dev_ending = ""
	return value

func request_dev_picker_reopen() -> void:
	reopen_dev_picker = true

func consume_dev_picker_reopen() -> bool:
	var value := reopen_dev_picker
	reopen_dev_picker = false
	return value

func is_dev_session() -> bool:
	return dev_session

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func has_valid_save() -> bool:
	return not load_game().is_empty()

func save_game(data: Dictionary) -> bool:
	last_error = ""
	if dev_session:
		return true
	var payload := data.duplicate(true)
	payload["version"] = CURRENT_VERSION
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		last_error = "Не удалось открыть файл сохранения."
		push_error(last_error)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	return true

func load_game() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(save_path):
		return {}
	var text := FileAccess.get_file_as_string(save_path)
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		last_error = "Сохранение повреждено: ошибка данных в строке %d." % parser.get_error_line()
		return {}
	var data = parser.data
	if not data is Dictionary:
		last_error = "Сохранение повреждено: файл не содержит корректные данные."
		return {}
	var version := int(data.get("version", 0))
	if version not in [1, CURRENT_VERSION]:
		last_error = "Сохранение создано несовместимой версией игры."
		return {}
	if not data.has("step") or not data.has("intro_seen"):
		last_error = "Сохранение повреждено: отсутствуют данные прогресса."
		return {}
	return data

func clear_save() -> bool:
	last_error = ""
	if not FileAccess.file_exists(save_path):
		return true
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if error != OK:
		last_error = "Не удалось сбросить старое сохранение."
		return false
	return true
