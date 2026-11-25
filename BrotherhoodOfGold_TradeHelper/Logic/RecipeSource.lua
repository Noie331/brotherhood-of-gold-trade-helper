-- Where a recipe comes from: the generated data file (Data/RecipeSources.lua) plus where its item was seen. Pure Lua.
-- entry fields: see tools/build_recipe_data.py. npcs = { [id] = { name, 'A'|'H'|'', map, x, y | ui = { uiMap, x, y } } }.
local _, ns = ...
local RS = {}
ns.RecipeSource = RS

local FACTION_NAME = { A = 'Alliance', H = 'Horde' }
local MANY_TRAINERS = 3 -- more than this: "any of N trainers"
RS.NO_SOURCE = 'Source unknown - send a data report if you find it'

local function names(list)
  local text = table.concat(list, ', ', 1, math.min(2, #list))
  if #list > 2 then text = text .. ' +' .. (#list - 2) .. ' more' end
  return text
end

local function npcName(npcs, id) return npcs[id] and npcs[id][1] or ('NPC ' .. id) end

-- NPCs that serve your faction (or both); the other faction's only when nobody else does.
-- Returns the names, A-Z, and the other faction's name when those are all there is.
local function byFaction(ids, npcs, faction, label)
  local ours, theirs, theirFaction = {}, {}, nil
  for _, item in ipairs(ids or {}) do
    local id = type(item) == 'table' and item[1] or item
    local f = npcs[id] and npcs[id][2] or ''
    local name = label and label(item, npcName(npcs, id)) or npcName(npcs, id)
    if f == '' or f == faction or not faction then ours[#ours + 1] = name
    else theirs[#theirs + 1] = name; theirFaction = f end
  end
  table.sort(ours); table.sort(theirs)
  if #ours > 0 then return ours end
  if #theirs > 0 then return theirs, FACTION_NAME[theirFaction] or theirFaction end
  return nil
end

local function vendorText(entry, npcs, faction, fmt)
  local list, only = byFaction(entry.vendors, npcs, faction,
    function(v, name) return name .. (v[2] and ' (limited)' or '') end)
  if not list then return nil end
  local text = (only and ('Vendor (' .. only .. ' only)') or 'Vendor') .. ': ' .. names(list)
  local cost = {}
  if entry.price and entry.price > 0 then cost[#cost + 1] = fmt(entry.price) end
  if entry.cost then cost[#cost + 1] = entry.cost end -- another currency, from player reports
  if #cost > 0 then text = text .. ' (' .. table.concat(cost, ' + ') .. ')' end
  return text
end

local function trainerText(entry, npcs, faction)
  local list, only = byFaction(entry.trainers, npcs, faction)
  if not list then return nil end
  local title = only and ('Trainer (' .. only .. ' only)') or 'Trainer'
  if #list > MANY_TRAINERS then return title .. ': any of ' .. #list .. ' trainers' end
  return title .. ': ' .. table.concat(list, ', ')
end

-- 25 -> '25%', 2.5 -> '2.5%', 0.02 -> '0.02%'
function RS.Pct(p)
  local text
  if p < 0.01 then return '<0.01%'
  elseif p >= 10 then text = string.format('%d', math.floor(p + 0.5))
  elseif p >= 1 then text = string.format('%.1f', p):gsub('%.0$', '')
  else text = string.format('%.2g', p) end
  return text .. '%'
end

-- Drop mobs, highest chance first (then A-Z): { { id, pct or nil } }. drops entries are ids or { id, pct }.
local function byChance(drops)
  local list = {}
  for _, d in ipairs(drops or {}) do
    if type(d) == 'table' then list[#list + 1] = { d[1], d[2] } else list[#list + 1] = { d } end
  end
  return list
end

local function dropText(entry, npcs)
  if entry.worldDrop then
    local b = entry.best
    return 'Drop: world drop' .. (b and (' (best: ' .. npcName(npcs, b[1]) .. ' ' .. RS.Pct(b[2]) .. ')') or '')
  end
  if not entry.drops then return nil end
  local list = byChance(entry.drops)
  for _, d in ipairs(list) do d.name = npcName(npcs, d[1]) end
  table.sort(list, function(a, b)
    if (a[2] or 0) ~= (b[2] or 0) then return (a[2] or 0) > (b[2] or 0) end
    return a.name < b.name
  end)
  for i, d in ipairs(list) do list[i] = d[2] and (d.name .. ' (' .. RS.Pct(d[2]) .. ')') or d.name end
  return 'Drop: ' .. names(list)
end

local function listText(label, list)
  if not list or #list == 0 then return nil end
  return label .. ': ' .. names(list)
end

-- Quest titles, each with the quest to do first when the data file's rewardQuests knows it.
local function questTitles(titles, rq)
  if not titles then return nil end
  local out = {}
  for i, title in ipairs(titles) do
    local after = rq and rq[title] and rq[title].after
    out[i] = after and (title .. ' (after ' .. after .. ')') or title
  end
  return out
end

-- entry: the data file's row for the recipe (nil when it isn't in the file).
-- seenText: vendors/drops recorded for the recipe item (Sightings), or nil. faction: 'A' or 'H'.
-- rq: the data file's rewardQuests ({ [title] = { givers, objects, after } }), or nil.
-- Returns where to get the recipe (nil when nothing is known), and the skill needed to learn it.
function RS.Text(entry, seenText, faction, fmt, npcs, rq)
  if not entry then return seenText end
  fmt = fmt or (ns.Format and ns.Format.Money) or tostring
  npcs = npcs or {}
  local parts = {}
  if entry.auto then parts[#parts + 1] = 'Learned with the profession' end
  parts[#parts + 1] = trainerText(entry, npcs, faction)
  parts[#parts + 1] = vendorText(entry, npcs, faction, fmt)
  parts[#parts + 1] = dropText(entry, npcs)
  parts[#parts + 1] = listText('Chest', entry.objects)
  parts[#parts + 1] = listText('Quest', questTitles(entry.quests, rq))
  parts[#parts + 1] = seenText
  if #parts > 0 then return table.concat(parts, '  ·  '), entry.skill end
  return entry.items and RS.NO_SOURCE or nil, entry.skill
end

-- Spots of the npcs in a list that have a spawn: yours and neutral; the other faction's only when that is all. A-Z.
local function spotsOf(ids, npcs, faction, kind, anyFaction)
  local ours, theirs = {}, {}
  for _, item in ipairs(ids or {}) do
    local id = type(item) == 'table' and item[1] or item
    local n = npcs[id]
    if n and (n[3] or n.ui) then
      local spot = { kind = kind, npc = id, name = n[1], map = n[3], x = n[4], y = n[5] }
      if not n[3] then spot.map, spot.uiMap, spot.x, spot.y = nil, n.ui[1], n.ui[2], n.ui[3] end
      if type(item) == 'table' and kind == 'Drop' then spot.pct = item[2] end
      if n.walks then spot.walks = true end
      if kind ~= 'Drop' and (n[2] == 'A' or n[2] == 'H') then spot.faction = n[2] end
      if anyFaction or n[2] == '' or n[2] == faction or not faction then ours[#ours + 1] = spot else theirs[#theirs + 1] = spot end
    end
  end
  local out = #ours > 0 and ours or theirs
  table.sort(out, function(a, b)
    if (a.pct or 0) ~= (b.pct or 0) then return (a.pct or 0) > (b.pct or 0) end
    return a.name < b.name
  end)
  return out
end

-- The givers of the quests that reward this recipe (rq: the data file's rewardQuests), each once.
local function questGivers(titles, rq)
  local out, seen = {}, {}
  for _, title in ipairs(titles or {}) do
    for _, id in ipairs(rq and rq[title] and rq[title].givers or {}) do
      if not seen[id] then seen[id] = true; out[#out + 1] = id end
    end
  end
  return out
end

-- Where the data file's trainers, vendors, drop mobs and reward quest givers for this recipe stand:
-- { { kind = 'Trainer'|'Vendor'|'Drop'|'Quest giver', name, map, x, y, pct (drops: % chance) } } (world map id and
-- server x, y), the same npcs the text shows.
function RS.Spots(entry, npcs, faction, rq)
  local out = {}
  if not entry then return out end
  for _, part in ipairs({ { entry.trainers, 'Trainer' }, { entry.vendors, 'Vendor' }, { entry.drops or (entry.best and { entry.best }), 'Drop', true },
                          { questGivers(entry.quests, rq), 'Quest giver' } }) do
    for _, s in ipairs(spotsOf(part[1], npcs, faction, part[2], part[3])) do out[#out + 1] = s end
  end
  return out
end

-- Vendor names the data file lists for this recipe (so seen vendors don't repeat them).
function RS.VendorNames(entry, npcs)
  local out = {}
  for _, v in ipairs(entry and entry.vendors or {}) do out[npcName(npcs or {}, v[1])] = true end
  return out
end

-- Profession quests (data file quests table). Who or what starts one, and the quest to do before it.
function RS.QuestText(q, npcs, faction)
  local parts = {}
  local list, only = byFaction(q.givers, npcs, faction)
  if list then parts[#parts + 1] = (only and ('Starts (' .. only .. ' only)') or 'Starts') .. ': ' .. names(list)
  elseif q.objects then parts[#parts + 1] = 'Starts at: ' .. names(q.objects)
  elseif q.item then parts[#parts + 1] = 'Starts from item: ' .. q.item
  else parts[#parts + 1] = 'Start unknown' end
  if q.after then parts[#parts + 1] = 'After: ' .. q.after end
  return table.concat(parts, '  ·  ')
end

-- Where a quest's givers stand (same spots as RS.Spots, kind 'Quest giver').
function RS.QuestSpots(q, npcs, faction)
  return q and spotsOf(q.givers, npcs, faction, 'Quest giver') or {}
end
