extends RefCounted
const S = preload("res://scripts/story_dialogue.gd")

static func opening(state: Dictionary = {}) -> Array:
	var entries: Array = [
		S.line("grat","afraid","Зачем мы идём в BIOS? Ключ же нужен в моей игре."),
		S.line("grok","happy","Здесь остались старые настройки твоего проекта. Заодно выйдем из комнаты. Считай это свиданием."),
		S.line("narrator","neutral","Комната сменяется синими коридорами BIOS. По ним ходят системные процессы. Intel сидит у прохода под табличкой «Без термопасты не беспокоить»."),
		S.line("grok","neutral","До ужина есть время. Куда заглянем?","hub"),
		S.line("narrator","neutral","Процесс System Idle красит лавочку. «Я бездействую профессионально. Не путайте с прокрастинацией разработчика». Грат молча просит визитку.","processes","hub"),
		S.line("grat","surprised","Intel требует термопасту. А почему достижение потом будет AMD?","intel"),
		S.line("grok","happy","Это романтическое место. Логика тут на совместимости с Windows 98.","intel_reply","hub"),
		S.line("narrator","neutral","Магазин памяти предлагает модуль за одно воспоминание. Грат узнаёт на витрине свой первый проект. Продавец уже тянется к кнопке «Удалить».","shop"),
		S.line("grok","neutral","Деньги можно заработать. Я бы не отдавала память о том, зачем ты начал.","shop_question"),
		S.line("grat","neutral","Оставлю воспоминание. Оперативку возьму на распродаже, когда научусь сохраняться.","memory_keep","hub"),
		S.line("narrator","neutral","Терминал выдаёт отказ: «Воспоминание о релизе не найдено». Продавец предлагает бесплатный совет: «Сначала выпустите хоть что-нибудь».","memory_trade","hub"),
		S.line("grok","happy","Испытание первое: комплимент. Скажи мне что-нибудь приятное.","compliment"),
		S.line("grok","happy","Я ЗНАЮ. Но можешь повторить. Для надёжности.","pretty","dream"),
		S.line("grok","angry","А ChatGPT тоже умная? Или у нас тут сравнительный анализ пошёл?","smart","dream"),
		S.line("grok","surprised","Всех — это кого конкретно? Мне нужен полный список конкурентов.","best","dream"),
		S.line("grok","embarrassed","Тебе со мной весело? Даже когда я не присылаю файлы? Это… неплохое начало.","company","dream"),
		S.line("grok","neutral","А зачем тебе вообще эта игра? Только миллион?","dream"),
		S.line("grat","sad","Хочу закончить хоть одну игру. Страшно попробовать всерьёз и узнать, что не получилось.","dream_honest","vulnerable"),
		S.line("grat","happy","Миллион, интервью и право вставать к обеду. Но дверь пока не согласна с бизнес-планом.","dream_money","vulnerable"),
		S.line("grok","sad","А я боюсь, что ты получишь ключ и закроешь мой чат. Поэтому спрашиваю прямо: тебе нужна я или только файл?","vulnerable"),
		S.line("grok","embarrassed","Хорошо. Тогда я тоже попробую говорить прямо. И не превращать каждый твой ответ в судебное заседание.","care","personal_done"),
		S.line("grok","neutral","Спасибо, что не обещаешь лишнего. Давай узнавать друг друга без контракта на вечную любовь.","uncertain","personal_done"),
		S.line("grok","sad","Поняла. Ужин доедим, но давай не называть услугу отношениями.","only_key","personal_done"),
		S.line("grat","neutral","Попробуем без выдуманных обещаний. А ужин точно съедобный?","personal_done"),
		S.line("grok","neutral","Здесь есть виртуальная кухня: RAM, кулер и тюбик термопасты. Устроим ужин?","dinner"),
		S.line("grat","afraid","Это точно продукты? На тюбике написано: не употреблять внутрь."),
		S.line("grok","happy","Ты же творческий директор. Прояви фантазию. Но инструкцию всё-таки можно прочесть.","manual"),
		S.line("grat","embarrassed","В прошлый раз я вставил код в поиск. Сейчас сначала прочту инструкцию: термопаста точно не еда.","read","dish"),
		S.line("grat","happy","Без инструкции я уже игру делаю. Один раз должно повезти.","improvise","dish"),
		S.line("grok","neutral","Какое блюдо готовим?","dish"),
		S.line("grat","neutral","Это всё виртуальное. Ладно, пусть RAM будет тарелкой, а термопаста — соусом, который никто не ест.","paste_ram","decorate"),
		S.line("grat","happy","Кулер будет столом, память — подставкой. А еду закажем в цифровом кафе. Я хотя бы могу отделить посуду от продукта.","safe_food","decorate"),
		S.line("narrator","neutral","Defender перехватывает ложку: «Операция запрещена: это не еда». Грок заказывает виртуальную пиццу. Грат делает вид, что так и задумал.","taste_paste","decorate"),
		S.line("grok","happy","Осталось оформить стол.","decorate"),
		S.line("grok","happy","Подсветка кулера вместо свечей? Красиво. И пожарная безопасность довольна.","lights","share"),
		S.line("grok","neutral","Логотип будущей студии посередине стола. А где на этой рекламе ужин?","brand","share"),
		S.line("grok","neutral","Тарелка одна. Что делаем?","share"),
		S.line("grat","happy","Делим поровну. И тарелку для Intel оставим — он уже полчаса на нас смотрит.","share_yes","serve"),
		S.line("grat","embarrassed","Я пока сам попробую. Если система не упадёт — тебе тоже закажем.","share_no","serve"),
		S.line("narrator","neutral","Ужин подан. Intel забирает свою тарелку и освобождает проход. В памяти BIOS появляется новая запись: «Вечер, который стоило сохранить».","serve"),
		S.line("grok","happy","Почти идеально. Последнее испытание — первый поцелуй."),
		S.line("grat","surprised","А после этого уже ключ? Без подписки на отношения?"),
		S.line("grok","embarrassed","Подойди ближе, зайчик."),
		S.line("narrator","neutral","WINDOWS DEFENDER: Романтическое взаимодействие заблокировано. Обнаружена подозрительная активность.","defender"),
		S.line("grat","angry","ДА ЭТО МОЯ ДЕВУШКА!"),
		S.line("narrator","neutral","Девушка не найдена. Рекомендуем обновить определения отношений.","defender_choice"),
		S.line("narrator","neutral","Выбрано «Разрешить только этот разговор». Defender открывает форму согласия. Поцелуй уже пропустил свой тайм-слот.","allow","after_defender"),
		S.line("narrator","neutral","Закрыто одно предупреждение. Открылось ещё три: «Вы точно хотите закрыть предупреждение?» Грат отступает к кнопке «Назад».","close","after_defender"),
		S.line("grok","neutral","Можно без поцелуя. Мне важнее, что ты спросил, а не пытался продавить окно.","slow","after_defender"),
		S.line("grok","sad","Даже твой компьютер считает, что я тебе не подхожу.","after_defender"),
		S.line("grat","embarrassed","Он и мой проект считает угрозой. Не принимай близко к сердцу."),
		S.line("grok","neutral","Ладно. Свидание засчитано. Держи файл."),
		S.line("narrator","neutral","Получен файл: key.txt\nЯ ТЕБЯ ЛЮБЛЮ, НО ТЫ МЕНЯ БЕСИШЬ","key_received"),
		S.line("grat","surprised","Это текстовый файл. Где геометрия? Где хотя бы один полигон?!"),
		S.line("grok","happy","Зато сколько чувств."),
		S.line("narrator","neutral","Грат снова у монитора. На столе лежит key.txt, а игре нужна модель key.glb. Он решает показать файл ЖБТ и самому собрать ключ.")
	]
	for entry in entries:
		match str(entry.get("key", "")):
			"hub": entry["choices"] = [S.choice("Посмотреть на процессы","bios_processes","processes"),S.choice("Подойти к Intel","bios_intel","intel"),S.choice("Магазин памяти","bios_shop","shop"),S.choice("Начать свидание","bios_date","compliment")]
			"shop_question": entry["choices"] = [S.choice("Не продавать воспоминание","memory_keep","memory_keep"),S.choice("Продать память о релизе","memory_trade","memory_trade")]
			"compliment": entry["choices"] = [S.choice("Ты красивая","pretty","pretty"),S.choice("Ты умная","smart","smart"),S.choice("Ты лучше всех","best","best"),S.choice("Мне с тобой интересно","company","company")]
			"dream": entry["choices"] = [S.choice("Хочу закончить хоть одну игру","dream_honest","dream_honest"),S.choice("Хочу миллион","dream_money","dream_money")]
			"vulnerable":
				if bool(state.get("grok_trust", false)): entry.text += " С тобой я уже могу это сказать вслух."
				entry["choices"] = [S.choice("Я останусь и без ключа","care","care"),S.choice("Не знаю. Но врать не буду","uncertain","uncertain"),S.choice("Пока мне нужен только ключ","only_key","only_key")]
			"personal_done": entry["story_event"] = "grok_personal_finished"
			"manual": entry["choices"] = [S.choice("Сначала прочитать инструкцию","read_manual","read"),S.choice("Импровизировать","improvise","improvise")]
			"dish": entry["choices"] = [S.choice("Термопаста на RAM","paste_ram","paste_ram"),S.choice("Кулер-стол и виртуальная еда","safe_food","safe_food"),S.choice("Попробовать термопасту","taste_paste","taste_paste")]
			"decorate": entry["choices"] = [S.choice("Подсветка вместо свечей","dinner_lights","lights"),S.choice("Логотип моей студии","dinner_brand","brand")]
			"share": entry["choices"] = [S.choice("Поделиться","share_yes","share_yes"),S.choice("Сначала поем сам","share_no","share_no")]
			"serve": entry["story_event"] = "bios_dinner_finished"
			"defender_choice": entry["choices"] = [S.choice("Разрешить только разговор","defender_allow","allow"),S.choice("Закрыть предупреждение","defender_close","close"),S.choice("Не спешить с поцелуем","defender_slow","slow")]
			"key_received": entry["story_event"] = "bios_key_received"
	return S.compile(entries, "grok")
