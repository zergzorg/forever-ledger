local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- Levelling tab (owner, October 7): part of the Levelling help module (Settings, Global
-- settings, Modules). Its first page is "С чего начать": ways to make gold while
-- levelling, priced from your scans, for characters under 20. From Codex's research
-- (planning/LAUNCH_GOLD_DRAFT.md in the notes repo, October 7), in our own words.
-- Forever = seen in Forever (patch notes, beta); otherwise Classic's, still to confirm.
-- Lines for a profession or class you don't have are dimmed, not hidden, so the list
-- also helps choose professions.
---------------------------------------------------------------------------
local MAX_LEVEL = 20   -- the tab shows below this level (owner, October 7: start there)

-- ids: items to price; the first is the one shown on the row. prof / class: what it
-- needs. zone: { Alliance, Horde }. vendor: priced at what a vendor pays (binds on pickup).
local LIST = {
  { title = "Свежуйте убитых зверей", prof = "Skinning", lvl = { 1, 20 }, forever = true,
    ids = { 2318, 2934, 783, 2319 },
    zone = { "Стартовая зона, затем Западный край и Лок Модан", "Стартовая зона, затем Степи и Серебряный бор" },
    how = "Свежуйте каждого зверя, которого и так убиваете по заданиям. В Forever одна шкура с трупа. Продавайте кожу, когда она дороже цены торговца.",
    why = "Дополнительные материалы с убийств, которые вы и так совершаете, почти без начальных затрат." },
  { title = "Добывайте медь по маршруту заданий", prof = "Mining", lvl = { 5, 15 },
    ids = { 2770, 2840, 2835 },
    zone = { "Элвиннский лес, Дун Морог, Тёмные берега", "Дуротар, Мулгор" },
    how = "Добывайте жилы по пути и оставляйте грубый камень. Плавьте, только если слитки дороже руды. В Forever медных жил меньше, чем в Classic.",
    why = "Многим прокачиваемым профессиям нужен ранний металл и камень." },
  { title = "Собирайте травы по пути", prof = "Herbalism", lvl = { 1, 20 },
    ids = { 2447, 765, 785, 2450, 2452, 2449 },
    zone = { "Элвинн, Дун Морог, Тельдрассил, затем Западный край и Тёмные берега", "Дуротар, Мулгор, Тирисфаль, затем Степи и Серебряный бор" },
    how = "Собирайте травы рядом с заданиями. Магоцвет и терновник иногда дают быстролист бонусом.",
    why = "Травы идут в зелья (в Forever — в первую помощь) и на прокачку навыка, поэтому они всегда продаются." },
  { title = "Лён и монеты из лагерей гуманоидов", lvl = { 6, 16 },
    ids = { 2589, 2996 },
    zone = { "Кобольды и гноллы Элвинна, затем Дефиас в Западном крае", "Лагеря иглогривов в Дуротаре, затем пираты южнее Крутого Холма" },
    how = "Убивайте гуманоидов по заданиям: лён оставляйте, серые предметы продавайте, зелёные проверяйте. Уходите, когда в лагере людно.",
    why = "Ткань, монеты и добыча торговцу с тех же убийств." },
  { title = "Делайте льняные сумки", prof = "Tailoring", lvl = { 1, 20 }, forever = true,
    ids = { 4238, 2589, 2996, 2320, 4496 },
    zone = { "Любой город с покупателями", "Любой город с покупателями" },
    how = "Сделайте несколько и продайте в «Торговле» или небольшим лотом на аукционе. Шестиячеечная сумка у торговца задаёт верхнюю цену.",
    why = "Каждому новому персонажу сразу нужно место в сумках." },
  { title = "Жезлы для кастеров (продажа игрокам)", prof = "Enchanting", lvl = { 5, 20 }, forever = true,
    ids = { 11287, 11288, 10938, 4470 },
    zone = { "Города с новыми кастерами", "Города с новыми кастерами" },
    how = "Сделайте малый волшебный жезл (позже большой) для кастера, которому он нужен. Торговцы дают за них мало (малый 1с 10м, большой 2с после патча 8 октября), поэтому продавайте игрокам; цена торговца — лишь нижняя граница.",
    why = "Полезное раннее оружие может стоить дороже затрат на изготовление." },
  { title = "Шерсть из следующих лагерей", lvl = { 18, 26 },
    ids = { 2592, 2997 },
    zone = { "Орки Чёрной горы в Красногорье, затем Хилсбрад", "Лагеря и фермы Синдиката в Хилсбраде" },
    how = "Когда хватает сил на лагерь, добывайте шерстяную ткань; продавайте её отдельно от льна.",
    why = "Следующая ткань попадает к покупателям раньше, чем туда дойдут остальные." },
  { title = "Олово, грубый камень и бронза", prof = "Mining", lvl = { 12, 25 },
    ids = { 2771, 3576, 2841, 2836 },
    zone = { "Лок Модан и Западный край, затем Красногорье", "Степи и Серебряный бор, затем Ясеневый лес" },
    how = "Добывайте по безопасному кругу. Плавьте бронзу, только если два слитка дороже меди и олова.",
    why = "Игрокам, прошедшим медь, нужно олово и бронза." },
  -- (Minor Wizard Oil left the list: since the October 8 patch a vendor pays 1s for it,
  -- less than its Maple Seed and vial cost. Codex's research, October 10.)
  { title = "Распыляйте дешёвые зелёные предметы", prof = "Enchanting", lvl = { 5, 20 }, forever = true,
    ids = { 10940, 10938, 10939, 10978 },
    zone = { "Аукцион", "Аукцион" },
    how = "Покупайте зелёные предметы дешевле, чем стоят их пыль и сущности: их показывает поиск распыления у аукциона.",
    why = "Цены снаряжения и материалов часто не совпадают." },
  { title = "Вода и еда мага", class = "MAGE", lvl = { 4, 20 }, forever = true, service = true,
    zone = { "Столицы и места сбора у подземелий", "Столицы и места сбора у подземелий" },
    how = "Предлагайте лучшую воду и еду группам и тем, кто просит в «Торговле», за чаевые. Окно клиентов их находит.",
    why = "Создаётся почти бесплатно; люди платят, чтобы не идти к торговцу." },
  { title = "Лечебные зелья из первой помощи", prof = "First Aid", lvl = { 5, 20 }, forever = true,
    ids = { 118, 858, 2447, 3371 },
    zone = { "Любой город", "Любой город" },
    how = "В Forever лечебные зелья — это первая помощь. Сделайте несколько на заказ; иначе продавайте травы.",
    why = "Прокачивающиеся покупают их вместо того, чтобы учить первую помощь." },
  { title = "Чары как услуга", prof = "Enchanting", lvl = { 5, 20 }, forever = true, service = true,
    zone = { "Чат торговли или ваша группа", "Чат торговли или ваша группа" },
    how = "Зачаровывайте материалами клиента за чаевые; окно клиентов находит заявки.",
    why = "Оплачиваемая прокачка навыка без товара." },
  { title = "Ловите то, что продаётся", prof = "Fishing", lvl = { 10, 20 },
    ids = { 6358, 6522, 21071 },
    zone = { "Побережья Западного края и Тёмных берегов, Лок Модан", "Крутой Холм, оазисы Степей, Серебряный бор" },
    how = "Попробуйте косяк и продайте небольшой улов, прежде чем рыбачить час.",
    why = "Не нужно драться за мобов, а часть рыбы идёт в зелья и еду." },
  -- (Recipe: Peace Tea left the list: it vends for 10c since the October 8 patch.)
}
ns.LEVELLING_START = LIST

local view

local PROF_RU = {
  Enchanting = "Наложение чар", ["First Aid"] = "Первая помощь", Fishing = "Рыбная ловля",
  Herbalism = "Травничество", Mining = "Горное дело", Skinning = "Снятие шкур",
  Tailoring = "Портняжное дело", Alchemy = "Алхимия", Blacksmithing = "Кузнечное дело",
  Engineering = "Инженерное дело", Leatherworking = "Кожевничество", Cooking = "Кулинария",
}

local function myProfs()
  local c = ns.db.chars[ns.CharKey()]
  local have = {}
  for name in pairs(c and c.profs or {}) do have[name] = true end
  return have
end

-- Can this character do it now (profession, class, faction)? And the reason if not.
local function fits(e, profs, class, faction)
  if e.class and e.class ~= class then return false, "нужен " .. e.class:sub(1, 1) .. e.class:sub(2):lower() end
  if e.faction and e.faction ~= faction then return false, e.faction .. " только" end
  if e.prof and not (profs[e.prof] or profs[PROF_RU[e.prof] or e.prof]) then return false, "нужно " .. (PROF_RU[e.prof] or e.prof) end
  return true
end

-- What the row shows on the right: the first item's price.
local function priceText(e)
  if e.service then return "|cff999999услуга|r" end
  local id = e.ids and e.ids[1]
  if not id then return "" end
  local p = e.vendor and ns:GetSellPrice(id) or (ns:GetPrice(id))
  if not p then return "|cff999999нужна проверка|r" end
  return ns.Money(p) .. (e.vendor and " |cff999999торговец|r" or "")
end

local function row(i)
  local r = view.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, view.content)
  r:SetHeight(40)
  r.hl = r:CreateTexture(nil, "HIGHLIGHT")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 1, 1, 0.04)
  r.line = r:CreateTexture(nil, "BORDER")
  r.line:SetHeight(1)
  r.line:SetPoint("BOTTOMLEFT")
  r.line:SetPoint("BOTTOMRIGHT")
  r.line:SetColorTexture(T.border[1], T.border[2], T.border[3], 0.5)
  r.title = T:Text(r, 13)
  r.title:SetPoint("TOPLEFT", 6, -5)
  r.title:SetPoint("RIGHT", r, "RIGHT", -140, 0)
  r.title:SetJustifyH("LEFT")
  r.title:SetWordWrap(false)
  r.sub = T:Text(r, 11, T.dim)
  r.sub:SetPoint("TOPLEFT", 6, -22)
  r.sub:SetPoint("RIGHT", r, "RIGHT", -140, 0)
  r.sub:SetJustifyH("LEFT")
  r.sub:SetWordWrap(false)
  r.price = T:Text(r, 12)
  r.price:SetPoint("RIGHT", -8, 0)
  r.price:SetJustifyH("RIGHT")
  r:RegisterForClicks("LeftButtonUp")
  r:SetScript("OnClick", function(self)
    local e = self.e
    if e.service then
      if ns.ShowCustomers then ns:ShowCustomers() end
    elseif e.ids and not e.vendor then
      if not ns:SearchAuctionHouse(e.ids[1]) then ns:Print("Откройте аукцион и щёлкните строку, чтобы найти её.") end
    end
  end)
  r:SetScript("OnEnter", function(self)
    local e = self.e
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.title, 1, 1, 1)
    GameTooltip:AddLine(e.forever and "Видно в Forever" or "Из Classic: в Forever не подтверждено", 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Что делать", 1, 0.82, 0)
    GameTooltip:AddLine(e.how, 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine("Почему выгодно", 1, 0.82, 0)
    GameTooltip:AddLine(e.why, 0.85, 0.85, 0.85, true)
    if e.ids then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(e.vendor and "Торговец платит" or "Цены из ваших проверок", 1, 0.82, 0)
      for _, id in ipairs(e.ids) do
        local p = e.vendor and ns:GetSellPrice(id) or (ns:GetPrice(id))
        GameTooltip:AddDoubleLine("  " .. ns.ItemName(id), p and ns.Money(p) or "ещё не проверялось", 0.8, 0.8, 0.8, 1, 1, 1)
      end
    end
    if e.service then GameTooltip:AddLine("Клик: окно клиентов.", T.accent[1], T.accent[2], T.accent[3])
    elseif e.ids and not e.vendor then GameTooltip:AddLine("Клик: поиск на аукционе.", T.accent[1], T.accent[2], T.accent[3]) end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  view.rows[i] = r
  return r
end

function ns:BuildLevelling(parent)
  view = CreateFrame("Frame", nil, parent)
  view:SetAllPoints()
  view.head = T:Text(view, 12)
  T:StyleHeading(view.head, "С чего начать")
  view.head:SetPoint("TOPLEFT", 4, -4)
  view.intro = T:Text(view, 11, T.dim)
  view.intro:SetPoint("TOPLEFT", 4, -24)
  view.intro:SetPoint("RIGHT", view, "RIGHT", -4, 0)
  view.intro:SetJustifyH("LEFT")
  view.intro:SetText("Способы заработать во время прокачки, лучшее сначала, по ценам ваших проверок. Приглушённые строки требуют профессии, которой у персонажа нет. Наведите на строку, чтобы узнать, что делать.")
  -- Only what this character can do: hides lines needing a profession it hasn't got
  -- (owner, October 7). Class-only lines never show for other classes.
  view.mine = T:Check(view, function(self)
    ns.db.settings.levellingMine = self:GetChecked()
    ns:RefreshLevelling()
  end)
  view.mine:SetPoint("TOPRIGHT", -150, -6)
  view.mine.label:SetText("Только мои профессии")
  view.mine:SetHitRectInsets(0, -140, 0, 0)
  view.sf, view.content = T:Scroll(view)
  view.sf:SetPoint("TOPLEFT", 0, -56)
  view.sf:SetPoint("BOTTOMRIGHT", 0, 0)
  view.rows = {}
  view:Hide()
  return view
end

function ns:RefreshLevelling()
  if not view then return end
  local profs, _, class = myProfs(), UnitClass("player")
  local faction = UnitFactionGroup("player")
  local level = UnitLevel("player") or 1
  -- What this character can do first (in the list's order), then the rest, dimmed.
  local onlyMine = ns.db.settings.levellingMine
  view.mine:SetChecked(onlyMine)
  local yes, no = {}, {}
  for _, e in ipairs(LIST) do
    local ok, why = fits(e, profs, class, faction)
    -- Another class's or faction's line is no use to this character: left out.
    local other = (e.class and e.class ~= class) or (e.faction and e.faction ~= faction)
    if not other and (ok or not onlyMine) then table.insert(ok and yes or no, { e = e, why = why }) end
  end
  local y, n = 0, 0
  for _, group in ipairs({ yes, no }) do
    for _, it in ipairs(group) do
      local e = it.e
      n = n + 1
      local r = row(n)
      r.e = e
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -y)
      r:SetPoint("RIGHT", view.content, "RIGHT", 0, 0)
      local zone = e.zone and e.zone[faction == "Horde" and 2 or 1] or ""
      local lv = ("уровень %d-%d"):format(e.lvl[1], e.lvl[2])
      if level < e.lvl[1] then lv = lv .. ", позже" end
      r.title:SetText(e.title .. (e.forever and "" or " |cff999999(Classic)|r"))
      local parts = { lv }
      if zone ~= "" then parts[#parts + 1] = zone end
      if it.why then parts[#parts + 1] = it.why end
      r.sub:SetText(table.concat(parts, ", "))
      r.price:SetText(priceText(e))
      r:SetAlpha(it.why and 0.45 or 1)
      r:Show()
      y = y + 42
    end
  end
  for i = n + 1, #view.rows do view.rows[i]:Hide() end
  view.content:SetWidth(math.max(view.sf:GetWidth() - 12, 300))
  view.content:SetHeight(math.max(y, 20))
  if view.sf.UpdateScrollBar then view.sf.UpdateScrollBar() end
end

-- The tab shows while the module is on and the character is under 20.
function ns:LevellingTabShown()
  return ns.LevellingOn and ns:LevellingOn() and (UnitLevel("player") or 0) < MAX_LEVEL
end
-- (UnitLevel catches up a moment after the event.)
ns:On("PLAYER_LEVEL_UP", function()
  if C_Timer then C_Timer.After(1, function() if ns.LayoutTabs then ns:LayoutTabs() end end) end
end)
