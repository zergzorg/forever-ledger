local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- Settings tab (October 4 redesign, after EllesmereUI's options window; owner): a
-- sidebar with Global settings (the same for every character), Profiles, then the
-- feature groups, gold making first. A page can have tabs across the top for its parts.
-- Changes apply straight away. Search finds a setting on any page.
-- Global settings decide what prices, flips and deals are, so they're account-wide and
-- never in a profile; every other setting is in the character's profile (Core.lua:
-- ApplyCharSettings, ns.PER_CHAR_SETTINGS).
---------------------------------------------------------------------------
local function recalc() ns:InvalidateValues(true) end
local function ads() ns:UpdateCustomerAds() end

-- A setting: key, label, kind (check, number, money, choice), help; numbers have min,
-- max and suffix, money a plainUnit, choices their options; after runs after a change.
-- A label starting with spaces is a sub-option of the one above it. { sub = "..." } is
-- a small heading.
local PAGES = {
  { key = "global", title = "Глобальные настройки", icon = "Interface\\AddOns\\ForeverLedger\\media\\icons\\global",
    desc = "Одинаковы для всех персонажей и профилей: они решают, сколько стоят предметы и что считается перепродажей или сделкой.",
    tabs = {
      { name = "Цены", rows = {
        { sub = "Как оцениваются предметы" },
        { key = "ahCut", label = "Комиссия аукциона", kind = "number", suffix = "%", min = 0, max = 99, after = recalc,
          help = "Вычитается из каждой продажи на аукционе в оценках и цепочках, на аукционе вашей фракции. Нейтральные (Бухта Боти, Прибамбасск, Круговзор) берут 15% и считаются отдельно." },
        { key = "margin", label = "Запас", kind = "number", suffix = "%", min = 0, max = 99,
          help = "Цепочки и «покупать по или ниже» держат такую долю ниже стоимости предмета." },
        { key = "actionSeconds", label = "Секунд на изготовление", kind = "number", suffix = "сек", min = 1, max = 60,
          help = "Для примерной прибыли в час." },
        { key = "source", label = "Цены аукциона из", kind = "choice", after = recalc, options = {
            { "auto", "Авто" }, { "own", "Мои проверки" }, { "Auctionator", "Auctionator" }, { "TSM", "TSM" }, { "Auctioneer", "Auctioneer" } },
          help = "Авто берёт ваши свежие проверки, затем другие аукционные аддоны." },
      } },
      { name = "Перепродажи и сделки", rules = true, rows = {
        { sub = "Перепродажи торговцу" },
        { key = "dealVendorPct", label = "Мин. прибыль от цены", kind = "number", suffix = "% от цены торговца", min = 0, max = 99, after = recalc,
          help = "Продажа торговцу без риска, только усилия на покупку. 0 считает любой лот дешевле цены торговца." },
        { key = "dealVendorMin", label = "Мин. прибыль за штуку", kind = "money", after = recalc,
          help = "Например 10c или 1s. «выкл» — без минимума. Перепродаже нужны и эта сумма, и доля выше." },
        { sub = "Сделки" },
        { key = "dealUsualPct", label = "Ниже обычной цены на", kind = "number", suffix = "% и больше", min = 1, max = 99 },
        { key = "dealWindow", label = "Обычная цена за", kind = "choice", options = {
            { "week", "Неделя" }, { "month", "Месяц" }, { "3months", "3 месяца" }, { "6months", "6 месяцев" },
            { "year", "Год" }, { "all", "Всё время" } } },
        { key = "dealHistory", label = "Обычные цены из", kind = "choice", options = {
            { "auto", "Авто" }, { "local", "Мои проверки" }, { "tsm", "TSM" } },
          help = "Авто берёт историю TSM, где есть цена, иначе ваши проверки." },
        { key = "dealUsualMin", label = "Мин. прибыль при перепродаже", kind = "money",
          help = "Вкладка «Сделки»: прибыль после комиссии аукциона при перепродаже по обычной цене или ниже следующего лота. «выкл» — без минимума." },
      } },
      -- Parts of the addon you can switch off whole (owner, October 7: modules, so extras
      -- don't crowd the window). Off means not running at all. More join with the side tabs.
      { name = "Модули", rows = {
        -- (Leveling help, the Leveling tab and training advice, was archived November 14.)
        { sub = "Обзор" },
        { key = "ridingFund", label = "Сбор на транспорт в Обзоре", kind = "check", after = function() ns:RefreshUI() end,
          help = "Полоса под плитками: транспорт, которого у персонажа ещё нет (потом эпический), его цена, сколько золота уже есть и примерно сколько дней при вашем темпе. Исчезает после обучения. «Скрыть» на полосе убирает её у одного персонажа; /fl fund вернёт." },
      } },
      { name = "Дополнительно", rows = {
        { sub = "Синхронизация со вторым аккаунтом" },
        { key = "syncMoney", label = "Делиться золотом и продажами с партнёром", kind = "check",
          after = function() if ns.SyncSend then ns:SyncSend(true) end end,
          help = "Отправляет золото персонажей, приход и расход, записи журнала и сессии связанному персонажу (Настройки, Персонажи), чтобы Обзор и Журнал на обоих аккаунтах совпадали. Там есть имена покупателей, поэтому не включайте, если связали друга. Отвязка удаляет полученное от него." },
        { key = "syncBags", label = "Делиться сумками и банком с партнёром", kind = "check",
          after = function() if ns.SyncSend then ns:SyncSend(true) end end,
          help = "Отправляет содержимое сумок и банка связанному персонажу (Настройки, Персонажи), чтобы это учитывалось в «Есть», списках покупок и вкладке «Персонажи». Только для своего второго аккаунта: по умолчанию выкл. Отвязка удаляет полученное от него." },
        { sub = "Проверка" },
        { key = "debug", label = "Отладочные сообщения", kind = "check", help = "Дополнительные строки в чате для проверки." },
      } },
    } },

  { key = "profiles", title = "Профили", icon = "Interface\\AddOns\\ForeverLedger\\media\\icons\\profiles", custom = true,
    desc = "Наборы настроек, которыми персонажи могут делиться, переключаться между ними, экспортировать и импортировать." },

  { key = "appearance", title = "Внешний вид", icon = "Interface\\AddOns\\ForeverLedger\\media\\icons\\appearance",
    desc = "Как выглядят окна Forever Ledger. Изменение видно после перезагрузки.",
    rows = {
      { sub = "Тема и цвет" },
      { key = "theme", label = "Тема", kind = "choice", after = function() ns:OfferReload() end, options = {
          { "clean", "FL Clean" }, { "default", "FL Bronze" }, { "gilded", "FL Gilded" } },
        help = "FL Clean: плоская и тихая. FL Bronze: бронзовый край, золотые заголовки, секции-карточки, переключатели. FL Gilded: бронзовая рамка и золотые заголовки с засечками. Оформление в стиле окон WoW Forever и Blizzard появится позже." },
      { key = "uiScale", label = "Размер", kind = "slider", min = 75, max = 150, step = 5, suffix = "%",
        after = function() if ns.ApplyScale then ns:ApplyScale() end end,
        help = "Размер окон Forever Ledger от 75% до 150%. Перетащите и отпустите." },
      { key = "accent", label = "Цвет акцента", kind = "accent", after = function() ns:OfferReload() end,
        help = "Цвет активного: выбранная вкладка, включённые переключатели, подсветка. Авто берёт цвет EllesmereUI, если он установлен." },
    } },

  { group = "Заработок" },
  { key = "ah", title = "Аукцион", icon = "Interface\\Icons\\INV_Misc_Coin_02",
    desc = "Покупка, продажа и оповещения на аукционе.",
    tabs = {
      { name = "Покупка", rows = {
        { sub = "Окно аукциона" },
        { key = "ahHighlight", label = "Отмечать выгодные покупки", kind = "check",
          help = "Лоты по цене покупки или ниже получают зелёный фон, полосу и значок «BUY»." },
        { sub = "Очередь покупок" },
        { key = "vendorItemsAH", label = "Покупать товары торговцев и на аукционе", kind = "check",
          after = function() if ns.RefreshListsView then ns:RefreshListsView() end; if ns.RebuildBuyQueue then ns:RebuildBuyQueue() end end,
          help = "Товары торговцев с бесконечным запасом из списков обычно не попадают в очередь аукциона. Вкл: покупать их там не дороже цены торговца. С ограниченным запасом остаются обычными лотами." },
        { key = "openFlips", label = "Открывать очередь покупок после полной проверки", kind = "check",
          help = "Когда полная проверка находит перепродажи торговцу, а очередь покупок у аукциона закрыта, открыть её. Новые перепродажи между полными проверками только звенят." },
        { key = "stackTwoClicks", label = "Подтверждать стопки вторым щелчком", kind = "check",
          help = "Выкл.: стопка материалов покупается одним тиком или щелчком — тот, что начинает покупку, подтверждает её, когда итоговая цена укладывается в предел и в доступное золото. Вкл.: второй тик или щелчок подтверждает после показа итоговой цены." },
        { key = "watchResume", label = "Возобновлять слежение за перепродажами", kind = "check",
          help = "Если слежение было включено при закрытии аукциона, запустить его снова при возвращении. Проверять оно может только при открытом аукционе." },
        { key = "keepGold", label = "Очередь покупок: всегда оставлять", kind = "money", plainUnit = "g",
          help = "Очередь не опускает ваше золото ниже этого, чтобы всегда хватало на ремонт, обучение или транспорт. Введите 100 для 100g. «выкл»: может потратить всё. (Максимум на визит задаётся в самой очереди.)" },
      } },
      { name = "Продажа", rows = {
        { sub = "Вкладка продажи" },
        { key = "priceHelper", label = "Помощь с ценой на вкладке продажи", kind = "check",
          help = "Под кнопкой создания лота: обычная цена и минимум сейчас, кнопки подставить на 1 медь ниже минимума или обычную цену. Сообщает, когда минимум заметно ниже обычного." },
        { key = "sellGuard", label = "Не выставлять дешевле цены торговца", kind = "check",
          help = "На вкладке продажи, если торговец даёт больше, чем аукцион после комиссии, «Выставить» недоступна, пока не нажмёте «Всё равно выставить». Выкл: только предупреждение." },
        { sub = "Ваши аукционы" },
        { key = "undercutAlerts", label = "Оповещения о перебитых лотах", kind = "check",
          help = "Когда проверка находит ваш перебитый лот: строка в чате, раз на цену. Вкладка «Аукционы» у аукциона покажет все." },
        { key = "undercutSound", label = "  Звук при оповещениях о перебитых", kind = "check",
          help = "Короткий сигнал с каждым оповещением о перебитом лоте." },
        { key = "saleSound", label = "Звук при продаже лота", kind = "check",
          help = "Звук монет, когда игра сообщает, что на ваш лот нашёлся покупатель." },
        { key = "soldSummary", label = "Что продалось без вас", kind = "check",
          help = "При открытии аукциона: строка в чате о том, что продалось с прошлого визита, и сколько золота это даёт." },
      } },
      { name = "Оповещения", rows = {
        { sub = "Новые перепродажи и сделки" },
        { key = "dealSound", label = "Звонок при новых перепродажах и сделках", kind = "check", help = "Играет звук предупреждения рейда, когда проверка находит новые перепродажи или сделки." },
        { key = "quietWatch", label = "Тихий режим во время слежения", kind = "check", after = function() ns:UpdateQuiet() end,
          help = "Пока идёт слежение: музыка, эффекты, окружение и голоса игры выключены, а звонки Forever Ledger звучат в полную громкость даже в фоне, плюс звонок при выигрыше лота. Настройки звука вернутся после остановки. /fl quiet включает это для одного персонажа, пока не введёте снова." },
        { key = "dealScreen", label = "Крупное сообщение на экране", kind = "check", help = "Показывает новые перепродажи и сделки крупным текстом вверху экрана, где предупреждения рейда. Отключите, если закрывает окна." },
        { key = "dealChat", label = "Строка в чате о новых перепродажах и сделках", kind = "check", help = "Перечисляет каждую новую перепродажу и сделку в чате." },
      } },
      { name = "Поиск распыления", rows = {
        { sub = "Броски" },
        { key = "deRolls", label = "Показывать неудачный и удачный бросок", kind = "check",
          help = "Помимо среднего — сколько стоят зелёные предметы уровня при неудачном и удачном броске (минимум и максимум распыления)." },
      } },
    } },
  { key = "tooltips", title = "Подсказки", icon = "Interface\\Icons\\INV_Misc_Note_01",
    desc = "Что Forever Ledger добавляет к подсказкам предметов.",
    tabs = {
      { name = "Общие", rows = {
        { sub = "Размер и детали" },
        { key = "tooltip", label = "Строки подсказки", kind = "check", help = "Строки Forever Ledger в подсказках предметов." },
        { key = "tipMode", label = "Размер подсказки", kind = "choice", options = {
            { "full", "Всё" }, { "compact", "Кратко, Shift — больше" } },
          help = "Короткий показывает сегодняшний минимум аукциона и стоимость для вас; Shift — остальное." },
        { key = "tipOptions", label = "Способов в «Стоит для вас»", kind = "number", suffix = "шт.", min = 1, max = 10,
          help = "Сколько способов применения перечислять, лучший первым." },
        -- On the first tab, where it's found (owner, November 8: "not sure where this
        -- option is" on What they show).
        { sub = "Окно цены" },
        { key = "priceWindow", label = "Клик по предмету открывает окно цены", kind = "check",
          help = "Alt+клик (или клик ниже) по предмету в сумках, ссылке в чате или лоту на аукционе: окно с графиком цены (до года), числом лотов, вашими запасами и лотами, вашими последними 7 днями и, если кто-то из персонажей умеет его изготавливать, стоимостью и прибылью. «Поиск цены» и /fl price <предмет> тоже открывают его." },
        { key = "priceClick", label = "Открывается по", kind = "choice", options = {
            { "alt", "Alt+клик" }, { "ctrl", "Ctrl+клик" }, { "ctrlalt", "Ctrl+Alt+клик" } },
          help = "Выберите другой клик, если Alt+клик занят другим аддоном (некоторые аддоны распыления). Ctrl+клик больше не открывает примерочную; при Ctrl+Alt+клике Ctrl+клик по-прежнему работает." },
      } },
      { name = "Что показывают", rows = {
        { sub = "Цены и стоимость" },
        { key = "tipPrice", label = "Цены аукциона и торговцев", kind = "check",
          help = "Минимум на аукционе (сколько лотов, как давно), среднее по 20 дешёвым и цена торговца." },
        { key = "tipHistory", label = "История цен при Ctrl", kind = "check",
          help = "Удерживайте Ctrl над предметом: минимум за 14 дней, направление, обычная цена месяца, обычное число лотов и исторический минимум." },
        { key = "tipSpeed", label = "Как быстро продаётся", kind = "check",
          help = "Быстро, стабильно, медленно, редко или продаж не видно, когда есть 3 часа проверок (и в первый день хотя бы 3 продажи)." },
        { key = "tipWorth", label = "Стоит для вас", kind = "check",
          help = "Лучший способ применения (аукцион, торговец, распыление или изготовление) и следующие по выгоде." },
        { key = "tipSell", label = "Подсказка о продаже", kind = "check",
          help = "На предметах в сумках: оставить (нужен заданию, используется в вашем рецепте, отслеживается или есть в списке) или продать торговцу, на аукционе, либо «на выбор», когда цены близки — с причиной; и распыление, если оно даёт больше. Это только подсказка: ничего не продаётся." },
        -- Which ways count (issue #15, October 22). Only the tooltip and the Characters
        -- tab; shuffles, the Buy queue and shopping lists still use every way.
        { key = "worthAH", label = "  Учитывать продажу на аукционе", kind = "check",
          help = "«Стоит для вас» и «Покупать по или ниже» учитывают продажу на аукционе. Цепочки, очередь и списки всегда учитывают все способы." },
        { key = "worthVendor", label = "  Учитывать продажу торговцу", kind = "check",
          help = "«Стоит для вас» и «Покупать по или ниже» учитывают цену торговца." },
        { key = "worthDisenchant", label = "  Учитывать распыление", kind = "check",
          help = "«Стоит для вас» и «Покупать по или ниже» учитывают распыление и продажу пыли и сущностей." },
        { key = "worthCraft", label = "  Учитывать изготовление и переделки", kind = "check",
          help = "«Стоит для вас» и «Покупать по или ниже» учитывают изготовление (рецепты любых ваших персонажей) или переделку, например разделение сущности. Отключите, если не хотите учитывать возможности альтов." },
        { key = "tipBuy", label = "Покупать по или ниже", kind = "check",
          help = "Максимум, который стоит платить, после запаса. Зелёное, если уже дешевле." },
        { key = "tipNeutral", label = "Бухта Боти, когда платит заметно больше", kind = "check",
          help = "Одна строка только для предметов, дающих хотя бы на 25% больше на нейтральном аукционе (Бухта Боти, Прибамбасск, Круговзор) после его комиссии 15%, по последней проверке там. По умолчанию выкл; вид «Бухта Боти» на вкладке «Сделки» покажет все." },
        { sub = "Применение и задания" },
        { key = "tipQuest", label = "Задания, где нужен предмет", kind = "check",
          help = "«Задания (3)»: сколько заданий просят предмет (оригинальные из Classic; в Forever часть могла измениться), и «оставьте себе», если персонажу он понадобится позже. Удерживайте Shift, чтобы увидеть задания." },
        { key = "tipQuestMine", label = "  Только задания, нужные этому персонажу", kind = "check",
          help = "Убирает выполненные, серые по уровню и задания других классов. Выкл: все, с пометками (выполнено), (низкий уровень) или (другой класс) — удобно при продаже другим." },
        { key = "tipDarkmoon", label = "Сдача на Ярмарке Новолуния", kind = "check",
          help = "Коралловая строка на предметах, которые Ярмарка Новолуния принимает за призовые билеты: сколько нужно на сдачу, сколько билетов даёт и кто принимает (список Classic; в Forever часть могла измениться)." },
        { key = "tipDisenchant", label = "Распыляется в", kind = "check",
          help = "Что в среднем даёт зелёный предмет при распылении." },
        { key = "tipUsedBy", label = "Используется в изготовлении", kind = "check",
          help = "«Используется в изготовлении (12)»: сколько изготовлений используют его, по профессиям, из всех известных рецептов. Удерживайте Shift, чтобы увидеть названия и рецепты ваших персонажей." },
        { key = "tipCrate", label = "Дешёвое заполнение ящика", kind = "check",
          help = "У Забытого ящика: самый дешёвый способ заполнить его по сегодняшним ценам." },
        { key = "tipBagSlot", label = "Цена сумки за слот", kind = "check",
          help = "У сумки: сколько стоит один слот по сегодняшней минимальной цене (аукцион или торговец) и самая дешёвая сумка за слот сейчас." },
      } },
    } },

  { group = "Профессии" },
  { key = "customers", title = "Клиенты", icon = "Interface\\Icons\\INV_Letter_15",
    desc = "Поиск в чате тех, кому нужно то, что умеет этот персонаж.",
    tabs = {
      { name = "Общие", rows = {
        { sub = "Поиск клиентов" },
        { key = "customers", label = "Поиск клиентов", kind = "check",
          help = "Находит в чате тех, кто просит то, что умеет персонаж (ищет зачарователя, покупает ваше изготовление, воду мага)." },
        { key = "customerWindow", label = "Открывать окно клиентов", kind = "check",
          help = "Открывается при новой заявке. /fl customers открывает в любой момент." },
        { key = "customerSound", label = "Звук", kind = "check", help = "Звук шёпота с каждой новой заявкой." },
        { key = "customerChat", label = "Заявки и в чате", kind = "check", help = "Также печатать каждую заявку в чате." },
      } },
      { name = "Что искать", rows = {
        { sub = "Услуги" },
        { key = "svcCrafting", label = "Изготовление", kind = "check", after = ads,
          help = "Заявки на ваши профессии и изготовление, а также кнопка рекламы изготовления." },
        { key = "svcFood", label = "Еда и вода мага", kind = "check", after = ads,
          help = "У мага: заявки на воду и еду и кнопка продажи еды и воды." },
        { key = "svcPortal", label = "Порталы мага", kind = "check", after = ads,
          help = "У мага с 40 уровня: заявки на порталы и кнопка продажи порталов." },
        { key = "svcSummon", label = "Призывы чернокнижника", kind = "check", after = ads,
          help = "У чернокнижника с 20 уровня: заявки на призыв и кнопка предложения призыва." },
        { key = "svcLockpick", label = "Взлом замков разбойника", kind = "check", after = ads,
          help = "У разбойника с 16 уровня: заявки на взлом и кнопка предложения взлома." },
      } },
    } },
  { key = "crates", title = "Забытые ящики", icon = "Interface\\Icons\\INV_Crate_01",
    desc = "Вкладка «Ящики» и дешёвое заполнение каждого ящика.",
    rows = {
      { sub = "Ящики" },
      { key = "crates", label = "Забытые ящики", kind = "check", after = function() ns:LayoutTabs() end,
        help = "Вкладка «Ящики» и строка подсказки о дешёвом заполнении." },
    } },

  { group = "Ваше золото" },
  { key = "sessions", title = "Сессии", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    desc = "Сколько приносит ваше время в игре.",
    rows = {
      { sub = "Добыча" },
      { key = "sessionValue", label = "Считать добычу по", kind = "choice", options = {
          { "best", "Лучшее из аукциона и торговца" }, { "vendor", "Только торговец" } },
        help = "Чем считается каждая добытая вещь в сессии. Цены аукциона — уже без комиссии; предметы, которые привязываются при получении, всегда считаются по цене торговца. Начать сессию: /fl session start или Ctrl+клик по кнопке миникарты." },
    } },

  { group = "Прочее" },
  { key = "other", title = "Миникарта и обновления", icon = "Interface\\Icons\\INV_Misc_Map_01",
    desc = "Кнопка у миникарты и сообщения о новых версиях.",
    rows = {
      { sub = "Миникарта" },
      { key = "minimap", label = "Кнопка у миникарты", kind = "check", after = function() ns:UpdateMinimapButton() end,
        help = "Кнопка Forever Ledger у миникарты. /fl всё равно открывает окно." },
      { sub = "Новые версии" },
      { key = "updateNotice", label = "Сообщать о новой версии", kind = "check",
        help = "Forever Ledger узнаёт от согильдейцев и участников группы с новой версией и сообщает об этом в чате раз за сессию. Передаётся только номер версии." },
    } },
  -- Every saved character, with Remove (owner, October 5: addons can't see a character
  -- being deleted, and a sync partner's stayed; rare and permanent, so here, not on the
  -- Characters tab).
  { key = "characters", title = "Персонажи", custom = true,
    desc = "Свяжите второй аккаунт, посмотрите всех известных персонажей и удалите тех, кого больше нет." },
}

-- Every page gets a tab list (one unnamed tab when it has none), and every setting is
-- found by key. Settings on any page but Global are in profiles.
local DEFS, PAGE_BY_KEY = {}, {}
ns.PER_CHAR_SETTINGS = {}
for _, p in ipairs(PAGES) do
  if p.key then
    PAGE_BY_KEY[p.key] = p
    if p.rows then p.tabs = { { rows = p.rows } } end
    for _, tab in ipairs(p.tabs or {}) do
      for _, d in ipairs(tab.rows) do
        if d.key then
          DEFS[d.key] = d
          d.page = p.key
          if p.key ~= "global" then ns.PER_CHAR_SETTINGS[d.key] = true end
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Appearance: a new look shows after a reload (every frame is drawn in the theme when
-- it's made), so a change offers one. Accept is a click, which ReloadUI needs.
---------------------------------------------------------------------------
if StaticPopupDialogs then
  StaticPopupDialogs.FLEDGER_RELOAD = {
    text = "Forever Ledger: перезагрузить, чтобы увидеть новый вид?",
    button1 = "Перезагрузить", button2 = "Позже",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end
function ns:OfferReload()
  local T = ns.Theme
  if T and T.NeedsReload and T:NeedsReload() and StaticPopup_Show then StaticPopup_Show("FLEDGER_RELOAD") end
end

-- The accent colours on offer ("" = auto: EllesmereUI's, else the theme's teal).
local ACCENTS = { "0cd29d", "e8c27a", "f08a24", "e5484d", "9b7bff", "3e9bff" }

-- WoW's colour picker, old and new forms. done(r, g, b) as the colour changes.
local function pickColour(start, done)
  local CP = ColorPickerFrame
  if not CP then return end
  local r, g, b = start[1], start[2], start[3]
  local function changed() local nr, ng, nb = CP:GetColorRGB(); done(nr, ng, nb) end
  if CP.SetupColorPickerAndShow then
    CP:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = changed, cancelFunc = function() done(r, g, b) end })
  else
    CP.func, CP.cancelFunc, CP.hasOpacity = changed, function() done(r, g, b) end, false
    CP:SetColorRGB(r, g, b)
    CP:Hide(); CP:Show()
  end
end

-- The accent control: Auto, a row of colour squares, and Custom (the colour picker).
local function accentControl(parent, onChange)
  local f = CreateFrame("Frame", nil, parent)
  f.items = {}
  local x = 0
  local function add(b, value)
    b:SetPoint("LEFT", x, 0)
    x = x + b:GetWidth() + 4
    b.value = value
    f.items[#f.items + 1] = b
  end
  add(T:Button(f, "Авто", 44, function() f:SetValue(""); onChange("") end, 20), "")
  for _, hex in ipairs(ACCENTS) do
    local c = T:FromHex(hex)
    local b = T:Button(f, "", 20, function() f:SetValue(hex); onChange(hex) end, 20)
    b.bg:SetColorTexture(c[1], c[2], c[3], 1)
    b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(c[1], c[2], c[3], 1); for _, e in ipairs(self.borders) do e:SetColorTexture(1, 1, 1, self.selected and 1 or 0.15) end end)
    b:SetScript("OnEnter", function(self) for _, e in ipairs(self.borders) do e:SetColorTexture(1, 1, 1, 0.8) end end)
    function b:SetSelected(on) self.selected = on; self:GetScript("OnLeave")(self) end
    add(b, hex)
  end
  add(T:Button(f, "Свой", 60, function()
    pickColour(T:FromHex(f.value) or T.accent, function(r, g, b)
      local hex = T:ToHex({ r, g, b })
      f:SetValue(hex)
      onChange(hex)
    end)
  end, 20), "custom")
  f:SetSize(x, 20)
  function f:SetValue(v)
    self.value = v or ""
    local preset = self.value == ""
    for _, hex in ipairs(ACCENTS) do if hex == self.value then preset = true end end
    for _, b in ipairs(self.items) do
      b:SetSelected(b.value == self.value or (b.value == "custom" and not preset))
    end
  end
  return f
end

---------------------------------------------------------------------------
-- Profiles: switching, new, rename, delete, reset, export, import
---------------------------------------------------------------------------
local function profileNames()
  local names = {}
  for n in pairs(ns.db.profiles) do names[#names + 1] = n end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  table.insert(names, 1, ns.DEFAULT_PROFILE)
  return names
end

local function usersOf(name)
  local out = {}
  for key, c in pairs(ns.db.chars) do
    if ns:ProfileOf(key) == name then out[#out + 1] = c.name or key end
  end
  table.sort(out)
  return out
end

-- After the profile changes: everything that reads a setting once is told.
local function afterSwitch()
  ns:ApplyCharSettings()
  ns:OfferReload()   -- (the profile may have another theme or accent)
  if ns.UpdateMinimapButton then pcall(ns.UpdateMinimapButton, ns) end
  if ns.LayoutTabs then pcall(ns.LayoutTabs, ns) end
  if ns.UpdateCustomerAds then pcall(ns.UpdateCustomerAds, ns) end
  if ns.ApplyScale then ns:ApplyScale() end
  ns:RefreshSettings()
end

local function useProfile(name)
  ns.db.charProfile[ns.CharKey()] = (name ~= ns.DEFAULT_PROFILE) and name or nil
  afterSwitch()
end

-- This character's per-character settings as they are now, as a new table.
local function snapshot()
  local v = {}
  for k in pairs(ns.PER_CHAR_SETTINGS) do
    local x = ns.db.settings[k]
    if type(x) ~= "table" then v[k] = x end
  end
  return v
end

local function cleanName(s)
  s = (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then return nil, "Сначала введите имя в поле." end
  if #s > 30 then return nil, "Слишком длинное имя (не больше 30 букв)." end
  if s:lower() == ns.DEFAULT_PROFILE:lower() then return nil, "Это имя занято профилем «По умолчанию»." end
  for n in pairs(ns.db.profiles) do
    if n:lower() == s:lower() then return nil, ("Профиль с именем %s уже есть."):format(n) end
  end
  return s
end

local function uniqueName(base)
  base = (type(base) == "string" and base:gsub("^%s+", ""):gsub("%s+$", "") ~= "" and base:sub(1, 26)) or "Imported"   -- (room for " 2")
  local name, n = base, 2
  while not cleanName(name) do name = base .. " " .. n; n = n + 1 end
  return name
end

local function newProfile(text)
  local name, err = cleanName(text)
  if not name then return ns:Print(err) end
  ns.db.profiles[name] = snapshot()
  useProfile(name)
  ns:Print(("Новый профиль %s — копия ваших настроек. Этот персонаж теперь использует его."):format(name))
end

local function renameProfile(text)
  local cur = ns:ProfileOf()
  if cur == ns.DEFAULT_PROFILE then return ns:Print("Профиль «По умолчанию» сохраняет имя. Создайте новый профиль, чтобы назвать свой.") end
  local name, err = cleanName(text)
  if not name then return ns:Print(err) end
  ns.db.profiles[name], ns.db.profiles[cur] = ns.db.profiles[cur], nil
  for key, n in pairs(ns.db.charProfile) do if n == cur then ns.db.charProfile[key] = name end end
  afterSwitch()
  ns:Print(("Профиль %s переименован в %s."):format(cur, name))
end

local function deleteProfile()
  local cur = ns:ProfileOf()
  if cur == ns.DEFAULT_PROFILE then return end
  ns.db.profiles[cur] = nil
  for key, n in pairs(ns.db.charProfile) do if n == cur then ns.db.charProfile[key] = nil end end
  afterSwitch()
  ns:Print(("Профиль %s удалён. Персонажи, которые его использовали, теперь на «По умолчанию»."):format(cur))
end

local function resetProfile()
  for k in pairs(ns.PER_CHAR_SETTINGS) do
    local d = ns.DEFAULT_SETTINGS[k]
    if type(d) ~= "table" then ns.db.settings[k] = d end
  end
  afterSwitch()
  ns:Print(("Профиль %s сброшен к умолчаниям Forever Ledger. Глобальные настройки не тронуты."):format(ns:ProfileOf()))
end

-- A value a setting could really have (imports are checked, never trusted).
local function validValue(d, v)
  if d.kind == "check" then return type(v) == "boolean" end
  if d.kind == "number" or d.kind == "slider" then return type(v) == "number" and v >= (d.min or -math.huge) and v <= (d.max or math.huge) end
  if d.kind == "money" then return type(v) == "number" and v >= 0 and v < 1e10 end
  if d.kind == "choice" then
    for _, o in ipairs(d.options) do if o[1] == v then return true end end
  end
  if d.kind == "accent" then return v == "" or (type(v) == "string" and v:match("^%x%x%x%x%x%x$") ~= nil) end
  return false
end

local function exportProfile(parts)
  local values = {}
  for key, d in pairs(DEFS) do
    if parts[d.page] and ns.PER_CHAR_SETTINGS[key] then
      local v = ns.db.settings[key]
      if type(v) ~= "table" then values[key] = v end
    end
  end
  return ns.Serialize({ kind = "profile", v = 1, name = ns:ProfileOf(), values = values })
end

local function importProfile(text)
  local data, err = ns.Deserialize(text)
  if not data then return false, err end
  if type(data) ~= "table" or data.kind ~= "profile" or type(data.values) ~= "table" then
    return false, "Это не профиль настроек. (Данные из «Экспорт / импорт» на вкладке «Персонажи» вставляются туда.)"
  end
  local values, n = {}, 0
  for k, v in pairs(data.values) do
    local d = DEFS[k]
    if d and ns.PER_CHAR_SETTINGS[k] and validValue(d, v) then values[k] = v; n = n + 1 end
  end
  if n == 0 then return false, "В этом профиле нет настроек, известных этой версии Forever Ledger." end
  -- Parts left out of the export start as this character's settings are now.
  local full = snapshot()
  for k, v in pairs(values) do full[k] = v end
  local name = uniqueName(data.name ~= ns.DEFAULT_PROFILE and data.name or "Imported")
  ns.db.profiles[name] = full
  useProfile(name)
  return true, ("Импортировано настроек: %d, профиль %s; этот персонаж теперь использует его. Вернуться можно в Настройках, Профилях."):format(n, name)
end

---------------------------------------------------------------------------
-- Building the tab
---------------------------------------------------------------------------
local NAV_W = 190
local f
local state = { page = "global", tab = {}, query = nil }

-- "Default: Auto." under each setting (owner's test, October 3).
local function defaultText(d)
  local v = ns.DEFAULT_SETTINGS and ns.DEFAULT_SETTINGS[d.key]
  if v == nil then return end
  if d.kind == "choice" then
    for _, o in ipairs(d.options) do if o[1] == v then return "По умолчанию: " .. o[2] .. "." end end
  elseif d.kind == "number" then
    local s = d.suffix or ""
    return ("По умолчанию: %g%s."):format(v, s == "" and "" or ((s:sub(1, 1) == "%" and "" or " ") .. s))
  elseif d.kind == "money" then
    return "По умолчанию: " .. ((v > 0) and ns.MoneyPlain(v) or "выкл") .. "."
  elseif d.kind == "accent" then
    return "По умолчанию: авто."
  elseif d.kind == "slider" then
    return ("По умолчанию: %d%s."):format(v, d.suffix or "")
  end
end

-- One setting's row: name, description and its control.
local function makeRow(box, d)
  local r = { def = d }
  r.label = T:Text(box, 12 + (T.theme.labelAdd or 0))   -- (names stand out from the grey text)
  r.label:SetJustifyH("LEFT")
  r.label:SetText((d.label:gsub("^%s+", "")))
  r.indent = d.label:find("^%s") and 18 or 0   -- a sub-option of the one above
  local dflt = defaultText(d)
  local helpText = d.help and dflt and (d.help .. " " .. dflt) or d.help or dflt
  if helpText then
    r.help = T:Text(box, 11, T.dim)
    r.help:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -3)
    r.help:SetJustifyH("LEFT")
    r.help:SetSpacing(2)
    r.help:SetText(helpText)
  end
  local function changed(v)
    ns.db.settings[d.key] = v
    if d.after then d.after() end
    if f.rules then f.rules:SetText("Сделки — это лоты " .. ns:DealRules() .. ".") end
  end
  if d.kind == "number" then
    r.control = T:Number(box, d, changed)
  elseif d.kind == "money" then
    r.control = T:MoneyBox(box, changed, d.plainUnit or "g")   -- a lone number is gold (owner, October 3)
  elseif d.kind == "choice" then
    local opts = {}
    for _, o in ipairs(d.options) do opts[#opts + 1] = { value = o[1], label = o[2] } end
    if #opts > 3 then   -- many options would run off the page: a dropdown instead
      r.control = T:Dropdown(box, 190, changed)
      r.control.default = ns.DEFAULT_SETTINGS and ns.DEFAULT_SETTINGS[d.key]
      r.control:SetOptions(opts)
    else
      r.control = T:Choice(box, opts, changed)
    end
  elseif d.kind == "accent" then
    r.control = accentControl(box, changed)
  elseif d.kind == "slider" then
    r.control = T:Slider(box, d, changed)
  elseif d.kind == "check" then
    r.control = T:Check(box, function(self) changed(self:GetChecked()) end, "switch")
  end
  r.line = box:CreateTexture(nil, "BACKGROUND")
  r.line:SetColorTexture(1, 1, 1, 0.04)
  r.line:SetHeight(1)
  f.controls[#f.controls + 1] = r
  return r
end

-- A small heading inside a tab, on a faint accent band (owner's test, October 3).
local function makeSub(box, text)
  local r = { head = true }
  r.text = T:Text(box, 11)
  T:StyleHeading(r.text, text)
  -- Plain, like the mockup (no band behind it); on Gilded a gold rule under it. The
  -- band is an invisible frame to lay it out by.
  r.band = box:CreateTexture(nil, "BACKGROUND")
  r.band:SetColorTexture(0, 0, 0, 0)
  r.band:SetHeight(20)
  if T.theme.serif then
    local c = T.theme.heading or T.accent
    r.rule = box:CreateTexture(nil, "BORDER")
    r.rule:SetColorTexture(c[1], c[2], c[3], 0.45)
    r.rule:SetHeight(1)
    r.rule:SetPoint("BOTTOMLEFT", r.band, "BOTTOMLEFT", 8, -2)
    r.rule:SetPoint("BOTTOMRIGHT", r.band, "BOTTOMRIGHT", -8, -2)
  end
  return r
end

local function showRow(r, on)
  if r.head then r.text:SetShown(on); r.band:SetShown(on); if r.rule then r.rule:SetShown(on) end; return end
  r.label:SetShown(on); r.control:SetShown(on); r.line:SetShown(on)
  if r.help then r.help:SetShown(on) end
end

local function rowMatches(r, q)
  local d = r.def
  return d and ((d.label or ""):lower():find(q, 1, true) or (d.help or ""):lower():find(q, 1, true)) and true or false
end

-- (Cards: T:PlaceCard / T:HideCards in Theme.lua, shared with Help.)

-- Lay out one tab's rows from y; returns where it ended. Tick boxes sit left of their
-- name so the text has the width; other controls line up on the right. withCards: a
-- card for each group (from a heading to the next).
local function layoutRows(box, rows, width, y, withCards)
  local used, groupTop, any = 0, nil, false
  local function close()
    if withCards and groupTop and any then
      used = used + 1
      T:PlaceCard(box, used, groupTop, y + 2, width)
      y = y + 12
    end
    groupTop, any = nil, false
  end
  for _, r in ipairs(rows) do
    if r.head then close(); groupTop = y elseif not groupTop then groupTop = y end
    if not r.head then any = true end
    if r.head then
      r.band:ClearAllPoints()
      r.band:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -(y + 4))
      r.band:SetWidth(width - 8)
      r.text:ClearAllPoints()
      r.text:SetPoint("LEFT", r.band, "LEFT", 8, 0)
      y = y + 30
    else
      local check = r.def.kind == "check"
      local cw = check and 0 or r.control:GetWidth()
      local textX = (check and (20 + r.control:GetWidth()) or 12) + (r.indent or 0)   -- (a switch is wider than a tick box)
      -- (Right-hand controls end 12 pixels inside the edge; they ran past the card's edge:
      -- owner's screenshots, October 4.)
      local textW = math.max(120, check and (width - textX - 12) or (width - cw - 48 - (r.indent or 0)))
      r.label:ClearAllPoints()
      r.label:SetPoint("TOPLEFT", box, "TOPLEFT", textX, -(y + 5))
      r.label:SetWidth(textW)
      local h = math.max(20, r.label:GetStringHeight())
      if r.help then
        r.help:SetWidth(textW)
        h = h + r.help:GetStringHeight() + 4
      end
      r.control:ClearAllPoints()
      if check then
        r.control:SetPoint("TOPLEFT", box, "TOPLEFT", 12 + (r.indent or 0), -(y + 6))
        r.control:SetHitRectInsets(0, -(math.min(r.label:GetStringWidth(), textW) + 22), -4, -4)   -- the name ticks it too
      else
        r.control:SetPoint("TOPLEFT", box, "TOPLEFT", math.max(textX + textW + 24, width - 12 - cw), -(y + 1))
      end
      y = y + math.max(h, 26) + 8
      r.line:ClearAllPoints()
      r.line:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -(y - 4))
      r.line:SetWidth(width - 16)
    end
  end
  close()
  T:HideCards(box, used + 1)
  return y
end

-- The sidebar: a page's button (its name, a bar and a tint on the chosen one).
local function navButton(p, indent)
  local b = CreateFrame("Button", nil, f.nav)
  b:SetHeight(24)
  b.sel = b:CreateTexture(nil, "BACKGROUND")
  b.sel:SetAllPoints()
  b.sel:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.15)
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetPoint("TOPLEFT")
  b.bar:SetPoint("BOTTOMLEFT")
  b.bar:SetWidth(2)
  b.bar:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 1)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.05)
  -- No icons (owner, October 4: the game's icons looked busy, and there will be many
  -- pages); the bar and the tint show the chosen one.
  -- Global settings, Profiles and Appearance (above the groups) get a small outline icon
  -- so they stand out, like the mockup (owner, October 4): our own drawings (media/icons,
  -- white, 64 px TGA), tinted in the heading colour.
  if p.icon and (indent or 14) < 20 then
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(15, 15)
    b.icon:SetPoint("LEFT", 12, 0)
    b.icon:SetTexture(p.icon)
    local c = T.theme.heading or T.accent
    b.icon:SetVertexColor(c[1], c[2], c[3], 0.9)
    indent = 32
  end
  b.text = T:Text(b, 12)
  b.text:SetPoint("LEFT", indent or 14, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetText(p.title)
  b.extra = T:Text(b, 10, T.dim)
  b.extra:SetPoint("RIGHT", -8, 0)
  b.extra:SetJustifyH("RIGHT")
  b.extra:SetWordWrap(false)
  b.text:SetPoint("RIGHT", b.extra, "LEFT", -4, 0)
  b.text:SetWordWrap(false)
  b:SetScript("OnClick", function()
    state.page = p.key
    f.search:SetText("")   -- (clears the search, which redraws)
    f.search:ClearFocus()
    ns:RefreshSettings()
    f.sf:SetVerticalScroll(0)
  end)
  return b
end

---------------------------------------------------------------------------
-- The Profiles page
---------------------------------------------------------------------------
local armed = {}   -- [button] = GetTime() of the first click ("Sure?")
local function confirmButton(parent, label, width, fn)
  local b
  b = T:Button(parent, label, width, function()
    if armed[b] and GetTime() - armed[b] < 4 then
      armed[b] = nil
      b:SetText(label)
      fn()
    else
      armed[b] = GetTime()
      b:SetText("Точно? Нажмите ещё раз")
      C_Timer.After(4, function() if armed[b] and GetTime() - armed[b] >= 4 then armed[b] = nil; b:SetText(label) end end)
    end
  end, 24)
  return b
end

local function buildProfiles(box)
  local P = CreateFrame("Frame", nil, box)
  P.intro = T:Text(P, 12, T.dim)
  P.intro:SetJustifyH("LEFT")
  P.intro:SetText("Профиль — набор настроек, которым персонажи могут делиться: например, без подсказок у одного, без поиска клиентов у другого. Каждый персонаж использует один профиль. Глобальные настройки в профили не входят: они одинаковы для всех.")

  P.head1 = makeSub(P, "Этот персонаж")
  P.pick = T:Dropdown(P, 220, function(v) useProfile(v) end)
  P.pickLabel = T:Text(P, 12)
  P.pickLabel:SetText("Профиль")
  P.users = T:Text(P, 11, T.dim)
  P.users:SetJustifyH("LEFT")

  P.head2 = makeSub(P, "Управление")
  P.name = T:EditBox(P, 200, "LEFT")
  local hint = T:Text(P.name, 11, T.section)
  hint:SetPoint("LEFT", 6, 0)
  hint:SetText("Название нового профиля")
  P.name:SetScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "" and not self:HasFocus()) end)
  P.name:SetScript("OnEditFocusGained", function() hint:Hide() end)
  P.name:SetScript("OnEditFocusLost", function(self) hint:SetShown(self:GetText() == "") end)
  P.name:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  P.new = T:Button(P, "Новый профиль", 110, function()
    newProfile(P.name:GetText())
    if ns:ProfileOf() ~= ns.DEFAULT_PROFILE then P.name:SetText(""); P.name:ClearFocus() end
  end, 24)
  P.rename = T:Button(P, "Переименовать", 104, function() renameProfile(P.name:GetText()); P.name:SetText(""); P.name:ClearFocus() end, 24)
  P.manageHelp = T:Text(P, 11, T.dim)
  P.manageHelp:SetJustifyH("LEFT")
  P.manageHelp:SetText("Новый профиль начинается как копия текущих настроек персонажа, и персонаж переключается на него. «Переименовать» меняет имя профиля этого персонажа.")
  P.reset = confirmButton(P, "Сбросить к умолчаниям", 140, resetProfile)
  P.delete = confirmButton(P, "Удалить профиль", 120, deleteProfile)
  for _, b in ipairs({ P.reset, P.delete }) do
    b:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(self == P.reset and "Сбросить к умолчаниям" or "Удалить профиль", 1, 1, 1)
      GameTooltip:AddLine(self == P.reset and "Возвращает все настройки профиля к умолчаниям Forever Ledger. Глобальные настройки не тронуты. Нажмите дважды."
        or "Удаляет профиль этого персонажа; персонажи на нём вернутся на «По умолчанию». Профиль «По умолчанию» удалить нельзя. Нажмите дважды.", nil, nil, nil, true)
      GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end

  P.head3 = makeSub(P, "Поделиться")
  P.shareHelp = T:Text(P, 11, T.dim)
  P.shareHelp:SetJustifyH("LEFT")
  P.shareHelp:SetText("Экспорт копирует профиль этого персонажа текстом, только отмеченные части. Импорт создаёт новый профиль из чужого текста. Переносятся только настройки: никогда глобальные настройки, золото или ваши данные.")
  P.parts, P.partChecks = {}, {}
  for _, p in ipairs(PAGES) do
    if p.key and p.tabs and p.key ~= "global" then   -- (pages with settings: not Profiles or Characters)
      P.parts[p.key] = true
      local c = T:Check(P, function(self) P.parts[p.key] = self:GetChecked() end)
      c:SetChecked(true)
      c.label:SetText(p.title)
      c:SetHitRectInsets(0, -(c.label:GetStringWidth() + 8), -4, -4)
      P.partChecks[#P.partChecks + 1] = c
    end
  end
  -- One button and one window with Export and Import tabs, like Export / import on the
  -- Characters tab (owner's test, October 5).
  local showExport, showImport
  local function tabs(current)
    return { current = current, { "Экспорт", function() showExport() end }, { "Импорт", function() showImport() end } }
  end
  showExport = function()
    local any = false
    for _, on in pairs(P.parts) do any = any or on end
    if not any then
      ns:ShowTextWindow("Экспорт / импорт профиля",
        "Отметьте хотя бы одну часть в «Поделиться» в Настройках, Профилях, чтобы экспортировать.", "", nil, nil, tabs(1))
      return
    end
    ns:ShowTextWindow("Экспорт / импорт профиля",
      ("Профиль %s. Нажмите Ctrl+A, затем Ctrl+C, чтобы скопировать. Получатель вставит его в Настройках, Профилях, «Экспорт / импорт», «Импорт»."):format(ns:ProfileOf()),
      exportProfile(P.parts), nil, nil, tabs(1))
  end
  showImport = function()
    ns:ShowTextWindow("Экспорт / импорт профиля",
      "Вставьте профиль через Ctrl+V и нажмите «Импорт». Он станет новым профилем, и персонаж переключится на него; остальные профили не изменятся.",
      "", "Импорт", importProfile, tabs(2))
  end
  P.export = T:Button(P, "Экспорт / импорт", 130, function() showExport() end, 24)
  return P
end

local function layoutProfiles(P, width)
  local y = 4
  P.intro:ClearAllPoints()
  P.intro:SetPoint("TOPLEFT", 12, -y)
  P.intro:SetWidth(width - 24)
  y = y + P.intro:GetStringHeight() + 12
  y = layoutRows(P, { P.head1 }, width, y)
  P.pickLabel:ClearAllPoints()
  P.pickLabel:SetPoint("TOPLEFT", 12, -(y + 4))
  P.pick:ClearAllPoints()
  P.pick:SetPoint("TOPLEFT", 80, -y)
  P.users:ClearAllPoints()
  P.users:SetPoint("TOPLEFT", 80, -(y + 28))
  P.users:SetWidth(width - 92)
  y = y + 32 + P.users:GetStringHeight() + 14
  y = layoutRows(P, { P.head2 }, width, y)
  P.name:ClearAllPoints()
  P.name:SetPoint("TOPLEFT", 12, -(y + 1))
  P.new:ClearAllPoints()
  P.new:SetPoint("LEFT", P.name, "RIGHT", 6, 0)
  P.rename:ClearAllPoints()
  P.rename:SetPoint("LEFT", P.new, "RIGHT", 4, 0)
  y = y + 30
  P.manageHelp:ClearAllPoints()
  P.manageHelp:SetPoint("TOPLEFT", 12, -y)
  P.manageHelp:SetWidth(width - 24)
  y = y + P.manageHelp:GetStringHeight() + 10
  P.reset:ClearAllPoints()
  P.reset:SetPoint("TOPLEFT", 12, -y)
  P.delete:ClearAllPoints()
  P.delete:SetPoint("LEFT", P.reset, "RIGHT", 6, 0)
  y = y + 38
  y = layoutRows(P, { P.head3 }, width, y)
  P.shareHelp:ClearAllPoints()
  P.shareHelp:SetPoint("TOPLEFT", 12, -y)
  P.shareHelp:SetWidth(width - 24)
  y = y + P.shareHelp:GetStringHeight() + 10
  local colW = math.max(150, math.floor((width - 24) / 3))
  for i, c in ipairs(P.partChecks) do
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", 12 + ((i - 1) % 3) * colW, -(y + math.floor((i - 1) / 3) * 22))
  end
  y = y + math.ceil(#P.partChecks / 3) * 22 + 6
  P.export:ClearAllPoints()
  P.export:SetPoint("TOPLEFT", 12, -y)
  return y + 40
end

local function refreshProfiles(P)
  local cur = ns:ProfileOf()
  local opts = {}
  for _, n in ipairs(profileNames()) do opts[#opts + 1] = { value = n, label = n } end
  P.pick:SetOptions(opts)
  P.pick:SetValue(cur)
  local users = usersOf(cur)
  P.users:SetText(#users > 0 and ("Используют: " .. table.concat(users, ", ")) or "")
  P.rename:SetEnabled(cur ~= ns.DEFAULT_PROFILE)
  P.delete:SetEnabled(cur ~= ns.DEFAULT_PROFILE)
end

---------------------------------------------------------------------------
-- The Characters page: every saved character, when it was last seen, where it came
-- from, and Remove (ns:RemoveCharacter, Core.lua). Never the one you're on.
---------------------------------------------------------------------------
local function lastSeen(key)
  if key == ns.CharKey() then return time() end
  local c, inv = ns.db.chars[key] or {}, ns.db.inventory[key] or {}
  local t = math.max(c.updated or 0, inv.t or 0, inv.bankT or 0)
  return t > 0 and t or nil
end

local function buildChars(box)
  local C = CreateFrame("Frame", nil, box)
  -- Linking your other account (owner, November 5): chat can't show at a glance whether
  -- the other side is there. /fl pair and /fl unpair still work.
  C.linkHead = makeSub(C, "Связать второй аккаунт")
  C.linkText = T:Text(C, 12, T.dim)
  C.linkText:SetJustifyH("LEFT")
  local function link()
    local name = C.linkBox:GetText()
    C.linkBox:ClearFocus()
    ns:SyncCommand("pair " .. name)
    if ns:SyncInfo() then C.linkBox:SetText("") end
    ns:RefreshSettings()
  end
  C.linkBox = T:EditBox(C, 200, "LEFT")
  C.linkBox:SetScript("OnEnterPressed", link)
  C.linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  C.linkButton = T:Button(C, "Связать", 80, link)
  C.linkButton:SetPoint("LEFT", C.linkBox, "RIGHT", 6, 0)
  C.linkButton:SetPrimary(true)
  C.unlink = confirmButton(C, "Отвязать", 130, function()
    ns:SyncCommand("unpair")
    ns:RefreshSettings()
  end)
  C.intro = T:Text(C, 12, T.dim)
  C.intro:SetJustifyH("LEFT")
  C.intro:SetText("Аддон не видит удаление или переименование персонажа, поэтому он остаётся здесь (и на вкладке «Персонажи», в «Есть» и в рецептах), пока вы не удалите его вручную.")
  -- A heading between the explanation and the list (owner's screenshot, October 5: the
  -- top ran straight into the rows), as on the Profiles page.
  C.head = makeSub(C, "Сохранённые персонажи")
  C.rows = {}
  return C
end

local function charRow(C, i)
  if C.rows[i] then return C.rows[i] end
  local r = CreateFrame("Frame", nil, C)
  r:SetHeight(40)
  r.stripe = T:Fill(r, { 1, 1, 1, 0.025 })
  r.remove = confirmButton(r, "Убрать", 130, function()
    local key = r.key
    local name = (ns.db.chars[key] and ns.db.chars[key].name) or key
    if ns:RemoveCharacter(key) then
      if ns.BuildUsageIndex then ns:BuildUsageIndex() end
      if ns.InvalidateValues then ns:InvalidateValues() end
      ns:Print(("%s удалён из Forever Ledger. Цены и история золота сохранены."):format(name))
      ns:RefreshUI()
      ns:RefreshSettings()
    end
  end)
  r.remove:SetPoint("RIGHT", -8, 0)
  r.you = T:Text(r, 11, T.dim)
  r.you:SetPoint("RIGHT", -14, 0)
  r.you:SetText("вы сейчас на нём")
  r.name = T:Text(r, 12)
  r.name:SetPoint("TOPLEFT", 10, -5)
  r.name:SetPoint("RIGHT", r.remove, "LEFT", -10, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r.info = T:Text(r, 11, T.dim)
  r.info:SetPoint("TOPLEFT", 10, -22)
  r.info:SetPoint("RIGHT", r.remove, "LEFT", -10, 0)
  r.info:SetJustifyH("LEFT")
  r.info:SetWordWrap(false)
  C.rows[i] = r
  return r
end

local function layoutChars(C, width)
  local y = layoutRows(C, { C.linkHead }, width, 4) + 2
  local partner, online = ns:SyncInfo()
  C.linkText:ClearAllPoints()
  C.linkText:SetPoint("TOPLEFT", 12, -y)
  C.linkText:SetWidth(width - 24)
  if not partner then
    C.linkText:SetText("Делитесь ценами и рецептами с персонажем второго аккаунта, пока оба в сети. Введите его имя и фамилию, нажмите «Связать».")
  elseif online then
    C.linkText:SetText(("Связка с %s: |cff7fd39cв сети|r. Обмен золотом и продажами или сумками и банком — в Глобальных, Дополнительно."):format(partner))
  else
    C.linkText:SetText(("Связка с %s: |cffee8597ещё не видно в сети|r. Оба персонажа должны быть в сети и связаны друг с другом."):format(partner))
  end
  y = y + C.linkText:GetStringHeight() + 8
  C.linkBox:ClearAllPoints()
  C.linkBox:SetPoint("TOPLEFT", 12, -y)
  C.linkBox:SetShown(not partner)
  C.linkButton:SetShown(not partner)
  C.unlink:ClearAllPoints()
  C.unlink:SetPoint("TOPLEFT", 12, -y)
  C.unlink:SetShown(partner ~= nil)
  y = y + 32
  C.intro:ClearAllPoints()
  C.intro:SetPoint("TOPLEFT", 12, -y)
  C.intro:SetWidth(width - 24)
  y = y + C.intro:GetStringHeight() + 12
  y = layoutRows(C, { C.head }, width, y) + 2
  -- The one you're on first, then the most recently seen.
  local keys = {}
  for key in pairs(ns.db.chars) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b)
    if (a == ns.CharKey()) ~= (b == ns.CharKey()) then return a == ns.CharKey() end
    return (lastSeen(a) or 0) > (lastSeen(b) or 0)
  end)
  for i, key in ipairs(keys) do
    local c, r = ns.db.chars[key], charRow(C, i)
    local me = key == ns.CharKey()
    r.key = key
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 4, -y)
    r:SetWidth(width - 8)
    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class or ""]
    local cls = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class or ""]) or c.class or ""
    r.name:SetText(("%s  |cff888888уровень %s %s|r"):format(
      cc and ("|c" .. (cc.colorStr or "ffffffff") .. (c.name or key) .. "|r") or (c.name or key), c.level or "?", cls))
    local from = (c.via and ("от партнёра по синхронизации " .. c.via))
      or (ns:IsOwnChar(key) and "этот аккаунт") or "из импорта или прошлой синхронизации"
    local seen = lastSeen(key)
    r.info:SetText(("%s %s, %s, %s"):format(c.realm or "?", c.faction or "", from,
      me and "сейчас в игре" or (seen and ("последний раз " .. ns.Age(seen)) or "здесь не появлялся")))
    r.remove:SetShown(not me)
    r.you:SetShown(me)
    r:Show()
    y = y + 44
  end
  for i = #keys + 1, #C.rows do C.rows[i]:Hide() end
  return y + 10
end

---------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------
function ns:BuildSettings(parent)
  f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  f.controls, f.boxes, f.navButtons = {}, {}, {}

  -- The sidebar: search, then the pages under their group headings.
  f.nav = CreateFrame("Frame", nil, f)
  f.nav:SetPoint("TOPLEFT")
  f.nav:SetPoint("BOTTOMLEFT")
  f.nav:SetWidth(NAV_W)
  -- Gilded: a warm gold tint and a bronze edge, like the mockup.
  local fr = T.theme.frame
  T:Fill(f.nav, fr and { 0.91, 0.76, 0.48, 0.04 } or { 1, 1, 1, 0.02 })
  local edge = f.nav:CreateTexture(nil, "BORDER")
  if fr then edge:SetColorTexture(fr[1], fr[2], fr[3], 0.5) else edge:SetColorTexture(1, 1, 1, 0.06) end
  edge:SetPoint("TOPRIGHT")
  edge:SetPoint("BOTTOMRIGHT")
  edge:SetWidth(1)

  local search = T:EditBox(f.nav, NAV_W - 16, "LEFT")
  search:SetPoint("TOPLEFT", 8, -6)
  local hint = T:Text(search, 11, T.section)
  hint:SetPoint("LEFT", 6, 0)
  hint:SetText("Поиск по настройкам")
  search:SetScript("OnTextChanged", function(self)
    hint:SetShown(self:GetText() == "" and not self:HasFocus())
    local q = self:GetText():lower():gsub("^%s+", ""):gsub("%s+$", "")
    local new = #q >= 2 and q or nil
    if new ~= state.query then
      state.query = new
      f.sf:SetVerticalScroll(0)
      ns:RefreshSettings()
    end
  end)
  search:SetScript("OnEditFocusGained", function() hint:Hide() end)
  search:SetScript("OnEditFocusLost", function(self) hint:SetShown(self:GetText() == "") end)
  search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  f.search = search

  local y = 38
  local grouped = false   -- pages under a group heading sit further in (owner, October 4)
  for _, p in ipairs(PAGES) do
    if p.group then
      grouped = true
      local h = T:Text(f.nav, 10)
      T:StyleHeading(h, p.group)
      h:SetPoint("TOPLEFT", 10, -(y + 8))
      y = y + 26
    else
      local b = navButton(p, grouped and 24 or 14)
      b:SetPoint("TOPLEFT", 0, -y)
      b:SetPoint("RIGHT", f.nav, "RIGHT", -1, 0)
      f.navButtons[p.key] = b
      y = y + 26
    end
  end

  -- The page: title, a line about it, tabs, then its settings.
  f.title = T:Text(f, 16)
  T:StyleTitle(f.title, 16)
  f.title:SetPoint("TOPLEFT", NAV_W + 14, -4)
  f.desc = T:Text(f, 11, T.dim)
  f.desc:SetPoint("TOPLEFT", NAV_W + 14, -26)
  f.desc:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  f.desc:SetJustifyH("LEFT")
  f.desc:SetWordWrap(false)
  f.tabLine = f:CreateTexture(nil, "BORDER")
  f.tabLine:SetColorTexture(1, 1, 1, 0.06)
  f.tabLine:SetHeight(1)
  f.tabLine:SetPoint("TOPLEFT", NAV_W + 8, -73)
  f.tabLine:SetPoint("TOPRIGHT", 0, -73)

  local sf, content = T:Scroll(f)
  sf:SetPoint("BOTTOMRIGHT")
  f.sf, f.content = sf, content
  sf:HookScript("OnSizeChanged", function() if f:IsVisible() then ns:RefreshSettings() end end)
  f.noMatch = T:Text(content, 12, T.dim)
  f.noMatch:SetPoint("TOPLEFT", 12, -12)
  f.noMatch:SetText("Ничего не найдено. Попробуйте другое слово, например цена, звук или подсказка.")

  -- Each page's tabs, and a box of rows for each tab.
  for _, p in ipairs(PAGES) do
    if p.key and p.tabs then
      p.tabButtons = {}
      local x = NAV_W + 8
      for i, tab in ipairs(p.tabs) do
        if tab.name then
          local b = T:Tab(f, tab.name, function()
            state.tab[p.key] = i
            ns:RefreshSettings()
            f.sf:SetVerticalScroll(0)
          end)
          b:SetPoint("TOPLEFT", x, -44)
          x = x + b:GetWidth()
          b:Hide()
          p.tabButtons[i] = b
        end
        local box = CreateFrame("Frame", nil, content)
        box:Hide()
        box.page, box.tabIndex, box.rows = p, i, {}
        box.headBand = box:CreateTexture(nil, "BACKGROUND")
        box.headBand:SetColorTexture(1, 1, 1, 0.05)
        box.headBand:SetHeight(24)
        box.headText = T:Text(box, 13, T.accent)
        box.headText:SetText(p.title .. (tab.name and ("  |cff888888>|r  " .. tab.name) or ""))
        if tab.rules then
          box.rules = T:Text(box, 11, T.dim)
          box.rules:SetJustifyH("LEFT")
          f.rules = box.rules
        end
        for _, d in ipairs(tab.rows) do
          box.rows[#box.rows + 1] = d.sub and makeSub(box, d.sub) or makeRow(box, d)
        end
        f.boxes[#f.boxes + 1] = box
      end
    end
  end
  f.profiles = buildProfiles(content)
  f.profiles:Hide()
  f.chars = buildChars(content)
  f.chars:Hide()
  return f
end

-- Back to Global settings and no search (the tab was clicked again).
function ns:ResetSettingsView()
  state.page, state.query, state.tab = "global", nil, {}
  if f and f.search then f.search:SetText("") end
end

function ns:RefreshSettings()
  if not (f and f:IsShown()) then return end
  local q = state.query
  local page = PAGE_BY_KEY[state.page] or PAGE_BY_KEY.global
  local tabIndex = state.tab[page.key] or 1

  -- Sidebar
  for key, b in pairs(f.navButtons) do
    local on = not q and key == page.key
    b.sel:SetShown(on)
    b.bar:SetShown(on)
    local nChars = 0
    if key == "characters" then for _ in pairs(ns.db.chars) do nChars = nChars + 1 end end
    b.extra:SetText((key == "profiles" and ns:ProfileOf()) or (key == "characters" and tostring(nChars)) or "")
  end

  -- Header and tabs
  local hasTabs = not q and page.tabButtons and #page.tabButtons > 0
  if q then
    f.title:SetText("Поиск")
    f.desc:SetText(("Настройки, где упоминается «%s», со всех страниц."):format(q))
  else
    f.title:SetText(page.title)
    f.desc:SetText(page.desc or "")
  end
  for _, p in ipairs(PAGES) do
    for i, b in pairs(p.tabButtons or {}) do
      b:SetShown(hasTabs and p == page)
      b:SetSelected(i == tabIndex)
    end
  end
  f.tabLine:SetShown(hasTabs)
  local top = hasTabs and 78 or 50
  f.sf:ClearAllPoints()
  f.sf:SetPoint("TOPLEFT", NAV_W + 4, -top)
  f.sf:SetPoint("BOTTOMRIGHT")

  -- Rows: this page's tab, or every match when searching.
  f.content:SetWidth(math.max(f.sf:GetWidth() - 12, 300))
  local width = f.content:GetWidth()
  local y = 0
  for _, box in ipairs(f.boxes) do
    local rows = {}
    for _, r in ipairs(box.rows) do
      local on = (not q) or (not r.head and rowMatches(r, q))
      showRow(r, on)
      if on then rows[#rows + 1] = r end
    end
    local show = (q and #rows > 0) or (not q and box.page == page and box.tabIndex == tabIndex)
    box:SetShown(show and true or false)
    if show then
      box:ClearAllPoints()
      box:SetPoint("TOPLEFT", 0, -y)
      box:SetWidth(width)
      local by = 0
      box.headBand:SetShown(q ~= nil)
      box.headText:SetShown(q ~= nil)
      if q then
        box.headBand:ClearAllPoints()
        box.headBand:SetPoint("TOPLEFT", 4, -4)
        box.headBand:SetWidth(width - 8)
        box.headText:ClearAllPoints()
        box.headText:SetPoint("LEFT", box.headBand, "LEFT", 8, 0)
        by = 32
      end
      if box.rules then
        box.rules:SetShown(not q)
        if not q then
          box.rules:ClearAllPoints()
          box.rules:SetPoint("TOPLEFT", 12, -(by + 4))
          box.rules:SetWidth(width - 24)
          box.rules:SetText("Сделки — это лоты " .. ns:DealRules() .. ".")
          by = by + box.rules:GetStringHeight() + 14
        end
      end
      by = layoutRows(box, rows, width, by, T.theme.cards) + 10
      box:SetHeight(by)
      y = y + by
    end
  end

  -- The Profiles page
  local prof = not q and page.key == "profiles"
  f.profiles:SetShown(prof)
  if prof then
    f.profiles:ClearAllPoints()
    f.profiles:SetPoint("TOPLEFT", 0, 0)
    f.profiles:SetWidth(width)
    refreshProfiles(f.profiles)
    local h = layoutProfiles(f.profiles, width)
    f.profiles:SetHeight(h)
    y = h
  end
  -- The Characters page
  local chars = not q and page.key == "characters"
  f.chars:SetShown(chars)
  if chars then
    f.chars:ClearAllPoints()
    f.chars:SetPoint("TOPLEFT", 0, 0)
    f.chars:SetWidth(width)
    local h = layoutChars(f.chars, width)
    f.chars:SetHeight(h)
    y = h
  end

  f.noMatch:SetShown(q ~= nil and y == 0)
  f.content:SetHeight(math.max(y, 100))
  for _, r in ipairs(f.controls) do
    if r.control:IsShown() then
      local v = ns.db.settings[r.def.key]
      if r.def.kind == "check" then r.control:SetChecked(v) else r.control:SetValue(v) end
    end
  end
  f.sf.UpdateScrollBar()
end

-- For the tests (tests/test_profiles.lua): the profile functions above are local, and
-- the tests call them the way the Profiles page's buttons do.
ns._test = { DEFS = DEFS, newProfile = newProfile, renameProfile = renameProfile, deleteProfile = deleteProfile,
  resetProfile = resetProfile, exportProfile = exportProfile, importProfile = importProfile, useProfile = useProfile }
