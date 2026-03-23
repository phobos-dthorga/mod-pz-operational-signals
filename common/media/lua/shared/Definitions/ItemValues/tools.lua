---------------------------------------------------------------
-- Essential Tools Item Value Overrides
-- Axes, hammers, saws, welding equipment, crowbars, wrenches.
-- These enable construction, repair, and resource processing.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Axes ───────────────────────────────────────────────
        { id = "Base.Axe",               basePrice = 45.00, reason = "Full-size axe — wood processing essential" },
        { id = "Base.Axe_Old",           basePrice = 35.00, reason = "Worn axe — still functional" },
        { id = "Base.PickAxe",           basePrice = 40.00, reason = "Mining/demolition tool" },
        { id = "Base.PickAxeForged",     basePrice = 38.00, reason = "Hand-forged pickaxe" },

        -- ── Hammers ────────────────────────────────────────────
        { id = "Base.Hammer",            basePrice = 22.00, reason = "General-purpose hammer — construction" },
        { id = "Base.HammerForged",      basePrice = 20.00, reason = "Hand-forged hammer" },
        { id = "Base.HammerStone",       basePrice = 12.00, reason = "Primitive stone hammer" },

        -- ── Saws ───────────────────────────────────────────────
        { id = "Base.Saw",               basePrice = 28.00, reason = "Handsaw — lumber processing" },
        { id = "Base.SmallSaw",          basePrice = 20.00, reason = "Compact saw" },

        -- ── Welding/Fabrication ────────────────────────────────
        { id = "Base.BlowTorch",         basePrice = 55.00, reason = "Welding/soldering — enables metal fabrication" },
        { id = "Base.WeldingRods",       basePrice = 30.00, reason = "Consumable welding supply" },
        { id = "Base.WeldingMask",       basePrice = 35.00, reason = "Eye protection for welding" },

        -- ── Crowbars ───────────────────────────────────────────
        { id = "Base.Crowbar",           basePrice = 25.00, reason = "Prying tool — breaching/salvage" },
        { id = "Base.CrowbarForged",     basePrice = 23.00, reason = "Hand-forged crowbar" },

        -- ── Wrenches ───────────────────────────────────────────
        { id = "Base.Wrench",            basePrice = 20.00, reason = "General wrench — mechanical repair" },
        { id = "Base.PipeWrench",        basePrice = 22.00, reason = "Heavy-duty pipe wrench" },
        { id = "Base.LugWrench",         basePrice = 18.00, reason = "Vehicle tyre changes" },

        -- ── Screwdrivers ───────────────────────────────────────
        { id = "Base.Screwdriver",       basePrice = 15.00, reason = "Phillips/flat screwdriver" },
        { id = "Base.Screwdriver_Old",   basePrice = 12.00, reason = "Worn screwdriver" },
    },
}
