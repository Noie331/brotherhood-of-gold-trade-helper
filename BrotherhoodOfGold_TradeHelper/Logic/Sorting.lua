-- Row orders. Rows are { recipe = saved recipe, eval = Pricing.Evaluate result }. Pure Lua.
local _, ns = ...
local Sorting = {}
ns.Sorting = Sorting

Sorting.DIFF_RANK = { optimal = 1, medium = 2, easy = 3, trivial = 4 }

local function name(r) return r.recipe.name or '' end

-- Best skill-up chance first; inside each colour, mode 'ah' / 'vendor' puts that profit highest first (unknown last);
-- then cheapest net cost; then name. mode nil or 'cheapest': cheapest first.
function Sorting.ForLeveling(rows, mode)
  local rank = Sorting.DIFF_RANK
  local key = (mode == 'ah' and 'ahProfit') or (mode == 'vendor' and 'vendorProfit') or nil
  table.sort(rows, function(a, b)
    local ra, rb = rank[a.recipe.difficulty] or 5, rank[b.recipe.difficulty] or 5
    if ra ~= rb then return ra < rb end
    if key then
      local pa, pb = a.eval[key], b.eval[key]
      if pa ~= nil and pb == nil then return true end
      if pa == nil and pb ~= nil then return false end
      if pa ~= nil and pa ~= pb then return pa > pb end
    end
    local na, nb = a.eval.net or 0, b.eval.net or 0
    if na ~= nb then return na < nb end
    return name(a) < name(b)
  end)
  return rows
end

-- Highest profit first for mode 'ah' or 'vendor'; rows without that profit last; then name.
function Sorting.ForMoney(rows, mode)
  local key = mode == 'vendor' and 'vendorProfit' or 'ahProfit'
  table.sort(rows, function(a, b)
    local pa, pb = a.eval[key], b.eval[key]
    if pa ~= nil and pb == nil then return true end
    if pa == nil and pb ~= nil then return false end
    if pa ~= nil and pa ~= pb then return pa > pb end
    return name(a) < name(b)
  end)
  return rows
end
