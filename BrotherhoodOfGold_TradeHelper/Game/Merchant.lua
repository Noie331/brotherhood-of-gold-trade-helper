-- Records what vendors charge (per item, with your reputation discount) for unlimited-stock items.
local _, ns = ...

local function itemInfo(i)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(i)
    if not info then return nil end
    return info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
  end
  local _, _, price, quantity, numAvailable, _, _, extendedCost = GetMerchantItemInfo(i)
  return price, quantity, numAvailable, extendedCost
end


local function record()
  if not ns.db then return end
  for i = 1, GetMerchantNumItems() do
    local id = GetMerchantItemID(i)
    local price, stack, available, extended = itemInfo(i)
    if id and price and price > 0 and stack and stack >= 1 and available == -1 and not extended then
      ns.db.vendor[id] = math.floor(price / stack)
    end
  end
  if ns.Refresh then ns.Refresh() end
end

local f = CreateFrame('Frame')
f:RegisterEvent('MERCHANT_SHOW')
f:RegisterEvent('MERCHANT_UPDATE')
f:SetScript('OnEvent', function() ns.Throttle('merchant', 0.5, record) end)
