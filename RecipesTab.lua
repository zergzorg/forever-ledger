local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- Recipes tab: every recipe of each profession (from RecipeBook.lua), who knows it,
-- where it comes from (as seen in game), what a craft makes at today's prices, and a
-- type: flip or shuffle, crafts that sell, not for sale, not profitable. Right-click a
-- row to set your own type. A Trainers view lists trainers seen, with map pins.
---------------------------------------------------------------------------
local SECONDARY = { Cooking = true, ["First Aid"] = true, Fishing = true, ["Кулинария"] = true, ["Первая помощь"] = true, ["Рыбная ловля"] = true }
local ALWAYS_SHUFFLE = { [11287] = true, [11288] = true }   -- Lesser and Greater Magic Wand
local MIN_LISTED = 5
local MAX_ROWS = 300
local ROW = 22
local TYPES = {
  shuffle = { label = "Перепродажа", short = "Перепродажа", color = "7fd39c" },
  sells = { label = "Изготовление", short = "Продажа", color = "ffd100" },
  enchant = { label = "Услуги чар", short = "Чары", color = "66bbff" },   -- no item to sell; sold as a service
  notsale = { label = "Не на продажу", short = "Не на продажу", color = "888888" },
  loss = { label = "Невыгодно", short = "Убыток", color = "ee8597" },
}
local ORDER = { "shuffle", "sells", "enchant", "notsale", "loss" }
local typeRank = {}
for i, k in ipairs(ORDER) do typeRank[k] = i end

local function dim(t) return "|cff888888" .. t .. "|r" end
local function money(v)
  if not v then return dim("?") end
  return (v < 0 and "-" or "") .. ns.Money(math.floor(math.abs(v) + 0.5))
end

local function settings()
  local s = ns.db.settings.recipes
  s.view = s.view or "known"   -- "view", not the first test's "show", so everyone starts on Known
  s.type = s.type or "all"
  if s.custom == nil then s.custom = true end
  s.source = s.source or "all"
  s.skill = s.skill or "all"
  s.group = s.group or "all"
  s.least = tonumber(s.least) or 0
  -- s.sort = { key, desc } after a column heading is clicked; nil keeps the usual order.
  return s
end

---------------------------------------------------------------------------
-- Map pins
---------------------------------------------------------------------------
function ns:PinOnMap(mapID, x, y, label)
  if not (mapID and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then
    ns:Print("Позиция пока не записана.")
    return
  end
  local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y))
  if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
  local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  ns:Print(ok and ("Метка на карте: %s, %s (%.1f, %.1f)."):format(label or "?", info and info.name or "?", x * 100, y * 100)
    or "Игра не приняла метку на карте.")
end

---------------------------------------------------------------------------
-- What a recipe is worth and which type it is
---------------------------------------------------------------------------
local function unitCost(id)
  -- The cheaper of a vendor and the auction house.
  local vendor, ah = ns:GetVendorBuyPrice(id), (ns:GetPrice(id))
  if vendor and ah then return math.min(vendor, ah) end
  return vendor or ah
end

-- Profit per craft at today's prices, and the output's best option (or nil).
local function craftValue(r)
  if not r.out then return end
  local best = ns:BestOption(r.out)
  if not best then return end
  local cost = 0
  for _, m in ipairs(r.r or {}) do
    local c = unitCost(m[1])
    if not c then return nil, best end
    cost = cost + c * m[2]
  end
  return best.value * (r.oq or 1) - cost, best
end

local function autoType(r)
  if ALWAYS_SHUFFLE[r.out or 0] then return "shuffle" end
  -- Enchants make no item: their value is what players pay for the service.
  if not r.out and (r.n or ""):find("^Enchant ") then return "enchant" end
  local _, _, _, _, _, _, _, _, _, _, sell, _, _, bind = ns.GetItemInfo(r.out or 0)
  local profit, best = craftValue(r)
  if bind == 1 or not best then return "notsale", profit end
  if not profit or profit <= 0 then return "loss", profit end
  if best.kind == "ah" then
    local rec = (ns.db.prices[ns.MarketKey()] or {})[r.out]
    if rec and (rec.q or 0) >= MIN_LISTED then return "sells", profit end
    return "loss", profit
  end
  return "shuffle", profit
end

---------------------------------------------------------------------------
-- Recipes from the game's own data (ForeverCrafts.lua) that no profession window has
-- recorded yet, so a profession nobody of yours has opened still lists its recipes
-- (Frank, November 15: Recipes needs more data). Shaped like recipe book entries:
-- `fc` marks them, `learn` is the recipe item's required skill where the game has one
-- (so the recipe is taught by an item), `rank` the skill the craft starts at.
---------------------------------------------------------------------------
local fcByProf
local function foreverBook(prof)
  if not fcByProf then
    fcByProf = {}
    for _, e in ipairs(ns.FOREVER_CRAFTS or {}) do
      local t = fcByProf[e.prof] or {}
      fcByProf[e.prof] = t
      t[e.id] = { n = e.n, out = e.out, oq = ((e.low or 1) + (e.high or e.low or 1)) / 2, r = e.r,
        fc = true, learn = e.learn, rank = e.skill }
    end
  end
  return fcByProf[prof] or {}
end

-- Every recipe of a profession: the recorded ones, then the game data's others.
local function eachRecipe(prof, fn)
  local book = ns.db.recipeBook[prof] or {}
  for id, r in pairs(book) do fn(id, r) end
  for id, r in pairs(foreverBook(prof)) do
    if not book[id] then fn(id, r) end
  end
end

local function hasRecipes(prof)
  return ns.db.recipeBook[prof] ~= nil or next(foreverBook(prof)) ~= nil
end

---------------------------------------------------------------------------
-- Classic data (ClassicRecipes.lua): turn an entry into a source like the ones seen
-- in game, with a map for pins.
---------------------------------------------------------------------------
-- Zone name -> map ID, from the game's own map list (Classic zone and city maps are
-- numbered 1411-1458; Stormwind City is 1453).
local mapByName
function ns:MapIDForZone(zone)
  if not zone then return end
  if not mapByName then
    mapByName = {}
    if C_Map and C_Map.GetMapInfo then
      for id = 1400, 1460 do
        local ok, info = pcall(C_Map.GetMapInfo, id)
        if ok and info and info.name then mapByName[info.name] = mapByName[info.name] or id end
      end
    end
  end
  return mapByName[zone]
end

local myFaction
local function friendly(npc)
  myFaction = myFaction or ((UnitFactionGroup("player") == "Horde") and "H" or "A")
  return not npc.fac or npc.fac:find(myFaction, 1, true) ~= nil
end

function ns.OtherFaction()
  return UnitFactionGroup("player") == "Horde" and "Alliance" or "Horde"
end

-- Only the other faction can get it: for you, the neutral auction house is the way.
local function otherSideText()
  return (" |cffee8597только %s: нейтральный аукцион|r"):format(ns.OtherFaction())
end

-- An NPC from the Classic data as a source table.
local function classicNPC(id, kind)
  local n = ns.CLASSIC_NPCS and ns.CLASSIC_NPCS[id]
  if not n then return end
  return { kind = kind, conf = "classic", npc = n.name, npcID = id, zone = n.zone,
    x = n.x and n.x / 100, y = n.y and n.y / 100, mapID = ns:MapIDForZone(n.zone), fac = n.fac }
end

function ns:ClassicSource(name)
  local e = ns.CLASSIC_RECIPES and ns.CLASSIC_RECIPES[name:lower()]
  if not e then return end
  local s
  if e.kind == "vendor" then
    -- A vendor of your own faction (or neutral) with a position first.
    local best, bestScore
    for _, id in ipairs(e.vendors or {}) do
      local v = classicNPC(id, "vendor")
      if v then
        local score = (friendly(v) and 2 or 0) + (v.mapID and 1 or 0)
        if not best or score > bestScore then best, bestScore = v, score end
      end
    end
    s = best or { kind = "vendor", conf = "classic" }
    s.cost = e.cost
    s.otherSide = best and not friendly(best) or nil
  elseif e.kind == "mob" or e.kind == "drop" then
    local top = e.mobs and e.mobs[1]
    s = top and classicNPC(top[1], e.kind) or { kind = e.kind, conf = "classic" }
    s.chance = top and top[2] or e.chance
    s.mobCount = e.kind == "drop" and (e.mobCount or (e.mobs and #e.mobs)) or nil
  else
    s = { kind = e.kind, conf = "classic", quest = e.quest, otherSide = e.faction == ns.OtherFaction() or nil }
  end
  s.entry = e
  return s
end

-- Tooltip lines for every Classic source of a recipe: all vendors, the top mobs.
function ns:AddClassicSourceLines(tt, name)
  local e = name and ns.CLASSIC_RECIPES and ns.CLASSIC_RECIPES[name:lower()]
  if not e then return end
  ns:AddTooltipLine(tt, " ")
  ns:AddTooltipLine(tt, "В оригинальном Classic (в Forever не подтверждено):", 1, 0.82, 0)
  for _, id in ipairs(e.vendors or {}) do
    local v = classicNPC(id, "vendor")
    if v then
      ns:AddTooltipDoubleLine(tt, "Продаёт " .. v.npc, (v.zone or "?") .. (v.x and (" %.0f, %.0f"):format(v.x * 100, v.y * 100) or "")
        .. (friendly(v) and "" or (" (только %s)"):format(ns.OtherFaction())), 1, 1, 1, 0.8, 0.8, 0.8)
    end
  end
  for _, m in ipairs(e.mobs or {}) do
    local v = classicNPC(m[1], "mob")
    if v then
      ns:AddTooltipDoubleLine(tt, ("%s (%s%%)"):format(v.npc, m[2] >= 1 and ("%.0f"):format(m[2]) or ("%.2f"):format(m[2])),
        v.zone or "?", 1, 1, 1, 0.8, 0.8, 0.8)
    end
  end
  if e.mobCount and e.mobCount > #(e.mobs or {}) then
    ns:AddTooltipLine(tt, ns.LocalizeText("...и ещё %d видов существ."):format(e.mobCount - #(e.mobs or {})), 0.8, 0.8, 0.8)
  end
  if e.quest then ns:AddTooltipLine(tt, "Задание: " .. e.quest, 1, 1, 1) end
  local s = ns:ClassicSource(name)
  if s and s.otherSide then
    ns:AddTooltipLine(tt, ns.LocalizeText("Этот рецепт доступен только %s. Для вас путь — нейтральный аукцион (Бухта Боти, Прибамбасск, Круговзор)."):format(
      ns.OtherFaction()), 0.93, 0.52, 0.59, true)
  end
end

-- The most useful source: seen in game first (vendor or trainer with a position best),
-- otherwise where it came from in original Classic (ClassicRecipes.lua, unconfirmed).
local function bestSource(name)
  if not name then return end
  local pick
  for _, s in pairs(ns.db.recipeSources[name:lower()] or {}) do
    local score = (s.mapID and 2 or 0) + ((s.kind == "vendor" or s.kind == "trainer") and 1 or 0)
    if not pick or score > pick.score then pick = { s = s, score = score } end
  end
  if pick then return pick.s end
  local classic = ns:ClassicSource(name)
  if classic then return classic end
  -- Nothing seen and not in Classic (new in Forever, like Savory Whimsyfin Delight):
  -- if its recipe item is on the auction house, that's where to get it.
  local item = ns.RecipeItemFor and ns.RecipeItemFor(name)
  local rec = item and (ns.db.prices[ns.MarketKey()] or {})[item]
  if rec and rec.m and not rec.none then
    return { kind = "ah", conf = "seen", item = item, price = rec.m, listed = rec.q }
  end
end

-- Recipe items by the recipe they teach ("Recipe: Savory Whimsyfin Delight" -> its item
-- ID), from every item name the addon has seen. Rebuilt when more names are known.
local RECIPE_PREFIXES = { "Formula", "Pattern", "Рецепт", "Plans", "Schematic", "Manual", "Design", "Technique" }
local recipeItems, recipeItemsFrom, recipeItemsChecked = {}, -1, 0
function ns.RecipeItemFor(name)
  local names = ns.db.itemNames
  -- Count the names at most every 30 seconds (this runs for every row of the tab).
  local count = recipeItemsFrom
  if GetTime() - recipeItemsChecked > 30 then
    recipeItemsChecked, count = GetTime(), 0
    for _ in pairs(names) do count = count + 1 end
  end
  if count ~= recipeItemsFrom then
    recipeItems, recipeItemsFrom = {}, count
    for id, itemName in pairs(names) do
      for _, p in ipairs(RECIPE_PREFIXES) do
        local rest = itemName:match("^" .. p .. ":%s*(.+)$")
        if rest then recipeItems[rest:lower()] = id; break end
      end
    end
  end
  return recipeItems[name:lower()]
end

-- Chance is in percent.
local function percent(p)
  if not p then return "" end
  if p <= 0 then return "" end
  return dim((" (%s%%)"):format(p >= 1 and ("%.0f"):format(p) or p >= 0.1 and ("%.1f"):format(p)
    or p >= 0.01 and ("%.2f"):format(p) or "<0.01"))
end

-- The recipe item's cheapest auction house listing: price, record (or nil).
local function recipeAH(s)
  local item = s and (s.item or (s.entry and s.entry.item))
  local rec = item and (ns.db.prices[ns.MarketKey()] or {})[item]
  if rec and rec.m and not rec.none then return rec.m, rec end
  return nil, rec
end

local function ahText(s)
  local price, rec = recipeAH(s)
  if price then return "  |cffffd100" .. ns.LocalizeText("аукцион") .. " " .. ns.Money(price) .. "|r" end
  if rec and rec.none then return dim(ns.LocalizeText("  на аукционе нет")) end
  return ""
end

local function sourceText(s, fromItem)
  -- Recipes with no recipe item to find were taught by trainers in Classic.
  -- Forever also adds recipes Classic never had (Favor vendors, camping).
  if not s then
    return dim(ns.LocalizeText(fromItem and "предмет-рецепт, ещё не видно" or "тренер или новое в Forever"))
  end
  if s.kind == "ah" then
    return ("На аукционе: |cffffd100%s|r %s"):format(ns.Money(s.price), dim(("(лотов: %d)"):format(s.listed or 0)))
  end
  local classic = s.conf ~= "seen"
  local where = s.zone and (", " .. ns.LocalizeText(s.zone)) or ""
  local text
  if s.kind == "trainer" then
    -- Every trainer of a tier teaches the same list (owner, beta), and higher tiers teach
    -- the lower ones' too, so name the tier and give the one seen as an example.
    local v = s.npcID and ns.db.vendors[s.npcID]
    local prof, tier = v and v.profession, v and v.tier
    if v and not (prof and tier) then
      local p2, t2 = ns.TrainerFromTitle(v.title)   -- defined further down
      prof, tier = prof or p2, tier or t2
    end
    if tier and prof then
      text = ("Любой тренер %s+ %s, например %s%s"):format(tier, prof, s.npc or "?", where)
    else
      text = ("Тренер %s%s"):format(s.npc or "?", where)
    end
  elseif s.kind == "vendor" then
    local price = s.currency or (s.cost and ns.Money(s.cost)) or ""
    local side = (classic and s.otherSide) and otherSideText() or ""
    text = ("Торговец %s%s  %s%s%s"):format(s.npc or "?", where, price, s.limited and dim(" ограничено") or "", side)
  elseif s.kind == "mob" then
    text = ("Добывается с %s%s"):format(s.npc or "?", where) .. percent(s.chance) .. ahText(s)
  elseif s.kind == "drop" then
    if s.mobCount then
      -- Kept short so the price fits; the mobs are in the hover.
      text = ("Добыча в мире, %d видов существ"):format(s.mobCount)
    else
      text = (s.npc and ("Добывается с %s%s"):format(s.npc, where) or (s.zone and ("Добыча в мире: " .. s.zone) or "Добыча в мире, редкое"))
        .. percent(s.chance)
    end
    text = text .. ahText(s)
  elseif s.kind == "quest" then
    text = ("Задание: %s"):format(s.quest or "?") .. (s.otherSide and otherSideText() or "")
  else
    text = s.kind or "?"
  end
  -- Short, so prices fit; the hover and summary line explain it.
  return text .. (classic and dim(ns.LocalizeText("  (Classic)")) or "")
end

---------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------
local f
local rows = {}
local current     -- profession shown, or "Trainers:<profession>"

-- num: sorts high to low first (text sorts A to Z first; Type in the usual group order).
local COLS = {
  { key = "name", label = "Рецепт", w = 150, grow = 1 },
  { key = "skill", label = "Навык", w = 42, num = true },
  { key = "known", label = "Известно", w = 110 },
  { key = "source", label = "Откуда (наведите для всех)", w = 230, grow = 1 },
  { key = "type", label = "Тип", w = 104 },
  { key = "profit", label = "На изготовление", w = 100, num = true },
  { key = "pin", label = "", w = 36 },
}
local NUMERIC = {}   -- [key] = true for numbers, false for text; columns with a label only
for _, c in ipairs(COLS) do if c.label ~= "" then NUMERIC[c.key] = c.num or false end end

-- The filters (November 16; Frank: Recipes needs filters, it's a long list).
local SOURCE_OPTS = {
  { value = "all", label = "Любой источник" }, { value = "trainer", label = "Тренер" }, { value = "vendor", label = "Торговец" },
  { value = "drop", label = "Добыча" }, { value = "quest", label = "Задание" }, { value = "ah", label = "На аукционе" },
  { value = "unseen", label = "Ещё не видно" },
}
local SKILL_OPTS = { { value = "all", label = "Любой навык" }, { value = "now", label = "Можно выучить" }, { value = "later", label = "Нужно больше навыка" } }
local LEAST_OPTS = {
  { value = 0, label = "Любая прибыль" }, { value = 100, label = "1с и больше" }, { value = 1000, label = "10с и больше" },
  { value = 5000, label = "50с и больше" }, { value = 10000, label = "1g и больше" }, { value = 50000, label = "5g и больше" },
}

-- Which Where from choice a recipe's source falls under. No source: a trainer (or new in
-- Forever), unless the game's data says a recipe item teaches it.
local function sourceKind(src, fromItem)
  if not src then return fromItem and "unseen" or "trainer" end
  if src.kind == "mob" or src.kind == "drop" then return "drop" end
  return src.kind
end
ns.RecipeSourceKind = sourceKind   -- (tests)

-- The tabs: this character's professions (main ones first, then secondary), then
-- Trainers; every other profession with a recipe book goes in the "Другие профессии"
-- dropdown, starred when another character on this realm and faction has it (owner's
-- test, October 4: all professions as tabs was too many).
local function professions()
  local me = ns.db.chars[ns.CharKey()]
  local mine, others, seen = {}, {}, {}
  for p in pairs((me and me.profs) or {}) do
    if hasRecipes(p) then mine[#mine + 1] = p; seen[p] = true end
  end
  table.sort(mine, function(a, b)
    if (SECONDARY[a] or false) ~= (SECONDARY[b] or false) then return not SECONDARY[a] end
    return a < b
  end)
  foreverBook("")   -- (builds the index)
  for _, set in ipairs({ ns.db.recipeBook, fcByProf }) do
    for p in pairs(set) do
      if not seen[p] then others[#others + 1] = p; seen[p] = true end
    end
  end
  table.sort(others)
  return mine, others
end

-- The rank of a profession by its skill cap, as a coin: gold Artisan (300), silver Expert
-- (225), copper Journeyman (150), none for Apprentice (owner, October 4).
local RANKS = { { 300, "Искусник", "Interface\\MoneyFrame\\UI-GoldIcon" }, { 225, "Эксперт", "Interface\\MoneyFrame\\UI-SilverIcon" },
  { 150, "Подмастерье", "Interface\\MoneyFrame\\UI-CopperIcon" }, { 0, "Ученик", "Interface\\COMMON\\Indicator-Gray" } }   -- (a grey dot, so every tab lines up: owner, October 4)
local function rankOf(max)
  for _, r in ipairs(RANKS) do if (max or 0) >= r[1] then return r[2], r[3] end end
end

-- Who else on this realm and faction has a profession (first names), or nil.
local function othersWith(prof)
  local names = {}
  for key, c in pairs(ns.db.chars) do
    if key ~= ns.CharKey() and ns:SameMarketChar(key) and c.profs and c.profs[prof] then
      names[#names + 1] = (c.name or key):match("^(%S+)") or c.name
    end
  end
  table.sort(names)
  return #names > 0 and table.concat(names, ", ") or nil
end
local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12:0:0|t "

StaticPopupDialogs["FOREVER_LEDGER_CLEAR_TYPES"] = {
  text = "Сбросить типы, заданные для %d рецептов? Они вернутся к автоматическим. Это необратимо.",
  button1 = YES or "Yes",
  button2 = NO or "No",
  OnAccept = function()
    wipe(ns.db.recipeTypes)
    ns:Print("Ваши типы рецептов сброшены.")
    ns:RefreshRecipes()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function ns:BuildRecipes(parent)
  f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  f.tabs = {}
  -- Two rows of choices (redesign build step 6, November 16): what to show, then how
  -- to narrow it. Trainers and Crates hide both.
  f.second = CreateFrame("Frame", nil, f)
  f.second:SetPoint("TOPLEFT", 0, -30)
  f.second:SetPoint("TOPRIGHT", 0, -30)
  f.second:SetHeight(24)
  f.third = CreateFrame("Frame", nil, f)
  f.third:SetPoint("TOPLEFT", 0, -56)
  f.third:SetPoint("TOPRIGHT", 0, -56)
  f.third:SetHeight(24)

  local function tip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      ns:TooltipAddLine(title, 1, 1, 1)
      ns:TooltipAddLine(text, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end

  local s = settings()
  f.show = T:Choice(f.second, { { value = "all", label = "Все" }, { value = "unknown", label = "Не изучено" }, { value = "known", label = "Известно" } },
    function(v) s.view = v; ns:RefreshRecipes() end)
  f.show:SetPoint("LEFT", 0, 0)
  -- Short labels so the row fits the window.
  -- A dropdown: six buttons pushed Use my types off the window with wider fonts
  -- (owner's test, October 4).
  local typeOpts = { { value = "all", label = "Любой тип" } }
  for _, k in ipairs(ORDER) do typeOpts[#typeOpts + 1] = { value = k, label = TYPES[k].short } end
  f.type = T:Dropdown(f.second, 120, function(v) s.type = v; ns:RefreshRecipes() end)
  f.type:SetOptions(typeOpts)
  f.type:SetPoint("LEFT", f.show, "RIGHT", 14, 0)
  tip(f.type, "Тип", "Перепродажа или цепочка, изготовление на продажу, услуги чар, не на продажу или невыгодно, по сегодняшним ценам. Правый клик по рецепту — задать свой.")
  f.source = T:Dropdown(f.second, 130, function(v) s.source = v; ns:RefreshRecipes() end)
  f.source:SetOptions(SOURCE_OPTS)
  f.source:SetPoint("LEFT", f.type, "RIGHT", 8, 0)
  tip(f.source, "Откуда", "Где учат рецепту: сначала то, что вы видели в игре, иначе данные оригинального Classic. «Ещё не видно»: рецепт даёт предмет, который никто не встречал.")
  f.skill = T:Dropdown(f.second, 140, function(v) s.skill = v; ns:RefreshRecipes() end)
  f.skill:SetOptions(SKILL_OPTS)
  f.skill:SetPoint("LEFT", f.source, "RIGHT", 8, 0)
  tip(f.skill, "Навык", "«Можно выучить»: у одного из ваших персонажей этого мира и фракции хватает навыка. «Нужно больше навыка»: ни у кого пока нет.")

  f.group = T:Dropdown(f.third, 170, function(v) s.group = v; ns:RefreshRecipes() end)
  f.group:SetPoint("LEFT", 0, 0)
  tip(f.group, "Группа", "Что делает рецепт, по группам вкладки «Группы»: зелья, тканевая броня, 16–25 уровень... Показаны только группы, в которых эта профессия что-то делает.")
  f.least = T:Dropdown(f.third, 110, function(v) s.least = v; ns:RefreshRecipes() end)
  f.least:SetOptions(LEAST_OPTS)
  f.least:SetPoint("LEFT", f.group, "RIGHT", 8, 0)
  tip(f.least, "Минимальная прибыль", "Скрыть рецепты, которые дают меньше этого за изготовление по сегодняшним ценам (и те, у которых нет цены).")
  f.search = T:EditBox(f.third, 130, "LEFT")
  f.search:SetPoint("LEFT", f.least, "RIGHT", 14, 0)
  f.custom = T:Check(f.third, function(self) s.custom = self:GetChecked(); ns:RefreshRecipes() end)
  f.custom.label:SetText("Использовать мои типы")
  f.custom:SetHitRectInsets(0, -(f.custom.label:GetStringWidth() + 8), 0, 0)   -- the name ticks it too
  f.custom:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    ns:TooltipAddLine("Мои типы", 1, 1, 1)
    ns:TooltipAddLine("Вкл: у рецептов, которым вы задали тип правым кликом, он сохраняется. Выкл: все рецепты используют автоматический тип (ваш выбор сохранится).", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  f.custom:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.custom:SetPoint("LEFT", f.search, "RIGHT", 14, 0)
  f.clear = T:Button(f.third, "Сбросить типы", 110, function()
    local n = 0
    for _ in pairs(ns.db.recipeTypes) do n = n + 1 end
    if n == 0 then ns:Print(ns.LocalizeText("Вы ещё не задавали типы.")); return end
    ns:ShowPopup("FOREVER_LEDGER_CLEAR_TYPES", n)
  end, 22)
  f.clear:SetPoint("LEFT", f.custom.label, "RIGHT", 14, 0)
  local hint = T:Text(f.search, 11, T.section)
  hint:SetPoint("LEFT", 6, 0)
  hint:SetText("Поиск рецептов")
  f.search:SetScript("OnTextChanged", function(self)
    hint:SetShown(self:GetText() == "" and not self:HasFocus())
    ns:RefreshRecipes()
  end)
  f.search:SetScript("OnEditFocusGained", function() hint:Hide() end)
  f.search:SetScript("OnEditFocusLost", function(self) hint:SetShown(self:GetText() == "") end)
  f.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

  -- The header and list move up when Trainers hides the rows of choices.
  f.header = CreateFrame("Frame", nil, f)
  f.header:SetHeight(22)
  T:Fill(f.header, { 1, 1, 1, 0.05 })
  f.heads = {}
  f.sf, f.content = T:Scroll(f)
  f.summary = T:Text(f, 11, T.dim)
  f.summary:SetPoint("BOTTOMLEFT", 4, 2)
  f.empty = T:Text(f.content, 12, T.dim)
  f.empty:SetPoint("TOPLEFT", 8, -8)
  f.empty:SetPoint("RIGHT", f.content, "RIGHT", -8, 0)
  f.empty:SetJustifyH("LEFT")

  -- Waylaid Crates live here too, as a tab after Trainers (Crates.lua builds the view).
  f.cratesHost = CreateFrame("Frame", nil, f)
  f.cratesHost:SetPoint("TOPLEFT", 0, -30)
  f.cratesHost:SetPoint("BOTTOMRIGHT")
  f.cratesHost:Hide()
  ns:BuildCrates(f.cratesHost)
  -- Craftsman's Writs beside them (Writs.lua).
  f.writsHost = CreateFrame("Frame", nil, f)
  f.writsHost:SetPoint("TOPLEFT", 0, -30)
  f.writsHost:SetPoint("BOTTOMRIGHT")
  f.writsHost:Hide()
  ns:BuildWrits(f.writsHost)
  return f
end

-- Profession sub-tabs (with their rank coin), Trainers, and the Other professions dropdown.
local function layoutTabs(list, others)
  local me = ns.db.chars[ns.CharKey()] or { profs = {} }
  me.profs = me.profs or {}
  local sig = table.concat(list, ",") .. "|" .. table.concat(others, ",") .. "|" .. tostring(ns.db.settings.crates)
  for _, p in ipairs(list) do sig = sig .. ":" .. tostring(me.profs[p] and me.profs[p].max) end
  if f.tabSig ~= sig then
    for _, b in pairs(f.tabs) do b:Hide() end
    f.tabs = {}
    local prev
    local function add(key, label, tip)
      local b = T:Tab(f, label, function() current = key; ns:RefreshRecipes() end)
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 0, 0) else b:SetPoint("TOPLEFT", -6, 4) end
      if tip then
        b:HookScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
          ns:TooltipAddLine(tip, 1, 1, 1)
          GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
      end
      f.tabs[key] = b
      prev = b
    end
    for _, p in ipairs(list) do
      local info = me.profs[p]
      local rank, icon = rankOf(info and info.max)
      add(p, (icon and ("|T" .. icon .. ":12:12:0:0|t ") or "") .. p,
        ("%s %s/%s, %s"):format(p, tostring(info and info.rank or "?"), tostring(info and info.max or "?"), rank))
    end
    add("trainers", "Тренеры")
    if ns.db.settings.crates then add("crates", "Ящики", "Забытые ящики: самый дешёвый способ заполнить каждый") end
    if ns.db.settings.crates then add("writs", "Заказы", "Заказы ремесленника: сколько стоит каждый заказ в репутации") end
    -- Other professions: a dropdown after the tabs.
    if not f.other then
      f.other = T:Dropdown(f, 170, function(v) if v ~= "" then current = v; ns:RefreshRecipes() end end)
      f.other:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        ns:TooltipAddLine("Другие профессии", 1, 1, 1)
        ns:TooltipAddLine("Профессии, которых нет у этого персонажа. Звёздочка: есть у другого вашего персонажа этого мира и фракции.", nil, nil, nil, true)
        GameTooltip:Show()
      end)
      f.other:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local opts = { { value = "", label = "Другие профессии" } }
    for _, p in ipairs(others) do
      local who = othersWith(p)
      opts[#opts + 1] = { value = p, label = who and (STAR .. p .. "  |cff888888" .. who .. "|r") or p }
    end
    f.other:SetOptions(opts)
    f.other:ClearAllPoints()
    f.other:SetPoint("LEFT", prev, "RIGHT", 10, 0)
    f.other:SetShown(#others > 0)
    f.tabSig = sig
  end
  local isOther = false
  for _, p in ipairs(others) do if p == current then isOther = true end end
  if not current or not (f.tabs[current] or isOther) then current = list[1] or "trainers" end
  for key, b in pairs(f.tabs) do b:SetSelected(key == current) end
  f.other:SetValue(isOther and current or "")
  f.other:SetSelected(isOther)
end

-- Columns with grow share the room left over, so a wider window gives the recipe name
-- and Where from more space (owner's test, October 4: only the names got wider).
local function layout(cols, width)
  local fixed, grow = 0, 0
  for _, c in ipairs(cols) do fixed = fixed + (c.w or 150) + 8; grow = grow + (c.grow or 0) end
  local extra = math.max(0, width - fixed - 4)
  local x, out = 4, {}
  for _, c in ipairs(cols) do
    local w = (c.w or 150) + (grow > 0 and c.grow and math.floor(extra * c.grow / grow) or 0)
    out[c.key] = { x = x, w = w }
    x = x + w + 8
  end
  return out
end

local function getRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", nil, f.content)
  r:SetHeight(ROW)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r.stripe = T:Fill(r, { 1, 1, 1, 0.025 })
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.08)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.cells = {}
  for _, c in ipairs(COLS) do
    if c.key ~= "pin" then
      local fs = T:Text(r, 11)
      fs:SetWordWrap(false)
      fs:SetJustifyH(c.key == "profit" and "RIGHT" or "LEFT")
      r.cells[c.key] = fs
    end
  end
  r.pin = T:Button(r, "Метка", 46, function(self)
    local s = self:GetParent().src
    if s then ns:PinOnMap(s.mapID, s.x, s.y, s.npc or s.name) end
  end, 18)
  -- Right-click: set your own type (cycles through the types, then back to automatic).
  r:SetScript("OnClick", function(self, button)
    if button ~= "RightButton" or not self.recipeID then return end
    if not settings().custom then
      ns:Print("Сначала отметьте «Мои типы», чтобы задавать свои.")
      return
    end
    local overrides = ns.db.recipeTypes
    -- Shift-right-click: back to the automatic type.
    if IsShiftKeyDown() then
      overrides[self.recipeID] = nil
      ns:RefreshRecipes()
      return
    end
    local now = overrides[self.recipeID]
    local nextType
    if not now then nextType = ORDER[1] else
      for i, k in ipairs(ORDER) do if k == now then nextType = ORDER[i + 1] end end
    end
    overrides[self.recipeID] = nextType
    ns:RefreshRecipes()
  end)
  r:SetScript("OnEnter", function(self)
    if not self.out then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetItemByID(self.out)
    ns:AddClassicSourceLines(GameTooltip, self.recipeName)
    local price, rec = recipeAH(self.src)
    if price then
      ns:TooltipAddLine(" ")
      ns:TooltipAddDoubleLine("Рецепт на аукционе", ns.Money(price), 1, 0.82, 0, 1, 1, 1)
      ns:TooltipAddLine(ns.LocalizeText("лотов: %d, проверка %s"):format(rec.q or 0, ns.Age(rec.t)), 0.8, 0.8, 0.8)
    elseif rec and rec.none then
      ns:TooltipAddLine(" ")
      ns:TooltipAddLine(ns.LocalizeText("Рецепта нет на аукционе (проверка %s)"):format(ns.Age(rec.t)), 0.8, 0.8, 0.8)
    end
    ns:TooltipAddLine(" ")
    ns:TooltipAddLine("Правый клик — задать свой тип, Shift+правый клик — автоматический.", T.accent[1], T.accent[2], T.accent[3])
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  rows[i] = r
  return r
end

local function knownBy(prof, recipeID)
  local names = {}
  -- Characters who could craft it for you: same ruleset and faction (Core.lua).
  for key, c in pairs(ns.db.chars) do
    local p = ns:SameMarketChar(key) and c.profs and c.profs[prof]
    if p and p.recipes and p.recipes[recipeID] then names[#names + 1] = c.name or key end
  end
  table.sort(names)
  return names
end

-- Skill needed to learn a recipe: from a trainer seen in game, else Classic's, else the
-- game's data (the recipe item's requirement, or the skill the craft starts at).
local function skillFor(prof, id, r)
  local name = r and r.n
  if name then
    for _, s in pairs(ns.db.recipeSources[name:lower()] or {}) do
      if s.skill and s.skill > 0 then return s.skill end
    end
    local e = ns.CLASSIC_RECIPES and ns.CLASSIC_RECIPES[name:lower()]
    if e and e.skill then return e.skill end
  end
  local fc = foreverBook(prof)[id]
  return fc and (fc.learn or fc.rank)
end

-- Highest skill any of your characters has in a profession.
local function bestRank(prof)
  local best
  for key, c in pairs(ns.db.chars) do
    local p = ns:SameMarketChar(key) and c.profs and c.profs[prof]
    if p and p.rank then best = math.max(best or 0, p.rank) end
  end
  return best
end

-- Green: one of your characters has the skill; red: not yet.
local function skillText(skill, rank)
  if not skill then return dim("?") end
  if not rank then return tostring(skill) end
  return (rank >= skill and "|cff7fd39c%d|r" or "|cffee8597%d|r"):format(skill)
end

-- The Group choices for a profession: groups (built in, two levels deep, and yours) that
-- hold something it makes, with each output's set of groups. Worked out again when the
-- profession or its recipe count changes, or after a minute (groups can be edited).
local groupCache = {}
local function groupChoices(prof)
  local count = 0
  eachRecipe(prof, function() count = count + 1 end)
  local c = groupCache[prof]
  if c and c.count == count and GetTime() - c.t < 60 then return c end
  c = { count = count, t = GetTime(), sets = {}, opts = { { value = "all", label = "Любая группа" } } }
  local present = {}
  if ns.ItemGroupSet then
    eachRecipe(prof, function(_, r)
      if r.out and not c.sets[r.out] then
        c.sets[r.out] = ns:ItemGroupSet(r.out)
        for gid in pairs(c.sets[r.out]) do present[gid] = true end
      end
    end)
    for _, g in ipairs(ns:GroupTree()) do
      if present[g.id] and (g.kind == "user" or (g.kind == "builtin" and g.depth <= 1)) then
        c.opts[#c.opts + 1] = { value = g.id, label = (g.depth > 0 and "   " or "") .. g.name }
      end
    end
  end
  groupCache[prof] = c
  return c
end

-- What a row sorts by in a column (nil: no value, always last).
local function plain(text)
  return (text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):lower())
end
local function sortValue(e, key)
  if key == "name" then return e.r.n and e.r.n:lower() end
  if key == "skill" then return e.skill end
  if key == "known" then return #e.names > 0 and table.concat(e.names, ", "):lower() or nil end
  if key == "source" then return e.src and plain(sourceText(e.src)) or nil end
  if key == "type" then return typeRank[e.type] end   -- the usual group order, not A to Z
  if key == "profit" then return e.profit end
end

local function recipeRows(prof, width, lay)
  local rank = bestRank(prof)
  local s = settings()
  local match = (f.search:GetText() or ""):lower()
  local groups = groupChoices(prof)
  local fc = foreverBook(prof)
  local list = {}
  local total, knownCount = 0, 0
  eachRecipe(prof, function(id, r)
    local names = knownBy(prof, id)
    local known = #names > 0
    total = total + 1
    if known then knownCount = knownCount + 1 end
    if not ((s.view == "all" or (s.view == "known") == known) and (match == "" or (r.n or ""):lower():find(match, 1, true))) then return end
    if s.group ~= "all" and not (r.out and groups.sets[r.out] and groups.sets[r.out][s.group]) then return end
    local auto, profit = autoType(r)
    local mine = s.custom and ns.db.recipeTypes[id] or nil
    local t = mine or auto
    if s.type ~= "all" and s.type ~= t then return end
    if s.least > 0 and not (profit and profit >= s.least) then return end
    local skill = skillFor(prof, id, r)
    if s.skill == "now" and not (skill and rank and skill <= rank) then return end
    if s.skill == "later" and not (skill and (not rank or skill > rank)) then return end
    local fromItem = fc[id] and fc[id].learn and true or false
    local src = bestSource(r.n)
    if s.source ~= "all" and sourceKind(src, fromItem) ~= s.source then return end
    list[#list + 1] = { id = id, r = r, names = names, type = t, override = mine ~= nil, profit = profit,
      skill = skill, src = src, fromItem = fromItem }
  end)
  -- Grouped by type (flip or shuffle first), then most profit first.
  local function usual(a, b)
    if a.type ~= b.type then return typeRank[a.type] < typeRank[b.type] end
    if (a.profit ~= nil) ~= (b.profit ~= nil) then return a.profit ~= nil end
    if a.profit and b.profit and a.profit ~= b.profit then return a.profit > b.profit end
    return (a.r.n or "") < (b.r.n or "")
  end
  -- A clicked column heading: by that column, ties and rows with no value in the usual order.
  local sort = s.sort
  if sort and NUMERIC[sort.key] ~= nil then
    for _, e in ipairs(list) do e.sortBy = sortValue(e, sort.key) end
    table.sort(list, function(a, b)
      local va, vb = a.sortBy, b.sortBy
      if va == nil or vb == nil or va == vb then
        if (va == nil) ~= (vb == nil) then return va ~= nil end
        return usual(a, b)
      end
      if sort.desc then return va > vb end
      return va < vb
    end)
  else
    table.sort(list, usual)
  end
  local n = math.min(#list, MAX_ROWS)
  for i = 1, n do
    local e, row = list[i], getRow(i)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(i - 1) * ROW)
    row:SetWidth(width)
    row.stripe:SetShown(i % 2 == 0)
    row.recipeID, row.out, row.recipeName = e.id, e.r.out, e.r.n
    row.cells.profit:SetJustifyH("RIGHT")
    row.icon:SetTexture(e.r.out and ns:ItemIcon(e.r.out) or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", lay.name.x, 0)
    local src = e.src
    row.src = src
    local tinfo = TYPES[e.type]
    local values = {
      name = e.r.n or "?",
      skill = skillText(e.skill, rank),
      known = #e.names > 0 and table.concat(e.names, ", ") or (SECONDARY[prof] and "|cff7fd39cможет изучить любой|r" or dim("пока никто")),
      source = sourceText(src, e.fromItem),
      type = ("|cff%s%s|r%s"):format(tinfo.color, tinfo.label, e.override and dim(" (ваш)") or ""),
      profit = money(e.profit),
    }
    for key, fs in pairs(row.cells) do
      local x, w = lay[key].x, lay[key].w
      if key == "name" then x, w = x + 20, w - 20 end
      fs:ClearAllPoints()
      fs:SetPoint("LEFT", row, "LEFT", x, 0)
      fs:SetWidth(w)
      fs:SetText(values[key])
      fs:Show()
    end
    row.pin:ClearAllPoints()
    row.pin:SetPoint("LEFT", row, "LEFT", lay.pin.x, 0)
    row.pin:SetShown(src and src.mapID and src.x and true or false)
    row:Show()
  end
  f.summary:SetText(ns.LocalizeText("%s: рецептов %d, изучено %d. Показано %d%s. (Classic) — данные оригинального Classic, в Forever не подтверждены, пока вы их не увидите."):format(
    prof, total, knownCount, n, #list > MAX_ROWS and (" из " .. #list) or ""))
  return n, total
end

-- The Trainers view has its own column widths (same keys, so rows can be shared).
local TRAINER_PROF_RU = {
  Alchemy = "Алхимия", Blacksmithing = "Кузнечное дело", Enchanting = "Наложение чар",
  Engineering = "Инженерное дело", Herbalism = "Травничество", Leatherworking = "Кожевничество",
  Mining = "Горное дело", Skinning = "Снятие шкур", Tailoring = "Портняжное дело",
  Cooking = "Кулинария", Fishing = "Рыбная ловля", ["First Aid"] = "Первая помощь",
}
local TIER_RU = { Apprentice = "Ученик", Journeyman = "Подмастерье", Expert = "Эксперт", Artisan = "Искусник", Master = "Мастер" }
local TRAINER_COLS = {
  { key = "name", label = "Тренер", w = 150, grow = 1 },
  { key = "skill", label = "", w = 0 },
  { key = "known", label = "Профессия", w = 110 },
  { key = "source", label = "Где", w = 240, grow = 1 },
  { key = "type", label = "Уровень", w = 90 },
  { key = "profit", label = "Заголовок или заметка", w = 150 },   -- (330 + 230 ran off the window at its smallest: October 4)
  { key = "pin", label = "", w = 36 },
}

-- Profession and tier from a trainer's title: "Expert Tailor", "Tailoring Trainer".
local TITLE_PROF = {
  { "Tailor", "Tailoring" }, { "Enchant", "Enchanting" }, { "Cook", "Cooking" }, { "First Aid", "First Aid" },
  { "Physician", "First Aid" }, { "First Aid", "First Aid" }, { "Первая помощь", "First Aid" }, { "Fish", "Fishing" }, { "Alchemist", "Alchemy" }, { "Alchemy", "Alchemy" },
  { "Blacksmith", "Blacksmithing" }, { "Leatherwork", "Leatherworking" }, { "Engineer", "Engineering" },
  { "Herbalis", "Herbalism" }, { "Miner", "Mining" }, { "Mining", "Mining" }, { "Skinn", "Skinning" },
  { "Портн", "Tailoring" }, { "Зачаров", "Enchanting" }, { "Наложение чар", "Enchanting" },
  { "Кулинар", "Cooking" }, { "Повар", "Cooking" }, { "Рыбн", "Fishing" }, { "Рыбак", "Fishing" },
  { "Алхим", "Alchemy" }, { "Кузнец", "Blacksmithing" }, { "Кожевн", "Leatherworking" },
  { "Инженер", "Engineering" }, { "Травник", "Herbalism" }, { "Травнич", "Herbalism" },
  { "Горн", "Mining" }, { "Шахт", "Mining" }, { "Шкур", "Skinning" }, { "Первая помощь", "First Aid" },
}
local TIERS = { Apprentice = true, Journeyman = true, Expert = true, Artisan = true, Master = true }
local TIER_WORDS = { { "подмастерье", "Journeyman" }, { "искусник", "Artisan" }, { "ученик", "Apprentice" },
  { "эксперт", "Expert" }, { "мастер", "Master" } }
local function fromTitle(title)
  if not title then return end
  local prof
  for _, p in ipairs(TITLE_PROF) do
    if title:find(p[1], 1, true) then prof = p[2]; break end
  end
  local first = title:match("^(%a+)")
  if TIERS[first or ""] then return prof, first end
  local low = title:lower()
  for _, t in ipairs(TIER_WORDS) do
    if low:find(t[1], 1, true) then return prof, t[2] end
  end
  return prof
end
function ns.ProfessionFromTitle(title) return (fromTitle(title)) end
ns.TrainerFromTitle = fromTitle

local function trainerRows(width, lay)
  local list, seen = {}, {}
  local classicByName = {}
  for _, t in ipairs(ns.CLASSIC_TRAINERS or {}) do classicByName[t.name:lower()] = t end
  for npcID, v in pairs(ns.db.vendors) do
    if v.trainer then
      -- Fill what the trainer window didn't give: from the title, then the Classic list.
      local prof, tier = fromTitle(v.title)
      local c = v.name and classicByName[v.name:lower()]
      list[#list + 1] = { id = npcID, v = v, profession = v.profession or prof or (c and c.profession),
        tier = v.tier or tier or (c and c.tier) }
      if v.name then seen[v.name:lower()] = true end
    end
  end
  local classicCount = 0
  -- Classic trainers (ClassicRecipes.lua, positions from pfQuest) not visited yet.
  for _, t in ipairs(ns.CLASSIC_TRAINERS or {}) do
    if not seen[t.name:lower()] then
      local n = t.npc and classicNPC(t.npc, "trainer") or {}
      list[#list + 1] = { classic = true, profession = t.profession, tier = t.tier,
        v = { name = t.name, title = t.title, zone = n.zone or t.zone, x = n.x, y = n.y, mapID = n.mapID } }
      classicCount = classicCount + 1
    end
  end
  -- Where a city guard said each profession's trainer is (Probe.lua saves guard map
  -- flags with the option you picked). Forever's own positions: the shop, not the NPC.
  local PROFS = { Alchemy = true, Blacksmithing = true, Enchanting = true, Engineering = true, Herbalism = true,
    Leatherworking = true, Mining = true, Skinning = true, Tailoring = true, Cooking = true, ["First Aid"] = true,
    Fishing = true }
  -- When the flag names a trainer we know (Lucan Cordell), their profession wins over the
  -- option recorded: early tests sometimes recorded the option next to the one picked.
  local knownProf = {}
  for _, t in ipairs(ns.CLASSIC_TRAINERS or {}) do knownProf[t.name:lower()] = t.profession end
  for _, v in pairs(ns.db.vendors) do
    if v.trainer and v.name then
      local p = v.profession or (ns.ProfessionFromTitle and ns.ProfessionFromTitle(v.title))
      if p then knownProf[v.name:lower()] = p end
    end
  end
  local guardCount, latest = 0, {}
  for _, g in ipairs(ns.db.guardPOIs or {}) do
    -- Flags saved before the option fix (no v) only count when they name a known trainer.
    local prof = (g.name and knownProf[g.name:lower()]) or (g.v == 2 and g.option) or nil
    if prof and PROFS[prof] and g.mapID and g.x then latest[prof .. ":" .. g.mapID] = { g = g, prof = prof } end
  end
  -- A flag that names a trainer already listed doesn't get a row of its own: a visited
  -- trainer is already Forever's real spot, and a Classic one takes the guard's position
  -- (Shaina Fuller moved from 43.1, 26.2 in Classic to 52.9, 44.9 in Forever).
  local byName = {}
  for _, e in ipairs(list) do if e.v.name then byName[e.v.name:lower()] = e end end
  for key, entry in pairs(latest) do
    local same = entry.g.name and byName[entry.g.name:lower()]
    if same then
      latest[key] = nil
      if same.classic then
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(entry.g.mapID)
        same.classic, same.guard, same.named = nil, true, true
        same.v.zone, same.v.x, same.v.y, same.v.mapID = info and info.name or same.v.zone, entry.g.x, entry.g.y, entry.g.mapID
        classicCount = classicCount - 1
        guardCount = guardCount + 1
      end
    end
  end
  for _, entry in pairs(latest) do
    local g = entry.g
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(g.mapID)
    list[#list + 1] = { guard = true, profession = entry.prof,
      v = { name = g.name or "?", title = "от " .. (g.npc or "городской стражник"), zone = info and info.name or "?",
        x = g.x, y = g.y, mapID = g.mapID } }
    guardCount = guardCount + 1
  end
  local TIER = { Apprentice = 1, Journeyman = 2, Expert = 3, Artisan = 4 }
  table.sort(list, function(a, b)
    -- Unknown professions last.
    local pa, pb = a.profession or "~", b.profession or "~"
    if pa ~= pb then return pa < pb end
    local ta, tb = TIER[a.tier or ""] or 0, TIER[b.tier or ""] or 0
    if ta ~= tb then return ta > tb end
    return (a.v.name or "") < (b.v.name or "")
  end)
  for i, e in ipairs(list) do
    local row = getRow(i)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(i - 1) * ROW)
    row:SetWidth(width)
    row.stripe:SetShown(i % 2 == 0)
    row.recipeID, row.out, row.recipeName = nil, nil, nil
    row.cells.profit:SetJustifyH("LEFT")
    row.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", lay.name.x, 0)
    row.src = e.v
    local values = {
      name = e.v.name or "?",
      skill = "",
      known = (e.profession and (TRAINER_PROF_RU[e.profession] or e.profession)) or dim("?"),
      source = ("%s%s%s"):format(ns.LocalizeText(e.v.zone or "?"), e.v.x and ("  (%.1f, %.1f)"):format(e.v.x * 100, e.v.y * 100) or "",
        e.classic and dim(ns.LocalizeText("  (Classic)")) or e.guard and "  |cff7fd39c(стражник)|r" or ""),
      type = e.tier and (TIER_RU[e.tier] or e.tier) or (e.guard and not e.named and dim("магазин") or dim("?")),
      profit = e.v.title and dim(e.v.title) or "",
    }
    for key, fs in pairs(row.cells) do
      local x, w = lay[key].x, lay[key].w
      if key == "name" then x, w = x + 20, w - 20 end
      fs:ClearAllPoints()
      fs:SetPoint("LEFT", row, "LEFT", x, 0)
      fs:SetWidth(w)
      fs:SetText(values[key])
      fs:Show()
    end
    row.pin:ClearAllPoints()
    row.pin:SetPoint("LEFT", row, "LEFT", lay.pin.x, 0)
    row.pin:SetShown(e.v.mapID and e.v.x and true or false)
    row:Show()
  end
  f.summary:SetText(ns.LocalizeText("Тренеров найдено: %d, от городских стражников: %d, ещё из Classic: %d (не подтверждено). Спросите стражника о тренере профессии, чтобы добавить настоящее место в Forever."):format(
    #list - classicCount - guardCount, guardCount, classicCount))
  return #list
end

function ns:RefreshRecipes()
  if not f or not f:IsShown() then return end
  local ahlBefore = ns.AHledgerUses and ns.AHledgerUses() or 0
  local s = settings()
  f.show:SetValue(s.view)
  f.custom:SetChecked(s.custom)
  f.type:SetValue(s.type)
  f.source:SetValue(s.source)
  f.skill:SetValue(s.skill)
  f.least:SetValue(s.least)
  layoutTabs(professions())   -- (mine, others)
  local trainers, writs = current == "trainers", current == "writs"
  local crates = current == "crates" or writs   -- (the same: the list's parts hidden)
  f.second:SetShown(not trainers and not crates)
  f.third:SetShown(not trainers and not crates)
  f.header:SetShown(not crates)
  f.sf:SetShown(not crates)
  f.summary:SetShown(not crates)
  f.cratesHost:SetShown(crates and not writs)
  f.writsHost:SetShown(writs)
  if writs then ns:RefreshWrits(); return end
  if crates then ns:RefreshCrates(); return end
  local top = trainers and -30 or -84
  f.header:ClearAllPoints()
  f.header:SetPoint("TOPLEFT", 0, top)
  f.header:SetPoint("TOPRIGHT", 0, top)
  f.sf:ClearAllPoints()
  f.sf:SetPoint("TOPLEFT", 0, top - 24)
  f.sf:SetPoint("BOTTOMRIGHT", 0, 20)
  if not trainers and current then
    -- A group chosen for another profession that makes nothing in it here: back to Any.
    local opts = groupChoices(current).opts
    local found = false
    for _, o in ipairs(opts) do if o.value == s.group then found = true end end
    if not found then s.group = "all" end
    f.group:SetOptions(opts)
    f.group:SetValue(s.group)
  end

  local width = f:GetWidth() - 20   -- (clear of the scroll bar)
  local cols = trainers and TRAINER_COLS or COLS
  local lay = layout(cols, width)
  -- Recipe columns sort when their heading is clicked (not the Trainers view).
  local sort = not trainers and s.sort or nil
  for i, c in ipairs(cols) do
    local h = f.heads[i]
    if not h then
      h = CreateFrame("Button", nil, f.header)
      h.fs = T:Text(h, 11, T.dim)
      h.fs:SetAllPoints()
      h:SetScript("OnClick", function(self)
        if not self.key then return end
        local st = settings()
        local cur = st.sort
        if cur and cur.key == self.key then cur.desc = not cur.desc
        else st.sort = { key = self.key, desc = NUMERIC[self.key] and true or false } end
        ns:RefreshRecipes()
      end)
      f.heads[i] = h
    end
    local sortable = not trainers and c.label ~= ""
    h.key = sortable and c.key or nil
    h:EnableMouse(sortable)
    h:ClearAllPoints()
    h:SetPoint("LEFT", f.header, "LEFT", lay[c.key].x, 0)
    h:SetSize(math.max(lay[c.key].w, 1), 22)
    h.fs:SetJustifyH(c.key == "profit" and not trainers and "RIGHT" or "LEFT")
    local sorted = sort and sortable and sort.key == c.key
    h.fs:SetText(ns.LocalizeText(c.label) .. (sorted and (sort.desc and " v" or " ^") or ""))
    local col = sorted and { T.accent[1], T.accent[2], T.accent[3], 1 } or T.dim
    h.fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
  end

  f.content:SetWidth(width)
  local n, total = 0, 0
  if trainers then n = trainerRows(width, lay) elseif current then n, total = recipeRows(current, width, lay) end
  for i = n + 1, #rows do rows[i]:Hide() end
  f.empty:SetShown(n == 0)
  -- Recipes there but all hidden by the choices above: say which (Frank, AN6, November 13:
  -- Skinning looked empty on Known, as none of his characters knows its 3 recipes).
  local why = {}
  if s.view == "known" then why[#why + 1] = "Только известные" elseif s.view == "unknown" then why[#why + 1] = "Только неизвестные" end
  if s.type ~= "all" and TYPES[s.type] then why[#why + 1] = TYPES[s.type].label end
  local function label(opts, v)
    for _, o in ipairs(opts) do if o.value == v then return (o.label:gsub("^%s+", "")) end end
    return tostring(v)
  end
  if s.source ~= "all" then why[#why + 1] = label(SOURCE_OPTS, s.source) end
  if s.skill ~= "all" then why[#why + 1] = label(SKILL_OPTS, s.skill) end
  if s.group ~= "all" and current and not trainers then why[#why + 1] = label(groupChoices(current).opts, s.group) end
  if s.least > 0 then why[#why + 1] = label(LEAST_OPTS, s.least) end
  local match = f.search:GetText() or ""
  if match ~= "" then why[#why + 1] = ('поиск "%s"'):format(match) end
  if trainers then
    f.empty:SetText("Тренеры ещё не найдены. Откройте окно тренера профессии.")
  elseif total > 0 then
    f.empty:SetText(("%s: рецептов записано — %d, но под выбранное выше (%s) не подходит ни один. Выберите «Все» и «Любой», чтобы увидеть их."):format(
      current, total, table.concat(why, ", ")))
  else
    f.empty:SetText("Рецепты не найдены. Откройте окно этой профессии один раз, чтобы записать рецепты.")
  end
  -- AHledger's terms: its credit where its prices went into the costs and profits shown
  -- (Codex review, November 17).
  if ns.AHledgerUses and ns.AHledgerUses() ~= ahlBefore then
    f.summary:SetText((f.summary:GetText() or "") .. " " .. ns.AHLEDGER_CREDIT .. ".")
  end
  f.content:SetHeight(math.max(n * ROW, 30))
  f.sf.UpdateScrollBar()
end

ns.RefreshRecipes = ns.Timed("Вкладка «Рецепты»", ns.RefreshRecipes)
