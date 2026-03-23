---------------------------------------------------------------
-- Ammunition Item Value Overrides
-- Individual rounds weigh almost nothing (0.02-0.06 kg) but
-- each represents irreplaceable defensive/hunting capability.
-- Bulk containers (boxes, cartons) priced proportionally.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Rifle Rounds (individual) ──────────────────────────
        { id = "Base.308Bullets",         basePrice = 12.00, reason = "Heavy rifle round — hunting/sniper" },
        { id = "Base.556Bullets",         basePrice = 10.00, reason = "Standard military rifle round" },
        { id = "Base.3030Bullets",        basePrice = 11.00, reason = "Lever-action rifle round" },

        -- ── Revolver/Magnum Rounds ─────────────────────────────
        { id = "Base.Bullets44",          basePrice = 10.00, reason = ".44 magnum round" },
        { id = "Base.Bullets44Box",       basePrice = 55.00, reason = ".44 magnum box" },
        { id = "Base.Bullets44Carton",    basePrice = 75.00, reason = ".44 magnum carton (bulk)" },
        { id = "Base.Bullets357",         basePrice = 9.00,  reason = ".357 revolver round" },
        { id = "Base.Bullets357Box",      basePrice = 50.00, reason = ".357 box" },
        { id = "Base.Bullets357Carton",   basePrice = 70.00, reason = ".357 carton (bulk)" },
        { id = "Base.Bullets38",          basePrice = 7.00,  reason = ".38 special round" },
        { id = "Base.Bullets38Box",       basePrice = 40.00, reason = ".38 box" },
        { id = "Base.Bullets38Carton",    basePrice = 55.00, reason = ".38 carton (bulk)" },

        -- ── Pistol Rounds ──────────────────────────────────────
        { id = "Base.Bullets9mm",         basePrice = 6.00,  reason = "9mm — most common pistol round" },
        { id = "Base.Bullets9mmBox",      basePrice = 35.00, reason = "9mm box" },
        { id = "Base.Bullets9mmCarton",   basePrice = 50.00, reason = "9mm carton (bulk)" },
        { id = "Base.Bullets45",          basePrice = 8.00,  reason = ".45 ACP — stopping power" },
        { id = "Base.Bullets45Box",       basePrice = 45.00, reason = ".45 box" },
        { id = "Base.Bullets45Carton",    basePrice = 65.00, reason = ".45 carton (bulk)" },

        -- ── Shotgun Shells ─────────────────────────────────────
        { id = "Base.ShotgunShells",      basePrice = 8.00,  reason = "12-gauge shell — versatile" },
        { id = "Base.ShotgunShellsBox",   basePrice = 45.00, reason = "Shotgun shell box" },
        { id = "Base.ShotgunShellsCarton", basePrice = 65.00, reason = "Shotgun shell carton (bulk)" },
    },
}
