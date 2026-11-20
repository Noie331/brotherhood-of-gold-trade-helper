-- Saves the open profession's learned recipes, and lists the character's trained professions.
local _, ns = ...
local Recipes = {}
ns.Recipes = Recipes

local T = C_TradeSkillUI

local function othersList()
  if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return true end
  if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return true end
  if T.IsNPCCrafting and T.IsNPCCrafting() then return true end
  return false
end

-- Name of the profession whose window is open, or nil.
function Recipes.CurrentName()
  if not T or not T.GetBaseProfessionInfo then return nil end
  local base = T.GetBaseProfessionInfo()
  if base and base.professionName and base.professionName ~= '' then return base.professionName end
  return nil
end

function Recipes.SaveOpen()
  if not ns.chardb or not T or not T.GetAllRecipeIDs or othersList() then return end
  local name = Recipes.CurrentName()
  if not name then return end
  local base = T.GetBaseProfessionInfo()
  local recipes, all, count = {}, {}, 0
  for _, id in ipairs(T.GetAllRecipeIDs() or {}) do
    local info = T.GetRecipeInfo(id)
    if info and info.learned then
      local r = ns.RecipeLogic.Normalize(info, T.GetRecipeSchematic(id, false))
      if r then recipes[id] = r; count = count + 1 end
    end
    all[id] = ns.RecipeLogic.CatalogEntry(info) -- Recipes tab: every recipe, learned or not
  end
  if count == 0 then return end -- list not loaded yet: keep what was saved
  ns.chardb.professions[name] = { name = name, rank = base.skillLevel, maxRank = base.maxSkillLevel,
    savedAt = time(), recipes = recipes, all = all }
  if ns.Refresh then ns.Refresh() end
end

-- Trained profession names: primaries first, then the secondary ones, in GetProfessions order.
function Recipes.TrainedNames()
  local out = {}
  local idx = { GetProfessions() }
  for i = 1, 8 do
    local slot = idx[i]
    if slot then
      local name, _, _, _, _, _, skillLine = GetProfessionInfo(slot)
      if name and not ns.View.NO_RECIPE_SKILL_LINES[skillLine] then out[#out + 1] = name end
    end
  end
  return out
end

local f = CreateFrame('Frame')
for _, e in ipairs({ 'TRADE_SKILL_SHOW', 'TRADE_SKILL_LIST_UPDATE', 'TRADE_SKILL_DATA_SOURCE_CHANGED' }) do
  pcall(f.RegisterEvent, f, e)
end
f:SetScript('OnEvent', function()
  ns.Throttle('recipes', 1, Recipes.SaveOpen)
end)
