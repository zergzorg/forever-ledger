-- Post.lua: the price the Post tab fills in from an item's post rule (redesign build
-- step 4, November 15; Frank agreed the default rule: the usual price, the cheapest matched (undercut 1c until his November 15 test),
-- never below 70% of the usual price or a vendor's price after the cut).
local T = ...
local ns = T.ns
local S = T.S

local RULE = { start = "usual", undercut = 1, floorPct = 70, belowFloor = "skip", keep = 0, hours = 24 }

T.test("Post price: 1c under the cheapest", function()
  local p = ns.PostPrice(RULE, 125, 119, nil)
  T.eq(p.price, 118); T.eq(p.floor, 87); T.ok(not p.skip)
  T.ok(p.why:find("under the cheapest"), p.why)
end)

T.test("Post price: none listed, the usual price", function()
  local p = ns.PostPrice(RULE, 200, nil, nil)
  T.eq(p.price, 200); T.ok(p.why:find("usual"), p.why)
end)

T.test("Post price: nothing to go on, no price", function()
  local p = ns.PostPrice(RULE, nil, nil, nil)
  T.eq(p.price, nil); T.ok(p.why:find("No price"), p.why)
end)

T.test("Post price: under the floor is skipped, or posted at the floor", function()
  local p = ns.PostPrice(RULE, 125, 50, nil)
  T.ok(p.skip); T.eq(p.floor, 87)
  local atFloor = {}
  for k, v in pairs(RULE) do atFloor[k] = v end
  atFloor.belowFloor = "floor"
  p = ns.PostPrice(atFloor, 125, 50, nil)
  T.ok(not p.skip); T.eq(p.price, 87)
end)

T.test("Post price: never below what a vendor pays after the cut", function()
  local p = ns.PostPrice(RULE, 125, 95, 105)
  T.eq(p.floor, 105, "the vendor floor is higher than 70% of usual")
  T.ok(p.skip, "the cheapest less 1c is under it")
  p = ns.PostPrice(RULE, nil, 200, 105)
  T.eq(p.price, 199); T.eq(p.floor, 105)
end)

T.test("Post price: rule off means you type the price", function()
  local p = ns.PostPrice(nil, 125, 119, nil)
  T.eq(p.price, nil); T.ok(p.why:find("Off"), p.why)
end)

T.test("Post: the vendor floor is the least price that still beats a vendor after the cut", function()
  local ID = 97701
  S.items[ID] = { name = "Test Pelt", sell = 100 }
  ns.db.settings.ahCut = 5
  local floor = ns:PostVendorFloor(ID)
  T.eq(floor, 105)
  T.ok(ns:AfterCut(floor) >= 100)
  T.ok(ns:AfterCut(floor - 1) < 100, "one less would lose to the vendor")
  S.items[97702] = { name = "Test Thing", sell = 0 }
  T.eq(ns:PostVendorFloor(97702), nil, "no vendor price: no vendor floor")
end)

T.test("Post price: the default rule matches the cheapest (Frank, November 15)", function()
  local p = ns.PostPrice(ns.RULE_DEFAULTS.post, 125, 119, nil)
  T.eq(p.price, 119); T.ok(p.why:find("same as the cheapest"), p.why)
end)
