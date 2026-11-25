-- Start-up: saved data, game constants, price lookups and the /bog command.
local ADDON, ns = ...

-- The .toc's "## Version:" (one place to bump it).
local metadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = metadata and metadata(ADDON, 'Version') or '?'

local function useEnums()
  if not Enum then return end
  local d = Enum.TradeskillRelativeDifficulty
  if d and d.Optimal and d.Medium and d.Easy and d.Trivial then
    ns.RecipeLogic.DIFFICULTY = { [d.Optimal] = 'optimal', [d.Medium] = 'medium', [d.Easy] = 'easy', [d.Trivial] = 'trivial' }
  end
  local r = Enum.CraftingReagentType
  if r and r.Basic then ns.RecipeLogic.BASIC = r.Basic end
end

ns.ctx = {
  ahPrice = function(id)
    local realm = ns.db and ns.db.ah[GetRealmName()]
    return realm and realm.prices and realm.prices[id] or nil
  end,
  vendorPrice = function(id) return ns.DB.VendorPrice(ns.db, id) end,
  sellPrice = function(id) return ns.Items.SellPrice(id) end,
  isBoP = function(id) return ns.Items.IsBoP(id) end,
}

local function yes(v) return v and '|cff40c040yes|r' or '|cffff4040no|r' end

local function probe()
  local _, build, _, interface = GetBuildInfo()
  print('|cffe8c66aProfession Helper v' .. ns.VERSION .. ' probe|r')
  print('  build ' .. tostring(build) .. ', interface ' .. tostring(interface) .. ' (toc says 16001)')
  print('  ProfessionsFrame: ' .. yes(ProfessionsFrame) .. '  TradeSkillFrame: ' .. yes(TradeSkillFrame)
    .. ' (open a profession first)')
  local T = C_TradeSkillUI
  print('  C_TradeSkillUI.GetAllRecipeIDs: ' .. yes(T and T.GetAllRecipeIDs)
    .. '  GetRecipeSchematic: ' .. yes(T and T.GetRecipeSchematic))
  print('  C_AuctionHouse.ReplicateItems: ' .. yes(C_AuctionHouse and C_AuctionHouse.ReplicateItems)
    .. '  C_MerchantFrame: ' .. yes(C_MerchantFrame))
  print('  professions: ' .. table.concat(ns.Recipes.TrainedNames(), ', '))
  print('  recipe data file: build ' .. tostring(ns.RecipeData and ns.RecipeData.build)
    .. ' (game ' .. tostring(build) .. ')')
  local seen = 0
  for _ in pairs(ns.db.recipeItems or {}) do seen = seen + 1 end
  print('  recipe items seen at vendors or in loot: ' .. seen)
  print('  vendor location test: ' .. ns.Locate.ProbeText() .. ' (expect Winterspring about 61, 37)')
  if ns.Locate.RouteProbe then print('  walking routes: ' .. ns.Locate.RouteProbe()) end
  -- Recipes tab check: does the client list unlearned recipes, and give their grey level?
  if T and T.GetAllRecipeIDs then
    local learned, unlearned, withGrey, inFile = 0, 0, 0, 0
    for _, id in ipairs(T.GetAllRecipeIDs() or {}) do
      local info = T.GetRecipeInfo(id)
      if info then
        if info.learned then learned = learned + 1 else unlearned = unlearned + 1 end
        if (tonumber(info.maxTrivialLevel) or 0) > 0 then withGrey = withGrey + 1 end
        if ns.RecipeData and ns.RecipeData.recipes[id] then inFile = inFile + 1 end
      end
    end
    print('  open profession: learned ' .. learned .. ', unlearned ' .. unlearned .. ', with grey level ' .. withGrey
      .. ', in the recipe data file ' .. inFile)
  end
end

local function say(msg) print('|cffe8c66aProfession Helper|r ' .. msg) end

-- /bog export: the data report to copy into a report for the shared data file.
local function export()
  local rep = ns.db.report
  if not rep or ns.Report.IsEmpty(rep, ns.Report.droppers) then
    say('Nothing new to report yet: visit vendors and trainers, and loot mobs.'
      .. (ns.db.record == false and ' Recording is off: /bog record on' or ''))
    return
  end
  ns.Export.Show(ns.Report.Export(rep, time(), ns.VERSION, ns.Report.droppers))
end
ns.ExportReport = export -- the window's Send data report button

local f = CreateFrame('Frame')
f:RegisterEvent('ADDON_LOADED')
f:SetScript('OnEvent', function(self, _, name)
  if name ~= ADDON then return end
  self:UnregisterEvent('ADDON_LOADED')
  ns.db, ns.chardb = ns.DB.Init(BoG_DB, BoG_CharDB)
  BoG_DB, BoG_CharDB = ns.db, ns.chardb
  ns.db.ui.sideTabY = nil -- old top-based spot; the tab now defaults to the bottom
  ns.db.sources = nil -- old name-based recipe sources; replaced by recipeItems (Game/Sightings.lua)
  useEnums()
end)

SLASH_BROTHERHOODOFGOLD1 = '/bog'
SlashCmdList.BROTHERHOODOFGOLD = function(msg)
  msg = strtrim(msg or ''):lower()
  if msg == 'probe' then probe()
  elseif msg == 'export' then export()
  elseif msg == 'record on' or msg == 'record off' then
    ns.db.record = msg == 'record on'
    say('recipe data recording ' .. (ns.db.record and 'on' or 'off') .. '.')
  else ns.Window.Toggle() end
end
