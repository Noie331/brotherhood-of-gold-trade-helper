-- Where a recipe's trainers, vendors and drop mobs are: zone + coordinates, and a map pin on the nearest one.
-- Data-file spots are world positions (map 0/1, server x/y) turned into zone coordinates with C_Map;
-- vendors you visited and mobs you looted carry the zone and coordinates you stood at.
local _, ns = ...
local L = ns.Locate

local CONTINENT = { [0] = 1415, [1] = 1414 } -- uiMap of Eastern Kingdoms, Kalimdor
local swap -- whether world vectors take (y, x); worked out once from your own position

local function vec(x, y, s) if s then return CreateVector2D(y, x) end return CreateVector2D(x, y) end
local function onMap(p) return p and p.x >= 0 and p.x <= 1 and p.y >= 0 and p.y <= 1 end

local function worldPos(map, v, uiMap)
  local ok, _, p = pcall(C_Map.GetMapPosFromWorldPos, map, v, uiMap)
  if ok then return p end
  return nil
end

-- The data file's x/y are the same pair UnitPosition gives; check which way round C_Map wants them.
local function calibrate()
  if swap ~= nil or not UnitPosition then return end
  local ok, a, b, _, inst = pcall(UnitPosition, 'player')
  local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
  local here = m and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(m, 'player')
  if not ok or not a or not here then return end
  for _, s in ipairs({ false, true }) do
    local p = worldPos(inst, vec(a, b, s), m)
    if p and math.abs(p.x - here.x) + math.abs(p.y - here.y) < 0.01 then swap = s; return end
  end
end

-- uiMap, x, y (0-1) for a spot, or nil.
local function resolve(s)
  if s.uiMap then return s.uiMap, s.x, s.y end
  local cont = CONTINENT[s.map]
  if not cont or not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
  calibrate()
  for _, o in ipairs(swap == nil and { false, true } or { swap }) do
    local v = vec(s.x, s.y, o)
    local p = worldPos(s.map, v, cont)
    if onMap(p) then
      local info = C_Map.GetMapInfoAtPosition and C_Map.GetMapInfoAtPosition(cont, p.x, p.y)
      local zone = info and info.mapID or cont
      local zp = worldPos(s.map, v, zone)
      if onMap(zp) then return zone, zp.x, zp.y end
      return cont, p.x, p.y
    end
  end
  return nil
end

-- Server x, y on world map `map` as u, v (0-1, can be outside) on uiMap `uiMap`, or nil.
function L.WorldToMap(map, x, y, uiMap)
  if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
  calibrate()
  for _, o in ipairs(swap == nil and { false, true } or { swap }) do
    local p = worldPos(map, vec(x, y, o), uiMap)
    if p and (swap ~= nil or onMap(p)) then return p.x, p.y end
  end
  return nil
end

local function zoneName(uiMap)
  local info = C_Map.GetMapInfo and C_Map.GetMapInfo(uiMap)
  return info and info.name or ('map ' .. uiMap)
end

-- All spots for a Recipes-tab line: the data file's, then ones you saw that it doesn't list.
local function myFaction() return ({ Alliance = 'A', Horde = 'H' })[UnitFactionGroup('player') or ''] end

local function spotsFor(line)
  local data = ns.RecipeData
  if line.questID then
    local spots = ns.RecipeSource.QuestSpots(data and data.quests and data.quests[line.questID], data and data.npcs or {},
      myFaction())
    L.ApplyMoved(spots, ns.db and ns.db.moved)
    return spots
  end
  local entry = data and data.recipes[line.recipeID]
  if not entry then return {} end
  local faction = myFaction()
  local spots = ns.RecipeSource.Spots(entry, data.npcs, faction)
  L.ApplyMoved(spots, ns.db and ns.db.moved)
  local listed = {}
  for _, s in ipairs(spots) do listed[s.kind .. s.name] = true end
  for _, s in ipairs(ns.Sightings.Spots(ns.db and ns.db.recipeItems or {}, entry.items)) do
    if not listed[s.kind .. s.name] then spots[#spots + 1] = s end
  end
  return spots
end

local function describe(s)
  local m, x, y = resolve(s)
  local who = (s.kind and (s.kind .. ' ') or '') .. s.name .. (s.pct and (' (' .. ns.RecipeSource.Pct(s.pct) .. ')') or '')
  if not m then
    local inst = s.map and L.Instance(s.map)
    return inst and (who .. ' - ' .. inst) or who, nil
  end
  return who .. ' - ' .. zoneName(m) .. ' ' .. L.Coords(x, y), m, x, y
end

-- The continent a zone map is on (nil when the map is a continent itself or unknown).
local function continentName(uiMap)
  local info = C_Map.GetMapInfo and C_Map.GetMapInfo(uiMap)
  if not info or info.mapType == 2 then return nil end
  for _ = 1, 5 do
    info = info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
    if not info then return nil end
    if info.mapType == 2 then return info.name end
  end
  return nil
end

local function world(uiMap, x, y)
  if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local ok, cont, p = pcall(C_Map.GetWorldPosFromMapPos, uiMap, CreateVector2D(x, y))
  if ok and cont and p then return cont, p end
  return nil
end

-- '1,240 yd NE' from where you stand to uiMap x, y; nil when not on the same continent.
local function awayFromYou(m, x, y)
  local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
  local hp = here and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(here, 'player')
  if not hp then return nil end
  local pc, pw = world(here, hp.x, hp.y)
  local sc, sw = world(m, x, y)
  if not pc or pc ~= sc then return nil end
  -- Which world direction is east and north: one small step on your own map.
  local _, e = world(here, hp.x + 0.01, hp.y)
  local _, n = world(here, hp.x, hp.y - 0.01)
  if not e or not n then return nil end
  local dx, dy = sw.x - pw.x, sw.y - pw.y
  local ex, ey, nx, ny = e.x - pw.x, e.y - pw.y, n.x - pw.x, n.y - pw.y
  local el, nl = math.sqrt(ex * ex + ey * ey), math.sqrt(nx * nx + ny * ny)
  if el == 0 or nl == 0 then return nil end
  return L.Away(math.sqrt(dx * dx + dy * dy), (dx * ex + dy * ey) / el, (dx * nx + dy * ny) / nl)
end

local function place(s)
  local m, x, y = resolve(s)
  if not m then
    local inst = s.map and L.Instance(s.map)
    return inst and { instance = inst } or nil
  end
  return { zone = zoneName(m), continent = continentName(m), x = x, y = y, away = awayFromYou(m, x, y) }
end

local MAX_LINES = 8 -- more than this: "+N more"

-- Recipes-tab hover: { { 'Vendor: Qia (Alliance)', 'Winterspring, Kalimdor  61.2, 37.4  -  1,240 yd NE' }, ... }.
function L.TipLines(line)
  local out, spots = {}, spotsFor(line)
  for i = 1, math.min(#spots, MAX_LINES) do out[i] = L.Tip(spots[i], place(spots[i])) end
  if #spots > MAX_LINES then out[#out + 1] = { '+' .. (#spots - MAX_LINES) .. ' more' } end
  return out
end

-- Tooltip lines: "Vendor Qia - Winterspring 61.2, 37.4" for each npc with a known spot.
function L.Lines(line)
  local out, spots = {}, spotsFor(line)
  for i = 1, math.min(#spots, MAX_LINES) do out[i] = (describe(spots[i])) end
  if #spots > MAX_LINES then out[#out + 1] = '+' .. (#spots - MAX_LINES) .. ' more' end
  return out
end

local function say(msg) print('|cffe8c66aTrade Helper|r ' .. msg) end

-- Click on a recipe: list where to get it in chat and pin the nearest spot on the map.
function L.Show(line)
  local spots = spotsFor(line)
  local walking = L.Walking(spots)
  if L.SetRoutes then L.SetRoutes(walking) end
  if #spots == 0 then say('No location known for ' .. (line.name or 'this recipe') .. '.'); return end
  say((line.name or 'Recipe') .. ':')
  for _, text in ipairs(L.Lines(line)) do say('  ' .. text) end
  if L.HasRoute and L.HasRoute(walking) then
    say('  Walking route drawn on the world map (yellow line; orange squares: where they stop and wait).')
  end
  local ok, px, py, _, inst = pcall(UnitPosition, 'player')
  if not ok then px, py, inst = nil, nil, nil end
  local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
  local pick = L.Pick(spots, inst, px, py, here, myFaction())
  local text, m, x, y = describe(pick)
  if not m then return end
  if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(m) and UiMapPoint then
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(m, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    say('Map pin set: ' .. text)
  end
end

-- /bog probe check of the world -> zone conversion: Qia stands in Everlook, about Winterspring 61, 37.
function L.ProbeText()
  local n = ns.RecipeData and ns.RecipeData.npcs[11189]
  if not n or not n[3] then return 'no spawn data' end
  local text, m = describe({ name = n[1], map = n[3], x = n[4], y = n[5] })
  return m and text or 'could not convert (' .. text .. ')'
end

-- Where you are now, for saving with a vendor visit: { uiMap, x, y } or nil.
function L.Here()
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
  local p = m and C_Map.GetPlayerMapPosition(m, 'player')
  if not p then return nil end
  return { uiMap = m, x = math.floor(p.x * 1000 + 0.5) / 1000, y = math.floor(p.y * 1000 + 0.5) / 1000 }
end
