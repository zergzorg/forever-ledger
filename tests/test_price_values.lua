-- Opt-in redesign values: raw own-history prices, never a purchase or craft cost.
local T = ...
local ns, S = T.ns, T.S
local DAY = 20000
local function history(rows)
  local out = {}
  for _, r in ipairs(rows) do out[#out + 1] = ("%d:%d:%d"):format(DAY - r[1], r[2], r[3] or r[2]) end
  return table.concat(out, "|")
end
local function values(rows, sold, changed)
  return ns.PriceHistoryValues(history(rows), sold, DAY, changed)
end

T.test("Price values: calendar weights, equal-day recent/long-term and daily typical", function()
  local v = values({ {14, 50, 100}, {1, 60, 200} })
  T.eq(v.usual, 193, "(100*1 + 200*14)/15, rounded")
  T.eq(v.recent, 200); T.eq(v.longTerm, 150)
  T.eq(v.usualDays, 2); T.eq(v.usualDropped, 0)
end)

T.test("Price values: exact 3/14/60 completed-day boundaries, gaps and today", function()
  local v = values({ {61, 900}, {60, 400}, {15, 300}, {14, 200}, {3, 100}, {0, 9000}, {-1, 9000} })
  T.eq(v.recent, 100); T.eq(v.recentDays, 1)
  T.eq(v.usual, 108, "(200 + 100*12)/13")
  T.eq(v.longTerm, 250); T.eq(v.longTermDays, 4)
  T.eq(values({ {0, 100} }).usual, nil, "partial today cannot set a usual price")
  T.eq(values({}).longTerm, nil, "missing is unknown, not free")
end)

T.test("Price values: isolated high and low outliers in a flat market", function()
  local rows = {}
  for age = 1, 14 do rows[#rows + 1] = {age, age == 1 and 1 or age == 2 and 100000 or 100} end
  local v = values(rows)
  T.eq(v.usual, 100); T.eq(v.usualDays, 12); T.eq(v.usualDropped, 2)
  T.eq(v.longTerm, 100); T.eq(v.longTermDropped, 2)
  T.eq(v.recentDropped, 0, "fewer than five observations: no guessed outliers")
end)

T.test("Price values: real market shifts and modest variation survive the filter", function()
  local rows = {}
  for age = 1, 14 do rows[#rows + 1] = {age, age <= 7 and 100 or 1000} end
  local v = values(rows)
  T.eq(v.usualDropped, 0, "two sustained regimes, not one outlier")
  T.eq(v.usual, 340); T.eq(v.recent, 100); T.eq(v.longTerm, 550)
  v = values({ {1,100}, {2,100}, {3,100}, {4,100}, {5,140} })
  T.eq(v.usualDropped, 0, "MAD zero must not discard normal movement")
end)

T.test("Price values: vendor-price change cuts history, no weekly reconstruction", function()
  local v = values({ {1, 100}, {2, 200}, {3, 300}, {30, 400} }, nil, DAY - 2)
  T.eq(v.longTerm, 150); T.eq(v.usualDays, 2)
  T.eq(values({ {1,100} }, nil, DAY).usual, nil)
end)

T.test("Price values: damaged strings and duplicate days do not add fake samples", function()
  local s = history({ {1,100}, {1,200}, {2,100} }) .. "|bad|1:2:3:x|19998:0:100|19997:200:100"
  local v = ns.PriceHistoryValues(s, nil, DAY)
  T.eq(v.usualDays, 2); T.eq(v.recent, 150)
  T.eq(ns.PriceHistoryValues(nil, nil, nil).usual, nil)
  T.eq(ns.PriceHistoryValues({}, {}, DAY).usual, nil)
end)

T.test("Price values: sells/day uses observed minutes, reliability and explicit zero", function()
  local function rate(g, m) return ns.PriceHistoryValues(nil, ("%d:%d:%d:%d"):format(DAY,g,m,m), DAY) end
  T.eq(rate(3,179).sellsPerDay, nil)
  T.eq(rate(3,180).sellsPerDay, 24)
  T.eq(rate(1,1439).sellsPerDay, nil)
  T.eq(rate(1,1440).sellsPerDay, 1)
  T.eq(rate(0,719).sellsPerDay, nil)
  T.eq(rate(0,720).sellsPerDay, 0)
  T.eq(rate(0,720).saleMinutes, 720)
end)

T.test("Price values: sold history excludes future/expired days and accepts old three fields", function()
  local s = ("%d:999:180|%d:3:180|%d:3:180:180|%d:999:180|bad|%d:3:180:999"):format(
    DAY-30, DAY-29, DAY, DAY+1, DAY-1)
  local v = ns.PriceHistoryValues(nil,s,DAY)
  T.eq(v.saleUnits,6); T.eq(v.saleMinutes,360); T.eq(v.sellsPerDay,24)
end)

T.test("Price values: fresh cheapest is the minimum, not the twenty-unit mean", function()
  local rec = {m=100,a=200,q=7,t=1000,src="scan"}
  local before = ns.Serialize(rec)
  local v = ns.PriceCurrentValues(rec,1100,100)
  T.eq(v.cheapest,100); T.eq(v.listed,7); T.eq(v.lastSeen,1000)
  T.eq(ns.Serialize(rec),before)
  v = ns.PriceCurrentValues(rec,1101,100)
  T.eq(v.cheapest,nil); T.eq(v.listed,nil); T.eq(v.stale,true)
end)

T.test("Price values: empty, unknown, other-addon and future observations", function()
  local v = ns.PriceCurrentValues({none=true,t=1000,src="full"},1100)
  T.eq(v.listed,0); T.eq(v.cheapest,nil)
  T.eq(ns.PriceCurrentValues(nil,1100).listed,nil)
  T.eq(ns.PriceCurrentValues({m=100,t=1000,src="TSM"},1100).cheapest,nil)
  T.eq(ns.PriceCurrentValues({m=100,t=1200,src="scan"},1100).cheapest,nil)
  T.eq(ns.PriceCurrentValues({m=0,t=1000,src="scan"},1100).cheapest,nil)
  v = ns.PriceCurrentValues({m=100,q=0,t=1000},1100)
  T.eq(v.cheapest,nil); T.eq(v.listed,0)
end)

T.test("Price values: explicit markets, read-only adapter and old UsualPrice unchanged", function()
  local id, d = 351999, ns.LocalDay()
  local own, neutral = ns.MarketKey(), "Other market neutral"
  ns.db.history[own] = {[id]=(d-1)..":100:100"}
  ns.db.history[neutral] = {[id]=(d-1)..":200:200"}
  ns.db.prices[own] = {[id]={m=80,a=90,q=3,t=S.now,src="scan"}}
  ns.db.prices[neutral] = {[id]={m=180,a=190,q=8,t=S.now,src="full"}}
  ns.db.historySold2[neutral] = {[id]=d..":3:180:180"}
  ns.db.historyWeekly[neutral] = {[id]="1:99999:99999:7"}
  local before = ns.Serialize(ns.db)
  local v = ns:PriceValues(id,neutral)
  T.eq(v.usual,200); T.eq(v.cheapest,180); T.eq(v.listed,8); T.eq(v.sellsPerDay,24)
  T.eq(ns:PriceValues(id).usual,100)
  T.eq(ns:PriceValues(id,"never scanned").cheapest,nil)
  T.eq(ns.Serialize(ns.db),before,"reads must not create market tables")
  local old = ns:UsualPrice(id,"week")
  T.eq(old,100,"new opt-in values do not change released pricing")
end)

T.test("Price values: pure inputs, stale listings with valid history, and one captured clock", function()
  local rec = { m=100, q=2, t=1000, src="scan" }
  local h = history({ {1,100}, {2,200} })
  local before = ns.Serialize(rec)
  local a, b = ns.PriceHistoryValues(h,nil,DAY), ns.PriceHistoryValues(h,nil,DAY)
  T.eq(ns.Serialize(a),ns.Serialize(b)); T.eq(ns.Serialize(rec),before)
  T.eq(ns.PriceCurrentValues(rec,1100,math.huge).cheapest,nil)
  local id, market, d = 351998, ns.MarketKey(), ns.LocalDay()
  ns.db.history[market] = {[id]=(d-1)..":100:100"}
  ns.db.prices[market] = {[id]={m=200,q=10,t=S.now-13*3600,src="scan"}}
  local realTime, calls = time, 0
  time = function(t) if t then return realTime(t) end; calls=calls+1; return S.now end
  local ok, v = pcall(ns.PriceValues,ns,id,market)
  time = realTime
  T.ok(ok,v); T.eq(calls,1)
  T.eq(v.usual,100); T.eq(v.cheapest,nil); T.eq(v.listed,nil); T.eq(v.stale,true)
end)
