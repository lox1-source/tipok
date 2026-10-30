extends RefCounted

const S = preload("res://scripts/story_dialogue.gd")

static func opening(values: Dictionary) -> Array:
	var access_line := "В презентации уже стоит твоё имя в строке автора. Дай логин — утром питч, вечером миллион скачиваний." if bool(values.get("project_access_shared",false)) else "Дай логин от публикации. Ты ведь сам говорил, что хочешь, чтобы игра наконец увидели."
	var entries: Array = [
		S.line("narrator","neutral","Глава 6. Друг, который всё устроил. В чате появляется файл: artbay_pitch_copy.zip."),
		S.line("artrey","happy",access_line),
		S.line("grat","surprised","Погоди. Я не давал тебе готовый проект и не соглашался публиковать его от твоего имени."),
		S.line("artrey","neutral","Тогда проверь историю файлов. Я ничего не удалял. Вроде бы."),
		S.line("narrator","neutral","На компьютере открывается старый архив. Исследуй шесть записей и собери три связи по источникам. Таймера нет; ошибочные гипотезы останутся в журнале."),
		S.line("grat","neutral","Сначала восстановлю хронологию. Потом решу, что делать с договором.","digital_archaeology")
	]
	entries[5]["story_event"] = "digital_archaeology"
	return S.compile(entries)

static func reveal(result: Dictionary, values: Dictionary) -> Array:
	var complete := int(result.get("links",0)) == 3
	var proof := "Три связи подтверждены источниками. Исходная комната и манифест — Грата; копия презентации меняет автора; доступ был до согласия." if complete else "Источников не хватило. Восстановленная резервная копия сохранит рабочий проект, но спор об авторстве остаётся открытым."
	var access := "Ты просил read-only копию, а не пароль." if bool(values.get("project_access_shared",false)) else "Я не передавал тебе пароль. В журнале это видно."
	var response := "Я правда хотел помочь. Потом увидел, что у тебя может получиться, и захотел, чтобы меня назвали автором, а не помощником." if complete else "Копия была у меня через доступ, который ты сам дал. Я не подумал, что презентация с моим именем уже выглядит как присвоение."
	var entries: Array = [
		S.line("narrator","neutral",proof),
		S.line("grat","angry","В презентации автор — ты. В истории проекта автор — я. И копия появилась до согласия."),
		S.line("artrey","sad",response),
		S.line("grat","neutral",access),
		S.line("grat","neutral","Что будем делать дальше?","decision"),
		S.line("grat","happy","Исправь авторство. Подпишем прозрачный договор и будем публиковать вместе.","contract","response_contract"),
		S.line("artrey","embarrassed","Да. Я исправлю презентацию. Доли и роли пропишем до публикации.","response_contract","wrap"),
		S.line("grat","neutral","Убирай мою игру из презентации. Контакт прекращаю.","cut","response_cut"),
		S.line("artrey","neutral","Понял. Я удалю питч и не буду спорить.","response_cut","wrap"),
		S.line("grat","afraid","Я верю тебе. Можешь сам опубликовать копию.","trust","response_trust"),
		S.line("artrey","happy","Спасибо. Я всё улажу.","response_trust","wrap"),
		S.line("narrator","neutral","Глава 6 завершена. Рабочая копия сохранена; завтра предстоит последняя сборка и решение о релизе.","wrap","end"),
		S.line("grat","happy","Завтра последняя сборка. Впервые все копии проекта ведут обратно к рабочей версии Грата.","end")
	]
	entries[4]["choices"] = [
		S.choice("Исправить авторство и подписать прозрачный договор" if complete else "Предложить прозрачный договор и обязательные титры","c6_contract","contract"),
		S.choice("Разорвать контакт и убрать игру из презентации","c6_cut","cut"),
		S.choice("Поверить обещанию и отдать контроль","c6_trust","trust")
	]
	return S.compile(entries)

static func after_archaeology(result: Dictionary, values: Dictionary) -> Array:
	return reveal(result,values)
