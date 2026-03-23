---------------------------------------------------------------
-- Item Value Override Template
--
-- Add this file to Definitions/ItemValues/ in your addon mod,
-- then register entries at runtime:
--
--   if POS_ItemValueRegistry then
--       POS_ItemValueRegistry.registerOverrides({
--           { id = "MyMod.RareMedicine", basePrice = 120.00,
--             reason = "Custom rare medical supply" },
--       })
--   end
--
-- Or use the data-pack approach: place a .lua file here that
-- returns the table below, and add its require-path to the
-- BUILTIN_PATHS in POS_ItemValueRegistry.lua.
--
-- Fields:
--   id        (string, required) PZ fullType e.g. "Base.Axe"
--   basePrice (number, required) Absolute base price in dollars
--   isLuxury  (boolean, default false) Zone-scaled luxury item
--   reason    (string, default "") Documentation / audit trail
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- { id = "Base.ExampleItem", basePrice = 10.00, reason = "Example" },
    },
}
