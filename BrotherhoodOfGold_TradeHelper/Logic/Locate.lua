-- Choosing which vendor spot to pin. Pure Lua.
-- Spots are either from the data file { name, map, x, y } (world map id, server x/y)
-- or seen by you { name, uiMap, x, y } (map coordinates 0-1).
local _, ns = ...
local L = {}
ns.Locate = L

-- The spot to pin: one you saw on the map you are on; else the nearest data spot on your continent; else the first.
-- playerMap/px/py: your world map id and server x/y (nil when unknown); playerUiMap: the map you are on.
function L.Pick(spots, playerMap, px, py, playerUiMap)
  if not spots or #spots == 0 then return nil end
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
