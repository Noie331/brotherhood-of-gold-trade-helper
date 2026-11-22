-- Item names, vendor sell prices and bind type. All return nil while the client has not cached the
-- item yet; a load is requested and the window refreshes when it arrives.
local _, ns = ...
local Items = {}
ns.Items = Items

-- Run fn at most once per `delay` seconds per key.
local timers = {}
function ns.Throttle(key, delay, fn)
  if timers[key] then return end
  timers[key] = true
  C_Timer.After(delay, function() timers[key] = nil; fn() end)
end

local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local BIND_ON_ACQUIRE = (Enum and Enum.ItemBind and Enum.ItemBind.OnAcquire) or 1
local pending = {}

local function request(id)
  if not id or pending[id] then return end
  pending[id] = true
  if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
end

function Items.Name(id)
  if not id then return nil end
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if not name then name = GetInfo(id) end
  if not name then request(id) end
  return name
end

-- Icon file id; works before the item is cached. Question mark when unknown.
local QUESTION = 134400
function Items.Icon(id)
  if not id then return nil end
  local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
  return icon or QUESTION
end

-- noLoad: don't ask the client to load an uncached item (callers that look up thousands of items
-- ask in batches with Items.Request instead).
function Items.SellPrice(id, noLoad)
  local name, _, _, _, _, _, _, _, _, _, sellPrice = GetInfo(id)
  if not name then
    if not noLoad then request(id) end
    return nil
  end
  return sellPrice
end

function Items.Request(id) request(id) end

local function isCached(id)
  if C_Item and C_Item.IsItemDataCachedByID then return C_Item.IsItemDataCachedByID(id) end
  return GetInfo(id) ~= nil
end

-- Background loading of many items (the AH Sell list): 500 asked every 0.25 s, finished when all
-- have loaded or after 30 s. `key` names the item set (one per AH scan); asking again with the same
-- key just reports progress. `loud`: the window shows a loading message (only after a new scan);
-- quiet jobs just refresh the list once when done. Returns loading (and loud), loaded, total.
local job
function Items.Preloading() return job ~= nil and not job.done end

function Items.PreloadFor(key, ids, loud)
  if job and job.key == key then return (not job.done) and job.loud, job.loaded, job.st.total end
  local j = { key = key, st = ns.Preload.New(ids), started = GetTime(), done = false, loaded = 0, loud = loud }
  job = j
  local function tick()
    if job ~= j or j.done then return end
    local done, loaded = ns.Preload.Step(j.st, isCached, request, 500)
    j.loaded = loaded
    if done or GetTime() - j.started > 30 then j.done = true end
    if ns.Refresh and ns.Window and (j.done or (j.loud and ns.Window.Selected() == ns.View.FLIP_TAB)) then ns.Refresh() end
    if not j.done then C_Timer.After(0.25, tick) end
  end
  tick()
  return (not j.done) and j.loud, j.loaded, j.st.total
end

function Items.IsBoP(id)
  local name, _, _, _, _, _, _, _, _, _, _, _, _, bindType = GetInfo(id)
  if not name then request(id); return false end
  return bindType == BIND_ON_ACQUIRE
end

local f = CreateFrame('Frame')
f:RegisterEvent('ITEM_DATA_LOAD_RESULT')
f:SetScript('OnEvent', function(_, _, itemID)
  if itemID and pending[itemID] then
    pending[itemID] = nil
    -- While a batch load runs, it refreshes once at the end instead (no jumping list).
    if Items.Preloading() then return end
    ns.Throttle('items', 0.5, function() if ns.Refresh then ns.Refresh() end end)
  end
end)

-- Shift-click on a row: put its item (or recipe spell) link in the chat box you have open. True when it went in.
function ns.LinkToChat(line)
  local what = line and ns.View.TooltipFor(line)
  if not what then return false end
  local link
  if what.itemID then
    link = select(2, C_Item.GetItemInfo(what.itemID))
  elseif what.spellID then
    link = C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(what.spellID)
  end
  if not link then return false end
  local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
  return insert and insert(link) and true or false
end

-- Recipes-tab search by effect: the crafted item's tooltip text (stats, Use:, well fed...) plus the recipe spell's
-- description (enchants). Kept once complete; while the item is still loading, asked again on the next search.
local effects = {}
function ns.RecipeEffectText(r)
  local id = r and r.recipeID
  if not id then return nil end
  if effects[id] then return effects[id] end
  local parts, complete = {}, true
  local get = C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic
  local ok, schematic = false, nil
  if get then ok, schematic = pcall(get, id, false) end
  local item = ok and schematic and schematic.outputItemID
  if item and C_TooltipInfo and C_TooltipInfo.GetItemByID then
    local data = isCached(item) and C_TooltipInfo.GetItemByID(item)
    if data and data.lines and #data.lines > 0 then
      for _, l in ipairs(data.lines) do
        if l.leftText and l.leftText ~= '' then parts[#parts + 1] = l.leftText end
        if l.rightText and l.rightText ~= '' then parts[#parts + 1] = l.rightText end
      end
    else
      complete = false
      request(item)
    end
  end
  local desc = C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(id)
  if desc and desc ~= '' then parts[#parts + 1] = desc end
  -- Materials it uses, so "wool cloth" finds every recipe that needs it.
  for _, slot in ipairs(ok and schematic and schematic.reagentSlotSchematics or {}) do
    for _, reagent in ipairs(slot.reagents or {}) do
      local name = reagent.itemID and Items.Name(reagent.itemID)
      if name then parts[#parts + 1] = name elseif reagent.itemID then complete = false end
    end
  end
  local text = table.concat(parts, ' ')
  if complete then effects[id] = text end
  return text
end
