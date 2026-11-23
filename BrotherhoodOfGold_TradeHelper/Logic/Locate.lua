-- Choosing which vendor spot to pin. Pure Lua.
-- Spots are either from the data file { name, map, x, y } (world map id, server x/y)
-- or seen by you { name, uiMap, x, y } (map coordinates 0-1).
local _, ns = ...
local L = {}
ns.Locate = L

-- The spot to pin: one you saw on the map you are on; else the nearest data spot on your continent; else the first.
-- playerMap/px/py: your world map id and server x/y (nil when unknown); playerUiMap: the map you are on.
-- faction ('A'|'H', optional): the other faction's trainers and vendors are left out unless they are all there is.
function L.Pick(spots, playerMap, px, py, playerUiMap, faction)
  if not spots or #spots == 0 then return nil end
  if faction then
    local usable = {}
    for _, s in ipairs(spots) do if not s.faction or s.faction == faction then usable[#usable + 1] = s end end
    if #usable > 0 then spots = usable end
  end
  if playerUiMap then
    for _, s in ipairs(spots) do if s.uiMap == playerUiMap then return s end end
  end
  local best, bestDist
  if playerMap and px and py then
    for _, s in ipairs(spots) do
      if s.map == playerMap then
        local d = (s.x - px) ^ 2 + (s.y - py) ^ 2
        if not bestDist or d < bestDist then best, bestDist = s, d end
      end
    end
  end
  if best then return best end
  for _, s in ipairs(spots) do if s.uiMap or s.map == 0 or s.map == 1 then return s end end
  return spots[1]
end

-- Npcs you saw standing somewhere other than the data file says ({ [npcID] = { uiMap, x, y } }): use where you saw them.
function L.ApplyMoved(spots, moved)
  if not moved then return end
  for _, s in ipairs(spots) do
    local m = s.npc and moved[s.npc]
    if m then s.map, s.uiMap, s.x, s.y, s.moved = nil, m.uiMap, m.x, m.y, true end
  end
end

-- Route of a walking npc drawn on the map being viewed. route: flat { x, y, wait seconds, ... } (server coordinates);
-- toMap(x, y) gives that map's u, v (0-1) or nil. Returns { segments = { { u1, v1, u2, v2 } }, stops = { { u, v, wait } } }
-- with each segment and stop once (routes walk out and back), or nil when none of it is on this map.
local function onThisMap(u, v) return u and v and u >= -0.1 and u <= 1.1 and v >= -0.1 and v <= 1.1 end

function L.RouteSegments(route, toMap)
  if not route then return nil end
  local pts = {}
  for i = 1, #route - 2, 3 do
    local u, v = toMap(route[i], route[i + 1])
    pts[#pts + 1] = { u = u, v = v, wait = route[i + 2], ok = onThisMap(u, v) }
  end
  local segs, stops, seen = {}, {}, {}
  local function key(a, b) return string.format('%.4f,%.4f', a, b) end
  for i, p in ipairs(pts) do
    local q = pts[i + 1]
    if q and p.ok and q.ok then
      local a, b = key(p.u, p.v), key(q.u, q.v)
      local k = a < b and (a .. '|' .. b) or (b .. '|' .. a)
      if a ~= b and not seen[k] then seen[k] = true; segs[#segs + 1] = { p.u, p.v, q.u, q.v } end
    end
    if p.ok and p.wait and p.wait > 0 and not seen[key(p.u, p.v)] then
      seen[key(p.u, p.v)] = true
      stops[#stops + 1] = { p.u, p.v, p.wait }
    end
  end
  if #segs == 0 and #stops == 0 then return nil end
  return { segments = segs, stops = stops }
end

-- Npc ids of the spots that walk a route.
function L.Walking(spots)
  local out = {}
  for _, s in ipairs(spots or {}) do if s.walks and s.npc then out[#out + 1] = s.npc end end
  return out
end

-- Classic dungeons and raids (world map id -> name); their spawns have no zone coordinates.
local INSTANCES = {
  [33] = 'Shadowfang Keep', [34] = 'The Stockade', [36] = 'The Deadmines', [43] = 'Wailing Caverns',
  [47] = 'Razorfen Kraul', [48] = 'Blackfathom Deeps', [70] = 'Uldaman', [90] = 'Gnomeregan',
  [109] = 'Sunken Temple', [129] = 'Razorfen Downs', [189] = 'Scarlet Monastery', [209] = "Zul'Farrak",
  [229] = 'Blackrock Spire', [230] = 'Blackrock Depths', [289] = 'Scholomance', [309] = "Zul'Gurub",
  [329] = 'Stratholme', [349] = 'Maraudon', [389] = 'Ragefire Chasm', [409] = 'Molten Core',
  [429] = 'Dire Maul', [469] = 'Blackwing Lair', [509] = "Ruins of Ahn'Qiraj", [531] = "Temple of Ahn'Qiraj",
  [533] = 'Naxxramas',
}
function L.Instance(map) return INSTANCES[map] end

-- 0.4237, 0.6512 -> '42.4, 65.1'
function L.Coords(x, y)
  return string.format('%.1f, %.1f', x * 100, y * 100)
end

-- 8-point compass for an offset east / north.
local POINTS = { 'E', 'NE', 'N', 'NW', 'W', 'SW', 'S', 'SE' }
function L.Compass(east, north)
  local a = math.atan2 and math.atan2(north, east) or math.atan(north, east) -- the game's Lua 5.1 has atan2
  local i = math.floor(((a / (2 * math.pi)) * 8 + 0.5)) % 8
  return POINTS[i + 1]
end

local function thousands(n)
  local s = tostring(math.floor(n + 0.5))
  repeat
    local k
    s, k = s:gsub('^(%d+)(%d%d%d)', '%1,%2')
  until k == 0
  return s
end

-- '1,240 yd NE'; under 20 yards: 'right here'.
function L.Away(yards, east, north)
  if yards < 20 then return 'right here' end
  return thousands(yards) .. ' yd ' .. L.Compass(east, north)
end

local FACTION = { A = 'Alliance', H = 'Horde' }

-- Two tooltip lines for a spot: who ('Vendor: Qia (Alliance)', 'Drop: Ogre (2.2%)') and where.
-- place: { zone, continent, x, y, away } or { instance }, or nil when the spot can't be placed.
function L.Tip(spot, place)
  local extra = spot.pct and ((ns.RecipeSource and ns.RecipeSource.Pct(spot.pct) or string.format('%.1f', spot.pct)) .. '%')
    or FACTION[spot.faction or '']
  local who = (spot.kind and (spot.kind .. ': ') or '') .. spot.name .. (extra and (' (' .. extra .. ')') or '')
  if not place then return { who, 'Location unknown' } end
  if place.instance then return { who, 'Inside ' .. place.instance } end
  local where = place.zone .. (place.continent and (', ' .. place.continent) or '') .. '  ' .. L.Coords(place.x, place.y)
  if place.away then where = where .. '  -  ' .. place.away end
  if spot.moved then where = where .. '  (moved - where you saw it)' end
  if spot.walks and not spot.moved then where = where .. '  (walks a route - may be nearby)' end
  return { who, where }
end
