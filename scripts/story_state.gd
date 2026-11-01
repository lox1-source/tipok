extends RefCounted

const DEFAULTS := {
	"tab_war_completed":false, "tab_war_won":false, "tab_war_result":{},
	"chapter_three_complete":false, "chapter_four_complete":false, "chapter_five_complete":false, "chapter_six_complete":false, "chapter_seven_complete":false, "court_evidence_quality":0, "lied_in_court":false, "affection_grok":0, "affection_gpt":0, "affection_artbay":0,
	"grok_trust":false, "grok_without_key":false, "gpt_trust":false, "gpt_boundaries":false,
	"artbay_trust":false, "artbay_trust_level":0, "artbay_suspicion":0,
	"hotdog_first_visit_seen":false, "hotdog_visit_count":0, "hotdog_order_stage":0, "hotdog_order_choice":"master",
	"hotdog_repeat_choice_seen":false, "hotdog_trust_choice_seen":false, "hotdog_suspicion_choice_seen":false, "hotdog_suspicion_action":"", "artbay_betrayal":false, "artbay_repaired":false,
	"old_projects_companion":"", "archive_companion_bond":"", "archive_used_backup":false,
	"artbay_evidence":false, "project_ownership_proven":false, "game_backup_created":false, "artbay_contract_signed":false, "artbay_control_taken":false, "final_ending":"", "last_build_turns":0,
	"compared_characters_often":false, "comparison_count":0, "lies_count":0,
	"learned_blender":false, "bad_key_export":false, "model_game_completed":false,
	"grok_date_completed":false, "dinner_finished":false, "amd_chef_achievement":false,
	"dinner_read_manual":false, "defender_interrupted":false, "key_txt_received":false,
	"artbay_intro_seen":false, "brainstorm_completed":false,
	"bios_memory_kept":false, "old_project_notes_found":false, "fast_money":false,
	"project_backup_snapshot":{}, "project_access_shared":false, "backup_candidate":false,
	"exploration_three_seen":false, "exploration_all_seen":false,
	"polaroid_easter_egg_seen":false,
	"defused_tab_war":false, "stamp_obtained":false, "stamp_stolen":false,
	"secret_protocol":false, "honest_final_choice":false
}

var values: Dictionary = DEFAULTS.duplicate(true)
var decisions: Dictionary = {}

func reset() -> void:
	values = DEFAULTS.duplicate(true)
	decisions.clear()

func get_value(key: String, fallback: Variant = false) -> Variant:
	return values.get(key, fallback)

func set_value(key: String, value: Variant) -> void:
	values[key] = value

func relationship_state(person: String) -> String:
	match person:
		"artrey":
			if bool(values.get("artbay_betrayal",false)) and not bool(values.get("artbay_repaired",false)):
				return "разрыв" if str(decisions.get("chapter_six_resolution", "")) == "c6_cut" else "конфликт"
			if bool(values.get("artbay_repaired",false)): return "партнёрство"
			if int(values.get("artbay_suspicion",0)) > 0: return "сомнение"
			return "дружба" if int(values.get("affection_artbay",0)) >= 3 else "знакомство"
		"grok":
			if int(values.get("lies_count",0)) >= 2: return "недоверие"
			if bool(values.get("grok_without_key",false)) and int(values.get("affection_grok",0)) >= 3: return "близость"
			return "доверие" if int(values.get("affection_grok",0)) >= 3 else "напряжение"
		"jbt":
			if bool(values.get("lied_in_court",false)): return "недоверие"
			if bool(values.get("gpt_boundaries",false)) and int(values.get("affection_gpt",0)) >= 3: return "партнёрство"
			return "доверие" if int(values.get("affection_gpt",0)) >= 3 else "дистанция"
	return ""

# Each decision is committed once per playthrough; replaying scenes cannot farm points.
func decide(key: String, answer: String, deltas: Dictionary = {}, flags: Dictionary = {}) -> bool:
	if decisions.has(key):
		return false
	decisions[key] = answer
	for stat in deltas:
		var next_value := int(values.get(stat, 0)) + int(deltas[stat])
		values[stat] = clampi(next_value, 0, 100)
	for flag in flags:
		values[flag] = flags[flag]
	values.compared_characters_often = int(values.comparison_count) >= 2
	return true

func export_data() -> Dictionary:
	return {"version":1, "values":values.duplicate(true), "decisions":decisions.duplicate(true)}

func import_data(data: Variant) -> void:
	reset()
	if not data is Dictionary:
		return
	var raw: Variant = data.get("values", {})
	if raw is Dictionary:
		for key in DEFAULTS:
			if raw.has(key) and typeof(raw[key]) == typeof(DEFAULTS[key]):
				values[key] = raw[key]
			elif raw.has(key) and typeof(DEFAULTS[key]) == TYPE_INT and raw[key] is float:
				values[key] = clampi(int(raw[key]), 0, 100)
		# Text/array results use explicit allowlists rather than accepting arbitrary saved objects.
		for key in ["compliment_choice", "dinner_dish", "dinner_decoration", "defender_choice", "brainstorm_first"]:
			if raw.get(key) is String:
				values[key] = raw[key]
		if raw.get("brainstorm_picks") is Array:
			values["brainstorm_picks"] = raw.brainstorm_picks.filter(func(item: Variant) -> bool: return item is String)
		if raw.get("project_backup_snapshot") is Dictionary:
			values.project_backup_snapshot = raw.project_backup_snapshot.duplicate(true)
		# Older saves already completed the verified contract before the explicit repair flag existed.
		if not raw.has("artbay_repaired") and bool(values.artbay_contract_signed) and bool(values.project_ownership_proven):
			values.artbay_repaired = true
	var choices: Variant = data.get("decisions", {})
	if choices is Dictionary:
		for key in choices:
			if key is String and choices[key] is String:
				decisions[key] = choices[key]
	if not values.hotdog_trust_choice_seen and str(decisions.get("hotdog_repeat_choice", "")) in ["hotdog_show", "hotdog_rest"]:
		values.hotdog_trust_choice_seen = true
	if not values.hotdog_suspicion_choice_seen and str(decisions.get("hotdog_repeat_choice", "")) in ["hotdog_check", "hotdog_wait"]:
		values.hotdog_suspicion_choice_seen = true
		values.hotdog_suspicion_action = str(decisions.hotdog_repeat_choice)
	if str(decisions.get("chapter_four_backup", "")) == "c4_access" and int(values.artbay_suspicion) == 0:
		values.artbay_suspicion = 1
	values.compared_characters_often = int(values.comparison_count) >= 2

