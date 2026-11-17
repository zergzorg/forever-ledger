-- QuickDisenchant.lua (Frank, November 16): the items the Disenchant window lists.
local T = ...
local ns, S = T.ns, T.S

T.test("Quick disenchant: the key names, and nothing listed without bags", function()
  T.eq(ns.QUICK_DE_KEYS.ctrlalt.name, "Ctrl+Alt")
  ns.db.settings.quickDEKey = "shiftalt"
  T.eq(ns:QuickDisenchantKeyName(), "Shift+Alt")
  ns.db.settings.quickDEKey = "nonsense"
  T.eq(ns:QuickDisenchantKeyName(), "Ctrl+Alt", "an unknown key falls back to Ctrl+Alt")
  ns.db.settings.quickDEKey = "ctrlalt"
  T.eq(type(ns:DisenchantableItems()), "table")
  T.ok(S ~= nil)
end)
