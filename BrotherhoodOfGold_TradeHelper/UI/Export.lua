-- /bog export: a window with the data report selected, ready for Ctrl+C.
local _, ns = ...
local E = {}
ns.Export = E

-- Where players paste their report (GitHub issue form "Recipe data report").
E.URL = 'github.com/neilclifton84-cell/brotherhood-of-gold-trade-helper/issues/new?template=data-report.yml'

local frame, edit, last

local function build()
  frame = CreateFrame('Frame', 'BoG_ExportFrame', UIParent, 'BasicFrameTemplateWithInset')
  frame:SetSize(520, 300)
  frame:SetPoint('CENTER')
  frame:SetFrameStrata('DIALOG')
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag('LeftButton')
  frame:SetScript('OnDragStart', frame.StartMoving)
  frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
  tinsert(UISpecialFrames, 'BoG_ExportFrame')
  local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  title:SetPoint('TOP', 0, -5)
  title:SetText('Trade Helper - recipe data report')
  local help = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
  help:SetPoint('TOPLEFT', 14, -32)
  help:SetPoint('TOPRIGHT', -14, -32)
  help:SetJustifyH('LEFT')
  help:SetText('Press Ctrl+C to copy, then paste it into a new report at\n' .. E.URL)
  local scroll = CreateFrame('ScrollFrame', nil, frame, 'UIPanelScrollFrameTemplate')
  scroll:SetPoint('TOPLEFT', 14, -66)
  scroll:SetPoint('BOTTOMRIGHT', -32, 14)
  edit = CreateFrame('EditBox', nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(460)
  edit:SetScript('OnEscapePressed', function() frame:Hide() end)
  edit:SetScript('OnTextChanged', function(self, user) if user then self:SetText(last or ''); self:HighlightText() end end)
  scroll:SetScrollChild(edit)
end

function E.Show(text)
  last = text
  if not frame then build() end
  edit:SetText(text)
  frame:Show()
  edit:SetFocus()
  edit:HighlightText()
end

function E.LastText() return last end
