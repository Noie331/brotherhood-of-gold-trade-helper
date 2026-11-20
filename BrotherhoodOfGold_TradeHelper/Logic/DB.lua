-- Saved data shape and defaults. Pure Lua: no WoW API.
-- BoG_DB (account):  { version, ah = { [realm] = { scanStartedAt, scannedAt, prices = { [itemID] = copper } } },
--                      vendor = { [itemID] = copper }, ui = { moneySort = 'ah'|'vendor', point = {...} } }
-- BoG_CharDB (char): { version, professions = { [name] = { name, rank, maxRank, savedAt, recipes = { [id] = recipe } } } }
local _, ns = ...
local DB = {}
ns.DB = DB

local function fill(t, defaults)
  for k, v in pairs(defaults) do
    if t[k] == nil then
      if type(v) == 'table' then t[k] = fill({}, v) else t[k] = v end
    elseif type(v) == 'table' and type(t[k]) == 'table' then
      fill(t[k], v)
    end
  end
  return t
end

function DB.Init(saved, charSaved)
  local db = fill(type(saved) == 'table' and saved or {},
    { version = 1, ah = {}, vendor = {}, ui = { moneySort = 'ah' } })
  local char = fill(type(charSaved) == 'table' and charSaved or {}, { version = 1, professions = {} })
  return db, char
end

-- A price seen at a vendor wins over the built-in starting list.
function DB.VendorPrice(db, itemID)
  local seen = db.vendor[itemID]
  if seen ~= nil then return seen end
  return ns.VendorSeed and ns.VendorSeed[itemID] or nil
end
