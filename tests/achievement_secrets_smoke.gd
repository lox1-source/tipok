extends SceneTree

var failures: Array[String] = []
var played_sounds: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error(message)

func _record_sound(achievement_id: String, is_secret: bool, path: String) -> void:
	played_sounds.append({"id":achievement_id, "secret":is_secret, "path":path})

func _catalog_item(catalog: Array[Dictionary], achievement_id: String) -> Dictionary:
	for item in catalog:
		if str(item.get("id", "")) == achievement_id:
			return item
	return {}

func run() -> void:
	var manager: Variant = root.get_node("AchievementManager")
	var audio: Variant = root.get_node("AudioManager")
	var old_unlocked: Dictionary = manager.unlocked.duplicate(true)
	var old_path: String = manager.save_path
	var old_notifications: bool = manager.notifications_enabled
	var old_queue: Array[String] = manager._toast_queue.duplicate()
	var old_toast_running: bool = manager._toast_running
	var save_path := "res://tests/achievement_secrets_isolated_%d.json" % Time.get_ticks_usec()
	manager.save_path = save_path
	manager.notifications_enabled = false
	manager.unlocked.clear()
	manager._toast_queue.clear()
	manager._toast_running = false
	played_sounds.clear()
	audio.achievement_sound_started.connect(_record_sound)

	var ending_ids: Array[String] = []
	var unique_ids := {}
	for definition in manager.DEFINITIONS:
		var id := str(definition.id)
		check(not unique_ids.has(id), "нет дубликата ID: " + id)
		unique_ids[id] = true
		if str(definition.category) == "Концовки":
			ending_ids.append(id)
			check(bool(definition.get("secret", false)), "достижение концовки секретное: " + id)
	for id in ["call_tables", "call_palych", "call_drx"]:
		var call_def: Dictionary = manager._catalog_by_id[id]
		check(bool(call_def.get("secret", false)), "звонок отмечен секретным: " + id)
		check(str(call_def.category) == "Сюжет", "звонок остался в категории сюжета: " + id)
	check(str(manager._catalog_by_id["call_drx"].name) == "звонок workersgoincrazy@outlook.com", "почта в названии хранится обычным текстом")
	check(FileAccess.file_exists("res://assets/audio/achievement.ogg"), "обычный звук достижения существует")
	check(FileAccess.file_exists("res://assets/audio/achievement_rare.ogg"), "редкий звук достижения существует")

	var catalog: Array[Dictionary] = manager.get_catalog()
	var question_region: Rect2 = manager.get_icon("first_choice").region
	for definition in catalog:
		var id := str(definition.id)
		if bool(definition.get("secret", false)):
			check(str(definition.name) == "???" and str(definition.description) == "???", "закрытое достижение скрывает текст: " + id)
			check(not definition.has("secret_description"), "из каталога удалена подсказка: " + id)
			var hidden_icon: Texture2D = manager.get_icon(id)
			check(hidden_icon is AtlasTexture and hidden_icon.region != question_region, "закрытый секрет показывает отдельный знак вопроса: " + id)
	check(manager.get_icon("call_drx", true).region == manager.get_icon("call_tables").region, "секретные звонки используют один знак вопроса")
	check(manager.get_icon("approved_ending").region == manager.get_icon("call_tables").region, "секретные концовки используют тот же знак вопроса")

	var menu: Variant = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var drx_definition := _catalog_item(catalog, "call_drx")
	var drx_card: Control = menu._achievement_card(drx_definition, false)
	var drx_labels: Array[Node] = drx_card.find_children("", "Label", true, false)
	check(drx_labels.size() >= 2 and (drx_labels[0] as Label).text == "???" and (drx_labels[1] as Label).text == "???", "карточка закрытого звонка не раскрывает имя или описание")
	check(drx_labels.size() >= 2 and (drx_labels[0] as Label).tooltip_text.is_empty() and (drx_labels[1] as Label).tooltip_text.is_empty(), "у закрытой карточки нет раскрывающих подсказок")
	check(drx_card.find_child("AchievementIcon", true, false) is TextureRect and (drx_card.find_child("AchievementIcon", true, false) as TextureRect).texture is AtlasTexture, "закрытая карточка использует вопросительный знак")
	var endings_in_catalog := 0
	for definition in catalog:
		if str(definition.category) == "Концовки":
			endings_in_catalog += 1
	check(endings_in_catalog == ending_ids.size(), "все секретные концовки остаются в разделе «Концовки»")
	menu.queue_free()

	manager.unlock_achievement("call_tables")
	catalog = manager.get_catalog()
	var revealed_tables := _catalog_item(catalog, "call_tables")
	check(str(revealed_tables.name) == "звонок mlff" and str(revealed_tables.description) != "???", "после получения открывается настоящее название и описание")
	var revealed_icon: Texture2D = manager.get_icon("call_tables")
	check(revealed_icon.resource_path == "res://assets/ui/achievements/call-tables.png", "после получения открывается настоящая иконка звонка")
	check(played_sounds.is_empty() and manager._toast_queue.is_empty(), "отключённые уведомления не запускают звук или тост")

	manager.notifications_enabled = true
	manager._toast_queue.clear()
	played_sounds.clear()
	manager._load_progress()
	await process_frame
	check(manager._toast_queue.is_empty() and played_sounds.is_empty(), "загрузка достижений не повторяет уведомления и звуки")
	check(manager.has_achievement("call_tables") and str(_catalog_item(manager.get_catalog(), "call_tables").name) == "звонок mlff", "полученные достижения раскрыты после загрузки сейва")
	manager.notifications_enabled = false
	var visual_menu: Variant = load("res://MainMenu.tscn").instantiate()
	root.add_child(visual_menu)
	await process_frame
	manager.notifications_enabled = true

	manager.unlock_achievement("first_choice")
	manager.unlock_achievement("call_drx")
	manager.unlock_achievement("call_palych")
	check(not manager.unlock_achievement("call_palych"), "повторная выдача секретного звонка не создаёт уведомление")
	check(played_sounds.size() == 1, "пока первый тост показывается, запущен только его звук")
	check(manager._toast_running and manager._toast_queue.size() == 2, "уведомления ожидают своей очереди без наложения")
	if played_sounds.size() >= 1:
		check(not bool(played_sounds[0].secret) and str(played_sounds[0].path) == "res://assets/audio/achievement.ogg", "обычное достижение выбирает обычный звук")
	check(audio._achievement_sfx_player.bus == &"SFX", "звуки достижений идут через регулируемую шину эффектов")
	check(audio._achievement_sfx_player.playing, "звуковой плеер запустил выбранный файл")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var old_sfx_mute := AudioServer.is_bus_mute(sfx_bus)
	var old_sfx_volume := AudioServer.get_bus_volume_db(sfx_bus)
	audio.set_sfx_volume(0.0)
	check(AudioServer.is_bus_mute(sfx_bus), "нулевая громкость SFX заглушает звук достижений")
	audio.set_sfx_volume(0.5)
	check(not AudioServer.is_bus_mute(sfx_bus), "регулировка SFX возвращает звук достижений")
	AudioServer.set_bus_volume_db(sfx_bus, old_sfx_volume)
	AudioServer.set_bus_mute(sfx_bus, old_sfx_mute)

	if DisplayServer.get_name() != "headless":
		await create_timer(3.55).timeout
		await process_frame
		check(manager._toast_name.text == "звонок workersgoincrazy@outlook.com", "длинное название звонка полностью показано в тосте")
		check(manager._toast_name.autowrap_mode != TextServer.AUTOWRAP_OFF and not manager._toast_name.clip_text, "длинное название переносится, а не обрезается")
		check(manager._toast_glow.visible and manager._toast_glow.modulate.a > 0.0, "секретное уведомление показывает золотое свечение")
		check(manager._toast_icon.texture.resource_path == "res://assets/ui/achievements/call-drx.png", "в секретном тосте проявляется настоящая иконка")
		check(played_sounds.size() >= 2 and bool(played_sounds[1].secret) and str(played_sounds[1].path) == "res://assets/audio/achievement_rare.ogg", "для секретного тоста выбран редкий звук")
		var screenshot_dir := ProjectSettings.globalize_path("res://.tools/achievement-secret-validation")
		DirAccess.make_dir_recursive_absolute(screenshot_dir)
		await RenderingServer.frame_post_draw
		var screenshot_path := screenshot_dir.path_join("secret-achievement-toast.png")
		var screenshot_error := root.get_texture().get_image().save_png(screenshot_path)
		check(screenshot_error == OK, "визуальный кадр секретного уведомления сохранён для просмотра")
	else:
		print("SKIP: graphical toast appearance requires a windowed Godot run")

	await create_timer(11.0 if DisplayServer.get_name() == "headless" else 7.2).timeout
	check(manager._toast_queue.is_empty() and not manager._toast_running, "очередь завершает оба тоста последовательно")
	check(played_sounds.size() == 3, "очередь проиграла по одному звуку на каждое уведомление")
	if played_sounds.size() == 3:
		check(bool(played_sounds[1].secret) and bool(played_sounds[2].secret), "оба звонка получили редкий звук")
		check(str(played_sounds[1].path) == "res://assets/audio/achievement_rare.ogg" and str(played_sounds[2].path) == "res://assets/audio/achievement_rare.ogg", "секретные тосты не получают обычный звук")
	manager._toast_queue.clear()
	played_sounds.clear()
	manager._load_progress()
	await process_frame
	check(played_sounds.is_empty() and manager._toast_queue.is_empty(), "повторная загрузка уже полученных наград ничего не проигрывает")

	audio.achievement_sound_started.disconnect(_record_sound)
	manager.unlocked = old_unlocked
	manager.save_path = old_path
	manager.notifications_enabled = old_notifications
	manager._toast_queue = old_queue
	manager._toast_running = old_toast_running
	if is_instance_valid(visual_menu):
		visual_menu.queue_free()
	await process_frame
	var absolute_save := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(absolute_save):
		DirAccess.remove_absolute(absolute_save)
	if not failures.is_empty():
		push_error("ACHIEVEMENT SECRET SMOKE: %d failure(s)" % failures.size())
		quit(1)
	else:
		print("ACHIEVEMENT SECRET SMOKE: PASS")
		quit(0)
