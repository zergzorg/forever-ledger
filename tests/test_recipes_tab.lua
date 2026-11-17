-- RecipesTab.lua: the Professions tab's Where from filter (November 16).
local T = ...
local ns = T.ns

T.test("Professions: Where from groups a recipe's source", function()
  local kind = ns.RecipeSourceKind
  T.eq(kind(nil, false), "trainer", "nothing seen and no recipe item: a trainer (or new in Forever)")
  T.eq(kind(nil, true), "unseen", "a recipe item nobody has spotted")
  T.eq(kind({ kind = "mob" }), "drop"); T.eq(kind({ kind = "drop" }), "drop")
  T.eq(kind({ kind = "vendor" }), "vendor"); T.eq(kind({ kind = "trainer" }), "trainer")
  T.eq(kind({ kind = "quest" }), "quest"); T.eq(kind({ kind = "ah" }), "ah")
end)
