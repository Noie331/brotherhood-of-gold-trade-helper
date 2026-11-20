-- Data report: records vendors, drops and trainers the recipe data file doesn't know yet (Logic/Report.lua).
-- On unless /bog record off. /bog export shows it to copy into a data report.
local _, ns = ...
local R = ns.Report

local vendorNews, dropNews
function R.Reindex()
  local idx = R.Index(ns.RecipeData and ns.RecipeData.recipes)
  vendorNews, dropNews = R.Keeper(idx, 'vendors'), R.Keeper(idx, 'drops')
end
R.Reindex()

local FACTION = { Alliance = 'A', Horde = 'H' }

-- The report to add to, or nil when recording is off / saved data isn't loaded yet.
function R.Current()
  local db = ns.db
  if not db or db.record == false then return nil end
  if not db.report then
    db.report = R.New(string.format('%06x%06x', math.random(0, 0xffffff), math.random(0, 0xffffff)), nil)
  end
  local version, build = GetBuildInfo()
  if version then db.report.build = version .. '.' .. tostring(build) end
  return db.report
end

local function npcFrom(unit)
  local id = R.NpcID(UnitGUID(unit))
  if not id then return nil end
  return { id = id, name = UnitName(unit), faction = FACTION[UnitFactionGroup(unit) or ''] or '' }
end

-- The unit (target, mouseover, npc) with this GUID, as an npc; else just the id.
local function npcByGUID(guid)
  local id = R.NpcID(guid)
  if not id then return nil end
  for _, unit in ipairs({ 'target', 'mouseover', 'npc' }) do
    if UnitGUID(unit) == guid then return npcFrom(unit) end
  end
  return { id = id }
end

local function otherCost(i)
  if not GetMerchantItemCostInfo then return nil end
  local parts = {}
  for j = 1, GetMerchantItemCostInfo(i) or 0 do
    local _, value, link, name = GetMerchantItemCostItem(i, j)
    name = name or (link and link:match('%[(.-)%]'))
    if value and name then parts[#parts + 1] = value .. ' ' .. name end
  end
  return #parts > 0 and table.concat(parts, ' + ') or nil
end

local function merchant()
  local rep = R.Current()
  if not rep then return end
  local items = {}
  for i = 1, GetMerchantNumItems() do
    local id = GetMerchantItemID(i)
    if id then
      local price, available
      if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(i)
        if info then price, available = info.price, info.numAvailable end
      else
        local _, _, p, _, a = GetMerchantItemInfo(i)
        price, available = p, a
      end
      items[#items + 1] = { id = id, price = price, limited = available ~= nil and available ~= -1, cost = otherCost(i) }
    end
  end
  R.Vendor(rep, npcFrom('npc'), ns.Locate.Here and ns.Locate.Here(), items, vendorNews)
end

local corpses = {} -- GUIDs looted this session: each corpse counts once

local function loot()
  local rep = R.Current()
  if not rep or not GetNumLootItems or not GetLootSourceInfo then return end
  local onCorpse, order = {}, {}
  for slot = 1, GetNumLootItems() do
    local link = GetLootSlotLink(slot)
    local item = link and tonumber(link:match('item:(%d+)'))
    local src = { GetLootSourceInfo(slot) }
    for k = 1, #src, 2 do
      local guid = src[k]
      if guid and not onCorpse[guid] then onCorpse[guid] = {}; order[#order + 1] = guid end
      if guid and item then table.insert(onCorpse[guid], item) end
    end
  end
  local here = ns.Locate.Here and ns.Locate.Here()
  for _, guid in ipairs(order) do
    if not corpses[guid] then
      corpses[guid] = true
      R.Loot(rep, npcByGUID(guid), here, onCorpse[guid], dropNews)
    end
  end
end

local function trainer()
  local rep = R.Current()
  if not rep or not GetNumTrainerServices then return end
  local services = {}
  for i = 1, GetNumTrainerServices() do
    local name, _, category = GetTrainerServiceInfo(i)
    if name and category ~= 'header' then
      local prof, skill = GetTrainerServiceSkillReq(i)
      services[#services + 1] = { name = name, prof = prof, skill = skill }
    end
  end
  R.Trainer(rep, npcFrom('npc'), ns.Locate.Here and ns.Locate.Here(), services)
end

local f = CreateFrame('Frame')
f:RegisterEvent('MERCHANT_SHOW')
f:RegisterEvent('LOOT_OPENED')
f:RegisterEvent('TRAINER_SHOW')
f:SetScript('OnEvent', function(_, event)
  if event == 'MERCHANT_SHOW' then ns.Throttle('reportVendor', 0.5, merchant)
  elseif event == 'LOOT_OPENED' then loot()
  else ns.Throttle('reportTrainer', 0.5, trainer) end
end)
