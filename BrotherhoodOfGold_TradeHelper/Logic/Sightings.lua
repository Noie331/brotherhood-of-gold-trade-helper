-- Where recipe items were seen: vendors that sold them and mobs/objects that dropped them. Pure Lua.
-- Store (account-wide BoG_DB.recipeItems):
--   { [itemID] = { vendors = { [npc] = { price, limited, uiMap, x, y } }, drops = { [mob or object] = times looted },
--                  dropSpots = { [mob or object] = { uiMap, x, y } } } }
local _, ns = ...
local S = {}
ns.Sightings = S

-- items: { { id, price, limited } } from one vendor. isRecipeItem(id) picks the recipe items. Returns how many.
-- spot (optional): where you stood, { uiMap, x, y } (map coordinates 0-1).
function S.RecordVendor(store, items, npc, isRecipeItem, spot)
  if not npc then return 0 end
  local n = 0
  for _, it in ipairs(items or {}) do
    if it.id and isRecipeItem(it.id) then
      store[it.id] = store[it.id] or {}
      store[it.id].vendors = store[it.id].vendors or {}
      local v = { price = it.price, limited = it.limited or nil }
      if spot then v.uiMap, v.x, v.y = spot.uiMap, spot.x, spot.y end
      store[it.id].vendors[npc] = v
      n = n + 1
    end
  end
  return n
end

-- Where you saw vendors of these items, then where you looted them: { { kind, name, uiMap, x, y } }, A-Z in each
-- (ones saved without a spot are left out).
function S.Spots(store, itemIDs)
  local out = {}
  for _, part in ipairs({ { 'vendors', 'Vendor' }, { 'dropSpots', 'Drop' } }) do
    local byName, list = {}, {}
    for _, id in ipairs(itemIDs or {}) do
      for name, v in pairs(store[id] and store[id][part[1]] or {}) do
        if v.uiMap and not byName[name] then
          byName[name] = true
          list[#list + 1] = { kind = part[2], name = name, uiMap = v.uiMap, x = v.x, y = v.y }
        end
      end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    for _, s in ipairs(list) do out[#out + 1] = s end
  end
  return out
end

-- spot (optional): where you looted, { uiMap, x, y }; the latest one is kept per source.
function S.RecordLoot(store, itemID, source, isRecipeItem, spot)
  if not itemID or not source or not isRecipeItem(itemID) then return false end
  store[itemID] = store[itemID] or {}
  store[itemID].drops = store[itemID].drops or {}
  store[itemID].drops[source] = (store[itemID].drops[source] or 0) + 1
  if spot then
    store[itemID].dropSpots = store[itemID].dropSpots or {}
    store[itemID].dropSpots[source] = { uiMap = spot.uiMap, x = spot.x, y = spot.y }
  end
  return true
end

local function list(label, names)
  if #names == 0 then return nil end
  local text = label .. ': ' .. table.concat(names, ', ', 1, math.min(2, #names))
  if #names > 2 then text = text .. ' +' .. (#names - 2) .. ' more' end
  return text
end

-- Everything seen for a recipe's items, or nil. skip: vendor names to leave out (already listed elsewhere).
function S.Text(store, itemIDs, fmt, skip)
  local vendors, drops = {}, {}
  for _, id in ipairs(itemIDs or {}) do
    local seen = store[id]
    if seen then
      for npc, v in pairs(seen.vendors or {}) do
        if not (skip and skip[npc]) and (not vendors[npc] or (v.price or 0) < (vendors[npc].price or 0)) then
          vendors[npc] = v
        end
      end
      for src, times in pairs(seen.drops or {}) do drops[src] = (drops[src] or 0) + times end
    end
  end
  local vNames, dNames = {}, {}
  for npc in pairs(vendors) do vNames[#vNames + 1] = npc end
  table.sort(vNames)
  for i, npc in ipairs(vNames) do
    local v, extra = vendors[npc], {}
    if v.price then extra[#extra + 1] = fmt(v.price) end
    if v.limited then extra[#extra + 1] = 'limited' end
    vNames[i] = #extra > 0 and (npc .. ' (' .. table.concat(extra, ', ') .. ')') or npc
  end
  for src in pairs(drops) do dNames[#dNames + 1] = src end
  table.sort(dNames, function(a, b) if drops[a] ~= drops[b] then return drops[a] > drops[b] end return a < b end)
  local parts = {}
  parts[#parts + 1] = list('Vendor', vNames)
  parts[#parts + 1] = list('Drop', dNames)
  return #parts > 0 and table.concat(parts, '  ·  ') or nil
end
