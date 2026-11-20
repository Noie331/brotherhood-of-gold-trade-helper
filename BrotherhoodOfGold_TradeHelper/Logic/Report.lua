-- Data report: recipe sources the data file doesn't have yet, saved as you play and exported with /bog export
-- for the shared data file. Keyed by npc id; no character or realm names. Pure Lua.
-- Shape (account-wide BoG_DB.report):
--   { v = 1, id = random reporter token, build,
--     vendors  = { [npcID] = { n = name, f = 'A'|'H'|'', m = uiMap, x, y, items = { [itemID] = { p = copper, l = limited, c = 'other cost' } } } },
--     drops    = { [npcID] = { n, m, x, y, items = { [itemID] = times looted } } },
--     looted   = { [npcID] = corpses looted },
--     trainers = { [npcID] = { n, f, m, x, y, teach = { ['Profession:Recipe name'] = skill needed } } } }
local _, ns = ...
local R = {}
ns.Report = R

function R.New(token, build)
  return { v = 1, id = token, build = build, vendors = {}, drops = {}, looted = {}, trainers = {} }
end

-- 'Creature-0-1-2-3-11189-0000ABCD' -> 11189; nil for players, pets and anything else.
function R.NpcID(guid)
  if type(guid) ~= 'string' or not guid:find('^Creature%-') then return nil end
  return tonumber(guid:match('^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)'))
end

local function npcRecord(section, npc, spot, withFaction)
  local r = section[npc.id] or {}
  r.n = npc.name
  if withFaction then r.f = npc.faction or '' end
  if spot then r.m, r.x, r.y = spot.uiMap, spot.x, spot.y end
  section[npc.id] = r
  return r
end

-- items: { { id, price, limited, cost } } from one vendor; keep(itemID, npcID) says whether it is news.
function R.Vendor(rep, npc, spot, items, keep)
  if not npc or not npc.id then return 0 end
  local new = {}
  for _, it in ipairs(items or {}) do
    if it.id and keep(it.id, npc.id) then new[#new + 1] = it end
  end
  if #new == 0 then return 0 end
  local r = npcRecord(rep.vendors, npc, spot, true)
  r.items = r.items or {}
  for _, it in ipairs(new) do r.items[it.id] = { p = it.price, l = it.limited or nil, c = it.cost } end
  return #new
end

-- One looted corpse: itemIDs are the recipe items on it; keep(itemID, npcID) as for vendors.
function R.Loot(rep, npc, spot, itemIDs, keep)
  if not npc or not npc.id then return end
  rep.looted[npc.id] = (rep.looted[npc.id] or 0) + 1
  for _, id in ipairs(itemIDs or {}) do
    if keep(id, npc.id) then
      local r = npcRecord(rep.drops, npc, spot)
      r.items = r.items or {}
      r.items[id] = (r.items[id] or 0) + 1
    end
  end
end

-- services: { { name, prof, skill } }; ones without a profession (riding, ranks) are left out.
function R.Trainer(rep, npc, spot, services)
  if not npc or not npc.id then return end
  local teach, any = {}, false
  for _, s in ipairs(services or {}) do
    if s.prof and s.name then teach[s.prof .. ':' .. s.name] = s.skill or 0; any = true end
  end
  if not any then return end
  npcRecord(rep.trainers, npc, spot, true).teach = teach
end

-- What the data file already knows per recipe item: { [itemID] = { vendors = { [npc] = true }, drops = { [npc] = true } } }.
-- World drops list no mobs, so every mob's count for them is news.
function R.Index(recipes)
  local idx = {}
  for _, e in pairs(recipes or {}) do
    for _, item in ipairs(e.items or {}) do
      local k = idx[item] or { vendors = {}, drops = {} }
      idx[item] = k
      for _, v in ipairs(e.vendors or {}) do k.vendors[v[1]] = true end
      if not e.worldDrop then
        for _, d in ipairs(e.drops or {}) do k.drops[type(d) == 'table' and d[1] or d] = true end
      end
    end
  end
  return idx
end

-- keep(itemID, npcID) for R.Vendor / R.Loot: a recipe item from an npc the data file doesn't list for it.
function R.Keeper(idx, section)
  return function(item, npc)
    local k = idx[item]
    return k ~= nil and not k[section][npc]
  end
end

local function isList(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n > 0 and n == #t
end

local function number(v)
  if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format('%d', v) end
  local s = string.format('%.4f', v):gsub('0+$', ''):gsub('%.$', '')
  return s
end

local function str(s)
  return '"' .. s:gsub('[%c"\\|]', function(c)
    if c == '"' then return '\\"' elseif c == '\\' then return '\\\\' end
    return string.format('\\u%04x', c:byte())
  end) .. '"'
end

-- Plain JSON (keys sorted, '|' escaped so WoW's chat box shows it as typed).
function R.JSON(v)
  local t = type(v)
  if t == 'number' then return number(v) end
  if t == 'string' then return str(v) end
  if t == 'boolean' then return tostring(v) end
  if t ~= 'table' then return 'null' end
  local parts = {}
  if isList(v) then
    for _, x in ipairs(v) do parts[#parts + 1] = R.JSON(x) end
    return '[' .. table.concat(parts, ',') .. ']'
  end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local x = v[k]
    if x == nil then x = v[tonumber(k)] end
    parts[#parts + 1] = str(k) .. ':' .. R.JSON(x)
  end
  return '{' .. table.concat(parts, ',') .. '}'
end

function R.IsEmpty(rep)
  return next(rep.vendors) == nil and next(rep.drops) == nil and next(rep.trainers) == nil
end

-- One line: 'BOG1 ' .. JSON. Looted counts only for npcs that dropped a recipe item. addon: the addon's version.
function R.Export(rep, now, addon)
  local looted = {}
  for id in pairs(rep.drops) do looted[id] = rep.looted[id] end
  return 'BOG1 ' .. R.JSON({ v = rep.v, id = rep.id, build = rep.build, t = now, addon = addon,
    vendors = rep.vendors, drops = rep.drops, looted = looted, trainers = rep.trainers })
end
