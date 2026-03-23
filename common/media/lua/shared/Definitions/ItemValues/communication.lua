---------------------------------------------------------------
-- Communication Equipment Item Value Overrides
-- Radios priced by TransmitRange (signal strength).
-- Military-grade ham radios are the most valuable; makeshift
-- walkie-talkies are entry-level.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Ham Radios (base station) ──────────────────────────
        { id = "Base.HamRadio2",          basePrice = 150.00, reason = "Military ham radio — 20,000 range, 100% signal" },
        { id = "Base.HamRadio1",          basePrice = 100.00, reason = "Civilian ham radio — 7,500 range, 56% signal" },
        { id = "Base.HamRadioMakeShift",  basePrice = 70.00,  reason = "Improvised ham radio — 6,000 range, 36% signal" },

        -- ── Man-Pack Radio ─────────────────────────────────────
        { id = "Base.ManPackRadio",       basePrice = 140.00, reason = "Military man-pack — 20,000 range, portable" },

        -- ── Walkie-Talkies (portable) ──────────────────────────
        { id = "Base.WalkieTalkie5",      basePrice = 70.00,  reason = "Military walkie — 16,000 range, 100% signal" },
        { id = "Base.WalkieTalkie4",      basePrice = 45.00,  reason = "Tactical walkie — 8,000 range, 64% signal" },
        { id = "Base.WalkieTalkie3",      basePrice = 30.00,  reason = "Mid-range walkie — 4,000 range, 16% signal" },
        { id = "Base.WalkieTalkie2",      basePrice = 18.00,  reason = "Civilian walkie — 2,000 range, 4% signal" },
        { id = "Base.WalkieTalkie1",      basePrice = 10.00,  reason = "Toy-grade walkie — 750 range, 0.6% signal" },
        { id = "Base.WalkieTalkieMakeShift", basePrice = 12.00, reason = "Improvised walkie — 1,000 range, 1% signal" },
    },
}
