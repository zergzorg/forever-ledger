local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- Quick disenchant (Frank, November 16; ideas from SKTools' Quick Salvage and TSM's
-- destroying window, no code from either). Two ways, each one hardware click per
-- disenchant, as Blizzard requires:
--   * Hold Ctrl+Alt (Settings, Disenchanting) and click a green or better item in your
--     bags: an invisible secure button sits over the slot you're pointing at, and the
--     click casts Disenchant on that item.
--   * The Disenchant window (/fl disenchant, or the Disenchant button at the top of the
--     main window): the items in your bags that can be disenchanted, with what each
--     brings; tick the ones to disenchant (only ticked ones: owner's rule, bulk actions
--     only on items you marked; "Tick suggested" ticks the ones the sell suggestion says
--     to disenchant), then click Disenchant next, once per item.
-- Secure buttons can't be moved or changed in combat, so neither works in combat.
---------------------------------------------------------------------------
local DISENCHANT = 13262
local KEYS = {
  ctrlalt = { name = "Ctrl+Alt", test = function() return IsControlKeyDown() and IsAltKeyDown() and not IsShiftKeyDown() end },
  shiftalt = { name = "Shift+Alt", test = function() return IsShiftKeyDown() and IsAltKeyDown() and not IsControlKeyDown() end },
  alt = { name = "Alt", test = function() return IsAltKeyDown() and not IsControlKeyDown() and not IsShiftKeyDown() end },
}
ns.QUICK_DE_KEYS = KEYS

local function S() return ns.db.settings end
local function keyOf() return KEYS[S().quickDEKey] or KEYS.ctrlalt end
function ns:QuickDisenchantKeyName() return keyOf().name end

local function spellName()
  local n
  if C_Spell and C_Spell.GetSpellName then n = C_Spell.GetSpellName(DISENCHANT) end
  if not n and GetSpellInfo then n = GetSpellInfo(DISENCHANT) end
  return n or "Disenchant"
end

-- This character can disenchant (knows the spell, or has Enchanting).
function ns:CanDisenchantHere()
  for _, f in ipairs({ IsPlayerSpell, IsSpellKnown }) do
    local ok, known = pcall(f, DISENCHANT)
    if ok and known then return true end
  end
  local c = ns.db.chars[ns.CharKey()]
  return c and c.profs and c.profs.Enchanting ~= nil or false
end

local function itemAt(bag, slot)
  if not (C_Container and C_Container.GetContainerItemInfo) then return end
  local info = C_Container.GetContainerItemInfo(bag, slot)
  return info and info.itemID, info
end

-- Gear the disenchant table covers (green, blue or purple armor and weapons).
local function deOK(id) return id and ns.DisenchantYield and ns:DisenchantYield(id) ~= nil end

-- The macro a click runs: cast Disenchant, then use the item in that slot as its target.
local function macro(bag, slot) return ("/cast %s\n/use %d %d"):format(spellName(), bag, slot) end

-- A secure button drawn in the addon's style (T:Button isn't secure).
local function secureButton(name, parent, w, h)
  local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  b:SetSize(w, h)
  b:RegisterForClicks("AnyUp", "AnyDown")   -- (either setting of "cast on key down")
  b:SetAttribute("type", "macro")
  return b
end

---------------------------------------------------------------------------
-- Hold the key and click in your bags
---------------------------------------------------------------------------
local over   -- the button over a bag slot

local function overlay()
  if over then return over end
  over = secureButton("ForeverLedgerQuickDisenchant", UIParent, 10, 10)
  over:SetFrameStrata("TOOLTIP")
  over:Hide()
  local glow = over:CreateTexture(nil, "OVERLAY")
  glow:SetAllPoints()
  glow:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.25)
  over:SetScript("OnEnter", function(self)
    if not self.bag then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(self.bag, self.slot)
    GameTooltip:AddLine(("Клик — распылить (%s зажато)."):format(keyOf().name), T.accent[1], T.accent[2], T.accent[3], true)
    GameTooltip:Show()
  end)
  over:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    if not InCombatLockdown() then self:Hide() end
  end)
  return over
end

local function hideOverlay()
  if over and over:IsShown() and not InCombatLockdown() then over:Hide() end
end

-- The bag and slot of a bag item button: Blizzard's (GetBagID), or the classic layout
-- (ContainerFrameNItemM: the slot's ID, its bag's ID on the parent).
local function bagSlotOf(owner)
  if not (owner and owner.GetID) then return end
  if owner.GetBagID then
    local ok, bag = pcall(owner.GetBagID, owner)
    if ok and type(bag) == "number" then return bag, owner:GetID() end
  end
  local name = owner.GetName and owner:GetName()
  if name and name:find("^ContainerFrame%d+Item%d+$") and owner:GetParent() then
    return owner:GetParent():GetID(), owner:GetID()
  end
end

-- Pointing at a bag item with the key held: cover the slot with the disenchant button.
local function tryArm()
  local s = S()
  if not s.quickDE or InCombatLockdown() or not keyOf().test() then return end
  if not GameTooltip:IsShown() then return end
  local owner = GameTooltip:GetOwner()
  if not owner or owner == over then return end
  local bag, slot = bagSlotOf(owner)
  if not bag then return end
  local id = itemAt(bag, slot)
  if not deOK(id) or not ns:CanDisenchantHere() then return end
  local b = overlay()
  b:ClearAllPoints()
  b:SetAllPoints(owner)
  b.bag, b.slot = bag, slot
  b:SetAttribute("macrotext", macro(bag, slot))
  b:Show()
end

local function onItemTooltip(tt)
  if tt == GameTooltip then tryArm() end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)
elseif GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnTooltipSetItem", onItemTooltip)
end

ns:On("MODIFIER_STATE_CHANGED", function()
  if keyOf().test() then tryArm() else hideOverlay() end
end)
ns:On("PLAYER_REGEN_DISABLED", function() if over then over:Hide() end end)   -- (still allowed as combat starts)
ns:On("BAG_UPDATE_DELAYED", function()
  -- The item was disenchanted (or moved): nothing to cover any more.
  if over and over:IsShown() and over.bag and not deOK(itemAt(over.bag, over.slot)) then hideOverlay() end
  if ns.RefreshDisenchantList then ns:RefreshDisenchantList() end
end)

---------------------------------------------------------------------------
-- The Disenchant window: tick items, then Disenchant next
---------------------------------------------------------------------------
local win
local ticked = {}      -- [itemID] = true (this session only)
local rows = {}
local ROW = 22

-- Every item in your bags that can be disenchanted: { id, bag, slot, value, suggested }.
function ns:DisenchantableItems()
  local out = {}
  if not (C_Container and C_Container.GetContainerNumSlots) then return out end
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local id, info = itemAt(bag, slot)
      if deOK(id) and not (info and info.isLocked) then
        local value = ns.DisenchantSaleValue and ns:DisenchantSaleValue(id)
        local ok, v = pcall(function() return ns.SellVerdict(ns:SellFacts(id, false, true)) end)
        out[#out + 1] = { id = id, bag = bag, slot = slot, value = value, suggested = ok and v and v.kind == "de" or false }
      end
    end
  end
  table.sort(out, function(a, b)
    if a.suggested ~= b.suggested then return a.suggested end
    return (a.value or 0) > (b.value or 0)
  end)
  return out
end

local function nextItem(items)
  for _, it in ipairs(items) do if ticked[it.id] then return it end end
end

local function getRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", nil, win.content)
  r:SetHeight(ROW)
  r.stripe = T:Fill(r, { 1, 1, 1, 0.025 })
  r.check = T:Check(r, function(self)
    if r.item then ticked[r.item.id] = self:GetChecked() and true or nil end
    ns:RefreshDisenchantList()
  end)
  r.check:SetPoint("LEFT", 4, 0)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT", r.check, "RIGHT", 6, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.value = T:Text(r, 11)
  r.value:SetPoint("RIGHT", -6, 0)
  r.value:SetJustifyH("RIGHT")
  r.name = T:Text(r, 11)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.name:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r:SetScript("OnEnter", function(self)
    if not self.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(self.item.bag, self.item.slot)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r:SetScript("OnClick", function(self) r.check:Click() end)
  rows[i] = r
  return r
end

local function build()
  win = ns.ThemedWindow("ForeverLedgerDisenchant", 400, 430, T:TitleCode() .. "Распыление|r")
  win:ClearAllPoints()
  win:SetPoint("CENTER", 220, 0)
  win.info = T:Text(win, 11, T.dim)
  win.info:SetPoint("TOPLEFT", 12, -38)
  win.info:SetPoint("RIGHT", win, "RIGHT", -12, 0)
  win.info:SetJustifyH("LEFT")
  win.tickSuggested = T:Button(win, "Отметить предложенное", 150, function()
    for _, it in ipairs(ns:DisenchantableItems()) do if it.suggested then ticked[it.id] = true end end
    ns:RefreshDisenchantList()
  end, 20)
  win.tickSuggested:SetPoint("TOPLEFT", win.info, "BOTTOMLEFT", 0, -6)
  win.tickNone = T:Button(win, "Снять все", 90, function() wipe(ticked); ns:RefreshDisenchantList() end, 20)
  win.tickNone:SetPoint("LEFT", win.tickSuggested, "RIGHT", 6, 0)
  win.sf, win.content = T:Scroll(win)
  win.sf:SetPoint("TOPLEFT", win.tickSuggested, "BOTTOMLEFT", 0, -6)
  win.sf:SetPoint("BOTTOMRIGHT", -10, 56)
  win.empty = T:Text(win.content, 12, T.dim)
  win.empty:SetPoint("TOPLEFT", 6, -6)
  win.empty:SetPoint("RIGHT", win.content, "RIGHT", -6, 0)
  win.empty:SetJustifyH("LEFT")

  -- Disenchant next: secure, one click per item.
  local nb = secureButton("ForeverLedgerDisenchantNext", win, 376, 30)
  nb:SetPoint("BOTTOM", 0, 14)
  T:Fill(nb, { T.accent[1], T.accent[2], T.accent[3], 0.18 })
  T:Border(nb)
  nb.hl = nb:CreateTexture(nil, "HIGHLIGHT")
  nb.hl:SetAllPoints()
  nb.hl:SetColorTexture(1, 1, 1, 0.08)
  nb.text = T:Text(nb, 13)
  nb.text:SetPoint("CENTER")
  nb:SetScript("OnEnter", function(self)
    if not self.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetBagItem(self.item.bag, self.item.slot)
    GameTooltip:Show()
  end)
  nb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  win.next = nb
  win:HookScript("OnShow", function() ns:RefreshDisenchantList() end)
end

local pending = false
function ns:RefreshDisenchantList()
  if not win or not win:IsShown() then return end
  local items = ns:DisenchantableItems()
  local can = ns:CanDisenchantHere()
  win.info:SetText(can and ("Отметьте, что распылять, и нажимайте кнопку ниже по одному предмету. Или держите %s и кликните по предмету в сумках. «Предложенное»: продажа советует распылить — это выгоднее."):format(keyOf().name)
    or "Этот персонаж не умеет распылять (нет наложения чар). Список показывает, что сделал бы чародей с вашими сумками.")
  local width = win.sf:GetWidth() - 12
  win.content:SetWidth(width)
  local total, n = 0, 0
  for i, it in ipairs(items) do
    local r = getRow(i)
    r.item = it
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, -(i - 1) * ROW)
    r:SetWidth(width)
    r.stripe:SetShown(i % 2 == 0)
    r.check:SetChecked(ticked[it.id] and true or false)
    r.icon:SetTexture(ns:ItemIcon(it.id))
    r.name:SetText(ns.ItemName(it.id) .. (it.suggested and (T:AccentCode() .. "  предложено|r") or ""))
    r.value:SetText(it.value and ns.Money(math.floor(it.value + 0.5)) or "|cff888888?|r")
    r:Show()
    if ticked[it.id] then total, n = total + (it.value or 0), n + 1 end
  end
  for i = #items + 1, #rows do rows[i]:Hide() end
  win.empty:SetText("В сумках нечего распылять: подходят зелёная, синяя и фиолетовая броня и оружие.")
  win.empty:SetShown(#items == 0)
  win.content:SetHeight(math.max(#items * ROW, 30))
  win.sf.UpdateScrollBar()

  -- The next ticked item onto the secure button (not in combat: done after it).
  if InCombatLockdown() then pending = true; return end
  local it = can and nextItem(items)
  local nb = win.next
  nb.item = it
  if it then
    nb:SetAttribute("macrotext", macro(it.bag, it.slot))
    nb.text:SetText(("Распылить: %s  |cff888888(отмечено %d, около %s)|r"):format(ns.ItemName(it.id), n, ns.Money(math.floor(total + 0.5))))
    nb:Enable()
  else
    nb:SetAttribute("macrotext", nil)
    nb.text:SetText(can and "|cff888888Отметьте предмет, чтобы распылить его|r" or "|cff888888У этого персонажа нет наложения чар|r")
    nb:Disable()
  end
end
ns.RefreshDisenchantList = ns.Timed("Disenchant window", ns.RefreshDisenchantList)

ns:On("PLAYER_REGEN_ENABLED", function()
  if pending then pending = false; ns:RefreshDisenchantList() end
end)

function ns:ToggleDisenchantList()
  if InCombatLockdown() then ns:Print("Окно распыления откроется после боя.") return end
  if not win then build() end
  win:SetShown(not win:IsShown())
end
