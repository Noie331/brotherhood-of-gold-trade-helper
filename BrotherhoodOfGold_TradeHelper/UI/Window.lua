-- The addon window: profession tabs + Money Maker, Scan AH row, and the recipe list.
local _, ns = ...
local Window = {}
ns.Window = Window

local DOT = { optimal = 'ff8040', medium = 'ffff00', easy = '40c040', trivial = '808080' }
local GREEN, RED, GREY = '40c040', 'ff4040', '9a8f7a'
local GAP = 10 -- space above each recipe
local SUB = 14 -- height of a recipe's second (sell prices) line
local TICK = ' |TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t'

local frame, selected, tabButtons, scanBtn, statusText, sortAH, sortVendor, sortLabel, box
local sortCheap, sortLevelAH, sortLevelVendor
local pickButtons, recipesProf -- Recipes tab: profession picker and the picked profession
local questsProf -- Quests tab: the picked profession (same picker buttons)
local searchBox, recipesQuery -- Recipes tab: search box and its text
local unlearnedCheck -- Recipes tab: 'Not learned only' tick box (ns.db.ui.recipesUnlearned)
local moneyChecks = {} -- Money Maker: one tick box per profession
local ticker

local function M(v) if v == nil then return '-' end return ns.Format.MoneyIcons(v) end
local function col(hex, s) return '|cff' .. hex .. s .. '|r' end
local function profit(v)
  if v == nil then return '-' end
  if v >= 0 then return col(GREEN, '+' .. ns.Format.MoneyIcons(v)) end
  return col(RED, ns.Format.MoneyIcons(v))
end

-- ---------- rows ----------
local function initRow(row, line)
  if not row.left then
    row.dot = row:CreateTexture(nil, 'ARTWORK')
    row.dot:SetSize(8, 8)
    row.dot:SetTexture('Interface\\Buttons\\WHITE8X8')
    row.icon = row:CreateTexture(nil, 'ARTWORK')
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the default icon border
    row.left = row:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
    row.left:SetJustifyH('LEFT')
    row.left:SetWordWrap(false)
    -- Columns (list is ~598 px): dot 4, icon, left text to 188, mid 192-412, right 418-594. No overlap, no wrapping.
    row.mid = row:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
    row.mid:SetJustifyH('LEFT')
    row.mid:SetWidth(220)
    row.mid:SetWordWrap(false)
    row.right = row:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
    row.right:SetJustifyH('RIGHT')
    row.right:SetWidth(176)
    row.right:SetWordWrap(false)
    row.sub = row:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall') -- recipe's second line
    row.sub:SetJustifyH('LEFT')
    row.sub:SetWidth(400)
    row.sub:SetWordWrap(false)
  end
  row:SetAlpha(1)
  row.line = line -- hover shows the item's (or recipe's) own tooltip
  row.tip = nil -- full text shown on hover (Recipes tab: where to get the recipe)
  row.recipeLine = nil -- Recipes tab: click pins the nearest trainer/vendor/drop
  if not row.hoverSet then
    row.hoverSet = true
    row:SetScript('OnEnter', function(self)
      local what = self.line and ns.View.TooltipFor(self.line)
      if not what and not self.tip then return end
      GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
      local shown = false
      if what and what.itemID then shown = pcall(GameTooltip.SetItemByID, GameTooltip, what.itemID)
      elseif what and what.spellID then shown = pcall(GameTooltip.SetSpellByID, GameTooltip, what.spellID) end
      if self.tip then
        if shown then GameTooltip:AddLine(' ') else GameTooltip:SetText(self.tip[1]) end
        GameTooltip:AddLine(self.tip[2], 1, 1, 1, true)
      end
      local where = self.recipeLine and ns.Locate.TipLines(self.recipeLine) or {}
      if #where > 0 then
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine(self.recipeLine.questID and 'Where it starts' or 'Where to get it', 1, 0.82, 0)
        for _, t in ipairs(where) do
          GameTooltip:AddLine(t[1], 0.9, 0.8, 0.5)
          if t[2] then GameTooltip:AddLine('   ' .. t[2], 0.85, 0.85, 0.85) end
        end
        GameTooltip:AddLine(self.recipeLine.questID and 'Click: map pin on the quest giver'
          or 'Click: map pin on the nearest one', 0.5, 0.8, 0.5)
      end
      if what then GameTooltip:AddLine('Shift-click: link it in chat', 0.5, 0.8, 0.5) end
      GameTooltip:Show()
    end)
    row:SetScript('OnLeave', function() GameTooltip:Hide() end)
    row:SetScript('OnMouseUp', function(self, button)
      if button ~= 'LeftButton' then return end
      local linking = (IsModifiedClick and IsModifiedClick('CHATLINK')) or (IsShiftKeyDown and IsShiftKeyDown())
      if linking and ns.LinkToChat(self.line) then return end
      if self.recipeLine then ns.Locate.Show(self.recipeLine) end
    end)
  end
  row.dot:Hide()
  row.icon:Hide()
  row.left:SetFontObject('GameFontHighlightSmall')
  row.mid:SetText(''); row.right:SetText(''); row.sub:SetText('')
  row.mid:SetWidth(220); row.right:SetWidth(176)

  -- Recipe rows: GAP px of space on top, the main line, then a SUB px second line for sell prices.
  -- Offsets are from the row's vertical centre.
  local y = 0
  row.sub:ClearAllPoints(); row.sub:SetJustifyH('LEFT'); row.sub:SetJustifyV('MIDDLE')
  row.sub:SetWordWrap(false); row.sub:SetMaxLines(1)
  if line.kind == 'recipe' then
    y = (SUB - GAP) / 2
    row.sub:SetPoint('LEFT', 36, -(GAP + 20) / 2)
  elseif line.kind == 'catalog' or line.kind == 'quest' then -- GAP on top, the name line, then up to two lines of where to get it
    if line.source then
      y = (2 * SUB - GAP) / 2
      row.sub:SetPoint('TOPLEFT', row, 'LEFT', 36, y - 10)
      row.sub:SetPoint('TOPRIGHT', row, 'RIGHT', -4, y - 10)
      row.sub:SetJustifyV('TOP')
      row.sub:SetWordWrap(true); row.sub:SetMaxLines(2)
    else
      y = -GAP / 2
    end
  end
  row.dot:ClearAllPoints(); row.dot:SetPoint('LEFT', 4, y)
  row.mid:ClearAllPoints(); row.mid:SetPoint('LEFT', 192, y)
  row.right:ClearAllPoints(); row.right:SetPoint('RIGHT', -4, y)

  -- Place the icon (size, x) and start the name text just after it, ending at x=188.
  local function withIcon(texture, size, x)
    row.icon:SetSize(size, size)
    row.icon:ClearAllPoints()
    row.icon:SetPoint('LEFT', x, y)
    row.icon:SetTexture(texture)
    row.icon:Show()
    row.left:ClearAllPoints()
    row.left:SetPoint('LEFT', x + size + 4, y)
    row.left:SetWidth(188 - (x + size + 4))
  end

  if line.kind == 'header' then
    row.left:ClearAllPoints()
    row.left:SetPoint('LEFT', 4, -4)
    row.left:SetWidth(500)
    row.left:SetFontObject('GameFontNormal')
    row.left:SetText(col(DOT[line.difficulty] or DOT.trivial, line.text))
    return
  end

  if line.kind == 'message' then
    row.left:ClearAllPoints()
    row.left:SetPoint('LEFT', 18, 0)
    row.left:SetWidth(500)
    row.left:SetText(col(GREY, line.text))
    return
  end

  if line.kind == 'quest' then
    local done = line.status == 'done'
    withIcon(done and 'Interface\\GossipFrame\\ActiveQuestIcon' or 'Interface\\GossipFrame\\AvailableQuestIcon', 16, 16)
    row.left:SetFontObject('GameFontNormalSmall')
    row.left:SetWidth(400)
    local name = line.name or '?'
    if done then name = col(GREY, name) end
    local need = 'level ' .. (line.level or '?') .. (line.req and (', skill ' .. line.req) or '')
    row.left:SetText(name .. col(GREY, ' (' .. need .. ')'))
    if done then row.right:SetText(col(GREEN, 'Done') .. TICK)
    elseif line.status == 'active' then row.right:SetText(col('ffff00', 'In quest log'))
    else row.right:SetText(col(GREY, 'Not done')) end
    row.sub:SetText(col(GREY, line.source or ''))
    local tip = (line.obj and line.obj ~= '' and (line.obj .. '\n\n') or '') .. (line.source or '')
      .. '\nNeeds level ' .. (line.min or '?') .. (line.req and (' and ' .. line.req .. ' skill') or '')
    row.tip = { line.name or '', tip }
    row.recipeLine = line
    if done then row:SetAlpha(0.7) end
    return
  end

  if line.kind == 'catalog' then
    withIcon(line.icon or 134400, 16, 16)
    row.dot:SetVertexColor(CreateColorFromHexString('ff' .. (DOT[line.difficulty] or DOT.trivial)):GetRGB())
    row.dot:Show()
    row.left:SetFontObject('GameFontNormalSmall')
    row.left:SetWidth(400) -- no middle column on this tab
    local name = line.name or '...'
    if not line.learned then name = col(GREY, name) end
    if line.skill then name = name .. col(GREY, ' (' .. line.skill .. ')') end
    row.left:SetText(name)
    row.right:SetText(line.learned and col(GREEN, 'Learned') .. TICK or col(GREY, 'Not learned'))
    if line.source then
      row.sub:SetText(col(GREY, line.source))
      row.tip = { line.name or '', line.source }
      row.recipeLine = line
    end
    return
  end

  if line.kind == 'recipe' then
    withIcon(ns.Items.Icon(line.outputItemID) or line.icon or 134400, 16, 16)
    local e, money = line.eval, selected == ns.View.MONEY_TAB
    row.dot:SetVertexColor(CreateColorFromHexString('ff' .. (DOT[line.difficulty] or DOT.trivial)):GetRGB())
    row.dot:SetShown(not money)
    row.left:SetFontObject('GameFontNormalSmall')
    local name = line.name or '...'
    if money then name = name .. ' ' .. col(GREY, '(' .. (line.profession or '') .. ')') end
    row.left:SetText(name)
    local cost = (e.partial and '>= ' or '') .. M(e.cost)
    row.mid:SetText(col(GREY, 'Cost ') .. cost)
    row.mid:SetWidth(140); row.right:SetWidth(256) -- recipe rows: mid 192-332, AH | vendor profit 338-594
    row.sub:SetText(col(GREY, 'Sells  AH ') .. M(e.ahValue) .. col(GREY, '  |  Vendor ') .. M(e.vendorValue))
    if not line.outputItemID then
      row.sub:SetText(col(GREY, ns.View.NO_ITEM))
      row.right:SetText(col(GREY, 'Net ') .. col(RED, (ns.View.NoItemNet(e, ns.Format.MoneyIcons))))
    elseif money then
      row.right:SetText(profit(e.ahProfit) .. col(GREY, ' | ') .. profit(e.vendorProfit))
    else
      -- Profit (or loss) selling on the AH and to a vendor, side by side.
      local function side(value)
        local text, sign = ns.View.SideProfit(value, e.cost, e.partial, ns.Format.MoneyIcons)
        if sign == nil then return col(GREY, text) end
        return col(sign > 0 and GREEN or sign < 0 and RED or 'd0c4a8', text)
      end
      row.right:SetText(col(GREY, 'AH ') .. side(e.ahValue) .. col(GREY, '  |  V ') .. side(e.vendorValue))
    end
    if line.difficulty == 'trivial' and not money then row:SetAlpha(0.55) end
  else -- reagent
    withIcon(ns.Items.Icon(line.itemID), 14, 34)
    local name = ns.Items.Name(line.itemID) or '...'
    row.left:SetText(col('d0c4a8', name .. ' x' .. line.qty))
    -- AH and vendor price side by side, cheaper one ticked.
    row.mid:SetText(col(GREY, 'AH ') .. M(line.ah) .. (line.cheaper == 'ah' and TICK or '')
      .. col(GREY, '  |  V ') .. M(line.vendor) .. (line.cheaper == 'vendor' and TICK or ''))
  end
end

local function extent(_, line)
  if line.kind == 'recipe' then return GAP + 20 + SUB end
  if line.kind == 'message' then return 28 end
  if line.kind == 'catalog' then return GAP + 20 + (line.source and 2 * SUB or 0) end
  if line.kind == 'quest' then return GAP + 20 + 2 * SUB end
  if line.kind == 'header' then return 26 end
  return 16
end

-- ---------- status row ----------
function ns.RefreshStatus()
  if not frame or not frame:IsShown() then return end
  local A = ns.Auction
  local left = A.CooldownLeft()
  local ok, label = ns.Scan.ButtonState(A.IsOpen(), left, A.IsScanning(), A.Progress())
  scanBtn:SetText(label)
  scanBtn:SetEnabled(ok)
  local data = A.RealmData()
  local ago = data.scannedAt and (time() - data.scannedAt) or nil
  local text = 'AH data: ' .. ns.Format.Ago(ago)
  if left > 0 then text = text .. ' · next scan in ' .. ns.Format.Clock(left) end
  statusText:SetText(text)
end

-- ---------- tabs ----------
local function layoutTabs(names)
  tabButtons = tabButtons or {}
  local x = 12
  for i, name in ipairs(names) do
    local b = tabButtons[i]
    if not b then
      b = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
      b:SetHeight(22)
      b:SetScript('OnClick', function(self)
        if self.tabName == ns.View.RECIPES_TAB and ns.chardb.professions[selected] then recipesProf = selected end
        if self.tabName == ns.View.QUESTS_TAB and ns.chardb.professions[selected] then questsProf = selected end
        selected = self.tabName
        ns.Refresh()
      end)
      tabButtons[i] = b
    end
    b.tabName = name
    b:SetText(name)
    b:SetWidth(math.max(70, b:GetFontString():GetStringWidth() + 24))
    b:ClearAllPoints()
    b:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, -30)
    x = x + b:GetWidth() + 4
    if name == selected then b:LockHighlight() else b:UnlockHighlight() end
    b:Show()
  end
  for i = #names + 1, #tabButtons do tabButtons[i]:Hide() end
end

-- Recipes tab: one button per profession with a saved full list. Quests tab: one per profession with quests.
local function layoutPicker(names, show, current)
  pickButtons = pickButtons or {}
  local x = 12
  for i, name in ipairs(show and names or {}) do
    local b = pickButtons[i]
    if not b then
      b = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
      b:SetHeight(20)
      b:SetScript('OnClick', function(self)
        if selected == ns.View.QUESTS_TAB then questsProf = self.profName else recipesProf = self.profName end
        ns.Refresh()
      end)
      pickButtons[i] = b
    end
    b.profName = name
    b:SetText(name)
    b:SetWidth(math.max(70, b:GetFontString():GetStringWidth() + 20))
    b:ClearAllPoints()
    b:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, -84)
    x = x + b:GetWidth() + 4
    if name == current then b:LockHighlight() else b:UnlockHighlight() end
    b:Show()
  end
  for i = (show and #names or 0) + 1, #pickButtons do pickButtons[i]:Hide() end
end

-- Money Maker: a tick box per profession under the sort row; unticked ones are hidden (ns.db.ui.moneyHide).
local function layoutMoneyFilter(names)
  local x = 12
  for i, name in ipairs(names) do
    local c = moneyChecks[i]
    if not c then
      c = CreateFrame('CheckButton', nil, frame, 'UICheckButtonTemplate')
      c:SetSize(22, 22)
      c.label = c:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
      c.label:SetPoint('LEFT', c, 'RIGHT', 0, 1)
      c:SetScript('OnClick', function(self)
        ns.db.ui.moneyHide = ns.db.ui.moneyHide or {}
        ns.db.ui.moneyHide[self.profName] = (not self:GetChecked()) or nil
        ns.Refresh()
      end)
      moneyChecks[i] = c
    end
    c.profName = name
    c.label:SetText(name)
    c:SetChecked(not (ns.db.ui.moneyHide and ns.db.ui.moneyHide[name]))
    c:ClearAllPoints()
    c:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, -106)
    x = x + 22 + c.label:GetStringWidth() + 14
    c:Show()
  end
  for i = #names + 1, #moneyChecks do moneyChecks[i]:Hide() end
end

-- ---------- whole refresh ----------
function ns.Refresh()
  if not frame or not frame:IsShown() then return end
  local profs = ns.chardb.professions
  local names = ns.View.TabList(ns.Recipes.TrainedNames(), profs)
  local valid = false
  for _, n in ipairs(names) do if n == selected then valid = true end end
  if not valid then selected = names[1] end
  layoutTabs(names)

  local money = selected == ns.View.MONEY_TAB
  sortAH:SetShown(money); sortVendor:SetShown(money)
  sortAH:SetChecked(ns.db.ui.moneySort ~= 'vendor')
  sortVendor:SetChecked(ns.db.ui.moneySort == 'vendor')
  local prof = not money and selected ~= ns.View.RECIPES_TAB and selected ~= ns.View.QUESTS_TAB
  sortLabel:SetShown(money or prof)
  sortCheap:SetShown(prof); sortLevelAH:SetShown(prof); sortLevelVendor:SetShown(prof)
  local ls = ns.db.ui.levelSort
  sortCheap:SetChecked(ls ~= 'ah' and ls ~= 'vendor')
  sortLevelAH:SetChecked(ls == 'ah'); sortLevelVendor:SetChecked(ls == 'vendor')

  local recipesTab = selected == ns.View.RECIPES_TAB
  local picks = ns.View.CatalogProfessions(profs)
  if recipesTab then
    local ok = false
    for _, n in ipairs(picks) do if n == recipesProf then ok = true end end
    if not ok then
      local open = ns.Recipes.CurrentName()
      recipesProf = (open and profs[open] and profs[open].all) and open or picks[1]
    end
  end
  local questsTab = selected == ns.View.QUESTS_TAB
  if questsTab then
    picks = ns.Quests.Professions()
    local ok = false
    for _, n in ipairs(picks) do if n == questsProf then ok = true end end
    if not ok then
      local open = ns.Recipes.CurrentName()
      questsProf = picks[1]
      for _, n in ipairs(picks) do if n == open then questsProf = open end end
    end
  end
  layoutPicker(picks, recipesTab or questsTab, questsTab and questsProf or recipesProf)
  searchBox:SetShown(recipesTab)
  unlearnedCheck:SetShown(recipesTab)
  unlearnedCheck:SetChecked(ns.db.ui.recipesUnlearned and true or false)
  local filterNames = money and ns.View.MoneyProfessions(profs) or {}
  layoutMoneyFilter(filterNames)
  box:ClearAllPoints()
  box:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, (#filterNames > 0 or recipesTab) and -132 or -108)
  box:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -30, 12)

  local lines
  if questsTab then
    lines = questsProf and ns.Quests.Lines(questsProf)
      or { { kind = 'message', text = 'None of your professions has quests in the data.' } }
  elseif recipesTab then
    lines = ns.View.CatalogLines(profs[recipesProf], recipesProf, ns.RecipeSourceText, recipesQuery, ns.RecipeEffectText,
      ns.db.ui.recipesUnlearned)
  elseif money then lines = ns.View.MoneyLines(profs, ns.ctx, ns.db.ui.moneySort, ns.db.ui.moneyHide)
  else lines = ns.View.ProfessionLines(profs[selected], selected, ns.ctx, ns.db.ui.levelSort) end
  box:SetDataProvider(CreateDataProvider(lines), ScrollBoxConstants.RetainScrollPosition)
  ns.RefreshStatus()
end

-- ---------- building the frame ----------
local function savePoint()
  local p, _, rp, x, y = frame:GetPoint()
  ns.db.ui.point = { p, rp, x, y }
end

local function place()
  frame:ClearAllPoints()
  local pt = ns.db.ui.point
  if pt then
    frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
  elseif ProfessionsFrame and ProfessionsFrame:IsShown() then
    frame:SetPoint('TOPLEFT', ProfessionsFrame, 'TOPRIGHT', 40, 0)
  elseif TradeSkillFrame and TradeSkillFrame:IsShown() then
    frame:SetPoint('TOPLEFT', TradeSkillFrame, 'TOPRIGHT', 40, 0)
  else
    frame:SetPoint('CENTER')
  end
end

local function radio(label, x, mode, key)
  key = key or 'moneySort'
  local b = CreateFrame('CheckButton', nil, frame, 'UIRadioButtonTemplate')
  b:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, -60)
  local t = b:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  t:SetPoint('LEFT', b, 'RIGHT', 2, 0)
  t:SetText(label)
  b:SetScript('OnClick', function() ns.db.ui[key] = mode; ns.Refresh() end)
  return b
end

local function build()
  frame = CreateFrame('Frame', 'BoG_TradeHelperFrame', UIParent, 'BasicFrameTemplateWithInset')
  frame:SetSize(ns.View.WindowSize(ns.db.ui.size))
  frame:SetFrameStrata('HIGH')
  frame:SetMovable(true)
  frame:SetResizable(true)
  local V = ns.View
  if frame.SetResizeBounds then
    frame:SetResizeBounds(V.WINDOW_MIN_W, V.WINDOW_MIN_H, V.WINDOW_MAX_W, V.WINDOW_MAX_H)
  else
    frame:SetMinResize(V.WINDOW_MIN_W, V.WINDOW_MIN_H)
    frame:SetMaxResize(V.WINDOW_MAX_W, V.WINDOW_MAX_H)
  end
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag('LeftButton')
  frame:SetScript('OnDragStart', frame.StartMoving)
  frame:SetScript('OnDragStop', function(self) self:StopMovingOrSizing(); savePoint() end)
  tinsert(UISpecialFrames, 'BoG_TradeHelperFrame')

  local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  title:SetPoint('TOP', frame, 'TOP', 0, -5)
  title:SetText('Brotherhood of Gold - Profession Helper  |cff9d9d9dv' .. (ns.VERSION or '?') .. '|r')

  scanBtn = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
  scanBtn:SetSize(150, 22)
  scanBtn:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -58)
  scanBtn:SetScript('OnClick', function() ns.Auction.Start() end)

  -- Same as /bog export: opens the data report, selected and ready for Ctrl+C.
  local exportBtn = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
  exportBtn:SetSize(130, 22)
  exportBtn:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -12, -58)
  exportBtn:SetText('Send data report')
  exportBtn:SetScript('OnClick', function() ns.ExportReport() end)
  exportBtn:SetScript('OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_BOTTOMLEFT')
    GameTooltip:SetText('Send data report')
    GameTooltip:AddLine('Opens your recipe data report, already selected.', 1, 1, 1, true)
    GameTooltip:AddLine('Press Ctrl+C, then paste it at ' .. ns.Export.URL .. ' and click Send. No account needed.', 1, 1, 1, true)
    GameTooltip:AddLine('Same as /bog export.', 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  exportBtn:SetScript('OnLeave', function() GameTooltip:Hide() end)

  statusText = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  statusText:SetPoint('LEFT', scanBtn, 'RIGHT', 10, 0)

  sortLabel = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
  sortLabel:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -88)
  sortLabel:SetText('Sort by:')
  sortAH = radio('AH profit', 70, 'ah')
  sortVendor = radio('Vendor profit', 170, 'vendor')
  sortAH:ClearAllPoints(); sortAH:SetPoint('LEFT', sortLabel, 'RIGHT', 8, 0)
  sortVendor:ClearAllPoints(); sortVendor:SetPoint('LEFT', sortAH, 'RIGHT', 80, 0)
  sortCheap = radio('Cheapest', 70, 'cheapest', 'levelSort')
  sortLevelAH = radio('AH profit', 170, 'ah', 'levelSort')
  sortLevelVendor = radio('Vendor profit', 270, 'vendor', 'levelSort')
  sortCheap:ClearAllPoints(); sortCheap:SetPoint('LEFT', sortLabel, 'RIGHT', 8, 0)
  sortLevelAH:ClearAllPoints(); sortLevelAH:SetPoint('LEFT', sortCheap, 'RIGHT', 80, 0)
  sortLevelVendor:ClearAllPoints(); sortLevelVendor:SetPoint('LEFT', sortLevelAH, 'RIGHT', 80, 0)

  -- Recipes tab search: filters by recipe name, materials, where it comes from, or what it does (stats, well fed...).
  local ok, sb = pcall(CreateFrame, 'EditBox', nil, frame, 'SearchBoxTemplate')
  if not ok or not sb then sb = CreateFrame('EditBox', nil, frame, 'InputBoxTemplate') end
  searchBox = sb
  searchBox:SetSize(170, 20)
  searchBox:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -34, -84)
  searchBox:SetAutoFocus(false)
  searchBox:HookScript('OnTextChanged', function(self)
    local text = self:GetText() or ''
    if text ~= (recipesQuery or '') then recipesQuery = text; ns.Refresh() end
  end)
  searchBox:SetScript('OnEscapePressed', function(self) self:SetText(''); self:ClearFocus() end)
  if searchBox.Instructions then searchBox.Instructions:SetText('Name, material, stat...') end -- grey hint while empty
  searchBox:HookScript('OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
    GameTooltip:SetText('Search recipes by')
    GameTooltip:AddLine('- recipe or item name: "wool cloak"', 1, 1, 1)
    GameTooltip:AddLine('- material it uses: "wool cloth", "silk"', 1, 1, 1)
    GameTooltip:AddLine('- stat or effect: "stamina", "armor", "well fed spirit", "restores health"', 1, 1, 1)
    GameTooltip:AddLine('- enchant: "agility boots"', 1, 1, 1)
    GameTooltip:AddLine('- where to get it: "vendor", "trainer", a zone or npc name', 1, 1, 1)
    GameTooltip:AddLine('Every word must match, in any order. Esc clears it.', 0.6, 0.8, 0.6, true)
    GameTooltip:Show()
  end)
  searchBox:HookScript('OnLeave', function() GameTooltip:Hide() end)
  searchBox:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
  searchBox:Hide()

  -- Recipes tab filter: only the recipes you don't know yet (remembered).
  unlearnedCheck = CreateFrame('CheckButton', nil, frame, 'UICheckButtonTemplate')
  unlearnedCheck:SetSize(22, 22)
  unlearnedCheck:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -106)
  unlearnedCheck.label = unlearnedCheck:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  unlearnedCheck.label:SetPoint('LEFT', unlearnedCheck, 'RIGHT', 0, 1)
  unlearnedCheck.label:SetText('Not learned only')
  unlearnedCheck:SetScript('OnClick', function(self)
    ns.db.ui.recipesUnlearned = self:GetChecked() and true or nil
    ns.Refresh()
  end)
  unlearnedCheck:Hide()

  box = CreateFrame('Frame', nil, frame, 'WowScrollBoxList')
  box:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -108)
  box:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -30, 12)
  local bar = CreateFrame('EventFrame', nil, frame, 'MinimalScrollBar')
  bar:SetPoint('TOPLEFT', box, 'TOPRIGHT', 6, 0)
  bar:SetPoint('BOTTOMLEFT', box, 'BOTTOMRIGHT', 6, 0)
  local view = CreateScrollBoxListLinearView()
  view:SetElementExtentCalculator(extent)
  view:SetElementInitializer('Frame', initRow)
  ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)

  -- Drag the bottom-right corner to resize; the size is saved like the position.
  local grip = CreateFrame('Button', nil, frame)
  grip:SetSize(16, 16)
  grip:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -3, 3)
  grip:SetFrameLevel(frame:GetFrameLevel() + 10)
  grip:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
  grip:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
  grip:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')
  grip:SetScript('OnMouseDown', function(_, button)
    if button == 'LeftButton' then frame:StartSizing('BOTTOMRIGHT') end
  end)
  grip:SetScript('OnMouseUp', function()
    frame:StopMovingOrSizing()
    local w, h = frame:GetSize()
    ns.db.ui.size = { math.floor(w + 0.5), math.floor(h + 0.5) }
    savePoint()
  end)
  grip:SetScript('OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
    GameTooltip:SetText('Drag to resize')
    GameTooltip:Show()
  end)
  grip:SetScript('OnLeave', function() GameTooltip:Hide() end)

  frame:SetScript('OnShow', function()
    ticker = C_Timer.NewTicker(1, ns.RefreshStatus)
    ns.Refresh()
  end)
  frame:SetScript('OnHide', function() if ticker then ticker:Cancel(); ticker = nil end end)
  frame:Hide()
end

function Window.Open(tabName)
  if not frame then build() end
  if tabName then selected = tabName end
  if not frame:IsShown() then place() end
  frame:Show()
  ns.Refresh()
end

function Window.Selected() return selected end

function Window.Toggle()
  if frame and frame:IsShown() then frame:Hide() else Window.Open(ns.Recipes.CurrentName()) end
end
