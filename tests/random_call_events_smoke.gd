extends SceneTree

var failures: Array[String] = []
const CALLS := ["call_drx", "call_tables", "call_palych"]

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error(message)

func _drive_dialogue(game: Variant, event_id: String) -> void:
	var guard := 0
	while game.dialogue_open and game.call_event_pending == event_id and guard < 100:
		guard += 1
		if game.vn.is_revealing():
			game.vn.advance()
		elif not game.vn.current_entry().get("choices", []).is_empty():
			game.vn.select_choice(0)
		else:
			game.vn.advance()
	check(guard < 100, "Call dialogue completes without getting stuck")

func run() -> void:
	var manager: Variant = root.get_node("AchievementManager")
	var old_achievements: Dictionary = manager.unlocked.duplicate(true)
	var old_achievement_path: String = manager.save_path
	var old_notifications: bool = manager.notifications_enabled
	manager.unlocked.clear()
	manager.notifications_enabled = false
	manager.save_path = "res://tests/call_event_achievements_temp.json"
	var paths := ["res://tests/call_event_save_temp.json", "res://tests/call_event_legacy_temp.json", manager.save_path, "res://tests/call_event_legacy_pending_temp.json"]

	var prototype: Variant = load("res://Prologue.tscn").instantiate()
	prototype.save_path = paths[0]
	root.add_child(prototype)
	await process_frame
	var chapters: Array[int] = [2,3,4,5,6,7]
	var seen_schedules: Dictionary = {}
	var every_schedule_valid := true
	for sample in range(30):
		var schedule: Array[Dictionary] = prototype._make_call_event_schedule(chapters)
		var schedule_chapters: Array[int] = []
		var schedule_ids: Array[String] = []
		for event in schedule:
			schedule_chapters.append(int(event.chapter))
			schedule_ids.append(str(event.id))
		every_schedule_valid = every_schedule_valid and schedule.size() == 3 and schedule_ids.size() == 3 and schedule_chapters.size() == 3
		every_schedule_valid = every_schedule_valid and CALLS.all(func(id: String) -> bool: return id in schedule_ids)
		every_schedule_valid = every_schedule_valid and schedule_chapters.all(func(chapter: int) -> bool: return chapter >= 2 and chapter <= 7)
		seen_schedules[JSON.stringify(schedule)] = true
	check(every_schedule_valid, "30 random schedules contain every call once at three distinct safe chapter starts")
	check(seen_schedules.size() > 1, "Random schedules vary between playthroughs")

	prototype.call_event_schedule.clear()
	prototype.call_event_schedule.append({"chapter":2, "id":"call_drx"})
	prototype.call_event_schedule.append({"chapter":3, "id":"call_tables"})
	prototype.call_event_schedule.append({"chapter":7, "id":"call_palych"})
	prototype.call_event_schedule_initialized = true
	prototype.mode = "dialogue"
	prototype.dialogue_open = true
	check(not prototype._maybe_start_call_event(2), "No call is injected into a dialogue already in progress")
	prototype.mode = "room"
	prototype.dialogue_open = false
	prototype.mode = "tab_war"
	check(not prototype._maybe_start_call_event(2), "No call starts over an active minigame")
	prototype.mode = "room"
	check(prototype._maybe_start_call_event(2), "Scheduled chapter 2 call starts at its boundary")
	check(prototype.flow == "phone_call_call_drx" and prototype.vn.phone_call_mode and prototype.vn.phone_call_discord, "DRX call uses distinct Discord phone UI")
	check(prototype.vn.phone_call_caller == "workersgoincrazy@outlook.com", "Full Discord account is retained for display")
	var drx_avatar: TextureRect = prototype.vn.get_node("CallAvatar")
	check(drx_avatar.visible and drx_avatar.texture != null, "DRX caller portrait is shown in the Discord call")
	check(not manager.has_achievement("call_drx"), "Call achievement remains locked before the final line")
	check(prototype.save_progress(), "Mid-call checkpoint saves")
	var pending_only_save: Dictionary = prototype._save_data()
	pending_only_save["dialogue_checkpoint"] = {}
	var before_dialogue_file := FileAccess.open(paths[0], FileAccess.WRITE)
	before_dialogue_file.store_string(JSON.stringify(pending_only_save))
	before_dialogue_file.close()

	var resumed: Variant = load("res://Prologue.tscn").instantiate()
	resumed.save_path = paths[0]
	root.add_child(resumed)
	await process_frame
	check(resumed.load_progress(), "Pending call save reloads")
	resumed.resume_game()
	check(resumed.flow == "phone_call_call_drx" and resumed.vn.phone_call_mode and resumed.vn.index == 0, "Pending call restarts if the save happened before its UI opened")
	check(resumed.save_progress() and resumed.load_progress(), "In-progress call checkpoint can be saved and loaded again")
	resumed.resume_game()
	check(resumed.flow == "phone_call_call_drx" and resumed.vn.phone_call_mode and resumed.vn.index == 0, "Reload resumes the same call from its saved line")
	_drive_dialogue(resumed, "call_drx")
	check("call_drx" in resumed.call_event_completed and manager.has_achievement("call_drx"), "DRX call is recorded and rewarded once after completion")
	check(resumed.flow == "chapter_two" and resumed.vn.visible, "After DRX the chapter 2 opening begins")

	# Exercise the remaining two scheduled events and their exact continuation targets.
	for item in [{"chapter":3, "id":"call_tables"}, {"chapter":7, "id":"call_palych"}]:
		resumed.mode = "ending"
		resumed.dialogue_open = false
		resumed.vn.close()
		resumed.call_event_schedule.clear()
		resumed.call_event_schedule.append(item)
		check(resumed._maybe_start_call_event(int(item.chapter)), "Scheduled call starts before chapter %d content" % int(item.chapter))
		check(resumed.vn.phone_call_mode, "Regular call uses the phone UI")
		var caller_avatar: TextureRect = resumed.vn.get_node("CallAvatar")
		check(caller_avatar.visible and caller_avatar.texture != null, "Caller portrait is shown for " + str(item.id))
		_drive_dialogue(resumed, str(item.id))
		check(str(item.id) in resumed.call_event_completed and manager.has_achievement(str(item.id)), "Call achievement unlocks after completion: " + str(item.id))
		check(resumed.chapter_computer_pending == int(item.chapter), "Call returns to chapter %d computer setup" % int(item.chapter))
	check(resumed.call_event_completed.size() == 3, "All three events complete without repeats")
	check(not resumed._maybe_start_call_event(3), "Completed event cannot repeat")
	check(resumed.load_progress(), "Save after the last call reloads")
	resumed.resume_game()
	check(resumed.mode == "room" and resumed.chapter_computer_pending == 7 and resumed.flow.is_empty(), "Final chapter continues at the computer without replaying a completed call")

	for id in CALLS:
		var icon: Texture2D = manager.get_icon(id)
		check(icon != null and icon.get_width() > 0 and icon.get_height() > 0, "Standalone achievement icon loads: " + id)
	var drx_entries: Array = prototype._call_event_dialogue("call_drx")
	check(str(drx_entries[0].speaker).length() == "workersgoincrazy@outlook.com".length(), "Long caller label contains the entire account name")

	var legacy := FileAccess.open(paths[1], FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version":2,"active_chapter":4,"step":8,"intro_seen":true}))
	legacy.close()
	var old_save_game: Variant = load("res://Prologue.tscn").instantiate()
	old_save_game.save_path = paths[1]
	root.add_child(old_save_game)
	await process_frame
	check(old_save_game.load_progress(), "Legacy save without call fields still loads")
	check(old_save_game.call_event_schedule_initialized and old_save_game.call_event_schedule.size() == 3, "Legacy chapter 4 save receives only the three remaining safe slots")
	check(old_save_game.call_event_schedule.all(func(event: Dictionary) -> bool: return int(event.chapter) > 4), "Legacy migration does not inject a call into the active chapter")
	var pending_legacy_file := FileAccess.open(paths[3], FileAccess.WRITE)
	pending_legacy_file.store_string(JSON.stringify({"version":2,"active_chapter":5,"chapter_computer_pending":5,"step":8,"intro_seen":true}))
	pending_legacy_file.close()
	var pending_old_save: Variant = load("res://Prologue.tscn").instantiate()
	pending_old_save.save_path = paths[3]
	root.add_child(pending_old_save)
	await process_frame
	check(pending_old_save.load_progress() and pending_old_save.call_event_schedule.size() == 3, "A legacy save waiting at the computer still has three safe future slots")
	check(pending_old_save.call_event_schedule.any(func(event: Dictionary) -> bool: return int(event.chapter) == 5), "Migration can safely use a chapter that has not opened its content yet")

	for game in [prototype, resumed, old_save_game, pending_old_save]:
		game.queue_free()
	await process_frame
	for path in paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	manager.unlocked = old_achievements
	manager.save_path = old_achievement_path
	manager.notifications_enabled = old_notifications
	print("RANDOM CALL EVENTS RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
