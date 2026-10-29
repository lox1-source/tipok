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
	check(dialogue.is_revealing(), "First line starts in typewriter mode")
	var first_index: int = dialogue.index
	dialogue.advance()
	check(not dialogue.is_revealing() and dialogue.index == first_index, "First advance reveals full line")
	dialogue.advance()
	check(dialogue.index == first_index + 1, "Second advance changes line")
	# Reveal and enter the choice line. The two options must stay separate.
	dialogue.advance()
	check(dialogue.choice_buttons.size() == 2, "Choice buttons appear after text reveal")
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
	dialogue.start([{"speaker_id":"narrator", "speaker":"СЦЕНА", "text":"Проверка страницы без аватаров.", "portraits":{}}])
	check(not dialogue._line_has_portraits, "Portrait halos are disabled on avatar-free dialogue pages")
	DirAccess.remove_absolute(game.save_path)
	game.queue_free()
	await process_frame
	print("VN RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	call_deferred("run")
