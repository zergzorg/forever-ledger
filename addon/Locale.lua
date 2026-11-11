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

-- n followed by the right form of a counted noun: ns.Plural(3, "день", "дня", "дней").
function ns.Plural(n, one, few, many)
  n = math.abs(tonumber(n) or 0)
  local mod100, mod10 = n % 100, n % 10
  if mod100 >= 11 and mod100 <= 14 then return many end
  if mod10 == 1 then return one end
  if mod10 >= 2 and mod10 <= 4 then return few end
  return many
end
