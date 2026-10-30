extends RefCounted

const S = preload("res://scripts/story_dialogue.gd")

static func opening(values: Dictionary) -> Array:
	var entries: Array = [
		S.line("narrator","neutral","Глава 7. Последняя сборка. До дедлайна релиза осталось несколько часов, а на экране всё ещё мигает: KEY NOT FOUND."),
		S.line("grok","neutral","Я могу помочь с геометрией. Но скажи честно: ты бы позвал меня, если бы ключ уже был?"),
		S.line("jbt","neutral","Я проведу тебя через проверку. Только не записывай мою помощь как обязанность."),
		S.line("artrey","neutral","Публикация готова. Но сначала реши, кто отвечает за сборку и кому принадлежат файлы."),
		S.line("grat","happy","Сначала соберу игру так, чтобы дверь открылась. Потом отвечу каждому прямо."),
		S.line("narrator","neutral","На монтажном столе четыре схемы маршрутизации. Поворачивай узлы и проведи сигнал от источника к двери. Ошибки можно исправить.","last_build")
	]
	entries[5]["story_event"] = "last_build"
	return S.compile(entries)

static func final_choice(values: Dictionary) -> Array:
	var entries: Array = [
		S.line("narrator","neutral","Дверь открылась. На экране готовая игра и несколько вариантов релиза. Выбери решение; игра покажет его последствия."),
		S.line("grat","neutral","Что я хочу сохранить, когда игра выйдет?","choice"),
		S.line("grat","neutral","Личный маршрут. С кем я хочу быть рядом?","relationships"),
		S.line("grat","neutral","Решение о проекте. Как мы выпускаем игру?","project_routes"),
		S.line("grat","neutral","Особые варианты доступны только при выполнении условий.","special_routes"),
		S.line("grat","neutral","Рискованные исходы: контроль Артрея или признание использования друзей.","risk_routes")
	]
	var main_choices: Array = [S.choice("Личный маршрут","c7_page_relationships","relationships"),S.choice("Решение о проекте","c7_page_project","project_routes")]
	var relationships: Array = []
	if bool(values.get("grok_date_completed",false)) and bool(values.get("grok_without_key",false)):
		relationships.append(S.choice("Попросить Грок остаться рядом, даже без задачи","c7_grok","grok"))
	if bool(values.get("gpt_boundaries",false)):
		relationships.append(S.choice("Выбрать ЖБТ как партнёра по жизни и работе","c7_jbt","jbt"))
	if bool(values.get("artbay_contract_signed",false)) and bool(values.get("project_ownership_proven",false)):
		relationships.append(S.choice("Подписать с Артреем проверенный договор","c7_artrey","artrey"))
	relationships.append(S.choice("Назад","c7_back_relationships","choice"))
	entries[2]["choices"] = relationships
	var project_routes: Array = [S.choice("Выпустить игру одному и поблагодарить всех","c7_solo","solo"),S.choice("Назад","c7_back_project","choice")]
	if bool(values.get("defused_tab_war",false)):
		project_routes.push_front(S.choice("Закончить игру вместе, без обещаний отношений","c7_team","team"))
	entries[3]["choices"] = project_routes
	var choices: Array = []
	if bool(values.get("secret_protocol",false)) and (bool(values.get("stamp_obtained",false)) or bool(values.get("stamp_stolen",false))):
		choices.append(S.choice("Достать Протокол 0 и министерскую печать","c7_ministry","ministry"))
	if bool(values.get("defused_tab_war",false)) and int(values.get("affection_grok",0)) >= 2 and int(values.get("affection_gpt",0)) >= 2 and int(values.get("affection_artbay",0)) >= 2:
		choices.append(S.choice("Секретно: обещать всем троим романтический финал","c7_triple","triple"))
	var risk_choices: Array = []
	if bool(values.get("artbay_control_taken",false)):
		risk_choices.append(S.choice("Оставить контроль публикации Артрею","c7_artrey_bad","artbay_bad"))
	if int(values.get("lies_count",0)) >= 2 or (bool(values.get("artbay_control_taken",false)) and bool(values.get("lied_in_court",false))):
		risk_choices.append(S.choice("Признать, что я хотел только чужой труд","c7_instrument","instrumental"))
	if not risk_choices.is_empty():
		choices.append(S.choice("Рискованные исходы","c7_page_risk","risk_routes"))
	entries[5]["choices"] = risk_choices + [S.choice("Назад","c7_back_risk","special_routes")]
	if choices.size() > 0:
		main_choices.append(S.choice("Особые варианты","c7_page_special","special_routes"))
	entries[1]["choices"] = main_choices
	choices.append(S.choice("Назад","c7_back_special","choice"))
	entries[4]["choices"] = choices
	var endings := ["grok","jbt","artrey","team","solo","instrumental","ministry","triple"]
	for id in endings:
		var title := str(id).to_upper()
		entries.append(S.line("narrator","neutral","ФИНАЛ: " + title + "." ,id,"wrap"))
	entries.append(S.line("grat","happy","Я закончил игру. Теперь в титрах будет понятно, кто что сделал — и кто сам решил остаться.","wrap"))
	return S.compile(entries)

static func ending_text(id: String, values: Dictionary) -> String:
	match id:
		"grok": return "Грок остаётся рядом не ради файла. Вы договариваетесь говорить прямо и не превращать помощь в долг. Игра выходит с ключом, который вы собрали вместе."
		"jbt": return "ЖБТ помогает проверить экспорт, но автором остаётся Грат. Вы выбираете отношения, в которых можно быть рядом и без технической заявки."
		"artrey": return "Артрей исправляет титры и подписывает прозрачный договор. Публикация проходит под общим контролем; авторство Грата указано в первой строке."
		"artbay_bad": return "Артрей выпускает копию под своим именем. Грат сохраняет резерв и восстанавливает игру, но теряет контроль над первой публикацией. Следующий билд он собирает сам."
		"team": return "Грок, ЖБТ и Артрей соглашаются закончить проект командой. Романтических обещаний нет; у каждого есть своя роль и право отказаться."
		"instrumental": return "Грат признаёт, что снова видел в людях кнопки и услуги. Проект он восстанавливает сам, но отношения придётся начинать с извинения."
		"ministry": return "Протокол 0 и печать телепортируются в релизное окно. Министерство одобряет отсутствующий ключ и требует выпустить игру вчера."
		"triple": return "Грат пообещал всем троим романтический финал. Грок, ЖБТ и Артрей одновременно требуют уточнить договор, и судья-принтер оформляет ему повестку за превышение симпатии. Игру всё равно можно допройти честным маршрутом."
		_: return "Грат выпускает игру самостоятельно, указывает реальный вклад каждого и оставляет личные отношения без обещаний. Дверь наконец открывается."
