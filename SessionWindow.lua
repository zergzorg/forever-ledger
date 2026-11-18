local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- The session window (Frank, AN29, November 17: the small tracker stays small, and More
-- opens "a larger overall window with all of the sections and features of other trackers";
-- he picked a pace graph, a sortable loot table and past sessions). More, the arrow on the
-- tracker, opens and closes it (settings.sessionFull); it redraws with the tracker every
-- second while a session runs. Where it was dragged: settings.sessionWinPos.
--
-- liveSession.pace = { { seconds played, gold + loot then }, ... }: a point every PACE_STEP
-- seconds of play (not while paused), thinned to every other point past PACE_MAX.
---------------------------------------------------------------------------
local W, H = 580, 470
local PACE_STEP, PACE_MAX = 30, 240
local ROW = 16
local GOLD_ROWS, PAST_ROWS = 6, 6

local function fmt() return ns.SessionFormat or {} end

-- A point on the pace graph when it's due; true when one was added (tested).
function ns.SessionPaceSample(s, st)
  if not (s and st) or s.paused then return end
  s.pace = s.pace or {}
  local last = s.pace[#s.pace]
  if last and st.secs - last[1] < PACE_STEP then return end
  s.pace[#s.pace + 1] = { st.secs, math.floor(st.gained + st.loot + 0.5) }
  if #s.pace > PACE_MAX then
    local thin = {}
    for i, p in ipairs(s.pace) do
      if i % 2 == 1 or i == #s.pace then thin[#thin + 1] = p end
    end
    s.pace = thin
  end
  return true
end

-- The loot table (tested): rows sorted by key ("name", "n", "each" or "value"; asc flips
-- it), gray items apart (for the vendor) with their total, and the best drop: the item
-- worth most each, gray items only when there's nothing else.
local SORTS = {
  name = function(a, b) return a.name < b.name end,
  n = function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end,
  each = function(a, b) if a.each ~= b.each then return a.each > b.each end return a.name < b.name end,
  value = function(a, b) if a.value ~= b.value then return a.value > b.value end return a.name < b.name end,
}
function ns.SessionLootRows(items, key, asc, quality)
  quality = quality or ns.ItemQuality
  local rows, grays, grayValue, best, bestGray = {}, {}, 0, nil, nil
  for _, it in ipairs(items or {}) do
    local r = { id = it.id, n = it.n, value = it.value, each = it.value / math.max(1, it.n), name = ns.ItemName(it.id) or "?" }
    if quality and quality(it.id) == 0 then
      grays[#grays + 1] = r
      grayValue = grayValue + r.value
      if not bestGray or r.each > bestGray.each then bestGray = r end
    else
      rows[#rows + 1] = r
      if not best or r.each > best.each then best = r end
    end
  end
  local cmp = SORTS[key] or SORTS.value
  local sorter = asc and function(a, b) return cmp(b, a) end or cmp
  table.sort(rows, sorter)
  table.sort(grays, sorter)
  return { rows = rows, grays = grays, grayValue = grayValue, best = best or bestGray }
end

-- Finished sessions, newest first (tested): { t, secs, gained, loot, rate, c, best }, at most n.
function ns.SessionPastRows(n)
  local out, list, top = {}, ns.db.sessions or {}, nil
  for i = #list, 1, -1 do
    local e = list[i]
    if e.kind == "general" then
      local r = { t = e.t, secs = e.secs or ((e.stop or e.t or 0) - (e.t or 0)), gained = (e.earned or 0) - (e.spent or 0),
        loot = e.loot or 0, rate = ns.SessionRate(e), c = e.c }
      out[#out + 1] = r
      if r.rate and (not top or r.rate > top.rate) then top = r end
      if #out >= n then break end
    end
  end
  if top and #out > 1 then top.best = true end
  return out
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local win

-- Frames made as they're needed and reused: pool(parent, make) gives next() and done().
local function pool(make)
  local list, used = {}, 0
  local function nextOne()
    used = used + 1
    local o = list[used]
    if not o then o = make(); list[used] = o end
    o:Show()
    return o
  end
  local function done()
    for i = used + 1, #list do list[i]:Hide() end
    used = 0
  end
  return nextOne, done
end

local function itemHover(r)
  r:SetScript("OnEnter", function(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) else GameTooltip:SetHyperlink("item:" .. self.itemID) end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A tile: a small label and a big number, with a line under it.
local function tile(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetHeight(50)
  T:Fill(t, { 1, 1, 1, 0.04 })
  t.label = T:Text(t, 10, T.dim)
  t.label:SetPoint("TOPLEFT", 8, -6)
  t.value = T:Text(t, 15, T.text)
  t.value:SetPoint("TOPLEFT", 8, -18)
  t.note = T:Text(t, 9, T.dim)
  t.note:SetPoint("BOTTOMRIGHT", -6, 4)
  t.note:SetJustifyH("RIGHT")
  return t
end

-- A plain two-sided line for the right column.
local function line(parent)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(ROW)
  r.left = T:Text(r, 11)
  r.left:SetPoint("LEFT", 0, 0)
  r.left:SetJustifyH("LEFT")
  r.left:SetWordWrap(false)
  r.right = T:Text(r, 11)
  r.right:SetPoint("RIGHT", 0, 0)
  r.right:SetJustifyH("RIGHT")
  r.left:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
  r.hl = T:Fill(r, { 0.5, 0.83, 0.61, 0.15 }, "BACKGROUND")
  return r
end

local LOOT_COLS = {
  { key = "name", label = "Предмет", x = 0 },
  { key = "n", label = "Кол-во", w = 44 },
  { key = "each", label = "За штуку", w = 74 },
  { key = "value", label = "Всего", w = 80 },
}

local function sortState()
  local s = ns.db.settings
  s.sessionSort = type(s.sessionSort) == "table" and s.sessionSort or { key = "value" }
  return s.sessionSort
end

local function build()
  local f = CreateFrame("Frame", "ForeverLedgerSessionWindow", UIParent)
  f:SetSize(W, H)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  T:Fill(f, { T.bg[1], T.bg[2], T.bg[3], 0.94 })
  T:Border(f, T.theme.frame and { T.theme.frame[1], T.theme.frame[2], T.theme.frame[3], 0.8 } or { 1, 1, 1, 0.12 })
  if T.DecorateWindow then T:DecorateWindow(f) end
  ns.scaledWindows = ns.scaledWindows or {}
  table.insert(ns.scaledWindows, f)
  f:SetScale(((ns.db and ns.db.settings.uiScale) or 100) / 100)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    ns.db.settings.sessionWinPos = { point, rel, x, y }
  end)
  local pos = ns.db.settings.sessionWinPos
  if pos then
    f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  elseif _G.ForeverLedgerSessionTracker then
    f:SetPoint("TOP", _G.ForeverLedgerSessionTracker, "BOTTOM", 0, -6)
  else
    f:SetPoint("CENTER")
  end

  -- Title, time, and Close.
  f.title = T:Text(f, 13)
  f.title:SetPoint("TOPLEFT", 12, -10)
  T:StyleHeading(f.title, "Сессия")
  f.time = T:Text(f, 11, T.dim)
  f.time:SetPoint("LEFT", f.title, "RIGHT", 8, 0)
  f.close = T:Button(f, "Закрыть", 54, function() ns:ToggleSessionWindow(false) end, 18)
  f.close:SetPoint("TOPRIGHT", -8, -7)
  f.hint = T:Text(f, 10, T.dim)
  f.hint:SetPoint("RIGHT", f.close, "LEFT", -10, 0)
  f.hint:SetText("Перетащите, чтобы переместить")

  -- Four tiles: gold an hour, gold, loot, against your usual.
  f.tiles = {}
  local tw = (W - 24 - 3 * 8) / 4
  for i = 1, 4 do
    local t = tile(f)
    t:SetWidth(tw)
    t:SetPoint("TOPLEFT", 12 + (i - 1) * (tw + 8), -34)
    f.tiles[i] = t
  end

  -- The pace graph: gold and loot so far, over the time played; your usual pace dimmed.
  local g = CreateFrame("Frame", nil, f)
  g:SetPoint("TOPLEFT", 12, -92)
  g:SetPoint("TOPRIGHT", -12, -92)
  g:SetHeight(106)
  T:Fill(g, { 0, 0, 0, 0.18 })
  g.top = T:Text(g, 9, T.dim)
  g.top:SetPoint("TOPLEFT", 4, -3)
  g.zero = T:Text(g, 9, T.dim)
  g.zero:SetPoint("BOTTOMLEFT", 4, 3)
  g.right = T:Text(g, 9, T.dim)
  g.right:SetPoint("BOTTOMRIGHT", -4, 3)
  g.legend = T:Text(g, 9, T.dim)
  g.legend:SetPoint("TOPRIGHT", -4, -3)
  g.empty = T:Text(g, 11, T.dim)
  g.empty:SetPoint("CENTER")
  g.empty:SetText("График начнётся после первых полминуты.")
  g.nextLine, g.doneLines = pool(function()
    local l = g.CreateLine and g:CreateLine(nil, "OVERLAY")
    if l then l:SetThickness(2) end
    return l or g:CreateTexture(nil, "OVERLAY")
  end)
  g.zeroLine = g:CreateTexture(nil, "BORDER")
  g.zeroLine:SetHeight(1)
  g.zeroLine:SetColorTexture(1, 1, 1, 0.08)
  f.graph = g

  -- Bottom left: the loot table.
  local L = CreateFrame("Frame", nil, f)
  L:SetPoint("TOPLEFT", 12, -208)
  L:SetPoint("BOTTOMLEFT", 12, 10)
  L:SetWidth(352)
  f.lootBox = L
  L.head = T:Text(L, 12)
  L.head:SetPoint("TOPLEFT", 0, 0)
  L.total = T:Text(L, 11)
  L.total:SetPoint("TOPRIGHT", 0, 0)
  L.best = CreateFrame("Frame", nil, L)
  L.best:SetPoint("TOPLEFT", 0, -16)
  L.best:SetPoint("TOPRIGHT", 0, -16)
  L.best:SetHeight(ROW)
  L.best.text = T:Text(L.best, 10, T.dim)
  L.best.text:SetPoint("LEFT")
  L.best.text:SetPoint("RIGHT")
  L.best.text:SetJustifyH("LEFT")
  L.best.text:SetWordWrap(false)
  L.best:EnableMouse(true)
  itemHover(L.best)
  -- Column headings: click to sort, again to flip.
  L.cols = {}
  local right = 0
  for i = #LOOT_COLS, 1, -1 do
    local c = LOOT_COLS[i]
    local b = CreateFrame("Button", nil, L)
    b:SetHeight(16)
    if c.w then
      b:SetWidth(c.w)
      b:SetPoint("TOPRIGHT", L, "TOPRIGHT", -right - 12, -34)
      right = right + c.w
    else
      b:SetPoint("TOPLEFT", 20, -34)
      b:SetPoint("RIGHT", L, "RIGHT", -right - 12, 0)
    end
    b.text = T:Text(b, 10, T.dim)
    b.text:SetPoint(c.w and "RIGHT" or "LEFT")
    b:SetScript("OnClick", function()
      local st = sortState()
      if st.key == c.key then st.asc = not st.asc or nil else st.key, st.asc = c.key, nil end
      if ns.RedrawSessionWindow then ns.RedrawSessionWindow() end
    end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      ns:TooltipAddLine(("Сортировать: %s"):format(c.label:lower()), 1, 1, 1)
      ns:TooltipAddLine("Клик ещё раз — в обратном порядке.", 0.7, 0.7, 0.7)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.col = c
    L.cols[i] = b
  end
  local sf, content = T:Scroll(L)
  sf:SetPoint("TOPLEFT", 0, -52)
  sf:SetPoint("BOTTOMRIGHT", 0, 0)
  L.content = content
  L.nextRow, L.doneRows = pool(function()
    local r = CreateFrame("Frame", nil, content)
    r:SetHeight(ROW)
    r.hl = T:Fill(r, { 0.5, 0.83, 0.61, 0.18 }, "BACKGROUND")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("LEFT", 2, 0)
    r.cells = {}
    local x = 0
    for i = #LOOT_COLS, 2, -1 do
      local fs = T:Text(r, 11)
      fs:SetPoint("RIGHT", r, "RIGHT", -x, 0)
      fs:SetWidth(LOOT_COLS[i].w)
      fs:SetJustifyH("RIGHT")
      r.cells[i] = fs
      x = x + LOOT_COLS[i].w
    end
    local name = T:Text(r, 11)
    name:SetPoint("LEFT", 20, 0)
    name:SetPoint("RIGHT", r, "RIGHT", -x - 4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    r.cells[1] = name
    itemHover(r)
    return r
  end)

  -- Bottom right: gold by where it came from, then past sessions.
  local R = CreateFrame("Frame", nil, f)
  R:SetPoint("TOPLEFT", L, "TOPRIGHT", 20, 0)
  R:SetPoint("BOTTOMRIGHT", -12, 10)
  f.side = R
  R.nextLine, R.doneLines = pool(function() return line(R) end)
  R.nextHead, R.doneHeads = pool(function() return T:Text(R, 12) end)

  f:Hide()
  return f
end

-- The graph from the pace points and where it is now.
local function drawGraph(g, s, st, usual)
  g.doneLines()
  local pts = {}
  for _, p in ipairs(s.pace or {}) do pts[#pts + 1] = p end
  local nowV = math.floor(st.gained + st.loot + 0.5)
  if #pts > 0 and st.secs > pts[#pts][1] then pts[#pts + 1] = { st.secs, nowV } end
  if #pts < 2 then
    g.empty:Show()
    g.top:SetText(""); g.zero:SetText(""); g.right:SetText(""); g.legend:SetText("")
    g.zeroLine:Hide()
    return
  end
  g.empty:Hide()
  local span = math.max(60, pts[#pts][1])
  local lo, hi = 0, 1
  for _, p in ipairs(pts) do lo, hi = math.min(lo, p[2]), math.max(hi, p[2]) end
  local usualEnd = usual and usual.usual * span / 3600
  if usualEnd then lo, hi = math.min(lo, usualEnd), math.max(hi, usualEnd) end
  local gw, gh = g:GetWidth(), g:GetHeight()
  if not gw or gw <= 0 then gw = W - 24 end
  if not gh or gh <= 0 then gh = 106 end
  local PADT, PADB = 16, 16
  local function x(t) return 2 + (gw - 4) * t / span end
  local function y(v) return PADB + (gh - PADT - PADB) * (v - lo) / (hi - lo) end
  g.zeroLine:ClearAllPoints()
  g.zeroLine:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, y(0))
  g.zeroLine:SetPoint("BOTTOMRIGHT", g, "BOTTOMLEFT", gw, y(0))
  g.zeroLine:Show()
  if usualEnd and g.CreateLine then
    local l = g.nextLine()
    l:SetThickness(1)
    l:SetColorTexture(1, 1, 1, 0.3)
    l:SetStartPoint("BOTTOMLEFT", g, x(0), y(0))
    l:SetEndPoint("BOTTOMLEFT", g, x(span), y(usualEnd))
  end
  if g.CreateLine then
    local c = T.accent
    for i = 2, #pts do
      local l = g.nextLine()
      l:SetThickness(2)
      l:SetColorTexture(c[1], c[2], c[3], 1)
      l:SetStartPoint("BOTTOMLEFT", g, x(pts[i - 1][1]), y(pts[i - 1][2]))
      l:SetEndPoint("BOTTOMLEFT", g, x(pts[i][1]), y(pts[i][2]))
    end
  end
  local F = fmt()
  g.top:SetText(ns.Money(math.floor(hi + 0.5)))
  g.zero:SetText(lo < 0 and ("-" .. ns.Money(math.floor(-lo + 0.5))) or "0")
  g.right:SetText(F.duration and F.duration(span) or "")
  g.legend:SetText(usualEnd and ("%sЗолото и добыча|r   |cffaaaaaaВаш обычный темп|r"):format(T:AccentCode()) or (T:AccentCode() .. "Золото и добыча|r"))
end

local function drawLoot(L, st, flashID)
  local sort = sortState()
  local t = ns.SessionLootRows(st.items, sort.key, sort.asc)
  T:StyleHeading(L.head, "Добыча")
  L.total:SetText(ns.Money(st.loot))
  if t.best then
    L.best.itemID = t.best.id
    L.best.text:SetText(("Лучшая добыча: |T%s:14:14|t %s, %s за штуку"):format(ns:ItemIcon(t.best.id) or "", t.best.name, ns.Money(math.floor(t.best.each + 0.5))))
  else
    L.best.itemID = nil
    L.best.text:SetText("Добычи пока нет (или всё продано: это в «Золоте»).")
  end
  for _, b in ipairs(L.cols) do
    local on = sort.key == b.col.key
    b.text:SetText(ns.LocalizeText(b.col.label) .. (on and (sort.asc and " ^" or " v") or ""))
    T:Font(b.text, 10, on and T.text or T.dim)
  end
  L.doneRows()
  local y = 0
  local function row(r)
    local f = L.nextRow()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", L.content, "TOPLEFT", 0, -y)
    f:SetPoint("RIGHT", L.content, "RIGHT", 0, 0)
    f.itemID = r and r.id
    f:EnableMouse(r ~= nil)
    f.icon:SetShown(r ~= nil)
    f.hl:SetShown(r ~= nil and r.id == flashID)
    y = y + ROW
    return f
  end
  for _, r in ipairs(t.rows) do
    local f = row(r)
    f.icon:SetTexture(ns:ItemIcon(r.id))
    f.cells[1]:SetText(r.name); T:Font(f.cells[1], 11, T.text)
    f.cells[2]:SetText(tostring(r.n))
    f.cells[3]:SetText(ns.Money(math.floor(r.each + 0.5)))
    f.cells[4]:SetText(ns.Money(r.value))
  end
  if #t.grays > 0 then
    y = y + 4
    local h = row(nil)
    h.cells[1]:SetText(("Серые предметы для торговца (%d)"):format(#t.grays)); T:Font(h.cells[1], 10, T.dim)
    h.cells[2]:SetText(""); h.cells[3]:SetText("")
    h.cells[4]:SetText(ns.Money(t.grayValue))
    for _, r in ipairs(t.grays) do
      local f = row(r)
      f.icon:SetTexture(ns:ItemIcon(r.id))
      f.cells[1]:SetText(r.name); T:Font(f.cells[1], 11, { 0.62, 0.62, 0.62, 1 })
      f.cells[2]:SetText(tostring(r.n))
      f.cells[3]:SetText(ns.Money(math.floor(r.each + 0.5)))
      f.cells[4]:SetText(ns.Money(r.value))
    end
  end
  if (st.unpriced or 0) > 0 then
    y = y + 4
    local n = row(nil)
    n.cells[1]:SetText(("Ещё %d без цены — не учтены."):format(st.unpriced)); T:Font(n.cells[1], 10, T.dim)
    n.cells[2]:SetText(""); n.cells[3]:SetText(""); n.cells[4]:SetText("")
  end
  L.content:SetHeight(math.max(1, y))
end

local function drawSide(R, s, st)
  local F = fmt()
  R.doneLines(); R.doneHeads()
  local y = 0
  local function head(text, right)
    local h = R.nextHead()
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 0, -y)
    T:StyleHeading(h, text)
    local r = R.nextLine()
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", R, "RIGHT", 0, 0)
    r.left:SetText("")
    r.right:SetText(right or "")
    r.hl:Hide()
    y = y + 18
  end
  local function add(left, right, lit, color)
    local r = R.nextLine()
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 6, -y)
    r:SetPoint("RIGHT", R, "RIGHT", 0, 0)
    r.left:SetText(left)
    T:Font(r.left, 11, color or T.text)
    r.right:SetText(right or "")
    r.hl:SetShown(lit and true or false)
    y = y + ROW
  end
  head("Золото", ("|cff%s%s|r"):format(st.gained >= 0 and "7fd39c" or "ee8597", F.signed and F.signed(st.gained) or ns.Money(st.gained)))
  local by = {}
  for src, v in pairs(s.money or {}) do if v ~= 0 then by[#by + 1] = { src, v } end end
  table.sort(by, function(a, b) return math.abs(a[2]) > math.abs(b[2]) end)
  if #by == 0 then add("Золота пока не было.", "", false, T.dim) end
  for k = 1, math.min(GOLD_ROWS, #by) do
    local x = by[k]
    add((ns.MONEY_LABELS and ns.MONEY_LABELS[x[1]]) or x[1], (x[2] < 0 and "|cffee8597-|r" or "|cff7fd39c+|r") .. ns.Money(math.abs(x[2])))
  end
  if #by > GOLD_ROWS then
    local rest = 0
    for k = GOLD_ROWS + 1, #by do rest = rest + by[k][2] end
    add(("ещё %d"):format(#by - GOLD_ROWS), F.signed and F.signed(rest) or ns.Money(rest))
  end
  y = y + 8
  head("Прошлые сессии")
  local past = ns.SessionPastRows(PAST_ROWS)
  if #past == 0 then add("Здесь появятся завершённые сессии.", "", false, T.dim) end
  for _, p in ipairs(past) do
    local when = date("%b %d", p.t or 0) .. "  " .. (F.duration and F.duration(p.secs or 0):gsub(" %d+s$", "") or "")
    local rate = p.rate and ((F.rate and F.rate(p.rate) or ns.Money(math.floor(p.rate))) .. "/ч") or "|cff888888короткая|r"
    add(when, rate, p.best, p.best and { 0.5, 0.83, 0.61, 1 } or nil)
  end
end

local function drawTiles(f, st, s, usual)
  local F = fmt()
  local rateSecs = ns.SESSION_RATE_SECONDS or 300
  local t1, t2, t3, t4 = f.tiles[1], f.tiles[2], f.tiles[3], f.tiles[4]
  t1.label:SetText("Золото в час")
  if st.secs >= rateSecs then
    t1.value:SetText(F.rate and F.rate(st.perHour) or ns.Money(math.floor(st.perHour)))
    t1.note:SetText("золото и добыча")
  else
    t1.value:SetText("|cff888888...|r")
    t1.note:SetText(("через %d мин"):format(rateSecs / 60))
  end
  t2.label:SetText("Золото")
  t2.value:SetText(("|cff%s%s|r"):format(st.gained >= 0 and "7fd39c" or "ee8597", F.signed and F.signed(st.gained) or ns.Money(st.gained)))
  t2.note:SetText(("приход %s, расход %s"):format(ns.Money(st.earned), ns.Money(st.spent)))
  t3.label:SetText("Добыча, ещё у вас")
  t3.value:SetText(ns.Money(st.loot))
  t3.note:SetText(("%d %s"):format(#st.items, ns.Plural(#st.items, "вид", "вида", "видов")))
  t4.label:SetText("Ваш обычный")
  if usual then
    t4.value:SetText((F.rate and F.rate(usual.usual) or ns.Money(math.floor(usual.usual))) .. " |cffbbbbbb/h|r")
    if st.secs >= rateSecs then
      local d = st.perHour - usual.usual
      t4.note:SetText(d >= 0 and ("|cff7fd39cвпереди на %s|r"):format(ns.Money(math.floor(d + 0.5)))
        or ("|cffee8597позади на %s|r"):format(ns.Money(math.floor(-d + 0.5))))
    else
      t4.note:SetText(("лучшее %s"):format(F.rate and F.rate(usual.best) or ns.Money(math.floor(usual.best))))
    end
  else
    t4.value:SetText("|cff888888...|r")
    t4.note:SetText("после 3 сессий по 10 мин")
  end
end

local lastFlash
function ns:DrawSessionWindow(st, s, flashID)
  if not (win and win:IsShown() and st and s) then return end
  lastFlash = flashID
  local F = fmt()
  win.time:SetText((F.duration and F.duration(st.secs) or "") .. (s.paused and "  |cffffd100пауза|r" or ""))
  -- AHledger's terms: its credit when its prices valued the loot (Codex review, November 17).
  win.hint:SetText(st.ahledger and ns.AHLEDGER_CREDIT or "Перетащите, чтобы переместить")
  local usual = ns:SessionUsual()
  drawTiles(win, st, s, usual)
  drawGraph(win.graph, s, st, usual)
  drawLoot(win.lootBox, st, flashID)
  drawSide(win.side, s, st)
end

function ns.RedrawSessionWindow()
  local s = ns.db and ns.db.liveSession
  if not s then return end
  local before = ns.AHledgerUses and ns.AHledgerUses() or 0
  local st = ns:SessionTotals(s)
  if st then st.ahledger = ns.AHledgerUses and ns.AHledgerUses() ~= before end
  ns:DrawSessionWindow(st, s, lastFlash)
end

function ns.SessionWindowShown() return win ~= nil and win:IsShown() end
-- With the tracker (the session ended or another character): hidden, still open next time.
function ns.HideSessionWindow() if win then win:Hide() end end

-- on: true opens, false closes, nil switches. Only while a session runs here.
function ns:ToggleSessionWindow(on)
  if on == nil then on = not ns.SessionWindowShown() end
  local s = ns.db.liveSession
  if on and not (s and s.char == ns.CharKey()) then return end
  ns.db.settings.sessionFull = on or nil
  if on then
    if not win then win = build() end
    win:Show()
    ns.RedrawSessionWindow()
  elseif win then
    win:Hide()
  end
  if ns.SessionTrackerLayout then ns.SessionTrackerLayout() end
end
