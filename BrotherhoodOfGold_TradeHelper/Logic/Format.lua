-- Money and time text. Pure Lua: no WoW API.
local _, ns = ...
local Format = {}
ns.Format = Format

local function money(copper, gold, silver, copperMark)
  copper = math.floor(copper or 0)
  local sign = ''
  if copper < 0 then sign = '-'; copper = -copper end
  if copper == 0 then return '0' .. copperMark end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. gold end
  if s > 0 then parts[#parts + 1] = s .. silver end
  if c > 0 then parts[#parts + 1] = c .. copperMark end
  return sign .. table.concat(parts, ' ')
end

-- Copper amount as "1g 20s 5c", leaving out zero parts; "0c" for nothing.
function Format.Money(copper) return money(copper, 'g', 's', 'c') end

-- Same, with WoW's gold/silver/copper coin icons in place of the letters (for in-game text).
local function coin(name) return '|TInterface\\MoneyFrame\\UI-' .. name .. 'Icon:0:0:2:0|t' end
local GOLD, SILVER, COPPER = coin('Gold'), coin('Silver'), coin('Copper')
function Format.MoneyIcons(copper) return money(copper, GOLD, SILVER, COPPER) end

-- How long ago something happened.
function Format.Ago(seconds)
  if seconds == nil then return 'never' end
  if seconds < 60 then return 'just now' end
  if seconds < 3600 then return math.floor(seconds / 60) .. ' min ago' end
  return math.floor(seconds / 3600) .. ' h ago'
end

-- Seconds as "mm:ss"; never negative.
function Format.Clock(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  return string.format('%02d:%02d', math.floor(seconds / 60), seconds % 60)
end
