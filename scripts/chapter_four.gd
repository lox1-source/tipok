extends RefCounted

const S = preload("res://scripts/story_dialogue.gd")

static func opening(values: Dictionary) -> Array:
	var copy_line := "Оставь мне копию проекта. Только резервную, без паролей и с твоим именем в манифесте." if bool(values.get("artbay_trust",false)) else "Я знаю, ты не захотел обсуждать план. Если передумаешь насчёт резервной копии — скажи."
	var entries: Array = [
		S.line("narrator","neutral","Глава 4. Министерство Ключевых Дел. Талон очереди: 404. На табло: «Сейчас обслуживается талон 403»."),
		S.line("grat","surprised","Я пришёл за разрешением сделать ключ. Почему тут отдельное окно для разрешения прийти за разрешением?"),
		S.line("artrey","neutral",copy_line,"backup"),
		S.line("grat","neutral","Перед тем как идти по окнам, надо решить, что делать с копией проекта.","backup_choice"),
		S.line("artrey","happy","Договорились. Доступ только для чтения. Я не трону файлы.","copy_safe"),
		S.line("artrey","neutral","Ладно. Если понадобится, я рядом. Давай сначала пройдём эти окна.","copy_no"),
		S.line("artrey","embarrassed","Спасибо, что доверяешь. Пароль оставь у себя — копию сделаем отдельно.","copy_access"),
		S.line("narrator","neutral","На столе три дела и три документа. Для каждого нужен один документ и одно окно. Ошибаться можно без штрафа — просто попробуй ещё раз."),
		S.line("grat","angry","Тут есть окно № 404. Оно хотя бы настоящее?"),
		S.line("narrator","neutral","Архив необязателен: там лежит Протокол 0, который пригодится в суде. Он не влияет на очередь.","ministry_game")
	]
	entries[3]["choices"] = [
		S.choice("Сделать копию с авторством и доступом только для чтения","c4_backup", "copy_safe"),
		S.choice("Спокойно отказаться от копии","c4_decline", "copy_no"),
		S.choice("Передать Артрею логин и пароль","c4_access", "copy_access")
	]
	return S.compile(entries)

static func after_queue(result: Dictionary) -> Array:
	var approved := int(result.get("approved",0))
	var mistakes := int(result.get("wrong_attempts",0))
	var protocol := bool(result.get("protocol",false))
	var stamp := bool(result.get("stamp_obtained",false))
	var summary := "Протокол 0 найден в архиве. В нём написано: «Ключ не является ключом до регистрации»." if protocol else "В архиве осталась папка «Справка о справках». До неё руки не дошли."
	var clerk := "Чиновник ставит печать: «Заявление принято. Ключ отсутствует» — и тут же выписывает отказ." if stamp else "Чиновник отказывает: «Ключ не приложен». Причину отсутствия ключа он просит подтвердить самим ключом."
	var queue_line := "Принято дел: %d из 3. Неверных попыток: %d; никто не потерял свой талон." % [approved,mistakes]
	var entries: Array = [
		S.line("narrator","neutral",queue_line),
		S.line("grat","neutral",summary),
		S.line("narrator","neutral",clerk),
		S.line("artrey","neutral","Я сохранил копию ровно в тех пределах, о которых мы договорились. Потом покажу, как устроен архив проекта."),
		S.line("grat","surprised","А это что за уведомление? «Повестка в суд. Причина: незаконное отсутствие ключа»."),
		S.line("narrator","neutral","Глава 4 завершена. Суд назначен на завтра.")
	]
	return S.compile(entries)
