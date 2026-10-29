extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: print("PASS: ",text)
	else:
		failures.append(text)
		push_error(text)
func drive(game: Variant, branch: int) -> void:
	var guard := 0
	while game.dialogue_open and guard < 200:
		guard += 1
		if game.vn.is_revealing(): game.vn.advance()
		elif not game.vn.current_entry().get("choices",[]).is_empty(): game.vn.select_choice(branch)
		else: game.vn.advance()
	check(guard<200,"Conversation completes")
func run() -> void:
	var a: Variant = root.get_node("AchievementManager")
	var old_path: String = a.save_path
	var old_unlocked: Dictionary = a.unlocked.duplicate(true)
	a.notifications_enabled = false
	a.save_path = "res://tests/c3_ach_temp.json"
	var g: Variant = load("res://Prologue.tscn").instantiate()
	g.save_path = "res://tests/c3_temp.json"
	root.add_child(g)
	for branch in range(3):
		g._reset_progress()
		g.start_chapter_three()
		drive(g,branch)
		check(g.mode == "tab_war","Every introduction branch reaches the real minigame")
		g.tab_war.choose_side("grok" if branch != 1 else "jbt")
		g.tab_war.state.finish(branch == 0,"control" if branch == 0 else "timeout")
		g.tab_war._changed()
		g.tab_war._continue_story()
		drive(g,branch)
		check(g.story.get_value("chapter_three_complete"),"Every resolution branch completes chapter 3")
		check(bool(g.story.get_value("defused_tab_war")) == (branch==0),"Only the peace resolution defuses the story conflict")
		check(g.load_progress() and g.story.get_value("tab_war_completed"),"Actual minigame outcome persists")
		# Release the old widget before the next test playthrough.
		await process_frame
	check(a.has_achievement("document_84") and a.has_achievement("tab_war"),"Chapter achievements are connected")
	g.queue_free()
	await process_frame
	for p in ["res://tests/c3_temp.json",a.save_path]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	a.save_path = old_path
	a.unlocked = old_unlocked
	a.notifications_enabled = true
	print("CHAPTER THREE RESULT: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
