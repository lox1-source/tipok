extends RefCounted
const S = preload("res://scripts/story_dialogue.gd")

static func opening(values: Dictionary = {}) -> Array:
	var jbt_reaction := "Ты обещал собрать модель сам. Давай посмотрим, что в key.txt и чего не хватает." if bool(values.get("gpt_boundaries",false)) else "Помогу проверить файл. Но сначала скажи, что ты уже пробовал."
	var grok_reaction := "Ты мог просто сказать, что покажешь файл ЖБТ. Мне неприятно узнавать последней." if bool(values.get("grok_without_key",false)) else "Это мой файл. Почему вы обсуждаете его без меня?"
	var artrey_reaction := "Сначала сохраните копию. Потом спорьте — но без открытого проекта на общем экране." if bool(values.get("brainstorm_completed",false)) else "Сохраните проект. Я видел, чем заканчиваются ваши споры у кнопки «Закрыть всё»."
	var entries: Array = [
		S.line("grat","embarrassed","Грок прислала key.txt. Но дверь ждёт модель key.glb. Поможешь понять, что делать дальше?"),
		S.line("jbt","neutral","В файле нет геометрии. Зато есть сообщение от Грок. Сначала прочти его, потом откроем Blender."),
		S.line("grat","surprised","Можно конвертировать чувства в полигоны?"),
		S.line("jbt","sad",jbt_reaction,"question"),
		S.line("jbt","happy","Спасибо. Мне приятно быть рядом и без заявки в поддержку.","respect","document"),
		S.line("jbt","neutral","Хорошо. Спасибо, что сказал прямо. Я объясню, но работать за тебя не буду.","work","document"),
		S.line("jbt","angry","«Лучше Грок» — это опять рейтинг. Со мной можно говорить без сравнения с ней.","compare","document"),
		S.line("narrator","neutral","ЖБТ прислала документ «ПОЧЕМУ GROK НЕ ПОДХОДИТ ТЕБЕ.docx». Внутри заметки о key.txt и 84 страницы личных выводов. Размер: 14 гигабайт.","document"),
		S.line("grat","surprised","Почему документ весит как RDR2?!"),
		S.line("jbt","embarrassed","Там много аргументов. И… я тоже хотела, чтобы ты выбрал мой чат."),
		S.line("artrey","neutral",artrey_reaction),
		S.line("grok","angry",grok_reaction),
		S.line("jbt","neutral","Добрый вечер. У нас идёт работа над проектом."),
		S.line("grok","angry","Тогда хотя бы не прячьте от меня мой файл."),
		S.line("narrator","neutral","Оба чата открывают файлы поверх проекта. Окна закрывают кнопку сохранения. Грату нужно расчистить экран и выбрать, чью вкладку оставить активной.","tabs")
	]
	entries[3]["choices"] = [S.choice("Мне важно общение с тобой","c3_respect","respect"),S.choice("Давай работать, но на твоих условиях","c3_work","work"),S.choice("Ты хотя бы лучше Грок","c3_compare","compare")]
	entries[7]["story_event"] = "document_84_opened"
	return S.compile(entries)

static func after_tab_war(result: Dictionary, values: Dictionary = {}) -> Array:
	var winner: String = str(result.get("side","grok"))
	var victory: bool = bool(result.get("won",false))
	var reaction := "Мои вкладки заняли экран. Но я надеюсь, что чат со мной ты оставишь не только ради победы." if winner == "grok" else "Экран под контролем. Хотя, возможно, я немного увлеклась количеством документов."
	if not victory: reaction = "Мы так увлеклись, что даже ты не успел закрыть всё это. Давай лучше поговорим без соревнования."
	var reconciliation := "Я слышу вас обеих. В BIOS я обещал быть честным, и сейчас начну с этого: key.txt не сделал меня автором модели." if bool(values.get("grok_without_key",false)) and bool(values.get("gpt_boundaries",false)) else "Вы обе мне важны. Давайте по очереди. Мне нужна помощь, но я не хочу устраивать соревнование."
	var grok_after := "Я останусь, если он снова не станет молчать, когда получит файл." if bool(values.get("grok_without_key",false)) else "А мне — чтобы ты не исчез, как только получишь файл."
	var entries: Array = [
		S.line(winner,"happy" if victory else "sad",reaction),
		S.line("grat","neutral","Окна закрыты. Но с вами обеими я ещё должен поговорить.","resolve"),
		S.line("grat","neutral",reconciliation,"peace","peace_reply"),
		S.line("grok","sad","Пока ты делаешь скриншоты, я начинаю думать, что мои чувства — твой новый контент.","fun","fun_reply"),
		S.line("artrey","neutral","Я не могу выбрать за тебя. Закрой лишние окна, потом поговори с каждой сам.","delegate","delegate_reply"),
		S.line("jbt","neutral","Хорошо. Я закрою свой документ. Но разговор продолжим без счёта побед.","peace_reply","endtalk"),
		S.line("grat","embarrassed","Я думал, вы засмеётесь вместе со мной. Вышло так, будто я вас снова сравнил.","fun_reply","fun_end"),
		S.line("grok","neutral","Я посмеюсь позже. Сейчас мне нужен перерыв от твоего экрана.","fun_end","endtalk"),
		S.line("grat","neutral","Ладно. Артрей не обязан решать за меня. С каждой поговорю сам.","delegate_reply","endtalk"),
		S.line("jbt","neutral","Мне важно, чтобы помощь не считалась обязанностью всегда соглашаться.","endtalk"),
		S.line("grok","neutral",grok_after),
		S.line("grat","embarrassed","Ключ соберу сам. А если попрошу помощи, скажу об этом прямо."),
		S.line("narrator","neutral","После сбоя компьютер отправил заявку на отсутствующий ключ. Ответ из Министерства Ключевых Дел: «Для продолжения нужен талон 404 и три документа»."),
		S.line("grat","angry","Да я хотел модель ключа сделать!")
	]
	entries[1]["choices"] = [S.choice("Дать каждой высказаться","c3_peace","peace"),S.choice("Ещё немного, это смешно","c3_fun","fun"),S.choice("Пусть Артрей решит","c3_delegate","delegate")]
	return S.compile(entries)
