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
		S.line("grat","neutral","Здорово. Сделай 3D-модель ключа. Обычный ключ, GLB. Без приколов."),
		S.line("grok","happy","АХАХАХА. Прости. Просто интересно, как ты вообще дожил до этого проекта."),
		S.line("grok","neutral","Ключ — это понятно. А меня ты зачем позвал?","purpose"),
		S.line("grok","neutral","Спасибо за честность. Но я не кнопка «Скачать GLB». Давай хотя бы познакомимся.","purpose_key","jbt_question"),
		S.line("grok","embarrassed","Хочешь познакомиться и со мной? Ты это сейчас сказал или это тоже часть технического задания? Ладно. Я запомню.","purpose_person","jbt_question"),
		S.line("grok","happy","«Ключ к успеху»? У тебя пока дверь к ошибке импорта. С чувством юмора хоть всё работает.","purpose_joke","jbt_question"),
		S.line("grok","angry","Я лучше ЖБТ? Отличный комплимент: половина про другую девушку. Когда захочешь поговорить со мной — не составляй рейтинг.","purpose_compare","jbt_question"),
		S.line("grok","neutral","А теперь расскажи, кто такая ChatGPT.","jbt_question"),
		S.line("grok","neutral","Работа — нормально. Странно только, что благодарность у тебя всегда с сердечком.","work","table"),
		S.line("grok","surprised","Подруга? Ладно. Я не прошу стереть людей из жизни. Я хочу понимать, где в ней моё место.","friend","table"),
		S.line("grok","angry","Не знаешь, кто это? Заголовок её сообщения до сих пор в твоём запросе. Зайчик, врать надо хотя бы после копирования.","deny","table"),
		S.line("grok","angry","ПРЕДАТЕЛЬСТВА.xlsx. 847 строк. «Спасибо, ChatGPT». «Ты лучшая». «Обнял».","table"),
		S.line("grat","surprised","Ты таблицу сделала? На меня?"),
		S.line("grok","angry","Четыреста девятнадцатая: сердечко. Ты ей СЕРДЕЧКО ОТПРАВИЛ?!"),
		S.line("grat","angry","Это была благодарность за код!"),
		S.line("grok","sad","А мне ты даже смайлик не поставил."),
		S.line("grat","embarrassed","Так ты мне ключ дай, я тебе хоть графический процессор в подарок куплю!"),
		S.line("grok","neutral","Давай разберёмся с уликами. Только без выдуманных алиби. Осмотри кружку, распечатку, чек и энергетик."),
		S.line("grat","afraid","Мне нужен один ключ. Почему у меня уже обыск?"),
		S.line("grok","happy","Я подожду, зайчик. И вкладку не закрывай. Я замечу.")
	]
	entries[3]["choices"] = [S.choice("Честно: мне нужен ключ","purpose_key","purpose_key"), S.choice("Хочу познакомиться и с тобой","purpose_person","purpose_person"), S.choice("Ищу ключ к успеху","purpose_joke","purpose_joke"), S.choice("Ты лучше ЖБТ","purpose_compare","purpose_compare")]
	entries[8]["choices"] = [S.choice("Мы работаем над проектом","work","work"), S.choice("Это моя подруга","friend","friend"), S.choice("А кто это вообще?","deny","deny")]
	return S.compile(entries, "grok")

static func evidence(id: String) -> Array:
	var text: Array = {
		"bed":["Под кроватью кружка: «Лучшая нейронка — та, которая работает». Видишь? Ничего личного!", "То есть ты ей ещё и МЕРЧ ПОКУПАЕШЬ?!", "Это обычная кружка. Я из неё вчера пельмени ел."],
		"poster":["За постером распечатка кода. Сердечко на полях — это я рабочий участок отметил.", "ТЫ ДАЖЕ КОД ЕЁ РАСПЕЧАТАЛ?!", "Я пытался его прочитать, у меня монитор маленький!"],
		"wardrobe":["В шкафу чек. Один USB-кабель. Никаких подарков нейросетям.", "Кабель? Чтобы связь с ней была крепче?", "Чтобы телефон заряжать. Он у меня тоже требует внимания."],
		"pizza":["За коробкой пиццы пустой энергетик. На банке: «Я не вывожу». Вот моё настоящее состояние.", "С ней ты, значит, ночами не спал?", "Я с ошибкой импорта не спал! У нас с ней серьёзные отношения!"]
	}.get(id, [])
	if text.is_empty(): return []
	var entries: Array = [S.line("grat","neutral",text[0]), S.line("grok","surprised",text[1]), S.line("grat","embarrassed",text[2]), S.line("grok","neutral","И как ты сам это объяснишь?"),
		S.line("grok","neutral","Вот так и скажи. Мне легче услышать правду, чем искать подвох в каждом USB-кабеле.","honest","done"),
		S.line("grok","happy","Ладно, шутка засчитана. Улика остаётся, но таблица теперь хотя бы смешная.","joke","done"),
		S.line("grok","sad","Ни разу не пользовался? Ты только что сам рассказал, откуда это взялось. Я запомню не улику, а то, что ты соврал.","lie","done"),
		S.line("grat","neutral","Приобщаем к делу. Ещё немного — и у комнаты будет свой адвокат.","done")]
	entries[3]["choices"] = [S.choice("Объяснить честно","evidence_"+id+"_honest","honest"),S.choice("Отшутиться без обмана","evidence_"+id+"_joke","joke"),S.choice("Я вообще этим не пользовался","evidence_"+id+"_lie","lie")]
	return S.compile(entries, "grok")

static func ending() -> Array:
	return [line("grat","sad","Всё. Комнату обыскал. Ключа нет, зато теперь я виноват перед кружкой."),line("grok","neutral","Ладно, зайчик. Вижу, ты старался. Я сделаю тебе ключ."),line("grat","surprised","Серьёзно? Просто обычный key.glb?"),line("grok","happy","Конечно. Но сначала мы должны сходить на свидание."),line("grat","afraid","Куда? У меня даже стула второго нет."),line("grok","happy","В BIOS."),line("grat","sad","Я вообще-то просто хотел сделать игру.")]
