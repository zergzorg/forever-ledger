local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- The Post tab (redesign build step 4, November 15; planning/REDESIGN_PLAN.md sections 2
-- and 8, mockup "AH: Post tab"). Inside the auction house window (AHTabs.lua):
--   left   your bags, grouped (Groups.lua), each with a price ready and a mark from the
--          sell suggestion (SellAdvice.lua): Post, Keep, Vendor, Disenchant
--   right  the item being posted: how many, the price each (from its post rule:
--          Groups.lua RuleFor), how long, the deposit and what you get; Post, Skip,
--          Previous; under it the cheapest listings at the last scan
-- Posting is the game's own C_AuctionHouse.PostCommodity / PostItem, from your click or a
-- mouse wheel tick (Blizzard's rule: one hardware action each), never by itself. When the
-- game asks for a confirmation (ConfirmPostCommodity / ConfirmPostItem), the next click or
-- tick confirms. The price never goes below the rule's floor or what a vendor pays after
-- the cut (sell protection, as SellGuard.lua does on Blizzard's Sell page).
-- Middle-click a row to skip it for this visit; Scroll to post (off at each visit, Esc
-- turns it off) posts the highlighted one with each wheel tick.
---------------------------------------------------------------------------

local AH = C_AuctionHouse
local HOURS_TO_INDEX = { [2] = 1, [8] = 2, [24] = 3 }   -- Forever: 1/2/3 = 2/8/24 hours (Deposits.lua)
local INDEX_HOURS = { 2, 8, 24 }

---------------------------------------------------------------------------
-- The price (pure, for the tests)
---------------------------------------------------------------------------
-- rule: a post rule's fields (Groups.lua RULE_DEFAULTS.post) or nil when posting is off.
-- usual, cheapest: copper or nil. vendorFloor: the least price that still beats a vendor
-- after the cut, or nil. Returns { price, floor, why, skip }.
function ns.PostPrice(rule, usual, cheapest, vendorFloor)
  local out = {}
  if not rule then out.why = "No post rule for it (Off): type a price."; return out end
  local floor = 0
  if usual and usual > 0 and rule.floorPct then floor = math.floor(usual * rule.floorPct / 100) end
  if vendorFloor and vendorFloor > floor then floor = vendorFloor end
  out.floor = floor > 0 and floor or nil
  local price
  if cheapest and cheapest > 0 then
    price = cheapest - (rule.undercut or 0)
    out.why = (rule.undercut or 0) > 0 and ("%s under the cheapest (%s)"):format(ns.MoneyPlain(rule.undercut), ns.MoneyPlain(cheapest))
      or ("the same as the cheapest (%s)"):format(ns.MoneyPlain(cheapest))
  elseif usual and usual > 0 and rule.start ~= "cheapest" then
    price = usual
    out.why = "the usual price (none listed now)"
  else
    out.why = "No price yet: scan, or type one."
    return out
  end
  if out.floor and price < out.floor then
    if rule.belowFloor == "floor" then
      price = out.floor
      out.why = ("your floor (the cheapest, %s, is under it)"):format(ns.MoneyPlain(cheapest or 0))
    else
      out.skip = true
      out.why = ("Not posted: the cheapest (%s) is under your floor (%s)."):format(ns.MoneyPlain(cheapest or 0), ns.MoneyPlain(out.floor))
    end
  end
  out.price = math.max(1, math.floor(price))
  return out
end

-- The least price each that brings at least what a vendor pays, after the cut.
function ns:PostVendorFloor(id)
  local vendor = ns:GetSellPrice(id)
  if not vendor or vendor <= 0 then return nil end
  local cut = (ns.neutralAH and 15 or (ns.db.settings.ahCut or 5)) / 100
  local p = math.max(1, math.floor(vendor / (1 - cut)))
  for _ = 1, 5 do
    if ns:AfterCut(p, ns.neutralAH) >= vendor then break end
    p = p + 1
  end
  return p
end

local function usualOf(id)
  local stats = ns.PriceStats and ns:PriceStats(id, "month")
  if stats and stats.points and stats.points >= 3 and stats.usual then return math.floor(stats.usual) end
  local u = ns.UsualPrice and ns:UsualPrice(id)
  return u and math.floor(u) or nil
end

local function cheapestOf(id, link)
  local rec = (ns.db.prices[ns.MarketKey()] or {})[id]
  local cheapest = rec and not rec.none and rec.m or nil
  -- Only a recent price (Settings: maxAgeHours, 12 by default): an old cheapest may have
  -- sold long ago, and undercutting it would give gold away. Then the usual price is used.
  local maxAge = (ns.db.settings.maxAgeHours or 12) * 3600
  if cheapest and rec.t and time() - rec.t > maxAge then cheapest = nil end
  -- Gear: this version's cheapest ("of the Monkey"), as the price helper does, only if
  -- that version's own price is recent (Codex review, November 15: a fresh search of the
  -- item kept an old version price alive). A version with no recent price of its own has
  -- no cheapest: the usual price and the floor decide until the lookup brings the real one.
  if link and rec and ns.VersionOfLink and ns.SuffixPrice then
    local suffix = ns:VersionOfLink(id, link)
    if suffix then
      local m, _, t = ns:SuffixPrice(id, suffix)
      if m and m > 0 and t and time() - t <= maxAge then cheapest = m else cheapest = nil end
    end
  end
  return cheapest, rec
end

---------------------------------------------------------------------------
-- Your bags
---------------------------------------------------------------------------
local entries = {}   -- the list: { id, count, link, bag, slot, gear, group, groupName, mark, price... }
local cur = 1        -- the highlighted one
local skipped = {}   -- [key] = true: middle-clicked, for this visit
local posted = {}    -- [key] = true: posted this visit
local edits = {}     -- [key] = { price, qty, hours } typed in this visit
local live = {}      -- [key] = the listings now: { market, t, rows, total, cheapest } or { market, t, failed = true }
local visit = 0      -- counts auction house visits: a lookup from an earlier one is dropped
-- The listings looked up at this auction house (Codex, November 15: a lookup at Booty Bay
-- must never price a post at the faction auction house). Cleared each visit too.
local function liveFor(k)
  local l = live[k]
  if l and l.market == ns.MarketKey() then return l end
end
local frame
local scrollPost = false
local pending        -- a post waiting for the game's confirmation: { fn, args, key, price, qty, hours, bag, slot }

-- Commodities are one entry per item; anything else (gear, bags, recipes) one per copy,
-- since each is posted on its own (Codex review, November 15: two bags made one entry and
-- one post retired both). A copy's key carries its link, so a different copy sorted into
-- the same slot is never taken for it, nor given its typed price.
local function keyOf(e)
  if e.single then return (e.link or tostring(e.id)) .. "@" .. e.bag .. ":" .. e.slot end
  return tostring(e.id)
end

local MARK = { ah = "Post", middle = "Post", keep = "Keep", vendor = "Vendor", de = "Disenchant" }
local MARK_COLOR = { Post = { 0.62, 0.91, 0.86 }, Keep = { 0.73, 0.74, 0.78 }, Vendor = { 0.94, 0.83, 0.54 },
  Disenchant = { 0.82, 0.66, 0.96 }, Skipped = { 0.55, 0.55, 0.55 }, Posted = { 0.5, 0.83, 0.61 } }

local function groupFor(id)
  for _, gid in ipairs(ns.ItemGroups and ns:ItemGroups(id) or {}) do
    local info = ns:GroupInfo(gid)
    if info and info.kind == "builtin" then
      local parent = info.parent and ns:GroupInfo(info.parent)
      return gid, parent and (parent.name .. " · " .. info.name) or info.name
    end
  end
  return "misc", "Miscellaneous"
end

local orderOf = {}
for i, g in ipairs(ns.BUILTIN_GROUPS or {}) do orderOf[g.id] = i end

local function readBags()
  local byId, list = {}, {}
  local CC = C_Container
  if not (CC and CC.GetContainerNumSlots and CC.GetContainerItemInfo) then return list end
  local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
  for bag = 0, last do
    for slot = 1, CC.GetContainerNumSlots(bag) or 0 do
      local info = CC.GetContainerItemInfo(bag, slot)
      if info and info.itemID and not info.isBound and (info.quality or 1) > 0 then
        local id = info.itemID
        local gear = ns.IsGearItem and ns:IsGearItem(id) or false
        local commodity = false
        if not gear and AH and AH.GetItemCommodityStatus and ItemLocation and ItemLocation.CreateFromBagAndSlot then
          local ok, st = pcall(AH.GetItemCommodityStatus, ItemLocation:CreateFromBagAndSlot(bag, slot))
          commodity = ok and st == 2
        end
        if not commodity then
          list[#list + 1] = { id = id, count = gear and 1 or (info.stackCount or 1), link = info.hyperlink,
            bag = bag, slot = slot, gear = gear, single = true }
        elseif byId[id] then
          byId[id].count = byId[id].count + (info.stackCount or 1)
        else
          byId[id] = { id = id, count = info.stackCount or 1, link = info.hyperlink, bag = bag, slot = slot }
          list[#list + 1] = byId[id]
        end
      end
    end
  end
  return list
end

local function verdictMark(e)
  if not (ns.SellVerdict and ns.SellFacts) then return "Post" end
  local ok, v = pcall(function() return ns.SellVerdict(ns:SellFacts(e.id, false, true)) end)
  if not ok or not v then return "Post" end
  if v.deFirst or v.kind == "de" then return "Disenchant" end
  return MARK[v.kind] or "Post"
end

-- Works out each entry's price and quantity from its rule (and what you typed).
local function price(e)
  -- (Its own lines: "ns.RuleFor and ns:RuleFor(...)" would keep only the first value.)
  local rule, from
  if ns.RuleFor then rule, from = ns:RuleFor(e.id, "post") else rule = ns.RULE_DEFAULTS and ns.RULE_DEFAULTS.post end
  e.rule, e.ruleFrom = rule, from or "Default"
  e.usual = usualOf(e.id)
  e.cheapest, e.rec = cheapestOf(e.id, e.gear and e.link)
  -- The listings now, once looked up (below): the cheapest that isn't yours.
  local l = liveFor(keyOf(e))
  e.live = l and not l.failed and l or nil
  if e.live then e.cheapest = e.live.cheapest end
  local p = ns.PostPrice(rule, e.usual, e.cheapest, ns:PostVendorFloor(e.id))
  e.suggested, e.floor, e.why, e.skipRule = p.price, p.floor, p.why, p.skip
  local typed = edits[keyOf(e)] or {}
  e.price = typed.price or e.suggested
  e.hours = typed.hours or (rule and rule.hours) or 24
  local keep = (rule and rule.keep) or 0
  e.qty = typed.qty or math.max(0, e.count - keep)
  if e.single then e.qty = math.min(e.qty, e.count) end
end

local refresh

function ns:RefreshPost()
  local list = readBags()
  for _, e in ipairs(list) do
    e.group, e.groupName = groupFor(e.id)
    e.mark = verdictMark(e)
    price(e)
  end
  local wantAll = frame and frame.showAll
  local out = {}
  for _, e in ipairs(list) do
    if wantAll or e.mark == "Post" then out[#out + 1] = e end
  end
  table.sort(out, function(a, b)
    local oa, ob = orderOf[a.group] or 999, orderOf[b.group] or 999
    if oa ~= ob then return oa < ob end
    local na, nb = ns.ItemName(a.id), ns.ItemName(b.id)
    if na ~= nb then return na < nb end
    return keyOf(a) < keyOf(b)
  end)
  local wasKey = entries[cur] and keyOf(entries[cur])
  entries = out
  cur = 1
  for i, e in ipairs(entries) do if keyOf(e) == wasKey then cur = i; break end end
  -- Start on one that can be posted.
  local function usable(e) local k = keyOf(e); return not skipped[k] and not posted[k] end
  if entries[cur] and not usable(entries[cur]) then
    for i = 1, #entries do if usable(entries[i]) then cur = i; break end end
  end
  if refresh then refresh() end
end

---------------------------------------------------------------------------
-- Posting
---------------------------------------------------------------------------
local function locationOf(e)
  if not (ItemLocation and ItemLocation.CreateFromBagAndSlot) then return end
  local CC = C_Container
  local info = CC.GetContainerItemInfo(e.bag, e.slot)
  -- A copy (gear, bags...) must still be in its slot: the same item, the same link, not
  -- bound (Codex review, November 15: a better version sorted into the slot would have been
  -- posted at the shown one's price). Moved: nothing, and the list is read again.
  if e.single then
    if info and info.itemID == e.id and not info.isBound and info.hyperlink == e.link
      and (info.stackCount or 1) >= (e.qty or 1) then
      return ItemLocation:CreateFromBagAndSlot(e.bag, e.slot)
    end
    return
  end
  -- A commodity: any stack of it will do; the slot may have changed since the list was read.
  if not (info and info.itemID == e.id and not info.isBound) then
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
      for slot = 1, CC.GetContainerNumSlots(bag) or 0 do
        local i2 = CC.GetContainerItemInfo(bag, slot)
        if i2 and i2.itemID == e.id and not i2.isBound then
          e.bag, e.slot = bag, slot
          return ItemLocation:CreateFromBagAndSlot(bag, slot)
        end
      end
    end
    return
  end
  return ItemLocation:CreateFromBagAndSlot(e.bag, e.slot)
end

---------------------------------------------------------------------------
-- The listings now (owner, AH15, November 15: the Post tab priced Carved Centaur Totem
-- from a scan 2 hours old at 3s 32c while Blizzard's Sell page, which looks the item up,
-- showed the cheapest at 8s 75c). Picking an item searches for it as the Sell page does;
-- the price comes from that, and Post waits for it. The listings show as the Sell page
-- shows them: price each, how many, the seller (yours marked).
---------------------------------------------------------------------------
local LIVE_FRESH = 60   -- seconds a lookup counts as current
local asking            -- the lookup on its way: { key, id, itemKey, commodity, tok, tries }
local askTok = 0
local waitingFor        -- the key a busy-retry is waiting to look up
local SORTS
local function sorts()
  if not SORTS and Enum and Enum.AuctionHouseSortOrder then
    SORTS = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
  end
  return SORTS or {}
end

local function sellerText(r)
  local o = r.owners and r.owners[1]
  if r.allMine or o == "player" then return "You", true end
  if (r.sellers or 0) > 1 then return ("%d sellers"):format(r.sellers) end
  return type(o) == "string" and o or ""
end

-- Reads the results of the lookup on its way. final: the wait is over, take what's there.
local function readLive(final)
  local a = asking
  if not a then return end
  -- A reply from an earlier visit or another auction house is not this one's listings.
  if a.visit ~= visit or a.market ~= ns.MarketKey() then asking = nil; return end
  local rows, total, n, complete = {}, 0, 0, false
  if a.commodity then
    n = AH.GetNumCommoditySearchResults(a.id) or 0
    complete = AH.HasFullCommoditySearchResults and AH.HasFullCommoditySearchResults(a.id) or false
    for i = 1, n do
      local r = AH.GetCommoditySearchResultInfo(a.id, i)
      if r and r.unitPrice then
        local q = r.quantity or 0
        rows[#rows + 1] = { price = r.unitPrice, qty = q, sellers = r.totalNumberOfOwners, owners = r.owners,
          allMine = (r.numOwnerItems or 0) >= q and q > 0, someMine = (r.numOwnerItems or 0) > 0 }
        total = total + q
      end
    end
  else
    -- The reply's key can differ in detail from the one asked for (BuyQueue.lua).
    local key = a.replyKey or a.itemKey
    n = AH.GetNumItemSearchResults(key) or 0
    complete = AH.HasFullItemSearchResults and AH.HasFullItemSearchResults(key) or false
    for i = 1, n do
      local r = AH.GetItemSearchResultInfo(key, i)
      if r and r.buyoutAmount and r.buyoutAmount > 0 then
        local q = math.max(r.quantity or 1, 1)
        rows[#rows + 1] = { price = r.buyoutAmount, qty = q, sellers = r.totalNumberOfOwners, owners = r.owners,
          allMine = r.containsOwnerItem and true or false, refused = ns.CantBuyOut and ns:CantBuyOut(r) or false }
        total = total + q
      end
    end
  end
  if n == 0 and not complete and not final then return end   -- still coming
  if n == 0 and not complete then
    live[a.key] = { market = ns.MarketKey(), t = time(), failed = true }
  else
    table.sort(rows, function(x, y) return x.price < y.price end)
    local cheapest
    for _, r in ipairs(rows) do
      if not r.allMine and not r.refused then cheapest = r.price; break end
    end
    live[a.key] = { market = ns.MarketKey(), t = time(), rows = rows, total = total, cheapest = cheapest }
  end
  if final or complete then asking = nil end
  for _, e in ipairs(entries) do
    if keyOf(e) == a.key then price(e) end
  end
  if refresh then refresh() end
end

-- Looks the item up (unless a lookup from the last minute is there). force: Refresh.
local function lookUp(e, force)
  if not (e and AH and AH.SendSearchQuery and AH.MakeItemKey) then return end
  local k = keyOf(e)
  local l = liveFor(k)
  if not force and l and time() - l.t < LIVE_FRESH then return end
  if asking and asking.key == k and GetTime() - asking.at < 5 then return end
  if AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady() then
    -- Busy (Live watch searches too): try again shortly, while it's still the one shown.
    if waitingFor == k then return end   -- a retry is already on its way
    e.lookTries = (e.lookTries or 0) + 1
    if e.lookTries > 20 then live[k] = { market = ns.MarketKey(), t = time(), failed = true }; e.lookTries = 0; if refresh then refresh() end; return end
    local v = visit
    waitingFor = k
    C_Timer.After(0.5, function()
      waitingFor = nil
      if v ~= visit then return end
      local now = entries[cur]
      if now and keyOf(now) == k then lookUp(now, force) end
    end)
    return
  end
  e.lookTries = 0
  local loc = locationOf(e)
  local itemKey
  if loc and AH.GetItemKeyFromItem then
    local ok, ik = pcall(AH.GetItemKeyFromItem, loc)
    if ok and type(ik) == "table" then itemKey = ik end
  end
  itemKey = itemKey or AH.MakeItemKey(e.id)
  local commodity = loc and AH.GetItemCommodityStatus and AH.GetItemCommodityStatus(loc) == 2 or false
  askTok = askTok + 1
  local tok = askTok
  asking = { key = k, id = e.id, itemKey = itemKey, commodity = commodity, at = GetTime(), tok = tok,
    visit = visit, market = ns.MarketKey() }
  -- A moment's room from Live watch's own searches, as the Buy queue gets (Prices.lua).
  ns.queueBusyUntil = math.max(ns.queueBusyUntil or 0, GetTime() + 1.5)
  ns.postSending = true
  local ok = pcall(AH.SendSearchQuery, itemKey, sorts(), true)
  ns.postSending = false
  if not ok then
    asking = nil
    live[k] = { market = ns.MarketKey(), t = time(), failed = true }
  else
    -- Items with nothing listed may never get a reply.
    C_Timer.After(4, function() if asking and asking.tok == tok then readLive(true) end end)
  end
  if refresh then refresh() end
end

ns:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID)
  if asking and asking.commodity and asking.id == itemID then readLive(false) end
end)
ns:On("ITEM_SEARCH_RESULTS_UPDATED", function(itemKey)
  if asking and not asking.commodity and itemKey and itemKey.itemID == asking.id then
    -- Gear: only the version asked for (its stats), when the reply says which.
    local want = asking.itemKey and asking.itemKey.itemSuffix or 0
    if (itemKey.itemSuffix or 0) ~= want then return end
    asking.replyKey = itemKey
    readLive(false)
  end
end)

local function say(text) if frame then frame.note:SetText(text or "") end end

local function nextUsable(from, step)
  local i = from
  for _ = 1, #entries do
    i = i + step
    if i < 1 or i > #entries then return from end
    local k = keyOf(entries[i])
    if not skipped[k] and not posted[k] then return i end
  end
  return from
end

-- Post the highlighted item (a click on Post, or a wheel tick with Scroll to post on).
local function postCurrent()
  if pending then
    -- The game asked to confirm the last one: this click or tick confirms it, but only
    -- exactly what was shown when it asked (Codex review, November 15: a price, quantity
    -- or length changed, or the row skipped, would have confirmed the old post).
    local p = pending
    pending = nil
    local e = entries[cur]
    local same = e and keyOf(e) == p.key and e.price == p.price and e.qty == p.qty and e.hours == p.hours
      and not skipped[p.key] and not posted[p.key] and not (e.floor and e.price < e.floor)
      and e.bag == p.bag and e.slot == p.slot
    if same then
      local info = C_Container.GetContainerItemInfo(p.bag, p.slot)
      same = info ~= nil and info.itemID == e.id and (not e.single or info.hyperlink == e.link)
    end
    if not same then
      say("It changed since the game asked to confirm: click Post again.")
      if refresh then refresh() end
      return
    end
    local ok, err = pcall(p.fn, unpack(p.args))
    if not ok then
      say("Couldn't confirm: " .. tostring(err))
      if refresh then refresh() end
      return
    end
    posted[p.key] = true
    say(("Posted %d %s at %s each."):format(p.qty, ns.ItemName(e.id), ns.MoneyPlain(p.price)))
    cur = nextUsable(cur, 1)
    if refresh then refresh() end
    return
  end
  local e = entries[cur]
  if not e then return end
  local k = keyOf(e)
  if skipped[k] or posted[k] then cur = nextUsable(cur, 1); refresh(); return end
  -- Never on an old price: the listings are looked up first (a lookup that got no answer
  -- lets the last scan's price through, said on screen).
  local l = liveFor(k)
  if not l or time() - l.t > 5 * LIVE_FRESH then
    lookUp(e, true)
    say("Checking the listings first: click again in a moment.")
    return
  end
  if not (e.price and e.price > 0) then say("Type a price first."); return end
  if e.floor and e.price < e.floor then
    say(("Under your floor (%s): type a higher price, or change the rule."):format(ns.MoneyPlain(e.floor)))
    return
  end
  if not e.qty or e.qty < 1 then say("Nothing to post (Keep holds them all)."); return end
  if AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady() then
    say("The auction house is busy: try again in a moment.")
    return
  end
  local loc = locationOf(e)
  if not loc then say("Couldn't find it in your bags any more."); ns:RefreshPost(); return end
  local dur = HOURS_TO_INDEX[e.hours] or 3
  local commodity = AH.GetItemCommodityStatus and AH.GetItemCommodityStatus(loc) == 2
  local fn, confirmFn, args
  if commodity then
    fn, confirmFn, args = AH.PostCommodity, AH.ConfirmPostCommodity, { loc, dur, e.qty, e.price }
  else
    -- One copy (its own slot): gear 1, a stack of something else as many as chosen.
    fn, confirmFn, args = AH.PostItem, AH.ConfirmPostItem, { loc, dur, e.qty, nil, e.price }
  end
  if not fn then say("This game client can't post from here: use Blizzard's Sell tab."); return end
  local ok, needsConfirm = pcall(fn, unpack(args))
  if not ok then say("Couldn't post: " .. tostring(needsConfirm)); return end
  if needsConfirm == true and confirmFn then
    pending = { fn = confirmFn, args = args, key = k, price = e.price, qty = e.qty, hours = e.hours, bag = e.bag, slot = e.slot }
    say("The auction house asks you to confirm this one: click Confirm post (or tick the wheel).")
    if refresh then refresh() end
    return
  end
  posted[k] = true
  say(("Posted %d %s at %s each."):format(e.qty, ns.ItemName(e.id), ns.MoneyPlain(e.price)))
  cur = nextUsable(cur, 1)
  if refresh then refresh() end
end
ns.PostCurrent = postCurrent   -- (tests)

---------------------------------------------------------------------------
-- The view
---------------------------------------------------------------------------
local ROW_H, LEFT_W = 18, 340

local function setScrollPost(on)
  scrollPost = on and true or false
  if not frame then return end
  frame.scrollSwitch:SetChecked(scrollPost)
  frame:EnableKeyboard(scrollPost)
  frame.listBox:SetBackdropShown(scrollPost)
end

local function row(i)
  local r = frame.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, frame.content)
  r:SetHeight(ROW_H)
  r:RegisterForClicks("LeftButtonUp", "MiddleButtonUp")
  r.bg = T:Fill(r, { 1, 1, 1, 0 })
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.12)
  r.heading = T:Text(r, 10, T.dim)
  r.heading:SetPoint("LEFT", 6, 0)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT", 6, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.mark = T:Text(r, 10)
  r.mark:SetPoint("RIGHT", -4, 0)
  r.mark:SetWidth(66)
  r.mark:SetJustifyH("RIGHT")
  r.price = T:Text(r, 11)
  r.price:SetPoint("RIGHT", r.mark, "LEFT", -6, 0)
  r.name = T:Text(r, 11)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
  r.name:SetPoint("RIGHT", r.price, "LEFT", -6, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r:SetScript("OnClick", function(self, button)
    if not self.index then return end
    local e = entries[self.index]
    if button == "MiddleButton" then
      pending = nil   -- a skip cancels a waiting confirmation (Codex review)
      local k = keyOf(e)
      skipped[k] = not skipped[k] or nil
      if skipped[k] and cur == self.index then cur = nextUsable(cur, 1) end
    else
      cur = self.index
      pending = nil
    end
    refresh()
  end)
  r:SetScript("OnEnter", function(self)
    if not self.index then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local e = entries[self.index]
    if e.link then GameTooltip:SetHyperlink(e.link) else GameTooltip:SetItemByID(e.id) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to post this one next. Middle-click to skip it this visit (again to bring it back).", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.rows[i] = r
  return r
end

local function drawList()
  local lines, lastGroup = {}, nil
  for i, e in ipairs(entries) do
    if e.groupName ~= lastGroup then
      lines[#lines + 1] = { heading = e.groupName }
      lastGroup = e.groupName
    end
    lines[#lines + 1] = { index = i }
  end
  local w = frame.sf:GetWidth() - 12
  for n, line in ipairs(lines) do
    local r = row(n)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(n - 1) * ROW_H)
    r:SetWidth(w)
    r.index = line.index
    if line.heading then
      r.heading:SetText(line.heading:upper())
      r.heading:Show()
      for _, part in ipairs({ r.icon, r.name, r.price, r.mark }) do part:Hide() end
      r.bg:SetColorTexture(1, 1, 1, 0)
      r:EnableMouse(false)
    else
      local e = entries[line.index]
      local k = keyOf(e)
      r:EnableMouse(true)
      r.heading:Hide()
      for _, part in ipairs({ r.icon, r.name, r.price, r.mark }) do part:Show() end
      r.icon:SetTexture(ns:ItemIcon(e.id))
      local label = (posted[k] and "Posted") or (skipped[k] and "Skipped") or e.mark
      r.name:SetText(ns.ItemName(e.id) .. (e.count > 1 and (" x" .. e.count) or ""))
      r.price:SetText(e.price and ns.MoneyPlain(e.price) or "|cff888888-|r")
      local c = MARK_COLOR[label] or MARK_COLOR.Post
      r.mark:SetText(label:upper())
      r.mark:SetTextColor(c[1], c[2], c[3])
      local dim = posted[k] or skipped[k]
      r.name:SetAlpha(dim and 0.45 or 1)
      r.price:SetAlpha(dim and 0.45 or 1)
      r.icon:SetDesaturated(dim and true or false)
      local on = line.index == cur
      r.bg:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], on and 0.22 or 0)
    end
    r:Show()
  end
  for n = #lines + 1, #frame.rows do frame.rows[n]:Hide() end
  frame.content:SetHeight(math.max(#lines * ROW_H, ROW_H))
  frame.sf.UpdateScrollBar()
  frame.emptyList:SetShown(#entries == 0)
end

-- The listings table: the listings now (or, until they come, the last scan's), with a
-- line where yours would go.
local LT_ROW = 18
local function listingRows(e)
  local l = liveFor(keyOf(e))
  if l and not l.failed then return l.rows, true end
  local rows, ladder = {}, e.rec and e.rec.l
  if ladder then
    local prev = 0
    for p, n in ladder:gmatch("(%d+):(%d+)") do
      p, n = tonumber(p), tonumber(n)
      rows[#rows + 1] = { price = p, qty = n - prev }
      prev = n
    end
  end
  return rows, false
end

local function drawListings(e)
  local lt = frame.item.lt
  local k = keyOf(e)
  local l = liveFor(k)
  local looking = asking and asking.key == k
  local rows, now = listingRows(e)
  if now then
    lt.title:SetText("Listed now")
    lt.info:SetText(("%d available · checked %s"):format(l.total or 0, time() - l.t < 60 and "just now" or ns.Age(l.t)))
  else
    local when = e.rec and e.rec.t
    lt.title:SetText(when and ("At the last scan (%s)"):format(ns.Age and ns.Age(when) or "") or "Listings")
    lt.info:SetText(looking and "|cffffd100Looking it up...|r" or (l and l.failed) and "|cffff8080Couldn't check now|r" or "")
  end
  -- Your price, in its place among them.
  local shown = {}
  local placed = false
  for _, r in ipairs(rows) do
    if not placed and e.price and r.price > e.price then
      shown[#shown + 1] = { yours = true, price = e.price, qty = e.qty or 0 }
      placed = true
    end
    shown[#shown + 1] = r
  end
  if not placed and e.price and #rows > 0 then shown[#shown + 1] = { yours = true, price = e.price, qty = e.qty or 0 } end
  local fit = math.max(3, math.floor(((lt:GetHeight() or 0) - 46) / LT_ROW))
  if (lt:GetHeight() or 0) < 60 then fit = 12 end
  for i = 1, math.max(fit, #lt.rows) do
    local r, d = lt.rows[i], shown[i]
    if i <= fit and d then
      r = r or lt.makeRow(i)
      r.data = d
      r.price:SetText(ns.Money(d.price))
      r.qty:SetText(tostring(d.qty or ""))
      if d.yours then
        r.seller:SetText("|cff9fe8dcYours, if you post now|r")
        r.bg:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.22)
      else
        local who, mine = sellerText(d)
        r.seller:SetText(mine and "|cff9fe8dcYou|r" or (d.refused and (who .. " |cff888888(can't be bought)|r")) or who)
        r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
      end
      r:Show()
    elseif r then
      r:Hide()
    end
  end
  local more = #shown - fit
  lt.more:SetText(more > 0 and ("and %d more"):format(more) or "")
  lt.empty:SetShown(#rows == 0)
  lt.empty:SetText(looking and "Looking it up..." or now and "None listed now: yours would be the only one."
    or "Nothing saved for it yet.")
end

local function drawItem()
  local e = entries[cur]
  local f = frame.item
  f:SetShown(e ~= nil)
  frame.none:SetShown(e == nil)
  if not e then return end
  f.icon:SetTexture(ns:ItemIcon(e.id))
  f.name:SetText(ns.ItemName(e.id))
  local bits = { ("%d in your bags"):format(e.count) }
  if e.usual then bits[#bits + 1] = "usual " .. ns.Money(e.usual) end
  f.sub:SetText(table.concat(bits, " · "))
  if not f.qty:HasFocus() then f.qty:SetText(tostring(e.qty or 0)) end
  f.price:SetValue(e.price)
  f.hours:SetValue(e.hours)
  -- What Blizzard's Sell page shows (deposit, total price), and what you get.
  local dur = HOURS_TO_INDEX[e.hours] or 3
  local deposit = ns.AuctionDeposit and select(1, ns:AuctionDeposit(e.id, math.max(e.qty or 1, 1), dur)) or 0
  local get = e.price and (ns:AfterCut(e.price, ns.neutralAH) * (e.qty or 0)) or nil
  f.deposit:SetText(ns.Money(deposit or 0))
  f.total:SetText(e.price and ns.Money(e.price * (e.qty or 0)) or "-")
  f.get:SetText(get and ns.Money(get) or "-")
  local k = keyOf(e)
  local l = liveFor(k)
  local why = e.why or ""
  if e.price and e.suggested and e.price ~= e.suggested then why = "your price (suggested " .. ns.MoneyPlain(e.suggested) .. ")"
  elseif not e.live and e.cheapest then why = why .. ", at the last scan" end
  f.why:SetText(("%s%s. |cff9fe8dcRule from: %s.|r"):format(why:sub(1, 1):upper(), why:sub(2), e.ruleFrom or "Default"))
  f.post:SetText(pending and "Confirm post" or not l and "Checking..." or "Post")
  f.post:SetEnabled(pending ~= nil or (l ~= nil and not posted[k] and not skipped[k] and e.price ~= nil and (e.qty or 0) > 0))
  local left = 0
  for _, x in ipairs(entries) do
    local xk = keyOf(x)
    if not posted[xk] and not skipped[xk] then left = left + 1 end
  end
  f.posFrom:SetText(("%d of %d · %d left"):format(cur, #entries, left))
  drawListings(e)
  -- Look it up (no-op while the last lookup is fresh).
  lookUp(e)
end

refresh = function()
  if not (frame and frame:IsVisible()) then return end
  drawList()
  drawItem()
end

local function build(host)
  frame = CreateFrame("Frame", "ForeverLedgerPost", host)
  frame:SetAllPoints(host)
  frame:EnableMouse(true)
  T:Fill(frame, T.bg)
  frame:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" and scrollPost then
      setScrollPost(false)
      self:SetPropagateKeyboardInput(false)
    else
      self:SetPropagateKeyboardInput(true)
    end
  end)

  -- Left: your bags.
  local listBox = CreateFrame("Frame", nil, frame)
  listBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -40)
  listBox:SetPoint("BOTTOMLEFT", 8, 8)
  listBox:SetWidth(LEFT_W)
  T:Border(listBox)
  -- A glow round the list while Scroll to post is on, as round the Buy queue.
  local glow = listBox:CreateTexture(nil, "BACKGROUND")
  glow:SetPoint("TOPLEFT", -2, 2)
  glow:SetPoint("BOTTOMRIGHT", 2, -2)
  glow:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.18)
  glow:Hide()
  function listBox:SetBackdropShown(on) glow:SetShown(on) end
  frame.listBox = listBox
  frame.sf, frame.content = T:Scroll(listBox)
  frame.sf:SetPoint("TOPLEFT", 2, -2)
  frame.sf:SetPoint("BOTTOMRIGHT", -3, 3)
  local scrollList = frame.sf:GetScript("OnMouseWheel")
  frame.sf:SetScript("OnMouseWheel", function(self, delta)
    if scrollPost then postCurrent() return end
    if scrollList then scrollList(self, delta) end
  end)
  frame.rows = {}
  frame.emptyList = T:Text(listBox, 12, T.dim)
  frame.emptyList:SetPoint("CENTER")
  frame.emptyList:SetWidth(LEFT_W - 30)
  frame.emptyList:SetText("Nothing in your bags to post. Show: Everything lists all you could.")

  -- Above the list: what's shown, how many left, Scroll to post.
  frame.showBtn = T:Button(frame, "Show: Worth posting", 150, function(self)
    frame.showAll = not frame.showAll
    self:SetText(frame.showAll and "Show: Everything" or "Show: Worth posting")
    ns:RefreshPost()
  end, 22)
  frame.showBtn:SetPoint("TOPLEFT", 8, -10)   -- (OnShow: right of the portrait if it's there)
  frame.scrollSwitch = T:Check(frame, function(b) setScrollPost(b:GetChecked()) end, "switch")
  frame.scrollSwitch:SetPoint("LEFT", frame.showBtn, "RIGHT", 14, 0)
  frame.scrollSwitch.label:SetText("Scroll to post")
  frame.scrollSwitch:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Scroll to post", 1, 1, 1)
    GameTooltip:AddLine("While it's on, each mouse wheel tick over your bag list posts the highlighted item at the price shown, then moves to the next. Off, or Esc: the wheel just scrolls. It starts off every visit. Middle-click a row to skip it.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  frame.scrollSwitch:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Right: the item being posted.
  local f = CreateFrame("Frame", nil, frame)
  f:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 12, 30)
  f:SetPoint("BOTTOMRIGHT", -10, 8)
  frame.item = f
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(32, 32)
  f.icon:SetPoint("TOPLEFT", 0, 0)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.name = T:Text(f, 15)
  f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -1)
  f.name:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  f.name:SetJustifyH("LEFT")
  f.name:SetWordWrap(false)
  f.sub = T:Text(f, 11, T.dim)
  f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
  f.sub:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  f.sub:SetJustifyH("LEFT")

  local function label(text, anchor, x)
    local fs = T:Text(f, 10, T.dim)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, -12)
    fs:SetText(text)
    return fs
  end
  local qtyL = label("How many", f.icon)
  f.qty = T:EditBox(f, 60)
  f.qty:SetPoint("TOPLEFT", qtyL, "BOTTOMLEFT", 0, -3)
  f.qty:SetNumeric(true)
  f.qty:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    local e = entries[cur]
    if not e then return end
    local n = math.min(tonumber(self:GetText()) or 0, e.count)
    edits[keyOf(e)] = edits[keyOf(e)] or {}
    pending = nil   -- an edit cancels a waiting confirmation
    edits[keyOf(e)].qty = n
    e.qty = n
    drawItem()
  end)
  f.max = T:Button(f, "Max", 40, function()
    local e = entries[cur]
    if not e then return end
    edits[keyOf(e)] = edits[keyOf(e)] or {}
    pending = nil   -- an edit cancels a waiting confirmation
    edits[keyOf(e)].qty = e.count
    e.qty = e.gear and 1 or e.count
    f.qty:SetText(tostring(e.qty))
    drawItem()
  end, 22)
  f.max:SetPoint("LEFT", f.qty, "RIGHT", 4, 0)

  local priceL = T:Text(f, 10, T.dim)
  priceL:SetPoint("LEFT", qtyL, "LEFT", 130, 0)
  priceL:SetText("Price each")
  f.price = T:MoneyBox(f, function(v)
    local e = entries[cur]
    if not e or not v then return end
    edits[keyOf(e)] = edits[keyOf(e)] or {}
    pending = nil   -- an edit cancels a waiting confirmation
    edits[keyOf(e)].price = v
    e.price = v
    drawList()
    drawItem()
  end)
  f.price:SetPoint("TOPLEFT", priceL, "BOTTOMLEFT", 0, -3)

  local hoursL = T:Text(f, 10, T.dim)
  hoursL:SetPoint("LEFT", priceL, "LEFT", 120, 0)
  hoursL:SetText("How long")
  f.hours = T:Choice(f, { { value = 2, label = "2h" }, { value = 8, label = "8h" }, { value = 24, label = "24h" } }, function(v)
    local e = entries[cur]
    if not e then return end
    edits[keyOf(e)] = edits[keyOf(e)] or {}
    pending = nil   -- an edit cancels a waiting confirmation
    edits[keyOf(e)].hours = v
    e.hours = v
    drawItem()
  end)
  f.hours:SetPoint("TOPLEFT", hoursL, "BOTTOMLEFT", 0, -3)

  -- Deposit, total price and what you get, side by side under the boxes.
  local depL = label("Deposit", f.qty, 0)
  f.deposit = T:Text(f, 13)
  f.deposit:SetPoint("TOPLEFT", depL, "BOTTOMLEFT", 0, -3)
  local totalL = T:Text(f, 10, T.dim)
  totalL:SetPoint("LEFT", depL, "LEFT", 130, 0)
  totalL:SetText("Total price")
  f.total = T:Text(f, 13)
  f.total:SetPoint("TOPLEFT", totalL, "BOTTOMLEFT", 0, -3)
  local getL = T:Text(f, 10, T.dim)
  getL:SetPoint("LEFT", totalL, "LEFT", 120, 0)
  getL:SetText("You get after the cut")
  f.get = T:Text(f, 14, { 0.88, 0.72, 0.35 })
  f.get:SetPoint("TOPLEFT", getL, "BOTTOMLEFT", 0, -3)
  f.why = T:Text(f, 11, T.dim)
  f.why:SetPoint("TOPLEFT", f.deposit, "BOTTOMLEFT", 0, -10)
  f.why:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  f.why:SetJustifyH("LEFT")

  f.prev = T:Button(f, "Previous", 80, function() cur = nextUsable(cur, -1); pending = nil; refresh() end)
  f.prev:SetPoint("TOPLEFT", f.why, "BOTTOMLEFT", 0, -10)
  f.skip = T:Button(f, "Skip", 70, function()
    local e = entries[cur]
    if e then skipped[keyOf(e)] = true end
    pending = nil
    cur = nextUsable(cur, 1)
    refresh()
  end)
  f.skip:SetPoint("LEFT", f.prev, "RIGHT", 6, 0)
  f.post = T:Button(f, "Post", 110, postCurrent, 28)
  f.post:SetPoint("TOPRIGHT", f.why, "BOTTOMRIGHT", 0, -8)
  f.posFrom = T:Text(f, 11, T.dim)
  f.posFrom:SetPoint("RIGHT", f.post, "LEFT", -10, 0)
  frame.note = T:Text(f, 11, { 0.62, 0.91, 0.86 })
  frame.note:SetPoint("TOPLEFT", f.prev, "BOTTOMLEFT", 0, -8)
  frame.note:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  frame.note:SetJustifyH("LEFT")

  -- The listings, as Blizzard's Sell page lists them: price each, how many, the seller.
  local lt = CreateFrame("Frame", nil, f)
  lt:SetPoint("TOPLEFT", frame.note, "BOTTOMLEFT", 0, -10)
  lt:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  T:Border(lt)
  f.lt = lt
  lt.title = T:Text(lt, 12)
  lt.title:SetPoint("TOPLEFT", 8, -8)
  lt.refresh = T:Button(lt, "Refresh", 70, function()
    local e = entries[cur]
    if e then lookUp(e, true) end
  end, 20)
  lt.refresh:SetPoint("TOPRIGHT", -6, -4)
  lt.info = T:Text(lt, 11, T.dim)
  lt.info:SetPoint("RIGHT", lt.refresh, "LEFT", -8, 0)
  local PRICE_X, PRICE_W, QTY_W, SELLER_X = 8, 120, 70, 220
  local function cells(parent, size, color)
    local p = T:Text(parent, size, color)
    p:SetPoint("LEFT", PRICE_X, 0)
    p:SetWidth(PRICE_W)
    p:SetJustifyH("RIGHT")
    local q = T:Text(parent, size, color)
    q:SetPoint("LEFT", PRICE_X + PRICE_W, 0)
    q:SetWidth(QTY_W)
    q:SetJustifyH("RIGHT")
    local s = T:Text(parent, size, color)
    s:SetPoint("LEFT", SELLER_X, 0)
    s:SetPoint("RIGHT", -8, 0)
    s:SetJustifyH("LEFT")
    s:SetWordWrap(false)
    return p, q, s
  end
  local head = CreateFrame("Frame", nil, lt)
  head:SetHeight(16)
  head:SetPoint("TOPLEFT", 4, -28)
  head:SetPoint("TOPRIGHT", -4, -28)
  local hp, hq, hs = cells(head, 10, T.dim)
  hp:SetText("Price each"); hq:SetText("Available"); hs:SetText("Seller")
  lt.rows = {}
  function lt.makeRow(i)
    local r = CreateFrame("Button", nil, lt)
    r:SetHeight(LT_ROW)
    r:SetPoint("TOPLEFT", 4, -(44 + (i - 1) * LT_ROW))
    r:SetPoint("TOPRIGHT", -4, -(44 + (i - 1) * LT_ROW))
    r.bg = T:Fill(r, { 1, 1, 1, 0 })
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.12)
    r.price, r.qty, r.seller = cells(r, 11)
    -- Click a listing to price yours at it (or under it, if the rule undercuts).
    r:SetScript("OnClick", function(self)
      local e, d = entries[cur], self.data
      if not (e and d and not d.yours) then return end
      local under = (e.rule and e.rule.undercut) or 0
      local p = (d.allMine or sellerText(d) == "You") and d.price or math.max(1, d.price - under)
      local k = keyOf(e)
      edits[k] = edits[k] or {}
      pending = nil   -- an edit cancels a waiting confirmation
      edits[k].price = p
      e.price = p
      refresh()
    end)
    r:SetScript("OnEnter", function(self)
      if not (self.data and not self.data.yours) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local e = entries[cur]
      local under = (e and e.rule and e.rule.undercut) or 0
      GameTooltip:AddLine(under > 0 and ("Click to price yours %s under this one."):format(ns.MoneyPlain(under))
        or "Click to price yours the same as this one.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lt.rows[i] = r
    return r
  end
  lt.more = T:Text(lt, 10, T.dim)
  lt.more:SetPoint("BOTTOMRIGHT", -8, 5)
  lt.empty = T:Text(lt, 11, T.dim)
  lt.empty:SetPoint("TOP", 0, -60)

  frame.none = T:Text(frame, 12, T.dim)
  frame.none:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 14, -10)
  frame.none:SetText("Pick something on the left.")

  frame:SetScript("OnShow", function()
    -- Right of the window's portrait, unless our tabs hid it (AHTabs.lua).
    local hidden = ns.AHPortraitHidden and ns:AHPortraitHidden()
    frame.showBtn:ClearAllPoints()
    frame.showBtn:SetPoint("TOPLEFT", hidden and 8 or 62, -10)
    setScrollPost(false)
    ns:RefreshPost()
  end)
  frame:SetScript("OnHide", function()
    pending = nil
    setScrollPost(false)
  end)
  frame:SetScript("OnSizeChanged", function() refresh() end)
  frame:Hide()
end

-- The view inside our auction house tab (AHTabs.lua).
function ns:PostFrame(host)
  if not frame and host then build(host) end
  return frame
end

-- New bag contents (posted, bought, looted) while the tab is open.
ns:On("BAG_UPDATE_DELAYED", function()
  if frame and frame:IsVisible() then ns:RefreshPost() end
end)

-- Each visit starts afresh: nothing skipped or posted, Scroll to post off, no listings
-- from before (another auction house may have other prices) and no lookup still waiting.
local function newVisit()
  visit = visit + 1
  for k in pairs(live) do live[k] = nil end
  asking, waitingFor = nil, nil
end
ns:On("AUCTION_HOUSE_SHOW", function()
  newVisit()
  skipped, posted, edits, pending, cur = {}, {}, {}, nil, 1
  scrollPost = false
end)
ns:On("AUCTION_HOUSE_CLOSED", function()
  newVisit()
  pending = nil
  scrollPost = false
end)
