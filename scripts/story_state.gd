extends RefCounted

const DEFAULTS := {
	"tab_war_completed":false, "tab_war_won":false, "tab_war_result":{},
	"chapter_three_complete":false, "chapter_four_complete":false, "chapter_five_complete":false, "chapter_six_complete":false, "chapter_seven_complete":false, "court_evidence_quality":0, "lied_in_court":false, "affection_grok":0, "affection_gpt":0, "affection_artbay":0,
	"grok_trust":false, "grok_without_key":false, "gpt_trust":false, "gpt_boundaries":false,
	"artbay_trust":false, "artbay_trust_level":0, "artbay_suspicion":0,
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
	var choices: Variant = data.get("decisions", {})
	if choices is Dictionary:
		for key in choices:
			if key is String and choices[key] is String:
				decisions[key] = choices[key]
	values.compared_characters_often = int(values.comparison_count) >= 2

