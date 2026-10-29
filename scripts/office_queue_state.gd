extends RefCounted

const DOCUMENTS := ["error", "key_txt", "history"]
const DOCUMENT_LABELS := {"error":"Скрин ERROR", "key_txt":"key.txt", "history":"История проекта"}
const CASES := [
	{"id":"missing_key", "title":"Ключ отсутствует", "request":"Приложи скрин ошибки про отсутствующий key.glb", "window":"intake", "document":"error"},
	{"id":"text_key", "title":"Текстовый ключ", "request":"Приложи файл key.txt", "window":"review", "document":"key_txt"},
	{"id":"authorship", "title":"Автор проекта", "request":"Приложи историю создания проекта", "window":"permit", "document":"history"}
]

var tickets: Array[Dictionary] = []
var selected := 0
var selected_documents: Array[String] = []
var authorship_proven := false
var protocol_found := false
var approved := 0
var wrong_attempts := 0
var finished := false
var message := "Выбери талон и приложи один подходящий документ."
var tutorial_seen := false

func _init() -> void:
	reset()

func reset() -> void:
	tickets.clear()
	for source in CASES:
		var ticket: Dictionary = source.duplicate(true)
		ticket["status"] = "waiting"
		tickets.append(ticket)
	selected = 0
	selected_documents.clear()
	authorship_proven = false
	protocol_found = false
	approved = 0
	wrong_attempts = 0
	finished = false
	tutorial_seen = false
	message = "Выбери талон и приложи один подходящий документ."

func waiting_count() -> int:
	var count := 0
	for ticket in tickets:
		if ticket.status == "waiting": count += 1
	return count

func select_ticket(index: int) -> void:
	if index < 0 or index >= tickets.size() or tickets[index].status != "waiting": return
	selected = index
	selected_documents.clear()
	message = "Нужен документ: " + str(DOCUMENT_LABELS[tickets[index].document])

func available_documents() -> Array[String]:
	return DOCUMENTS.duplicate()

func toggle_document(id: String) -> void:
	if finished or id not in DOCUMENTS: return
	if selected_documents.has(id):
		selected_documents.clear()
		message = "Документ убран."
	else:
		selected_documents = [id]
		message = "Выбран документ: " + str(DOCUMENT_LABELS[id])

func inspect_archive() -> bool:
	if finished or protocol_found: return false
	protocol_found = true
	message = "Нашёл Протокол 0. Он пригодится в суде. Очередь не продвинулась и талон не потерян."
	return true

func submit(window_id: String) -> bool:
	if finished or selected < 0 or selected >= tickets.size(): return false
	var ticket: Dictionary = tickets[selected]
	if ticket.status != "waiting": return false
	var correct := window_id == str(ticket.window) and selected_documents.size() == 1 and selected_documents[0] == str(ticket.document)
	if correct:
		ticket.status = "approved"
		approved += 1
		if ticket.id == "authorship": authorship_proven = true
		message = "Верно! Дело принято. Выбери следующий талон."
	else:
		wrong_attempts += 1
		message = "Не подошло. Ничего не потеряно: сверь требование талона с документом и окном, затем попробуй ещё раз."
	selected_documents.clear()
	finished = waiting_count() == 0
	if finished: message = "Все три дела приняты. Теперь выбери, как поступить с печатью."
	return correct

func result(outcome: String = "leave") -> Dictionary:
	return {
		"approved":approved,
		"lost":0,
		"wrong_attempts":wrong_attempts,
		"protocol":protocol_found,
		"stamp_obtained":outcome == "legal",
		"stamp_stolen":outcome == "steal",
		"authorship_proven":authorship_proven
	}

func snapshot() -> Dictionary:
	return {"tickets":tickets.duplicate(true),"selected":selected,"selected_documents":selected_documents.duplicate(),"authorship_proven":authorship_proven,"protocol_found":protocol_found,"approved":approved,"wrong_attempts":wrong_attempts,"finished":finished,"message":message,"tutorial_seen":tutorial_seen}

func restore(data: Dictionary) -> void:
	reset()
	var raw: Variant = data.get("tickets", [])
	if not raw is Array or raw.size() != CASES.size(): return
	for i in range(CASES.size()):
		if not raw[i] is Dictionary or raw[i].get("id") != CASES[i].id: return
		if raw[i].get("status") not in ["waiting","approved"]: return
		tickets[i]["status"] = raw[i].status
	selected = clampi(int(data.get("selected",0)),0,tickets.size()-1)
	selected_documents.clear()
	var docs: Variant = data.get("selected_documents", [])
	if docs is Array:
		for doc in docs:
			if doc is String and doc in DOCUMENTS and doc not in selected_documents: selected_documents.append(doc)
	authorship_proven = bool(data.get("authorship_proven",false))
	protocol_found = bool(data.get("protocol_found",false))
	approved = clampi(int(data.get("approved",0)),0,CASES.size())
	wrong_attempts = clampi(int(data.get("wrong_attempts",0)),0,100)
	finished = waiting_count() == 0
	message = str(data.get("message","Выбери следующий талон."))
	tutorial_seen = bool(data.get("tutorial_seen",false))
