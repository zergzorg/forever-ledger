local _, ns = ...

---------------------------------------------------------------------------
-- Trainers and the riding fund (owner, October 5). The training advice built on this (spell
-- casts, spellbook ranks, talent trees) was archived November 14 (Frank: other addons do it
-- better), with the Leveling tab and dungeon runs.
--  - What class and riding trainers teach, with cost and level, saved when a trainer
--    window is read (RecipeBook.lua reads it with every filter on and hands the list
--    here). /fl trainer shows the last one.
--  - Riding: whether the character knows it (ns:RidingTier), and what training costs.
--
-- ns.db.trainers[class] = { t, npc, spells = { [name] = { [sub] = { cost, level } } } }
-- ns.db.riding = { [service name] = { cost, level, t } }
---------------------------------------------------------------------------
local lastRead   -- the last trainer read: { name, npc, prof, list }

local function isRiding(name) return name and name:find("Riding", 1, true) ~= nil end

function ns:TrainerRead(list, npc, npcID, prof)
  lastRead = { npc = npc, prof = prof, list = list, t = time() }
  ns.db.riding = ns.db.riding or {}
  local riding, spells = 0, {}
  for _, s in ipairs(list) do
    if isRiding(s.name) then
      ns.db.riding[s.name] = { cost = s.cost, level = s.level, t = time() }
      riding = riding + 1
    elseif s.state ~= "header" and (not s.skill or s.skill == "") then
      -- No profession needed: a class spell (profession trainers' recipes name a skill).
      -- By level: Forever's second value is the spell's icon, not "Rank 2" (owner's
      -- /fl trainer, October 5), so ranks are counted from the levels (ns:SpellRanks).
      spells[s.name] = spells[s.name] or {}
      spells[s.name][s.level or 0] = s.cost or 0
    end
  end
  local n = 0
  for _ in pairs(spells) do n = n + 1 end
  -- A class trainer: more class spells than anything else and no profession.
  if n > 0 and not prof then
    local _, class = UnitClass("player")
    -- Added to what earlier visits saw, never replacing it (Codex review, October 6: a
    -- portal trainer that teaches only teleports wiped Frostbolt's saved ranks). Reference
    -- data is kept for good; a level seen again just updates its cost.
    ns.db.trainers = ns.db.trainers or {}
    local cat = ns.db.trainers[class or "?"] or { spells = {} }
    ns.db.trainers[class or "?"] = cat
    cat.spells = cat.spells or {}
    for name, levels in pairs(spells) do
      cat.spells[name] = cat.spells[name] or {}
      for level, cost in pairs(levels) do cat.spells[name][level] = cost end
    end
    cat.t, cat.npc = time(), npc
    ns:Debug(("Training: %s teaches %d %s spells (%d services)."):format(npc or "?", n, class or "?", #list))
  end
  if riding > 0 then ns:Debug(("Training: %d riding services seen at %s."):format(riding, npc or "?")) end
end


-- Riding the character knows: 0 none, 1 riding, 2 epic riding. Tried several ways, as
-- Forever's client may keep riding as spells (modern) or as a skill (Classic); the
-- beta check (/fl api, "Riding") says which works.
local RIDING_SPELLS = { { 33388, 1 }, { 33391, 2 }, { 34090, 2 }, { 34091, 2 } }
function ns:RidingTier()
  local best = 0
  for _, r in ipairs(RIDING_SPELLS) do
    local ok, known = pcall(function()
      return (IsPlayerSpell and IsPlayerSpell(r[1])) or (IsSpellKnown and IsSpellKnown(r[1]))
    end)
    if ok and known and r[2] > best then best = r[2] end
  end
  if best > 0 then return best end
  -- The spellbook, by name (Forever has no Classic skill list: owner's /fl api, October 5).
  for _, name in ipairs(ns:SpellbookRiding()) do
    local tier = (name:find("Apprentice", 1, true) and 1) or 2
    if tier > best then best = tier end
  end
  if best > 0 then return best end
  -- Classic's skill list: "Riding" and the old per-mount skills (Horse Riding, Ram Riding...).
  if GetNumSkillLines and GetSkillLineInfo then
    local ok, n = pcall(GetNumSkillLines)
    for i = 1, (ok and n or 0) do
      local okI, name, _, _, rank = pcall(GetSkillLineInfo, i)
      if okI and isRiding(name) then
        local tier = (rank or 0) >= 150 and 2 or 1
        if tier > best then best = tier end
      end
    end
  end
  return best
end

-- Spells in the spellbook with "Riding" in their name: the modern spellbook, else the
-- older one. Empty when neither can be read.
function ns:SpellbookRiding()
  local found = {}
  local SB = C_SpellBook
  local ok = pcall(function()
    if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemName then
      local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
      for i = 1, SB.GetNumSpellBookSkillLines() or 0 do
        local info = SB.GetSpellBookSkillLineInfo(i)
        for j = (info and info.itemIndexOffset or 0) + 1, (info and (info.itemIndexOffset + info.numSpellBookItems) or 0) do
          local name = SB.GetSpellBookItemName(j, bank)
          if name and isRiding(name) then found[#found + 1] = name end
        end
      end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
      for i = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(i)
        for j = (offset or 0) + 1, (offset or 0) + (count or 0) do
          local name = GetSpellBookItemName(j, BOOKTYPE_SPELL or "spell")
          if name and isRiding(name) then found[#found + 1] = name end
        end
      end
    end
  end)
  return ok and found or {}
end

-- For /fl api: what each way of telling says.
function ns:RidingReport()
  local parts = {}
  for _, r in ipairs(RIDING_SPELLS) do
    local ok, a, b = pcall(function()
      return IsPlayerSpell and IsPlayerSpell(r[1]), IsSpellKnown and IsSpellKnown(r[1])
    end)
    parts[#parts + 1] = ("%d %s/%s"):format(r[1], ok and tostring(a) or "err", ok and tostring(b) or "err")
  end
  local book = ns:SpellbookRiding()
  return ("tier %d; spells (player/known): %s; spellbook: %s"):format(ns:RidingTier(), table.concat(parts, ", "),
    #book > 0 and table.concat(book, ", ") or "no Riding spell")
end

-- /fl trainer: the last trainer read this session, every service with its state, rank,
-- cost and level, to check against the skip lists and see riding costs.
function ns:PrintTrainer()
  if not lastRead then
    ns:Print("Open a trainer first (class or riding); then /fl trainer lists what it teaches.")
    return
  end
  -- One line per spell, its ranks as "level cost" (owner, October 5: one line per rank
  -- was too long for chat), * on ranks you can learn now, + on ones you know.
  ns:Print(("%s (%s), %d services:"):format(lastRead.npc or "?", lastRead.prof or "class or riding", #lastRead.list))
  local order, by = {}, {}
  for _, s in ipairs(lastRead.list) do
    if not by[s.name] then by[s.name] = {}; order[#order + 1] = s.name end
    table.insert(by[s.name], s)
  end
  for _, name in ipairs(order) do
    local list = by[name]
    table.sort(list, function(a, b) return (a.level or 0) < (b.level or 0) end)
    local parts = {}
    for _, s in ipairs(list) do
      local mark = (s.state == "available" and "*") or (s.state == "used" and "+") or ""
      parts[#parts + 1] = ("%s%s %s"):format(mark, tostring(s.level or "?"), s.cost and ns.MoneyPlain(s.cost) or "?")
    end
    print(("  %s: %s"):format(name, table.concat(parts, ", ")))
  end
  print("  (* you can learn it now, + you know it)")
  -- Where Forever keeps the rank (Blizzard's window shows "Rank 4"; the list gives the
  -- state and icon): every value of the first service, and the spellbook's rank text.
  if GetTrainerServiceInfo and GetNumTrainerServices and (GetNumTrainerServices() or 0) > 0 then
    local vals = { pcall(GetTrainerServiceInfo, 1) }
    local parts = {}
    for i = 2, #vals do parts[#parts + 1] = tostring(vals[i]) end
    print("  First service, every value: " .. table.concat(parts, " | "))
    local ok, desc = pcall(function() return GetTrainerServiceDescription and GetTrainerServiceDescription(1) end)
    if ok and desc then print("  Its description: " .. tostring(desc):sub(1, 120)) end
  end
end

-- A spell's ranks at the trainer, lowest level first: { { level, cost }, ... }.
function ns:SpellRanks(name, class)
  local t = ns.db.trainers and ns.db.trainers[class or select(2, UnitClass("player")) or "?"]
  local ranks = {}
  for level, cost in pairs(t and t.spells[name] or {}) do ranks[#ranks + 1] = { level = level, cost = cost } end
  table.sort(ranks, function(a, b) return a.level < b.level end)
  return ranks
end

---------------------------------------------------------------------------
-- Riding fund (Dashboard.lua): the next riding this character doesn't know, what it
-- costs (as seen at a riding trainer, else the beta's reported price, marked "about"),
-- and the gold and pace from the Dashboard's own numbers. nil when it shouldn't show:
-- switched off (Settings, Global settings, Modules), hidden on this character (Hide
-- here; /fl fund brings it back), or the character knows epic riding.
---------------------------------------------------------------------------
-- Training as seen in the beta (owner, October 5, Binjy Featherwhistle: Apprentice
-- Riding 90g at 40, Journeyman Riding 900g at 60), plus a mount: about a ninth of the
-- training (owner's estimate: 10g and 100g; mounts are per character, so each needs
-- its own). The fund is the two together: 100g, then 1,000g.
local RIDING_GUESS = {
  { name = "Apprentice Riding", short = "Riding at 40", level = 40, training = 900000, mount = 100000, match = "Apprentice" },
  { name = "Journeyman Riding", short = "Epic riding at 60", level = 60, training = 9000000, mount = 1000000, match = "Journeyman" },
}
function ns:RidingFund(goldNow, totals, goldFirst)
  if ns.db.settings.ridingFund == false then return end
  local c = ns.db.chars[ns.CharKey()]
  if c and c.noRidingFund then return end
  local tier = ns:RidingTier()
  local want = RIDING_GUESS[tier + 1]
  if not want then return end
  local out = { name = want.name, short = want.short, level = want.level, training = want.training,
    mount = want.mount, seen = false }
  -- Seen at a riding trainer: the service whose name says its tier (Apprentice Riding...).
  for svc, r in pairs(ns.db.riding or {}) do
    if svc:find(want.match, 1, true) and r.cost then
      out.training, out.seen, out.name = r.cost, true, svc
      if r.level and r.level > 0 then out.level = r.level end
    end
  end
  out.cost = out.training + out.mount
  out.gold = goldNow or GetMoney()
  if goldNow and goldFirst and totals and totals.days and totals.days > 0 then
    out.perDay = (goldNow - goldFirst) / totals.days
  end
  return out
end

function ns:FundCommand()
  local c = ns.db.chars[ns.CharKey()]
  if c then c.noRidingFund = nil end
  if ns.db.settings.ridingFund == false then
    ns:Print("The riding fund is switched off everywhere: Settings, Global settings, Modules.")
  else
    ns:Print("Riding fund shown on this character's Dashboard again.")
  end
  ns:RefreshUI()
end

