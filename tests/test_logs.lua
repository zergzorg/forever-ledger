-- The ledger's logs as they're written (History.lua addLog, through the game's own
-- events): vendor trades of the same item within a minute become one entry, and the
-- size limit on the logs.
local T = ...
local ns, S = T.ns, T.S
local ME = ns.CharKey()
local NOW = os.time({ year = 2026, month = 3, day = 15, hour = 12 })

-- At a vendor with 1000g. History.lua notes the gold at login.
local function atVendor(item)
  S.now, S.money = NOW, 10000000
  S.merchant[1] = item
  ns.db.vendorLog = {}
  T.fire("PLAYER_ENTERING_WORLD")
  T.fire("MERCHANT_SHOW")
end

-- Buy from the vendor's first slot: the game takes the gold a moment later.
local function buy(qty, copper)
  BuyMerchantItem(1, qty)
  S.money = S.money - copper
  T.fire("PLAYER_MONEY")
end

T.test("A vendor purchase is logged", function()
  atVendor(159)
  buy(5, 125)
  T.eq(#ns.db.vendorLog, 1)
  local e = ns.db.vendorLog[1]
  T.same(e, { t = NOW, c = ME, id = 159, q = 5, a = 125, s = "buy" })
end)

T.test("The same item at the same price within a minute is one entry", function()
  atVendor(159)
  buy(5, 125)
  S.now = NOW + 60
  buy(3, 75)
  T.eq(#ns.db.vendorLog, 1)
  local e = ns.db.vendorLog[1]
  T.eq(e.q, 8)
  T.eq(e.a, 200)
  T.eq(e.t, NOW + 60, "the time of the last one")
end)

T.test("More than a minute apart: two entries", function()
  atVendor(159)
  buy(5, 125)
  S.now = NOW + 61
  buy(3, 75)
  T.eq(#ns.db.vendorLog, 2)
end)

T.test("A different price each: two entries", function()
  atVendor(159)
  buy(5, 125)
  buy(5, 150)
  T.eq(#ns.db.vendorLog, 2)
end)

-- Past LOG_SIZE (10,000) entries the oldest goes into its month's total (History.lua
-- addLog; found by this test as a copper loss, fixed October 4).
T.test("A full log doesn't lose an entry from the last 30 days", function()
  atVendor(159)
  local log = ns.db.vendorLog
  for i = 1, 10000 do log[i] = { t = NOW - 20 * 86400 + i * 60, c = ME, id = 100000 + i, q = 1, a = 1, s = "buy" } end
  S.now = NOW + 10000 * 60
  buy(1, 100)
  local total = 0
  for _, e in ipairs(ns.db.vendorLog) do total = total + e.a end
  for _, m in ipairs(ns.db.ledgerMonths) do total = total + m.a end
  T.eq(total, 10000 + 100, "every copper still counted")
end)

-- Codex review, November 5: folded here, then sent again by the partner, it counted twice.
T.test("A full log folds your own entries, never a partner's", function()
  atVendor(159)
  ns.db.booksFrom = { ["Partner-Testrealm"] = "Partner" }
  ns.db.ledgerMonths = {}
  local log = ns.db.vendorLog
  log[1] = { t = NOW - 25 * 86400, c = "Partner-Testrealm", id = 99, q = 1, a = 100, s = "buy" }
  for i = 1, 10000 do log[i + 1] = { t = NOW - 20 * 86400 + i * 60, c = ME, id = 100000 + i, q = 1, a = 1, s = "buy" } end
  S.now = NOW + 10000 * 60
  buy(1, 100)
  T.eq(ns.db.vendorLog[1].c, "Partner-Testrealm", "theirs stays")
  T.eq(ns.db.vendorLog[2].id, 100002, "your oldest went")
  T.eq(#ns.db.ledgerMonths, 1)
  T.eq(ns.db.ledgerMonths[1].c, ME)
end)

---------------------------------------------------------------------------
-- Auction house purchases: which gold is which (History.lua takeHints)
---------------------------------------------------------------------------
-- At the auction house with 1000g, every earlier hint long gone (GetTime over 99000).
local function atAH()
  S.now, S.money = math.max(S.now, 1800099000) + 100, 10000000
  T.fire("MERCHANT_CLOSED")
  S.now = S.now + 2
  ns.db.purchases = {}
  T.fire("PLAYER_ENTERING_WORLD")
end
-- A purchase sent the way the Buy queue sends it (it names the item).
local function bid(item, copper)
  ns.queueBidItem = item
  C_AuctionHouse.PlaceBid(1, copper)
  ns.queueBidItem = nil
end
local function pay(copper)
  S.now = S.now + 1
  S.money = S.money - copper
  T.fire("PLAYER_MONEY")
end

-- Owner's log, November 10: two Rough Bronze Leggings purchases at 5s were refused, then
-- a 9s purchase and a 22c deposit were put down as Rough Bronze Leggings.
T.test("A refused purchase doesn't name the next gold to leave", function()
  atAH()
  bid(2865, 500)   -- refused twice: no gold leaves
  bid(2865, 500)
  bid(4561, 900)
  pay(900)
  T.eq(#ns.db.purchases, 1)
  T.eq(ns.db.purchases[1].id, 4561, "the one that cost 9s")
  T.eq(ns.db.purchases[1].a, 900)
  C_Item = { GetItemID = function(loc) return loc.id end }
  C_AuctionHouse.PostItem({ id = 2589 }, 1, 1, 100)
  C_Item = nil
  pay(22)
  T.eq(#ns.db.purchases, 1, "a deposit isn't a purchase")
  T.eq(ns.db.money[ME][ns.LocalDay()].ahFee, 22)
end)

T.test("Two purchases at one price: the gold goes to the newer", function()
  atAH()
  bid(2865, 500)   -- refused
  bid(4561, 500)
  pay(500)
  T.eq(#ns.db.purchases, 1)
  T.eq(ns.db.purchases[1].id, 4561)
end)

-- Frank, November 14: flights, loot, other income and the rest were only day totals, so
-- they sorted oddly among the Ledger's timed entries. Now each has its own time too.
T.test("Other money is logged with its time; the same kind within 5 minutes is one entry", function()
  ns.db.otherLog, ns.db.otherLogSince = {}, {}
  local log = ns.LogOtherMoney
  log("flight", 500, ME, NOW)
  T.same(ns.db.otherLog[1], { t = NOW, c = ME, s = "flight", a = 500 })
  T.eq(ns.db.otherLogSince[ME], NOW)
  log("flight", 200, ME, NOW + 120)
  T.eq(#ns.db.otherLog, 1, "two minutes later: the same entry")
  T.eq(ns.db.otherLog[1].a, 700); T.eq(ns.db.otherLog[1].t, NOW + 120)
  log("loot", 50, ME, NOW + 130)
  T.eq(#ns.db.otherLog, 2, "another kind: its own entry")
  log("loot", 10, ME, NOW + 130 + 301)
  T.eq(#ns.db.otherLog, 3, "over 5 minutes later: a new entry")
  log("ahSale", 999, ME, NOW + 500)
  log("vendorSell", 999, ME, NOW + 500)
  T.eq(#ns.db.otherLog, 3, "sales and vendor trades have their own logs")
  log("repair", 0, ME, NOW + 600)
  T.eq(#ns.db.otherLog, 3, "nothing for nothing")
  T.eq(ns.db.otherLogSince[ME], NOW, "since its first entry")
end)

-- Codex review of 211a277: what the Ledger shows for other money, not just the log.
local function ledgerOther()
  local total, rows = 0, ns.LedgerRecords("other", 0, function() return true end, "")
  for _, r in ipairs(rows) do total = total + r.total end
  return total, rows
end

T.test("Ledger: money a minute either side of midnight is counted once", function()
  local late = os.time({ year = 2026, month = 3, day = 15, hour = 23, min = 59 })
  local D = ns.LocalDay(late)
  ns.db.otherLog, ns.db.otherLogSince, ns.db.otherLogCut = {}, {}, {}
  ns.db.money = { [ME] = { [D] = { otherIn = 100 }, [D + 1] = { otherIn = 10 } } }
  S.now = late + 300
  ns.LogOtherMoney("otherIn", 100, ME, late)
  ns.LogOtherMoney("otherIn", 10, ME, late + 120)
  T.eq(#ns.db.otherLog, 2, "not merged across midnight")
  local total, rows = ledgerOther()
  T.eq(total, 110)
  T.eq(#rows, 2, "two timed entries, no 'earlier' line")
end)

T.test("Ledger: a day the size limit cut into shows its day totals, nothing lost", function()
  local noon = os.time({ year = 2026, month = 3, day = 15, hour = 12 })
  local D = ns.LocalDay(noon)
  local nextDay = os.time({ year = 2026, month = 3, day = 16, hour = 0, min = 10 })
  ns.db.otherLog, ns.db.otherLogSince, ns.db.otherLogCut = {}, {}, {}
  ns.db.money = { [ME] = { [D] = { otherIn = 5 }, [D + 1] = { loot = 5001, quest = 5000 } } }
  ns.LogOtherMoney("otherIn", 5, ME, noon)
  for i = 1, 10001 do ns.LogOtherMoney(i % 2 == 1 and "loot" or "quest", 1, ME, nextDay + i) end
  T.eq(#ns.db.otherLog, 10000, "the size limit")
  T.ok(ns.db.otherLogCut[ME] and ns.LocalDay(ns.db.otherLogCut[ME]) == D + 1, "the cut reached the next day")
  S.now = nextDay + 20000
  local total = ledgerOther()
  T.eq(total, 10006, "all of it, from the day totals")
end)
