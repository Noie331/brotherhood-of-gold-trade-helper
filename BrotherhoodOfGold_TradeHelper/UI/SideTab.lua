-- The logo tab (the BoG crest) on the right edge of the profession window.
-- It sits above the window's own tabs and can be dragged up or down the edge; the spot is saved.
local _, ns = ...

local BOTTOM_GAP = 20 -- default: this far up from the window's bottom edge
local LOGO = 'Interface\\AddOns\\BrotherhoodOfGold_TradeHelper\\Media\\logo' -- Media/logo.tga, 128 px

-- y = offset from the window's top edge (a dragged spot), or nil for the default bottom spot.
local function setY(b, parent, y)
  b:ClearAllPoints()
  if y then b:SetPoint('TOPLEFT', parent, 'TOPRIGHT', 0, y)
  else b:SetPoint('BOTTOMLEFT', parent, 'BOTTOMRIGHT', 0, BOTTOM_GAP) end
end

local function create()
  if ns.sideTab then return end
  local parent = ProfessionsFrame or TradeSkillFrame
  if not parent then return end
  local b = CreateFrame('Button', 'BoG_SideTab', parent)
  b:SetSize(ns.View.TAB_SIZE, ns.View.TAB_SIZE)
  b:SetFrameStrata(parent:GetFrameStrata())
  b:SetFrameLevel(parent:GetFrameLevel() + 100) -- above the window's own tabs and other addons' buttons
  b:SetToplevel(true)
  setY(b, parent, ns.db and ns.db.ui.sideTabSpot)
  b:SetNormalTexture(LOGO)
  b:SetHighlightTexture(LOGO, 'ADD') -- the logo glows on hover

  b:RegisterForClicks('LeftButtonUp')
  b:RegisterForDrag('LeftButton')
  b:SetScript('OnDragStart', function(self)
    self.dragging = true
    self:SetScript('OnUpdate', function()
      local scale = parent:GetEffectiveScale()
      local _, cy = GetCursorPosition()
      local y = ns.View.TabOffset(cy / scale, parent:GetTop(), parent:GetHeight())
      setY(self, parent, y)
      self.y = y
    end)
  end)
  b:SetScript('OnDragStop', function(self)
    self:SetScript('OnUpdate', nil)
    if self.y and ns.db then ns.db.ui.sideTabSpot = self.y end
    C_Timer.After(0, function() self.dragging = false end)
  end)

  b:SetScript('OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
    GameTooltip:SetText('Brotherhood of Gold - Profession Helper')
    GameTooltip:AddLine('Click to open. Drag to move along the edge.', 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript('OnLeave', function() GameTooltip:Hide() end)
  b:SetScript('OnClick', function(self)
    if self.dragging then return end
    ns.Window.Open(ns.Recipes.CurrentName())
  end)
  ns.sideTab = b
end

local function loaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
  return IsAddOnLoaded and IsAddOnLoaded(name)
end

local f = CreateFrame('Frame')
f:RegisterEvent('ADDON_LOADED')
f:RegisterEvent('PLAYER_LOGIN')
f:SetScript('OnEvent', function(_, event, name)
  if event == 'PLAYER_LOGIN' then
    if loaded('Blizzard_Professions') or loaded('Blizzard_TradeSkillUI') then create() end
  elseif name == 'Blizzard_Professions' or name == 'Blizzard_TradeSkillUI' then
    create()
  end
end)
