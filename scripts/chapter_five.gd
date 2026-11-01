extends RefCounted

const S = preload("res://scripts/story_dialogue.gd")

static func opening(values: Dictionary) -> Array:
	var artrey_line := "Я свидетель. Мы с Гратом вместе обсуждали план, так что подтвержу его вклад." if not bool(values.get("project_access_shared",false)) else "Я свидетель. Да, у меня был доступ к проекту — по его просьбе."
	var stamp_line := "Судья-принтер замечает украденную печать и кладёт её отдельно как улику." if bool(values.get("stamp_stolen",false)) else ("Министерская печать лежит в деле. Судья пока не считает её доказательством авторства." if bool(values.get("stamp_obtained",false)) else "На месте печати — талон с отказом Министерства.")
	var entries: Array = [
		S.line("narrator","neutral","Грат приносит на суд переписку, раннюю историю проекта и проверку двери. Судья — принтер в чёрной мантии."),
		S.line("narrator","neutral","Судья-принтер: «Три пункта: помощь друзей, авторство и готовность игры. Оригиналы в лоток не класть»."),
		S.line("grok","angry","В переписке видно, зачем ты меня позвал. Я хочу, чтобы ты это сказал сам."),
		S.line("jbt","neutral","Я покажу файлы и даты. За твои решения отвечать тебе."),
		S.line("grat","neutral","Ваша честь, я отвечу прямо.","answer"),
		S.line("grat","embarrassed","Да, сначала мне был нужен ключ. Потом я понял, что мне важно с вами разговаривать.","honest","artrey_witness"),
		S.line("grat","embarrassed","Ваша честь, я подал бы протест, но сначала надо скачать форму протеста.","joke","artrey_witness"),
		S.line("grat","afraid","Я ни у кого ничего не просил. Вообще.","lie","artrey_witness"),
		S.line("artrey","neutral",artrey_line,"artrey_witness"),
		S.line("narrator","neutral",stamp_line),
		S.line("narrator","neutral","На каждом пункте выбери улику, которая отвечает именно на этот вопрос. Ошибочную можно заменить без потери дела."),
		S.line("narrator","neutral","Принтер греет ролики. Суд начинается.","court_game")
	]
	entries[4]["choices"] = [
		S.choice("Сначала мне нужен был ключ, но потом стало важно общение","c5_honest","honest"),
		S.choice("Отшутиться и вернуться к делу об авторстве","c5_joke","joke"),
		S.choice("Сказать, что я никогда не просил у них помощи","c5_lie","lie")
	]
	return S.compile(entries)

static func after_trial(result: Dictionary, values: Dictionary) -> Array:
	var quality := int(result.get("quality",0))
	var verdict := "Суд принял три улики. Ранний прототип сделал Грат. Но последнюю копию и доступ к ней ещё надо проверить." if quality >= 3 else ("Часть улик принята. Историю копии придётся проверить отдельно." if quality == 2 else "Улик мало. Суд не запрещает работу, но требует отдельно проверить историю копии.")
	var stamp := "Украденная печать добавлена в протокол. Судья обещает «рассмотреть этот вопрос после перезагрузки»." if bool(values.get("stamp_stolen",false)) else ("Законная печать подтверждает только визит в Министерство, не авторство." if bool(values.get("stamp_obtained",false)) else "Министерский отказ прикреплён к делу как подтверждение бюрократического тупика.")
	var protocol := "Протокол 0 заставляет судью признать, что без регистрации ключ формально не ключ." if bool(values.get("secret_protocol",false)) else "Архивный протокол в деле отсутствует."
	var entries: Array = [
		S.line("narrator","neutral",verdict),
		S.line("narrator","neutral",stamp),
		S.line("narrator","neutral",protocol),
		S.line("grok","sad","Я не прошу обещать отношения. Просто скажи: если бы ключ уже был, ты бы всё равно захотел со мной поговорить?","grok_question"),
		S.line("grok","happy","Ладно. Я запомню именно это, а не количество файлов.","grok_yes","jbt_question"),
		S.line("grok","neutral","Хорошо. Не буду вытягивать ответ силой.","grok_unsure","jbt_question"),
		S.line("jbt","embarrassed","И мне ответь честно: ты видишь во мне собеседницу или круглосуточную техподдержку?","jbt_question"),
		S.line("jbt","happy","Спасибо. Я не хочу быть только окном для ошибок.","jbt_yes","artrey_offer"),
		S.line("jbt","neutral","Поняла. Я подожду, пока ты разберёшься.","jbt_unsure","artrey_offer"),
		S.line("artrey","neutral","Когда будет рабочая сборка, я помогу показать её людям. Договор обсудим отдельно.","artrey_offer"),
		S.line("grat","neutral","Сначала проверю копию и историю доступа. Потом решу, что подписывать."),
		S.line("narrator","neutral","Суд даёт 48 часов на проверку сборки. Артрей обещает прислать презентационную копию. Её историю Грат сверит со старым архивом.")
	]
	entries[3]["choices"] = [
		S.choice("Да. Я хотел бы поговорить с тобой и без ключа","c5_grok_yes","grok_yes"),
		S.choice("Не знаю. Мне нужно разобраться в себе","c5_grok_unsure","grok_unsure")
	]
	entries[6]["choices"] = [
		S.choice("Ты для меня собеседница, не техподдержка","c5_jbt_yes","jbt_yes"),
		S.choice("Я пока не умею это нормально объяснить","c5_jbt_unsure","jbt_unsure")
	]
	return S.compile(entries)
