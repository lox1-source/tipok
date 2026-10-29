extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var one = load("res://scripts/chapter_one.gd")
	var two = load("res://scripts/chapter_two.gd")
	var early = load("res://scripts/early_content.gd")
	var graphs: Array = [one.opening(),two.opening(),early.artrey_intro()]
	for id in one.EVIDENCE: graphs.append(one.evidence(id))
	var widget: Variant = load("res://scripts/vn_dialogue.gd").new()
	root.add_child(widget)
	for entries in graphs:
		var visited := {}
		var pending: Array = [0]
		while not pending.is_empty():
			var index: int = int(pending.pop_back())
			if index == entries.size() or visited.has(index): continue
			if index < 0 or index >= entries.size():
				failures.append("Invalid transition: %d" % index)
				continue
			visited[index] = true
			var entry: Dictionary = entries[index]
			var choices: Array = entry.get("choices",[])
			if choices.is_empty(): pending.append(int(entry.get("next",index+1)))
			else:
				for choice in choices: pending.append(int(choice.get("next",index+1)))
		if visited.size() != entries.size(): failures.append("Unreachable lines: %d" % (entries.size()-visited.size()))
		for entry in entries:
			widget.start([entry])
			widget.advance()
			await process_frame
			if widget._text.get_content_height() > widget._text.size.y + 1:
				failures.append("Text clips: "+str(entry.text))
	print("EARLY GRAPH AND TEXT RESULT: ","PASS" if failures.is_empty() else "FAIL")
	for failure in failures: push_error(failure)
	widget.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
