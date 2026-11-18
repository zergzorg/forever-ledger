local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- Ledger tab: every transaction in one list (All), every sale and purchase (auction
-- house and vendor), a resale summary for items both bought and sold, other money in
-- and out, and every session (Sessions). Filter by time, character and item name; click a column heading to sort.
-- Select rows (click, Shift-click, Ctrl-click or drag) to see their total (owner,
-- October 3: "a single view for all transactions" and "select several to see the
-- gold in or out").
---------------------------------------------------------------------------
local DAY = 86400
local ROW_HEIGHT = 20
local MAX_ROWS = 500
local RANGES = {
  { key = "week", label = "Неделя", secs = 7 * DAY },
  { key = "month", label = "Месяц", secs = 30 * DAY },
  { key = "3months", label = "3 месяца", secs = 91 * DAY },
  { key = "year", label = "Год", secs = 365 * DAY },
  { key = "all", label = "Все" },
}
local SUBTABS = {
  { key = "all", label = "Все" },
  { key = "sales", label = "Продажи" },
  { key = "purchases", label = "Покупки" },
  -- By item: every item bought or sold, its totals and averages (Frank, November 16,
  -- TSM's item view). The key stays "resale" so saved sort choices carry over.
  { key = "resale", label = "По предметам" },
  { key = "other", label = "Прочее" },
  { key = "sessions", label = "Сессии" },   -- (owner, October 4: a home for every session)
}
local OTHER = {
  ahFee = "Сборы аукциона", ahDepositBack = "Возврат залогов", repair = "Ремонт", mailIn = "Почта получена", mailOut = "Почта отправлена",
  tradeIn = "Обмен получен", tradeOut = "Обмен отдан", loot = "Добыча", quest = "Задания",
  training = "Обучение", flight = "Полёты", otherIn = "Прочий доход", otherOut = "Прочие расходы",
}
local OTHER_IN = { ahDepositBack = true, mailIn = true, tradeIn = true, loot = true, quest = true, otherIn = true }

local COLUMNS = {
  all = {
    { key = "t", label = "Время", width = 96 },
    { key = "kind", label = "Тип", width = 118 },
    { key = "item", label = "Предмет" },
    { key = "qty", label = "Кол-во", width = 46, right = true },
    { key = "each", label = "Цена", width = 86, right = true },
    { key = "amount", label = "Сумма", width = 100, right = true },
    { key = "char", label = "Персонаж", width = 108 },
  },
  sales = {
    { key = "t", label = "Время", width = 96 },
    { key = "item", label = "Предмет" },
    { key = "qty", label = "Кол-во", width = 46, right = true },
    { key = "each", label = "Цена", width = 86, right = true },
    { key = "total", label = "Итого", width = 96, right = true },
    { key = "where", label = "Где", width = 60 },
    { key = "who", label = "Покупатель", width = 88 },
    { key = "char", label = "Персонаж", width = 108 },
  },
  purchases = {
    { key = "t", label = "Время", width = 96 },
    { key = "item", label = "Предмет" },
    { key = "qty", label = "Кол-во", width = 46, right = true },
    { key = "each", label = "Цена", width = 86, right = true },
    { key = "total", label = "Итого", width = 96, right = true },
    { key = "where", label = "Где", width = 60 },
    { key = "char", label = "Персонаж", width = 108 },
  },
  resale = {
    { key = "item", label = "Предмет" },
    { key = "bought", label = "Куплено", width = 56, right = true },
    { key = "avgBuy", label = "Ср. покупка", width = 86, right = true },
    { key = "sold", label = "Продано", width = 50, right = true },
    { key = "avgSell", label = "Ср. продажа", width = 86, right = true },
    { key = "avgProfit", label = "Прибыль с каждого", width = 86, right = true },
    { key = "profit", label = "Прибыль", width = 96, right = true },
  },
  sessions = {
    { key = "t", label = "Когда", width = 96 },
    { key = "item", label = "Сессия" },
    { key = "length", label = "Длительность", width = 76, right = true },
    { key = "total", label = "Золото", width = 96, right = true },
    { key = "loot", label = "Добыто", width = 90, right = true },
    { key = "rate", label = "В час", width = 90, right = true },
    { key = "char", label = "Персонаж", width = 108 },
  },
  other = {
    { key = "t", label = "День", width = 96 },
    { key = "item", label = "Тип" },
    { key = "total", label = "Сумма", width = 110, right = true },
    { key = "char", label = "Персонаж", width = 108 },
  },
}

local function dim(t) return "|cff888888" .. t .. "|r" end
local function money(v) return (v < 0 and "-" or "") .. ns.Money(math.abs(v)) end

local function settings()
  local s = ns.db.settings.ledger
  -- (The tab opens on All each time: UI.lua's setView.)
  s.tab = s.tab or "all"
  s.range = s.range or "month"
  s.char = s.char or "all"
  s.sort = s.sort or {}
  s.group = s.group or "all"
  s.rarity = s.rarity or "all"
  return s
end

-- Item IDs by name: auction sales are saved by name only (the mail names the item, not its
-- ID). From the names the game has given (saved in itemNames), rebuilt when that grows.
-- (Counted once per redraw, not per sale.)
local idByName, idByNameSize = {}, -1
local function nameIndex()
  local names = ns.db.itemNames or {}
  local count = 0
  for _ in pairs(names) do count = count + 1 end
  if count ~= idByNameSize then
    idByName, idByNameSize = {}, count
    for id, n in pairs(names) do
      if type(n) == "string" then idByName[n:lower()] = idByName[n:lower()] or id end
    end
  end
  return idByName
end

-- Rarity: the game's names and colors.
local RARITY = {
  [0] = { "Мусор", "9d9d9d" }, [1] = { "Обычный", "ffffff" }, [2] = { "Необычный", "1eff00" },
  [3] = { "Редкий", "0070dd" }, [4] = { "Эпический", "a335ee" }, [5] = { "Легендарный", "ff8000" },
}

local function charName(key)
  local c = ns.db.chars[key]
  return (c and c.name) or (key and key:match("^[^-]+")) or "?"
end

local function nameOf(id) return id and ns.ItemName(id) or "Неизвестный предмет" end

-- An item's icon from its ID or name (names only work once the game knows the item).
local function iconOf(idOrName)
  if not idOrName then return end
  if type(idOrName) == "number" then return ns:ItemIcon(idOrName) end
  local ok, _, _, _, _, _, _, _, _, _, icon = pcall(ns.GetItemInfo, idOrName)
  return ok and icon or nil
end

-- Seconds ahead of UTC, to turn a local day number back into a time for display.
local function utcOffset()
  local now = time()
  local utc = date("!*t", now)
  utc.isdst = date("*t", now).isdst
  return now - time(utc)
end

---------------------------------------------------------------------------
-- Records for each sub-tab
---------------------------------------------------------------------------
local GROUP_SECONDS = 60

-- Combine trades of the same item, at the same price each, in the same place, by the
-- same character, within a minute of each other (selling 10 oils one by one is one row).
local function groupSimilar(list)
  table.sort(list, function(a, b) return a.t < b.t end)
  local out, last = {}, nil
  for _, r in ipairs(list) do
    if last and not r.month and not last.month and r.item == last.item and r.where == last.where and r.char == last.char and r.who == last.who
      and r.each and last.each and math.abs(r.each - last.each) < 1 and r.t - last.t <= GROUP_SECONDS then
      last.qty = (last.qty or 1) + (r.qty or 1)
      last.total = last.total + r.total
      last.t = r.t
    else
      last = r
      out[#out + 1] = r
    end
  end
  return out
end

-- opts (optional): itemOK(id) keeps only some items (Sales, Purchases, By item: the Group
-- and Rarity choices); seen[id] = true collects every item before that, for the choices.
local function records(tab, from, charOK, match, opts)
  local out = {}
  opts = opts or {}
  local function keep(e) return (e.t or 0) >= from and charOK(e.c) end

  if tab == "sales" or tab == "purchases" or tab == "resale" or tab == "all" then
    local sales, buys = {}, {}
    local byName = nameIndex()
    for _, e in ipairs(ns.db.sales) do
      if keep(e) then
        local id = e.n and byName[e.n:lower()]
        sales[#sales + 1] = { t = e.t, id = id, item = e.n or "?", iconKey = id or e.n, qty = e.q, total = e.a,
          where = "Аукцион", who = e.b, char = e.c, kind = "Продажа на аукционе" }
      end
    end
    for _, e in ipairs(ns.db.purchases) do
      if keep(e) then
        -- No quantity means a non-commodity purchase, which is always one item.
        buys[#buys + 1] = { t = e.t, id = e.id, item = nameOf(e.id), iconKey = e.id, qty = e.q or 1, total = e.a,
          where = "Аукцион", char = e.c, kind = "Покупка на аукционе" }
      end
    end
    for _, e in ipairs(ns.db.vendorLog) do
      if keep(e) and e.id then
        local sold = e.s == "sell"
        local r = { t = e.t, id = e.id, item = nameOf(e.id), iconKey = e.id, qty = e.q, total = e.a, where = "Торговец",
          char = e.c, kind = sold and "Продано торговцу" or "Куплено у торговца" }
        if sold then sales[#sales + 1] = r else buys[#buys + 1] = r end
      end
    end
    -- Older than 30 days: one line per item and month (History.lua foldLedger).
    for _, m in ipairs(ns.db.ledgerMonths or {}) do
      if keep(m) then
        local auction = m.k == "sale" or m.k == "buy"
        local sold = m.k == "sale" or m.k == "vsell"
        local r = { t = m.t, month = true, id = m.id, item = m.id and nameOf(m.id) or m.n or "?", iconKey = m.id or m.n,
          qty = m.q, total = m.a, where = auction and "Аукцион" or "Торговец", char = m.c,
          kind = auction and (sold and "Продажи на аукционе" or "Покупки на аукционе") or (sold and "Продано торговцам" or "Куплено у торговцев") }
        if sold then sales[#sales + 1] = r else buys[#buys + 1] = r end
      end
    end
    for _, list in ipairs({ sales, buys }) do
      for _, r in ipairs(list) do
        r.each = r.qty and r.qty > 0 and r.total / r.qty or nil
        r.id = r.id or (r.item and byName[r.item:lower()])
        if opts.seen and r.id then opts.seen[r.id] = true end
      end
    end
    -- Group and rarity (an item whose ID isn't known can't be sorted, so it's left out).
    if opts.itemOK then
      local function only(list)
        local kept = {}
        for _, r in ipairs(list) do if r.id and opts.itemOK(r.id) then kept[#kept + 1] = r end end
        return kept
      end
      sales, buys = only(sales), only(buys)
    end

    if tab == "sales" then out = groupSimilar(sales) elseif tab == "purchases" then out = groupSimilar(buys)
    elseif tab == "all" then
      -- Everything, money in (+) and out (-); the other money is added below.
      for _, r in ipairs(groupSimilar(sales)) do r.amount = r.total; out[#out + 1] = r end
      for _, r in ipairs(groupSimilar(buys)) do r.amount = -r.total; out[#out + 1] = r end
    else
      -- By item: every item bought or sold, with how many, the averages, and (for items
      -- both bought and sold) the profit on the ones sold, each and in all. Auction sales
      -- count what reached you after the cut.
      local by = {}
      local function add(r, sold)
        local x = by[r.item]
        if not x then
          x = { item = r.item, id = r.id, iconKey = r.iconKey, bought = 0, boughtTotal = 0, sold = 0, soldTotal = 0,
            byItem = true, where = {}, first = r.t, last = r.t }
          by[r.item] = x
        end
        x.iconKey, x.id = x.iconKey or r.iconKey, x.id or r.id
        local q = r.qty or 1
        if sold then x.sold, x.soldTotal = x.sold + q, x.soldTotal + r.total
        else x.bought, x.boughtTotal = x.bought + q, x.boughtTotal + r.total end
        local w = (sold and "sold" or "bought") .. r.where
        x.where[w] = (x.where[w] or 0) + q
        x.first, x.last = math.min(x.first or 0, r.t or 0), math.max(x.last or 0, r.t or 0)
      end
      for _, r in ipairs(sales) do add(r, true) end
      for _, r in ipairs(buys) do add(r, false) end
      for _, x in pairs(by) do
        x.avgBuy = x.bought > 0 and x.boughtTotal / x.bought or nil
        x.avgSell = x.sold > 0 and x.soldTotal / x.sold or nil
        if x.avgBuy and x.avgSell then
          x.avgProfit = x.avgSell - x.avgBuy
          x.profit = x.avgProfit * math.min(x.bought, x.sold)
        end
        x.bought, x.sold = x.bought > 0 and x.bought or nil, x.sold > 0 and x.sold or nil
        x.t = x.last
        out[#out + 1] = x
      end
    end
  end
  if tab == "sessions" then
    -- Sessions (Sessions.lua; older shuffle sessions too). Ones saved before October 4
    -- don't know their character: they show under every character choice.
    for _, e in ipairs(ns.db.sessions or {}) do
      if (e.t or 0) >= from and (not e.c or charOK(e.c)) then
        local secs = e.secs or ((e.stop or e.t) - e.t)
        local gained = (e.earned or 0) - (e.spent or 0)
        out[#out + 1] = { t = e.t, session = e, item = e.kind == "general" and "Session" or (e.name or "Shuffle"),
          kind = "Session", length = secs, total = gained, amount = gained, loot = e.kind == "general" and (e.loot or 0) or nil,
          rate = ns.SessionRate and ns.SessionRate(e) or nil, char = e.c }
      end
    end
  end
  if tab == "other" or tab == "all" then
    -- Other money (repairs, mail, loot, quests...). Auction and vendor money isn't here:
    -- the lists above have it item by item. One by one with its time from the moment the
    -- character's otherLog began (within the last 30 days; Frank, November 14), as day
    -- totals before. On the day it began, what came before it is one line per kind
    -- ("(earlier)"): the day's total less what the log has (AN14: a flight taken that day
    -- was missing until the next day). A day whose entries the size limit removed, and
    -- every day before it, is day totals only (Codex review of 211a277: otherwise money
    -- went missing).
    local fromDay, offset = ns.LocalDay(from), utcOffset()
    local recentDay = ns.LocalDay(time() - (ns.LEDGER_LOG_DAYS or 30) * DAY) + 1
    local coverFrom, partial, since, cut = {}, {}, ns.db.otherLogSince or {}, ns.db.otherLogCut or {}
    for key, t in pairs(since) do
      local start = ns.LocalDay(t)
      local first = math.max(start, recentDay)
      if cut[key] then first = math.max(first, ns.LocalDay(cut[key]) + 1) end
      coverFrom[key] = first
      if first == start then partial[key] = start end   -- its first day: money from before the log too
    end
    local loggedOnStart = {}   -- [charKey][source] = copper logged on its first, partial day
    for _, e in ipairs(ns.db.otherLog or {}) do
      if partial[e.c] and ns.LocalDay(e.t) == partial[e.c] then
        local t = loggedOnStart[e.c] or {}
        loggedOnStart[e.c] = t
        t[e.s] = (t[e.s] or 0) + (e.a or 0)
      end
    end
    for key, days in pairs(ns.db.money) do
      if charOK(key) then
        for day, src in pairs(days) do
          local covered = coverFrom[key] and day >= coverFrom[key]
          if day >= fromDay and (not covered or day == partial[key]) then
            for s, amt in pairs(src) do
              if OTHER[s] then
                local t = day * DAY - offset + DAY / 2
                if covered then   -- the first day: only what came before the log
                  amt = amt - ((loggedOnStart[key] or {})[s] or 0)
                  t = since[key] - 1
                end
                if amt > 0 then
                  local signed = OTHER_IN[s] and amt or -amt
                  -- "(earlier)" goes with the kind in Other, and in All's wider Item column
                  -- (Frank's screenshot: "Auction house fees (earlier)" was cut off).
                  local earlier = covered and " (раньше)" or ""
                  out[#out + 1] = { t = t, day = true, other = true,
                    item = tab == "other" and (OTHER[s] .. earlier) or (covered and "сегодня раньше" or ""),
                    kind = OTHER[s] .. (tab == "other" and earlier or ""), total = signed, amount = signed, char = key }
                end
              end
            end
          end
        end
      end
    end
    for _, e in ipairs(ns.db.otherLog or {}) do
      local cover = coverFrom[e.c]
      if OTHER[e.s] and (e.t or 0) >= from and charOK(e.c) and cover and ns.LocalDay(e.t) >= cover then
        local signed = OTHER_IN[e.s] and e.a or -e.a
        out[#out + 1] = { t = e.t, other = true, item = tab == "other" and OTHER[e.s] or "", kind = OTHER[e.s],
          total = signed, amount = signed, char = e.c }
      end
    end
  end

  -- Search: the item's name, or (All) the type too. In quotes, that one item's name exactly
  -- (By item's double-click puts one there: Silk Cloth, not Bolt of Silk Cloth too).
  if match ~= "" then
    local exact = match:match('^"(.+)"$')
    local kept = {}
    for _, r in ipairs(out) do
      local hit
      if exact then hit = (r.item or ""):lower() == exact
      else hit = ((r.item or "") .. " " .. (r.kind or "")):lower():find(match, 1, true) end
      if hit then kept[#kept + 1] = r end
    end
    out = kept
  end
  return out
end
ns.LedgerRecords = records   -- (the tests check what the Ledger shows)


---------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------
local f
local rows, headers = {}, {}
local shown = {}          -- the records on screen, in order (for selecting by row)
local sel = {}            -- [record key] = true: the selected rows
local anchor, dragging    -- the row a Shift-click or drag starts from; a drag under way
local lastClick = { t = 0 }   -- (By item's double-click)

-- A key that stays the same for a record across redraws (selections survive them).
local function recKey(rec)
  return ("%s|%s|%s|%s|%s"):format(rec.t or 0, rec.item or "", rec.kind or "", rec.total or rec.profit or 0, rec.char or "")
end

local function columnLayout(cols, width)
  local fixed = 0
  for _, c in ipairs(cols) do fixed = fixed + (c.width or 0) + 8 end
  local x, out = 4, {}
  for _, c in ipairs(cols) do
    local w = c.width or math.max(140, width - fixed - 4)
    out[c.key] = { x = x, w = w }
    x = x + w + 8
  end
  return out
end

-- What a record adds to a total: money in positive, out negative (resale: its profit).
local function signedOf(rec, tab)
  if rec.amount then return rec.amount end
  if tab == "resale" then return rec.profit or 0 end
  if tab == "purchases" then return -(rec.total or 0) end
  return rec.total or 0
end

-- The bottom line: the selection's total when rows are selected, else the list's.
local function updateSummary()
  local s = settings()
  local n, inn, out = 0, 0, 0
  for _, rec in ipairs(shown) do
    if sel[recKey(rec)] then
      n = n + 1
      local v = signedOf(rec, s.tab)
      if v >= 0 then inn = inn + v else out = out - v end
    end
  end
  f.clear:SetShown(n > 0)
  if n > 0 then
    local net = inn - out
    f.summary:SetText(ns.LocalizeText("%sвыбрано: %d|r приход %s, расход %s, итог %s"):format(T:AccentCode(), n,
      "|cff7fd39c+" .. ns.Money(math.floor(inn + 0.5)) .. "|r", "|cffee8597-" .. ns.Money(math.floor(out + 0.5)) .. "|r",
      "|cff" .. (net >= 0 and "7fd39c+" or "ee8597-") .. ns.Money(math.floor(math.abs(net) + 0.5)) .. "|r"))
    return
  end
  if s.tab == "resale" then
    -- By item: what the items cost, what they brought, and the profit on those resold.
    local spent, earned, profit = 0, 0, 0
    for _, rec in ipairs(f.list or {}) do
      spent, earned, profit = spent + rec.boughtTotal, earned + rec.soldTotal, profit + (rec.profit or 0)
    end
    local extra = (f.list and #f.list > MAX_ROWS) and dim((" (показаны первые %d)"):format(MAX_ROWS)) or ""
    -- (Short: with "showing the first 500" the hint ran off the edge, Frank's screenshot.)
    f.summary:SetText(("%d %s: потрачено %s, получено %s, прибыль с перепродажи %s%s   %s"):format(f.list and #f.list or 0,
      ns.Plural(f.list and #f.list or 0, "предмет", "предмета", "предметов"),
      ns.Money(math.floor(spent + 0.5)), ns.Money(math.floor(earned + 0.5)), money(math.floor(profit + 0.5)), extra,
      dim("Двойной клик — все сделки")))
    return
  end
  local total = 0
  for _, rec in ipairs(f.list or {}) do total = total + signedOf(rec, s.tab) end
  local words = { all = "записей", sales = "продаж", purchases = "покупок", other = "записей", sessions = "сессий" }
  local label = (s.tab == "sessions" and "золото") or ((s.tab == "other" or s.tab == "all") and "итог") or "всего"
  local shownTotal = s.tab == "purchases" and -total or total
  local extra = (f.list and #f.list > MAX_ROWS) and dim((" (показаны первые %d)"):format(MAX_ROWS)) or ""
  f.summary:SetText(("%d %s, %s %s%s   %s"):format(f.list and #f.list or 0, words[s.tab] or "записей", label,
    money(math.floor(shownTotal + 0.5)), extra, dim("Клик, Shift+клик или перетаскивание строк — сумма.")))
end

-- Selected rows get the accent tint.
local function paint()
  for i, r in ipairs(rows) do
    local rec = shown[i]
    r.sel:SetShown(rec ~= nil and r:IsShown() and sel[recKey(rec)] or false)
  end
  updateSummary()
end

local function selectRange(a, b)
  if a > b then a, b = b, a end
  for i = a, b do if shown[i] then sel[recKey(shown[i])] = true end end
end

local function clearSelection()
  wipe(sel)
  anchor, dragging = nil, false
end

function ns:BuildLedger(parent)
  f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()

  -- A line under the sub-tabs, as on Shuffles (owner's test, October 4).
  local subLine = f:CreateTexture(nil, "BORDER")
  subLine:SetColorTexture(T.border[1], T.border[2], T.border[3], T.border[4])
  subLine:SetHeight(1)
  subLine:SetPoint("TOPLEFT", 0, -30)
  subLine:SetPoint("TOPRIGHT", 0, -30)
  f.subtabs = {}
  local prev
  for _, st in ipairs(SUBTABS) do
    local b = T:Tab(f, st.label, function() settings().tab = st.key; clearSelection(); ns:RefreshLedger() end)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 0, 0) else b:SetPoint("TOPLEFT", -6, 4) end
    f.subtabs[st.key] = b
    prev = b
  end
  f.range = T:Choice(f, (function()
    local o = {}
    for _, r in ipairs(RANGES) do o[#o + 1] = { value = r.key, label = r.label } end
    return o
  end)(), function(v) settings().range = v; clearSelection(); ns:RefreshLedger() end)
  f.range:SetPoint("TOPRIGHT", 0, 0)

  f.searchLabel = T:Text(f, 12, T.dim)
  f.searchLabel:SetPoint("TOPLEFT", 4, -40)
  f.searchLabel:SetText("Поиск")
  f.search = T:EditBox(f, 150, "LEFT")
  f.search:SetPoint("LEFT", f.searchLabel, "RIGHT", 8, 0)
  -- Redraw once typing pauses (code review, October 4: every key rebuilt every record).
  local typed = 0
  f.search:SetScript("OnTextChanged", function()
    typed = typed + 1
    local mine = typed
    C_Timer.After(0.25, function()
      if mine == typed then clearSelection(); ns:RefreshLedger() end
    end)
  end)
  f.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  f.charLabel = T:Text(f, 12, T.dim)
  f.charLabel:SetPoint("LEFT", f.search, "RIGHT", 18, 0)
  f.charLabel:SetText("Персонажи")

  f.header = CreateFrame("Frame", nil, f)
  f.header:SetPoint("TOPLEFT", 0, -66)
  f.header:SetPoint("TOPRIGHT", 0, -66)
  f.header:SetHeight(22)
  T:Fill(f.header, { 1, 1, 1, 0.05 })

  f.sf, f.content = T:Scroll(f)
  f.sf:SetPoint("TOPLEFT", 0, -90)
  f.sf:SetPoint("BOTTOMRIGHT", 0, 24)
  f.empty = T:Text(f.content, 12, T.dim)
  f.empty:SetPoint("TOPLEFT", 8, -8)
  f.empty:SetPoint("RIGHT", f.content, "RIGHT", -8, 0)
  f.empty:SetJustifyH("LEFT")

  f.summary = T:Text(f, 12)
  f.summary:SetPoint("BOTTOMLEFT", 4, 4)
  f.summary:SetJustifyH("LEFT")
  f.summary:SetWordWrap(false)
  -- Clear the selection (right-clicking a row does the same).
  f.clear = T:Button(f, "Сбросить выбор", 110, function() clearSelection(); paint() end, 20)
  f.clear:SetPoint("BOTTOMRIGHT", 0, 2)
  f.clear:Hide()
  f.summary:SetPoint("RIGHT", f.clear, "LEFT", -8, 0)
  return f
end

-- Which characters: a dropdown (Dashboard.lua's ns:CharacterOptions).
local function charChoice()
  if not f.chars then
    f.chars = T:Dropdown(f, 170, function(v) settings().char = v; clearSelection(); ns:RefreshLedger() end)
    f.chars:SetPoint("LEFT", f.charLabel, "RIGHT", 10, 0)
    -- Sales, Purchases and By item: which group (the Groups tab's) and rarity.
    f.group = T:Dropdown(f, 150, function(v) settings().group = v; clearSelection(); ns:RefreshLedger() end)
    f.group:SetPoint("LEFT", f.chars, "RIGHT", 10, 0)
    f.rarity = T:Dropdown(f, 120, function(v) settings().rarity = v; clearSelection(); ns:RefreshLedger() end)
    f.rarity:SetPoint("LEFT", f.group, "RIGHT", 6, 0)
  end
  f.chars:SetOptions(ns:CharacterOptions())
end

-- Each item's groups, worked out only while a group is chosen, and kept 10 minutes:
-- for every item listed it was too slow (Frank, November 16: "script ran too long" with
-- 1,190 items in By item).
local groupSets, groupSetsAt = {}, 0
local function groupSet(id)
  if GetTime() - groupSetsAt > 600 then wipe(groupSets); groupSetsAt = GetTime() end
  if not groupSets[id] then groupSets[id] = ns.ItemGroupSet and ns:ItemGroupSet(id) or {} end
  return groupSets[id]
end
local qualities = {}
local function qualityOf(id)
  local q = qualities[id]
  if q == nil then
    q = ns.ItemQuality and ns.ItemQuality(id) or false
    if q then qualities[id] = q end   -- (not cached while the game hasn't loaded the item)
  end
  return q or nil
end

-- The Group choices (every top group and yours, not checked against the items: that was
-- the slow part) and the Rarity choices the listed items have.
local function itemChoices(seen)
  local rar = {}
  for id in pairs(seen) do
    local q = qualityOf(id)
    if q then rar[q] = true end
  end
  local gopts, hasG = { { value = "all", label = "Любая группа" } }, { all = true }
  if ns.GroupTree then
    for _, g in ipairs(ns:GroupTree()) do
      if g.kind == "user" or (g.kind == "builtin" and g.depth <= 1) then
        gopts[#gopts + 1] = { value = g.id, label = (g.depth > 0 and "   " or "") .. g.name }
        hasG[g.id] = true
      end
    end
  end
  local ropts, hasR = { { value = "all", label = "Любая редкость" } }, { all = true }
  for q = 0, 5 do
    if rar[q] then
      ropts[#ropts + 1] = { value = tostring(q), label = "|cff" .. RARITY[q][2] .. RARITY[q][1] .. "|r" }
      hasR[tostring(q)] = true
    end
  end
  return gopts, ropts, hasG, hasR
end

local function getHeader(i)
  if not headers[i] then
    local h = CreateFrame("Button", nil, f.header)
    h.fs = T:Text(h, 11, T.dim)
    h.fs:SetAllPoints()
    h:SetScript("OnClick", function(self)
      local s = settings()
      local sort = s.sort[s.tab] or {}
      if sort.key == self.key then sort.desc = not sort.desc else sort.key, sort.desc = self.key, self.key ~= "item" and self.key ~= "kind" end
      s.sort[s.tab] = sort
      ns:RefreshLedger()
    end)
    headers[i] = h
  end
  return headers[i]
end

-- The text shown for one value.
local function show(rec, key)
  local v = rec[key]
  -- Other money has no item, count or price each: blank, not "-" or "?" (AN14).
  if rec.other and (key == "qty" or key == "each" or (key == "item" and (v or "") == "")) then return "" end
  if rec.session then
    if key == "length" then local m = math.floor((v or 0) / 60); return m < 1 and "< 1 мин" or (m < 60 and (m .. " мин") or ("%d ч %02d мин"):format(math.floor(m / 60), m % 60)) end
    if key == "total" or key == "rate" then
      if not v then return dim("-") end
      v = math.floor(v + 0.5)
      if v == 0 then return ns.Money(0) end
      return "|cff" .. (v > 0 and "7fd39c+" or "ee8597-") .. ns.Money(math.abs(v)) .. "|r"
    end
    if key == "loot" then return v and ns.Money(v) or dim("-") end
    if key == "char" and not v then return dim("-") end
  end
  if key == "t" then return dim(date((rec.month and "%m.%Y") or (rec.day and "%d.%m") or "%d.%m %H:%M", v)) end
  if key == "char" then return charName(v) end
  if rec.byItem and v == nil then return dim("-") end   -- (By item: never bought, or never sold)
  if key == "qty" or key == "bought" or key == "sold" then return v and tostring(v) or dim(rec.day and "" or "?") end
  if key == "each" or key == "avgBuy" or key == "avgSell" then return v and ns.Money(math.floor(v + 0.5)) or dim(rec.day and "" or "?") end
  if key == "total" then return (rec.day or rec.other) and ("|cff" .. (v >= 0 and "7fd39c" or "ee8597") .. money(v) .. "|r") or ns.Money(v) end
  if key == "amount" or key == "profit" or key == "avgProfit" then
    return "|cff" .. (v >= 0 and "7fd39c+" or "ee8597-") .. ns.Money(math.floor(math.abs(v) + 0.5)) .. "|r"
  end
  if key == "who" then return v or dim("-") end
  if key == "item" and v == "" then return dim("-") end
  return v or ""
end

-- Hover: the item's own tooltip where we know it, then the row in full.
local function rowTooltip(r)
  local rec = shown[r.index]
  if not rec then return end
  local session = rec.session
  -- Beside the window, not at the cursor: at the cursor it could run off the screen's
  -- edge (owner's test, October 3).
  GameTooltip:SetOwner(r, "ANCHOR_NONE")
  GameTooltip:ClearAllPoints()
  local scale, right = f:GetEffectiveScale(), f:GetRight() or 0
  if right * scale + 320 < (GetScreenWidth() * UIParent:GetEffectiveScale()) then
    GameTooltip:SetPoint("TOPLEFT", r, "TOPLEFT", f:GetWidth() + 16, 0)
  else
    GameTooltip:SetPoint("TOPRIGHT", r, "TOPLEFT", -16, 0)
  end
  if session then
    -- A session: where its gold came from and what it looted best.
    local function line(a, b, r, g, bl) ns:TooltipAddDoubleLine(a, b, 0.7, 0.7, 0.7, r or 1, g or 1, bl or 1) end
    ns:TooltipAddLine(("%s, %s"):format(rec.item, date("%d.%m %H:%M", rec.t or 0)), 1, 1, 1)
    line("Длительность", show(rec, "length"))
    local function gold(v, r, g, bl) if (v or 0) > 0 then return ns.Money(v), r, g, bl end return ns.Money(0), 0.6, 0.6, 0.6 end
    if session.earned then line("Приход", gold(session.earned, 0.5, 0.83, 0.61)) end
    if session.spent then line("Расход", gold(session.spent, 0.93, 0.52, 0.59)) end
    if rec.rate then line("Золото в час", show(rec, "rate")) end
    if rec.loot then line("Добыто, примерно на", ns.Money(rec.loot)) end
    if session.runs and session.runs > 0 then line(session.kind == "general" and "Забеги по подземельям" or "Забеги", tostring(session.runs)) end
    local by = {}
    for src, v in pairs(session.money or {}) do if v ~= 0 then by[#by + 1] = { src, v } end end
    table.sort(by, function(a, b) return math.abs(a[2]) > math.abs(b[2]) end)
    if #by > 0 then
      ns:TooltipAddLine(" ")
      ns:TooltipAddLine("Золото по источникам", 1, 0.82, 0)
      for k = 1, math.min(6, #by) do
        local v = by[k][2]
        line("  " .. ((ns.MONEY_LABELS and ns.MONEY_LABELS[by[k][1]]) or by[k][1]), (v > 0 and "+" or "-") .. ns.Money(math.abs(v)),
          v > 0 and 0.5 or 0.93, v > 0 and 0.83 or 0.52, v > 0 and 0.61 or 0.59)
      end
    end
    if session.top and #session.top > 0 then
      ns:TooltipAddLine(" ")
      ns:TooltipAddLine("Лучшая добыча", 1, 0.82, 0)
      for _, it in ipairs(session.top) do
        line(("  %d x %s"):format(it[2] or 1, nameOf(it[1])), it[3] and ns.Money(it[3]) or "")
      end
    end
    if #by == 0 and not (session.top and #session.top > 0) then
      ns:TooltipAddLine(" ")
      ns:TooltipAddLine((session.money or session.top) and "В ней ничего не заработано, не потрачено и не добыто."
        or "Для этой сессии разбивка не сохранена (у старых остались только итоги).", 0.6, 0.6, 0.6, true)
    end
    if rec.char then line("Персонаж", charName(rec.char)) end
    ns:TooltipAddLine("Клик — выбрать; Shift+клик или протяните мышью, чтобы сложить несколько.", 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
    return
  end
  if rec.id then GameTooltip:SetItemByID(rec.id); ns:TooltipAddLine(" ")
  else ns:TooltipAddLine(rec.item ~= "" and rec.item or (rec.kind or "?"), 1, 1, 1) end
  local function line(a, b) if b then ns:TooltipAddDoubleLine(a, b, 0.7, 0.7, 0.7, 1, 1, 1) end end
  if rec.byItem then
    -- By item: the totals, and where (auction house or vendor) each side was.
    local function split(side)
      local a, v = rec.where[side .. "Auction"], rec.where[side .. "Vendor"]
      if a and v then return (" (%d на аукционе, %d у торговца)"):format(a, v) end
      return v and " (у торговца)" or " (на аукционе)"
    end
    if rec.bought then line("Куплено", ("%d за %s%s"):format(rec.bought, ns.Money(math.floor(rec.boughtTotal + 0.5)), split("bought"))) end
    if rec.sold then line("Продано", ("%d за %s%s"):format(rec.sold, ns.Money(math.floor(rec.soldTotal + 0.5)), split("sold"))) end
    if rec.profit then
      line("Прибыль с каждого", show(rec, "avgProfit"))
      local n = math.min(rec.bought, rec.sold)
      line(("Прибыль с %d %s"):format(n, ns.Plural(n, "перепроданного", "перепроданных", "перепроданных")), show(rec, "profit"))
    end
    line("Первая и последняя", date("%d.%m", rec.first or 0) .. " - " .. date("%d.%m", rec.last or 0))
    if rec.where.soldAuction then ns:TooltipAddLine("Продажи на аукционе считаются по тому, что вы получили после комиссии.", 0.5, 0.5, 0.5, true) end
    ns:TooltipAddLine("Двойной клик — все сделки с этим предметом. Клик, Shift+клик или протягивание — сложить предметы.", 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
    return
  end
  line("Когда", date((rec.month and "%m.%Y, итог за месяц") or (rec.day and "%d.%m, итог за день") or "%d.%m %H:%M", rec.t or 0))
  line("Тип", rec.kind)
  if rec.qty and rec.each then line("Количество", ("%d x %s"):format(rec.qty, ns.Money(math.floor(rec.each + 0.5)))) end
  if rec.amount or rec.total then line("Сумма", show(rec, rec.amount and "amount" or "всего")) end
  if rec.profit then line("Прибыль", show(rec, "прибыль")) end
  line("Покупатель", rec.who)
  if rec.char then line("Персонаж", charName(rec.char)) end
  ns:TooltipAddLine("Клик — выбрать; Shift+клик или перетаскивание — несколько, Ctrl+клик — добавить. Правый клик — сбросить.", 0.5, 0.5, 0.5, true)
  GameTooltip:Show()
end

local function getRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Frame", nil, f.content)
  r:SetHeight(ROW_HEIGHT)
  r:EnableMouse(true)
  r.stripe = T:Fill(r, { 1, 1, 1, 0.025 })
  r.sel = r:CreateTexture(nil, "BACKGROUND", nil, 1)
  r.sel:SetAllPoints()
  r.sel:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.2)
  r.sel:Hide()
  r.hl = r:CreateTexture(nil, "HIGHLIGHT")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 1, 1, 0.05)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(14, 14)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.cells = {}
  -- Selecting: click one (again to unselect), Shift-click a range, Ctrl-click to add or
  -- take one, or press and drag across rows. Right-click clears.
  r:SetScript("OnMouseDown", function(self, button)
    local rec = shown[self.index]
    if not rec then return end
    if button == "RightButton" then clearSelection(); paint(); return end
    -- By item: a double-click shows every trade of that item, with its time, in All.
    local now = GetTime()
    if rec.byItem and lastClick.index == self.index and now - lastClick.t < 0.4 then
      lastClick.index = nil
      settings().tab = "all"
      clearSelection()
      f.search:SetText('"' .. rec.item .. '"')
      ns:RefreshLedger()
      return
    end
    lastClick.index, lastClick.t = self.index, now
    local key = recKey(rec)
    if IsShiftKeyDown() and anchor then
      wipe(sel)
      selectRange(anchor, self.index)
    elseif IsControlKeyDown() then
      sel[key] = not sel[key] or nil
      anchor = self.index
    else
      local only = sel[key] and next(sel, next(sel)) == nil
      wipe(sel)
      if not only then sel[key] = true end
      anchor, dragging = self.index, true
    end
    paint()
  end)
  r:SetScript("OnMouseUp", function() dragging = false end)
  r:SetScript("OnEnter", function(self)
    if dragging and anchor and IsMouseButtonDown("LeftButton") then
      wipe(sel)
      selectRange(anchor, self.index)
      paint()
      return
    end
    dragging = false
    rowTooltip(self)
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
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

-- What each view says when it's empty, and how to fill it.
local EMPTY = {
  all = "По этим фильтрам пока ничего нет. Продажи на аукционе записываются, когда вы забираете золото из почты; покупки, сделки с торговцами и прочее — по мере событий.",
  sales = "По этим фильтрам продаж пока нет. Продажи на аукционе записываются, когда вы забираете золото из почты; продажи торговцам — при продаже.",
  purchases = "По этим фильтрам покупок пока нет. Покупки на аукционе и у торговцев записываются при покупке.",
  resale = "По этим фильтрам пока ничего не куплено и не продано. Каждый купленный или проданный предмет получает здесь строку: сколько, средние цены и прибыль, когда есть и покупки, и продажи.",
  other = "По этим фильтрам прочих денег пока нет: ремонт, почта, обмен, добыча, задания, обучение и полёты показываются здесь каждое со своим временем (старше 30 дней — по дням).",
  sessions = "По этим фильтрам сессий пока нет. Начните её через /fl session start или Ctrl+клик по кнопке миникарты; она появится здесь, когда вы её остановите.",
}

function ns:RefreshLedger()
  if not f or not f:IsShown() then return end
  local s = settings()
  if not ns:IsCharChoice(s.char) then s.char = "all" end
  if not COLUMNS[s.tab] then s.tab = "all" end
  for key, b in pairs(f.subtabs) do b:SetSelected(key == s.tab) end
  f.range:SetValue(s.range)
  -- Sessions: no search (the other filters do the job; owner's test, October 4), so
  -- Characters moves to the left.
  local noSearch = s.tab == "sessions"
  f.searchLabel:SetShown(not noSearch)
  f.search:SetShown(not noSearch)
  if noSearch and f.search:GetText() ~= "" then f.search:SetText("") end
  f.charLabel:ClearAllPoints()
  if noSearch then f.charLabel:SetPoint("TOPLEFT", 4, -40) else f.charLabel:SetPoint("LEFT", f.search, "RIGHT", 18, 0) end
  charChoice()
  f.chars:SetValue(s.char)

  -- Records for the filters
  local from = 0
  for _, r in ipairs(RANGES) do if r.key == s.range and r.secs then from = time() - r.secs end end
  -- All: this ruleset and faction (Dashboard.lua CharacterOptions).
  local function charOK(c) return ns:CharChoiceHas(s.char, c) end
  local match = (f.search:GetText() or ""):lower()
  local itemTab = s.tab == "sales" or s.tab == "purchases" or s.tab == "resale"
  f.group:SetShown(itemTab)
  f.rarity:SetShown(itemTab)
  local list
  if itemTab then
    local function itemOK(id)
      -- Rarity first: it is quick, and an item it rules out needs no group look-up.
      return (s.rarity == "all" or qualityOf(id) == tonumber(s.rarity))
        and (s.group == "all" or groupSet(id)[s.group] ~= nil)
    end
    local function run()
      local seen = {}
      local filtered = s.group ~= "all" or s.rarity ~= "all"
      return records(s.tab, from, charOK, match, { seen = seen, itemOK = filtered and itemOK or nil }), seen
    end
    local seen
    list, seen = run()
    local gopts, ropts, hasG, hasR = itemChoices(seen)
    -- A choice none of these items has any more (another range or character): Any.
    if not hasG[s.group] or not hasR[s.rarity] then
      if not hasG[s.group] then s.group = "all" end
      if not hasR[s.rarity] then s.rarity = "all" end
      list = run()
    end
    f.group:SetOptions(gopts)
    f.group:SetValue(s.group)
    f.rarity:SetOptions(ropts)
    f.rarity:SetValue(s.rarity)
  else
    list = records(s.tab, from, charOK, match)
  end
  f.list = list

  local cols = COLUMNS[s.tab]
  local sort = s.sort[s.tab] or { key = s.tab == "resale" and "прибыль" or "t", desc = true }
  table.sort(list, function(a, b)
    local va, vb = a[sort.key], b[sort.key]
    if type(va) == "string" then va = va:lower() end
    if type(vb) == "string" then vb = vb:lower() end
    if va == vb or va == nil or vb == nil then
      if va == nil and vb ~= nil then return false end
      if vb == nil and va ~= nil then return true end
      return (a.t or 0) > (b.t or 0)
    end
    if sort.desc then return va > vb end
    return va < vb
  end)

  -- Header
  -- Clear of the scroll bar (long names ran under it and off the edge: owner's test,
  -- October 4).
  local width = f:GetWidth() - 20
  local lay = columnLayout(cols, width)
  for i, c in ipairs(cols) do
    local h = getHeader(i)
    h.key = c.key
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
  wipe(shown)
  for i = 1, n do
    local rec, r = list[i], getRow(i)
    shown[i] = rec
    r.index = i
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    r:SetWidth(width)
    r.stripe:SetShown(i % 2 == 0)
    for key, fs in pairs(r.cells) do fs:SetShown(lay[key] ~= nil) end
    -- The icon, looked up for shown rows only (for every record it was part of the "script
    -- ran too long", Frank, November 16).
    if rec.icon == nil then rec.icon = rec.iconKey and iconOf(rec.iconKey) or false end
    for _, c in ipairs(cols) do
      local fs = cell(r, c.key)
      fs:ClearAllPoints()
      local x, w = lay[c.key].x, lay[c.key].w
      if c.key == "item" and rec.icon then
        r.icon:ClearAllPoints()
        r.icon:SetPoint("LEFT", r, "LEFT", x, 0)
        r.icon:SetTexture(rec.icon)
        x, w = x + 18, w - 18
      end
      fs:SetPoint("LEFT", r, "LEFT", x, 0)
      fs:SetWidth(w)
      fs:SetJustifyH(c.right and "RIGHT" or "LEFT")
      fs:SetText(show(rec, c.key))
      fs:Show()
    end
    r.icon:SetShown(lay.item ~= nil and rec.icon and true or false)
    r:Show()
  end
  for i = n + 1, #rows do rows[i]:Hide() end
  local narrowed = itemTab and (s.group ~= "all" or s.rarity ~= "all")
  f.empty:SetText((EMPTY[s.tab] or EMPTY.all) .. (narrowed and "\n\nФильтр группы или редкости что-то скрывает: выберите «Любая группа» и «Любая редкость», чтобы увидеть всё." or ""))
  f.empty:SetShown(#list == 0)
  f.content:SetHeight(math.max(n * ROW_HEIGHT, 30))
  f.sf.UpdateScrollBar()
  paint()
end

ns.RefreshLedger = ns.Timed("Ledger tab", ns.RefreshLedger)

-- Open the Ledger on one of its sub-tabs (the Dashboard's "See all sessions").
function ns:OpenLedgerTab(tab)
  ns:ShowTab("ledger")   -- (opening resets it to All)
  settings().tab = tab
  clearSelection()
  ns:RefreshLedger()
end