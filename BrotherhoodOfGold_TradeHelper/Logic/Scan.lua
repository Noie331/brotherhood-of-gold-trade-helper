-- Full AH scan: reducing rows to lowest unit prices, cooldown and button text. Pure Lua.
local _, ns = ...
local Scan = {}
ns.Scan = Scan

Scan.COOLDOWN = 900 -- seconds between full scans
Scan.CHUNK = 2000   -- rows handled per frame

-- Keep the lowest per-unit buyout seen for each item. Bid-only and empty rows are ignored.
-- qty (optional) counts the units listed at that lowest price.
function Scan.AddRow(acc, itemID, count, buyout, qty)
  if not itemID or not buyout or buyout <= 0 or not count or count < 1 then return end
  local unit = math.floor(buyout / count)
  local old = acc[itemID]
  if old == nil or unit < old then
    acc[itemID] = unit
    if qty then qty[itemID] = count end
  elseif unit == old and qty then
    qty[itemID] = (qty[itemID] or 0) + count
  end
end

function Scan.CooldownLeft(startedAt, now)
  if not startedAt then return 0 end
  return math.max(0, Scan.COOLDOWN - (now - startedAt))
end

function Scan.ButtonState(ahOpen, left, scanning, pct)
  if scanning then return false, 'Scanning... ' .. math.floor(pct or 0) .. '%' end
  if not ahOpen then return false, 'Open the AH to scan' end
  if left and left > 0 then return false, 'Scan AH (' .. ns.Format.Clock(left) .. ')' end
  return true, 'Scan AH'
end

-- Called only when a scan completed: the new prices replace the old set entirely.
function Scan.Finish(realmData, acc, startedAt, now, qty)
  realmData.prices = acc
  realmData.qty = qty or {}
  realmData.scanStartedAt = startedAt
  realmData.scannedAt = now
  return realmData
end
