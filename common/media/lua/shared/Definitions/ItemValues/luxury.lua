---------------------------------------------------------------
-- Luxury Item Value Overrides
-- Gold, jewelry, precious materials. All flagged isLuxury=true
-- so their final price is scaled by zone luxuryDemand:
--   Louisville (urban) = 2.5x, Muldraugh (rural) = 0.5x
-- Base prices are intentionally low — gold is near-worthless
-- without an urban trade economy to back it.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Gold ───────────────────────────────────────────────
        { id = "Base.GoldBar",       basePrice = 12.00, isLuxury = true, reason = "Pre-apocalypse wealth — heavy, near-worthless rurally" },
        { id = "Base.GoldScrap",     basePrice = 1.00,  isLuxury = true, reason = "Gold scrap — minimal barter value" },
        { id = "Base.GoldSheet",     basePrice = 2.00,  isLuxury = true, reason = "Gold sheet — craft material" },
        { id = "Base.GoldCoin",      basePrice = 1.50,  isLuxury = true, reason = "Gold coin — collectible barter token" },
        { id = "Base.GoldCup",       basePrice = 2.00,  isLuxury = true, reason = "Gold cup — ornamental" },

        -- ── High-End Jewelry ───────────────────────────────────
        { id = "Base.Necklace_GoldDiamond",   basePrice = 5.00, isLuxury = true, reason = "Gold + diamond necklace" },
        { id = "Base.Necklace_GoldRuby",      basePrice = 4.00, isLuxury = true, reason = "Gold + ruby necklace" },
        { id = "Base.Necklace_Gold",          basePrice = 3.00, isLuxury = true, reason = "Gold necklace" },
        { id = "Base.Necklace_SilverDiamond", basePrice = 3.50, isLuxury = true, reason = "Silver + diamond necklace" },
        { id = "Base.Necklace_SilverSapphire", basePrice = 3.00, isLuxury = true, reason = "Silver + sapphire necklace" },
        { id = "Base.Necklace_Pearl",         basePrice = 2.50, isLuxury = true, reason = "Pearl necklace" },
        { id = "Base.Necklace_Silver",        basePrice = 2.00, isLuxury = true, reason = "Silver necklace" },

        -- ── Diamond ────────────────────────────────────────────
        { id = "Base.Diamond",       basePrice = 8.00,  isLuxury = true, reason = "Gem — extremely high pre-apocalypse value, limited post-apocalypse use" },

        -- ── Earrings (selected high-value) ─────────────────────
        { id = "Base.Earring_Dangly_Diamond",  basePrice = 2.50, isLuxury = true, reason = "Diamond earring" },
        { id = "Base.Earring_Dangly_Ruby",     basePrice = 2.00, isLuxury = true, reason = "Ruby earring" },
        { id = "Base.Earring_Dangly_Sapphire", basePrice = 2.00, isLuxury = true, reason = "Sapphire earring" },
        { id = "Base.Earring_LoopLrg_Gold",   basePrice = 1.50, isLuxury = true, reason = "Large gold hoop earring" },
    },
}
