extends RefCounted
const S = preload("res://scripts/story_dialogue.gd")

static func opening(state: Dictionary = {}) -> Array:
	var entries: Array = [
		S.line("grat","afraid","Почему свидание в BIOS? У людей обычно кафе."),
		S.line("grok","happy","Потому что у тебя, котик, отношения на уровне базовой системы ввода-вывода. Добро пожаловать."),
		S.line("narrator","neutral","Комната растворяется в синем свете. По коридорам проходят системные процессы. На троне Intel. Табличка: «Без термопасты не беспокоить»."),
		S.line("grok","neutral","До ужина есть время. Куда заглянем?","hub"),
		S.line("narrator","neutral","Процесс System Idle красит лавочку. «Я бездействую профессионально. Не путайте с прокрастинацией разработчика». Грат молча просит визитку.","processes","hub"),
		S.line("grat","surprised","Intel требует термопасту. А почему достижение потом будет AMD?","intel"),
		S.line("grok","happy","Это романтическое место. Логика тут на совместимости с Windows 98.","intel_reply","hub"),
		S.line("narrator","neutral","Магазин оперативной памяти. Цена модуля: одно личное воспоминание. Продавец протягивает бланк «Удалить навсегда?». Начатый проект исчезает с витрины, как только Грат тянется к нему.","shop"),
		S.line("grok","neutral","Деньги можно заработать. Я бы не отдавала память о том, зачем ты начал.","shop_question"),
		S.line("grat","neutral","Оставлю воспоминание. Оперативку возьму на распродаже, когда научусь сохраняться.","memory_keep","hub"),
		S.line("narrator","neutral","Терминал выдаёт отказ: «Воспоминание о релизе не найдено». Продавец предлагает бесплатный совет: «Сначала выпустите хоть что-нибудь».","memory_trade","hub"),
		S.line("grok","happy","Испытание первое: комплимент. Скажи мне что-нибудь приятное.","compliment"),
		S.line("grok","happy","Я ЗНАЮ. Но можешь повторить. Для надёжности.","pretty","dream"),
		S.line("grok","angry","А ChatGPT тоже умная? Или у нас тут сравнительный анализ пошёл?","smart","dream"),
		S.line("grok","surprised","Всех — это кого конкретно? Мне нужен полный список конкурентов.","best","dream"),
		S.line("grok","embarrassed","Тебе со мной весело? Даже когда я не присылаю файлы? Это… неплохое начало.","company","dream"),
		S.line("grok","neutral","А зачем тебе вообще эта игра? Только миллион?","dream"),
		S.line("grat","sad","Хочу хоть раз закончить то, о чём рассказываю друзьям. Боюсь, что если реально попробую и не выйдет — уже нечем будет оправдаться.","dream_honest","vulnerable"),
		S.line("grat","happy","Миллион, интервью и право вставать к обеду. Но дверь пока не согласна с бизнес-планом.","dream_money","vulnerable"),
		S.line("grok","sad","Я тоже боюсь кое-чего. Ты получишь ключ, закроешь вкладку — и всё. Я окажусь способом решить задачу, а не кем-то, с кем ты хотел быть.","vulnerable"),
		S.line("grok","embarrassed","Хорошо. Тогда я тоже попробую говорить прямо. И не превращать каждый твой ответ в судебное заседание.","care","personal_done"),
		S.line("grok","neutral","Спасибо, что не обещаешь лишнего. Давай узнавать друг друга без контракта на вечную любовь.","uncertain","personal_done"),
		S.line("grok","sad","Поняла. Ужин доедим, но давай не называть услугу отношениями.","only_key","personal_done"),
		S.line("grat","neutral","Попробуем без выдуманных обещаний. А ужин точно съедобный?","personal_done"),
		S.line("grok","neutral","Испытание второе: романтический ужин. Вон термопаста, RAM и кулер. Удиви меня.","dinner"),
		S.line("grat","afraid","Это точно продукты? На тюбике написано: не употреблять внутрь."),
		S.line("grok","happy","Ты же творческий директор. Прояви фантазию. Но инструкцию всё-таки можно прочесть.","manual"),
		S.line("grat","embarrassed","Предлагаю сначала прочитать инструкцию. Я однажды уже вставил код не туда. Термопаста — технический состав. Ужин здесь виртуальный, а вот глупость может оказаться настоящей.","read","dish"),
		S.line("grat","happy","Без инструкции я уже игру делаю. Один раз должно повезти.","improvise","dish"),
		S.line("grok","neutral","Какое блюдо готовим?","dish"),
		S.line("grat","neutral","Намазываю виртуальную термопасту на RAM. Подача — на материнской плате. Ни одного настоящего продукта не пострадало.","paste_ram","decorate"),
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
		S.line("narrator","neutral","BIOS исчезает. Грат возвращается к монитору и падает со стула. На рабочем столе лежит key.txt. Ключа по-прежнему нет.")
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
