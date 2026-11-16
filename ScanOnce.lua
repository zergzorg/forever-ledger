local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- Scan once (redesign build step 3, November 15; planning/REDESIGN_PLAN.md section 8):
-- the Buy panel's view for looking things over instead of sniping. One reading of the
-- auction house list (Sweep.lua, the same reading Live watch makes every 20 seconds),
-- then everything in the groups you tick (Groups.lua), with its cheapest price now, its
-- usual price and how far under or over that it is. The list stays as it was scanned
-- until you scan again, so nothing moves while you read it.
--
-- Left: the group tree, with tick boxes. All items (nothing ticked) > All groups > the
-- built-in groups and their sub-groups, then Watched, Gray items, the profession
-- groups and yours. Ticked groups add together; a group counts the ones under it.
-- Each level is indented and has its own shade (owner's mockup comment, November 15).
-- Saved in settings.buyQueue.scan = { groups = { [gid] = true }, open = { [gid] = true } }.
---------------------------------------------------------------------------

local frame            -- the view, inside the Buy panel (BuyQueue.lua)
local results = {}     -- every item from the last scan: { id, cheap, usual, pct, listed, why, set, name }
local shown = {}       -- the rows after the groups and the search
local scannedAt        -- time() of the prices the list shows
local building         -- the list is being worked out (a few hundred items a frame)
local MAX_ROWS = 400   -- more than this: narrow it with groups or the search
local ROW_H = 18
local TREE_ROW_H = 18
local SHADES = { 0.10, 0.075, 0.055, 0.04 }

local function S()
  local q = ns.db.settings.buyQueue
  q.scan = q.scan or {}
  q.scan.groups = q.scan.groups or {}
  q.scan.open = q.scan.open or {}
  return q.scan
end

local function money(c) return c and ns.Money(c) or "" end

---------------------------------------------------------------------------
-- The group tree
---------------------------------------------------------------------------
local ALL, ALLGROUPS = "all", "allgroups"

-- The tree's rows: { id, name, depth, parent, hasKids }.
local function treeRows()
  local rows = {
    { id = ALL, name = "All items", depth = 0 },
    { id = ALLGROUPS, name = "All groups", depth = 1, parent = ALL },
  }
  local tree = ns.GroupTree and ns:GroupTree() or {}
  for i, g in ipairs(tree) do
    local info = ns:GroupInfo(g.id)
    local nextG = tree[i + 1]
    rows[#rows + 1] = { id = g.id, name = g.name, depth = g.depth + 2,
      parent = info and info.parent or ALLGROUPS, hasKids = nextG and nextG.depth > g.depth }
  end
  return rows
end

local function ticked(gid) return S().groups[gid] == true end

-- Whether a group above it is ticked (then it's covered and shown ticked, dimmed).
local function covered(row, byId)
  local p = row.parent
  while p and p ~= ALL do
    if ticked(p) then return true end
    p = byId[p] and byId[p].parent
  end
  return false
end

-- Whether a group under it is ticked (a dash).
local function partial(row, rows)
  for _, r in ipairs(rows) do
    local p = r.parent
    while p do
      if p == row.id and ticked(r.id) then return true end
      local up
      for _, x in ipairs(rows) do if x.id == p then up = x; break end end
      p = up and up.parent
    end
  end
  return false
end

local function nothingTicked() return next(S().groups) == nil end

---------------------------------------------------------------------------
-- Working out the list
---------------------------------------------------------------------------
local function whyOf(id, cheap, usual)
  local f = ns.FlipOrWatched and ns:FlipOrWatched(id)
  if f then return f.watched == "you" and "WATCH" or "FLIP" end
  local pct = ns.db.settings.dealUsualPct or 20
  if cheap and usual and usual > 0 and cheap <= usual * (100 - pct) / 100 then return "DEAL" end
  return ""
end

local refresh   -- shows `results` filtered (below)

-- Every item with a price from the last scan, 150 a frame so the game doesn't
-- stop for a moment on thousands of items.
local function build()
  local key = ns.MarketKey()
  local market = ns.db.prices[key] or {}
  local ids = {}
  for id, rec in pairs(market) do
    if type(id) == "number" and not rec.none and rec.m then ids[#ids + 1] = id end
  end
  local out, i = {}, 0
  building = true
  scannedAt = time()
  local function step()
    -- Another market since it started (the neutral auction house opened or closed):
    -- usual prices and reasons would come from it, so start again there (Codex review,
    -- November 15).
    if ns.MarketKey() ~= key then building = false; build(); return end
    local stop = math.min(i + 150, #ids)
    for k = i + 1, stop do
      local id = ids[k]
      local rec = market[id]
      local usual = ns.UsualPrice and ns:UsualPrice(id) or nil
      local cheap = rec.m
      out[#out + 1] = {
        id = id, cheap = cheap, usual = usual, listed = rec.q,
        pct = (usual and usual > 0) and math.floor(cheap / usual * 100 + 0.5) or nil,
        why = whyOf(id, cheap, usual),
        set = ns.ItemGroupSet and ns:ItemGroupSet(id) or {},
      }
    end
    i = stop
    if frame then frame.status:SetText(("Working out %d of %d items..."):format(i, #ids)) end
    if i < #ids then C_Timer.After(0, step) return end
    results, building = out, false
    refresh()
  end
  step()
end

-- Results that match the ticked groups and the search, best deals first.
local function filtered()
  local want = {}
  for gid in pairs(S().groups) do want[#want + 1] = gid end
  local search = frame and frame.search:GetText():lower() or ""
  local out = {}
  for _, e in ipairs(results) do
    local keep = #want == 0
    for _, gid in ipairs(want) do
      if gid == ALLGROUPS then
        for g in pairs(e.set) do if g ~= "misc" then keep = true; break end end
      elseif e.set[gid] then
        keep = true
      end
      if keep then break end
    end
    if keep and search ~= "" then
      e.name = e.name or ns.ItemName(e.id)
      keep = e.name:lower():find(search, 1, true) ~= nil
    end
    if keep then out[#out + 1] = e end
  end
  table.sort(out, function(a, b)
    if (a.pct ~= nil) ~= (b.pct ~= nil) then return a.pct ~= nil end
    if a.pct and b.pct and a.pct ~= b.pct then return a.pct < b.pct end
    return a.id < b.id
  end)
  return out
end

---------------------------------------------------------------------------
-- The view
---------------------------------------------------------------------------
local treeRowsNow, byIdNow = {}, {}

local function treeRow(i)
  local r = frame.tree.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, frame.tree.content)
  r:SetHeight(TREE_ROW_H)
  r.bg = T:Fill(r, { 1, 1, 1, 0.05 })
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.12)
  r.arrow = T:Text(r, 11, T.dim)
  r.box = CreateFrame("Frame", nil, r)
  r.box:SetSize(12, 12)
  T:Fill(r.box, T.button)
  T:Border(r.box, { 1, 1, 1, 0.3 })
  r.mark = r.box:CreateTexture(nil, "ARTWORK")
  r.mark:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 1)
  r.name = T:Text(r, 11)
  r.name:SetPoint("LEFT", r.box, "RIGHT", 5, 0)
  r.name:SetPoint("RIGHT", r, "RIGHT", -4, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r:RegisterForClicks("LeftButtonUp")
  r:SetScript("OnClick", function(self)
    local row = self.row
    local s = S()
    -- Clicking the arrow area opens or closes a group with groups under it.
    local x = select(1, GetCursorPosition()) / self:GetEffectiveScale() - self:GetLeft()
    if row.hasKids and x < 14 + row.depth * 12 then
      s.open[row.id] = not s.open[row.id] or nil
      ns:RefreshScanOnce(true)
      return
    end
    if row.id == ALL then
      wipe(s.groups)
    elseif covered(row, byIdNow) then
      return   -- a group above it is ticked: untick that one first (the tooltip says so)
    elseif s.groups[row.id] then
      s.groups[row.id] = nil
    else
      s.groups[row.id] = true
      -- It covers the ones under it now.
      for _, other in ipairs(treeRowsNow) do
        local p = other.parent
        while p do
          if p == row.id then s.groups[other.id] = nil; break end
          p = byIdNow[p] and byIdNow[p].parent
        end
      end
    end
    ns:RefreshScanOnce(true)
  end)
  r:SetScript("OnEnter", function(self)
    if not covered(self.row, byIdNow) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.row.name, 1, 1, 1)
    GameTooltip:AddLine("Already in: a group above it is ticked. Untick that one to pick parts of it.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.tree.rows[i] = r
  return r
end

local function drawTree()
  local s = S()
  treeRowsNow = treeRows()
  byIdNow = {}
  for _, r in ipairs(treeRowsNow) do byIdNow[r.id] = r end
  -- Only rows whose groups above are open (All items and All groups always are).
  local visible = {}
  for _, r in ipairs(treeRowsNow) do
    local show, p = true, r.parent
    while p and p ~= ALL and p ~= ALLGROUPS do
      if not s.open[p] then show = false; break end
      p = byIdNow[p] and byIdNow[p].parent
    end
    if show then visible[#visible + 1] = r end
  end
  local w = frame.tree.sf:GetWidth() - 12
  for i, row in ipairs(visible) do
    local r = treeRow(i)
    r.row = row
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", frame.tree.content, "TOPLEFT", 0, -(i - 1) * TREE_ROW_H)
    r:SetWidth(w)
    local shade = SHADES[math.min(row.depth + 1, #SHADES)]
    r.bg:SetColorTexture(1, 1, 1, shade)
    local indent = 4 + row.depth * 12
    r.arrow:ClearAllPoints()
    r.arrow:SetPoint("LEFT", indent - 2, 0)
    r.arrow:SetText(row.hasKids and (s.open[row.id] and "-" or "+") or "")
    r.box:ClearAllPoints()
    r.box:SetPoint("LEFT", indent + 10, 0)
    local on = (row.id == ALL and nothingTicked()) or ticked(row.id)
    local cover = row.id ~= ALL and covered(row, byIdNow)
    local part = not on and not cover and row.id ~= ALL and partial(row, treeRowsNow)
    r.mark:ClearAllPoints()
    if part then
      r.mark:SetPoint("LEFT", 3, 0)
      r.mark:SetSize(6, 2)
    else
      r.mark:SetPoint("TOPLEFT", 3, -3)
      r.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    r.mark:SetShown(on or cover or part)
    r.mark:SetAlpha(cover and 0.45 or 1)
    r.name:SetText(row.name)
    r:Show()
  end
  for i = #visible + 1, #frame.tree.rows do frame.tree.rows[i]:Hide() end
  frame.tree.content:SetHeight(math.max(#visible * TREE_ROW_H, TREE_ROW_H))
  frame.tree.sf.UpdateScrollBar()
end

-- Result columns from the right edge (the numbers never get cut off; the name does).
-- Room for the widest prices (189g 98s 50c) and the % of usual header (Frank's AH14
-- screenshot, November 15: Cheapest ran into Usual, Usual into % of usual).
local COL = { listed = -4, pct = -58, usual = -116, cheap = -208, why = -330, whyW = 46 }

local function resultRow(i)
  local r = frame.list.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, frame.list.content)
  r:SetHeight(ROW_H)
  r.stripe = T:Fill(r, { 1, 1, 1, 0.025 })
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.12)
  r.star = CreateFrame("Button", nil, r)
  r.star:SetSize(13, 13)
  r.star:SetPoint("LEFT", 2, 0)
  r.star.tex = r.star:CreateTexture(nil, "ARTWORK")
  r.star.tex:SetAllPoints()
  r.star:SetScript("OnClick", function(self)
    local e = self:GetParent().entry
    if ns:IsWatched(e.id) then ns:UnwatchItem(e.id) else ns:WatchItem(e.id) end
    if ns.SetWatchStar then ns.SetWatchStar(self.tex, ns:IsWatched(e.id)) end
  end)
  r.star:SetScript("OnEnter", function(self)
    local e = self:GetParent().entry
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns:IsWatched(e.id) and "Watched: click to stop watching it" or "Watch this item", 1, 1, 1)
    GameTooltip:AddLine("Live watch looks for watched items every time it reads the auction house, and the Buy queue buys them at or under your price (set it on the item's price window).", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  r.star:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(14, 14)
  r.icon:SetPoint("LEFT", r.star, "RIGHT", 3, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.listed, r.pct, r.usual, r.cheap = T:Text(r, 11), T:Text(r, 11), T:Text(r, 11), T:Text(r, 11)
  r.listed:SetPoint("RIGHT", r, "RIGHT", COL.listed, 0)
  r.pct:SetPoint("RIGHT", r, "RIGHT", COL.pct, 0)
  r.usual:SetPoint("RIGHT", r, "RIGHT", COL.usual, 0)
  r.cheap:SetPoint("RIGHT", r, "RIGHT", COL.cheap, 0)
  r.why = T:Text(r, 10, T.dim)
  r.why:SetPoint("LEFT", r, "RIGHT", COL.why, 0)
  r.why:SetWidth(COL.whyW)
  r.why:SetJustifyH("LEFT")
  r.name = T:Text(r, 11)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", r.why, "LEFT", -8, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r:SetScript("OnClick", function(self)
    if ns.ShowPriceWindow then ns:ShowPriceWindow(self.entry.id) end
  end)
  r:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetItemByID(self.entry.id)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click for its price window: listings now, price history, watch it at your price.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.list.rows[i] = r
  return r
end

local function pctText(p)
  if not p then return "|cff888888-|r" end
  if p <= 90 then return ("|cff7fd39c%d%%|r"):format(p) end
  if p >= 110 then return ("|cffee8597%d%%|r"):format(p) end
  return ("%d%%"):format(p)
end

local function drawList()
  shown = filtered()
  local n = math.min(#shown, MAX_ROWS)
  local w = frame.list.sf:GetWidth() - 12
  for i = 1, n do
    local e = shown[i]
    local r = resultRow(i)
    r.entry = e
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", frame.list.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetWidth(w)
    r.stripe:SetShown(i % 2 == 0)
    r.icon:SetTexture(ns:ItemIcon(e.id))
    r.name:SetText(ns.ItemName(e.id))
    r.why:SetText(e.why or "")
    r.cheap:SetText(money(e.cheap))
    r.usual:SetText(e.usual and money(e.usual) or "|cff888888-|r")
    r.pct:SetText(pctText(e.pct))
    r.listed:SetText(e.listed and tostring(e.listed) or "")
    if ns.SetWatchStar then ns.SetWatchStar(r.star.tex, ns:IsWatched(e.id)) end
    r:Show()
  end
  for i = n + 1, #frame.list.rows do frame.list.rows[i]:Hide() end
  frame.list.content:SetHeight(math.max(n * ROW_H, ROW_H))
  frame.list.sf.UpdateScrollBar()
  local when = scannedAt and date("%H:%M", scannedAt) or nil
  local status
  if building then
    status = nil
  elseif not when then
    status = "Press Scan to read the auction house, then tick groups on the left to narrow it down."
  else
    status = ("Prices from %s: %d item%s%s."):format(when, #shown, #shown == 1 and "" or "s",
      #shown > MAX_ROWS and (", the first %d shown (tick groups or search to narrow it)"):format(MAX_ROWS) or "")
  end
  if status then frame.status:SetText(status) end
  frame.empty:SetShown(not building and #shown == 0)
  frame.empty:SetText(not when and "Nothing scanned yet: press Scan."
    or "Nothing here: tick other groups, or clear the search.")
end

refresh = function()
  if not (frame and frame:IsVisible()) then return end
  drawTree()
  drawList()
end

-- tree: the ticks or open groups changed (only the list is filtered again, no new scan).
function ns:RefreshScanOnce()
  refresh()
end

-- Scan: Live watch already reads the list every 20 seconds, so its prices are used as
-- they are; otherwise one reading of the list (Sweep.lua), then the list is worked out.
local function scan()
  if not ns:IsAHOpen() then
    frame.status:SetText("Open the auction house first.")
    return
  end
  if ns:IsFlipWatching() or not (ns.SweepAvailable and ns:SweepAvailable()) then
    build()
    return
  end
  frame.status:SetText("Reading the auction house list...")
  frame.scanBtn:Disable()
  local started = ns:StartSweep(function()
    frame.scanBtn:Enable()
    build()
  end)
  if not started then
    frame.scanBtn:Enable()
    build()
  end
end

local function buildFrame(side)
  frame = CreateFrame("Frame", "ForeverLedgerScanOnce", side)
  frame:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -30)
  frame:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, 0)
  frame:EnableMouse(true)
  T:Fill(frame, T.bg)

  frame.scanBtn = T:Button(frame, "Scan", 90, scan)
  frame.scanBtn:SetPoint("TOPLEFT", 10, -8)
  frame.scanBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Scan once", 1, 1, 1)
    GameTooltip:AddLine("Reads the whole auction house list once (about 20 seconds), then shows everything in the groups you tick. The list stays as it was scanned until you scan again. With Live watch on, its prices are fresh already, so the list is just worked out again.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  frame.scanBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.status = T:Text(frame, 11, T.dim)
  frame.status:SetPoint("LEFT", frame.scanBtn, "RIGHT", 10, 0)
  frame.status:SetPoint("RIGHT", frame, "RIGHT", -170, 0)
  frame.status:SetJustifyH("LEFT")
  frame.status:SetWordWrap(false)
  frame.search = T:EditBox(frame, 150, "LEFT")
  frame.search:SetPoint("TOPRIGHT", -10, -9)
  frame.search:SetScript("OnTextChanged", function() if not building then drawList() end end)
  frame.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  local hint = T:Text(frame.search, 11, T.dim)
  hint:SetPoint("LEFT", 6, 0)
  hint:SetText("Search names")
  frame.search:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)

  -- Left: the groups.
  local left = CreateFrame("Frame", nil, frame)
  left:SetPoint("TOPLEFT", 10, -40)
  left:SetPoint("BOTTOMLEFT", 10, 10)
  left:SetWidth(210)
  T:Border(left)
  local lt = T:Text(left, 10, T.dim)
  lt:SetPoint("TOPLEFT", 6, -5)
  lt:SetText("Groups to show")
  frame.tree = { rows = {} }
  frame.tree.sf, frame.tree.content = T:Scroll(left)
  frame.tree.sf:SetPoint("TOPLEFT", 2, -20)
  frame.tree.sf:SetPoint("BOTTOMRIGHT", -3, 3)

  -- Right: the items.
  local right = CreateFrame("Frame", nil, frame)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
  right:SetPoint("BOTTOMRIGHT", -10, 10)
  T:Border(right)
  local header = CreateFrame("Frame", nil, right)
  header:SetPoint("TOPLEFT", 4, -3)
  header:SetPoint("TOPRIGHT", -4, -3)
  header:SetHeight(14)
  for _, c in ipairs({ { "Item", 32, "LEFT" }, { "Why", COL.why - 10, "WHY" }, { "Cheapest", COL.cheap - 10 },
                       { "Usual", COL.usual - 10 }, { "% of usual", COL.pct - 10 }, { "Listed", COL.listed - 10 } }) do
    local fs = T:Text(header, 10, T.dim)
    if c[3] == "LEFT" then fs:SetPoint("LEFT", c[2], 0)
    elseif c[3] == "WHY" then fs:SetPoint("LEFT", header, "RIGHT", c[2], 0)
    else fs:SetPoint("RIGHT", header, "RIGHT", c[2], 0) end
    fs:SetText(c[1])
  end
  frame.list = { rows = {} }
  frame.list.sf, frame.list.content = T:Scroll(right)
  frame.list.sf:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -2, -1)
  frame.list.sf:SetPoint("BOTTOMRIGHT", -3, 3)
  frame.empty = T:Text(right, 12, T.dim)
  frame.empty:SetPoint("CENTER")

  frame:SetScript("OnShow", function()
    -- First visit this session: work out the list from the prices already saved.
    if not scannedAt and not building then build() else refresh() end
  end)
  frame:SetScript("OnSizeChanged", function() if frame:IsVisible() and not building then refresh() end end)
  frame:Hide()
end

-- The view, made the first time the Buy panel asks for it.
function ns:ScanOnceFrame(side)
  if not frame and side then buildFrame(side) end
  return frame
end
