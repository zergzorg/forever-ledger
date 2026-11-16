local _, ns = ...

---------------------------------------------------------------------------
-- Help: every feature at a high level, shown in the Help tab. The same text is in
-- docs/GUIDE.md on GitHub (with pictures); keep the two in step when features change.
-- Also: a one-time question for players who run TSM or Auctionator, whose tooltips
-- already show prices, offering the one-line tooltip.
---------------------------------------------------------------------------
-- Each section: { title, { { topic, text }, ... } }.
ns.HELP = {
  { "С чего начать", {
    { sub = "Первые шаги" },
    { "Откройте это окно", "Введите /fl или нажмите кнопку у миникарты." },
    { "Изучите рецепты", "Откройте окно каждой профессии один раз на каждом персонаже." },
    { "Узнайте цены", "На аукционе нажмите «Полная проверка» (разрешается примерно каждые 15 минут)." },
    { "Подсказки", "Наведите на любой предмет, чтобы увидеть его стоимость для вас. В настройках можно включить короткий вид (сегодняшний минимум и стоимость для вас), Shift — остальное. Если лотов 20 и больше, продажа на аукционе оценивается по сегодняшним ценам; если меньше — по обычной цене месяца, если она ниже, чтобы пара надежд не вводила в заблуждение; серая строка об этом скажет. Что даёт распыление или изготовление, оценивается не выше обычной цены за эту неделю, поэтому скупка, взвинтившая цену материала, не сделает распыление выгодным." },
    { "Сумки", "Подсказка сумки показывает, сколько стоит один слот по сегодняшней минимальной цене (аукцион или торговец), и какая сумка сейчас дешевле всего за слот — чтобы сначала покупать самое дешёвое место." },
    { sub = "Настройки и вид" },
    { "Поиск", "В настройках и справке есть поиск над списком: введите две буквы или больше, чтобы увидеть всё, где это упоминается, сразу из всех разделов." },
    { "Настройки", "Боковая панель, как в EllesmereUI: сначала глобальные настройки (одинаковые для всех персонажей: комиссия аукциона, запас, источник цен и что считается перепродажей или сделкой), затем профили, затем страница на каждую часть аддона с вкладками сверху." },
    { "Темы", "Настройки, Внешний вид: FL Clean (плоская и тихая), FL Bronze (бронзовый край, золотые заголовки, секции-карточки, переключатели) или FL Gilded (бронзовая рамка, золотые заголовки с засечками), и цвет акцента: «Авто» берёт цвет EllesmereUI, если он установлен, или выберите свой. Новый вид появляется после перезагрузки; аддон предложит её. «Размер» делает окна меньше или больше, от 75% до 150%: перетащите и отпустите." },
    { "Профили", "Настройки, Профили: профиль — набор настроек, которым могут делиться персонажи, например без подсказок у одного и без поиска клиентов у другого. Каждый персонаж использует один (сначала «По умолчанию»). «Новый профиль» копирует текущие настройки; «Переименовать», «Сбросить» и «Удалить профиль» (клик дважды) действуют на профиль этого персонажа. «Экспорт и импорт» открывает одно окно: экспорт копирует профиль текстом с отмеченными частями; импорт создаёт новый профиль из чужого текста. Глобальные настройки в профиль не входят." },
    { sub = "Обновления" },
    { "Приветствие", "При первом открытии окна короткое приветствие перечисляет пять первых шагов. Показать снова — кнопка внизу слева на этой вкладке или /fl welcome." },
    { "Что нового", "После обновления чат один раз перечисляет новое в версии. Кнопка «Что нового» (внизу справа в справке и Обзоре) или /fl new покажет это карточкой." },
  } },
  { "Auction house scans", {
    { sub = "Scanning" },
    { "Full scan", "Reads every listing in a few seconds." },
    { "Pause", "Holds Live watch and the Buy queue's own lookups, so your searches and the page you're on stay as you leave them; Buy, Go now and clicking a row still work. Resume carries on, and closing the auction house ends it too. To check just what your recipes use, type /fl scan materials." },
    { "Live watch", "On the auction house: keeps scanning while it stays open and chimes when a new vendor flip turns up. Between full scans (about every 15 minutes) it reads the auction house's whole list about every 20 seconds, as a search with no name on the Buy page does, and looks closely at anything that just got cheap enough. The list comes cheapest first, in parts: a new flip chimes and goes to the Buy queue as soon as its part arrives, without waiting for the rest. While it reads, the Buy page's list shows every item, cheapest first; after your own search it waits half a minute before replacing your results. It can only scan with the auction house open: it pauses when you close it and picks up again when you come back (Settings, Auction house: Resume Live watch). It also waits while you're on one item's buy or sell page, so it doesn't change what the page shows; the status line says so, and it carries on when you go back to the list." },
    { "Quiet mode", "Doing something else while you wait for a chime? /fl quiet turns the game's sound off and plays Forever Ledger's chimes at full volume, even with the game in the background, plus a chime when you win an auction. It stays on for that character, through reloads and logins, until you type /fl quiet again. Quiet mode while Live watch runs (Settings, Auction house, Alerts) does it by itself, and /fl pair offers to turn that on. Your sound settings come back afterward." },
    { "Other addons", "If Auctionator or another addon runs a full scan, Forever Ledger reads it too. With Auctionator, TSM or ForeverForge installed, features they already cover (like auction prices in tooltips, or a sound when an auction sells) are switched off once, with a message; turn them back on in Settings." },
    { "Neutral auction houses", "Booty Bay, Gadgetzan and Everlook keep their own prices and take a 15% cut (your faction's takes 5%), which values, sell protection and the Auctions tab count while you're there. The Auctions tab lists what you have up there apart from your faction's." },
    { sub = "Selling" },
    { "Your auctions", "The Auctions tab beside the auction house: All, Up, Undercut and Sold, like the Ledger. Each auction shows how many, your price each, the cheapest now, and undercut (red) or cheapest (green); sold ones show what you get after the cut and when the gold reaches your mailbox. The bottom line says what gold is on the way and what's waiting in your mailbox. Check prices looks them all up; scans and Live watch check them too, and an undercut gets a chat line and a sound (Settings, Auction house). Cancel next undercut asks once, then each click cancels the next one (each loses its deposit). Opening the auction house says in chat what sold while you were away and the gold it brings (Settings, Auction house). Scroll to cancel (off each visit, Esc turns it off): each mouse wheel tick over the list cancels the next undercut one. Also cancel ones I could ask more for: adds your auctions that are the cheapest but at least 10% under the usual price (marked could ask more), to repost higher. Middle-click a row to skip it this visit." },
    { "Sale sound", "A coin sound when one of your auctions sells. Settings, Auction house: Sound when an auction sells." },
    { "Price helper", "On the Sell tab, under the Create Auction button: your usual price and the cheapest now, with Undercut (1 copper under the cheapest) and Usual buttons that fill in the price. When the cheapest is well below usual it says so, so you can wait. You still click Post (Settings, Auction house)." },
    { "Sell protection", "On the Sell tab, if a vendor pays more than your listing would bring after the auction house cut, a red line under Post says so and Post is grayed out until you click Post anyway. Settings, Auction house: untick Stop posts below vendor price to keep just the warning." },
  } },
  { "Tooltips", {
    { sub = "Prices" },
    { "Auction price", "Auction, cheapest: the lowest price listed at your last scan, how many were listed, and (in gray) how long ago. Under it, when different: the average of the 20 cheapest, about what you'd pay buying a few. Values in Forever Ledger use that average, so one odd cheap listing doesn't sway them. With your own prices over 12 hours old, Auctionator's or TSM's price is used if you have them, and named." },
    { "Worth to you", "The best of selling on the auction house, selling to a vendor, disenchanting, or crafting it into something, with the best few ways listed. Disenchanting counts what the materials sell for, as an average: each disenchant gives one result, and the tooltip shows the chance of each. Hover damaged gear and the vendor way counts what a vendor pays for it as it is. Settings, Tooltips chooses which ways it counts (turn off crafting to leave out what your alts could make); shuffles and the Buy queue still count every way." },
    { "Sell suggestion", "On items in your bags, the first Forever Ledger line says what to do with it. Keep, when a quest still needs it, a recipe of one of your characters uses it, you watch it, or it's on one of your lists. Otherwise Sell: Vendor, Sell: Auction house (it brings clearly more after the cut and a deposit: a quarter more, or twice as much when it sells slowly), or Sell: Close call when the two are near, with the reason in gray. Soulbound items say Vendor; gear this character can wear says what to do if you won't wear it (If you won't wear it: sell to a vendor, or disenchant when that's clearly worth more). When disenchanting brings more, that shows too, with your enchanter's name; when it brings a quarter more or better, Disenchant is the first line and selling the other way under it. Only a suggestion: nothing is sold. Off in Settings, Tooltips." },
    { "Auction house deposits", "Selling an item on the auction house (its Worth to you line), resale deals and the Booty Bay view allow for one 8-hour listing that doesn't sell (its deposit is lost). The deposit comes back when a listing sells. Materials further down a chain (dust from disenchanting, a craft's output) don't count it, so the Disenchant finder, shuffles, vendor flips and shopping-list limits are unchanged. If this makes selling to a vendor better, the option says Vendor it instead. Deposits use the auction house's quote when available, otherwise Classic's formula, which matches Forever: 5% of the vendor price per 2 hours (25% at Booty Bay), so 20% for 8 hours. Without a known vendor price, it's zero." },
    { "Buy at or below", "The most worth paying, after your safety margin. Green when it's already cheaper." },
    { "Gear versions", "Gear with random stats (of the Eagle) also shows the price of that exact version." },
    { "Price history", "Hold Ctrl over an item: the cheapest price over the last 14 days, whether it's rising or falling, the usual price this month, how many are usually listed and the lowest price ever seen. It builds up with each scan." },
    { "Price window", "Alt-click an item in your bags, a link in chat or a listing on the auction house (search results, a gear listing, or the item's picture on its buy page; gear with random stats opens on the version you clicked) for its own window. To look up any item, even one you don't have: Price lookup at the top of this window, or /fl price, then type part of its name in the box at the top right. The window shows the usual price, which way it's heading, the cheapest now and how many are listed, how many you have and have posted; a graph of the cheapest and typical price each day for 2 weeks, 3 months or a year (each scan saves a day, and with sync on your other account's scans count too, with days you missed while offline, up to 14, sent over when the two connect; days are kept 90 days, then as weekly averages for a year), with how many were listed as bars and dashed lines for the vendor price or disenchant value and the cost to craft; hover it for each day. Gear with random stats can show one version (of the Eagle). Beside it: your last 7 days with the item and what it's worth to you. If a recipe makes it: the materials at today's prices, what crafting one costs against what it sells for after the cut and one unsold listing (as Worth to you counts it), and the profit; click a material for its own graph. Choose how many crafts and a list to add the materials to a shopping list. Search on the auction house shows it there while the auction house is open. Settings, Tooltips, General turns the click off or changes it to Ctrl-click or Ctrl+Alt-click (if another addon, such as a disenchanting one, uses Alt-click). Ctrl-click then no longer opens the dressing room; with Ctrl+Alt-click, Ctrl-click still does." },
    { sub = "Uses and quests" },
    { "Also", "Disenchant results, which of your recipes use it, and the cheapest crate fill." },
    { "Quests and crafts", "Items quests ask for (Bronze Tube, Spider Ichor, Flask of Oil...) say Quests (3) in orange, and items crafts use say Used in crafts (12) with the professions (every recipe we know, yours or not). Hold Shift for the lists: each quest, its level and how many, for your faction, and the crafts by profession, with which of your characters use it. Quests turn yellow with keep it when this character hasn't reached that level yet, so you don't vendor it. Quests this character has done, ones gray for its level and other classes' quests are left out (Settings, Tooltips: Only quests this character still needs; off shows them all, marked). Leveling players buy these once per character, so they sell; the Deals tab's hover says when a deal is one. From original Classic quests: Forever may have changed some." },
    { "Darkmoon Faire", "Items the Darkmoon Faire takes for Prize Tickets get a coral red line: how many a turn-in takes, the tickets it gives and who takes them (Small Furry Paw: 5 for 1 ticket, Yebb Neblegear). Animal parts, and Blacksmithing, Engineering and Leatherworking crafts. Classic's list: Forever may have changed it. Settings, Tooltips." },
    { "Sells", "How fast an item sells: Fast, Steady, Slow, Rare (seldom listed, goes quickly) or No sales seen, judged against items of the same kind, so ore and swords aren't held to the same bar. It counts listings that vanished before they could have expired, so it builds up as you run full scans (fastest with Live watch) and shows after 3 hours of scans compared (and, in the first day, at least 3 sales)." },
  } },
  { "The Gold making tab", {
    { "Gold making tab", "Every way to make gold Forever Ledger finds, in one list: crafts that sell to a vendor or on the auction house, conversions, vendor flips, deals well below the usual price, disenchanting, and Booty Bay against your own auction house. Each row: what it costs, what it brings, the profit each time and how many times you could do it with what's listed cheaply enough now. Click a column name to sort; it starts with profit times how many. It's worked out when you open the tab (Refresh to do it again). It replaces the Shuffles and Deals tabs: /fl deals still opens the old Deals tab for now." },
    { "Kinds and filters", "The buttons across the top pick a kind, with how many of each; Everything leaves Booty Bay out (it needs a trip there, and only prices from the last 3 days count). Least profit hides small ones, and the profession box shows one profession's crafts (disenchanting counts as Enchanting). Untick Only my recipes to add every profession's crafts that sell to a vendor for more than they cost, from recipes nobody of yours knows yet (marked learn). Search narrows it by name." },
    { "Saved filters", "Pick filters, then Save these filters: they become a quick button (up to 5). Click one to use it, right-click to delete it." },
    { "How it adds up", "Click a craft: the panel on the right works out the cheapest way to get its materials for that many crafts (it starts at what's listed cheaply enough, and for an auction house craft no more than about a day's sales; change it with Crafts). Each material is filled one at a time from the cheapest place next: your bags (at what they'd sell for, or free with Count my bags as paid for), the next listing on the auction house, a vendor, or making it from its own materials. So a few cheap Bolts of Runecloth are bought and the rest made from cloth, and nothing is counted twice. Add materials to a shopping list puts what's bought on a new list, each up to the highest price the plan paid." },
    { "Other kinds", "Click a deal, flip, disenchant or Booty Bay row for its numbers and why. Right-click any row (or Price window) for the item's price window." },
  } },
  { "Shuffles and vendor flips", {
    { "Shuffles", "Buy materials, craft, disenchant or convert, and sell, ranked by profit per hour. Click a row for every step. Blizzard nerfed most vendor shuffles, so Sells to a vendor may often be empty. Tick All professions there to see every profession's crafts that sell to a vendor for more than their materials, whoever knows them. Recipes from your profession windows come first. Ones your windows haven't shown come from the game's own data, marked (Forever), and for an item that has none, Classic's, marked (Classic). Some may not be learnable in game yet." },
    { "Add to shopping list", "Open a shuffle or vendor flip, pick a regular list or New list, choose how many crafts (or items), then Add to shopping list. Its purchases and price limits are added; an existing item keeps its bought count and any price you typed. A disenchant group uses its cheapest item. Crate lists and lists with Any price are left out. New lists start with buying off: check Want and Up to and tick Buy from this list when ready." },
    { "Vendor flips", "Things on the auction house for less than a vendor pays. They're in the Buy queue beside the auction house (its Vendor flips view); a full scan that finds some opens it if it's closed, and Live watch chimes. Settings, Global settings, Flips and deals sets the least profit worth your time, as a share of the vendor price and as an amount." },
    { "On the auction house", "Listings worth buying get a green bar and a badge saying why (FLIP, DE, CRAFT, USE), and the line above says how many are left." },
  } },
  { "Buy queue and lists", {
    { sub = "Buy queue" },
    { "Buy queue", "Click the Buy tab along the bottom of the auction house window, after Blizzard's Buy, Sell and Auctions (My auctions beside it shows your auctions; with Forever Ledger's tabs in the auction house off in Settings, click Buy queue under the window for a panel beside it). It lines up vendor flips and your shopping lists. Each row says Up to (the most it pays for one), Buy (how many it would buy now: what's listed at or under that, no more than the list wants or your gold covers) and Total (what those cost). It finds the next one by itself, and a click on Buy (or, with Scroll to buy ticked, a tick of the mouse wheel, up or down, anywhere over Vendor flips or over a shopping list's top strip) buys it. A stack of materials is confirmed in the same tick once its final price comes back within your limit (to confirm it yourself, tick Confirm stacks with a second click in Settings, Auction house). Bottom right: what you bought this visit, what it cost and the profit if you vendored it (hover for the numbers). /fl queue. Each row has a star: click it to watch the item (gold while watched; Live watch then looks for it every time it reads the auction house), and a short reason, FLIP or WATCH (or the shopping list's name)." },
    { "Scan once", "The Buy tab's Scan once view is for looking things over instead of sniping. Scan reads the whole auction house list once (with Live watch on, its prices are fresh already), and the list stays as scanned until you scan again. Tick groups on the left (All items, All groups, Materials, Cloth...; a group counts the ones under it, ticked groups add together, + opens a group) and search names at the top right. Each item shows its cheapest price, its usual price, how far under or over that it is (green under 90%, red over 110%), how many are listed, and FLIP, WATCH or DEAL when Live watch would buy it. Best deals first. Click a row for its price window; click the star to watch it." },
    { "Post", "The Post tab in the auction house window: your bags, grouped (Cloth, Herbs, Gear...), each with a price ready and a mark from the sell suggestion (Post, Keep, Vendor, Disenchant; Show: Everything lists all you could post). The price comes from the item's post rule: the same as the cheapest (listings at one price sell in the order they went up; a rule can undercut instead), never below 70% of the usual price or what a vendor pays after the cut; under that it isn't posted. Picking an item looks it up on the auction house, as the Sell page does, and the price comes from the listings now (Post waits for that); the table below lists them, price each, how many and the seller, yours marked, with a line where yours would go; click a listing to price yours the same as it, Refresh looks again. Change how many, the price or how long (2h, 8h, 24h) and see the deposit, the total price and what you get after the cut; the line under says where the price came from and which rule. Post posts it and moves to the next; Skip and Previous move along; middle-click a row to skip it this visit. Scroll to post (off each visit, Esc turns it off): each mouse wheel tick over the list posts the highlighted one. One click or tick per post, as the game requires; when the game asks to confirm, the next click or tick confirms." },
    { "Groups", "The Groups tab sorts items into groups and gives each group rules. Built-in groups (Materials, Cloth, Herbs, Consumables, Recipes, Gear...) sort themselves by the game's item type, gear by kind and then by required level (Level 1-15 up to 56-60); profession groups (Tailoring materials, Tailoring crafts) come from the recipes; Watched and Gray items; and your own groups (New group). Pick a group: Items lists what's in it (add an item by name, ID or Shift-click; Remove from group; Restore items puts a built-in group back), Rules has four cards, Post, Buy, Vendor and Craft, each Same as the group above, Forever Ledger's default, Off, Changed here (edit a field) or one of your saved rules. Rules on the left lists the defaults (copy one to make your own) and your saved rules, which several groups can share. When an item is in several groups, your own group wins, then a profession group, then a built-in one. The Post tab uses the post rules today; Restore built-in and deletes ask first." },
    { "Scanning from the panel", "The panel's bottom row has Live watch, Full scan and Pause (Stop watching and Resume while they're on), with the scan's progress just above. While the panel is open beside the auction house, the same buttons under the auction house window are hidden." },
    { "Watched items", "Items you always want checked, each with the most you'd pay (Silk Cloth up to 2s for bandages, say). Live watch looks for them every time it reads the auction house (about every 20 seconds), and anything at or under your price joins Vendor flips, first in the list, and chimes. Leave the price at vendor to buy one only when a vendor pays more. Add one with Watch in its price window, or with the Watched button at the top of Vendor flips (shift-click, drag or type it); change Up to or remove it there. For gear, any stat version at or under your price is bought." },
    { "Two views", "Vendor flips or Shopping lists, switched at the top of the panel, one at a time; the one you're on is the one that buys, so a list never buys a flip by accident. Each has its own buttons at the bottom. When there is something to buy, the strip at the top glows (gold for Vendor flips, purple for Shopping lists); with Scroll to buy ticked it also shows a mouse wheel: scroll anywhere over Vendor flips (drag the bar on the right to scroll its list), or over a shopping list's top strip. A new flip that chimes switches the panel to Vendor flips, unless you're using a shopping list (something on it being looked up or bought, or a click or scroll there in the last 30 seconds); then a gold count on the Vendor flips button (and on the Buy queue tab) says it's there." },
    { "Safe by design", "It never pays more than the limit shown (checked again on the final price) or more than you have, and every purchase starts with your own tick or click, as Blizzard requires. Scroll to buy only works with the mouse over Vendor flips or a shopping list's top strip; untick it to buy by clicking only. Right-click an item to skip it. Items you can't afford yet stay at the bottom of the list, grayed and marked can't afford, and are skipped until you have the gold; scroll past the last one you can buy and you get the error sound and a red message, once." },
    { "Spend at most", "The box near the bottom of the Buy queue caps what it spends this auction house visit (type 50 for 50g; it starts again each time you open the auction house). No limit until you type one; what's left shows beside it. Items over it are marked over limit and skipped. To always keep some gold back for repairs or a mount: Settings, Auction house, Buy queue: always keep." },
    { sub = "Shopping lists" },
    { "Shopping lists", "Named lists of items, for example twink gear to watch for or raid consumables to buy. Pick a list from the dropdown at the top; New, Rename and Delete are beside it. With the list open, shift-click an item to add it (or drag it, or type its name: names are suggested as you type, Enter takes the top one). Open them anywhere, to plan before you go to the auction house: the Shopping lists button at the top of this window, Shift-click on the minimap button, or /fl lists." },
    { "Search all", "Checks the auction house for everything on the list at once. Each item shows when it was checked (checking... and in line while it runs), how many are listed and the cheapest. Click an item to look at it on the auction house." },
    { "Have", "What you own of each item: this character's bags, bank and auction house purchases still in the mail, and your characters on this ruleset and faction. On a list you buy from it reads 3 (20): 3 bought for the list, 20 owned. Hover the number to see where. It's there to know, it doesn't change what's bought." },
    { "Buying from a list", "Tick Buy from this list in the Buy queue: the list adds Want (how many to buy) and Up to (the most you'll pay for one: filled in from its source; hover to see where it came from; off means don't buy it), and the Buy queue's Shopping lists view buys them. Want is how many to buy, whatever you already have; Have shows how many are bought so far. It never buys more than Want. Type any in Want to keep buying it whenever it's at or under Up to, with no limit (not with Up to any, which would buy every listing: then it buys one). An item is done once its Want is bought, and stays done; Buy again (bottom right) starts the list over. The bottom line says about what buying the rest would cost." },
    { "Where Up to comes from", "Hover Up to for its source. From a shuffle: its buying cap, not today's price; if two shuffles use an item, the lower cap wins. Add the shuffle again or use Buy again to refresh it. Added by hand: usual price plus this list's allowance (Pay up to X% over the usual price, starting at 10%); change the percentage on each list, then switch buying on or use Buy again to fill it. Type any price yourself, including off: it always wins and is never changed automatically. Existing limits are treated as yours. A shuffle route that can no longer be valued turns off until refreshed with known prices." },
    { "Prices", "Type a price any way: 2g 50s 25c, 2 50 25 or 2.50.25 (gold silver copper), 2 50 (gold silver), 25s, 75c, or a plain number for gold; it's tidied up when you press Enter, and a tip shows what it will be. Type any for any price, or tick Any price (bottom of the list) for the whole list (raid prep): the queue then buys the cheapest until it has bought what you want, never more than 3 times the usual price." },
    { "Vendor supplies", "Unlimited-stock vendor items show vendor under Up to on lists and stay out of the auction house queue, including hand-added items. Settings > Auction house > Buying: Buy vendor items on the auction house too (off by default) permits buying at the vendor price; a lower price or off that you typed is still respected. Your stored price is kept. Right-click an item's Up to box to use its automatic price again; the hover shows the underlying shuffle cap or usual price plus the list allowance while a typed price is in force. Limited-stock vendor items remain ordinary auction house items." },
    { "Buy or craft", "Items one of your recipes makes have a Buy/Craft button: set Craft and the list shows the materials for the number you want, with Up to for each (usual price plus this list's allowance unless you type one) and how many are bought. Materials a vendor sells are marked vendor. Hover an item one of your recipes makes: what buying it would cost against buying the materials to craft it, and which is cheaper." },
    { "One version", "Type \"Soldier's Armor of the Monkey\", or shift-click a link of that version, to keep just that version on a list. Search all looks up every version of gear; hover an item for each version's price, yours first." },
    { "Share and import", "Share / import (top right of the list) opens a window with two tabs. Share copies a list as plain text to paste in Discord or send a friend; Import reads it back (or a plain list of item names, item numbers or Wowhead links, one per line). Imports never change your own lists, and never buy by themselves: tick Buy from this list to buy from one." },
  } },
  { "Сделки", {
    { "Вкладка «Сделки»", "Лоты заметно ниже обычной минимальной цены предмета — для покупки и перепродажи: цена сейчас, обычный минимум, сколько лотов стоит купить, прибыль после комиссии и одного непроданного лота и насколько это надёжно (хорошо, средне или мало данных)." },
    { "Бухта Боти", "Вкладка «Сделки», «Бухта Боти» (вверху справа): нейтральный аукцион против вашего, каждый после своей комиссии (там 15%, здесь 5%) и одного непроданного лота. «Там продаётся дороже»: предметы минимум на 10% выгоднее при продаже в Бухте Боти. «Там дешевле»: купить там, продать здесь. Цены берутся из проверок там и хранятся отдельно; строка подсказки для больших разниц — в Настройках, Подсказки." },
    { "Почему это сделка", "Наведите на сделку: обычный минимум и типичная цена с числом дней проверок, обычное число лотов и следующий лот. Прибыль считается при перепродаже по обычному минимуму или чуть ниже следующего лота — что ниже. Клик — поиск на аукционе." },
    { "Фильтр", "«Все», «Материалы», «Снаряжение» или «Прочее» и поиск по названию." },
    { "Насколько надёжно", "Если большая часть лотов настолько дешёвая, цена упала и это не выгода: оценка «мало данных». Сделкам нужно минимум 4 дня проверок (или TSM). Слабые данные (мало дней, прыгающие цены, обычно один лот) скрыты, пока не отмечено «Показывать сомнительные сделки»." },
    { "Учтите", "Аукцион не знает, что реально продалось. Покупайте то, что готовы подержать." },
  } },
  { "Распыление", {
    { "Оценки распыления", "Распылить может любой навык наложения чар. Что даёт предмет и как часто — оценки по публичным данным, поэтому игра может отличаться. Зелёные, синие с 21 уровня предмета и фиолетовые с 40 учтены; синие ниже 21 — нет, потому что у нас они давали эссенции там, где оценка говорит об осколках. Зачарованные жезлы и предметы, которые игра не даёт распылить, не учитываются. Редкий дополнительный кристалл из синих высокого уровня и бонус «Тайного утилизатора» не считаются." },
    { "Поиск распыления", "Рядом с аукционом (кнопка очереди, вкладка «Поиск распыления»): подходящая броня и оружие выбранных уровней предмета (список уровней с «Выбрать все» и «Снять все») и сколько в среднем даёт их распыление, если продать материалы. Наведите на строку, чтобы увидеть цену каждого материала и сумму. Наведите на уровень в списке — шансы и что даст неудачный и удачный бросок (Настройки, Аукцион могут скрыть броски). Выберите обычный список или «Новый список» и нажмите «В список покупок», чтобы добавить по одному из каждой показанной строки, которую ваше наложение чар может распылить; правый клик по строке — только её. «До» берёт стоимость распыления минус запас и обновляется при повторном добавлении, по «Купить снова» или правым кликом по «До». Введите цену ниже для большего запаса; ваши цены сохраняются. Новые списки начинают с выключенной покупкой. Подойдёт любая версия характеристик." },
  } },
  { "Рецепты и тренеры", {
    { "Вкладка «Рецепты»", "Все рецепты ваших профессий, кто их знает, где взять, нужный навык и прибыль от изготовления. Правый клик по рецепту — задать тип вручную. Клик по заголовку столбца — сортировка." },
    { "Типы", "Перепродажа или цепочка, изготовление на продажу, услуги чар, не на продажу, невыгодно." },
    { "Откуда", "Сначала то, что вы видели в игре, иначе данные оригинального Classic с пометкой (Classic) или аукцион, если там есть предмет-рецепт. «Метка» ставит точку на карте у торговца, тренера или существа." },
    { "Вид тренеров", "Тренеры, у которых вы были, из Classic и места, которые отмечают городские стражники по вопросу о тренере профессии (с пометкой «стражник»)." },
  } },
  { "Забытые ящики", {
    { "Вкладка «Ящики»", "Самый дешёвый способ заполнить каждый ящик по сегодняшним ценам, с ценой ящика и золотом за награду торговца. После первой сдачи (разовое задание) каждый ящик даёт 5с и 10 наград; чистая стоимость вычитает 5с и зеленеет, если ящик окупается. Клик по ящику — все наборы и то, что у вас есть." },
    { "Список покупок для ящика", "Откройте ящик и нажмите «Дешёвое заполнение в список покупок»: ящик и его предметы попадут в список с его именем и ценами, достаточными, чтобы купить всё по последней проверке. Имеющееся учитывается в «Нужно» списка ящика (только у таких списков). Отметьте «Покупать из этого списка» в очереди, чтобы докупить недостающее. Задайте «Нужно» у ящика, чтобы заполнить несколько сразу: «Нужно» каждого предмета следует за ним. Список временный: каждый заполненный ящик снимает один, и список исчезает с последним (или через неделю)." },
  } },
  { "Клиенты и работа", {
    { "Окно клиентов", "Открывается, когда в чате кто-то просит то, что умеет персонаж, с кнопками «Шёпот» и «Пригласить». x скрывает одну заявку; «Скрыть все» внизу справа — все. /fl customers открывает в любой момент." },
    { "Приглушение", "Кнопка «Приглушить» (внизу справа в окне клиентов) убирает оповещения: до следующего визита в столицу, до перезагрузки, до выхода или навсегда (это выключает поиск; «Включить оповещения» или /fl customers on вернут его). При приглушении заявки всё равно видны в окне, но без всплывающего окна, звука и строки в чате." },
    { "Услуги классов", "Поиск также замечает заявки на еду и воду мага, порталы (с 40 уровня), призывы чернокнижника (с 20) и взлом замков разбойника (с 16) у этих классов. Настройки, Клиенты включают и выключают каждую услугу (и изготовление)." },
    { "Объявления", "Отправляет ваше изготовление (со ссылками на профессии) в «Торговлю», а у этих классов — еду и воду, порталы, призывы или взлом. Правый клик по кнопке — изменить текст." },
    { "Работы", "Чары и оплаченные сделки с заработком за сегодня и неделю. /fl work." },
  } },
  { "Ваше золото", {
    { sub = "Обзор" },
    { "Обзор", "Ваше золото сейчас и его изменение, прибыль, продажи и расходы за выбранный период (от дня до всего времени), график золота (наведите для любого момента), самый прибыльный предмет и крупнейшие продажа и покупка, оборот в день." },
    { "Сбор на транспорт", "Полоса в Обзоре, пока персонаж не выучил транспорт (потом эпический): цена (от тренера езды, как увидите его, иначе около 100g и 1000g), ваше золото и примерное число дней при вашем темпе. Отключается везде в Настройках, Глобальные, Модули; «Скрыть» — у одного персонажа, /fl fund вернёт." },
    { "Персонажи", "Слева ваши персонажи этого мира и фракции с золотом (меню выше выбирает другой мир или фракцию, обе фракции или все миры). Выберите персонажа, чтобы увидеть профессии, сумки и банк, стоимость каждого предмета для вас («Цена»: лучшее из аукциона, торговца, распыления или изготовления) и лучший способ получения; «Все персонажи» суммирует всех. Наведите на предмет — у кого он есть, на персонажа — золото и стоимость сумок и банка, на нижнюю строку — из чего она сложилась. Сумки на момент последнего входа, банк — последнего визита." },
    { sub = "Журнал" },
    { "Журнал", "Все: каждая операция в одном списке (продажи и покупки на аукционе и у торговцев, ремонт, почта, добыча, задания...), приход зелёным, расход красным. «Продажи», «Покупки», «Перепродажа» (прибыль по купленным и проданным) и «Прочее» показывают по одному виду. Фильтр по времени, персонажу или слову; клик по заголовку — сортировка; наведите на строку для подробностей." },
    { "Суммы строк", "Выберите строки, чтобы увидеть сумму: клик по одной, Shift+клик по другой — всё между ними, Ctrl+клик добавляет или убирает, либо протяните мышью. Нижняя строка покажет приход, расход и итог выбранного. Правый клик по строке или «Сбросить выбор» — начать заново." },
    { sub = "Сессии" },
    { "Сессии", "Запустите её (Ctrl+клик по кнопке миникарты или /fl session start) — небольшой счётчик, который можно перетащить, посчитает, сколько приносит ваше время: золото в час, приход и расход и добычу (по лучшей из цен аукциона и торговца; в Настройках, Сессии можно считать только по торговцу). Правый клик по счётчику сворачивает его в одну строку. Остановите — придёт сводка в чат; сессия появится в подвкладке «Сессии» журнала: когда, сколько длилась, золото, что вы добыли, золото в час и персонаж (наведите на строку — откуда пришло золото и лучшая добыча). Сессия продолжается после выхода из игры тем же персонажем." },
    { sub = "Хранение данных" },
    { "Сколько хранится", "Продажи и покупки по одной — 30 дней, затем строкой на предмет в месяц в течение года. Золото и движение денег по дням — год, затем по месяцам. Цены по дням — 90 дней, затем понедельно год. Рецепты, торговцы, предметы и персонажи хранятся всегда. При перезагрузке ничего не теряется: суммируются или удаляются только данные старше этих сроков." },
  } },
  { "Два аккаунта", {
    { "Живая синхронизация", "Свяжите второй аккаунт в Настройках, Персонажи (или /fl pair Имя Фамилия на обоих персонажах): цены и рецепты ходят между аккаунтами, пока оба в сети: сначала персонажи, затем цены (это может занять несколько минут), затем пропущенные дни истории цен (до 14, примерно минута в день). При связке спрашивают, ваш ли это аккаунт: «да» — и золото с продажами тоже идут, чтобы Обзор и Журнал совпадали. В них есть имена покупателей, поэтому для друга отвечайте «нет». Каждая новая связка начинает с выключенным обменом и спрашивает снова. Меняется в «Делиться золотом и продажами», сумки и банк — в «Делиться сумками и банком» (обе в Глобальных, Дополнительно). /fl unpair останавливает и удаляет персонажей, золото и продажи другой стороны; цены остаются." },
    { "Удаление персонажа", "Настройки, Персонажи показывают всех известных персонажей, когда их видели и откуда. Аддон не видит удаление персонажа, поэтому старых убирают там: нажмите «Удалить» дважды. Забываются уровень, профессии, рецепты, сумки и банк; цены и история золота остаются. Текущего персонажа удалить нельзя." },
    { "Экспорт и импорт", "«Экспорт и импорт» на вкладке персонажей, чтобы перенести всё вручную (и цены текстом)." },
  } },
  { "Справка и сообщество", {
    { "Новые версии", "Если у согильдейца или участника группы новее Forever Ledger, чат раз за сессию сообщит об этом и где обновиться. Передаётся только номер версии (Настройки, Миникарта и обновления)." },
    { "Discord", "discord.gg/WKsCtvupeC: обновления, вопросы и новости WoW Forever." },
    { "Нашли ошибку?", "Введите /bug в Discord и заполните короткую форму. По возможности приложите вывод /fl api или ошибку BugSack." },
    { "Есть идея?", "Введите /idea в Discord. Отчёты появятся в вашем сообщении." },
  } },
  { "Ваши данные", {
    { "Остаётся на вашем компьютере", "Всё, что записывает Forever Ledger, хранится в его файле сохранения на вашем компьютере. Автору и кому-либо ещё ничего не отправляется." },
    { "Что хранится", "Цены и их история, замеченные места торговцев и тренеров, рецепты ваших персонажей, золото, продажи и покупки, сумки и банк, найденные в чате заявки и журнал работ." },
    { "Что отправляется", "Только живая синхронизация со своим связанным персонажем (выключена до /fl pair), объявления в «Торговлю» по нажатию кнопки и номер версии Forever Ledger согильдейцам и группе, что можно отключить (Настройки, Миникарта и обновления)." },
  } },
  { "Commands", {
    { "/fl", "Open or close the window." },
    { "/fl scan", "Full scan or materials." },
    { "/fl watch", "Live watch." },
    { "/fl quiet", "Quiet mode on this character, until you type it again: game sound off, chimes at full volume." },
    { "/fl price", "The Price window: look up any item's price history." },
    { "/fl queue, /fl lists", "The Buy queue or shopping lists." },
    { "/fl deals", "The old Deals tab (/fl deals list in chat). Deals are on Gold making now." },
    { "/fl session", "Sessions: /fl session start or stop (or Ctrl-click the minimap button)." },
    { "/fl customers, /fl work", "The Customers window. /fl customers on or off turns the customer finder on or off." },
    { "/fl de", "Your disenchant results." },
    { "/fl book", "Recipe data gathered." },
    { "/fl pair, /fl unpair", "Link or unlink your other account." },
    { "/fl sync", "Sync status." },
    { "/fl welcome, /fl new", "The welcome card; what's new in this version." },
    { "/fl perf, /fl probe", "What takes time; game checks." },
  } },
}

---------------------------------------------------------------------------
-- Questions players asked, per Help section (owner, October 3: one page was getting
-- long, so Help is split into topics, each with its questions). Add new ones as players
-- ask them; keep the answers short. { question, answer }.
---------------------------------------------------------------------------
ns.HELP_FAQ = {
  ["С чего начать"] = {
    { "Покупает или продаёт ли аддон сам?", "Нет. Каждая покупка и лот начинаются с вашего клика (или тика колеса), как требует Blizzard; подтверждение стопки может прийти в том же тике. Forever Ledger находит, подсказывает и ставит в очередь." },
    { "Почему в первый день что-то пусто?", "Цены и перепродажи работают с первой полной проверки. Сделкам и скорости продажи нужно несколько дней проверок, чтобы понять, что обычно." },
  },
  ["Очередь покупок и списки"] = {
    { "Нажимать большую кнопку или строку?", "Любое. Большая кнопка (или колесо при отмеченной «Покупке колесом») покупает следующее. Клик по строке покупает её следующей." },
    { "Почему предметы исчезли из очереди?", "Их купили раньше или цена слишком старая: находки старше 15 минут не учитываются, пока проверка не найдёт их снова." },
  },
}

---------------------------------------------------------------------------
-- The Help tab, laid out like Settings (owner's test, October 4): a sidebar with search
-- and the topics, the chosen topic on the right under its title, each entry as a name
-- with its explanation under it, the topic and its questions each in a card with the
-- heading inside (Default and Gilded). Opens on the first topic each time (ns.helpTopic,
-- set back by UI.lua's setView).
---------------------------------------------------------------------------
local NAV_W = 190
local hv

-- The sidebar's groups, like Settings'; Getting started stands on its own.
local HELP_GROUPS = {
  ["The Gold making tab"] = "Gold making", ["Auction house scans"] = "Gold making", ["Tooltips"] = "Gold making", ["Shuffles and vendor flips"] = "Gold making",
  ["Buy queue and lists"] = "Gold making", ["Deals"] = "Gold making", ["Disenchanting"] = "Gold making",
  ["Recipes and trainers"] = "Professions", ["Waylaid Crates"] = "Professions", ["Customers and work"] = "Professions",
  ["Your gold"] = "Your gold",
  ["Two accounts"] = "Other", ["Help and community"] = "Other", ["Your data"] = "Other", ["Commands"] = "Other",
}

local function topicIndex()
  local want = ns.helpTopic
  for i, s in ipairs(ns.HELP) do if s[1] == want then return i end end
  return 1
end

function ns:BuildHelp(parent)
  local T = ns.Theme
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  hv = { frame = f, navButtons = {} }

  -- The sidebar, like Settings': search and the topics.
  local nav = CreateFrame("Frame", nil, f)
  nav:SetPoint("TOPLEFT")
  nav:SetPoint("BOTTOMLEFT")
  nav:SetWidth(NAV_W)
  local fr = T.theme.frame
  T:Fill(nav, fr and { 0.91, 0.76, 0.48, 0.04 } or { 1, 1, 1, 0.02 })
  local edge = nav:CreateTexture(nil, "BORDER")
  if fr then edge:SetColorTexture(fr[1], fr[2], fr[3], 0.5) else edge:SetColorTexture(1, 1, 1, 0.06) end
  edge:SetPoint("TOPRIGHT")
  edge:SetPoint("BOTTOMRIGHT")
  edge:SetWidth(1)

  -- Search, from 2 letters: every entry and question with it, from all topics at once
  -- (owner's test, October 3). Clicking a topic clears it.
  local search = T:EditBox(nav, NAV_W - 16, "LEFT")
  search:SetPoint("TOPLEFT", 8, -6)
  local hint = T:Text(search, 11, T.section)
  hint:SetPoint("LEFT", 6, 0)
  hint:SetText("Поиск по справке")
  search:SetScript("OnTextChanged", function(self)
    hint:SetShown(self:GetText() == "" and not self:HasFocus())
    local q = self:GetText():lower():gsub("^%s+", ""):gsub("%s+$", "")
    local new = #q >= 2 and q or nil
    if new ~= ns.helpQuery then
      ns.helpQuery = new
      ns:RefreshHelp()
      hv.sf:SetVerticalScroll(0)
    end
  end)
  search:SetScript("OnEditFocusGained", function() hint:Hide() end)
  search:SetScript("OnEditFocusLost", function(self) hint:SetShown(self:GetText() == "") end)
  search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  hv.search = search
  f.search = search   -- (UI.lua clears it when the tab is opened)

  -- Topics (scroll if the window is short): a name, with a bar and a tint on the chosen one.
  local navSf, list = T:Scroll(nav)
  navSf:SetPoint("TOPLEFT", 0, -38)
  navSf:SetPoint("BOTTOMRIGHT", -1, 4)
  hv.navSf, hv.list = navSf, list
  local y, lastGroup = 0, nil
  for i, section in ipairs(ns.HELP) do
    local group = HELP_GROUPS[section[1]]
    if group and group ~= lastGroup then
      local h = T:Text(list, 10)
      T:StyleHeading(h, group)
      h:SetPoint("TOPLEFT", 10, -(y + 8))
      y = y + 26
    end
    lastGroup = group
    local b = CreateFrame("Button", nil, list)
    b:SetHeight(24)
    b:SetPoint("TOPLEFT", 0, -y)
    y = y + 26
    b:SetPoint("RIGHT", list, "RIGHT", 0, 0)
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
    b.text = T:Text(b, 12)
    b.text:SetPoint("LEFT", group and 24 or 14, 0)
    b.text:SetPoint("RIGHT", -6, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)   -- (Magic, October 3: names ran out)
    b.text:SetText(section[1])
    b:SetScript("OnClick", function()
      ns.helpTopic = section[1]
      hv.search:SetText("")
      hv.search:ClearFocus()
      ns:RefreshHelp()
      hv.sf:SetVerticalScroll(0)
    end)
    hv.navButtons[i] = b
  end
  list:SetHeight(y)
  -- (Show the welcome again is in the window's bottom bar, UI.lua: owner, October 5.)

  -- The chosen topic: its title, a line about it, then the entries.
  hv.title = T:Text(f, 16)
  T:StyleTitle(hv.title, 16)
  hv.title:SetPoint("TOPLEFT", NAV_W + 14, -4)
  hv.desc = T:Text(f, 11, T.dim)
  hv.desc:SetPoint("TOPLEFT", NAV_W + 14, -26)
  hv.desc:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  hv.desc:SetJustifyH("LEFT")
  hv.desc:SetWordWrap(false)
  local sf, content = T:Scroll(f)
  sf:SetPoint("TOPLEFT", NAV_W + 4, -50)
  sf:SetPoint("BOTTOMRIGHT")
  hv.sf, hv.content = sf, content
  return f
end

-- Text pieces are reused between topics: get the i-th of a kind.
local function piece(kind, i, make)
  hv.pool = hv.pool or {}
  local list = hv.pool[kind] or {}
  hv.pool[kind] = list
  if not list[i] then list[i] = make() end
  return list[i]
end

-- Draws the chosen topic for the current width (text heights depend on it).
function ns:RefreshHelp()
  if not hv then return end
  local T = ns.Theme
  local cur = topicIndex()
  local q = ns.helpQuery
  for i, b in ipairs(hv.navButtons) do
    local on = not q and i == cur
    b.sel:SetShown(on)
    b.bar:SetShown(on)
  end
  hv.navSf.UpdateScrollBar()

  local section = ns.HELP[cur]
  if q then
    hv.title:SetText("Поиск")
    hv.desc:SetText(("Справка, где упоминается «%s», из всех разделов."):format(q))
  else
    hv.title:SetText(section[1])
    local faq = ns.HELP_FAQ[section[1]]
    local count = 0
    for _, e in ipairs(section[2]) do if not e.sub then count = count + 1 end end
    hv.desc:SetText(("%d материалов%s. Поиск найдёт всё в справке."):format(count,
      (faq and #faq > 0) and (", и частые вопросы") or ""))
  end
  local width = math.max(hv.sf:GetWidth() - 12, 280)
  hv.content:SetWidth(width)
  for _, list in pairs(hv.pool or {}) do for _, p in ipairs(list) do p:Hide() end end

  local y, cards, groupTop = 0, 0, nil
  local nHead, nName, nText, nLine = 0, 0, 0, 0
  -- A group: its heading inside the top of a card; close() ends the card.
  local function close()
    if groupTop then
      cards = cards + 1
      T:PlaceCard(hv.content, cards, groupTop, y + 2, width)
      y = y + 12
      groupTop = nil
    end
  end
  local function heading(title)
    close()
    groupTop = y
    nHead = nHead + 1
    local h = piece("head", nHead, function()
      local fs = T:Text(hv.content, 11)
      fs:SetJustifyH("LEFT")
      return fs
    end)
    T:StyleHeading(h, title)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 14, -(y + 8))
    h:Show()
    y = y + 30
  end
  local function entry(name, text, question)
    nName, nText, nLine = nName + 1, nText + 1, nLine + 1
    local n = piece("name", nName, function()
      local fs = T:Text(hv.content, 12 + (T.theme.labelAdd or 0))
      fs:SetJustifyH("LEFT")
      return fs
    end)
    local d = piece("text", nText, function()
      local fs = T:Text(hv.content, 11, T.dim)
      fs:SetJustifyH("LEFT")
      fs:SetSpacing(2)
      return fs
    end)
    local line = piece("line", nLine, function()
      local tx = hv.content:CreateTexture(nil, "BACKGROUND")
      tx:SetColorTexture(1, 1, 1, 0.04)
      tx:SetHeight(1)
      return tx
    end)
    n:SetText(name)
    local c = question and T.accent or T.text
    n:SetTextColor(c[1], c[2], c[3], 1)
    n:ClearAllPoints()
    n:SetPoint("TOPLEFT", 14, -(y + 4))
    n:SetWidth(width - 28)
    d:SetText(text)
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -3)
    d:SetWidth(width - 28)
    n:Show()
    d:Show()
    y = y + 4 + n:GetStringHeight() + 3 + d:GetStringHeight() + 10
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", 8, -(y - 4))
    line:SetPoint("RIGHT", hv.content, "RIGHT", -8, 0)
    line:Show()
  end

  if q then
    -- Searching: the matching entries and questions of every topic, under its name.
    local function hit(a, b) return (a or ""):lower():find(q, 1, true) or (b or ""):lower():find(q, 1, true) end
    local any = false
    for _, s in ipairs(ns.HELP) do
      local list = {}
      for _, e in ipairs(s[2]) do if not e.sub and hit(e[1], e[2]) then list[#list + 1] = { e[1], e[2] } end end
      for _, fq in ipairs(ns.HELP_FAQ[s[1]] or {}) do
        if hit(fq[1], fq[2]) then list[#list + 1] = { fq[1], fq[2], true } end
      end
      if #list > 0 then
        any = true
        heading(s[1])
        for _, e in ipairs(list) do entry(e[1], e[2], e[3]) end
      end
    end
    if not any then
      heading("Ничего не найдено")
      entry("Попробуйте другое слово", "Например цена, перепродажа, список, проверка или звук. Или выберите раздел слева.")
    end
  else
    -- A topic's named groups each get a card; entries before the first are under the
    -- topic's own name.
    local started = false
    for _, e in ipairs(section[2]) do
      if e.sub then
        heading(e.sub)
      else
        if not started and not groupTop then heading(section[1]) end
        entry(e[1], e[2])
      end
      started = true
    end
    local faq = ns.HELP_FAQ[section[1]]
    if faq and #faq > 0 then
      heading("Вопросы")
      for _, fq in ipairs(faq) do entry(fq[1], fq[2], true) end
    end
    if cur == 1 then
      heading("Ещё")
      entry("Полное руководство", "docs/GUIDE.md на странице аддона в GitHub, с картинками.")
    end
  end
  close()
  T:HideCards(hv.content, cards + 1)
  hv.content:SetHeight(y + 10)
  hv.sf.UpdateScrollBar()
end

---------------------------------------------------------------------------
-- Playing nice with Auctionator and TSM (owner, October 1): features they already
-- cover are switched off the first time each is found, with a one-time message
-- saying what was turned off and where to turn it back on. Every new feature that
-- overlaps one of them gets an entry here (its setting, its name in the message, and
-- which addons cover it).
---------------------------------------------------------------------------
-- ForeverForge (owner, October 3): its Auction module shows prices in tooltips and its
-- core plays a sound when an auction sells. Its folder name isn't known for sure, so a
-- few likely ones are tried (alt).
local AUCTION_ADDONS = {
  { name = "Auctionator", global = "Auctionator" },
  { name = "TradeSkillMaster", short = "TSM", global = "TSM_API" },
  { name = "ForeverForge_Auction", short = "ForeverForge Auction", alt = { "ForeverForgeAuction", "ForeverForge-Auction" } },
  { name = "ForeverForge", alt = { "ForeverForge_Core" } },
  -- Lists the crafts an item is used for (Frank has it, November 14).
  { name = "ProfTooltip-Forever", short = "ProfTooltip", alt = { "ProfTooltip" } },
}
ns.OVERLAPS = {
  { setting = "tipPrice", label = "Цены аукциона и торговцев в подсказках",
    addons = { Auctionator = true, TradeSkillMaster = true, ForeverForge_Auction = true } },
  { setting = "saleSound", label = "Звук при продаже лота", addons = { ForeverForge = true } },
  { setting = "undercutAlerts", label = "Оповещения о перебитых лотах", addons = { Auctionator = true, TradeSkillMaster = true } },
  { setting = "priceHelper", label = "Помощь с ценой на вкладке продажи", addons = { Auctionator = true, TradeSkillMaster = true } },
  { setting = "soldSummary", label = "Что продалось без вас", addons = { TradeSkillMaster = true } },
  { setting = "tipUsedBy", label = "Используется в изготовлении", addons = { ["ProfTooltip-Forever"] = true } },
}

local function loaded(a)
  local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if a.global and _G[a.global] ~= nil then return true end
  if not isLoaded then return false end
  if isLoaded(a.name) then return true end
  for _, n in ipairs(a.alt or {}) do if isLoaded(n) then return true end end
  return false
end

StaticPopupDialogs["FOREVER_LEDGER_OVERLAP"] = {
  text = "%s",
  button1 = OKAY or "OK",
  button2 = "Оставить включёнными",
  OnCancel = function(_, turnedOff)
    for _, key in ipairs(turnedOff or {}) do ns.db.settings[key] = true end
    ns:Print("Оставлено включённым. Изменить можно в любой момент в настройках.")
  end,
  timeout = 0, whileDead = true, hideOnEscape = false, preferredIndex = 3,
}

ns:On("PLAYER_ENTERING_WORLD", function()
  C_Timer.After(10, function()
    if not ns.db then return end
    local s = ns.db.settings
    s.overlapSeen = s.overlapSeen or {}
    local found, names, turnedOff = {}, {}, {}
    for _, a in ipairs(AUCTION_ADDONS) do
      if loaded(a) and not s.overlapSeen[a.name] then
        s.overlapSeen[a.name] = true
        found[a.name] = true
        names[#names + 1] = a.short or a.name
      end
    end
    if #names == 0 then return end
    -- The old tooltip question (before October 1) is covered by this one.
    s.tipAsked = true
    local lines = {}
    for _, o in ipairs(ns.OVERLAPS) do
      local covered
      for name in pairs(found) do if o.addons[name] then covered = true end end
      if covered and s[o.setting] ~= false then
        s[o.setting] = false
        turnedOff[#turnedOff + 1] = o.setting
        lines[#lines + 1] = "- " .. o.label
      end
    end
    if #turnedOff == 0 then return end
    local text = ("%s установлен. Чтобы не видеть всё дважды, Forever Ledger отключил:\n\n%s\n\nОстальное остаётся. Вернуть можно в любой момент в настройках."):format(
      table.concat(names, " и "), table.concat(lines, "\n"))
    local dialog = StaticPopup_Show("FOREVER_LEDGER_OVERLAP", text)
    if dialog then dialog.data = turnedOff end
  end)
end)
