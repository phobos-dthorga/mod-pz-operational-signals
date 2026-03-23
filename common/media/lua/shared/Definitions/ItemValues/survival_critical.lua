---------------------------------------------------------------
-- Survival-Critical Item Value Overrides
-- Generators, car batteries, water purification, seeds.
-- These items are irreplaceable in an apocalypse and their
-- tiny weight would otherwise produce absurd base prices.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Generators ─────────────────────────────────────────
        -- The single most valuable tradeable item class.
        -- Only power source that doesn't degrade; enables 24/7 ops.
        { id = "Base.Generator",        basePrice = 500.00, reason = "Standard generator — irreplaceable power" },
        { id = "Base.Generator_Blue",   basePrice = 420.00, reason = "Portable generator variant" },
        { id = "Base.Generator_Old",    basePrice = 350.00, reason = "Degraded generator — still works" },
        { id = "Base.Generator_Yellow", basePrice = 500.00, reason = "Standard generator variant" },

        -- ── Car Batteries ──────────────────────────────────────
        -- Vehicle-critical; also used for portable power rigs.
        { id = "Base.CarBattery1",      basePrice = 90.00,  reason = "Entry-level car battery" },
        { id = "Base.CarBattery2",      basePrice = 110.00, reason = "Mid-tier car battery" },
        { id = "Base.CarBattery3",      basePrice = 130.00, reason = "Heavy-duty car battery" },
        { id = "Base.CarBatteryCharger", basePrice = 150.00, reason = "Keeps batteries alive — force multiplier" },

        -- ── Water Purification ─────────────────────────────────
        { id = "Base.WaterPurificationTablets", basePrice = 40.00, reason = "Clean water = survival" },
        { id = "Base.Bleach",           basePrice = 20.00, reason = "Dual-use: water purification + disinfection" },

        -- ── Seeds (staple crops) ───────────────────────────────
        -- Despite weighing 0.02 kg, each seed represents an
        -- entire future food supply chain. Priced by caloric
        -- and nutritional value of the resulting crop.
        { id = "Base.CornSeed",         basePrice = 22.00, reason = "Staple carbohydrate crop" },
        { id = "Base.PotatoSeed",       basePrice = 22.00, reason = "Calorie-dense staple" },
        { id = "Base.WheatSeed",        basePrice = 20.00, reason = "Bread/flour foundation" },
        { id = "Base.BarleySeed",       basePrice = 18.00, reason = "Grain crop, brewing use" },
        { id = "Base.RyeSeed",          basePrice = 18.00, reason = "Grain crop" },
        { id = "Base.SoybeansSeed",     basePrice = 20.00, reason = "High-protein crop" },
        { id = "Base.TomatoSeed",       basePrice = 18.00, reason = "Nutrition diversity" },
        { id = "Base.CabbageSeed",      basePrice = 16.00, reason = "Long shelf-life crop" },
        { id = "Base.CarrotSeed",       basePrice = 16.00, reason = "Root vegetable staple" },
        { id = "Base.OnionSeed",        basePrice = 16.00, reason = "Long-storage root crop" },
        { id = "Base.GarlicSeed",       basePrice = 16.00, reason = "Medicinal and nutritional" },
        { id = "Base.BroccoliSeed",     basePrice = 15.00, reason = "Nutrient-dense vegetable" },
        { id = "Base.CauliflowerSeed",  basePrice = 15.00, reason = "Nutrient-dense vegetable" },
        { id = "Base.SpinachSeed",      basePrice = 15.00, reason = "Iron-rich leafy green" },
        { id = "Base.KaleSeed",         basePrice = 15.00, reason = "Cold-hardy leafy green" },
        { id = "Base.LettuceSeed",      basePrice = 12.00, reason = "Fast-growing salad crop" },
        { id = "Base.CucumberSeed",     basePrice = 14.00, reason = "Hydration crop" },
        { id = "Base.PumpkinSeed",      basePrice = 16.00, reason = "Calorie-dense, long storage" },
        { id = "Base.WatermelonSeed",   basePrice = 14.00, reason = "Hydration crop" },
        { id = "Base.ZucchiniSeed",     basePrice = 14.00, reason = "Prolific producer" },
        { id = "Base.BellPepperSeed",   basePrice = 14.00, reason = "Nutrition diversity" },
        { id = "Base.GreenpeasSeed",    basePrice = 15.00, reason = "Protein-rich legume" },
        { id = "Base.SweetPotatoSeed",  basePrice = 18.00, reason = "Calorie-dense root crop" },
        { id = "Base.TurnipSeed",       basePrice = 14.00, reason = "Hardy root vegetable" },
        { id = "Base.RedRadishSeed",    basePrice = 12.00, reason = "Fast-growing root crop" },
        { id = "Base.StrewberrieSeed",  basePrice = 14.00, reason = "Morale-boosting fruit" },
        { id = "Base.SugarBeetSeed",    basePrice = 16.00, reason = "Sugar production" },
        { id = "Base.SunflowerSeeds",   basePrice = 14.00, reason = "Oil and food crop" },
        { id = "Base.LeekSeed",         basePrice = 14.00, reason = "Cold-hardy allium" },

        -- ── Seeds (herbs and specialty) ────────────────────────
        { id = "Base.BasilSeed",        basePrice = 10.00, reason = "Culinary herb" },
        { id = "Base.ChamomileSeed",    basePrice = 12.00, reason = "Medicinal tea herb" },
        { id = "Base.ChivesSeed",       basePrice = 10.00, reason = "Culinary herb" },
        { id = "Base.CilantroSeed",     basePrice = 10.00, reason = "Culinary herb" },
        { id = "Base.ComfreySeed",      basePrice = 14.00, reason = "Medicinal plant — poultice use" },
        { id = "Base.CommonMallowSeed", basePrice = 10.00, reason = "Medicinal herb" },
        { id = "Base.HempSeed",         basePrice = 18.00, reason = "Rope/fibre production" },
        { id = "Base.HopsSeed",         basePrice = 12.00, reason = "Brewing ingredient" },
        { id = "Base.LavenderSeed",     basePrice = 10.00, reason = "Medicinal/morale herb" },
        { id = "Base.LemonGrassSeed",   basePrice = 10.00, reason = "Culinary/medicinal herb" },
        { id = "Base.MarigoldSeed",     basePrice = 10.00, reason = "Companion planting/medicinal" },
        { id = "Base.MintSeed",         basePrice = 10.00, reason = "Medicinal tea herb" },
        { id = "Base.OreganoSeed",      basePrice = 10.00, reason = "Culinary herb" },
        { id = "Base.ParsleySeed",      basePrice = 10.00, reason = "Culinary herb" },
        { id = "Base.RosemarySeed",     basePrice = 10.00, reason = "Culinary/medicinal herb" },
        { id = "Base.RoseSeed",         basePrice = 8.00,  reason = "Ornamental — low survival value" },
        { id = "Base.SageSeed",         basePrice = 10.00, reason = "Culinary/medicinal herb" },
        { id = "Base.ThymeSeed",        basePrice = 10.00, reason = "Culinary herb" },
        { id = "Base.TobaccoSeed",      basePrice = 16.00, reason = "High trade/morale value" },
        { id = "Base.BlackSageSeed",    basePrice = 10.00, reason = "Medicinal herb" },
        { id = "Base.FlaxSeed",         basePrice = 14.00, reason = "Fibre and oil crop" },
        { id = "Base.HabaneroSeed",     basePrice = 12.00, reason = "Hot pepper — preservation use" },
        { id = "Base.JalapenoSeed",     basePrice = 12.00, reason = "Hot pepper — preservation use" },
        { id = "Base.PoppySeed",        basePrice = 12.00, reason = "Medicinal/culinary use" },
        { id = "Base.WildGarlicSeed",   basePrice = 12.00, reason = "Wild forage medicinal" },
    },
}
