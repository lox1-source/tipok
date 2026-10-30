extends SceneTree

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error(message)

func run() -> void:
	var game = load("res://Prologue.tscn").instantiate()
	game.save_path = "res://tests/vn_test_progress.json"
	root.add_child(game)
	await process_frame
	game.start_vn_demo()
	await process_frame
	var dialogue = game.vn
	check(dialogue.visible and game.dialogue_open, "VN demo opens")
	check(dialogue._compact_dialogue_text("Строка 1\n\nСтрока 2\n\n\nСтрока 3") == "Строка 1\nСтрока 2\nСтрока 3", "Extra blank lines are collapsed in dialogue text")
	check(dialogue.is_revealing(), "First line starts in typewriter mode")
	var first_index: int = dialogue.index
	dialogue.advance()
	check(not dialogue.is_revealing() and dialogue.index == first_index, "First advance reveals full line")
	dialogue.advance()
	check(dialogue.index == first_index + 1, "Second advance changes line")
	# Reveal and enter the choice line. The two options must stay separate.
	dialogue.advance()
	check(dialogue.choice_buttons.size() == 2, "Choice buttons appear after text reveal")
	dialogue.handle_key(KEY_SPACE)
	check(dialogue.choice_buttons.size() == 2 and dialogue.index == first_index + 1, "Space cannot silently answer a dialogue choice")
	dialogue.advance()
	check(dialogue.choice_buttons.size() == 2 and dialogue.index == first_index + 1, "Continue input cannot bypass an unanswered choice")
	dialogue.select_choice(0)
	check(dialogue.index == 2, "First branch lands on its declared next entry")
	# Every approved character has seven emotions and two explicit directions.
	for speaker in ["grat", "grok", "jbt"]:
		for side in ["left", "right"]:
			for emotion in ["neutral", "happy", "sad", "angry", "surprised", "afraid", "embarrassed"]:
				var texture = dialogue._portrait_texture(speaker, emotion, side)
				check(texture is AtlasTexture, "%s %s %s portrait atlas resolves" % [speaker, side, emotion])
				check((texture as AtlasTexture).region.size.x > 0.0 and (texture as AtlasTexture).region.size.y > 0.0, "%s %s %s portrait region is non-empty" % [speaker, side, emotion])
	check(dialogue._slots["left"].size() == 2 and dialogue._slots["right"].size() == 2, "Each side has a crossfade pair")
	check(dialogue._slots["left"][0].flip_h == false and dialogue._slots["right"][0].flip_h == false, "Portraits use authored directions, no blind mirroring")
	check(dialogue._slots["left"][1].texture == null and dialogue._slots["right"][1].texture == null, "Emotion swaps never overlap two portrait textures")
	check(dialogue._dialogue_window_layer.visible, "Authored dialogue panel is visible in VN mode")
	check(dialogue._text.scroll_active and dialogue._text.clip_contents, "Authored text scrolling and clipping remain enabled")
	check(dialogue._silhouette_shadows["left"].texture != null, "Authored portrait silhouette is present")
	var phone_entries: Array = game.Early.artrey_intro()
	game.flow = "chapter_two_artrey"
	game._start_dialogue_entries(phone_entries, 1)
	check(dialogue.phone_chat_mode and not dialogue._dialogue_window_layer.visible, "Artrey phone mode hides the ordinary VN panel")
	check(dialogue._silhouette_shadows["left"].texture == null and dialogue._silhouette_shadows["right"].texture == null, "Phone mode has no leftover portrait silhouettes")
	dialogue.start([{"speaker_id":"grat", "speaker":"Грат", "text":"Проверка длинного ответа.", "choices":[
		{"text":"1. Сделать копию с авторством и доступом только для чтения, чтобы текст переносился внутри кнопки", "id":"long"},
		{"text":"2. Спокойно отказаться от копии", "id":"short"},
		{"text":"3. Передать Артрею логин и пароль", "id":"other"}
	]}])
	dialogue.advance()
	await process_frame
	check(dialogue.choice_buttons.size() == 3, "phone choices render all answer buttons")
	for choice_button in dialogue.choice_buttons:
		var choice_label := choice_button.get_child(0) as RichTextLabel
		check(choice_label != null and choice_label.clip_contents and choice_label.size.y > 0.0, "phone answer text stays inside a clipped button")
		if choice_label != null:
			check(choice_label.get_content_height() <= choice_label.size.y + 1.0, "wrapped phone answer fits its button")
	game.start_vn_demo()
	check(not dialogue.phone_chat_mode and dialogue._dialogue_window_layer.visible, "Returning to VN restores the authored panel")
	dialogue.start([{"speaker_id":"grat", "speaker":"Грат", "text":"Выбери один из четырёх вариантов.", "choices":[
		{"text":"1. Посмотреть на процессы", "id":"a"},
		{"text":"2. Подойти к Intel", "id":"b"},
		{"text":"3. Магазин памяти", "id":"c"},
		{"text":"4. Начать свидание", "id":"d"}
	]}])
	dialogue.advance()
	await process_frame
	check(dialogue.choice_buttons.size() == 4, "four-answer dialogue displays all choices")
	check(dialogue._active_dialogue_rect.end.y <= dialogue.size.y and dialogue._choice_layer.position.y + dialogue._choice_layer.size.y <= dialogue._active_dialogue_rect.end.y, "four-answer layout stays inside dialogue panel and viewport (panel %s, choices %s, viewport %s)" % [dialogue._active_dialogue_rect, dialogue._choice_layer.get_rect(), dialogue.size])
	check(dialogue.choice_buttons[3].position.y + dialogue.choice_buttons[3].size.y <= dialogue._choice_layer.size.y + 1.0, "fourth answer stays inside the answer list")
	dialogue.handle_key(KEY_SPACE)
	check(dialogue.choice_buttons.size() == 4, "Space does not skip a four-answer decision")
	dialogue.handle_key(KEY_ENTER)
	check(dialogue.choice_buttons.is_empty(), "Enter confirms the highlighted answer")
	game.start_vn_demo()
	dialogue.start([{"speaker_id":"narrator", "speaker":"СЦЕНА", "text":"Проверка страницы без аватаров.", "portraits":{}}])
	check(not dialogue._line_has_portraits, "Portrait halos are disabled on avatar-free dialogue pages")
	DirAccess.remove_absolute(game.save_path)
	game.queue_free()
	await process_frame
	print("VN RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	call_deferred("run")
