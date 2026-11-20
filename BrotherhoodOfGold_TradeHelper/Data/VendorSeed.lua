-- Starting vendor prices (copper, before reputation discounts) for common vendor-sold materials,
-- so costs show before any vendor visit. Classic-era base prices from memory; NOT checked against
-- Wowhead (its prices load by script and could not be read). Any vendor visit overwrites the price.
local _, ns = ...

ns.VendorSeed = {
  [2320] = 10,     -- Coarse Thread
  [2321] = 100,    -- Fine Thread
  [4291] = 500,    -- Silken Thread
  [8343] = 2000,   -- Heavy Silken Thread
  [14341] = 5000,  -- Rune Thread
  [3371] = 20,     -- Empty Vial
  [3372] = 200,    -- Leaded Vial
  [8925] = 2000,   -- Crystal Vial
  [2880] = 100,    -- Weak Flux
  [3466] = 2000,   -- Strong Flux
  [2324] = 25,     -- Bleach
  [2604] = 50,     -- Red Dye
  [6260] = 50,     -- Blue Dye
  [4340] = 350,    -- Gray Dye
  [2678] = 10,     -- Mild Spices
  [159] = 25,      -- Refreshing Spring Water
  [4289] = 50,     -- Salt
}
