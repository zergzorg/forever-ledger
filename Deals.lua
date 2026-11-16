local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- Deals tab: listings well below an item's usual price, each with why it's a deal
-- (hover) and how sure that is. Vendor flips (below what a vendor pays) have their
-- own tab; these are a bet that the item resells, so the tab shows as much as it
-- can: usual price and its spread, days of data, how many are usually listed, the
-- next listing up, and profit after the auction house cut. Click to search the AH.
-- The judging is in Shuffles.lua (FindDeals, DealExplain).
---------------------------------------------------------------------------
local ROW_HEIGHT = 20
local MAX_ROWS = 300
local MAX_AGE = 3600   -- prices from the last hour (alerts use the last 10 minutes)

local SPEED_SHORT = { fast = "Быстро", steady = "Стабильно", slow = "Медленно", rare = "Редко", none = "Нет" }

local COLUMNS = {
  { key = "item", label = "Предмет" },
  { key = "price", label = "Сейчас", width = 80, right = true, tip = "Самый дешёвый лот прямо сейчас." },
  { key = "worth", label = "Обычный мин.", width = 88, right = true, tip = "Обычная минимальная цена по вашим проверкам." },   -- the usual cheapest price
  { key = "pct", label = "Ниже", width = 46, right = true, tip = "Насколько сегодняшняя цена ниже обычного минимума." },
  { key = "listed", label = "Лотов", width = 44, right = true, tip = "Сколько лотов по цене сделки." },
  { key = "sold", label = "Сбыт", width = 60, right = true, tip = "Как быстро продаётся, по вашим проверкам." },   -- the sell speed rating
  { key = "each", label = "Прибыль/шт", width = 80, right = true, tip = "Сколько приносит один после комиссии и залога, минус затраты." },
  { key = "total", label = "Прибыль вся", width = 84, right = true, tip = "То же для всех лотов по цене сделки." },
  { key = "level", label = "Надёжность", width = 76, tip = "Насколько можно верить: хорошо, средне или мало данных. Наведите на сделку." },
}

-- The Booty Bay view (owner, October 5): the neutral auction house against yours, each
-- after its own cut (15% there, yours here). Its prices stay in their own market and
-- only this view (and an optional tooltip line) reads them (Values.lua NeutralCompare).
local NEUTRAL_COLUMNS = {
  { key = "item", label = "Предмет" },
  { key = "there", label = "Бухта Боти", width = 80, right = true },
  { key = "here", label = "Здесь", width = 80, right = true },
  { key = "better", label = "Выгоднее на", width = 80, right = true },
  { key = "npct", label = "%", width = 46, right = true },
  { key = "lthere", label = "Лотов там", width = 80, right = true },
  { key = "lhere", label = "Лотов здесь", width = 80, right = true },   -- (UI pass, October 6: two "Здесь" columns)
}
local NEUTRAL_MIN = 0.10   -- at least 10% better after both cuts
-- Listings needed on the side you'd sell to, unless "Show thin data too" (owner's
-- screenshot, October 5: one Bauxite listed at 55g at Booty Bay read as 44,637% better;
-- one listing is someone's asking price, not what it sells for).
local NEUTRAL_LISTED = 3

local LEVEL_ORDER = { thin = 1, fair = 2, good = 3 }

local function dim(t) return "|cff888888" .. t .. "|r" end

local function neutralMode() return ns.db.settings.dealsMode == "neutral" end

local function sortState()
  local key = neutralMode() and "neutralSort" or "dealsSort"
  ns.db.settings[key] = ns.db.settings[key] or {}
  local s = ns.db.settings[key]
  if not s.key then s.key, s.desc = neutralMode() and "better" or "total", true end
  return s
end

local f
local rows, headers = {}, {}

-- The columns shown (a column marked debugOnly only with /fl debug on).
local function shownColumns()
  local out = {}
  for _, c in ipairs(neutralMode() and NEUTRAL_COLUMNS or COLUMNS) do
    if not c.debugOnly or ns.db.settings.debug then out[#out + 1] = c end
  end
  return out
end

local function columnLayout(cols, width)
  local fixed = 0
  for _, c in ipairs(cols) do fixed = fixed + (c.width or 0) + 8 end
  local x, out = 4, {}
  for _, c in ipairs(cols) do
    local w = c.width or math.max(120, width - fixed - 4)
    out[c.key] = { x = x, w = w }
    x = x + w + 8
  end
  return out
end

function ns:BuildDeals(parent)
  f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()

  f.intro = T:Text(f, 11, T.dim)
  f.intro:SetPoint("TOPLEFT", 4, -2)
  f.intro:SetPoint("RIGHT", f, "RIGHT", -220, 0)
  f.intro:SetJustifyH("LEFT")
  f.intro:SetText("Лоты заметно ниже обычной минимальной цены — для покупки и перепродажи. Наведите на сделку, чтобы понять почему; "
    .. "клик — поиск на аукционе. Предметы дешевле цены торговца — в очереди покупок у аукциона.")

  f.thin = T:Check(f, function(self)
    ns.db.settings.dealShowThin = self:GetChecked()
    ns:RefreshDeals()
  end)
  f.thin:SetPoint("TOPRIGHT", -150, -4)
  f.thin.label:SetText("Показывать сомнительные сделки")
  f.thin:SetHitRectInsets(0, -(f.thin.label:GetStringWidth() + 8), 0, 0)   -- the name ticks it too
  f.thin:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    ns:TooltipAddLine("Показывать сомнительные сделки", 1, 1, 1)
    ns:TooltipAddLine("Также показывать сделки с малым числом дней цен или с прыгающими ценами, где обычная цена — лишь догадка.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  f.thin:HookScript("OnLeave", function() GameTooltip:Hide() end)
  -- Booty Bay: which way round.
  f.dir = T:Choice(f, { { value = "sell", label = "Там продаётся дороже" }, { value = "buy", label = "Там дешевле" } },
    function(v) ns.db.settings.neutralDir = v; ns:RefreshDeals() end)
  f.dir:SetPoint("TOPRIGHT", -4, -2)

  -- Deals, or the Booty Bay comparison.
  f.mode = T:Choice(f, { { value = "deals", label = "Сделки" }, { value = "neutral", label = "Бухта Боти" } }, function(v)
    ns.db.settings.dealsMode = v
    f.sf:SetVerticalScroll(0)
    ns:RefreshDeals()
  end)
  f.mode:SetPoint("TOPRIGHT", -4, -42)
  f.mode:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    ns:TooltipAddLine("Сделки или Бухта Боти", 1, 1, 1)
    ns:TooltipAddLine("Бухта Боти сравнивает нейтральный аукцион (Бухта Боти, Прибамбасск, Круговзор) с вашим, каждый после своей комиссии: там 15%. Цены берутся из проверок там и хранятся отдельно от ваших.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  f.mode:HookScript("OnLeave", function() GameTooltip:Hide() end)

  -- Filter: which kind of item, and a name search.
  f.kind = T:Choice(f, { { value = "all", label = "Все" }, { value = "goods", label = "Материалы" },
    { value = "gear", label = "Снаряжение" }, { value = "other", label = "Прочее" } }, function(value)
    ns.db.settings.dealKind = value
    ns:RefreshDeals()
  end)
  f.kind:SetPoint("TOPLEFT", 4, -42)
  f.kind:SetValue(ns.db.settings.dealKind or "all")
  f.search = T:EditBox(f, 180, "LEFT")
  f.search:SetPoint("LEFT", f.kind, "RIGHT", 12, 0)
  local hint = T:Text(f.search, 11, T.section)
  hint:SetPoint("LEFT", 6, 0)
  hint:SetText("Поиск по названию")
  -- Redraw once you pause typing, not on every letter (each redraw takes about 0.1 s).
  local pending
  f.search:SetScript("OnTextChanged", function(self)
    hint:SetShown(self:GetText() == "" and not self:HasFocus())
    if pending then pending:Cancel() end
    pending = C_Timer.NewTimer(0.3, function() pending = nil; ns:RefreshDeals() end)
  end)
  f.search:SetScript("OnEditFocusGained", function() hint:Hide() end)
  f.search:SetScript("OnEditFocusLost", function(self) hint:SetShown(self:GetText() == "") end)
  f.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

  f.header = CreateFrame("Frame", nil, f)
  f.header:SetPoint("TOPLEFT", 0, -70)
  f.header:SetPoint("TOPRIGHT", 0, -70)
  f.header:SetHeight(22)
  T:Fill(f.header, { 1, 1, 1, 0.05 })

  f.sf, f.content = T:Scroll(f)
  f.sf:SetPoint("TOPLEFT", 0, -94)
  f.sf:SetPoint("BOTTOMRIGHT", 0, 22)
  f.empty = T:Text(f.content, 12, T.dim)
  f.empty:SetPoint("TOPLEFT", 8, -8)
  f.empty:SetPoint("RIGHT", f.content, "RIGHT", -8, 0)
  f.empty:SetJustifyH("LEFT")

  f.summary = T:Text(f, 11, T.dim)
  f.summary:SetPoint("BOTTOMLEFT", 4, 2)
  f.summary:SetPoint("RIGHT", f, "RIGHT", -4, 0)
  f.summary:SetJustifyH("LEFT")
  f.summary:SetWordWrap(false)
  return f
end

local function getHeader(i)
  if not headers[i] then
    local h = CreateFrame("Button", nil, f.header)
    h.fs = T:Text(h, 11, T.dim)
    h.fs:SetAllPoints()
    h:SetScript("OnClick", function(self)
      local s = sortState()
      if s.key == self.key then s.desc = not s.desc else s.key, s.desc = self.key, self.key ~= "item" end
      ns:RefreshDeals()
    end)
    h:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      ns:TooltipAddLine(self.label or "", 1, 1, 1)
      if self.tip then ns:TooltipAddLine(self.tip, nil, nil, nil, true) end
      ns:TooltipAddLine("Клик — сортировка.", 0.7, 0.7, 0.7)
      GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    headers[i] = h
  end
  return headers[i]
end

local function neutralTip(self, d)
  local a = T.accent
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  ns:TooltipAddLine(ns.ItemName(d.id) or "?", 1, 1, 1)
  ns:TooltipAddLine("Учитывает один непроданный лот (залог теряется).", 0.7, 0.7, 0.7, true)
  ns:TooltipAddLine(" ")
  ns:TooltipAddLine("Бухта Боти (комиссия 15%)", a[1], a[2], a[3])
  ns:TooltipAddDoubleLine("  Минимум", ns.Money(d.there) .. " |cff999999" .. d.listedThere .. " в продаже|r", 0.7, 0.7, 0.7, 1, 1, 1)
  ns:TooltipAddDoubleLine("  Продажа там даёт", ns.Money(d.netThere), 0.7, 0.7, 0.7, 1, 1, 1)
  ns:TooltipAddDoubleLine("  Замечено", ns.Age(d.t), 0.7, 0.7, 0.7, 1, 1, 1)
  ns:TooltipAddLine(("Ваш аукцион (комиссия %g%%)"):format(ns:AHCut(false) * 100), a[1], a[2], a[3])
  ns:TooltipAddDoubleLine("  Минимум", ns.Money(d.here) .. " |cff999999" .. d.listedHere .. " в продаже|r", 0.7, 0.7, 0.7, 1, 1, 1)
  ns:TooltipAddDoubleLine("  Продажа здесь даёт", ns.Money(d.netHere), 0.7, 0.7, 0.7, 1, 1, 1)
  ns:TooltipAddLine(" ")
  if d.dir == "buy" then
    ns:TooltipAddLine(("Купить в Бухте Боти за %s, продать здесь за %s после комиссии: на %s больше за штуку."):format(
      ns.Money(d.there), ns.Money(d.netHere), ns.Money(d.buyProfit)), 0.5, 0.83, 0.61, true)
  else
    ns:TooltipAddLine(("Продажа в Бухте Боти даёт на %s больше за штуку."):format(ns.Money(d.gain)), 0.5, 0.83, 0.61, true)
  end
  ns:TooltipAddLine("Цены меняются: цены Бухты Боти свежи только на момент последнего визита.", 0.5, 0.5, 0.5, true)
  GameTooltip:Show()
end

local function showTip(self)
  local d = self.deal
  if not d then return end
  if d.neutral then return neutralTip(self, d) end
  local a = T.accent
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  ns:TooltipAddDoubleLine(ns.ItemName(d.id) or "?", ("%d%% ниже обычной"):format(math.floor(d.pct * 100 + 0.5)),
    1, 1, 1, 0.5, 0.83, 0.61)
  for _, e in ipairs(ns:DealExplain(d)) do
    if e.head then
      ns:TooltipAddLine(" ")
      ns:TooltipAddLine(e.head, a[1], a[2], a[3])
    elseif e.note then
      ns:TooltipAddLine(e.note, e.color[1], e.color[2], e.color[3], true)
    else
      ns:TooltipAddDoubleLine("  " .. e[1], e[2], 0.7, 0.7, 0.7, 1, 1, 1)
    end
  end
  ns:TooltipAddLine(" ")
  ns:TooltipAddLine("Клик — поиск на аукционе.", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function getRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", nil, f.content)
  r:SetHeight(ROW_HEIGHT)
  r.stripe = T:Fill(r, { 1, 1, 1, 0.025 })
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.10)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(14, 14)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.cells = {}
  r:SetScript("OnEnter", showTip)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r:SetScript("OnClick", function(self)
    local d = self.deal
    if not d then return end
    if d.neutral then
      if not ns:SearchAuctionHouse(d.id) then ns:Print("Откройте аукцион и щёлкните предмет, чтобы найти его.") end
    elseif ns:SearchAuctionHouse(d.id) then
      ns:Print(("%s: %d по %s или дешевле (обычно %s). Наведите на сделку для подробностей."):format(
        ns.ItemName(d.id) or "?", d.listed, ns.Money(d.limit), ns.Money(d.worth)))
    else
      ns:Print("Откройте аукцион и щёлкните сделку, чтобы найти её.")
    end
  end)
  rows[i] = r
  return r
end

local function cell(r, key)
  if not r.cells[key] then
    local fs = T:Text(r, 11)
    fs:SetWordWrap(false)
    r.cells[key] = fs
  end
  return r.cells[key]
end

local function show(d, key)
  if key == "item" then return ns.ItemName(d.id) or ("предмет " .. d.id) end
  if key == "there" or key == "here" then return ns.Money(d[key]) end
  if key == "better" then return "|cff7fd39c" .. ns.Money(d.better) .. "|r" end
  -- Ten times or more as "x12" (owner's screenshot: "44637..." was cut off).
  if key == "npct" then
    if d.npct >= 9 then return ("x%d"):format(math.floor(d.npct + 1)) end
    return ("%d%%"):format(math.floor(d.npct * 100 + 0.5))
  end
  if key == "lthere" then return tostring(d.listedThere) end
  if key == "lhere" then return tostring(d.listedHere) end
  if key == "price" or key == "worth" then return ns.Money(d[key]) end
  if key == "pct" then return ("%d%%"):format(math.floor(d.pct * 100 + 0.5)) end
  if key == "listed" then return tostring(d.listed) end
  if key == "sold" then
    -- The rating's first word (Fast, Steady, Slow, Rare, No); "?" until there are 3
    -- hours of scans to judge by.
    if not d.speed then return dim("?") end
    local short = SPEED_SHORT[d.speed.key] or d.speed.label
    return ("|cff%s%s|r"):format(d.speed.color, short)
  end
  if key == "each" or key == "total" then
    local v = d[key]
    return v > 0 and ("|cff7fd39c" .. ns.Money(v) .. "|r") or ("|cffee8597" .. ns.Money(0) .. "|r")
  end
  if key == "level" then
    local days = d.stats and d.stats.points
    return (ns.DEAL_LEVEL_TEXT[d.level] or d.level) .. (days and dim((" %dд"):format(days)) or dim(" TSM"))
  end
  return ""
end

local function sortValue(d, key)
  if key == "item" then return (ns.ItemName(d.id) or ""):lower() end
  if key == "level" then return LEVEL_ORDER[d.level] * 1000 + (d.stats and d.stats.points or 0) end
  if key == "sold" then return d.soldPerDay or -1 end
  if key == "lthere" then return d.listedThere or 0 end
  if key == "lhere" then return d.listedHere or 0 end
  return d[key] or 0
end

-- The Booty Bay rows: items at least NEUTRAL_MIN better one way round, after both cuts.
local function neutralList(dir, kind, search, thin)
  local realm = ns.RealmName() or "?"
  local list, filtered, newest, any, hidden = {}, 0, nil, false, 0
  for id in pairs(ns.db.prices[realm .. "|Neutral"] or {}) do
    any = true
    local c = ns:NeutralCompare(id)
    if c then
      newest = math.max(newest or 0, c.t or 0)
      local better = dir == "buy" and c.buyProfit or c.gain
      local base = dir == "buy" and c.there or c.netHere
      -- Selling there: enough listed there to trust its price; buying there to sell
      -- here: enough listed here.
      local listed = dir == "buy" and c.listedHere or c.listedThere
      if better > 0 and base > 0 and better / base >= NEUTRAL_MIN and not thin and listed < NEUTRAL_LISTED then
        hidden = hidden + 1
      elseif better > 0 and base > 0 and better / base >= NEUTRAL_MIN then
        if (kind == "all" or ns:ItemKind(id) == kind)
          and (search == "" or (ns.ItemName(id) or ""):lower():find(search, 1, true)) then
          c.id, c.neutral, c.dir, c.better, c.npct = id, true, dir, better, better / base
          list[#list + 1] = c
        else
          filtered = filtered + 1
        end
      end
    end
  end
  return list, filtered, newest, any, hidden
end

function ns:RefreshDeals()
  if not f or not f:IsShown() then return end
  local set = ns.db.settings
  local neutral = neutralMode()
  f.thin:SetChecked(set.dealShowThin)
  f.mode:SetValue(neutral and "neutral" or "deals")
  -- Booty Bay: "Show thin data too" sits left of the two direction buttons.
  f.thin:ClearAllPoints()
  f.thin:SetPoint("TOPRIGHT", neutral and -(math.max(f.mode:GetWidth(), 180) + 150) or -150, neutral and -44 or -4)
  f.dir:SetShown(neutral)
  f.dir:SetValue(set.neutralDir or "sell")
  f.intro:SetPoint("RIGHT", f, "RIGHT", neutral and -(math.max(f.dir:GetWidth(), 250) + 16) or -220, 0)
  f.intro:SetText(neutral
    and "Бухта Боти против вашего аукциона, каждый после своей комиссии (там 15%): предметы на 10% выгоднее для продажи там или дешевле для покупки. Наведите для цифр."
    or ("Лоты заметно ниже обычной минимальной цены — для покупки и перепродажи. Наведите на сделку, чтобы понять почему; "
      .. "клик — поиск на аукционе. Предметы дешевле цены торговца — в очереди покупок у аукциона."))

  -- Filter by kind and by name (owner, October 2: 193 deals is too many to read).
  local kind = set.dealKind or "all"
  local search = (f.search and f.search:GetText() or ""):lower()
  local list, hidden, filtered, newest = {}, 0, 0, nil
  local anyNeutral
  if neutral then
    list, filtered, newest, anyNeutral, hidden = neutralList(set.neutralDir or "sell", kind, search, set.dealShowThin)
  end
  for _, d in ipairs(neutral and {} or ns:FindDeals(MAX_AGE)) do
    if d.kind == "usual" then
      local keep = (kind == "all" or ns:ItemKind(d.id) == kind)
        and (search == "" or (ns.ItemName(d.id) or ""):lower():find(search, 1, true))
      if not keep then
        filtered = filtered + 1
      elseif ns:DealShown(d) then
        list[#list + 1] = d
      else
        hidden = hidden + 1
      end
      newest = math.max(newest or 0, d.t or 0)
    end
  end
  f.filtered = filtered

  local sort = sortState()
  table.sort(list, function(a, b)
    local va, vb = sortValue(a, sort.key), sortValue(b, sort.key)
    if va == vb then return (a.total or a.better or 0) > (b.total or b.better or 0) end
    if sort.desc then return va > vb end
    return va < vb
  end)

  -- Header
  local width = f:GetWidth() - 12
  local cols = shownColumns()
  local lay = columnLayout(cols, width)
  for i, c in ipairs(cols) do
    local h = getHeader(i)
    h.key, h.label, h.tip = c.key, c.label, c.tip
    h:ClearAllPoints()
    h:SetPoint("LEFT", f.header, "LEFT", lay[c.key].x, 0)
    h:SetSize(lay[c.key].w, 22)
    h.fs:SetJustifyH(c.right and "RIGHT" or "LEFT")
    local sorted = sort.key == c.key
    h.fs:SetText(c.label .. (sorted and (sort.desc and " v" or " ^") or ""))
    local col = sorted and { T.accent[1], T.accent[2], T.accent[3], 1 } or T.dim
    h.fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
    h:Show()
  end
  for i = #cols + 1, #headers do headers[i]:Hide() end

  -- Rows
  f.content:SetWidth(width)
  local n = math.min(#list, MAX_ROWS)
  for i = 1, n do
    local d, r = list[i], getRow(i)
    r.deal = d
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    r:SetWidth(width)
    r.stripe:SetShown(i % 2 == 0)
    local icon = ns:ItemIcon(d.id)
    for key, fs in pairs(r.cells) do fs:SetShown(lay[key] ~= nil) end
    for _, c in ipairs(cols) do
      local fs = cell(r, c.key)
      fs:Show()
      fs:ClearAllPoints()
      local x, w = lay[c.key].x, lay[c.key].w
      if c.key == "item" then
        r.icon:ClearAllPoints()
        r.icon:SetPoint("LEFT", r, "LEFT", x, 0)
        r.icon:SetTexture(icon)
        x, w = x + 18, w - 18
      end
      fs:SetPoint("LEFT", r, "LEFT", x, 0)
      fs:SetWidth(w)
      fs:SetJustifyH(c.right and "RIGHT" or "LEFT")
      fs:SetText(show(d, c.key))
    end
    r.icon:SetShown(icon ~= nil)
    r:Show()
  end
  for i = n + 1, #rows do rows[i]:Hide() end

  if neutral and #list == 0 and filtered == 0 then
    f.empty:SetText(anyNeutral
      and ((set.neutralDir == "buy") and "В Бухте Боти нет ничего хотя бы на 10% дешевле, чем продаётся здесь после комиссии."
        or "Ничто не продаётся в Бухте Боти хотя бы на 10% дороже, чем здесь, после обеих комиссий.")
      or "Цен Бухты Боти пока нет. Откройте аукцион в Бухте Боти, Прибамбасске или Круговзоре и запустите там полную проверку: эти цены хранятся отдельно.")
  elseif #list == 0 and filtered > 0 then
    f.empty:SetText(("Под фильтр ничего не подходит: скрыто %d %s. Нажмите «Все» или очистите поиск."):format(
      filtered, ns.Plural(filtered, "сделка", "сделки", "сделок")))
  elseif #list == 0 then
    f.empty:SetText(newest and "Сейчас нет сделок, проходящих проверки. Отметьте «Показывать сомнительные сделки», чтобы увидеть их."
      or "Сделок пока нет. Нужны цены за последний час (полная проверка или слежение за перепродажами) и хотя бы 4 дня проверок, "
      .. "чтобы знать обычную цену предмета (или установленный TSM).")
  end
  f.empty:SetShown(#list == 0)
  f.content:SetHeight(math.max(n * ROW_HEIGHT, 30))
  f.sf.UpdateScrollBar()

  if neutral then
    local parts = { ("%d %s"):format(#list, ns.Plural(#list, "предмет", "предмета", "предметов")) }
    if hidden > 0 then parts[#parts + 1] = ("%d скрыто (меньше %d лотов)"):format(hidden, NEUTRAL_LISTED) end
    if filtered > 0 then parts[#parts + 1] = ("%d отфильтровано"):format(filtered) end
    if newest then parts[#parts + 1] = "Цены Бухты Боти от " .. ns.Age(newest) end
    if #list > MAX_ROWS then parts[#parts + 1] = ("показаны первые %d"):format(MAX_ROWS) end
    f.summary:SetText(table.concat(parts, ", ") .. ". Хранятся отдельно от ваших; подсказки могут их показывать (Настройки, Подсказки).")
    return
  end
  local parts = { ("%d %s"):format(#list, ns.Plural(#list, "сделка", "сделки", "сделок")) }
  if hidden > 0 then
    parts[#parts + 1] = ("%d скрыто (мало данных, упавшие цены или прибыль ниже %s)"):format(hidden, ns.Money(set.dealUsualMin or 0))
  end
  if filtered > 0 then parts[#parts + 1] = ("%d отфильтровано"):format(filtered) end
  if newest then parts[#parts + 1] = "цены от " .. date("%H:%M", newest) end
  if #list > MAX_ROWS then parts[#parts + 1] = ("показаны первые %d"):format(MAX_ROWS) end
  f.summary:SetText(table.concat(parts, ", ") .. ". Правила: Настройки → Глобальные → Перепродажи и сделки.")
end

ns.RefreshDeals = ns.Timed("Вкладка «Сделки»", ns.RefreshDeals)
