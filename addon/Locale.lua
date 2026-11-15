local ADDON, ns = ...

---------------------------------------------------------------------------
-- Russian localization support.
-- The addon's own text is translated in place (every file holds Russian now); this
-- file only carries what the client itself decides:
--  - fonts: Friz Quadrata has no Cyrillic glyphs in the Latin client build, so the
--    Cyrillic variants are used when the client ships them;
--  - plural forms: Russian needs three (1 день, 2 дня, 5 дней), which a plain
--    "%d days" cannot express.
---------------------------------------------------------------------------
ns.RU = (GetLocale and GetLocale() == "ruRU")

-- Font files differ per locale build: the ruRU client uses FRIZQT___CYR.TTF where the
-- others use FRIZQT__.TTF. SetFont returns false when a file is missing, so each
-- candidate is tried once and the first that loads wins.
do
  local probe = CreateFrame("Frame"):CreateFontString()
  local tried = {}
  local function loads(path)
    if tried[path] ~= nil then return tried[path] end
    local ok, result = pcall(probe.SetFont, probe, path, 12, "")
    tried[path] = ok and result ~= false
    return tried[path]
  end
  local CYR = {
    ["Fonts\\FRIZQT__.TTF"] = "Fonts\\FRIZQT___CYR.TTF",
    ["Fonts\\MORPHEUS.TTF"] = "Fonts\\MORPHEUS_CYR.TTF",
  }
  -- A Cyrillic-capable font for a path that may be Latin-only.
  function ns.FontPath(path)
    if not ns.RU then return path end
    local cyr = CYR[path]
    if cyr and loads(cyr) then return cyr end
    if cyr then return STANDARD_TEXT_FONT or path end
    return path
  end
end

-- English <-> the client's profession names. The game gives recipes under its own
-- language ("Алхимия"), while the addon's reference data uses English ("Alchemy").
local PROF_RU = {
  Alchemy = "Алхимия", Blacksmithing = "Кузнечное дело", Enchanting = "Наложение чар",
  Engineering = "Инженерное дело", Leatherworking = "Кожевничество", Tailoring = "Портняжное дело",
  Cooking = "Кулинария", ["First Aid"] = "Первая помощь", Fishing = "Рыбная ловля",
  Herbalism = "Травничество", Mining = "Горное дело", Skinning = "Снятие шкур",
}
local PROF_EN = {}
for en, ru in pairs(PROF_RU) do PROF_EN[ru] = en end

function ns.ProfName(prof)
  return PROF_RU[prof] or prof
end

function ns.ProfKey(prof)
  return PROF_EN[prof] or prof
end

-- n followed by the right form of a counted noun: ns.Plural(3, "день", "дня", "дней").
function ns.Plural(n, one, few, many)
  n = math.abs(tonumber(n) or 0)
  local mod100, mod10 = n % 100, n % 10
  if mod100 >= 11 and mod100 <= 14 then return many end
  if mod10 == 1 then return one end
  if mod10 >= 2 and mod10 <= 4 then return few end
  return many
end
