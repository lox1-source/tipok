extends RefCounted

const S = preload("res://scripts/story_dialogue.gd")

static func opening(values: Dictionary) -> Array:
	var copy_line := "Оставь мне копию проекта. Только резервную, без паролей и с твоим именем в манифесте." if bool(values.get("artbay_trust",false)) else "Я знаю, ты не захотел обсуждать план. Если передумаешь насчёт резервной копии — скажи."
	var entries: Array = [
		S.line("narrator","neutral","Заявка о пропавшем ключе привела Грата в Министерство Ключевых Дел. У него талон 404. На табло всё ещё 403."),
		S.line("grat","surprised","Мне нужен рабочий ключ для двери. Здесь хотя бы объяснят, какой документ потерялся?"),
		S.line("artrey","neutral",copy_line,"backup"),
		S.line("grat","neutral","Перед тем как идти по окнам, надо решить, что делать с копией проекта.","backup_choice"),
		S.line("artrey","happy","Договорились. Доступ только для чтения. Я не трону файлы.","copy_safe"),
		S.line("artrey","neutral","Ладно. Если понадобится, я рядом. Давай сначала пройдём эти окна.","copy_no"),
		S.line("artrey","embarrassed","Спасибо, что доверяешь. Пароль оставь у себя — копию сделаем отдельно.","copy_access"),
		S.line("narrator","neutral","Три дела: пропавший key.glb, полученный key.txt и авторство игры. Выбери талон, один подходящий документ и нужное окно. Ошибку можно исправить."),
		S.line("grat","angry","Тут есть окно № 404. Оно хотя бы настоящее?"),
		S.line("narrator","neutral","Архив открывать необязательно. Там лежит Протокол 0 — возможный аргумент на суде. Очередь можно пройти без него.","ministry_game")
	]
	entries[3]["choices"] = [
		S.choice("Сделать копию с авторством и доступом только для чтения","c4_backup", "copy_safe"),
		S.choice("Спокойно отказаться от копии","c4_decline", "copy_no"),
		S.choice("Передать Артрею логин и пароль","c4_access", "copy_access")
	]
	return S.compile(entries)

static func after_queue(result: Dictionary, values: Dictionary = {}) -> Array:
	var approved := int(result.get("approved",0))
	var mistakes := int(result.get("wrong_attempts",0))
	var protocol := bool(result.get("protocol",false))
	var stamp := bool(result.get("stamp_obtained",false))
	var summary := "Протокол 0 найден в архиве. В нём написано: «Ключ не является ключом до регистрации»." if protocol else "В архиве осталась папка «Справка о справках». До неё руки не дошли."
	var clerk := "Чиновник ставит печать: «Заявление принято. Ключ отсутствует» — и тут же выписывает отказ." if stamp else "Чиновник отказывает: «Ключ не приложен». Причину отсутствия ключа он просит подтвердить самим ключом."
	var queue_line := "Принято дел: %d из 3. Неверных попыток: %d. Грат забирает документы обратно." % [approved,mistakes]
	var copy_line := "Копия только для чтения готова. В манифесте твое имя; мой вклад записан отдельно." if bool(values.get("backup_candidate",false)) and not bool(values.get("project_access_shared",false)) else ("Доступ у меня есть, но пароль я должен был попросить не у тебя, а у собственного стыда." if bool(values.get("project_access_shared",false)) else "Ты отказался от копии. Я не открывал твои файлы; если решишь передумать, сначала спроси сам.")
	var entries: Array = [
		S.line("narrator","neutral",queue_line),
		S.line("grat","neutral",summary),
		S.line("narrator","neutral",clerk),
		S.line("artrey","neutral",copy_line),
		S.line("grat","surprised","Повестка? Тут спорят не только о ключе, но и о том, кто сделал игру."),
		S.line("narrator","neutral","Заявку передали судье-принтеру: ему нужны переписка, история проекта и проверка двери. Заседание завтра.")
	]
	return S.compile(entries)
