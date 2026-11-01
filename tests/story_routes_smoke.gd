extends SceneTree

const S = preload("res://scripts/story_state.gd")
const THREE = preload("res://scripts/chapter_three.gd")
const FIVE = preload("res://scripts/chapter_five.gd")
const SIX = preload("res://scripts/chapter_six.gd")
const SEVEN = preload("res://scripts/chapter_seven.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition: print("PASS: ",description)
	else:
		failures.append(description)
		push_error(description)

func _entry(entries: Array, key: String) -> Dictionary:
	for item in entries:
		if str(item.get("key", "")) == key: return item
	return {}

func _choice(entry: Dictionary, id: String) -> Dictionary:
	for item in entry.get("choices", []):
		if str(item.get("id", "")) == id: return item
	return {}

func run() -> void:
	var EARLY = load("res://scripts/early_content.gd")
	var story = S.new()
	story.set_value("artbay_suspicion",1)
	story.set_value("hotdog_trust_choice_seen",true)
	var kiosk: Array = EARLY.hotdog_repeat_visit(story.values)
	check(not _choice(_entry(kiosk,"choice"),"hotdog_check").is_empty(),"Подозрение открывает отдельный разговор после доверительной встречи")
	story.decide("hotdog_suspicion_choice","hotdog_check",{"artbay_suspicion":1},{"hotdog_suspicion_choice_seen":true,"hotdog_suspicion_action":"hotdog_check"})
	kiosk = EARLY.hotdog_repeat_visit(story.values)
	check(_entry(kiosk,"choice").is_empty() and str(kiosk[0].text).to_lower().contains("историю копии"),"Повтор встречи не выдаёт тот же выбор и очки снова")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(story.export_data()))
	var restored = S.new()
	restored.import_data(saved)
	check(restored.get_value("hotdog_suspicion_action") == "hotdog_check" and restored.relationship_state("artrey") == "сомнение","Решение у киоска и сомнение переживают загрузку")
	var three: Array = THREE.after_tab_war({"side":"grok","won":true}, {})
	var three_choice: Dictionary = _entry(three,"resolve")
	var fun: Dictionary = _choice(three_choice,"c3_fun")
	var peace: Dictionary = _choice(three_choice,"c3_peace")
	check(not fun.is_empty() and not peace.is_empty() and int(fun.next) != int(peace.next),"Разрешение войны вкладок ведёт к разным сценам")
	var five: Array = FIVE.opening({})
	check(not _choice(_entry(five,"answer"),"c5_honest").is_empty(),"Судебный ответ доступен на вопросе, а не на уже выбранной реплике")
	var five_outro: Array = FIVE.after_trial({"quality":3},{})
	check(not _choice(_entry(five_outro,"grok_question"),"c5_grok_yes").is_empty() and not _choice(_entry(five_outro,"jbt_question"),"c5_jbt_yes").is_empty(),"После суда оба личных ответа доступны в соответствующих вопросах")
	var six_open: Array = SIX.opening({"hotdog_suspicion_action":"hotdog_check","gpt_boundaries":true})
	check(str(_entry(six_open,"companion").text).contains("Старые проекты") and not _choice(_entry(six_open,"companion"),"c6_companion_jbt").is_empty(),"Понятная причина входа в архив и выбор спутника")
	var no_proof: Array = SIX.reveal({"links":1},{"old_projects_companion":"jbt"})
	var proof: Array = SIX.reveal({"links":3},{"old_projects_companion":"grok"})
	check(not _choice(_entry(no_proof,"decision"),"c6_defer").is_empty() and _choice(_entry(no_proof,"decision"),"c6_contract").is_empty(),"Без полного расследования договор откладывается")
	check(not _choice(_entry(proof,"decision"),"c6_contract").is_empty(),"Подтверждённая история позволяет проверить договор")
	check(str(no_proof[2].text) != str(proof[2].text) and str(no_proof[2].speaker_id) == "jbt" and str(proof[2].speaker_id) == "grok","Грок и ЖБТ говорят по-разному после расследования")
	var final_choices: Array = SEVEN.final_choice({"grok_date_completed":true,"grok_without_key":true,"lies_count":2,"artbay_contract_signed":true,"project_ownership_proven":true,"artbay_repaired":false})
	check(_choice(_entry(final_choices,"relationships"),"c7_grok").is_empty() and _choice(_entry(final_choices,"relationships"),"c7_artrey").is_empty(),"Ложь и неисправленное авторство закрывают хорошие личные исходы")
	print("STORY ROUTES SMOKE: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
