-- Builds the flat line lists the window draws. Pure Lua.
-- Lines: { kind='recipe', recipeID, name, profession, difficulty, outputItemID, eval }
--        { kind='reagent', itemID, qty, ah, vendor, cheaper='ah'|'vendor'|nil }  (unit prices)
--        { kind='message', text }
local _, ns = ...
local View = {}
ns.View = View

View.MONEY_TAB = 'Money Maker'
local NO_RECIPES = { Fishing = true }
-- Skill lines with no recipes (Herbalism, Skinning, Fishing, Archaeology), matched by id so any language works.
View.NO_RECIPE_SKILL_LINES = { [182] = true, [393] = true, [356] = true, [794] = true }

-- Side tab drag: y offset (from the window's top edge, <= 0) that centres the 36 px tab on the cursor,
-- kept within the window's height.
View.TAB_SIZE = 36
function View.TabOffset(cursorY, windowTop, windowHeight)
  local y = -(windowTop - cursorY) + View.TAB_SIZE / 2
  return math.max(-(windowHeight - View.TAB_SIZE), math.min(0, y))
end

-- Net cost text for a profession-tab row: what the skill point costs after selling the result.
function View.NetLabel(e, fmt)
  fmt = fmt or ns.Format.Money
  local where = ''
  if e.bestSource == 'ah' then where = ' (AH)' elseif e.bestSource == 'vendor' then where = ' (vendor)' end
  if e.net < 0 then return 'profit +' .. fmt(-e.net) .. where end
  if e.net == 0 and not e.partial then return 'even' .. where end
  return 'loss ' .. (e.partial and '>= ' or '') .. fmt(e.net) .. where
end

-- Profit selling at one place (AH or vendor) after material cost: text, and sign (1, 0, -1; nil = no price there).
-- partial: some materials have no price, so the profit is at most this.
function View.SideProfit(value, cost, partial, fmt)
  fmt = fmt or ns.Format.Money
  if value == nil then return '-', nil end
  local p = value - cost
  local prefix = partial and '<= ' or ''
  if p > 0 then return prefix .. '+' .. fmt(p), 1 end
  if p < 0 then return prefix .. '-' .. fmt(-p), -1 end
  return partial and '<= even' or 'even', 0
end

-- Recipes that make no item (enchants): nothing to sell, so the craft is all cost.
View.NO_ITEM = 'Makes no item (enchant) - nothing to sell'
function View.NoItemNet(e, fmt)
  return View.SideProfit(0, e.cost, e.partial, fmt)
end

-- What to show when hovering a row: { itemID } (crafted item, material, AH Sell item) or { spellID } (the recipe).
function View.TooltipFor(line)
  if line.kind == 'recipe' then
    if line.outputItemID then return { itemID = line.outputItemID } end
    return line.recipeID and { spellID = line.recipeID } or nil
  end
  if line.kind == 'reagent' or line.kind == 'flip' then return line.itemID and { itemID = line.itemID } or nil end
  if line.kind == 'catalog' then return line.recipeID and { spellID = line.recipeID } or nil end
  return nil
end

function View.TabList(trainedNames, savedProfessions)
  local out, seen = {}, {}
  for _, n in ipairs(trainedNames or {}) do
    if not NO_RECIPES[n] and not seen[n] then out[#out + 1] = n; seen[n] = true end
  end
  local extra = {}
  for n in pairs(savedProfessions or {}) do
    if not NO_RECIPES[n] and not seen[n] then extra[#extra + 1] = n end
  end
  table.sort(extra)
  for _, n in ipairs(extra) do out[#out + 1] = n end
  out[#out + 1] = View.MONEY_TAB
  out[#out + 1] = View.FLIP_TAB
  out[#out + 1] = View.RECIPES_TAB
  return out
end

-- Recipes tab: every recipe of one profession, learned or not, by the skill needed to learn it.
View.RECIPES_TAB = 'Recipes'

function View.CatalogProfessions(professions)
  local out = {}
  for key, p in pairs(professions or {}) do
    if p.all then out[#out + 1] = key end
  end
  table.sort(out)
  return out
end

-- sourceOf(recipe): where it comes from (nil when unknown), and the skill needed to learn it.
-- Without sourceOf there is no source line.
View.NO_SOURCE = 'No source known'
-- query (optional): only recipes whose name or source contains it (plain text, any case).
function View.CatalogLines(profession, name, sourceOf, query)
  if not profession or not profession.all or next(profession.all) == nil then
    return { { kind = 'message', text = 'Open ' .. (name or 'a profession') .. ' once to load its recipe list.' } }
  end
  local rows, learned = {}, 0
  for _, r in pairs(profession.all) do
    local line = { kind = 'catalog' }
    for k, v in pairs(r) do line[k] = v end
    line.source, line.skill = nil, nil
    if sourceOf then
      line.source, line.skill = sourceOf(r)
      line.source = line.source or View.NO_SOURCE
    end
    rows[#rows + 1] = line
    if r.learned then learned = learned + 1 end
  end
  -- Skill needed to learn it, lowest first; the grey level when that is unknown; neither: last.
  table.sort(rows, function(a, b)
    local ga, gb = a.skill or a.grey or math.huge, b.skill or b.grey or math.huge
    if ga ~= gb then return ga < gb end
    if a.name ~= b.name then return (a.name or '') < (b.name or '') end
    return (a.recipeID or 0) < (b.recipeID or 0)
  end)
  local header = { kind = 'header', difficulty = 'medium', text = 'Learned ' .. learned .. ' of ' .. #rows }
  local lines = { header }
  local q = query and query:match('^%s*(.-)%s*$') or ''
  local needle = q:lower()
  for _, r in ipairs(rows) do
    if needle == '' or (r.name or ''):lower():find(needle, 1, true) or (r.source or ''):lower():find(needle, 1, true) then
      lines[#lines + 1] = r
    end
  end
  if needle ~= '' then
    header.text = header.text .. '  ·  ' .. (#lines - 1) .. ' match "' .. q .. '"'
    if #lines == 1 then lines[2] = { kind = 'message', text = 'No ' .. (name or '') .. ' recipes match "' .. q .. '".' } end
  end
  return lines
end

-- AH Sell: items whose lowest AH unit price is below what a vendor pays.
-- sellPrice(id) returns copper or nil while the item is still loading (those are skipped for now).
-- mode: 'each' (most profit per item first, the default) or 'total' (most profit buying them all first).
View.FLIP_TAB = 'AH Sell'
function View.FlipLines(prices, qty, sellPrice, mode)
  if not prices or next(prices) == nil then
    return { { kind = 'message', text = 'Scan the AH to find items to buy and sell to a vendor.' } }
  end
  qty = qty or {}
  local lines = {}
  for id, ah in pairs(prices) do
    local vendor = sellPrice(id)
    if vendor and vendor > ah then
      local n = qty[id] or 1
      lines[#lines + 1] = { kind = 'flip', itemID = id, ah = ah, vendor = vendor, profit = vendor - ah,
        qty = n, total = (vendor - ah) * n, cost = ah * n }
    end
  end
  if #lines == 0 then
    return { { kind = 'message', text = 'Nothing on the AH sells to a vendor for more than it costs right now.' } }
  end
  -- The chosen profit first, then the other one, then item id (stable order).
  local first, second = 'profit', 'total'
  if mode == 'total' then first, second = 'total', 'profit' end
  table.sort(lines, function(a, b)
    if a[first] ~= b[first] then return a[first] > b[first] end
    if a[second] ~= b[second] then return a[second] > b[second] end
    return a.itemID < b.itemID
  end)
  return lines
end

local function rowsOf(profession, profName, ctx, rows)
  for _, recipe in pairs(profession.recipes or {}) do
    rows[#rows + 1] = { recipe = recipe, profession = profName, eval = ns.Pricing.Evaluate(recipe, ctx) }
  end
end

View.GROUP_TEXT = {
  optimal = 'Orange - always a skill point',
  medium = 'Yellow - likely a skill point',
  easy = 'Green - sometimes a skill point',
  trivial = 'Grey - no skill points',
}

-- withHeaders: a { kind='header' } line before each skill-up colour group (rows already sorted by colour).
local function emit(rows, ctx, withHeaders)
  local lines, group = {}, nil
  for _, row in ipairs(rows) do
    local r = row.recipe
    if withHeaders and r.difficulty ~= group then
      group = r.difficulty
      lines[#lines + 1] = { kind = 'header', difficulty = group, text = View.GROUP_TEXT[group] or View.GROUP_TEXT.trivial }
    end
    lines[#lines + 1] = { kind = 'recipe', recipeID = r.recipeID, name = r.name, profession = row.profession,
      difficulty = r.difficulty, outputItemID = r.outputItemID, icon = r.icon, eval = row.eval }
    for _, g in ipairs(r.reagents or {}) do
      local _, cheaper = ns.Pricing.UnitCost(g.itemID, ctx)
      lines[#lines + 1] = { kind = 'reagent', itemID = g.itemID, qty = g.qty,
        ah = ctx.ahPrice(g.itemID), vendor = ctx.vendorPrice(g.itemID), cheaper = cheaper }
    end
  end
  return lines
end

function View.ProfessionLines(profession, name, ctx, mode)
  local rows = {}
  if profession then rowsOf(profession, profession.name or name, ctx, rows) end
  if #rows == 0 then return { { kind = 'message', text = 'Open ' .. name .. ' once to load its recipes.' } } end
  return emit(ns.Sorting.ForLeveling(rows, mode), ctx, true)
end

-- Professions to tick on Money Maker: the saved ones that have recipes, A-Z.
function View.MoneyProfessions(professions)
  local out = {}
  for key, p in pairs(professions or {}) do
    if p.recipes and next(p.recipes) ~= nil then out[#out + 1] = p.name or key end
  end
  table.sort(out)
  return out
end

-- hidden (optional): { [profession name] = true } for professions unticked on Money Maker.
function View.MoneyLines(professions, ctx, mode, hidden)
  local rows, any = {}, false
  for key, p in pairs(professions or {}) do
    local name = p.name or key
    if p.recipes and next(p.recipes) ~= nil then any = true end
    if not (hidden and hidden[name]) then rowsOf(p, name, ctx, rows) end
  end
  if #rows == 0 and any and hidden and next(hidden) ~= nil then
    return { { kind = 'message', text = 'Every profession is unticked. Tick one above to see its recipes.' } }
  end
  if #rows == 0 then return { { kind = 'message', text = 'No recipes saved yet. Open your professions once.' } } end
  return emit(ns.Sorting.ForMoney(rows, mode), ctx)
end
