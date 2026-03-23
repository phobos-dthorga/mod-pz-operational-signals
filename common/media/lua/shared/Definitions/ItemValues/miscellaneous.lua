---------------------------------------------------------------
-- Miscellaneous Item Value Overrides
-- Notable items that don't fit cleanly into other categories
-- but have distinct apocalypse value.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Rope & Binding ─────────────────────────────────────
        { id = "Base.Rope",              basePrice = 12.00, reason = "Versatile binding/climbing material" },

        -- ── Security ───────────────────────────────────────────
        { id = "Base.Padlock",           basePrice = 15.00, reason = "Base security — lock doors and gates" },
        { id = "Base.CombinationPadlock", basePrice = 18.00, reason = "Keyless lock — no key to lose" },

        -- ── Hollow Books (contraband) ──────────────────────────
        { id = "Base.HollowBook_Handgun",   basePrice = 35.00, reason = "Concealed pistol + book" },
        { id = "Base.HollowBook_Valuables", basePrice = 20.00, reason = "Hidden valuables stash" },
        { id = "Base.HollowBook_Whiskey",   basePrice = 15.00, reason = "Hidden whiskey stash — morale" },
        { id = "Base.HollowBook_Kids",      basePrice = 5.00,  reason = "Children's book — morale only" },
        { id = "Base.HollowBook_Prison",    basePrice = 8.00,  reason = "Prison literature" },
    },
}
