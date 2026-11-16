local _, ns = ...
local T = ns.Theme

---------------------------------------------------------------------------
-- The Groups tab in the main window (redesign build step 6, November 15; mockups "Main
-- window: Groups, Items", "Groups, Rules" and "Groups page, Rules tab", with Frank's
-- comments). Groups.lua holds the data; this is the screen for it.
--   left    Groups | Rules. Groups: the tree (built in, special, profession, yours),
--           New group, Restore built-in groups. Rules: Forever Ledger's defaults (view
--           only, Copy) and your saved rules, New rule.
--   right   a group: Items (what's in it; add, remove, restore) | Rules (four cards, each
--           Same as the group above / Default / Off / Changed here / one of your rules,
--           with its fields). A saved rule: its fields, the groups using it, Copy, Rename,
--           Delete. Restores and deletes ask first (Frank: "click are you sure").
---------------------------------------------------------------------------

local f                     -- the tab
local state = { mode = "groups", group = "mat", view = "items", rule = nil, open = { mat = true } }
local NAV_W, ROW_H = 230, 18
local KIND_LABEL = { post = "Выставление", buy = "Покупка", vendor = "Торговец", craft = "Изготовление" }

local function copy(t) local c = {} for k, v in pairs(t or {}) do c[k] = v end return c end

---------------------------------------------------------------------------
-- Confirmations
---------------------------------------------------------------------------
local function confirm(text, onYes)
  StaticPopupDialogs["FOREVER_LEDGER_GROUPS_CONFIRM"] = {
    text = text, button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = onYes, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopup_Show("FOREVER_LEDGER_GROUPS_CONFIRM")
end

local function askName(text, start, onName)
  StaticPopupDialogs["FOREVER_LEDGER_GROUPS_NAME"] = {
    text = text, button1 = OKAY or "OK", button2 = CANCEL or "Cancel", hasEditBox = true,
    OnShow = function(self)
      local eb = self.editBox or self.EditBox
      if eb then eb:SetText(start or ""); eb:HighlightText() end
    end,
    OnAccept = function(self)
      local eb = self.editBox or self.EditBox
      local name = eb and eb:GetText() or ""
      if not name:match("^%s*$") then onName(name) end
    end,
    EditBoxOnEnterPressed = function(self)
      local p = self:GetParent()
      local name = self:GetText()
      if not name:match("^%s*$") then onName(name) end
      p:Hide()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopup_Show("FOREVER_LEDGER_GROUPS_NAME")
end

---------------------------------------------------------------------------
-- Rule fields: one editor per kind, used on a group's Rules cards and for saved rules.
---------------------------------------------------------------------------
local FIELDS = {
  post = {
    { key = "start", label = "Начать с", kind = "choice", options = { { value = "usual", label = "обычной цены" }, { value = "cheapest", label = "текущего минимума" } } },
    { key = "undercut", label = "Перебить минимум на", kind = "money" },
    { key = "floorPct", label = "Не ниже", kind = "number", suffix = "% обычной", min = 0, max = 200, step = 5 },
    { key = "belowFloor", label = "Если минимум ниже", kind = "choice", options = { { value = "skip", label = "не выставлять" }, { value = "floor", label = "выставить по порогу" } } },
    { key = "keep", label = "Оставить в сумках", kind = "number", min = 0, max = 1000, step = 1 },
    { key = "hours", label = "На сколько", kind = "choice", options = { { value = 2, label = "2 часа" }, { value = 8, label = "8 часов" }, { value = 24, label = "24 часа" } } },
  },
  buy = {
    { key = "underPct", label = "Покупать, если ниже", kind = "number", suffix = "% обычной", min = 5, max = 150, step = 5 },
    { key = "maxQty", label = "Не больше за раз", kind = "number", min = 1, max = 5000, step = 10 },
  },
  vendor = {
    { key = "protectRecipes", label = "Не предлагать продавать то, что нужно вашим рецептам", kind = "check" },
  },
  craft = {
    { key = "stock", label = "Держать в запасе", kind = "number", min = 0, max = 1000, step = 1 },
    { key = "minProfit", label = "Прибыль не меньше", kind = "money" },
  },
}

-- An editor for one kind's fields. onEdit(fields) runs with a full copy after a change.
local function fieldEditor(parent, kind, width, onEdit)
  local e = CreateFrame("Frame", nil, parent)
  e:SetSize(width, #FIELDS[kind] * 26)
  e.controls = {}
  local values = {}
  local function changed(key, v)
    values[key] = v
    onEdit(copy(values))
  end
  for i, def in ipairs(FIELDS[kind]) do
    local y = -(i - 1) * 26
    local label = T:Text(e, 11, T.dim)
    label:SetPoint("TOPLEFT", 0, y - 5)
    label:SetWidth(def.kind == "check" and (width - 24) or 132)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(def.label)
    local c
    if def.kind == "choice" then
      c = T:Dropdown(e, width - 140, function(v) changed(def.key, v) end)
      c:SetOptions(def.options)
    elseif def.kind == "money" then
      c = T:MoneyBox(e, function(v) if v then changed(def.key, v) end end)
      c:SetWidth(math.min(110, width - 140))
    elseif def.kind == "number" then
      c = T:Number(e, { min = def.min, max = def.max, step = def.step, suffix = def.suffix }, function(v) changed(def.key, v) end)
    elseif def.kind == "check" then
      c = T:Check(e, function(b) changed(def.key, b:GetChecked() and true or false) end)
      label:ClearAllPoints()
      label:SetPoint("TOPLEFT", 20, y - 5)
    end
    if def.kind == "check" then c:SetPoint("TOPLEFT", 0, y - 4)
    else c:SetPoint("TOPLEFT", 136, y) end
    c.def = def
    e.controls[#e.controls + 1] = c
  end
  -- Shows fields; editable false greys them out (a default, or a rule that follows another).
  function e:Load(fields, editable)
    values = copy(fields or ns.RULE_DEFAULTS[kind])
    for _, c in ipairs(self.controls) do
      local v = values[c.def.key]
      if c.def.kind == "check" then c:SetChecked(v and true or false)
      elseif c.SetValue then c:SetValue(v) end
      c:SetAlpha(editable and 1 or 0.5)
      if c.EnableMouse then c:EnableMouse(editable and true or false) end
      for _, child in ipairs({ c:GetChildren() }) do
        if child.EnableMouse then child:EnableMouse(editable and true or false) end
      end
    end
  end
  return e
end

---------------------------------------------------------------------------
-- Items in a group: every item we know of (prices, vendors, bags, watched, your groups),
-- sorted into groups a few hundred a frame the first time, then kept until groups change.
---------------------------------------------------------------------------
local sets, setsDirty, working = nil, true, false

local function knownItems()
  local ids, out = {}, {}
  local function add(id) if type(id) == "number" and id > 0 then ids[id] = true end end
  for id in pairs(ns.db.prices[ns.MarketKey()] or {}) do add(id) end
  for id in pairs(ns.db.vendorBuy or {}) do add(id) end
  for id in pairs(ns.db.watchItems or {}) do add(id) end
  for _, inv in pairs(ns.db.inventory or {}) do
    for id in pairs(inv.bags or {}) do add(id) end
    for id in pairs(inv.bank or {}) do add(id) end
  end
  local g = ns.db.groups or {}
  for _, u in pairs(g.user or {}) do for id in pairs(u.items or {}) do add(id) end end
  for _, t in pairs(g.added or {}) do for id in pairs(t) do add(id) end end
  for id in pairs(ids) do out[#out + 1] = id end
  return out
end

local refresh

local function rebuildSets()
  if working then return end
  working = true
  local ids, i, out = knownItems(), 0, {}
  local function step()
    local stop = math.min(i + 200, #ids)
    for k = i + 1, stop do out[ids[k]] = ns:ItemGroupSet(ids[k]) end
    i = stop
    if f and f.itemsNote then f.itemsNote:SetText(("Раскладываю %d из %d предметов по группам..."):format(i, #ids)) end
    if i < #ids then C_Timer.After(0, step) return end
    sets, setsDirty, working = out, false, false
    if refresh then refresh() end
  end
  step()
end

-- Something about groups changed: sort again next time the items show.
local function groupsChanged()
  setsDirty = true
  if ns.ForgetProfessionGroups then ns:ForgetProfessionGroups() end
end

local function itemsOf(gid)
  local out = {}
  for id, set in pairs(sets or {}) do
    if set[gid] then out[#out + 1] = id end
  end
  table.sort(out, function(a, b) return ns.ItemName(a) < ns.ItemName(b) end)
  return out
end

---------------------------------------------------------------------------
-- The left side
---------------------------------------------------------------------------
local function navRow(i)
  local r = f.navRows[i]
  if r then return r end
  r = CreateFrame("Button", nil, f.nav)
  r:SetHeight(ROW_H)
  r.bg = T:Fill(r, { 1, 1, 1, 0 })
  r.sel = T:Fill(r, { T.accent[1], T.accent[2], T.accent[3], 0.2 }, "BORDER")
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.12)
  r.arrow = T:Text(r, 11, T.dim)
  r.name = T:Text(r, 11)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r.note = T:Text(r, 10, T.dim)
  r.note:SetPoint("RIGHT", -4, 0)
  r.name:SetPoint("RIGHT", r.note, "LEFT", -4, 0)
  r:SetScript("OnClick", function(self)
    local it = self.item
    if not it then return end
    if it.heading then return end
    if it.group then
      local x = select(1, GetCursorPosition()) / self:GetEffectiveScale() - self:GetLeft()
      if it.hasKids and x < 16 + it.depth * 12 then
        state.open[it.group] = not state.open[it.group] or nil
      else
        state.group = it.group
      end
    elseif it.rule then
      state.rule = it.rule
    end
    refresh()
  end)
  f.navRows[i] = r
  return r
end

local function navItems()
  local items = {}
  if state.mode == "groups" then
    local tree = ns:GroupTree()
    local parentOf = {}
    for _, g in ipairs(tree) do
      local info = ns:GroupInfo(g.id)
      parentOf[g.id] = info and info.parent
    end
    local lastKind
    local headings = { builtin = "Встроенные", special = "Особые", profession = "По профессии (автоматически)", user = "Ваши группы" }
    for i, g in ipairs(tree) do
      if g.kind ~= lastKind then
        items[#items + 1] = { heading = headings[g.kind] or "" }
        lastKind = g.kind
      end
      local show, p = true, parentOf[g.id]
      while p do
        if not state.open[p] then show = false break end
        p = parentOf[p]
      end
      if show then
        local nxt = tree[i + 1]
        items[#items + 1] = { group = g.id, name = g.name, depth = g.depth, hasKids = nxt and nxt.depth > g.depth }
      end
    end
  else
    items[#items + 1] = { heading = "Наборы Forever Ledger по умолчанию" }
    for _, kind in ipairs(ns.RULE_KINDS) do
      items[#items + 1] = { rule = "default:" .. kind, name = "По умолчанию: " .. KIND_LABEL[kind]:lower(), note = "не меняется" }
    end
    items[#items + 1] = { heading = "Ваши правила" }
    local saved = (ns.db.groups or {}).saved or {}
    local ids = {}
    for rid in pairs(saved) do ids[#ids + 1] = rid end
    table.sort(ids, function(a, b) return (saved[a].name or ""):lower() < (saved[b].name or ""):lower() end)
    for _, rid in ipairs(ids) do
      local users = #ns:RuleUsers(rid)
      items[#items + 1] = { rule = rid, name = saved[rid].name, note = ("%s · %d"):format(KIND_LABEL[saved[rid].kind] or "?", users) }
    end
    if #ids == 0 then items[#items + 1] = { heading = "  пока нет: «Новое правило» или «Копировать»" } end
  end
  return items
end

local function drawNav()
  local items = navItems()
  local w = f.navSf:GetWidth() - 12
  for i, it in ipairs(items) do
    local r = navRow(i)
    r.item = it
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f.nav, "TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetWidth(w)
    r.name:ClearAllPoints()
    if it.heading then
      r.name:SetPoint("LEFT", 4, 0)
      r.name:SetText("|cff888888" .. it.heading:upper() .. "|r")
      r.arrow:SetText("")
      r.note:SetText("")
      r.bg:SetColorTexture(1, 1, 1, 0)
      r.sel:Hide()
      r:EnableMouse(false)
    else
      r:EnableMouse(true)
      local depth = it.depth or 0
      r.arrow:ClearAllPoints()
      r.arrow:SetPoint("LEFT", 4 + depth * 12, 0)
      r.arrow:SetText(it.hasKids and (state.open[it.group] and "-" or "+") or "")
      r.name:SetPoint("LEFT", 16 + depth * 12, 0)
      r.name:SetText(it.name)
      r.note:SetText(it.note or "")
      r.bg:SetColorTexture(1, 1, 1, ({ 0.06, 0.04, 0.025 })[math.min(depth + 1, 3)])
      r.sel:SetShown((it.group and it.group == state.group) or (it.rule and it.rule == state.rule) or false)
    end
    r:Show()
  end
  for i = #items + 1, #f.navRows do f.navRows[i]:Hide() end
  f.nav:SetHeight(math.max(#items * ROW_H, ROW_H))
  f.navSf.UpdateScrollBar()
  f.newGroup:SetShown(state.mode == "groups")
  f.restoreAll:SetShown(state.mode == "groups")
  f.newRule:SetShown(state.mode == "rules")
  f.modeGroups:SetSelected(state.mode == "groups")
  f.modeRules:SetSelected(state.mode == "rules")
end

---------------------------------------------------------------------------
-- A group: Items
---------------------------------------------------------------------------
local function itemRow(i)
  local r = f.itemRows[i]
  if r then return r end
  r = CreateFrame("Button", nil, f.items)
  r:SetHeight(ROW_H)
  r.stripe = T:Fill(r, { 1, 1, 1, 0.025 })
  r.sel = T:Fill(r, { T.accent[1], T.accent[2], T.accent[3], 0.2 }, "BORDER")
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.12)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(14, 14)
  r.icon:SetPoint("LEFT", 4, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.listed, r.usual, r.bags = T:Text(r, 11), T:Text(r, 11), T:Text(r, 11)
  r.listed:SetPoint("RIGHT", -4, 0)
  r.usual:SetPoint("RIGHT", -70, 0)
  r.bags:SetPoint("RIGHT", -160, 0)
  r.name = T:Text(r, 11)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", r.bags, "LEFT", -40, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r:SetScript("OnClick", function(self)
    state.item = (state.item ~= self.id) and self.id or nil
    refresh()
  end)
  r:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetItemByID(self.id)
    ns:TooltipAddLine(" ")
    ns:TooltipAddLine("Клик — выбрать, затем «Убрать из группы» уберёт его.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.itemRows[i] = r
  return r
end

local function drawItems(gid, info)
  if setsDirty and not working then rebuildSets() end
  local list = sets and itemsOf(gid) or {}
  local market = ns.db.prices[ns.MarketKey()] or {}
  local added = ((ns.db.groups or {}).added or {})[gid] or {}
  local w = f.itemsSf:GetWidth() - 12
  local n = math.min(#list, 400)
  for i = 1, n do
    local id = list[i]
    local r = itemRow(i)
    r.id = id
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f.items, "TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetWidth(w)
    r.stripe:SetShown(i % 2 == 0)
    r.sel:SetShown(state.item == id)
    r.icon:SetTexture(ns:ItemIcon(id))
    r.name:SetText(ns.ItemName(id) .. (added[id] and " |cff9fe8dc(добавлено вами)|r" or ""))
    local inBags = ns.ItemCount and ns.ItemCount(id, true) or 0
    r.bags:SetText(inBags > 0 and tostring(inBags) or "")
    local usual = ns.UsualPrice and ns:UsualPrice(id)
    r.usual:SetText(usual and ns.MoneyPlain(math.floor(usual)) or "|cff888888-|r")
    local rec = market[id]
    r.listed:SetText(rec and (rec.none and "0" or (rec.q and tostring(rec.q) or "")) or "")
    r:Show()
  end
  for i = n + 1, #f.itemRows do f.itemRows[i]:Hide() end
  f.items:SetHeight(math.max(n * ROW_H, ROW_H))
  f.itemsSf.UpdateScrollBar()
  if working then return end
  local builtin = info and info.kind == "builtin"
  local mine = info and info.kind == "user"
  f.itemsNote:SetText(#list == 0 and "Пока нет ни одного известного нам предмета."
    or (#list > n and ("Предметов: %d, показаны первые %d."):format(#list, n) or ("%d %s."):format(#list, ns.Plural(#list, "предмет", "предмета", "предметов"))))
  f.restoreItems:SetShown(builtin)
  f.addBox:SetShown(builtin or mine)
  f.addLabel:SetShown(builtin or mine)
  f.remove:SetShown(builtin or mine)
  f.remove:SetEnabled(state.item ~= nil)
  f.itemsHint:SetText((info and info.kind == "profession") and "Собрана из данных рецептов: вручную её не изменить."
    or (info and info.kind == "special") and "«Отслеживаемые»: добавьте предметы звёздочкой. «Серые предметы»: все предметы низкого качества." or "")
end

---------------------------------------------------------------------------
-- A group: Rules (four cards)
---------------------------------------------------------------------------
local function followOptions(gid, kind)
  local info = ns:GroupInfo(gid)
  local parent = info and info.parent and ns:GroupInfo(info.parent)
  local opts = {
    { value = "parent", label = parent and ("Как в «" .. parent.name .. "»") or "Как выше (по умолчанию)" },
    { value = "default", label = "По умолчанию Forever Ledger" },
    { value = "off", label = "Выкл" },
    { value = "changed", label = "Изменено здесь" },
  }
  local saved = (ns.db.groups or {}).saved or {}
  for rid, s in pairs(saved) do
    if s.kind == kind then opts[#opts + 1] = { value = "rule:" .. rid, label = "Ваше правило: " .. s.name } end
  end
  return opts
end

local function settingValue(gid, kind)
  local s = ns:GroupRuleSetting(gid, kind)
  if s == nil then return "parent" end
  if type(s) == "table" then return "changed" end
  return s
end

local function drawRules(gid)
  for _, kind in ipairs(ns.RULE_KINDS) do
    local card = f.cards[kind]
    card.gid = gid
    card.follow:SetOptions(followOptions(gid, kind))
    local value = settingValue(gid, kind)
    card.follow:SetValue(value)
    local fields, how, from, rid = ns:GroupRule(gid, kind)
    card.editor:Load(fields or ns.RULE_DEFAULTS[kind], value == "changed")
    card.editor:SetAlpha(how == "off" and 0.35 or 1)
    local fromName = from and ns:GroupInfo(from) and ns:GroupInfo(from).name
    local saved = rid and ((ns.db.groups or {}).saved or {})[rid]
    card.from:SetText(
      (how == "off" and ("Выкл" .. (from ~= gid and fromName and (" (из «" .. fromName .. "»)") or ""))) or
      (how == "rule" and ("Ваше правило " .. (saved and saved.name or "?") .. (from ~= gid and fromName and (" (из «" .. fromName .. "»)") or ""))) or
      (how == "changed" and (from == gid and "Изменено здесь" or ("Изменено в «" .. (fromName or "?") .. "»"))) or
      (from and from ~= gid and ("По умолчанию (задано в «" .. (fromName or "?") .. "»)")) or "По умолчанию Forever Ledger")
  end
end

---------------------------------------------------------------------------
-- A saved rule (Rules on the left)
---------------------------------------------------------------------------
local function drawRule()
  local r = state.rule
  local kind, fields, editable, title
  if r and r:match("^default:") then
    kind = r:match("^default:(.+)$")
    fields, editable, title = ns.RULE_DEFAULTS[kind], false, "По умолчанию: " .. KIND_LABEL[kind]:lower()
  else
    local saved = ((ns.db.groups or {}).saved or {})[r or ""]
    if not saved then
      f.ruleTitle:SetText("Выберите правило слева")
      for _, e in pairs(f.ruleEditors) do e:Hide() end
      f.ruleUsers:SetText("")
      f.ruleCopy:Hide(); f.ruleRename:Hide(); f.ruleDelete:Hide()
      return
    end
    kind, fields, editable, title = saved.kind, saved.fields, true, saved.name
  end
  f.ruleTitle:SetText(title .. (editable and ("  |cff888888" .. KIND_LABEL[kind]:lower() .. "|r") or ""))
  for k, e in pairs(f.ruleEditors) do e:SetShown(k == kind) end
  f.ruleEditors[kind]:Load(fields, editable)
  if editable then
    local users = ns:RuleUsers(r)
    local names = {}
    for _, gid in ipairs(users) do
      local info = ns:GroupInfo(gid)
      names[#names + 1] = info and info.name or gid
    end
    f.ruleUsers:SetText(#names == 0 and "Ни одна группа его пока не использует: выберите его в «Правилах» группы."
      or ("Используется: %d %s — %s. Изменение здесь затронет всех."):format(#names, ns.Plural(#names, "группа", "группы", "групп"), table.concat(names, ", ")))
  else
    f.ruleUsers:SetText("Наборы Forever Ledger по умолчанию не меняются: мы правим их в обновлениях, и группы «По умолчанию» всегда получают свежие. Скопируйте набор, чтобы сделать свой.")
  end
  f.ruleCopy:Show()
  f.ruleRename:SetShown(editable)
  f.ruleDelete:SetShown(editable)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
refresh = function()
  if not (f and f:IsVisible()) then return end
  drawNav()
  local groupMode = state.mode == "groups"
  f.groupPane:SetShown(groupMode)
  f.rulePane:SetShown(not groupMode)
  if not groupMode then drawRule(); return end
  local info = ns:GroupInfo(state.group)
  if not info then state.group = "mat"; info = ns:GroupInfo("mat") end
  local parent = info.parent and ns:GroupInfo(info.parent)
  local kinds = { builtin = "встроенная, поддерживается Forever Ledger", profession = "собрана из данных рецептов",
    special = "поддерживается Forever Ledger", user = "ваша группа" }
  f.title:SetText(info.name)
  f.sub:SetText((parent and (parent.name .. " › " .. info.name .. " · ") or "") .. (kinds[info.kind] or ""))
  f.viewItems:SetSelected(state.view == "items")
  f.viewRules:SetSelected(state.view == "rules")
  f.itemsPane:SetShown(state.view == "items")
  f.rulesPane:SetShown(state.view == "rules")
  f.renameGroup:SetShown(info.kind == "user")
  f.deleteGroup:SetShown(info.kind == "user")
  if state.view == "items" then drawItems(state.group, info) else drawRules(state.group) end
end

function ns:RefreshGroupsTab() refresh() end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function resolveItem(text)
  text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return end
  local id = tonumber(text:match("item:(%d+)") or text:match("^(%d+)$") or "")
  if id then return id end
  local lower = text:lower()
  for iid, name in pairs(ns.db.itemNames or {}) do
    if name:lower() == lower then return iid end
  end
end

function ns:BuildGroups(parent)
  f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()

  -- Left: Groups | Rules.
  f.modeGroups = T:Tab(f, "Группы", function() state.mode = "groups"; refresh() end)
  f.modeGroups:SetPoint("TOPLEFT", 0, 0)
  f.modeRules = T:Tab(f, "Правила", function() state.mode = "rules"; refresh() end)
  f.modeRules:SetPoint("LEFT", f.modeGroups, "RIGHT", 4, 0)
  f.navSf, f.nav = T:Scroll(f)
  f.navSf:SetPoint("TOPLEFT", 0, -30)
  f.navSf:SetPoint("BOTTOMLEFT", 0, 34)
  f.navSf:SetWidth(NAV_W)
  f.navRows = {}
  f.newGroup = T:Button(f, "Новая группа", 110, function()
    askName("Название новой группы:", "", function(name)
      local gid = ns:NewGroup(name)
      if gid then state.group, state.view = gid, "items"; groupsChanged(); refresh() end
    end)
  end, 22)
  f.newGroup:SetPoint("BOTTOMLEFT", 0, 4)
  f.restoreAll = T:Button(f, "Вернуть встроенные...", 116, function()
    local added, removed, rules = ns:BuiltinChanges()
    if added + removed + rules == 0 then ns:Print("Встроенные группы уже такие, какими их сделал Forever Ledger."); return end
    confirm(("Вернуть встроенные группы к наборам по умолчанию?\n\nУйдёт добавленных вами: %d. Вернётся убранных: %d. Правил, которые вы меняли, вернётся к «По умолчанию»: %d.\n\nВаши группы и сохранённые правила останутся. Отменить нельзя."):format(
      added, removed, rules), function()
      ns:RestoreBuiltinGroups(); groupsChanged(); refresh()
    end)
  end, 22)
  f.restoreAll:SetPoint("LEFT", f.newGroup, "RIGHT", 4, 0)
  f.newRule = T:Dropdown(f, NAV_W - 4, function(kind)
    askName(("Название нового правила: %s"):format(KIND_LABEL[kind]:lower()), "", function(name)
      local rid = ns:SaveRule(name, kind, ns.RULE_DEFAULTS[kind])
      if rid then state.rule = rid; refresh() end
    end)
  end)
  f.newRule:SetOptions({ { value = "post", label = "Новое правило: выставление" }, { value = "buy", label = "Новое правило: покупка" },
    { value = "vendor", label = "Новое правило: торговец" }, { value = "craft", label = "Новое правило: изготовление" } })
  f.newRule:SetText("Новое правило...")
  f.newRule:SetPoint("BOTTOMLEFT", 0, 4)

  -- Right: a group.
  local gp = CreateFrame("Frame", nil, f)
  gp:SetPoint("TOPLEFT", NAV_W + 16, 0)
  gp:SetPoint("BOTTOMRIGHT", 0, 0)
  f.groupPane = gp
  f.title = T:Text(gp, 16)
  f.title:SetPoint("TOPLEFT", 0, -2)
  f.sub = T:Text(gp, 11, T.dim)
  f.sub:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
  f.sub:SetPoint("RIGHT", gp, "RIGHT", -170, 0)
  f.sub:SetJustifyH("LEFT")
  f.sub:SetWordWrap(false)
  f.renameGroup = T:Button(gp, "Переименовать", 70, function()
    -- The group asked about, not whatever is picked when you answer (Codex review,
    -- November 15: the popups don't stop you picking another group meanwhile).
    local gid = state.group
    local info = ns:GroupInfo(gid)
    askName("Новое название группы:", info and info.name, function(name)
      if ns:GroupInfo(gid) then ns:RenameGroup(gid, name) end
      refresh()
    end)
  end, 22)
  f.renameGroup:SetPoint("TOPRIGHT", -84, 0)
  f.deleteGroup = T:Button(gp, "Удалить...", 80, function()
    local gid = state.group
    local info = ns:GroupInfo(gid)
    confirm(("Удалить вашу группу «%s»? Её предметы останутся в других группах; вложенные группы поднимутся выше. Отменить нельзя."):format(info and info.name or "?"), function()
      if not ns:GroupInfo(gid) then return end
      ns:DeleteGroup(gid)
      if state.group == gid then state.group = "mat" end
      groupsChanged(); refresh()
    end)
  end, 22)
  f.deleteGroup:SetPoint("TOPRIGHT", 0, 0)
  f.viewItems = T:Tab(gp, "Предметы", function() state.view = "items"; refresh() end)
  f.viewItems:SetPoint("TOPLEFT", 0, -26)
  f.viewRules = T:Tab(gp, "Правила", function() state.view = "rules"; refresh() end)
  f.viewRules:SetPoint("LEFT", f.viewItems, "RIGHT", 4, 0)

  -- Items.
  local ip = CreateFrame("Frame", nil, gp)
  ip:SetPoint("TOPLEFT", 0, -56)
  ip:SetPoint("BOTTOMRIGHT", 0, 0)
  f.itemsPane = ip
  f.addLabel = T:Text(ip, 11, T.dim)
  f.addLabel:SetPoint("TOPLEFT", 0, -5)
  f.addLabel:SetText("Добавить предмет:")
  f.addBox = T:EditBox(ip, 170, "LEFT")
  f.addBox:SetPoint("LEFT", f.addLabel, "RIGHT", 6, 0)
  f.addBox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    ns:TooltipAddLine("Добавить предмет", 1, 1, 1)
    ns:TooltipAddLine("Введите название или номер и нажмите Enter, либо кликните в поле и Shift+кликните предмет.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  f.addBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.addBox:SetScript("OnEnterPressed", function(self)
    local id = resolveItem(self:GetText())
    if not id then ns:Print("Предмет не найден: введите точное название или номер либо Shift+кликните его, когда поле активно."); return end
    if ns:AddToGroup(state.group, id) then groupsChanged() end
    self:SetText("")
    self:ClearFocus()
    refresh()
  end)
  if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
      if f.addBox:IsVisible() and f.addBox:HasFocus() and link then f.addBox:SetText(link) end
    end)
  end
  f.remove = T:Button(ip, "Убрать из группы", 140, function()
    if state.item and ns:RemoveFromGroup(state.group, state.item) then
      state.item = nil
      groupsChanged()
      refresh()
    end
  end, 22)
  f.remove:SetPoint("TOPRIGHT", 0, 0)
  f.restoreItems = T:Button(ip, "Вернуть предметы...", 110, function()
    local gid = state.group
    local added, removed = ns:BuiltinChanges(gid)
    if added + removed == 0 then ns:Print("Предметы этой группы уже такие, какими их сделал Forever Ledger."); return end
    local info = ns:GroupInfo(gid)
    confirm(("Вернуть предметы группы «%s» так, как их сделал Forever Ledger? Уйдёт добавленных вами: %d, вернётся убранных: %d. Правила останутся. Отменить нельзя."):format(
      info and info.name or "?", added, removed), function()
      ns:RestoreGroupItems(gid); groupsChanged(); refresh()
    end)
  end, 22)
  f.restoreItems:SetPoint("RIGHT", f.remove, "LEFT", -6, 0)
  -- The box fills the room up to the buttons (Frank's AN19 screenshot: it ran under them).
  f.addBox:SetPoint("RIGHT", f.restoreItems, "LEFT", -8, 0)
  local header = CreateFrame("Frame", nil, ip)
  header:SetPoint("TOPLEFT", 0, -30)
  header:SetPoint("TOPRIGHT", 0, -30)
  header:SetHeight(14)
  for _, c in ipairs({ { "Предмет", 24, "LEFT" }, { "В сумках", -170 }, { "Обычная", -80 }, { "Лотов", -14 } }) do
    local fs = T:Text(header, 10, T.dim)
    if c[3] == "LEFT" then fs:SetPoint("LEFT", c[2], 0) else fs:SetPoint("RIGHT", header, "RIGHT", c[2], 0) end
    fs:SetText(c[1])
  end
  f.itemsSf, f.items = T:Scroll(ip)
  f.itemsSf:SetPoint("TOPLEFT", 0, -46)
  f.itemsSf:SetPoint("BOTTOMRIGHT", 0, 22)
  f.itemRows = {}
  f.itemsNote = T:Text(ip, 11, T.dim)
  f.itemsNote:SetPoint("BOTTOMLEFT", 0, 4)
  f.itemsHint = T:Text(ip, 11, T.dim)
  f.itemsHint:SetPoint("LEFT", f.itemsNote, "RIGHT", 12, 0)

  -- Rules: four cards, two by two.
  local rp = CreateFrame("Frame", nil, gp)
  rp:SetPoint("TOPLEFT", 0, -56)
  rp:SetPoint("BOTTOMRIGHT", 0, 0)
  f.rulesPane = rp
  f.cards = {}
  local cardW = 296
  for i, kind in ipairs(ns.RULE_KINDS) do
    local card = CreateFrame("Frame", nil, rp)
    card:SetSize(cardW, 210)
    card:SetPoint("TOPLEFT", ((i - 1) % 2) * (cardW + 12), -math.floor((i - 1) / 2) * 216)
    T:Fill(card, { 1, 1, 1, 0.03 })
    T:Border(card)
    local name = T:Text(card, 13)
    name:SetPoint("TOPLEFT", 10, -10)
    name:SetText(KIND_LABEL[kind])
    card.follow = T:Dropdown(card, 190, function(v)
      local gid = card.gid
      if v == "changed" then
        ns:SetGroupRule(gid, kind, (ns:GroupRule(gid, kind)) or ns.RULE_DEFAULTS[kind])
      else
        ns:SetGroupRule(gid, kind, v)
      end
      refresh()
    end)
    card.follow:SetPoint("TOPRIGHT", -8, -6)
    card.follow:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      ns:TooltipAddLine(KIND_LABEL[kind] .. " rule", 1, 1, 1)
      ns:TooltipAddLine("«Как выше» повторяет группу, в которой находится; «По умолчанию» — набор Forever Ledger; «Изменено здесь» — своё для этой группы; или одно из ваших сохранённых правил. Если предмет в нескольких группах, побеждает ваша группа, затем группа профессии, затем встроенная.", nil, nil, nil, true)
      GameTooltip:Show()
    end)
    card.follow:HookScript("OnLeave", function() GameTooltip:Hide() end)
    card.editor = fieldEditor(card, kind, cardW - 20, function(fields)
      -- Changing a field makes it this group's own ("Changed here").
      ns:SetGroupRule(card.gid, kind, fields)
      refresh()
    end)
    card.editor:SetPoint("TOPLEFT", 10, -38)
    card.from = T:Text(card, 10, { 0.62, 0.91, 0.86 })
    card.from:SetPoint("BOTTOMLEFT", 10, 8)
    card.from:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    card.from:SetJustifyH("LEFT")
    f.cards[kind] = card
  end

  -- Right: a saved rule.
  local sp = CreateFrame("Frame", nil, f)
  sp:SetPoint("TOPLEFT", NAV_W + 16, 0)
  sp:SetPoint("BOTTOMRIGHT", 0, 0)
  f.rulePane = sp
  f.ruleTitle = T:Text(sp, 16)
  f.ruleTitle:SetPoint("TOPLEFT", 0, -2)
  f.ruleEditors = {}
  for _, kind in ipairs(ns.RULE_KINDS) do
    local e = fieldEditor(sp, kind, 320, function(fields)
      if state.rule and not state.rule:match("^default:") then ns:UpdateRule(state.rule, fields); refresh() end
    end)
    e:SetPoint("TOPLEFT", 0, -40)
    f.ruleEditors[kind] = e
  end
  f.ruleUsers = T:Text(sp, 11, T.dim)
  f.ruleUsers:SetPoint("TOPLEFT", 0, -230)
  f.ruleUsers:SetPoint("RIGHT", sp, "RIGHT", 0, 0)
  f.ruleUsers:SetJustifyH("LEFT")
  f.ruleCopy = T:Button(sp, "Копировать", 70, function()
    local r = state.rule
    local kind, fields, name
    if r:match("^default:") then
      kind = r:match("^default:(.+)$"); fields = ns.RULE_DEFAULTS[kind]; name = "Моё правило: " .. KIND_LABEL[kind]:lower()
    else
      local s = ns.db.groups.saved[r]; kind, fields, name = s.kind, s.fields, s.name .. " (копия)"
    end
    askName("Название копии:", name, function(n)
      local rid = ns:SaveRule(n, kind, fields)
      if rid then state.rule = rid; refresh() end
    end)
  end, 22)
  f.ruleCopy:SetPoint("TOPRIGHT", -170, 0)
  f.ruleRename = T:Button(sp, "Переименовать", 70, function()
    local s = ns.db.groups.saved[state.rule]
    askName("Новое название правила:", s and s.name, function(n) if s then s.name = n; refresh() end end)
  end, 22)
  f.ruleRename:SetPoint("LEFT", f.ruleCopy, "RIGHT", 6, 0)
  f.ruleDelete = T:Button(sp, "Удалить...", 80, function()
    local rid = state.rule
    local s = ns.db.groups.saved[rid]
    local users = #ns:RuleUsers(rid)
    confirm(("Удалить ваше правило «%s»? %d %s вернутся к «Как выше». Отменить нельзя."):format(
      s and s.name or "?", users, ns.Plural(users, "группа", "группы", "групп")), function()
      if not ns.db.groups.saved[rid] then return end
      ns:DeleteRule(rid)
      if state.rule == rid then state.rule = nil end
      refresh()
    end)
  end, 22)
  f.ruleDelete:SetPoint("LEFT", f.ruleRename, "RIGHT", 6, 0)

  f:SetScript("OnShow", function() refresh() end)
  f:Hide()
  return f
end
