-- Writs.lua: Craftsman's Writs (Frank, November 16): the order a writ item is, and what
-- filling it costs per point of reputation.
local T = ...
local ns, S = T.ns, T.S

T.test("Writs: 150 orders, each with a profession, tier and item", function()
  T.eq(#ns.WRITS, 150)
  local per = {}
  for _, e in ipairs(ns.WRITS) do
    T.ok(e.item and e.prof and ns.WRIT_TIERS[e.tier], "order " .. e.n)
    per[e.prof] = (per[e.prof] or 0) + 1
  end
  for _, p in ipairs({ "Alchemy", "Blacksmithing", "Engineering", "Leatherworking", "Tailoring" }) do T.eq(per[p], 30, p) end
end)

T.test("Writs: a writ item is found by its ID, its name, or its sealed tier", function()
  local e = ns:WritFor(264012)
  T.eq(e.item, 3383, "Elixir of Wisdom by the writ's ID")
  ns.db.itemNames[3391] = "Elixir of Ogre Strength"
  ns.db.itemNames[999001] = "Craftsman's Writ: Elixir of Ogre Strength"
  local ogre = ns:WritFor(999001)
  T.ok(ogre, "by name, for a writ whose ID isn't known")
  T.eq(ogre and ogre.item, 3391)
  local _, tier = ns:WritFor(262889)
  T.eq(tier.label, "Expert")
  ns.db.itemNames[999002] = "Sealed Artisan's Writ"
  _, tier = ns:WritFor(999002)
  T.eq(tier and tier.label, "Artisan")
  T.eq(ns:WritFor(2589), nil, "linen cloth is no writ")
end)

T.test("Writs: cost per reputation after the coin pouch", function()
  T.eq(ns.WritPerRep(10800, "J"), 100, "(10800 - 3300) / 75")
  T.ok(ns.WritPerRep(1000, "J") < 0, "a cheap order: the pouch pays more")
  T.eq(ns.WritPerRep(nil, "J"), nil)
  local key = ns.MarketKey()
  ns.db.prices[key] = ns.db.prices[key] or {}
  ns.db.prices[key][3383] = { m = 900, a = 900, q = 5, l = "900:5", t = S.now }
  local c = ns:WritCost(ns:WritFor(264012))
  T.ok(c, "priced from the auction house")
  T.eq(c and c.total, 900)
  T.eq(c and c.plan[3383].bought, 1)
end)

T.test("Writs: yours from the bags, and onto the Writs shopping list", function()
  ns.db.inventory = ns.db.inventory or {}
  ns.db.inventory[ns.CharKey()] = { bags = { [264012] = 1, [262888] = 2, [2589] = 20 }, bank = {} }
  local orders, sealed = ns:YourWrits()
  local wisdom = ns:WritFor(264012)
  T.eq(orders[wisdom], 1)
  T.eq(sealed.J, 2, "two sealed Journeyman's writs")
  local key = ns.MarketKey()
  ns.db.prices[key] = ns.db.prices[key] or {}
  ns.db.prices[key][3383] = { m = 900, a = 900, q = 5, l = "900:2,950:5", t = S.now }
  local list = ns:WritsToShoppingList({ wisdom })
  T.eq(list.name, "Writs")
  T.eq(#list.items, 1)
  T.eq(list.items[1].id, 3383); T.eq(list.items[1].qty, 1); T.eq(list.items[1].max, 900)
  -- The same order again: still one item, not two.
  ns:WritsToShoppingList({ wisdom })
  T.eq(#list.items, 1)
  T.eq(list.items[1].qty, 1)
  ns.db.inventory[ns.CharKey()] = nil
end)

T.test("Writs: a sealed writ's average is worked out in the background, then kept", function()
  -- (Frank's AN30, November 17: all of a tier's orders at once froze a hover for half a second.)
  local key = ns.MarketKey()
  ns.db.prices[key] = ns.db.prices[key] or {}
  ns.db.prices[key][3383] = { m = 900, a = 900, q = 5, l = "900:5", t = S.now }
  local first = ns.WritTierAverage("J")
  T.runTimers()
  local a = ns.WritTierAverage("J")
  T.ok(a and a.avg and a.avg > 0, "ready once its timers ran")
  T.ok(first == nil or first == a, "not all at once in the tooltip (or already kept)")
  T.eq(ns.WritTierAverage("J"), a, "kept: not worked out again")
  T.eq(#S.timers, 0, "and nothing started again")
  local lines = ns:WritTooltipLines(262888)
  T.ok(lines and lines[1]:find("on average", 1, true), "the sealed writ's line has it")
end)
