local _, ns = ...

---------------------------------------------------------------------------
-- Our tabs inside Blizzard's auction house window (redesign build step 3, November 15;
-- planning/REDESIGN_PLAN.md: Buy, Post, My auctions, "get it working first").
--
-- How: tabs made from the game's own auction house tab template sit after Browse, Sell
-- and Auctions. Picking one empties Blizzard's content area (SetDisplayMode with an
-- empty mode) and shows ours in its place; a hook on SetDisplayMode hides ours again
-- when a Blizzard tab is picked. When Auctionator or TradeSkillMaster are loaded they
-- bring the shared LibAHTab library, and our tabs go through it so all of them line up
-- in one row.
--
-- For now the tabs hold the existing panel (BuyQueue.lua): Buy = the Buy queue with
-- Shopping lists and the Disenchant finder; My auctions = your auctions. Post follows in
-- build step 4. Settings, Auction house, "Forever Ledger's tabs in the auction house"
-- (ahTabs) off puts the panel back beside the window.
---------------------------------------------------------------------------

local TABS = {
  { key = "buy", label = "Buy", title = "Forever Ledger: Buy" },
  { key = "post", label = "Post", title = "Forever Ledger: Post" },
  { key = "auctions", label = "My auctions", title = "Forever Ledger: My auctions" },
}

local host            -- our content area inside the auction house window
local buttons = {}    -- key = the tab button
local lib             -- LibAHTab when another addon brought it
local made, failed
local chosen          -- the tab picked last, kept while the window hides (Codex review, November 15)
local closingWith     -- what was chosen as the window closed
local lastBlizz = 1   -- Blizzard's tab picked last this visit (1 Buy, 2 Sell, 3 Auctions)
local hookedBlizz

function ns:AHTabsOn()
  return ns.db and ns.db.settings.ahTabs ~= false and not failed and AuctionHouseFrame ~= nil
end

-- Which of our tabs is showing, or nil.
function ns:AHTabShown()
  return host and host:IsShown() and host.key or nil
end

-- The tab you picked, even while the window is hidden; nil after picking a Blizzard tab.
function ns:AHTabChosen() return chosen end

-- The window's portrait (the auctioneer's face, top left) takes room our tabs can use
-- (owner, AH15, November 15): hidden while one of ours is open, back on Blizzard's tabs.
-- The game's ButtonFrameTemplate_HidePortrait swaps to the border without a portrait
-- ring; without it the portrait pieces are just hidden. Only what was shown comes back
-- (a UI addon may hide it itself).
local portraitHidden, portraitWasShown
local function setPortrait(show)
  local ah = AuctionHouseFrame
  if not ah then return end
  if show then
    if not portraitHidden then return end
    portraitHidden = false
    if portraitWasShown and ButtonFrameTemplate_ShowPortrait then pcall(ButtonFrameTemplate_ShowPortrait, ah) end
    for part in pairs(portraitWasShown or {}) do part:Show() end
    portraitWasShown = nil
    return
  end
  if portraitHidden then return end
  portraitHidden = true
  portraitWasShown = nil
  for _, part in pairs({ ah.PortraitContainer, ah.portrait, ah.PortraitFrame, _G.AuctionHouseFramePortrait }) do
    if part and part.IsShown and part:IsShown() then
      portraitWasShown = portraitWasShown or {}
      portraitWasShown[part] = true
    end
  end
  if not portraitWasShown then return end
  if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, ah) end
  for part in pairs(portraitWasShown) do part:Hide() end
end
function ns:AHPortraitHidden() return portraitHidden and portraitWasShown ~= nil end

local function deselectOurs()
  for _, b in pairs(buttons) do
    if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(b) end
  end
end

-- Our own tab row (no LibAHTab): the same steps the game's tabs take, after its last tab.
local function selectTab(key)
  local ah = AuctionHouseFrame
  ah:SetDisplayMode({})
  ah.displayMode = nil   -- so clicking the Blizzard tab that was open shows it again
  for _, b in ipairs(ah.Tabs or {}) do PanelTemplates_DeselectTab(b) end
  deselectOurs()
  PanelTemplates_SelectTab(buttons[key])
  for _, t in ipairs(TABS) do
    if t.key == key and ah.SetTitle then ah:SetTitle(t.title) end
  end
  host.key, chosen = key, key
  if host:IsShown() then host:GetScript("OnShow")(host) else host:Show() end
end

local function makeOwn()
  local ah = AuctionHouseFrame
  local last = ah.Tabs and ah.Tabs[#ah.Tabs]
  if not last then error("no auction house tabs") end
  -- The same gap as between Blizzard's own tabs (owner's screenshot, November 15: a
  -- guessed overlap made a hovered tab run into the next).
  local overlap = 3
  local t1, t2 = ah.Tabs[1], ah.Tabs[2]
  if t1 and t2 and t1:GetRight() and t2:GetLeft() then
    overlap = math.floor(t2:GetLeft() - t1:GetRight() + 0.5)
  end
  local root = CreateFrame("Frame", nil, ah)
  root:SetSize(10, 10)
  root:SetPoint("TOPLEFT", last, "TOPRIGHT", 0, 0)
  local prev
  for _, t in ipairs(TABS) do
    local b = CreateFrame("Button", "ForeverLedgerAHTab_" .. t.key, root, "AuctionHouseFrameDisplayModeTabTemplate")
    b:SetText(t.label)
    PanelTemplates_TabResize(b, 20, nil, 70)
    if prev then b:SetPoint("TOPLEFT", prev, "TOPRIGHT", overlap, 0)
    else b:SetPoint("TOPLEFT", root, "TOPLEFT", overlap, 0) end
    PanelTemplates_DeselectTab(b)
    b:SetScript("OnClick", function() selectTab(t.key) end)
    buttons[t.key] = b
    prev = b
  end
  hooksecurefunc(ah, "SetDisplayMode", function(_, mode)
    if mode ~= nil and #mode > 0 then
      deselectOurs()
      chosen = nil
      host:Hide()
    end
  end)
end

-- Through LibAHTab: one frame per tab, each showing our host when it opens.
local function makeShared()
  for _, t in ipairs(TABS) do
    local holder = CreateFrame("Frame", nil, AuctionHouseFrame)
    holder:SetAllPoints(host)
    holder:Hide()
    holder:SetScript("OnShow", function()
      host.key, chosen = t.key, t.key
      if host:IsShown() then host:GetScript("OnShow")(host) else host:Show() end
    end)
    holder:SetScript("OnHide", function()
      -- Another tab picked while the window stays open: no longer chosen. The window
      -- itself hiding (closing the auction house) keeps the choice for next visit.
      if chosen == t.key and AuctionHouseFrame:IsVisible() then chosen = nil end
      if host.key == t.key then host:Hide() end
    end)
    local id = "ForeverLedger_" .. t.key
    lib:CreateTab(id, holder, t.label, t.title)
    buttons[t.key] = lib:GetButton(id)
  end
end

local function make()
  if made or failed then return made end
  local ah = AuctionHouseFrame
  if not (ah and ah.SetDisplayMode and PanelTemplates_TabResize and PanelTemplates_SelectTab) then
    failed = true
    return false
  end
  -- Where Blizzard's own content goes: under the title bar, above the money line.
  host = CreateFrame("Frame", "ForeverLedgerAHTabHost", ah)
  host:SetPoint("TOPLEFT", ah, "TOPLEFT", 4, -26)
  host:SetPoint("BOTTOMRIGHT", ah, "BOTTOMRIGHT", -4, 27)
  host:SetFrameLevel(ah:GetFrameLevel() + 10)
  host:Hide()
  host:SetScript("OnShow", function(self)
    setPortrait(false)
    -- Post has its own view (Post.lua); Buy and My auctions show the Buy queue panel.
    local post = ns.PostFrame and ns:PostFrame(self)
    if self.key == "post" then
      if ns.HideSidePanelInside then ns:HideSidePanelInside() end
      if post then post:Show() end
    else
      if post then post:Hide() end
      if ns.ShowSidePanelInside then ns:ShowSidePanelInside(self, self.key == "auctions" and "auctions" or nil) end
    end
    if ns.UpdateAHScanButtons then ns:UpdateAHScanButtons() end
  end)
  host:SetScript("OnHide", function()
    -- The window closing hides us too: remember what was chosen before anything resets it.
    if not AuctionHouseFrame:IsVisible() then closingWith = chosen end
    setPortrait(true)
    if ns.HideSidePanelInside then ns:HideSidePanelInside() end
    if ns.UpdateAHScanButtons then ns:UpdateAHScanButtons() end
  end)
  lib = LibStub and LibStub("LibAHTab-1-0", true)
  local ok, err = pcall(lib and makeShared or makeOwn)
  if not ok then
    failed = true
    host:Hide()
    for _, b in pairs(buttons) do b:Hide() end
    ns:Debug("Auction house tabs couldn't be made, so the panel stays beside the window:", err)
    return false
  end
  made = true
  -- Blizzard's own tabs: note which one you pick, to open on it next visit too
  -- (owner, November 15: "it doesn't remember to open on the Auctions and Sell tabs").
  if not hookedBlizz then
    hookedBlizz = true
    for i, b in ipairs(AuctionHouseFrame.Tabs or {}) do
      b:HookScript("OnClick", function() lastBlizz = i end)
    end
  end
  return true
end

-- Opens one of our tabs ("buy" or "auctions"). False if the tabs aren't in use.
function ns:SelectAHTab(key)
  if not (ns:AHTabsOn() and ns:IsAHOpen() and make()) then return false end
  if lib then
    lib:SetSelected("ForeverLedger_" .. key)
  else
    selectTab(key)
  end
  return true
end

-- New flips while you're on a Blizzard tab: the Buy tab says how many, instead of the
-- view changing under your mouse. nil clears it.
function ns:MarkAHTab(n)
  local b = buttons.buy
  if not b then return end
  if n and n > 0 then b:SetText(("Buy (%d)"):format(n)) else b:SetText("Buy") end
  if PanelTemplates_TabResize then PanelTemplates_TabResize(b, 20, nil, 70) end
end

ns:On("AUCTION_HOUSE_SHOW", function()
  -- After the other addons' tabs (Auctionator adds its own as the window opens).
  C_Timer.After(0.3, function()
    if not ns:AHTabsOn() then
      for _, b in pairs(buttons) do b:Hide() end
      return
    end
    if not make() then return end
    for _, b in pairs(buttons) do b:Show() end
    ns:MarkAHTab(nil)
    -- Blizzard's Sell or Auctions if that's where you left (ours: BuyQueue.lua SetUpSidePanel).
    local q = ns.db.settings.buyQueue
    local tab = not q.ahTab and q.ahBlizzTab and AuctionHouseFrame.Tabs and AuctionHouseFrame.Tabs[q.ahBlizzTab]
    if tab and not chosen then tab:Click() end
    if ns.UpdateAHScanButtons then ns:UpdateAHScanButtons() end
  end)
end)

-- Remember which of our tabs was open, to open it again next visit (BuyQueue.lua
-- SetUpSidePanel). The window is already hidden, but our tab still counts as chosen.
ns:On("AUCTION_HOUSE_CLOSED", function()
  if not host then return end
  if ns:AHTabsOn() then
    local ours = closingWith or chosen
    ns.db.settings.buyQueue.ahTab = ours
    ns.db.settings.buyQueue.ahBlizzTab = (not ours and lastBlizz ~= 1) and lastBlizz or nil
  end
  closingWith, lastBlizz = nil, 1
  host:Hide()
end)

-- Settings: turning the tabs on or off while the auction house is open.
function ns:ApplyAHTabs()
  if not AuctionHouseFrame then return end
  local on = ns:AHTabsOn()
  if on and ns:IsAHOpen() then make() end
  for _, b in pairs(buttons) do b:SetShown(on) end
  if not on and host and host:IsShown() then
    host:Hide()
    if AuctionHouseFrameDisplayMode and AuctionHouseFrameDisplayMode.Buy then
      pcall(AuctionHouseFrame.SetDisplayMode, AuctionHouseFrame, AuctionHouseFrameDisplayMode.Buy)
    end
  end
  if ns.SetUpSidePanel and ns:IsAHOpen() then ns:SetUpSidePanel() end
  if ns.UpdateAHScanButtons then ns:UpdateAHScanButtons() end
end
