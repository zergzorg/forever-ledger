-- GoldMaking.lua: the Gold making tab's data (redesign build step 6, November 15): saved
-- price ladders read back, the filters, the ranking, every finder's results as one list,
-- and "How it adds up" (the cheapest way to get a craft's materials for that many).
local T = ...
local ns, S = T.ns, T.S
local ME = ns.CharKey()
local CLOTH, BOLT, THREAD, BAG, SHIRT, GLOVES = 96001, 96002, 96003, 96004, 96005, 96006

local function money(c) return tostring(c) end

local function price(id, p, ladder, q)
  local key = ns.MarketKey()
  ns.db.prices[key] = ns.db.prices[key] or {}
  ns.db.prices[key][id] = { m = p, a = p, q = q or 50, l = ladder, t = S.now }
end

T.test("Gold making: a saved ladder's running totals become counts at each price", function()
  T.same(ns.LadderLevels("66:2,70:6,90:16"), { { 66, 2 }, { 70, 4 }, { 90, 10 } })
  T.same(ns.LadderLevels(""), {})
  T.same(ns.LadderLevels(nil), {})
  -- A level that adds nothing (an odd saved string) is skipped.
  T.same(ns.LadderLevels("10:3,12:3,15:5"), { { 10, 3 }, { 15, 2 } })
end)

T.test("Gold making: the filters and the chips' counts", function()
  local craft = { kind = "craftVendor", name = "Heavy Silk Bandage", profit = 60 }
  local learn = { kind = "craftVendor", name = "Silk Shirt", profit = 500, unknown = true }
  local flip = { kind = "flip", name = "Elixir of Fortitude", profit = 22 }
  local f = { kind = "all", least = 0, mine = true, search = "" }
  T.ok(ns.GoldRowShown(craft, f))
  T.ok(not ns.GoldRowShown(learn, f), "a recipe nobody knows, with Only recipes my characters know")
  f.mine = false
  T.ok(ns.GoldRowShown(learn, f))
  f.kind = "flip"
  T.ok(ns.GoldRowShown(flip, f)); T.ok(not ns.GoldRowShown(craft, f))
  f.kind = nil   -- the chips count every kind
  T.ok(ns.GoldRowShown(craft, f) and ns.GoldRowShown(flip, f))
  f.least = 50
  T.ok(ns.GoldRowShown(craft, f)); T.ok(not ns.GoldRowShown(flip, f), "22c is under 50c")
  f.least, f.search = 0, "SILK"
  T.ok(ns.GoldRowShown(craft, f)); T.ok(not ns.GoldRowShown(flip, f), "the search ignores case")
  -- Everything leaves Booty Bay out (it needs a trip); its own button shows it.
  -- Profession: crafts of that profession only; disenchanting is Enchanting.
  craft.prof = "First Aid"
  T.ok(ns.GoldRowShown(craft, { kind = "all", least = 0, prof = "First Aid", search = "" }))
  T.ok(not ns.GoldRowShown(craft, { kind = "all", least = 0, prof = "Tailoring", search = "" }))
  T.ok(not ns.GoldRowShown(flip, { kind = "all", least = 0, prof = "Tailoring", search = "" }), "a flip has no profession")
  T.ok(ns.GoldRowShown(flip, { kind = "all", least = 0, prof = "all", search = "" }))
  local bb = { kind = "bootybay", name = "Staff of Jordan", profit = 5000 }
  T.ok(not ns.GoldRowShown(bb, { kind = "all", least = 0, search = "" }))
  T.ok(ns.GoldRowShown(bb, { kind = "bootybay", least = 0, search = "" }))
  T.ok(ns.GoldRowShown(bb, { least = 0, search = "" }), "counted for its own button")
end)

T.test("Gold making: ranked by profit times how many, at most 20", function()
  T.eq(ns.GoldRowTotal({ profit = 100, count = 3 }), 300)
  T.eq(ns.GoldRowTotal({ profit = 100, count = 50 }), 2000)
  T.eq(ns.GoldRowTotal({ profit = 100 }), 2000, "no limit counts as 20")
end)

T.test("Gold making: How it adds up buys the cheap bolts and makes the rest", function()
  ns:ForgetRecipeIndex()   -- (one built by an earlier test file is kept 30 seconds)
  ns.db.recipeBook = { Tailoring = {
    [1] = { n = "Bolt of Test Cloth", out = BOLT, oq = 1, r = { { CLOTH, 4 } } },
  } }
  -- 2 bolts at 66, 4 at 70, 10 at 90; cloth at 18 (a bolt made for 72).
  price(BOLT, 66, "66:2,70:6,90:16", 16)
  price(CLOTH, 18, "18:200", 200)
  ns.db.vendorBuy[THREAD] = { p = 10, n = 1, t = S.now, src = "merchant" }
  local row = { kind = "craftAH", s = { opt = { kind = "craft",
    rec = { n = "Test Bag", out = BAG, oq = 1, r = { { BOLT, 4 }, { THREAD, 1 } } },
    next = { kind = "ah", value = 600 } } } }
  local p = ns:GoldPlan(row, 5)
  T.eq(p.total, 2 * 66 + 4 * 70 + 14 * 72 + 5 * 10)
  T.eq(p.plan[BOLT].bought, 6); T.eq(p.plan[BOLT].made, 14); T.eq(p.plan[BOLT].top, 70)
  T.eq(p.plan[CLOTH].bought, 56); T.eq(p.plan[THREAD].vendor, 5)
  T.eq(p.brings, 600)
  local lines = ns.GoldPlanLines(p.need, p.order, p.plan, function(id) return p.src(id).recipe end, money)
  T.eq(#lines, 3, "bolts, the cloth they're made from, thread")
  T.eq(lines[1].id, BOLT); T.eq(lines[1].depth, 0)
  T.eq(lines[1].head:format("Bolt"), "20 Bolt")
  T.eq(lines[1].text, "buy 6 on the AH, up to 70 (412), make 14")
  T.eq(lines[2].id, CLOTH); T.eq(lines[2].depth, 1)
  T.eq(lines[2].text, "buy 56 on the AH, up to 18 (1008)")
  T.eq(lines[3].id, THREAD); T.eq(lines[3].text, "5 from a vendor (50)")
  -- Not a craft: no plan.
  T.eq(ns:GoldPlan({ kind = "flip", s = { opt = { kind = "vendor" } } }, 5), nil)
end)

T.test("Gold making: shuffles, flips and recipes nobody knows in one list", function()
  local realChars, realBook, realClassic = ns.db.chars, ns.db.recipeBook, ns.CLASSIC_CRAFT_LIST
  S.items[SHIRT] = { name = "Test Shirt", sell = 300 }
  S.items[GLOVES] = { name = "Test Gloves", sell = 200 }
  ns.db.chars = { [ME] = { name = "Tester Veren", realm = ns.RealmName(), faction = "Alliance",
    profs = { Tailoring = { rank = 100, recipes = { [5] = { n = "Test Shirt", out = SHIRT, oq = 1, r = { { CLOTH, 2 } } } } } } } }
  ns.db.recipeBook = { Tailoring = {
    [5] = { n = "Test Shirt", out = SHIRT, oq = 1, r = { { CLOTH, 2 } } },
    [6] = { n = "Test Gloves", out = GLOVES, oq = 1, r = { { CLOTH, 1 } } },
  } }
  ns.CLASSIC_CRAFT_LIST = {}
  price(CLOTH, 50)
  ns:BuildUsageIndex()
  ns:InvalidateValues(true)
  local rows = ns:GoldIdeas()
  local byName = {}
  for _, r in ipairs(rows) do byName[r.name] = r end
  local shirt, gloves = byName["Test Shirt"], byName["Test Gloves"]
  T.ok(shirt, "the known shirt craft")
  T.eq(shirt.kind, "craftVendor"); T.eq(shirt.id, SHIRT); T.eq(shirt.who, "Tester")
  T.eq(shirt.prof, "Tailoring")
  T.eq(shirt.cost, 100); T.eq(shirt.profit, 200); T.eq(shirt.brings, 300)
  T.ok(not shirt.unknown)
  T.ok(gloves, "the gloves: a recipe nobody knows")
  T.eq(gloves.unknown, true); T.eq(gloves.who, "Tailoring")
  T.eq(gloves.profit, 150)
  ns.db.chars, ns.db.recipeBook, ns.CLASSIC_CRAFT_LIST = realChars, realBook, realClassic
  ns:BuildUsageIndex()
  ns:InvalidateValues(true)
end)
