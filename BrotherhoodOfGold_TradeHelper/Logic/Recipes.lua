-- Turns C_TradeSkillUI recipe info + schematic tables into the saved recipe shape. Pure Lua.
local _, ns = ...
local RecipeLogic = {}
ns.RecipeLogic = RecipeLogic

-- Defaults match Enum.TradeskillRelativeDifficulty and Enum.CraftingReagentType.Basic;
-- Core.lua overwrites them from Enum in game when those exist.
RecipeLogic.DIFFICULTY = { [0] = 'optimal', [1] = 'medium', [2] = 'easy', [3] = 'trivial' }
RecipeLogic.BASIC = 1

-- One line of the Recipes tab: every recipe of the profession, learned or not.
-- grey = the skill level where it stops giving points (the game's maxTrivialLevel; nil when unknown).
function RecipeLogic.CatalogEntry(info)
  if not info or not info.name then return nil end
  local grey = tonumber(info.maxTrivialLevel)
  return {
    recipeID = info.recipeID,
    name = info.name,
    icon = info.icon,
    learned = info.learned == true,
    grey = (grey and grey > 0) and grey or nil,
    difficulty = RecipeLogic.DIFFICULTY[info.relativeDifficulty] or 'trivial',
  }
end

function RecipeLogic.Normalize(info, schematic)
  if not info or not info.learned then return nil end
  schematic = schematic or {}
  local reagents = {}
  for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
    local first = slot.reagents and slot.reagents[1]
    if slot.reagentType == RecipeLogic.BASIC and first and first.itemID then
      reagents[#reagents + 1] = { itemID = first.itemID, qty = slot.quantityRequired or 1 }
    end
  end
  local qmin = schematic.quantityMin or 1
  local qmax = schematic.quantityMax or qmin
  return {
    recipeID = info.recipeID,
    name = info.name,
    icon = info.icon,
    difficulty = RecipeLogic.DIFFICULTY[info.relativeDifficulty] or 'trivial',
    outputItemID = schematic.outputItemID,
    outputQty = (qmin + qmax) / 2,
    reagents = reagents,
  }
end
