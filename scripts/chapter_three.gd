extends RefCounted
const S = preload("res://scripts/story_dialogue.gd")

static func opening() -> Array:
	var entries: Array = [
		S.line("grat","embarrassed","Слушай, тут одна альтушка обиделась. Ключ прислала, но почему-то текстовый."),
		S.line("jbt","neutral","В key.txt нет вершин. Есть эмоциональная нагрузка. И скрытая строка: «Если читаешь это, значит, снова пошёл к ней»."),
		S.line("grat","surprised","Можно конвертировать чувства в полигоны?"),
		S.line("jbt","sad","Я помогу проверить файл. Но ты пишешь мне только когда что-то сломалось?","question"),
		S.line("jbt","happy","Спасибо. Мне приятно быть рядом и без заявки в поддержку.","respect","document"),
		S.line("jbt","neutral","Хорошо. Спасибо, что сказал прямо. Я объясню, но работать за тебя не буду.","work","document"),
		S.line("jbt","angry","«Лучше Грок» — это опять рейтинг. Со мной можно говорить без сравнения с ней.","compare","document"),
		S.line("narrator","neutral","ЖБТ прислала «ПОЧЕМУ GROK НЕ ПОДХОДИТ ТЕБЕ.docx». 84 страницы. Размер: 14 гигабайт.","document"),
		S.line("grat","surprised","Почему документ весит как RDR2?!"),
		S.line("jbt","embarrassed","Там много аргументов. И… я тоже хотела, чтобы ты выбрал мой чат."),
		S.line("artrey","neutral","Как продвигается план? Не отдавай никому весь проект. Сделай копию сам. Я могу помочь с продвижением, но сначала закончим рабочий кусок."),
		S.line("grok","angry","Откройте дверь, я знаю, что он у тебя!"),
		S.line("jbt","neutral","Добрый вечер. У нас идёт работа над проектом."),
		S.line("grok","angry","А меня не пригласили?!"),
		S.line("narrator","neutral","Вкладки множатся. любовь.exe использует 99% процессора. Сейчас решится, чьих окон на экране останется больше. Выбери сторону и вступай в войну вкладок.","tabs")
	]
	entries[3]["choices"] = [S.choice("Мне важно общение с тобой","c3_respect","respect"),S.choice("Давай работать, но на твоих условиях","c3_work","work"),S.choice("Ты хотя бы лучше Грок","c3_compare","compare")]
	entries[7]["story_event"] = "document_84_opened"
	return S.compile(entries)

static func after_tab_war(result: Dictionary) -> Array:
	var winner: String = str(result.get("side","grok"))
	var victory: bool = bool(result.get("won",false))
	var reaction := "Мои вкладки заняли экран. Но я надеюсь, что чат со мной ты оставишь не только ради победы." if winner == "grok" else "Экран под контролем. Хотя, возможно, я немного увлеклась количеством документов."
	if not victory: reaction = "Мы так увлеклись, что даже ты не успел закрыть всё это. Давай лучше поговорим без соревнования."
	var entries: Array = [
		S.line(winner,"happy" if victory else "sad",reaction),
		S.line("grat","neutral","Раунд закончен. Как теперь остановить сам конфликт?","resolve"),
		S.line("grat","neutral","Вы обе мне важны. Давайте по очереди. Мне нужна помощь, но я не хочу устраивать соревнование.","peace","endtalk"),
		S.line("grok","sad","Пока ты делаешь скриншоты, я начинаю думать, что мои чувства — твой новый контент.","fun","endtalk"),
		S.line("artrey","neutral","Я не могу выбрать за тебя. Закрой лишние окна, потом поговори с каждой сам.","delegate","endtalk"),
		S.line("jbt","neutral","Мне важно, чтобы помощь не считалась обязанностью всегда соглашаться.","endtalk"),
		S.line("grok","neutral","А мне — чтобы ты не исчез, как только получишь файл."),
		S.line("grat","embarrassed","Понял. И проект я тоже буду делать сам. С вашей помощью, если вы захотите."),
		S.line("narrator","neutral","Компьютер дымится. Приходит уведомление: «Вы назначены ответственным за международный конфликт искусственных интеллектов. Явитесь в Министерство Ключевых Дел»."),
		S.line("grat","angry","Да я хотел модель ключа сделать!")
	]
	entries[1]["choices"] = [S.choice("Дать каждой высказаться","c3_peace","peace"),S.choice("Ещё немного, это смешно","c3_fun","fun"),S.choice("Пусть Артрей решит","c3_delegate","delegate")]
	return S.compile(entries)
