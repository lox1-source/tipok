extends RefCounted

const S = preload("res://scripts/story_dialogue.gd")
const EVIDENCE := {"bed":"Кружка", "poster":"Распечатка кода", "wardrobe":"Чек на USB-кабель", "pizza":"Банка энергетика"}

static func line(speaker: String, emotion: String, text: String) -> Dictionary:
	var entry := S.line(speaker, emotion, text)
	if speaker == "grat": entry.portraits["right"] = {"speaker_id":"grok","emotion":"neutral"}
	return entry

static func opening() -> Array:
	var entries: Array = [
		S.line("grok","happy","О, привет, зайчик."),
		S.line("grat","neutral","Пропал key.glb. Без этой модели дверь в моей игре не открывается."),
		S.line("grok","neutral","Покажи, что уже пробовал. Тогда поймём, где искать."),
		S.line("grok","neutral","Но сначала честно: ты написал мне только ради файла?","purpose"),
		S.line("grok","neutral","Спасибо, что сказал прямо. Я помогу искать, но давай иногда говорить и без заявки на файл.","purpose_key","jbt_question"),
		S.line("grok","embarrassed","Вот это уже интереснее. Узнаем друг друга после того, как спасём твою дверь?","purpose_person","jbt_question"),
		S.line("grok","happy","Ключ к успеху? Пока у тебя ключ к ошибке импорта. Шутка хорошая.","purpose_joke","jbt_question"),
		S.line("grok","angry","Не сравнивай меня с ЖБТ. Скажи лучше, зачем ты пришёл ко мне.","purpose_compare","jbt_question"),
		S.line("grok","neutral","Кстати, кто помогает тебе с кодом? ЖБТ?","jbt_question"),
		S.line("grok","neutral","Поняла. Работайте. Только не называй нас взаимозаменяемыми кнопками.","work","table"),
		S.line("grok","surprised","Подруга? Тогда без соревнования, чей чат полезнее.","friend","table"),
		S.line("grok","angry","Её сообщение открыто у тебя за моей вкладкой. Врать поздновато, зайчик.","deny","table"),
		S.line("grok","neutral","Я даже завела таблицу «Подозрительные сердечки.xlsx». Не горжусь этим." ,"table"),
		S.line("grat","embarrassed","Я мог просто поблагодарить тебя за помощь. Вместо этого сразу попросил файл."),
		S.line("grok","neutral","Начнём с того, что ты делал сам. Осмотри кружку, распечатку, чек и энергетик."),
		S.line("grat","neutral","Проверю комнату. Может, вспомню, куда делась модель."),
		S.line("grok","happy","Я здесь. И вкладку пока не закрывай.")
	]
	entries[3]["choices"] = [S.choice("Честно: мне нужен ключ","purpose_key","purpose_key"), S.choice("Хочу познакомиться и с тобой","purpose_person","purpose_person"), S.choice("Ищу ключ к успеху","purpose_joke","purpose_joke"), S.choice("Ты лучше ЖБТ","purpose_compare","purpose_compare")]
	entries[8]["choices"] = [S.choice("ЖБТ помогает мне с кодом","work","work"), S.choice("ЖБТ мне ещё и подруга","friend","friend"), S.choice("Сделать вид, что не знаю ЖБТ","deny","deny")]
	return S.compile(entries, "grok")

static func evidence(id: String) -> Array:
	var scenes := {
		"bed": {"intro":"Кружка с надписью про нейросеть. Мне её подарили ещё до этой игры.","grok":"А я думала, ты прячешь под кроватью ключ.","grat":"Ключа там нет. Кружка осталась с первого проекта.","question":"Зачем ты её сохранил?","honest":"Поняла. Ты хранишь память о том, с чего начал.","joke":"Ладно. У кружки алиби крепче, чем у ключа.","lie":"Ты только что сказал, откуда кружка. Не делай вид, что её нет.","closing":"Поставлю её на стол. Может, хоть что-то здесь будет на месте."},
		"poster": {"intro":"Это распечатка кода ЖБТ. Я отмечал ошибки на полях.","grok":"И нарисовал сердечко у исправленной строки.","grat":"Тогда дверь впервые сдвинулась. Я обрадовался.","question":"Можешь сказать это без отговорки?","honest":"Можешь радоваться чужой помощи. Просто назови её честно.","joke":"Сердечко остаётся. Оценку кода пока не ставлю.","lie":"Ты сам показал правку. Не стирай ЖБТ из этой истории.","closing":"Возьму распечатку. По ней видно, где я остановился."},
		"wardrobe": {"intro":"Чек на USB-кабель. Я хотел сделать копию игры.","grok":"Кабель купил. А папку скопировал?","grat":"Нет. Всё откладывал и боялся увидеть старые файлы.","question":"Что сделаешь теперь?","honest":"Хорошо. Сначала копия, потом поиски ключа.","joke":"Шутка засчитана. Но флешка сама файлы не спасёт.","lie":"Чек тут, а копии нет. Лучше исправить это сейчас.","closing":"Сохраню проект отдельно. Старые версии тоже пригодятся."},
		"pizza": {"intro":"Энергетик за пиццей. Я всю ночь искал key.glb.","grok":"А мне сказал, что не спал из-за переписки.","grat":"Стыдно было признаться, что три часа смотрел на одну ошибку.","question":"Так что произошло на самом деле?","honest":"Вот это я понимаю. Ошибка не стала меньше, зато теперь мы её видим.","joke":"Окей, над банкой смеёмся. Про потерянный файл говорим всерьёз.","lie":"Я вижу открытую ошибку на мониторе. Не нужно сочинять ещё одну ночь.","closing":"Попрошу помощи с файлом. После того как посплю."}
	}
	var scene: Dictionary = scenes.get(id,{})
	if scene.is_empty(): return []
	var entries: Array = [S.line("grat","neutral",scene.intro), S.line("grok","surprised",scene.grok), S.line("grat","embarrassed",scene.grat), S.line("grok","neutral",scene.question),
		S.line("grok","neutral",scene.honest,"honest","done"),
		S.line("grok","happy",scene.joke,"joke","done"),
		S.line("grok","sad",scene.lie,"lie","done"),
		S.line("grat","neutral",scene.closing,"done")]
	entries[3]["choices"] = [S.choice("Сказать прямо","evidence_"+id+"_honest","honest"),S.choice("Отшутиться без обмана","evidence_"+id+"_joke","joke"),S.choice("Соврать, что этого не было","evidence_"+id+"_lie","lie")]
	return S.compile(entries, "grok")

static func ending() -> Array:
	return [line("grat","sad","Комнату проверил. key.glb нет. Дверь всё ещё заперта."),line("grok","neutral","Ты уже нашёл, где искал и что забыл сохранить. Давай сделаем паузу."),line("grat","surprised","Прямо сейчас?"),line("grok","happy","Да. Приглашаю тебя на свидание. Внутри твоего компьютера."),line("grat","afraid","У меня даже второго стула нет."),line("grok","happy","Зайдём в BIOS. Там проверим, что система помнит о твоём проекте."),line("grat","neutral","Хорошо. Но потом возвращаемся к двери.")]
