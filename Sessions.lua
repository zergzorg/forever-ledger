local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- Sessions (owner, October 3): start one any time and a small tracker counts what the
-- time was worth: gold in and out by where it came from (History.lua tells us each
-- change and its source), and what you looted, valued at the better of the auction
-- house (after the cut) and a vendor, or vendor only (setting). At the end, a summary
-- in chat and a line in the Ledger's Sessions. (The "Work it" shuffle sessions were
-- removed with that window, October 4; their finished ones still show.) Archived November
-- 13 and back November 15 at a player's request, without the Dashboard's button and table
-- (Frank: "We can sort out how to utilize it in the new version"): start and stop with
-- /fl session or Ctrl-click on the minimap button.
--
-- ns.db.liveSession = { t, char, money = { [source] = signed copper }, loot = { [itemID] = count } }
-- Finished ones go to ns.db.sessions as { kind = "general", name, t, stop, earned, spent, loot, top }.
-- Nothing here runs without a session: the events return at once.
---------------------------------------------------------------------------
local TRACKER_SECONDS = 1   -- the tracker redraws this often, and only while a session runs

local function live() return ns.db and ns.db.liveSession end
local drawTracker   -- (the tracker, below; the loot event redraws it)

-- Gold an hour, losses in red with a minus (owner's test, October 3: a session that
-- spent 16s said "0c an hour").
local function rateText(v)
  v = math.floor(v + 0.5)
  if v >= 0 then return ns.Money(v) end
  return "|cffee8597-|r" .. ns.Money(-v)
end

-- What one looted item is worth: ns:LootValue (Values.lua; Settings, Sessions, Count loot at).

-- Gold an hour shows from this far in: before that one kill or purchase swings it wildly
-- (owner's test, October 3: "-21g 60s an hour" 20 seconds in; 5 minutes since November 17,
-- as Blackthornes Farmer does).
local RATE_SECONDS = 300
ns.SESSION_RATE_SECONDS = RATE_SECONDS

-- Of a session's loot, how many still count as loot: looted, less what was sold during it,
-- and no more than this character still has (bags, bank, its auctions not yet sold).
-- Selling looted items counted them twice, as loot and again as the gold they brought (a
-- player on CurseForge, November 16); disenchanting, using or destroying them likewise
-- left them counted. What a sale brought is in the gold; what's gone is gone.
local function stillHeld(s)
  if s.char ~= ns.CharKey() then return nil end   -- another character's bags say nothing
  local posted = {}
  for _, key in ipairs({ s.char, s.char .. " (neutral)" }) do
    local mine = ns.db.myAuctions and ns.db.myAuctions[key]
    for _, e in ipairs(mine and mine.list or {}) do
      if e.id and not e.sold then posted[e.id] = (posted[e.id] or 0) + (e.q or 1) end
    end
  end
  return function(id) return ns.ItemCount(id, true) + (posted[id] or 0) end
end

-- Totals so far: { secs, gained = net gold change, earned, spent, loot = value of what
-- was looted and is still held, items = { { id, n, value } } best first, unpriced = items
-- with no price (not counted), perHour }.
function ns:SessionTotals(s)
  s = s or live()
  if not s then return end
  local earned, spent = 0, 0
  for _, v in pairs(s.money or {}) do
    if v > 0 then earned = earned + v else spent = spent - v end
  end
  local loot, items, unpriced = 0, {}, 0
  local held = stillHeld(s)
  for id, n in pairs(s.loot or {}) do
    n = n - ((s.sold or {})[id] or 0)
    if held then n = math.min(n, held(id)) end
    if n > 0 then
      local value = ns:LootValue(id) * n
      if value > 0 then
        loot = loot + value
        items[#items + 1] = { id = id, n = n, value = value }
      else
        unpriced = unpriced + n
      end
    end
  end
  table.sort(items, function(a, b) return a.value > b.value end)
  -- Time played, not time since it started: a session carried over a logout doesn't
  -- count the time offline (code review, October 4). s.active = seconds before the
  -- last logout, s.resume = when it carried on (old sessions: from the start).
  local secs
  if s.active == nil and s.resume == nil then
    secs = time() - s.t   -- a session from before this was counted (or a stored one)
  else
    -- The clock runs only while its own character plays (Codex review of 893cbbd: another
    -- character's hour went into it).
    local mine = s.char == ns.CharKey()
    secs = (s.active or 0) + ((mine and s.resume) and (time() - s.resume) or 0)
  end
  secs = math.max(1, secs)
  local gained = earned - spent
  return { secs = secs, earned = earned, spent = spent, gained = gained, loot = loot, items = items,
    unpriced = unpriced, perHour = (gained + loot) / secs * 3600 }
end

-- Gold an hour of a finished session (gold and loot), or nil when it was too short to say.
function ns.SessionRate(e)
  local secs = e and (e.secs or ((e.stop or e.t or 0) - (e.t or 0)))
  if not secs or secs < RATE_SECONDS then return nil end
  return ((e.earned or 0) - (e.spent or 0) + (e.loot or 0)) / secs * 3600
end

-- Your usual and best gold an hour, from finished sessions of 10 minutes or more on this
-- character's realm and faction (the newest 20; usual = their median). nil with fewer than 3.
local USUAL_MIN_SECONDS, USUAL_COUNT = 600, 20
function ns:SessionUsual()
  local rates = {}
  local list = ns.db.sessions or {}
  for i = #list, 1, -1 do
    local e = list[i]
    if e.kind == "general" and (e.secs or 0) >= USUAL_MIN_SECONDS and (not e.c or not ns.SameMarketChar or ns:SameMarketChar(e.c)) then
      rates[#rates + 1] = ns.SessionRate(e)
      if #rates >= USUAL_COUNT then break end
    end
  end
  if #rates < 3 then return nil end
  local best = math.max(unpack(rates))
  table.sort(rates)
  local n = #rates
  local usual = n % 2 == 1 and rates[(n + 1) / 2] or (rates[n / 2] + rates[n / 2 + 1]) / 2
  return { usual = usual, best = best, n = n }
end

local function duration(secs)
  local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60)
  if h > 0 then return ("%d ч %02d мин"):format(h, m) end
  return ("%d мин %02d с"):format(m, secs % 60)
end
local function signed(c) return (c < 0 and "-" or "+") .. ns.Money(math.abs(c)) end
ns.SessionFormat = { duration = duration, signed = signed, rate = rateText }   -- (SessionWindow.lua)

---------------------------------------------------------------------------
-- Counting
---------------------------------------------------------------------------
-- Every gold change, with where it came from (History.lua onMoney).
function ns:SessionMoney(source, delta)
  local s = live()
  if not s or s.char ~= ns.CharKey() or s.paused then return end
  s.money[source] = (s.money[source] or 0) + delta
end

-- Something sold to a vendor or on the auction house (History.lua, with the gold it
-- brought): looted this session, it now counts as that gold, not as loot as well. item is
-- an item ID (vendor) or a name (auction sales name the item). Counted while paused too:
-- the loot it was is still in the totals.
-- An auction sale counts only against what was posted during this session (Codex review,
-- November 17: the money for an auction posted before it took this session's new loot of
-- the same item off), and its name may carry random stats ("Short Bastard Sword of
-- Strength" for the looted Short Bastard Sword). Copies are alike, so what's sold during
-- the session comes off its loot first: never counted twice, at worst a little under.
-- And the sale's mail must have come after the post (Codex verification, November 18: an
-- old auction's mail, collected while this session's loot of the same item was still
-- listed, took that loot off): arrived = when the mail came (History.lua, from its days
-- left), and only posts made by then count. A little slack for the days-left rounding.
local function nameMatches(sale, base)
  if not (sale and base) then return false end
  if sale == base then return true end
  return sale:sub(1, #base + 4) == base .. " of "
end
local MAIL_SLACK = 300
-- How many of this session's posts of id a sale whose mail came at arrived can be.
local function postsBefore(s, id, arrived)
  local n = (s.posted or {})[id] or 0
  local batches = s.postedAt and s.postedAt[id]
  if not (arrived and batches) then return n end   -- (no mail time, or posts from before this was kept)
  local m = 0
  for _, b in ipairs(batches) do if b[1] <= arrived + MAIL_SLACK then m = m + b[2] end end
  return math.min(n, m)
end
local function usePosts(s, id, qty)
  s.posted[id] = s.posted[id] - qty
  local batches = s.postedAt and s.postedAt[id]
  while batches and qty > 0 and batches[1] do   -- the oldest first
    local take = math.min(qty, batches[1][2])
    batches[1][2], qty = batches[1][2] - take, qty - take
    if batches[1][2] <= 0 then table.remove(batches, 1) end
  end
end
function ns:SessionSold(item, qty, arrived)
  local s = live()
  if not (s and item) or s.char ~= ns.CharKey() then return end
  qty = tonumber(qty) or 1
  local id = type(item) == "number" and item or nil
  if not id then
    -- The posted item it was: the exact name first, then a version with random stats.
    local loose
    for postedID in pairs(s.posted or {}) do
      if postsBefore(s, postedID, arrived) > 0 and s.loot[postedID] then
        local base = ns.ItemName(postedID)
        if base == item then id = postedID; break end
        if not loose and nameMatches(item, base) then loose = postedID end
      end
    end
    id = id or loose
    if not id then return end
    qty = math.min(qty, postsBefore(s, id, arrived))
    usePosts(s, id, qty)
  end
  if not (id and s.loot[id]) then return end
  s.sold = s.sold or {}
  s.sold[id] = math.min(s.loot[id], (s.sold[id] or 0) + qty)
end

-- Posted on the auction house during the session (the hooks below): what its sales can
-- count against.
function ns:SessionPosted(id, qty)
  local s = live()
  if not (s and id) or s.char ~= ns.CharKey() then return end
  qty = tonumber(qty) or 1
  s.posted = s.posted or {}
  s.posted[id] = (s.posted[id] or 0) + qty
  -- When, so a sale's mail from before it can't be this post's (postsBefore above).
  s.postedAt = s.postedAt or {}
  s.postedAt[id] = s.postedAt[id] or {}
  table.insert(s.postedAt[id], { time(), qty })
end
ns:OnReady(function()
  local AH = C_AuctionHouse
  local function onPost(loc, _, qty)
    if not live() then return end
    local ok, id = pcall(function() return C_Item and C_Item.GetItemID and C_Item.GetItemID(loc) end)
    if ok and id then ns:SessionPosted(id, qty) end
  end
  if AH and AH.PostItem then hooksecurefunc(AH, "PostItem", onPost) end
  if AH and AH.PostCommodity then hooksecurefunc(AH, "PostCommodity", onPost) end
end)

-- "You receive loot: [Linen Cloth]x2." in the client's own language, as patterns.
local lootPatterns
local function patterns()
  if lootPatterns then return lootPatterns end
  lootPatterns = {}
  local function add(fmt, multiple)
    if not fmt then return end
    -- Escape the pattern characters, then turn %s into the item and %d into the count.
    local p = fmt:gsub("([%(%)%.%-%+%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    p = "^" .. p .. "$"
    lootPatterns[#lootPatterns + 1] = { p = p, multiple = multiple }
  end
  -- Only "You receive loot" (mobs, chests, gathering). "You receive item" is also vendor
  -- purchases and quest rewards: those would count twice, as gold spent and as loot.
  add(LOOT_ITEM_SELF_MULTIPLE, true)   -- first: the single form would match it too
  add(LOOT_ITEM_SELF, false)
  return lootPatterns
end

ns:On("CHAT_MSG_LOOT", function(msg)
  local s = live()
  if not (s and msg) or s.char ~= ns.CharKey() or s.paused then return end
  for _, pat in ipairs(patterns()) do
    local link, n = msg:match(pat.p)
    if link then
      local id = ns.ItemIDFromLink(link)
      if id then
        n = tonumber(n) or 1
        s.loot[id] = (s.loot[id] or 0) + n
        ns:RememberItem(id)
        -- The tracker shows what came in for a few seconds ("+2 Linen Cloth").
        ns.sessionLastLoot = { id = id, n = n, t = GetTime and GetTime() or time() }
        if drawTracker then drawTracker() end
      end
      return
    end
  end
end)

---------------------------------------------------------------------------
-- The tracker: a small window you can move, while a session runs.
---------------------------------------------------------------------------
local tracker, ticker

-- Small and quiet, so it doesn't get in the way of playing (owner's test, October 3:
-- "make it look a little nicer while keeping it small"): a thin accent line on top, the
-- time, gold an hour in larger text (the number people watch), gold and loot under it.
-- Right-click folds it to one slim line (settings.sessionSmall). More opens the full view
-- under it (settings.sessionFull; Frank, November 17: "a mini version... then the full
-- version that lets people see all the data live"): gold by where it came from, every
-- item looted with its worth (hover one for its tooltip), and your usual pace.
local W_MINI, W_SMALL = 244, 210   -- (wider for Reset, November 18: four icons and the time with "paused")
local FLASH_SECONDS = 4   -- (new loot shows on the tracker and is lit in the window this long)
local LOOT_NOTE = "Добыча считается по лучшей из цен аукциона (за вычетом комиссии) и торговца (Настройки, Сессии: только торговец), и только пока предмет у вас: проданное за сессию считается один раз — золотом, которое принесло."
local function fullView() return ns.SessionWindowShown and ns.SessionWindowShown() end   -- (SessionWindow.lua)

-- A small icon button with its name and what it does on hover; SetIcon changes both (Pause / Carry on).
local ICONS = "Interface\\AddOns\\ForeverLedger\\media\\icons\\session-"
local function iconButton(parent, icon, name, what, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(18, 18)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetSize(12, 12)
  b.tex:SetPoint("CENTER")
  local function tint(on) b.tex:SetVertexColor(on and 1 or 0.75, on and 0.85 or 0.75, on and 0.45 or 0.75) end
  function b:SetIcon(i, n, w)
    if i ~= b.icon then b.icon = i; b.tex:SetTexture(ICONS .. i) end
    b.name, b.what = n, w or b.what
  end
  b:SetIcon(icon, name, what)
  tint(false)
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    tint(true)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    ns:TooltipAddLine(self.name, 1, 1, 1)
    if self.what then ns:TooltipAddLine(self.what, 0.7, 0.7, 0.7, true) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() tint(false); GameTooltip:Hide() end)
  return b
end

local function layoutTracker(f)
  local small = ns.db.settings.sessionSmall
  f:SetSize(small and W_SMALL or W_MINI, small and 22 or 64)
  f.title:ClearAllPoints()
  f.title:SetPoint(small and "LEFT" or "TOPLEFT", 8, small and 0 or -8)
  f.time:ClearAllPoints()
  f.time:SetPoint("LEFT", f.title, "RIGHT", 6, 0)
  f.rate:SetShown(not small)
  f.gold:SetShown(not small)
  f.loot:SetShown(not small)
  f.stop:SetShown(not small)
  f.pause:SetShown(not small)
  f.reset:SetShown(not small)
  f.more:SetShown(not small)
  f.more:SetIcon(fullView() and "less" or "more", fullView() and "Less" or "More",
    fullView() and "Closes the session window." or "Opens the session window: a graph of your pace, every item looted (sort by any column), gold by where it came from and your past sessions.")
  f.smallRate:SetShown(small)
end
ns.SessionTrackerLayout = function() if tracker then layoutTracker(tracker) end end

local function buildTracker()
  local f = CreateFrame("Frame", "ForeverLedgerSessionTracker", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  -- In the theme (owner, October 4): its background a little see-through, its edge, the
  -- bronze top line on Default and Gilded (the accent on Clean), and Size.
  T:Fill(f, { T.bg[1], T.bg[2], T.bg[3], 0.85 })
  local edge = T.theme.frame and { T.theme.frame[1], T.theme.frame[2], T.theme.frame[3], 0.8 } or { 1, 1, 1, 0.12 }
  T:Border(f, edge)
  local top = T.theme.topLine or T.accent
  local bar = f:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("TOPRIGHT", -1, -1)
  bar:SetHeight(2)
  bar:SetColorTexture(top[1], top[2], top[3], 0.9)
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
    ns.db.settings.sessionPos = { point, rel, x, y }
  end)
  f:SetScript("OnMouseUp", function(self, button)
    if button ~= "RightButton" then return end
    ns.db.settings.sessionSmall = not ns.db.settings.sessionSmall or nil
    layoutTracker(self)
    drawTracker()
  end)
  local pos = ns.db.settings.sessionPos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOP", UIParent, "TOP", 0, -140) end

  f.title = T:Text(f, 11)
  T:StyleHeading(f.title, "Сессия")
  f.time = T:Text(f, 11, T.dim)
  f.rate = T:Text(f, 15, { 1, 0.82, 0, 1 })
  f.rate:SetPoint("TOPLEFT", 8, -24)
  f.gold = T:Text(f, 11)
  f.gold:SetPoint("BOTTOMLEFT", 8, 7)
  f.loot = T:Text(f, 11)
  f.loot:SetPoint("BOTTOMRIGHT", -8, 7)
  f.loot:SetJustifyH("RIGHT")
  f.loot:SetWidth(118)   -- (a new item's name, "+2 Linen Cloth", is cut short, not run into Gold)
  f.loot:SetWordWrap(false)
  f.smallRate = T:Text(f, 11, { 1, 0.82, 0, 1 })
  f.smallRate:SetPoint("RIGHT", -8, 0)
  f.smallRate:SetJustifyH("RIGHT")
  -- Small icons, not words (Frank, AN29, November 17: "More Pause Stop" ran over the time;
  -- media/icons/session-*, drawn by tools/make-icons.ps1). A hover names each one.
  f.stop = iconButton(f, "stop", "Стоп", "Завершает сессию и кладёт её итог в чат и в «Сессии» журнала.", function() ns:StopGeneralSession() end)
  f.stop:SetPoint("TOPRIGHT", -5, -5)
  -- Pause (Blackthornes Farmer has one; Frank, November 17): the clock stops and nothing is
  -- counted until Carry on (the play icon).
  f.pause = iconButton(f, "pause", "Пауза", "Счёт времени останавливается, и ничего не считается, пока не продолжите.", function() ns:PauseGeneralSession() end)
  f.pause:SetPoint("RIGHT", f.stop, "LEFT", -2, 0)
  f.reset = iconButton(f, "reset", "Сброс", "Очищает счёт этой сессии и запускает её часы заново с нуля. Спрашивает подтверждение.", function() ns:ResetGeneralSession() end)
  f.reset:SetPoint("RIGHT", f.pause, "LEFT", -2, 0)
  f.more = iconButton(f, "more", "Ещё", "", function() ns:ToggleSessionWindow() end)
  f.more:SetPoint("RIGHT", f.reset, "LEFT", -2, 0)
  layoutTracker(f)
  f:SetScript("OnEnter", function(self)
    local ahlBefore = ns.AHledgerUses and ns.AHledgerUses() or 0
    local st = ns:SessionTotals()
    -- (The full view shows all of it already.)
    if not st or fullView() then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    ns:TooltipAddLine("Сессия", 1, 1, 1)
    ns:TooltipAddDoubleLine("Приход", ns.Money(st.earned), 0.8, 0.8, 0.8, 1, 1, 1)
    ns:TooltipAddDoubleLine("Расход", ns.Money(st.spent), 0.8, 0.8, 0.8, 1, 1, 1)
    -- Where it came from and went (owner's test, October 3: "+1g 84s, I don't think
    -- that's right"): auction sales, vendor, mail, loot..., biggest first.
    local by = {}
    for src, v in pairs((live() or {}).money or {}) do if v ~= 0 then by[#by + 1] = { src, v } end end
    table.sort(by, function(a, b) return math.abs(a[2]) > math.abs(b[2]) end)
    for _, x in ipairs(by) do
      local label = (ns.MONEY_LABELS and ns.MONEY_LABELS[x[1]]) or x[1]
      ns:TooltipAddDoubleLine("  " .. label, (x[2] < 0 and "|cffee8597-|r" or "|cff7fd39c+|r") .. ns.Money(math.abs(x[2])),
        0.7, 0.7, 0.7, 1, 1, 1)
    end
    ns:TooltipAddDoubleLine("Добыто, примерно на", ns.Money(st.loot), 0.8, 0.8, 0.8, 1, 1, 1)
    for k = 1, math.min(5, #st.items) do
      local it = st.items[k]
      ns:TooltipAddDoubleLine(("  %d x %s"):format(it.n, ns.ItemName(it.id) or "?"), ns.Money(it.value), 0.7, 0.7, 0.7, 1, 1, 1)
    end
    if #st.items > 5 then ns:TooltipAddLine(("  и ещё %d: стрелка («Ещё») покажет все"):format(#st.items - 5), 0.6, 0.6, 0.6) end
    ns:TooltipAddLine(LOOT_NOTE, 0.6, 0.6, 0.6, true)
    if ns.AHledgerUses and ns.AHledgerUses() ~= ahlBefore then ns:TooltipAddLine(ns.AHLEDGER_CREDIT, 0.5, 0.5, 0.5) end
    ns:TooltipAddLine(ns.db.settings.sessionSmall and "Перетащите, чтобы переместить. Правый клик — полный вид, там же «Ещё» (стрелка), «Сброс», «Пауза» и «Стоп»."
      or "Перетащите, чтобы переместить. Правый клик — свернуть в одну строку. Стрелка показывает всё по мере поступления.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return f
end

drawTracker = function()
  local ahlBefore = ns.AHledgerUses and ns.AHledgerUses() or 0
  local st = ns:SessionTotals()
  if st then st.ahledger = ns.AHledgerUses and ns.AHledgerUses() ~= ahlBefore end   -- (loot valued with its prices: its credit)
  if not (tracker and st) then return end
  local s = live()
  local rate = st.secs >= RATE_SECONDS and rateText(st.perHour) or "|cff888888...|r"
  tracker.time:SetText(duration(st.secs) .. (s.paused and " |cffffd100пауза|r" or ""))
  tracker.rate:SetText(st.secs >= RATE_SECONDS and (rate .. " |cffbbbbbbв час|r") or "|cff888888в час: через 5 мин|r")   -- (shorter: the longer text ran past the tracker, October 4)
  tracker.smallRate:SetText(s.paused and "|cffffd100пауза|r" or (rate .. " |cffbbbbbb/ч|r"))
  tracker.pause:SetIcon(s.paused and "play" or "pause", s.paused and "Продолжить" or "Пауза",
    s.paused and "Счёт времени идёт дальше, и всё снова считается." or "Счёт времени останавливается, и ничего не считается, пока не продолжите.")
  tracker.gold:SetText(("|cff999999Золото|r |cff%s%s|r"):format(st.gained >= 0 and "7fd39c" or "ee8597", signed(st.gained)))
  -- What just came in, for a few seconds (as Blackthornes Farmer's "+2").
  local last = ns.sessionLastLoot
  local now = GetTime and GetTime() or time()
  local flashID = last and now - last.t < FLASH_SECONDS and last.id or nil
  if flashID then
    tracker.loot:SetText(("|cff7fd39c+%d %s|r"):format(last.n, ns.ItemName(last.id) or "?"))
  else
    tracker.loot:SetText(("|cff999999Добыча|r %s"):format(ns.Money(st.loot)))
  end
  if ns.SessionPaceSample then ns.SessionPaceSample(s, st) end   -- (the window's graph)
  if ns.DrawSessionWindow then ns:DrawSessionWindow(st, s, flashID) end
end

-- Pause or carry on (on = true pauses, false carries on, nil switches). While paused the
-- clock stops and nothing new is counted; selling what was looted still moves it to gold.
function ns:PauseGeneralSession(on)
  local s = live()
  if not s or s.char ~= ns.CharKey() then ns:Print("Сессия здесь не идёт. /fl session start начнёт её."); return end
  if on == nil then on = not s.paused end
  if on and not s.paused then
    if s.resume then s.active = (s.active or 0) + (time() - s.resume) end
    s.resume, s.paused = nil, true
  elseif not on and s.paused then
    s.paused, s.resume = nil, time()
  end
  if drawTracker then drawTracker() end
end

-- Start over (Frank, November 18: a reset button, with a confirm): what this session
-- counted goes, not kept in your sessions, and the clock starts again from zero. A paused
-- one carries on. Asks first unless sure is true.
StaticPopupDialogs["FOREVER_LEDGER_SESSION_RESET"] = {
  text = "Сбросить сессию?\n\nВсё, что она насчитала (%s), очистится, и часы пойдут заново с нуля. В «Сессии» это не попадёт.",
  button1 = "Сбросить", button2 = CANCEL or "Отмена",
  OnAccept = function() ns:ResetGeneralSession(true) end,
  timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
}
function ns:ResetGeneralSession(sure)
  local s = live()
  if not s or s.char ~= ns.CharKey() then ns:Print("Здесь сессия не идёт. /fl session start начнёт её."); return end
  if not sure then
    local st = ns:SessionTotals(s)
    StaticPopup_Show("FOREVER_LEDGER_SESSION_RESET", ("%s, золото %s, добыча %s"):format(duration(st.secs), signed(st.gained), ns.Money(st.loot)))
    return
  end
  ns.db.liveSession = { t = time(), resume = time(), active = 0, char = s.char, money = {}, loot = {} }
  ns.sessionLastLoot = nil
  ns:Print("Сессия сброшена: счёт пойдёт заново с этого момента.")
  if drawTracker then drawTracker() end
end

local function showTracker()
  if not tracker then tracker = buildTracker() end
  tracker:Show()
  drawTracker()
  if ns.db.settings.sessionFull and ns.ToggleSessionWindow then ns:ToggleSessionWindow(true) end
  if ticker then ticker:Cancel() end
  ticker = C_Timer.NewTicker(TRACKER_SECONDS, drawTracker)
end

local function hideTracker()
  if ticker then ticker:Cancel(); ticker = nil end
  if tracker then tracker:Hide() end
  if ns.HideSessionWindow then ns.HideSessionWindow() end
end

---------------------------------------------------------------------------
-- Start and stop
---------------------------------------------------------------------------
function ns:StartGeneralSession()
  local s = live()
  if s and s.char == ns.CharKey() then
    ns:Print("Сессия уже идёт: /fl session stop завершит её.")
    return
  elseif s then
    -- One left running on another character: end it (kept with your sessions) and
    -- start this one, in one click (owner's test, October 4).
    -- One line, not two that disagree ("it's in your sessions", then "isn't kept":
    -- owner's test, October 4).
    local c = ns.db.chars[s.char]
    local kept = ns:StopGeneralSession(true)
    ns:Print(("Завершена сессия, оставшаяся на %s (%s)."):format((c and c.name) or s.char,
      kept and "она в ваших сессиях" or "в ней ничего не произошло, поэтому она не сохранена"))
  end
  ns.db.liveSession = { t = time(), resume = time(), active = 0, char = ns.CharKey(), money = {}, loot = {} }
  ns:Print("Сессия начата: считаются приход и расход золота и ваша добыча. Завершить: /fl session stop (или «Стоп» на счётчике).")
  showTracker()
  if ns.RefreshUI then ns:RefreshUI() end
end

-- quiet: no summary in chat (ending one left on another character says it in one line).
-- Returns true when the session was kept.
function ns:StopGeneralSession(quiet)
  local s = live()
  if not s then ns:Print("Сессия не идёт. /fl session start начнёт её."); return end
  local st = ns:SessionTotals(s)
  ns.db.liveSession = nil
  hideTracker()
  -- Started and stopped with nothing happening (a misclick, a test): not kept (owner's
  -- test, October 3: the Dashboard listed several "0 min, gold 0c" sessions).
  if st.secs < 60 and st.earned == 0 and st.spent == 0 and st.loot == 0 then
    if not quiet then ns:Print("Сессия остановлена. В ней ничего не произошло, поэтому она не сохранена.") end
    if ns.RefreshUI then ns:RefreshUI() end
    return false
  end
  local usual = ns:SessionUsual()   -- (before this one joins them)
  local top = {}
  for k = 1, math.min(5, #st.items) do top[k] = { st.items[k].id, st.items[k].n, st.items[k].value } end
  table.insert(ns.db.sessions, { kind = "general", name = "Сессия", c = s.char, t = s.t, stop = time(), secs = st.secs, earned = st.earned,
    spent = st.spent, loot = st.loot, top = top, runs = 0, money = s.money })
  while #ns.db.sessions > 100 do table.remove(ns.db.sessions, 1) end
  if ns.BooksChanged then ns:BooksChanged() end
  if quiet then
    if ns.RefreshUI then ns:RefreshUI() end
    return true
  end
  ns:Print(("Сессия длилась %s: золото %s, добыто примерно на %s — примерно %s в час."):format(duration(st.secs),
    signed(st.gained), ns.Money(st.loot), rateText(st.perHour)))
  -- Against your usual pace, and a cheer for your best yet (as Blackthornes Farmer does).
  if usual and st.secs >= USUAL_MIN_SECONDS then
    if st.perHour > usual.best then
      print(("  |cff7fd39cЛучшая сессия!|r (прежняя лучшая: %s в час)"):format(rateText(usual.best)))
    else
      print(("  Ваш обычный темп: %s в час."):format(rateText(usual.usual)))
    end
  end
  -- Gold by where it came from, biggest first.
  local by = {}
  for src, v in pairs(s.money or {}) do if v ~= 0 then by[#by + 1] = { src, v } end end
  table.sort(by, function(a, b) return math.abs(a[2]) > math.abs(b[2]) end)
  local parts = {}
  for k = 1, math.min(4, #by) do
    parts[k] = ("%s %s"):format((ns.MONEY_LABELS and ns.MONEY_LABELS[by[k][1]]) or by[k][1], signed(by[k][2]))
  end
  if #parts > 0 then print("  Золото: " .. table.concat(parts, ", ") .. ".") end
  for k = 1, math.min(3, #st.items) do
    local it = st.items[k]
    print(("  %d x %s, около %s"):format(it.n, ns.ItemName(it.id) or "?", ns.Money(it.value)))
  end
  if ns.RefreshUI then ns:RefreshUI() end
  return true
end

-- Running on this character (one left running on another doesn't count here: owner's
-- test, October 4, the Dashboard's button stopped it instead of starting one).
function ns:GeneralSessionRunning()
  local s = live()
  return s ~= nil and s.char == ns.CharKey()
end

-- A session left running at logout carries on at login, on the same character. Another
-- character leaves it paused until its own comes back (Codex review of 893cbbd: logging in
-- on another character resumed it, and its logout put that character's hour into it).
ns:On("PLAYER_ENTERING_WORLD", function()
  local s = live()
  -- Carrying on after a logout or reload: count time again from now.
  if s and s.char == ns.CharKey() and not s.resume and not s.paused then
    if s.active == nil then s.active = time() - s.t end   -- one started before this was counted
    s.resume = time()
  end
  if s and s.char == ns.CharKey() then showTracker() else hideTracker() end
end)
-- Logging out (or reloading): bank the time played so far, so time offline isn't counted.
ns:On("PLAYER_LOGOUT", function()
  local s = live()
  if not s then return end
  if s.char ~= ns.CharKey() then
    -- Not this character's: nothing to bank, and a resume an older version set here goes.
    s.resume = nil
    return
  end
  if s.resume then
    s.active = (s.active or 0) + (time() - s.resume)
  elseif s.active == nil then
    s.active = time() - s.t
  end
  s.resume = nil
end)
