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
    },
}
