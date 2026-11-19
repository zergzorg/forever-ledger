-- Crates.lua: crates found by item number and their bundles read from the tooltip in any
-- language (a German player's Crates tab was empty, CurseForge, November 18).
local T = ...
local ns = T.ns

T.test("Crates: every Waylaid Crate is known by item number", function()
  local n = 0
  for _ in pairs(ns.CRATE_IDS) do n = n + 1 end
  T.eq(n, 30)
  T.ok(ns.CRATE_IDS[248682] and ns.CRATE_IDS[248713])
  T.ok(not ns.CRATE_IDS[248700] and not ns.CRATE_IDS[248701])
end)

T.test("Crates: English tooltip, only the lines after any bundle", function()
  local b = ns.CrateBundlesFromLines({ "Waylaid Crate: Expert Ingots", "- 1 thing in the flavor text",
    "Fill it with any bundle below:\n- 10 Copper Bar and 5 Tin Bar\n- 20 Strange Dust" })
  T.eq(#b, 2)
  T.eq(#b[1], 2); T.eq(b[1][1].qty, 10); T.eq(b[1][1].name, "Copper Bar")
  T.eq(b[1][2].qty, 5); T.eq(b[1][2].name, "Tin Bar")
  T.eq(b[2][1].name, "Strange Dust"); T.eq(b[2][1].qty, 20)
end)

T.test("Crates: another language, every dash line with a number", function()
  local b = ns.CrateBundlesFromLines({ "Verirrte Kiste: Experteneisen",
    "Füllt sie mit einem dieser Bündel:", "- 10 Kupferbarren und 5 Zinnbarren", "- 8x Runenstoffballen", "- 4 Eisenbarren, 2 Goldbarren" })
  T.eq(#b, 3)
  T.eq(b[1][1].name, "Kupferbarren"); T.eq(b[1][2].name, "Zinnbarren"); T.eq(b[1][2].qty, 5)
  T.eq(b[2][1].name, "Runenstoffballen"); T.eq(b[2][1].qty, 8)
  T.eq(b[3][1].name, "Eisenbarren"); T.eq(b[3][2].name, "Goldbarren"); T.eq(b[3][2].qty, 2)
end)

T.test("Crates: the filled crate is known by item number, each quality", function()
  T.ok(ns.SEALED_CRATE_IDS[248765] and ns.SEALED_CRATE_IDS[248770] and ns.SEALED_CRATE_IDS[248775])
  T.ok(not ns.SEALED_CRATE_IDS[248682], "an empty crate isn't a filled one")
end)
