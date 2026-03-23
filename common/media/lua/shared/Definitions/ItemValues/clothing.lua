---------------------------------------------------------------
-- Clothing/Protective Gear Item Value Overrides
-- Military and protective gear commands a premium due to
-- combat protection. Standard civilian clothing uses the
-- fallback weight-based formula.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Bullet-Resistant Vests ─────────────────────────────
        { id = "Base.Vest_BulletArmy",       basePrice = 80.00, reason = "Military ballistic vest" },
        { id = "Base.Vest_BulletCivilian",   basePrice = 60.00, reason = "Civilian ballistic vest" },
        { id = "Base.Vest_BulletDesert",     basePrice = 75.00, reason = "Desert camo ballistic vest" },
        { id = "Base.Vest_BulletDesertNew",  basePrice = 80.00, reason = "New-issue desert ballistic vest" },
        { id = "Base.Vest_BulletOliveDrab",  basePrice = 75.00, reason = "OD green ballistic vest" },
        { id = "Base.Vest_BulletPolice",     basePrice = 65.00, reason = "Police ballistic vest" },
        { id = "Base.Vest_BulletSWAT",       basePrice = 85.00, reason = "SWAT tactical ballistic vest" },

        -- ── Gas Masks ──────────────────────────────────────────
        { id = "Base.Hat_GasMask",           basePrice = 40.00, reason = "Full gas mask with filter" },
        { id = "Base.Hat_GasMask_nofilter",  basePrice = 15.00, reason = "Gas mask body — needs filter" },
        { id = "Base.Hat_ImprovisedGasMask", basePrice = 20.00, reason = "Improvised gas mask with filter" },
        { id = "Base.Hat_ImprovisedGasMask_nofilter", basePrice = 8.00, reason = "Improvised gas mask — needs filter" },
    },
}
