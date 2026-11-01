extends SceneTree

const SAVE := "res://tests/phone_drafts_temp.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error(description)

func find_button(panel: Control, caption: String) -> Button:
	for button in panel.find_children("*", "Button", true, false):
		for child in button.get_children():
			if child is Label and child.text == caption:
				return button
	return null

func has_message(panel: Control, fragment: String) -> bool:
	for label in panel.find_children("*", "RichTextLabel", true, false):
		if fragment in label.text:
			return true
	return false

func run() -> void:
	var save_manager: Node = root.get_node("SaveManager")
	var old_dev_session: bool = save_manager.dev_session
	var achievements: Node = root.get_node("AchievementManager")
	var old_notifications: bool = achievements.notifications_enabled
	achievements.notifications_enabled = false
	save_manager.set_dev_chapter(1)
	var game: Node = load("res://Prologue.tscn").instantiate()
	game.save_path = SAVE
	root.add_child(game)
	await process_frame
	game.vn.close()
	game.dialogue_open = false
	game.mode = "room"
	game.show_friends_chat("draft_grok")
	check(game.phone_panel.find_child("ContactAvatar", true, false) == null, "Экран заметок не показывает аватар контакта")
	check(game.phone_notes_open, "Черновик открывается как отдельная заметка")
	check(find_button(game.phone_panel, "Написать честно  →") != null, "Черновик предлагает честный ответ")
	check(find_button(game.phone_panel, "Отправить шутку") != null, "Черновик предлагает шутку")
	var honest_button := find_button(game.phone_panel, "Написать честно  →")
	if honest_button != null:
		honest_button.pressed.emit()
	check(str(game.story.decisions.get("phone_draft_grok", "")) == "honest", "Отправленный черновик сохраняет выбор")
	check(has_message(game.phone_panel, "боюсь снова бросить"), "Чат Грок показывает отправленный текст")
	check(game.phone_panel.find_child("ContactAvatar", true, false) is TextureRect, "У Грок круглая фотоаватарка")
	var grok_avatar: TextureRect = game.phone_panel.find_child("ContactAvatar", true, false) as TextureRect
	check(grok_avatar != null and grok_avatar.texture != null and grok_avatar.material is ShaderMaterial, "Портрет Грок загружен и обрезан круглой маской")
	game._phone_send_draft("grok", "joke")
	check(str(game.story.decisions.get("phone_draft_grok", "")) == "honest", "Повторная отправка не меняет решение")
	game.show_friends_chat("draft_jbt")
	var joke_button := find_button(game.phone_panel, "Отправить шутку")
	if joke_button != null:
		joke_button.pressed.emit()
	check(str(game.story.decisions.get("phone_draft_jbt", "")) == "joke", "Черновик для ЖБТ сохраняется отдельно")
	check(has_message(game.phone_panel, "табуретка"), "Чат ЖБТ меняется после отправки")
	check(game.phone_panel.find_child("ContactAvatar", true, false) is TextureRect, "У ЖБТ круглая фотоаватарка")
	game.story.set_value("old_project_notes_found", true)
	game.show_friends_chat("artrey")
	check(has_message(game.phone_panel, "журнал доступа"), "Чат Артрея обновляется после находки старой копии")
	check(game.phone_panel.find_child("ContactAvatar", true, false) is TextureRect, "У Артрея круглая фотоаватарка")
	game.story.set_value("artbay_betrayal", true)
	game.show_friends_chat("artrey")
	check(has_message(game.phone_panel, "Поговорим лично"), "Чат Артрея отражает конфликт")
	check(FileAccess.file_exists(SAVE), "Решения записаны в отдельное тестовое сохранение")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE)) if FileAccess.file_exists(SAVE) else {}
	var restored: RefCounted = load("res://scripts/story_state.gd").new()
	if raw is Dictionary:
		restored.import_data(raw.get("story", {}))
	check(str(restored.decisions.get("phone_draft_grok", "")) == "honest" and str(restored.decisions.get("phone_draft_jbt", "")) == "joke", "Оба выбора восстанавливаются из сохранения")
	var back_button := find_button(game.phone_panel, "‹")
	check(back_button != null, "На телефоне есть кнопка возврата")
	if back_button != null:
		back_button.pressed.emit()
		check(game.mode == "room" and not game.phone_panel.visible, "Кнопка возврата закрывает телефон")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	save_manager.dev_session = old_dev_session
	achievements.notifications_enabled = old_notifications
	print("PHONE DRAFTS: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
