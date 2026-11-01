extends RefCounted

const S = preload("res://scripts/story_dialogue.gd")

static func opening(values: Dictionary) -> Array:
	var access_line := "Ты дал мне доступ к копии. Но страницу с моим именем я тебе не показал." if bool(values.get("project_access_shared",false)) else "Я собрал копию для показа. Ты ещё не разрешал её отправлять."
	var grok_line := "Я всё ещё злюсь. Но даты проверю вместе с тобой." if int(values.get("lies_count",0)) >= 2 else "Пойду с тобой. Если найду папку «финал_точно», смеяться разрешается?"
	var jbt_line := "Сверю версии и время доступа. С Артбеем говорить будешь сам." if bool(values.get("gpt_boundaries",false)) else "Покажу, где искать историю файлов. Решение останется за тобой."
	var entries: Array = [
		S.line("narrator","neutral","Артбей прислал копию игры для презентации. В поле «Автор» стоит его имя."),
		S.line("artrey","happy",access_line),
		S.line("grat","surprised","План показа — твой. Но игру сделал я. Надо проверить, когда поменялось имя."),
		S.line("artrey","sad","Проверь старые версии. Я должен был показать тебе презентацию до отправки."),
		S.line("narrator","neutral","4fr открывает резервную папку «Старые проекты». Там остались ранняя комната, копия для показа и история доступа. Кого позвать с собой?","companion"),
		S.line("grok","neutral",grok_line,"with_grok","grok_reply"),
		S.line("grok","sad","Ты называл ту дверь бесполезной, а всё равно возвращался к ней. Покажешь первую версию?","grok_reply","enter"),
		S.line("jbt","neutral",jbt_line,"with_jbt","jbt_reply"),
		S.line("jbt","embarrassed","Сохраним исходные файлы отдельно. Их не надо стыдливо переименовывать в «тест».","jbt_reply","enter"),
		S.line("grat","neutral","Сначала посмотрю сам. Не хочу, чтобы за меня снова делали выводы.","alone","enter"),
		S.line("grat","neutral","Найду прототип и сравню даты. Потом поговорю с Артбеем по фактам.","enter")
	]
	entries[4]["choices"] = [
		S.choice("Позвать Грок проверить старую игру","c6_companion_grok","with_grok"),
		S.choice("Позвать ЖБТ сверить версии файлов","c6_companion_jbt","with_jbt"),
		S.choice("Проверить архив самому","c6_companion_alone","alone")
	]
	entries[10]["story_event"] = "digital_archaeology"
	return S.compile(entries)

static func reveal(result: Dictionary, values: Dictionary) -> Array:
	var complete := int(result.get("links",0)) == 3
	var proof := "Ранняя комната и исходный файл показывают, что прототип сделал 4fr." if complete else "Рабочая копия восстановлена. Пока не хватает связей, чтобы доказать, когда сменили автора."
	var pitch_fact := "Артбей сделал план показа. Сменить автора в копии — уже другое действие." if complete else "План показа принадлежит Артбею. Кто и когда изменил поле автора, ещё нужно проверить."
	var access := "Я сам дал тебе пароль. Но это не разрешение менять имя автора." if bool(values.get("project_access_shared",false)) else "Я не передавал тебе пароль. В журнале это видно."
	var response := "Я составил план и нашёл площадки для показа. Потом вписал себя автором. Это сделал я." if complete else "План был мой. Но презентацию с моим именем я отправил без твоего согласия. Исправлю."
	var companion := str(values.get("old_projects_companion","alone"))
	var companion_entry := S.line("grat","neutral","Резервную копию оставлю у себя. Теперь у меня есть с чем сравнивать.")
	if companion == "grok":
		companion_entry = S.line("grok","sad" if int(values.get("lies_count",0)) >= 2 else "neutral","Наш разговор ещё не закончен. Но твою работу я видела. Не отдавай её за красивый питч." if int(values.get("lies_count",0)) >= 2 else "Ты возвращался к этой двери, даже когда говорил, что бросил. Это тоже часть истории.")
	elif companion == "jbt":
		companion_entry = S.line("jbt","neutral","Я сохраню даты. Ты сам скажешь Артбею, что они значат." if bool(values.get("gpt_boundaries",false)) else "Я могу показать разницу версий. Говорить за тебя не буду.")
	var entries: Array = [
		S.line("narrator","neutral",proof),
		S.line("narrator","neutral",pitch_fact),
		companion_entry,
		S.line("grat","angry","Твой план показа я признаю. Но в строке автора должно быть моё имя."),
		S.line("artrey","sad",response),
		S.line("grat","neutral",access),
		S.line("grat","neutral","Что делаем с презентацией и доступом?","decision"),
		S.line("grat","happy","Исправь авторство. Покажи новую страницу и договор с ясными ролями. Потом подпишем.","contract","response_contract"),
		S.line("artrey","embarrassed","Убрал своё имя из поля автора. Мой план отмечен отдельно. Договор покажу до публикации.","response_contract","wrap"),
		S.line("grat","neutral","Пока у меня только восстановленная копия. Сначала соберу доказательства, потом вернусь к договору.","defer","response_defer"),
		S.line("artrey","neutral","Хорошо. До новых писем покажу тебе исправленную страницу.","response_defer","wrap"),
		S.line("grat","neutral","Убирай мою игру из презентации. Контакт прекращаю.","cut","response_cut"),
		S.line("artrey","neutral","Понял. Удалю питч и сообщу получателям об ошибке.","response_cut","wrap"),
		S.line("grat","afraid","Я верю тебе. Можешь сам опубликовать копию.","trust","response_trust"),
		S.line("artrey","happy","Спасибо. Я всё улажу.","response_trust","wrap"),
		S.line("narrator","neutral","Копия сохранена. Завтра 4fr проверит последнюю сборку и решит, кто может её публиковать.","wrap","end"),
		S.line("grat","happy","Дверь ещё не открылась. Зато теперь я знаю, где моя игра.","end")
	]
	entries[6]["choices"] = [
		S.choice("Исправить авторство и проверить договор","c6_contract","contract") if complete else S.choice("Отложить договор до проверки истории файлов","c6_defer","defer"),
		S.choice("Разорвать контакт и убрать игру из презентации","c6_cut","cut"),
		S.choice("Поверить обещанию и отдать контроль","c6_trust","trust")
	]
	return S.compile(entries)

static func after_archaeology(result: Dictionary, values: Dictionary) -> Array:
	return reveal(result,values)
