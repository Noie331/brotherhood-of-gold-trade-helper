-- Full auction house scan: one ReplicateItems request, rows read in chunks so the game keeps running.
-- Prices are only replaced when a scan completes; closing the AH mid-scan keeps the old ones.
local _, ns = ...
local Auction = {}
ns.Auction = Auction

local open, scanning, reading = false, false, false
local acc, qty, startedAt, total, done = nil, nil, nil, 0, 0

local function realmData()
  local realm = GetRealmName()
  ns.db.ah[realm] = ns.db.ah[realm] or { prices = {} }
  return ns.db.ah[realm]
end
Auction.RealmData = realmData

-- Starts (or reports) loading item data for everything in the last scan. `loud` only right after a
-- new scan. Returns showLoading, loaded, total.
function Auction.PreloadPrices(loud)
  local data = realmData()
  local ids = {}
  for id in pairs(data.prices or {}) do ids[#ids + 1] = id end
  return ns.Items.PreloadFor(data.scannedAt or 0, ids, loud)
end

function Auction.IsOpen() return open end
function Auction.IsScanning() return scanning end
function Auction.Progress() return total > 0 and (done * 100 / total) or 0 end
function Auction.CooldownLeft() return ns.Scan.CooldownLeft(realmData().scanStartedAt, time()) end

local function status() if ns.RefreshStatus then ns.RefreshStatus() end end

local function stop(msg)
  scanning, reading, acc, qty = false, false, nil, nil
  if msg then print('|cffe8c66aTrade Helper:|r ' .. msg) end
  status()
end

function Auction.Start()
  local ok = ns.Scan.ButtonState(open, Auction.CooldownLeft(), scanning)
  if not ok then return end
  if not (C_AuctionHouse and C_AuctionHouse.ReplicateItems) then
    stop('This client has no full AH scan (ReplicateItems).')
    return
  end
  acc, qty, startedAt, total, done, scanning, reading = {}, {}, time(), 0, 0, true, false
  realmData().scanStartedAt = startedAt -- the 15-minute wait starts from the request
  C_AuctionHouse.ReplicateItems()
  status()
end

local function step(from)
  if not scanning then return end
  local last = math.min(total - 1, from + ns.Scan.CHUNK - 1)
  for i = from, last do
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
    ns.Scan.AddRow(acc, itemID, count, buyout, qty)
  end
  done = last + 1
  if done >= total then
    ns.Scan.Finish(realmData(), acc, startedAt, time(), qty)
    scanning, reading, acc, qty = false, false, nil, nil
    print('|cffe8c66aTrade Helper:|r AH scan done, ' .. total .. ' auctions read.')
    Auction.PreloadPrices(true) -- load item prices for the AH Sell tab, with a loading message
    if ns.Refresh then ns.Refresh() end
  else
    status()
    C_Timer.After(0, function() step(done) end)
  end
end

local f = CreateFrame('Frame')
f:RegisterEvent('AUCTION_HOUSE_SHOW')
f:RegisterEvent('AUCTION_HOUSE_CLOSED')
pcall(f.RegisterEvent, f, 'REPLICATE_ITEM_LIST_UPDATE')
f:SetScript('OnEvent', function(_, event)
  if event == 'AUCTION_HOUSE_SHOW' then
    open = true; status()
  elseif event == 'AUCTION_HOUSE_CLOSED' then
    open = false
    if scanning then stop('AH closed before the scan finished; kept the old prices.') else status() end
  elseif event == 'REPLICATE_ITEM_LIST_UPDATE' and scanning and not reading then
    total = C_AuctionHouse.GetNumReplicateItems() or 0
    if total == 0 then stop('The AH sent no auctions; kept the old prices.'); return end
    reading = true
    step(0)
  end
end)
