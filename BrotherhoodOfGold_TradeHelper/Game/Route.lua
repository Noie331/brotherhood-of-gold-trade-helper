-- Walking routes on the world map: after clicking a recipe on the Recipes tab, the routes of its vendors and
-- trainers that walk (Data/RecipeSources.lua routes) are drawn on whatever map you look at.
local _, ns = ...
local L = ns.Locate

local active = {}         -- npc ids whose route is shown
local provider, layer     -- world map data provider and the frame the lines sit on
local lines, squares = {}, {}
local COLOR, STOP = { 1, 0.82, 0, 0.9 }, { 1, 0.35, 0.1, 1 }

function L.HasRoute(ids)
  local routes = ns.RecipeData and ns.RecipeData.routes or {}
  for _, id in ipairs(ids or {}) do if routes[id] then return true end end
  return false
end

local function clear()
  for _, l in ipairs(lines) do l:Hide() end
  for _, q in ipairs(squares) do q:Hide() end
end

local last = {} -- what the last draw did, for /bog probe

-- Put the lines on the level the map gives its own icons (quest markers, area POIs), above the map picture.
local function raise(map)
  if not layer.SetFrameLevel then return end
  local level
  local mgr = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
  if mgr and mgr.GetValidFrameLevel then
    local ok, v = pcall(mgr.GetValidFrameLevel, mgr, 'PIN_FRAME_LEVEL_AREA_POI')
    if ok and type(v) == 'number' then level = v end
  end
  local canvas = map:GetCanvas()
  level = level or ((canvas.GetFrameLevel and canvas:GetFrameLevel() or 0) + 500)
  if layer.SetFrameStrata and canvas.GetFrameStrata then layer:SetFrameStrata(canvas:GetFrameStrata()) end
  layer:SetFrameLevel(level)
end

local function draw()
  clear()
  last = {}
  if not provider or not layer or #active == 0 then return end
  local map = provider:GetMap()
  local uiMap, canvas = map:GetMapID(), map:GetCanvas()
  if not uiMap or not canvas then return end
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  last.uiMap, last.w, last.h = uiMap, w, h
  raise(map)
  last.level = layer.GetFrameLevel and layer:GetFrameLevel()
  if not w or w == 0 then return end -- map not laid out yet: drawn when it is shown
  local scale = (map.GetCanvasScale and map:GetCanvasScale()) or 1
  local data, nl, nq = ns.RecipeData, 0, 0
  for _, id in ipairs(active) do
    local n, route = data.npcs[id], data.routes and data.routes[id]
    local r = n and n[3] and route and L.RouteSegments(route, function(x, y) return L.WorldToMap(n[3], x, y, uiMap) end)
    for _, s in ipairs(r and r.segments or {}) do
      nl = nl + 1
      local l = lines[nl] or layer:CreateLine(nil, 'OVERLAY')
      lines[nl] = l
      l:SetThickness(3 / scale)
      l:SetColorTexture(COLOR[1], COLOR[2], COLOR[3], COLOR[4])
      l:SetStartPoint('TOPLEFT', layer, s[1] * w, -s[2] * h)
      l:SetEndPoint('TOPLEFT', layer, s[3] * w, -s[4] * h)
      l:Show()
    end
    for _, p in ipairs(r and r.stops or {}) do
      nq = nq + 1
      local q = squares[nq] or layer:CreateTexture(nil, 'OVERLAY')
      squares[nq] = q
      q:SetSize(10 / scale, 10 / scale)
      q:SetColorTexture(STOP[1], STOP[2], STOP[3], STOP[4])
      q:ClearAllPoints()
      q:SetPoint('CENTER', layer, 'TOPLEFT', p[1] * w, -p[2] * h)
      q:Show()
    end
  end
  last.lines, last.stops = nl, nq
end

-- /bog probe: is the map hooked, what is shown, and what the last draw put on which map.
function L.RouteProbe()
  local routes, n = ns.RecipeData and ns.RecipeData.routes or {}, 0
  for _ in pairs(routes) do n = n + 1 end
  local names = {}
  for _, id in ipairs(active) do names[#names + 1] = ns.RecipeData.npcs[id] and ns.RecipeData.npcs[id][1] or tostring(id) end
  local text = 'map hooked ' .. (provider and layer and 'yes' or 'no') .. ', routes in data ' .. n
    .. ', showing ' .. (#names > 0 and table.concat(names, ', ') or 'none')
  if last.uiMap then
    text = text .. ', on map ' .. last.uiMap .. ': ' .. (last.lines or 0) .. ' lines, ' .. (last.stops or 0) .. ' stops'
      .. ' (canvas ' .. string.format('%dx%d', last.w or 0, last.h or 0) .. ', level ' .. tostring(last.level) .. ')'
  end
  return text
end

-- Show these npcs' routes (npc ids; empty clears them).
function L.SetRoutes(ids)
  active = {}
  local routes = ns.RecipeData and ns.RecipeData.routes or {}
  for _, id in ipairs(ids or {}) do if routes[id] then active[#active + 1] = id end end
  draw()
end

local function setup()
  if provider or not (WorldMapFrame and WorldMapFrame.AddDataProvider and MapCanvasDataProviderMixin and CreateFromMixins) then
    return
  end
  provider = CreateFromMixins(MapCanvasDataProviderMixin)
  function provider:OnAdded(map)
    MapCanvasDataProviderMixin.OnAdded(self, map)
    layer = CreateFrame('Frame', nil, map:GetCanvas())
    layer:SetAllPoints(map:GetCanvas())
  end
  function provider:RemoveAllData() clear() end
  function provider:RefreshAllData() draw() end
  function provider:OnMapChanged() draw() end
  function provider:OnCanvasScaleChanged() draw() end
  function provider:OnCanvasSizeChanged() draw() end
  function provider:OnShow() draw() end
  WorldMapFrame:AddDataProvider(provider)
  if WorldMapFrame.HookScript then WorldMapFrame:HookScript('OnShow', draw) end -- in case the canvas doesn't tell providers
end

setup()
if not provider then -- the world map loads later on some clients
  local f = CreateFrame('Frame')
  f:RegisterEvent('ADDON_LOADED')
  f:RegisterEvent('PLAYER_LOGIN')
  f:SetScript('OnEvent', function() setup() end)
end
