-- Records recipe items seen at vendors and in loot, and builds the Recipes tab's source line:
-- the recipe data file (how it's learned) first, then where its recipe item was seen.
local _, ns = ...

local recipeItem = {} -- itemID -> true for every item in the recipe data file

function ns.Sightings.Reindex()
  recipeItem = {}
  for _, entry in pairs(ns.RecipeData and ns.RecipeData.recipes or {}) do
    for _, id in ipairs(entry.items or {}) do recipeItem[id] = true end
  end
end
ns.Sightings.Reindex()

local function isRecipeItem(id) return recipeItem[id] == true end

local function store()
  if not ns.db then return nil end
  ns.db.recipeItems = ns.db.recipeItems or {}
  return ns.db.recipeItems
end

local function merchantItem(i)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(i)
    if info then return info.price, info.numAvailable end
    return nil
  end
  local _, _, price, _, numAvailable = GetMerchantItemInfo(i)
  return price, numAvailable
end

local function vendorVisit()
  local s = store()
  if not s then return end
  local items = {}
  for i = 1, GetMerchantNumItems() do
    local id = GetMerchantItemID(i)
    local price, available = merchantItem(i)
    if id then items[#items + 1] = { id = id, price = price, limited = available ~= nil and available ~= -1 } end
  end
  local here = ns.Locate.Here and ns.Locate.Here()
  if ns.Sightings.RecordVendor(s, items, UnitName('npc'), isRecipeItem, here) > 0 and ns.Refresh then ns.Refresh() end
end

-- Name of what a loot slot came from: the target, mouseover or npc unit with that GUID; nil when none matches.
local function sourceName(guid)
  if not guid then return nil end
  for _, unit in ipairs({ 'target', 'mouseover', 'npc' }) do
    if UnitGUID(unit) == guid then return UnitName(unit) end
  end
  return nil
end

local function lootOpened()
  local s = store()
  if not s or not GetNumLootItems then return end
  local any = false
  local here = ns.Locate.Here and ns.Locate.Here()
  for slot = 1, GetNumLootItems() do
    local link = GetLootSlotLink(slot)
    local id = link and tonumber(link:match('item:(%d+)'))
    if id and isRecipeItem(id) then
      local guid = GetLootSourceInfo and GetLootSourceInfo(slot)
      any = ns.Sightings.RecordLoot(s, id, sourceName(guid), isRecipeItem, here) or any
    end
  end
  if any and ns.Refresh then ns.Refresh() end
end

function ns.RecipeSourceText(recipe)
  local entry = ns.RecipeData and ns.RecipeData.recipes[recipe.recipeID]
  if not entry then return nil end
  local seen = nil
  if entry.items and ns.db and ns.db.recipeItems then
    seen = ns.Sightings.Text(ns.db.recipeItems, entry.items, ns.Format.MoneyIcons,
      ns.RecipeSource.VendorNames(entry, ns.RecipeData.npcs))
  end
  local faction = ({ Alliance = 'A', Horde = 'H' })[UnitFactionGroup('player') or '']
  return ns.RecipeSource.Text(entry, seen, faction, ns.Format.MoneyIcons, ns.RecipeData.npcs, ns.RecipeData.rewardQuests)
end

local f = CreateFrame('Frame')
f:RegisterEvent('MERCHANT_SHOW')
f:RegisterEvent('LOOT_OPENED')
f:SetScript('OnEvent', function(_, event)
  if event == 'MERCHANT_SHOW' then ns.Throttle('recipeVendor', 0.5, vendorVisit) else lootOpened() end
end)
