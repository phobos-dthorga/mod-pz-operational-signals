---------------------------------------------------------------
-- Food Item Value Overrides
-- Long-shelf-life preserved food commands a premium.
-- Canned goods are the post-apocalypse gold standard for
-- reliable, portable, shelf-stable nutrition.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Canned Goods (individual) ──────────────────────────
        { id = "Base.TinnedBeans",         basePrice = 8.00,  reason = "Canned beans — calorie-dense, long shelf life" },
        { id = "Base.TinnedSoup",          basePrice = 7.00,  reason = "Canned soup — nutrition variety" },
        { id = "Base.CannedBolognese",     basePrice = 9.00,  reason = "Canned bolognese — protein-rich" },
        { id = "Base.CannedChili",         basePrice = 9.00,  reason = "Canned chili — high calorie" },
        { id = "Base.CannedCorn",          basePrice = 7.00,  reason = "Canned corn — staple vegetable" },

        -- ── Canned Goods (bulk boxes) ──────────────────────────
        { id = "Base.TinnedBeans_Box",     basePrice = 22.00, reason = "Box of canned beans" },
        { id = "Base.TinnedSoup_Box",      basePrice = 20.00, reason = "Box of canned soup" },
        { id = "Base.CannedBolognese_Box", basePrice = 25.00, reason = "Box of canned bolognese" },
        { id = "Base.CannedChili_Box",     basePrice = 25.00, reason = "Box of canned chili" },
        { id = "Base.CannedCorn_Box",      basePrice = 20.00, reason = "Box of canned corn" },

        -- ── Canned Goods (bulk boxes — extended) ──────────────
        { id = "Base.WaterRationCan_Box",      basePrice = 25.00, subCategory = "canned_food" },
        { id = "Base.MysteryCan_Box",          basePrice = 12.00, subCategory = "canned_food" },
        { id = "Base.DentedCan_Box",           basePrice = 10.00, subCategory = "canned_food" },
        { id = "Base.CannedCarrots_Box",       basePrice = 20.00, subCategory = "canned_food" },
        { id = "Base.CannedCornedBeef_Box",    basePrice = 28.00, subCategory = "canned_food" },
        { id = "Base.CannedFruitCocktail_Box", basePrice = 22.00, subCategory = "canned_food" },
        { id = "Base.CannedMilk_Box",          basePrice = 18.00, subCategory = "canned_food" },
        { id = "Base.CannedMushroomSoup_Box",  basePrice = 20.00, subCategory = "canned_food" },
        { id = "Base.CannedPeaches_Box",       basePrice = 22.00, subCategory = "canned_food" },
        { id = "Base.CannedPeas_Box",          basePrice = 18.00, subCategory = "canned_food" },
        { id = "Base.CannedPineapple_Box",     basePrice = 22.00, subCategory = "canned_food" },
        { id = "Base.CannedPotato_Box",        basePrice = 18.00, subCategory = "canned_food" },
        { id = "Base.CannedSardines_Box",      basePrice = 24.00, subCategory = "canned_food" },
        { id = "Base.CannedTomato_Box",        basePrice = 18.00, subCategory = "canned_food" },
        { id = "Base.Dogfood_Box",             basePrice = 8.00,  subCategory = "canned_food" },
        { id = "Base.TunaTin_Box",             basePrice = 26.00, subCategory = "canned_food" },

        -- ── Boxed Beverages ───────────────────────────────────
        { id = "Base.CannedFruitBeverage_Box", basePrice = 16.00, subCategory = "beverages" },
        { id = "Base.WineWhite_Boxed",         basePrice = 15.00, subCategory = "beverages" },
        { id = "Base.WineRed_Boxed",           basePrice = 15.00, subCategory = "beverages" },
        { id = "Base.WineBox",                 basePrice = 12.00, subCategory = "beverages" },
        { id = "Base.JuiceBox",               basePrice = 3.00,  subCategory = "beverages" },
        { id = "Base.JuiceBoxApple",           basePrice = 3.00,  subCategory = "beverages" },
        { id = "Base.JuiceBoxFruitpunch",      basePrice = 3.00,  subCategory = "beverages" },
        { id = "Base.JuiceBoxOrange",          basePrice = 3.00,  subCategory = "beverages" },

        -- ── Boxed Dry Goods & Packs ───────────────────────────
        { id = "Base.Macandcheese_Box",        basePrice = 6.00,  subCategory = "dry_goods" },
        { id = "Base.BeerPack",               basePrice = 12.00, subCategory = "beverages" },
        { id = "Base.BeerCanPack",             basePrice = 10.00, subCategory = "beverages" },
    },
}
