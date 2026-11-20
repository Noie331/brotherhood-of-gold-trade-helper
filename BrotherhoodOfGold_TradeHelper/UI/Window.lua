-- The addon window: profession tabs + Money Maker, Scan AH row, and the recipe list.
local _, ns = ...
local Window = {}
ns.Window = Window

local W, H = 640, 600
local DOT = { optimal = 'ff8040', medium = 'ffff00', easy = '40c040', trivial = '808080' }
local GREEN, RED, GREY = '40c040', 'ff4040', '9a8f7a'
local GAP = 10 -- space above each recipe
local SUB = 14 -- height of a recipe's second (sell prices) line
local TICK = ' |TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t'

local frame, selected, tabButtons, scanBtn, statusText, sortAH, sortVendor, sortEach, sortTotal, sortLabel, box
local sortCheap, sortLevelAH, sortLevelVendor
local pickButtons, recipesProf -- Recipes tab: profession picker and the picked profession
local searchBox, recipesQuery -- Recipes tab: search box and its text
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
    row.sub2 = row:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall') -- under the middle column
    row.sub2:SetJustifyH('LEFT')
    row.sub2:SetWidth(220)
    row.sub2:SetWordWrap(false)
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
      local where = self.recipeLine and ns.Locate.Lines(self.recipeLine) or {}
      if #where > 0 then
        GameTooltip:AddLine(' ')
        for _, l in ipairs(where) do GameTooltip:AddLine(l, 0.9, 0.8, 0.5) end
        GameTooltip:AddLine('Click: map pin on the nearest one', 0.5, 0.8, 0.5)
      end
      GameTooltip:Show()
    end)
    row:SetScript('OnLeave', function() GameTooltip:Hide() end)
    row:SetScript('OnMouseUp', function(self, button)
      if button == 'LeftButton' and self.recipeLine then ns.Locate.Show(self.recipeLine) end
    end)
  end
  row.dot:Hide()
  row.icon:Hide()
  row.left:SetFontObject('GameFontHighlightSmall')
  row.mid:SetText(''); row.right:SetText(''); row.sub:SetText(''); row.sub2:SetText('')
  row.mid:SetWidth(220); row.right:SetWidth(176)

  -- Recipe rows: GAP px of space on top, the main line, then a SUB px second line for sell prices.
  -- Offsets are from the row's vertical centre.
  local y = 0
  row.sub:ClearAllPoints(); row.sub:SetJustifyH('LEFT'); row.sub:SetJustifyV('MIDDLE')
  row.sub:SetWordWrap(false); row.sub:SetMaxLines(1)
  if line.kind == 'recipe' then
    y = (SUB - GAP) / 2
    row.sub:SetPoint('LEFT', 36, -(GAP + 20) / 2)
  elseif line.kind == 'catalog' then -- GAP on top, the name line, then up to two lines of where to get it
    if line.source then
      y = (2 * SUB - GAP) / 2
      row.sub:SetPoint('TOPLEFT', row, 'LEFT', 36, y - 10)
      row.sub:SetPoint('TOPRIGHT', row, 'RIGHT', -4, y - 10)
      row.sub:SetJustifyV('TOP')
      row.sub:SetWordWrap(true); row.sub:SetMaxLines(2)
    else
      y = -GAP / 2
    end
  elseif line.kind == 'flip' then -- second line sits under the profit, right-aligned
    y = SUB / 2
    row.sub:SetPoint('RIGHT', -4, -10)
    row.sub:SetJustifyH('RIGHT')
    row.sub2:ClearAllPoints(); row.sub2:SetPoint('LEFT', 192, -10)
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

  if line.kind == 'flip' then
    withIcon(ns.Items.Icon(line.itemID), 16, 16)
    row.left:SetText(ns.Items.Name(line.itemID) or '...')
    row.mid:SetText(col(GREY, 'AH ') .. M(line.ah) .. col(GREY, '  |  V ') .. M(line.vendor))
    -- Profit per item (buy at the lowest AH price, sell to a vendor); below it, how many at that price and the total.
    row.right:SetText(col(GREEN, '+' .. M(line.profit) .. ' each'))
    row.sub:SetText(col(GREY, 'Available ') .. line.qty .. col(GREY, '  ·  Total ') .. col(GREEN, '+' .. M(line.total)))
    row.sub2:SetText(col(GREY, 'Total cost ') .. M(line.cost))
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
  if line.kind == 'flip' then return 20 + SUB end
  if line.kind == 'catalog' then return GAP + 20 + (line.source and 2 * SUB or 0) end
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

-- Recipes tab: one button per profession with a saved full list.
local function layoutPicker(names, show)
  pickButtons = pickButtons or {}
  local x = 12
  for i, name in ipairs(show and names or {}) do
    local b = pickButtons[i]
    if not b then
      b = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
      b:SetHeight(20)
      b:SetScript('OnClick', function(self) recipesProf = self.profName; ns.Refresh() end)
      pickButtons[i] = b
    end
    b.profName = name
    b:SetText(name)
    b:SetWidth(math.max(70, b:GetFontString():GetStringWidth() + 20))
    b:ClearAllPoints()
    b:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, -84)
    x = x + b:GetWidth() + 4
    if name == recipesProf then b:LockHighlight() else b:UnlockHighlight() end
    b:Show()
  end
  for i = (show and #names or 0) + 1, #pickButtons do pickButtons[i]:Hide() end
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

  local money, flip = selected == ns.View.MONEY_TAB, selected == ns.View.FLIP_TAB
  sortAH:SetShown(money); sortVendor:SetShown(money)
  sortAH:SetChecked(ns.db.ui.moneySort ~= 'vendor')
  sortVendor:SetChecked(ns.db.ui.moneySort == 'vendor')
  local prof = not money and not flip and selected ~= ns.View.RECIPES_TAB
  sortLabel:SetShown(money or flip or prof)
  sortCheap:SetShown(prof); sortLevelAH:SetShown(prof); sortLevelVendor:SetShown(prof)
  local ls = ns.db.ui.levelSort
  sortCheap:SetChecked(ls ~= 'ah' and ls ~= 'vendor')
  sortLevelAH:SetChecked(ls == 'ah'); sortLevelVendor:SetChecked(ls == 'vendor')
  sortEach:SetShown(flip); sortTotal:SetShown(flip)
  sortEach:SetChecked(ns.db.ui.flipSort ~= 'total')
  sortTotal:SetChecked(ns.db.ui.flipSort == 'total')

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
  layoutPicker(picks, recipesTab)
  searchBox:SetShown(recipesTab)

  local lines
  if recipesTab then
    lines = ns.View.CatalogLines(profs[recipesProf], recipesProf, ns.RecipeSourceText, recipesQuery)
  elseif selected == ns.View.FLIP_TAB then
    local data = ns.Auction.RealmData()
    local loading, loaded, total = ns.Auction.PreloadPrices()
    if loading then
      lines = { { kind = 'message', text = 'Loading item prices... ' .. loaded .. ' / ' .. total } }
    else
      -- After a reload, items still loading join when the quiet background load finishes (one refresh).
      lines = ns.View.FlipLines(data.prices, data.qty, function(id) return ns.Items.SellPrice(id, true) end,
        ns.db.ui.flipSort)
    end
  elseif money then lines = ns.View.MoneyLines(profs, ns.ctx, ns.db.ui.moneySort)
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
  frame:SetSize(W, H)
  frame:SetFrameStrata('HIGH')
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag('LeftButton')
  frame:SetScript('OnDragStart', frame.StartMoving)
  frame:SetScript('OnDragStop', function(self) self:StopMovingOrSizing(); savePoint() end)
  tinsert(UISpecialFrames, 'BoG_TradeHelperFrame')

  local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  title:SetPoint('TOP', frame, 'TOP', 0, -5)
  title:SetText('Brotherhood of Gold - Trade Helper')

  scanBtn = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
  scanBtn:SetSize(150, 22)
  scanBtn:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -58)
  scanBtn:SetScript('OnClick', function() ns.Auction.Start() end)

  statusText = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  statusText:SetPoint('LEFT', scanBtn, 'RIGHT', 10, 0)

  sortLabel = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
  sortLabel:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -88)
  sortLabel:SetText('Sort by:')
  sortAH = radio('AH profit', 70, 'ah')
  sortVendor = radio('Vendor profit', 170, 'vendor')
  sortAH:ClearAllPoints(); sortAH:SetPoint('LEFT', sortLabel, 'RIGHT', 8, 0)
  sortVendor:ClearAllPoints(); sortVendor:SetPoint('LEFT', sortAH, 'RIGHT', 80, 0)
  sortEach = radio('Profit each', 70, 'each', 'flipSort')
  sortTotal = radio('Total profit', 170, 'total', 'flipSort')
  sortEach:ClearAllPoints(); sortEach:SetPoint('LEFT', sortLabel, 'RIGHT', 8, 0)
  sortTotal:ClearAllPoints(); sortTotal:SetPoint('LEFT', sortEach, 'RIGHT', 90, 0)
  sortCheap = radio('Cheapest', 70, 'cheapest', 'levelSort')
  sortLevelAH = radio('AH profit', 170, 'ah', 'levelSort')
  sortLevelVendor = radio('Vendor profit', 270, 'vendor', 'levelSort')
  sortCheap:ClearAllPoints(); sortCheap:SetPoint('LEFT', sortLabel, 'RIGHT', 8, 0)
  sortLevelAH:ClearAllPoints(); sortLevelAH:SetPoint('LEFT', sortCheap, 'RIGHT', 80, 0)
  sortLevelVendor:ClearAllPoints(); sortLevelVendor:SetPoint('LEFT', sortLevelAH, 'RIGHT', 80, 0)

  -- Recipes tab search: filters by recipe name or where it comes from, as you type.
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
  searchBox:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
  searchBox:Hide()

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
