extends RefCounted
const S = preload("res://scripts/story_dialogue.gd")

static func on_choice(g: Variant, id: String) -> void:
	var deltas := {}
	var flags := {}
	var key := ""
	if g.flow == "chapter_one_intro":
		key = "grok_purpose" if id.begins_with("purpose_") else "grok_jbt_question"
		match id:
			"purpose_person": deltas = {"affection_grok":2}; flags = {"grok_trust":true}
			"purpose_key", "work", "friend": deltas = {"affection_grok":1}; flags = {"grok_trust":true}
			"purpose_joke": deltas = {"affection_grok":1}
			"purpose_compare": deltas = {"affection_grok":-2,"comparison_count":1}
			"deny": deltas = {"affection_grok":-2,"lies_count":1}; flags = {"grok_trust":false}
	elif id.begins_with("evidence_"):
		var parts := id.split("_")
		key = "evidence_" + parts[1]
		if id.ends_with("honest"):
			deltas = {"affection_grok":1}
		elif id.ends_with("lie"):
			deltas = {"affection_grok":-2,"lies_count":1}; flags = {"grok_trust":false}
	elif g.flow == "chapter_two":
		match id:
			"pretty", "smart", "best", "company":
				key = "bios_compliment"; flags = {"compliment_choice":id}
				if id == "company": deltas = {"affection_grok":2}
				elif id == "best": deltas = {"comparison_count":1}
				else: deltas = {"affection_grok":1}
			"dream_honest", "dream_money":
				key = "bios_dream"
				if id == "dream_honest": deltas = {"affection_grok":1}
			"care", "uncertain", "only_key":
				key = "grok_personal"
				if id == "care": deltas = {"affection_grok":2}; flags = {"grok_trust":true,"grok_without_key":true}
				elif id == "uncertain": deltas = {"affection_grok":1}; flags = {"grok_trust":true}
				else: deltas = {"affection_grok":-2}; flags = {"grok_trust":false,"grok_without_key":false}
			"read_manual", "improvise": key = "bios_manual"; flags = {"dinner_read_manual":id == "read_manual"}
			"paste_ram", "safe_food", "taste_paste": key = "bios_dish"; flags = {"dinner_dish":id}
			"dinner_lights", "dinner_brand": key = "bios_decoration"; flags = {"dinner_decoration":id}
			"share_yes", "share_no":
				key = "bios_sharing"; deltas = {"affection_grok":1 if id == "share_yes" else -1}
			"defender_allow", "defender_close", "defender_slow":
				key = "bios_defender"; flags = {"defender_choice":id, "defender_interrupted":true}
				if id == "defender_slow": deltas = {"affection_grok":1}
			"memory_keep", "memory_trade": key = "bios_memory"; flags = {"bios_memory_kept":id == "memory_keep"}
	elif g.flow == "chapter_two_artrey":
		key = "artrey_cooperation"
		if id == "artrey_accept": deltas = {"affection_artbay":1,"artbay_trust_level":1}; flags = {"artbay_trust":true}
		elif id == "artrey_terms": deltas = {"affection_artbay":2}; flags = {"artbay_trust":true}
	elif id in ["jbt_room_respect", "jbt_room_rude"]:
		key = "jbt_room_conversation"
		if id == "jbt_room_respect": deltas = {"affection_gpt":2}; flags = {"gpt_trust":true,"gpt_boundaries":true}
		else: deltas = {"affection_gpt":-1}; flags = {"gpt_trust":false}
	if key != "":
		g.story.decide(key, id, deltas, flags)

static func room_entries(g: Variant, id: String) -> Array:
	var entries: Array = []
	match id:
		"bed": entries = [S.line("grat","neutral","«Посплю после релиза». Сон — единственная механика, которую я освоил. Релиз пока не знает, что он существует.")]
		"poster": entries = [S.line("grat","happy","Такой же постер повешу в офисе студии. Когда будет офис. И студия."),S.line("narrator","neutral","Под постером заметки: «комната, дверь, ключ, миллион». Между ключом и миллионом — пустая страница."),S.line("grat","embarrassed","Это рабочий стол с планом. Пока рабочая тут только древесина.")]
		"pizza": entries = [S.line("grat","happy","Единственный круг в комнате, который я не просил нарисовать нейросеть."),S.line("narrator","neutral","Рядом энергетик «Я не вывожу». Срок годности длиннее текущего плана разработки."),S.line("grat","neutral","Еда есть, энергия есть. Осталось найти дисциплину. Телефон ниже, на той же тумбочке.")]
		"wardrobe":
			entries = [S.line("grat","neutral","Футболка для разработки и для интервью после релиза. Это одна футболка."),S.line("narrator","neutral","За ней папка старого проекта. В заметках — дата первого теста двери и имя 4fr. Рядом скриншот: «Когда-нибудь закончу»."),S.line("grat","sad","Три года назад я тоже писал «почти готово». Сохраню заметки. Хочу хоть этот проект закончить.")]
			g.story.set_value("old_project_notes_found", true)
		"plant": entries = [S.line("grat","neutral","Растение пережило три дедлайна и один эксперимент с энергетиком. Поливаю его чаще, чем обновляю план разработки.")]
		"drafts": entries = [S.line("grat","embarrassed","Черновики идей. Тут есть дверь, ключ и ещё одна дверь. Похоже, сюжет уже сам себя пишет.")]
	entries.append_array(chapter_room_entries(g, id))
	if g.examined.size() >= 3 and not g.story.get_value("exploration_three_seen"):
		g.story.set_value("exploration_three_seen", true)
		entries.append(S.line("jbt","neutral","В твоём плане пока три пункта: попросить кого-нибудь, подождать, стать известным. Хочешь, я помогу разбить работу на маленькие задачи?"))
		var prompt := S.line("grat","neutral","ЖБТ написала сама. Можно хотя бы нормально ответить.")
		prompt["choices"] = [S.choice("Спасибо. Я тоже буду делать","jbt_room_respect","jbt_respect"),S.choice("Просто сделай всё за меня","jbt_room_rude","jbt_rude")]
		entries.append(prompt)
		entries.append(S.line("jbt","happy","Тогда начнём с одного шага. И можно иногда писать мне без задачи.","jbt_respect","room_done"))
		entries.append(S.line("jbt","sad","Помочь — могу. Заменить твоё участие — нет. Вернёмся к этому, когда будешь готов.","jbt_rude","room_done"))
		entries.append(S.line("grat","neutral","Ладно. Пора вернуться к проекту.","room_done"))
	if g.examined.size() >= 6 and not g.story.get_value("exploration_all_seen"):
		g.story.set_value("exploration_all_seen", true)
		entries.append(S.line("grat","happy","Всё осмотрел. Если игра станет популярной, скажу, что этот бардак был экологическим повествованием."))
	return S.compile(entries)

static func chapter_room_entries(g: Variant, id: String) -> Array:
	# Small optional room moments make returning to the bedroom feel different
	# as the story advances. They reuse existing interactables and add no HUD clutter.
	var chapter := int(g.active_chapter)
	var moments: Dictionary = {
		2: {
			"bed": [S.line("grat","embarrassed","После свидания в BIOS кровать выглядит подозрительно аналоговой. Хотя спать в компьютере я уже пробовал — не помогло.")],
			"pizza": [S.line("grat","happy","Пицца сработала лучше любого романтического сценария. Запишу в план: в следующей версии свидания добавить нормальную еду.")],
			"plant": [S.line("grat","neutral","Растение пережило ужин в BIOS. Значит, если проект опять зависнет, хотя бы один свидетель у меня будет.")]
		},
		3: {
			"poster": [S.line("grat","sad","После войны вкладок повесил бы рядом правило: люди — не окна, которые можно перетаскивать до победы.")],
			"bed": [S.line("grat","neutral","Надо поспать. Но сначала проверю, помирились ли вкладки. Нет, вкладки не умеют мириться. Это моя работа.")],
			"plant": [S.line("grat","happy","У растения сегодня меньше открытых процессов, чем у меня. И оно всё равно справляется лучше.")]
		},
		4: {
			"wardrobe": [S.line("grat","neutral","Спрячу сюда талон 404. Может, в следующий раз он превратится в талон 403 и пустит меня без трёх справок.")],
			"pizza": [S.line("grat","sad","В Министерстве три окна, три дела и ни одного окна, где принимают пиццу. Бюрократия явно не готова к будущему.")],
			"plant": [S.line("grat","neutral","На суд лучше взять зелёного свидетеля. Оно видело, сколько раз я говорил, что ключ почти готов.")]
		},
		5: {
			"poster": [S.line("grat","embarrassed","Судья-принтер вынесет вердикт. Надеюсь, он не попросит распечатать доказательство, что я умею делать игры.")],
			"bed": [S.line("grat","sad","После суда хочется просто лечь и ничего не доказывать. Но проекту ещё нужна резервная копия.")],
			"plant": [S.line("grat","neutral","Ты был единственным свидетелем, которому не пришлось давать показания. Спасибо за молчание.")]
		},
		6: {
			"wardrobe": [S.line("grat","angry","Старый проект всё ещё здесь. В этот раз я проверю историю файлов, прежде чем кому-то поверю на слово.")],
			"poster": [S.line("grat","neutral","На постере всё ещё написано «сделать игру». Теперь хотя бы ясно, кто должен стоять в строке автора.")],
			"bed": [S.line("grat","sad","Восстановил проект. Странное чувство: файлы вернулись быстрее, чем доверие.")]
		},
		7: {
			"bed": [S.line("grat","happy","Последняя сборка. После релиза можно будет поспать без мысли «я ещё не закончил».")],
			"poster": [S.line("grat","neutral","Комната, дверь, ключ. На этот раз дверь действительно открывается. Надо бы обновить постер и добавить «проверить сборку».")],
			"pizza": [S.line("grat","happy","Пицца на последнюю сборку. Сегодня это не план на потом, а перекус после релиза.")]
		}
	}
	var chapter_moments: Dictionary = moments.get(chapter, {})
	return chapter_moments.get(id, [])

static func artrey_intro() -> Array:
	var entries: Array = [
		S.line("narrator","neutral","После свидания телефон снова вибрирует. Артбей продолжает переписку в чате друзей."),
		S.line("artrey","happy","Увидел апдейт: свидание внутри BIOS, а на выходе опять текстовый файл. Прогресс неоднозначный, творческий директор."),
		S.line("grat","embarrassed","Пока один текстовый ключ. Зато с эмоциональной нагрузкой."),
		S.line("artrey","happy","Я помню твою игру, где дверь вылетала из комнаты вместе с игроком. Прогресс есть: теперь дверь хотя бы стоит на месте."),
		S.line("grat","happy","То была экспериментальная механика эвакуации."),
		S.line("artrey","neutral","Слушай, ты реально что-то собрал. Давай выберем одну вещь, которую можно закончить. Я помогу с планом и потом с продвижением."),
		S.line("grat","surprised","Ты сейчас скажешь, что знаешь инвестора?"),
		S.line("artrey","happy","Знаю. Но он пока инвестирует только в шаурму. Есть и знакомые с игровыми пабликами. Покажем им готовый кусок, а не миллион обещаний."),
		S.line("artrey","neutral","Проект у тебя на одном компьютере? Копия есть? И на чьём аккаунте потом будем публиковать?"),
		S.line("grat","neutral","На моём. Копии пока — это папки «финал», «финал2» и «финал_не_трогать»."),
		S.line("artrey","happy","Последнее название у всех самое рабочее. Предлагаю короткий мозговой штурм. Без паролей и передач квартиры в залог.","offer"),
		S.line("artrey","happy","Договорились. Сначала честный маленький план, потом попробуем заинтересовать людей. Ты ещё заработаешь на своей игре — если мы её закончим.","accept","ready"),
		S.line("artrey","neutral","Нормально. Твой проект — твоё авторство. Я предложу идеи, ты решишь. Для списка задач доступ к исходникам не нужен.","terms","ready"),
		S.line("artrey","neutral","Без проблем. Могу позже посмотреть готовый кусок. Только не пропадай до следующего голосового через три года.","refuse","end"),
		S.line("grat","happy","Ладно. Показывай свою салфетку с бизнес-планом.","ready"),
		S.line("artrey","happy","Салфетка одна. Идей семь. Выбирай три — иначе опять не начнём.")
	]
	entries[10]["choices"] = [S.choice("Давай составим план","artrey_accept","accept"),S.choice("Да, но авторство за мной","artrey_terms","terms"),S.choice("Хочу пока поработать один","artrey_refuse","refuse")]
	return S.compile(entries)

static func hotdog_first_chat(state: Dictionary = {}) -> Array:
	var has_notes := bool(state.get("old_project_notes_found",false))
	var remembered_line := "Ты уже нашёл заметки из старого проекта? Значит, правда хочешь довести эту историю до конца." if has_notes else "Покажешь, что уже работает? Не презентацию — саму игру."
	var entries: Array = [
		S.line("narrator","neutral","После BIOS вы выходите на улицу. У киоска «Хот-дог Мастер» Артбей уже стоит у окна и держит два чека."),
		S.line("artrey","happy","Я заказал как обычно. Они спросили, что именно это значит. Третий год подряд спрашивают."),
		S.line("grat","happy","Зато одна постоянная вещь у тебя в жизни есть."),
		S.line("artrey","neutral","Не считая тебя, который каждый год обещает доделать игру?"),
		S.line("grat","embarrassed","Я сегодня хотя бы получил ключ. Текстовый. До настоящего ещё один шаг и несколько месяцев, видимо."),
		S.line("artrey","happy","Это уже лучше, чем папка «финал_точно_последний»."),
		S.line("narrator","neutral",remembered_line),
		S.line("artrey","neutral","Я помню старую комнату и эту дверь. Могу помочь выбрать маленькую следующую задачу. Пароли и полный доступ для этого не нужны."),
		S.line("grat","neutral","Ладно. Только сначала поедим. Я не умею принимать решения на голодный желудок."),
		S.line("artrey","happy","Уже взял два — себе и на потом. Ты себе выбери у окна. На этот раз один из моих даже хот-дог."),
		S.line("artrey","neutral","Что дальше с игрой?","offer"),
		S.line("artrey","happy","Хорошо. Выберем одну задачу и проверим её на маленькой сборке.","accept","ready"),
		S.line("artrey","neutral","Согласен. Авторство и границы доступа остаются твоими; мою помощь запишем отдельно.","terms","ready"),
		S.line("artrey","neutral","Понял. Сегодня без плана. Когда будет что показать — позови.","refuse","end"),
		S.line("grat","happy","Спасибо. Показывай свою салфетку с бизнес-планом.","ready","brainstorm"),
		S.line("artrey","happy","Салфетка одна. Идей семь. Выберем три и решим, с чего начать.","brainstorm")
	]
	entries[10]["choices"] = [
		S.choice("Показать прототип и выбрать один маленький шаг","artrey_accept","accept"),
		S.choice("Обсудить роли и доступ до совместной работы","artrey_terms","terms"),
		S.choice("Сегодня просто поесть, к проекту вернуться позже","artrey_refuse","refuse")
	]
	return S.compile(entries, "artrey")

static func hotdog_taste(item_id: String = "master") -> Array:
	var entries: Array = []
	match item_id:
		"single":
			entries = [
				S.line("narrator","neutral","4fr берёт одинарный хот-дог. Продавец заворачивает его в пакет с надписью «сегодня точно свежий»."),
				S.line("grat","happy","Классика. Даже название не пытается меня удивить."),
				S.line("artrey","happy","Смелый выбор. Здесь и обычная сосиска иногда с сюжетом."),
				S.line("narrator","neutral","4fr откусывает. Соус хрустит, хотя лука в меню нет."),
				S.line("grat","surprised","Подожди. Если это классика, почему соус звучит как клавиатура?"),
				S.line("artrey","neutral","Отложи пока. Я спрошу у продавца, что он туда положил.")
			]
		"double":
			entries = [
				S.line("narrator","neutral","4fr заказывает двойной. Из булки торчат две сосиски и половина салфетки."),
				S.line("grat","happy","Вот это архитектура. Держится на честном слове и горчице."),
				S.line("artrey","happy","Только не урони. Мои два пока целые."),
				S.line("narrator","neutral","4fr откусывает. Под второй сосиской обнаруживается тот же хрустящий соус."),
				S.line("grat","surprised","Почему хрустит не сосиска, а соус?"),
				S.line("artrey","neutral","Хороший вопрос. Второй укус отложим до ответа.")
			]
		"signature":
			entries = [
				S.line("narrator","neutral","4fr выбирает фирменный хот-дог. Продавец щедро добавляет секретный соус."),
				S.line("grat","happy","Секретный рецепт? Надеюсь, секрет хотя бы съедобный."),
				S.line("artrey","neutral","У меня в пакете два обычных. Сравним, когда попробуешь."),
				S.line("narrator","neutral","4fr откусывает. Соус неожиданно хрустит."),
				S.line("grat","surprised","Я понял секрет: он издаёт звук. Так и задумано?"),
				S.line("artrey","neutral","Лучше пока не проверяй второй раз.")
			]
		_:
			entries = [
				S.line("narrator","neutral","4fr берёт у окна «Мастер сосиску». Бумажный пакет подозрительно тёплый."),
				S.line("grat","happy","За девяносто девять рублей она должна хотя бы знать мой пароль от Wi-Fi."),
				S.line("artrey","happy","Не говори ей пароль. Сначала проверь, что она съедобная."),
				S.line("narrator","neutral","4fr откусывает. Соус хрустит."),
				S.line("grat","surprised","Стой. Соус не должен хрустеть. Что там внутри?"),
				S.line("artrey","neutral","Может, лук? Ты пока не делай второй укус.")
			]
	return S.compile(entries, "artrey")

static func hotdog_poisoning(refused_plan: bool = false, item_id: String = "master") -> Array:
	var order_name: String = str({"single":"Одинарный", "double":"Двойной", "master":"Мастер сосиска", "signature":"Фирменный"}.get(item_id,"Мастер сосиска"))
	var entries: Array = [
		S.line("narrator","neutral","Через минуту 4fr мутит. Он садится на лавку и откладывает хот-дог."),
		S.line("grat","afraid","В животе будто запустилась сборка без кнопки «Отмена»."),
		S.line("artrey","sad","Продавец сказал, что соус у всех один. Держи воду. Если не отпустит — пойдём за помощью."),
		S.line("grat","neutral","Отпускает. Но «%s» теперь мой главный баг-репорт." % order_name),
	]
	if refused_plan:
		entries.append(S.line("artrey","neutral","Мои два я пока не трону. До дома дойдёшь? Про игру сегодня не спрашиваю."))
		entries.append(S.line("grat","happy","Дойду. А завтра открою проект сам. Хот-догам доступ к папке не дам."))
	else:
		entries.append(S.line("artrey","happy","Мои два я пока не трону. С игрой что делаем? Только короткий план, без героизма."))
		entries.append(S.line("grat","happy","Давай. Сначала один рабочий шаг. И копию проекта — отдельно от хот-догов."))
	return S.compile(entries, "artrey")

static func hotdog_repeat_visit(state: Dictionary = {}) -> Array:
	var suspicion := int(state.get("artbay_suspicion",0))
	var entries: Array = []
	if bool(state.get("artbay_betrayal",false)):
		if bool(state.get("artbay_repaired",false)):
			entries = [
				S.line("artrey","sad","Я разослал исправленную презентацию. Твоё авторство стоит первым. Мой план продвижения отмечен отдельно."),
				S.line("grat","neutral","Покажи письма. Договор не вернёт доверие за один вечер, но теперь хотя бы ясно, что ты исправил."),
				S.line("artrey","neutral","Покажу. И логин останется у тебя. Сегодня я отвечаю за свои ошибки, не за твою игру.")
			]
		elif bool(state.get("artbay_control_taken",false)):
			entries = [
				S.line("grat","angry","Ты обещал исправить имя. В опубликованной копии его всё ещё нет."),
				S.line("artrey","sad","Я хотел успеть к питчу и снова выбрал за тебя. Не прошу считать это помощью."),
				S.line("grat","neutral","Мою резервную копию ты не получишь. Теперь у каждого из нас свой релиз.")
			]
		elif bool(state.get("artbay_contract_signed",false)):
			entries = [
				S.line("artrey","sad","Я подготовил исправление к презентации, но у нас всё ещё нет полной истории файлов."),
				S.line("grat","neutral","Пока не будет доказательств и новой страницы с моим именем, договор не вступит в силу."),
				S.line("artrey","neutral","Понял. Сначала покажу исправления, потом вернёмся к подписи.")
			]
		else:
			entries = [
				S.line("artrey","sad","Я удалил питч. Получателям отправил исправление: игру сделал ты, я помогал с планом."),
				S.line("grat","neutral","Хорошо. Это не приглашение снова работать вместе."),
				S.line("artrey","neutral","Понимаю. Сегодня просто верну твою флешку.")
			]
	elif suspicion > 0 and bool(state.get("hotdog_suspicion_choice_seen",false)):
		entries = [
			S.line("grat","neutral","Историю копии я проверю сам. Разговор у киоска не сделал даты в файлах понятнее."),
			S.line("artrey","sad","Я принесу исходную версию. Но после того, что ты увидел, обещаний мало — сравни файлы."),
			S.line("grat","neutral","Да. Сначала факты, потом решения о нас и о проекте.")
		]
	elif suspicion > 0:
		entries = [
			S.line("grat","neutral","Ты говорил, что только смотришь копию. Почему в черновике презентации автором стоит твоё имя?"),
			S.line("artrey","embarrassed","Я поставил заглушку для питча. Надо было показать тебе до отправки."),
			S.line("grat","neutral","Что мне сделать сейчас?","choice"),
			S.line("artrey","sad","Проверяй историю. Словами я уже не докажу, когда и что менял.","check","end"),
			S.line("artrey","neutral","Я сам принесу старую копию. Но решение о доступе оставь за собой.","wait","end"),
			S.line("grat","neutral","Вернусь к файлам. Не к обещаниям.","end")
		]
		entries[2]["choices"] = [S.choice("Проверить историю копии самому","hotdog_check","check"),S.choice("Попросить Артбея принести исходную версию","hotdog_wait","wait")]
	elif bool(state.get("hotdog_trust_choice_seen",false)):
		entries = [
			S.line("artrey","happy","Два хот-дога. Проект сегодня открывать будем?"),
			S.line("grat","neutral","Сначала поем. Потом покажу, что изменилось после нашего разговора."),
			S.line("artrey","neutral","Вот теперь мы точно похожи на друзей, а не на план релиза.")
		]
	else:
		entries = [
			S.line("artrey","happy","Как обычно? На этот раз продавец узнал меня. Правда, спросил, кто ты."),
			S.line("grat","happy","Скажи: человек, у которого впервые запускается собственная игра."),
			S.line("artrey","neutral","Покажешь сборку или сегодня просто поедим?","choice"),
			S.line("artrey","happy","Вот здесь дверь открывается. Помнишь, раньше она улетала вместе с игроком? Я помогу проверить короткий трейлер.","show","end"),
			S.line("artrey","neutral","Тоже план. Дружить можно и без общего документа с задачами.","rest","end"),
			S.line("grat","neutral","Хорошо. К файлам вернёмся, когда я сам буду готов.","end")
		]
		entries[2]["choices"] = [S.choice("Показать рабочую сборку, но оставить доступ у себя","hotdog_show","show"),S.choice("Сегодня просто поговорить без проекта","hotdog_rest","rest")]
	return S.compile(entries, "artrey")

static func show_blender_game(g: Variant) -> void:
	if g.minigame_checkpoint.get("kind", "") != "blender":
		g.minigame_checkpoint = {"kind":"blender","stage":0,"errors":0,"notice":"Ошибаться можно. Это учебная сцена, без таймера."}
	g.app_header("Blender / создай ключ, не сломав проект")
	g.hint_label.show()
	g._show_hint("Выбери действие · ошибку можно исправить · Esc — вернуться на рабочий стол")
	var stages := [
		["1. Где создаём модель?", ["Открыть Blender", "Вставить команду в поиск"],0],
		["2. Что станет заготовкой ключа?", ["Источник света", "Меш: цилиндр"],1],
		["3. Подгони размер под дверь", ["Уменьшить до масштаба двери", "Увеличить в тысячу раз"],0],
		["4. Экспорт модели", ["Картинка PNG", "glTF Binary (.glb)"],1],
		["5. Проверь файл в папке проекта", ["training_key.glb — меш найден", "key.txt — тоже сойдёт"],0]
	]
	var stage: int = clampi(int(g.minigame_checkpoint.stage),0,4)
	var item: Array = stages[stage]
	g.text_at(g.app_panel,str(item[0]),Vector2(28,88),Vector2(695,45),23)
	g.text_at(g.app_panel,str(g.minigame_checkpoint.get("notice","")),Vector2(28,140),Vector2(695,60),16)
	for i in range(2):
		g.button_at(g.app_panel,str(item[1][i]),Vector2(28,211+i*49),Vector2(695,42),func():
			if i == int(item[2]):
				g.minigame_checkpoint.stage = stage+1
				g.minigame_checkpoint.notice = "Шаг выполнен. Куб начинает подозревать, что ты учишься."
				if stage == 4:
					finish_model(g,true)
					return
			else:
				g.minigame_checkpoint.errors = int(g.minigame_checkpoint.errors)+1
				g.minigame_checkpoint.notice = ["Поиск не стал трёхмерным от твоей уверенности.","Лампа осветит проблему, но ключом не станет.","Ключ размером с дом требует дверь размером с район.","Картинка ключа откроет только галерею.","Файл существует. Геометрия в текстовый файл не переехала."][stage]
				if int(g.minigame_checkpoint.errors) >= 2:
					g.minigame_checkpoint.notice += " Подсказка: «" + str(item[1][item[2]]) + "»."
			g.save_progress()
			show_blender_game(g)
		)
	g.button_at(g.app_panel,"Сохранить куб и продолжить",Vector2(28,323),Vector2(330,40),func(): finish_model(g,false))
	g.save_progress()

static func finish_model(g: Variant, success: bool) -> void:
	g.story.decide("blender_training", "success" if success else "cube", {}, {"model_game_completed":true,"learned_blender":success,"bad_key_export":not success})
	if success: g.story.set_value("learned_blender", true)
	g.minigame_checkpoint.clear()
	AchievementManager.report_story_event("model_game_finished")
	if g.step != g.Step.BLENDER:
		g.play_chapter_scene("blender_replay",[S.line("grat","happy" if success else "embarrassed","Экспорт проверен. Основной сюжет не откатывается; тренировку можно повторить." if success else "Куб сохранён. Попробую ещё раз, когда захочу разобраться.")])
	elif success:
		g.play_chapter_scene("blender_training",[S.line("grat","happy","Получилось! Экспорт есть. Правда, это пока заготовка без зубцов. Дверь не обязана открываться от моей гордости."),S.line("jbt","happy","Ты разобрался с мешем, масштабом и экспортом. Давай теперь доведём геометрию до ключа. Открой Scripting — покажу следующий шаг.")])
	else:
		g.begin_flow("blender")
	g.save_progress()

static func observe_model(g: Variant) -> void:
	if g.step == g.Step.BLENDER:
		g.begin_flow("blender")
	else:
		g.play_chapter_scene("blender_replay",[S.line("grat","neutral","Куб на месте. Я тоже. Можно открыть тренировку и разобраться с экспортом, но основной сюжет от этого не откатится.")])

static func show_brainstorm(g: Variant) -> void:
	if g.minigame_checkpoint.get("kind", "") != "brainstorm":
		g.minigame_checkpoint = {"kind":"brainstorm","picks":[],"phase":"pick"}
	g.app_header("Артбей / бизнес-план на салфетке")
	g.hint_label.show()
	g._show_hint("Выбери три идеи и первый шаг · Esc — вернуться · продолжение доступно с телефона")
	var ideas := {"prototype":"Закончить короткий пролог", "story":"История и заметная механика", "test":"Проверить сборку с другом", "ad":"Сразу купить рекламу", "meme":"Вирусный мем", "donate":"Донаты до готовой игры", "sale":"Продать ещё не готовую игру"}
	var picks: Array = g.minigame_checkpoint.get("picks",[])
	if g.minigame_checkpoint.get("phase","pick") == "priority":
		g.text_at(g.app_panel,"Что делаем первым?",Vector2(28,87),Vector2(695,40),24)
		for i in range(picks.size()):
			var selected: String = str(picks[i])
			g.button_at(g.app_panel,str(ideas[selected]),Vector2(28,145+i*50),Vector2(695,42),func(): finish_brainstorm(g,picks,selected))
	else:
		g.text_at(g.app_panel,"Выбери три идеи: %d / 3" % picks.size(),Vector2(28,78),Vector2(695,35),22)
		var keys: Array = ideas.keys()
		for i in range(keys.size()):
			var identifier: String = str(keys[i])
			g.button_at(g.app_panel,("✓ " if picks.has(identifier) else "□ ")+str(ideas[identifier]),Vector2(28+(i%2)*350,125+floori(float(i)/2.0)*43),Vector2(338,37),func():
				if picks.has(identifier): picks.erase(identifier)
				elif picks.size()<3: picks.append(identifier)
				g.minigame_checkpoint.picks = picks
				g.save_progress()
				show_brainstorm(g)
			)
		var go: Button = g.button_at(g.app_panel,"Определить первый шаг →",Vector2(28,326),Vector2(330,40),func():
			g.minigame_checkpoint.phase = "priority"
			g.save_progress()
			show_brainstorm(g)
		)
		go.disabled = picks.size() != 3
	g.save_progress()

static func finish_brainstorm(g: Variant, picks: Array, first: String) -> void:
	var grounded: bool = first in ["prototype","story","test"]
	g.story.decide("artrey_brainstorm",first,{"affection_artbay":2 if grounded else 1},{"brainstorm_picks":picks.duplicate(),"brainstorm_first":first,"fast_money":not grounded,"brainstorm_completed":true})
	g.minigame_checkpoint.clear()
	var response := "Вот это план. Сначала рабочий кусок. Рекламу обсудим, когда людям будет что запускать." if grounded else "Продать до релиза? Можно попробовать питч. Только осторожно: обещания потом придётся выполнять. Главное — не продать уверенность вместо игры."
	g.play_chapter_scene("artrey_plan_done",[S.line("artrey","neutral",response),S.line("grat","happy","Записал. Первый раз список задач длиннее названия папки."),S.line("artrey","happy","И копию проверь сам. Для совместного списка мне достаточно картинки. Доступы обсудим, когда вообще появится что публиковать.")])
	g.save_progress()
