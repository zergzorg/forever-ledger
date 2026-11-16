local _, ns = ...

---------------------------------------------------------------------------
-- The cheapest way to get a number of items, buying or making each one (redesign,
-- Frank's comment on the Gold making mockup, November 15: a Felblood Soul Bag needs 4
-- Bolts of Runecloth: buy the few cheap bolts listed, make the rest from Runecloth, and
-- never count both the bolts and the cloth). Pure, for the tests; Gold making and
-- shopping lists will call it.
--
-- Each unit is filled from whichever is cheapest next:
--   made already  a unit left over from a batch made earlier in the plan (paid for)
--   your bags     at what they'd sell for (opts.ownedFree: at no cost)
--   the AH        the next listing on its price ladder (cheapest first; each used once)
--   a vendor      its price, as many as wanted
--   a craft       one more batch, tried out first on a copy of the plan so far: its
--                 materials come from the same listings, bags and leftovers the rest of
--                 the plan uses (never the same cheap listing twice), and the whole batch
--                 is paid for, shared over the units still needed (Codex review, November
--                 15: one needed, 20c on the AH, a batch of 10 for 100c must buy)
-- so a thin cheap end on the auction house is used, then making takes over when that
-- gets dearer. Every unit is counted once, bought or made, never both.
-- When buying the next unit is cheaper than a batch but a batch could be made, the rest of
-- what's needed is worked out both ways (buy this one, or make a batch now) and the cheaper
-- whole is kept (Codex review, November 15: a 49c bolt then 10s ones, against a batch of 2
-- for 1s). Inside that look ahead the plan is filled unit by unit, so it stays quick.
--
-- sourceOf(id) returns { ladder = { { price, count }, ... } (cheapest first) or nil,
--   vendor = copper each or nil, recipe = { makes = n, mats = { { id, qty }, ... } } or
--   nil, owned = count in your bags or nil, ownedValue = copper each or nil }.
-- need = { [id] = units }. Returns total copper (nil if something can't be had) and the
-- plan: { [id] = { owned = n, bought = n, boughtCost = c, vendor = n, vendorCost = c,
--   made = n, top = highest AH price paid } }.
---------------------------------------------------------------------------
local MAX_DEPTH = 4

function ns.CraftPlan(need, sourceOf, opts)
  opts = opts or {}
  local cache = {}
  local function src(id)
    local s = cache[id]
    if s == nil then
      s = sourceOf(id) or {}
      cache[id] = s
    end
    return s
  end

  -- The plan so far: where each item's ladder is up to, bags left, units made and not yet
  -- used, and the plan's counts. A copy (for trying a craft out) shares nothing.
  local function newState() return { pos = {}, owned = {}, left = {}, plan = {} } end
  local function copy(st)
    local c = newState()
    for id, p in pairs(st.pos) do c.pos[id] = { level = p.level, used = p.used } end
    for id, n in pairs(st.owned) do c.owned[id] = n end
    for id, n in pairs(st.left) do c.left[id] = n end
    return c
  end
  local function posOf(st, id)
    local p = st.pos[id]
    if not p then p = { level = 1, used = 0 }; st.pos[id] = p end
    return p
  end
  local function ownedOf(st, id)
    if st.owned[id] == nil then st.owned[id] = src(id).owned or 0 end
    return st.owned[id]
  end
  local function entry(st, id)
    st.plan[id] = st.plan[id] or { owned = 0, bought = 0, boughtCost = 0, vendor = 0, vendorCost = 0, made = 0 }
    return st.plan[id]
  end
  -- The next AH listing's price (its place on the ladder moves past used-up levels).
  local function nextListing(st, id)
    local ladder = src(id).ladder or {}
    local p = posOf(st, id)
    while ladder[p.level] and p.used >= ladder[p.level][2] do p.level, p.used = p.level + 1, 0 end
    return ladder[p.level] and ladder[p.level][1] or nil
  end

  local take
  -- One batch of id: its materials taken in st. The copper, or nil if they can't be had.
  local function makeBatch(st, id, depth, simple)
    local total = 0
    for _, m in ipairs(src(id).recipe.mats or {}) do
      local c = take(st, m[1], m[2], depth + 1, simple)
      if not c then return nil end
      total = total + c
    end
    return total
  end

  -- One unit of id the chosen way (how: "ah", "vendor" or "craft"), in st. The copper.
  local function takeOne(st, id, how, depth, simple)
    local s, e = src(id), entry(st, id)
    if how == "ah" then
      local listing = nextListing(st, id)
      local p = posOf(st, id)
      p.used = p.used + 1
      e.bought, e.boughtCost = e.bought + 1, e.boughtCost + listing
      e.top = math.max(e.top or 0, listing)
      return listing
    elseif how == "vendor" then
      e.vendor, e.vendorCost = e.vendor + 1, e.vendorCost + s.vendor
      return s.vendor
    end
    local makes = math.max(s.recipe.makes or 1, 1)
    local batch = makeBatch(st, id, depth, simple)
    if not batch then return nil end
    e.made = e.made + makes
    st.left[id] = (st.left[id] or 0) + makes - 1   -- this unit is one of them
    return batch
  end

  -- Takes n units of id in st, cheapest first. The copper, or nil if they can't be had.
  -- simple: no looking ahead (used inside a look ahead, so it stays quick).
  take = function(st, id, n, depth, simple)
    local s = src(id)
    local e = entry(st, id)
    local total = 0
    for i = 1, n do
      if (st.left[id] or 0) > 0 then
        st.left[id] = st.left[id] - 1   -- made earlier in the plan, paid for then
      elseif ownedOf(st, id) > 0 then
        st.owned[id] = st.owned[id] - 1
        e.owned = e.owned + 1
        total = total + (opts.ownedFree and 0 or (s.ownedValue or 0))
      else
        local listing = nextListing(st, id)
        local best, how = listing, "ah"
        if s.vendor and (not best or s.vendor < best) then best, how = s.vendor, "vendor" end
        local makes = s.recipe and math.max(s.recipe.makes or 1, 1)
        local canMake = false
        if s.recipe and depth < MAX_DEPTH then
          local batch = makeBatch(copy(st), id, depth, true)
          if batch then
            canMake = true
            -- The whole batch, over the units still needed here (a leftover may be wasted).
            local each = batch / math.min(makes, n - i + 1)
            if not best or each < best then best, how = each, "craft" end
          end
        end
        if not best then return nil end
        -- Buying this one looks cheaper, but a batch now may fill the rest for less (Codex
        -- review, November 15: need 2, one listed at 49c then 10s, a batch of 2 for 1s:
        -- buying the 49c one, then making a whole batch for the other, came to 1s 49c).
        -- So the rest of what's needed is worked out both ways and the cheaper kept.
        if not simple and canMake and how ~= "craft" and n - i >= 1 then
          local a, b = copy(st), copy(st)
          local ca = takeOne(a, id, how, depth, true)
          local ra = ca and take(a, id, n - i, depth, true)
          local cb = takeOne(b, id, "craft", depth, true)
          local rb = cb and take(b, id, n - i, depth, true)
          if cb and rb and not (ca and ra and ca + ra <= cb + rb) then how = "craft" end
        end
        local c = takeOne(st, id, how, depth, simple)
        if not c then return nil end
        total = total + c
      end
    end
    return total
  end

  local st = newState()
  local total = 0
  for id, n in pairs(need) do
    local c = take(st, id, n, 0)
    if not c then return nil, st.plan end
    total = total + c
  end
  return math.floor(total + 0.5), st.plan
end
