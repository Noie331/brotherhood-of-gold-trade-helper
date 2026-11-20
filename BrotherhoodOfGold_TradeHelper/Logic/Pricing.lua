-- Material cost, sale returns and profit for one recipe. Pure Lua: no WoW API.
-- ctx = { ahPrice=fn(id), vendorPrice=fn(id), sellPrice=fn(id), isBoP=fn(id) }, prices in copper.
local _, ns = ...
local Pricing = {}
ns.Pricing = Pricing

-- Cheapest place to buy one of an item. A tie goes to the vendor.
function Pricing.UnitCost(itemID, ctx)
  local ah, vendor = ctx.ahPrice(itemID), ctx.vendorPrice(itemID)
  if ah and vendor then
    if vendor <= ah then return vendor, 'vendor' end
    return ah, 'ah'
  end
  if vendor then return vendor, 'vendor' end
  if ah then return ah, 'ah' end
  return nil, nil
end

function Pricing.Evaluate(recipe, ctx)
  local cost, partial = 0, false
  for _, r in ipairs(recipe.reagents or {}) do
    local unit = Pricing.UnitCost(r.itemID, ctx)
    if unit then cost = cost + unit * r.qty else partial = true end
  end

  local out, qty = recipe.outputItemID, recipe.outputQty or 1
  local ahValue, vendorValue
  if out then
    local ah = ctx.ahPrice(out)
    if ah and not ctx.isBoP(out) then ahValue = math.floor(ah * qty) end
    local sell = ctx.sellPrice(out)
    if sell then vendorValue = math.floor(sell * qty) end
  end

  -- Best place to sell the result; a tie goes to the vendor (instant, no AH cut).
  local best, bestSource
  if ahValue and (not vendorValue or ahValue > vendorValue) then best, bestSource = ahValue, 'ah'
  elseif vendorValue then best, bestSource = vendorValue, 'vendor' end

  local e = { cost = cost, partial = partial, ahValue = ahValue, vendorValue = vendorValue,
    net = cost - (best or 0), bestSource = bestSource }
  if not partial then
    if ahValue then e.ahProfit = ahValue - cost end
    if vendorValue then e.vendorProfit = vendorValue - cost end
  end
  return e
end
