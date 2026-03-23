---------------------------------------------------------------
-- Firearms Item Value Overrides
-- Priced by combat effectiveness, ammunition availability,
-- and rarity. Assault rifles command highest premiums;
-- pistols are the baseline sidearm.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Assault/Battle Rifles ──────────────────────────────
        { id = "Base.AssaultRifle",       basePrice = 200.00, reason = "Full-auto military rifle — top tier" },
        { id = "Base.AssaultRifle2",      basePrice = 180.00, reason = "Assault rifle variant" },
        { id = "Base.MSR7T_Rifle",        basePrice = 170.00, reason = "Precision semi-auto rifle" },

        -- ── Hunting/Bolt Rifles ────────────────────────────────
        { id = "Base.HuntingRifle",       basePrice = 140.00, reason = "Reliable hunting rifle — common calibre" },
        { id = "Base.VarmintRifle",       basePrice = 120.00, reason = "Light varmint rifle" },
        { id = "Base.JS14_Rifle",         basePrice = 130.00, reason = "Lever-action rifle" },
        { id = "Base.L94_Rifle",          basePrice = 130.00, reason = "Lever-action rifle" },

        -- ── Shotguns ───────────────────────────────────────────
        { id = "Base.Shotgun",            basePrice = 120.00, reason = "Pump-action shotgun — versatile" },
        { id = "Base.DoubleBarrelShotgun", basePrice = 100.00, reason = "Double-barrel — reliable but slow" },
        { id = "Base.JS3T_Shotgun",       basePrice = 110.00, reason = "Tactical shotgun variant" },
        { id = "Base.ShotgunSawnoff",     basePrice = 90.00,  reason = "Sawn-off — close range only" },
        { id = "Base.DoubleBarrelShotgunSawnoff", basePrice = 80.00, reason = "Sawn-off double — last resort" },

        -- ── Pistols ────────────────────────────────────────────
        { id = "Base.Pistol",             basePrice = 70.00,  reason = "Standard semi-auto pistol" },
        { id = "Base.Pistol2",            basePrice = 65.00,  reason = "Compact pistol" },
        { id = "Base.Pistol3",            basePrice = 75.00,  reason = "Full-size pistol" },

        -- ── Revolvers ──────────────────────────────────────────
        { id = "Base.Revolver",           basePrice = 60.00,  reason = "Standard revolver" },
        { id = "Base.Revolver_Long",      basePrice = 65.00,  reason = "Long-barrel revolver — better accuracy" },
        { id = "Base.Revolver_Short",     basePrice = 50.00,  reason = "Snub-nose — concealment weapon" },
    },
}
