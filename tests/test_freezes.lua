-- Core.lua freeze watch (Frank, November 17: the game froze while hovering tooltips): a
-- slow frame is kept with Forever Ledger's share and what the profiler named.
local T = ...
local ns = T.ns

T.test("Freeze watch: slow frames kept, short ones not, Forever Ledger's share", function()
  ns.db.freezeLog = nil
  ns.NoteFrame(0.1, 5, "Tooltip lines", 5, nil, nil)
  T.eq(ns.db.freezeLog, nil, "a normal frame isn't noted")
  ns.NoteFrame(0.8, 12.4, "Tooltip lines", 9, 2589, { { name = "SomeAddon", v = 640 } })
  local e = ns.db.freezeLog[1]
  T.eq(e.ms, 800)
  T.eq(e.ours, 12)
  T.eq(e.what, "Tooltip lines")
  T.eq(e.item, 2589)
  T.eq(e.addons[1], "SomeAddon 640 ms")
  ns.NoteFrame(0.5, 1, "Tiny", 1, nil, nil)
  T.eq(ns.db.freezeLog[2].what, nil, "a share under 5 ms isn't named")
  local text = table.concat(ns.FreezeLines(8), "\n")
  T.ok(text:find("800 ms", 1, true), "listed")
  T.ok(text:find("SomeAddon 640 ms", 1, true), "with the other addon")
  for _ = 1, 30 do ns.NoteFrame(0.3, 0, nil, 0, nil, nil) end
  T.eq(#ns.db.freezeLog, 20, "the last 20 kept")
  ns.db.freezeLog = nil
  T.ok(table.concat(ns.FreezeLines(8), "\n"):find("none seen", 1, true))
end)

T.test("Freeze watch: the addons with a frame over 100 ms in it", function()
  local slow = ns.SlowSince({ Bags = 10, UI = 3, Other = 2 }, { Bags = 12, UI = 3, Other = 3, New = 1 })
  T.eq(#slow, 3)
  T.eq(slow[1].name, "Bags", "most first")
  T.eq(slow[1].n, 2)
  T.eq(#ns.SlowSince({ A = 1 }, { A = 1 }), 0, "none: the game itself")
  ns.db.freezeLog = { { t = 1, ms = 600, ours = 2, slow = { "Bags" } }, { t = 2, ms = 500, ours = 1, slow = {} } }
  local text = table.concat(ns.FreezeLines(8), "\n")
  T.ok(text:find("over 100 ms within a second or two of it: Bags", 1, true), "named, as nearby")
  T.ok(text:find("no addon had a frame over 100 ms within", 1, true), "or none (not blamed on the game)")
  T.ok(not text:find("game itself", 1, true), "no conclusion it can't support")
  ns.db.freezeLog = nil
end)

T.test("Freeze watch: the slowest part of our share is named", function()
  ns.db.freezeLog = nil
  ns.NoteFrame(0.5, 471, "Tooltip lines", 468, 2589, nil, "Tooltip: worth to you", 450.4)
  local e = ns.db.freezeLog[1]
  T.eq(e.part, "Tooltip: worth to you")
  T.eq(e.partMs, 450)
  T.ok(table.concat(ns.FreezeLines(8), "\n"):find("slowest part Tooltip: worth to you, 450 ms", 1, true), "listed")
  ns.NoteFrame(0.5, 3, "Tooltip lines", 3, nil, nil, "Tooltip: price", 2)
  T.eq(ns.db.freezeLog[2].part, nil, "not when our share wasn't named")
  -- A part is listed in /fl perf without being counted twice in the frame's total.
  ns.perf["Tooltip: test part"] = nil
  ns.PerfNote("Tooltip: test part", 7, true)
  T.eq(ns.perf["Tooltip: test part"].max, 7)
  ns.perf["Tooltip: test part"] = nil
  ns.db.freezeLog = nil
end)

T.test("Freeze watch: a timed step inside a timed task isn't counted twice", function()
  -- (Codex review, November 17: 100 ms outer with an 80 ms inner showed as 180 ms.)
  local realClock = debugprofilestop
  local now = 0
  debugprofilestop = function() return now end
  local inner = ns.Timed("Test inner", function() now = now + 80 end)
  local outer = ns.Timed("Test outer", function() now = now + 10; inner(); now = now + 10 end)
  local before = ns.perf["Test outer"]
  local share = ns.FrameShare()
  outer()
  local added = ns.FrameShare() - share
  debugprofilestop = realClock
  T.eq(ns.perf["Test outer"].max, 100)
  T.eq(ns.perf["Test inner"].max, 80, "the inner step is still listed")
  T.ok(before == nil)
  T.eq(added, 100, "the frame's share: the outer task once")
  ns.perf["Test outer"], ns.perf["Test inner"] = nil, nil
end)
