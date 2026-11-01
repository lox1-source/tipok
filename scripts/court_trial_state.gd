extends RefCounted

const ROUNDS := [
	{"id":"relationship","title":"ПУНКТ 1 · «Вы использовали Грок и ЖБТ только ради ключа»","hint":"Нужна переписка целиком: она показывает и просьбу о ключе, и разговор после неё.","correct":"full_chat","cards":[{"id":"full_chat","title":"Полная переписка","detail":"Просьба о ключе и дальнейший разговор"},{"id":"key_txt","title":"Файл key.txt","detail":"Показывает, что прислала Грок, но не ваши отношения"},{"id":"search","title":"История поисковых запросов","detail":"Показывает только технические вопросы"}]},
	{"id":"authorship","title":"ПУНКТ 2 · «Проект создал Артрей»","hint":"Ищи источник с датами и автором файлов. Слова свидетеля сами себя не подтверждают.","correct":"project_history","cards":[{"id":"project_history","title":"История файлов проекта","detail":"Даты создания комнаты и изменений с именем автора"},{"id":"ministry_stamp","title":"Печать Министерства","detail":"Подтверждает визит или разрешение, но не авторство"},{"id":"artrey_words","title":"Показания Артрея","detail":"Слова свидетеля без независимого источника"}]},
	{"id":"build","title":"ПУНКТ 3 · «Раз есть GLB-файл, игра готова»","hint":"Наличие файла ещё не значит, что дверь его использует и открывается.","correct":"door_test","cards":[{"id":"door_test","title":"Проверка двери","detail":"GLB экспортирован, но дверь всё ещё не открылась"},{"id":"key_txt","title":"Файл key.txt","detail":"Текст есть, геометрии в нём нет"},{"id":"protocol","title":"Протокол 0","detail":"Объясняет регистрацию ключа, но не тестирует игру"}]}
]

var round := 0
var selected_card := ""
var mistakes_this_round := 0
var total_mistakes := 0
var correct_count := 0
var evidence: Array[String] = []
var finished := false
var message := "Выбери улику, которая прямо относится к обвинению."

func _init() -> void:
	reset()

func reset() -> void:
	round = 0
	selected_card = ""
	mistakes_this_round = 0
	total_mistakes = 0
	correct_count = 0
	evidence.clear()
	finished = false
	message = "Выбери улику, которая прямо относится к обвинению."

func current_round() -> Dictionary:
	return ROUNDS[clampi(round,0,ROUNDS.size()-1)]

func select_card(card_id: String) -> void:
	if finished: return
	for card in current_round().cards:
		if card.id == card_id:
			selected_card = card_id
			message = "Выбрана улика: " + str(card.title)
			return

func submit() -> bool:
	if finished or selected_card == "": return false
	var data := current_round()
	if selected_card == str(data.correct):
		correct_count += 1
		evidence.append(selected_card)
		message = "Улика принята."
		round += 1
		mistakes_this_round = 0
		selected_card = ""
		if round >= ROUNDS.size():
			finished = true
			message = "Все три пункта рассмотрены."
		return true
	mistakes_this_round += 1
	total_mistakes += 1
	if mistakes_this_round >= 2:
		message = "Подсказка: " + str(data.hint)
	else:
		message = "Эта улика не отвечает на обвинение. Попробуй другую — дело не испорчено."
	selected_card = ""
	return false

func result() -> Dictionary:
	return {"quality":maxi(0,correct_count - floori(float(total_mistakes) / 2.0)),"correct_count":correct_count,"mistakes":total_mistakes,"evidence":evidence.duplicate()}

func snapshot() -> Dictionary:
	return {"round":round,"selected_card":selected_card,"mistakes_this_round":mistakes_this_round,"total_mistakes":total_mistakes,"correct_count":correct_count,"evidence":evidence.duplicate(),"finished":finished,"message":message}

func restore(data: Dictionary) -> void:
	reset()
	round = clampi(int(data.get("round",0)),0,ROUNDS.size())
	if round >= ROUNDS.size():
		finished = true
	else:
		var picked := str(data.get("selected_card",""))
		for card in current_round().cards:
			if card.id == picked: selected_card = picked
	mistakes_this_round = clampi(int(data.get("mistakes_this_round",0)),0,100)
	total_mistakes = clampi(int(data.get("total_mistakes",0)),0,100)
	correct_count = clampi(int(data.get("correct_count",0)),0,ROUNDS.size())
	var raw: Variant = data.get("evidence",[])
	if raw is Array:
		for item in raw:
			if item is String and item not in evidence: evidence.append(item)
	message = str(data.get("message","Продолжай разбирать дело."))
