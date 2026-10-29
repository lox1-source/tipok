extends RefCounted

static func line(speaker: String, emotion: String, text: String, key: String = "", next_key: String = "") -> Dictionary:
	var names := {"grat":"Грат", "grok":"Грок", "jbt":"ЖБТ", "artrey":"Артрей • сообщения", "narrator":"СЦЕНА"}
	var portraits := {}
	if speaker in ["grat", "grok", "jbt"]:
		portraits["left"] = {"speaker_id":"grat", "emotion":emotion if speaker == "grat" else "neutral"}
		if speaker != "grat":
			portraits["right"] = {"speaker_id":speaker, "emotion":emotion}
	var result := {"speaker_id":speaker if speaker != "artrey" else "narrator", "speaker":names.get(speaker, speaker), "emotion":emotion, "side":"left" if speaker == "grat" else "right", "text":text, "portraits":portraits}
	if key != "": result["key"] = key
	if next_key != "": result["next"] = next_key
	return result

static func choice(text: String, identifier: String, next_key: String) -> Dictionary:
	return {"text":text, "id":identifier, "next":next_key}

static func compile(raw: Array, partner: String = "") -> Array:
	var entries := raw.duplicate(true)
	var labels := {}
	for i in range(entries.size()):
		if entries[i].has("key"):
			labels[str(entries[i].key)] = i
	for entry in entries:
		if partner != "" and entry.get("speaker_id", "") == "grat":
			entry.portraits["right"] = {"speaker_id":partner,"emotion":"neutral"}
		if entry.get("next") is String:
			entry.next = int(labels.get(entry.next, entries.size()))
		for option in entry.get("choices", []):
			if option.get("next") is String:
				option.next = int(labels.get(option.next, entries.size()))
	return entries
