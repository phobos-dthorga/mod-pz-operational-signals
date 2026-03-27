---------------------------------------------------------------
-- Medical Supply Item Value Overrides
-- Antibiotics, sutures, first aid supplies.
-- No hospitals in the apocalypse — these are irreplaceable.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Antibiotics ────────────────────────────────────────
        { id = "Base.Antibiotics",         basePrice = 100.00, reason = "Life-saving infection treatment — irreplaceable" },
        { id = "Base.AntibioticsBox",      basePrice = 80.00,  reason = "Antibiotic supply box" },

        -- ── Surgical Supplies ──────────────────────────────────
        { id = "Base.SutureNeedle",        basePrice = 50.00,  reason = "Wound closure — critical trauma care" },
        { id = "Base.SutureNeedleBox",     basePrice = 40.00,  reason = "Suture needle supply" },
        { id = "Base.SutureNeedleHolder",  basePrice = 45.00,  reason = "Surgical instrument" },
        { id = "Base.Scalpel",             basePrice = 35.00,  reason = "Surgical cutting tool" },

        -- ── First Aid Essentials ───────────────────────────────
        { id = "Base.AlcoholWipes",        basePrice = 25.00,  reason = "Wound sterilisation" },
        { id = "Base.Disinfectant",        basePrice = 30.00,  reason = "Wound/surface disinfection" },
        { id = "Base.Tweezers",            basePrice = 20.00,  reason = "Foreign body removal" },
        { id = "Base.Tweezers_Forged",     basePrice = 18.00,  reason = "Improvised tweezers" },

        -- ── Medical Supply Boxes ──────────────────────────────
        { id = "Base.BandageBox",             basePrice = 25.00 },
        { id = "Base.AdhesiveBandageBox",     basePrice = 20.00 },
        { id = "Base.ColdpackBox",            basePrice = 15.00 },
        { id = "Base.CottonBallsBox",         basePrice = 8.00 },
        { id = "Base.TongueDepressorBox",     basePrice = 5.00 },
        { id = "Base.PaperclipBox",           basePrice = 2.00 },
        { id = "Base.AdhesiveTapeBox",        basePrice = 10.00 },
    },
}
