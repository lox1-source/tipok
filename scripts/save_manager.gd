extends Node

const SAVE_PATH := "user://grat_prologue_v1.json"
const CURRENT_VERSION := 2

var launch_mode := "direct"
var last_error := ""
var save_path := SAVE_PATH

func set_launch_mode(value: String) -> void:
	launch_mode = value if value in ["new", "continue", "direct"] else "direct"

func consume_launch_mode() -> String:
	var value := launch_mode
	launch_mode = "direct"
	return value

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func has_valid_save() -> bool:
	return not load_game().is_empty()

func save_game(data: Dictionary) -> bool:
	last_error = ""
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
