---------------------------------------------------------------
-- Literature Item Value Overrides
-- Skill books are incredibly valuable — knowledge is survival.
-- Entertainment books provide morale but little practical use.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    entries = {
        -- ── Skill Books (highest value) ────────────────────────
        -- Each skill book represents irreplaceable training that
        -- could take months to acquire through practice alone.
        { id = "Base.BookCarpentry1",     basePrice = 35.00, reason = "Carpentry skill book — beginner" },
        { id = "Base.BookCarpentry2",     basePrice = 40.00, reason = "Carpentry skill book — intermediate" },
        { id = "Base.BookCarpentry3",     basePrice = 45.00, reason = "Carpentry skill book — advanced" },
        { id = "Base.BookCarpentry4",     basePrice = 50.00, reason = "Carpentry skill book — expert" },
        { id = "Base.BookCarpentry5",     basePrice = 55.00, reason = "Carpentry skill book — master" },
        { id = "Base.BookCooking1",       basePrice = 35.00, reason = "Cooking skill book — beginner" },
        { id = "Base.BookCooking2",       basePrice = 40.00, reason = "Cooking skill book — intermediate" },
        { id = "Base.BookCooking3",       basePrice = 45.00, reason = "Cooking skill book — advanced" },
        { id = "Base.BookCooking4",       basePrice = 50.00, reason = "Cooking skill book — expert" },
        { id = "Base.BookCooking5",       basePrice = 55.00, reason = "Cooking skill book — master" },
        { id = "Base.BookElectrician1",   basePrice = 40.00, reason = "Electrical skill book — beginner" },
        { id = "Base.BookElectrician2",   basePrice = 45.00, reason = "Electrical skill book — intermediate" },
        { id = "Base.BookElectrician3",   basePrice = 50.00, reason = "Electrical skill book — advanced" },
        { id = "Base.BookElectrician4",   basePrice = 55.00, reason = "Electrical skill book — expert" },
        { id = "Base.BookElectrician5",   basePrice = 60.00, reason = "Electrical skill book — master" },
        { id = "Base.BookFarming1",       basePrice = 40.00, reason = "Farming skill book — beginner" },
        { id = "Base.BookFarming2",       basePrice = 45.00, reason = "Farming skill book — intermediate" },
        { id = "Base.BookFarming3",       basePrice = 50.00, reason = "Farming skill book — advanced" },
        { id = "Base.BookFarming4",       basePrice = 55.00, reason = "Farming skill book — expert" },
        { id = "Base.BookFarming5",       basePrice = 60.00, reason = "Farming skill book — master" },
        { id = "Base.BookFirstAid1",      basePrice = 45.00, reason = "First Aid skill book — beginner" },
        { id = "Base.BookFirstAid2",      basePrice = 50.00, reason = "First Aid skill book — intermediate" },
        { id = "Base.BookFirstAid3",      basePrice = 55.00, reason = "First Aid skill book — advanced" },
        { id = "Base.BookFirstAid4",      basePrice = 60.00, reason = "First Aid skill book — expert" },
        { id = "Base.BookFirstAid5",      basePrice = 65.00, reason = "First Aid skill book — master (most valuable)" },
        { id = "Base.BookFishing1",       basePrice = 35.00, reason = "Fishing skill book — beginner" },
        { id = "Base.BookFishing2",       basePrice = 40.00, reason = "Fishing skill book — intermediate" },
        { id = "Base.BookFishing3",       basePrice = 45.00, reason = "Fishing skill book — advanced" },
        { id = "Base.BookFishing4",       basePrice = 50.00, reason = "Fishing skill book — expert" },
        { id = "Base.BookFishing5",       basePrice = 55.00, reason = "Fishing skill book — master" },
        { id = "Base.BookForaging1",      basePrice = 35.00, reason = "Foraging skill book — beginner" },
        { id = "Base.BookForaging2",      basePrice = 40.00, reason = "Foraging skill book — intermediate" },
        { id = "Base.BookForaging3",      basePrice = 45.00, reason = "Foraging skill book — advanced" },
        { id = "Base.BookForaging4",      basePrice = 50.00, reason = "Foraging skill book — expert" },
        { id = "Base.BookForaging5",      basePrice = 55.00, reason = "Foraging skill book — master" },
        { id = "Base.BookMechanic1",      basePrice = 40.00, reason = "Mechanics skill book — beginner" },
        { id = "Base.BookMechanic2",      basePrice = 45.00, reason = "Mechanics skill book — intermediate" },
        { id = "Base.BookMechanic3",      basePrice = 50.00, reason = "Mechanics skill book — advanced" },
        { id = "Base.BookMechanic4",      basePrice = 55.00, reason = "Mechanics skill book — expert" },
        { id = "Base.BookMechanic5",      basePrice = 60.00, reason = "Mechanics skill book — master" },
        { id = "Base.BookMetalWelding1",  basePrice = 40.00, reason = "Metalworking skill book — beginner" },
        { id = "Base.BookMetalWelding2",  basePrice = 45.00, reason = "Metalworking skill book — intermediate" },
        { id = "Base.BookMetalWelding3",  basePrice = 50.00, reason = "Metalworking skill book — advanced" },
        { id = "Base.BookMetalWelding4",  basePrice = 55.00, reason = "Metalworking skill book — expert" },
        { id = "Base.BookMetalWelding5",  basePrice = 60.00, reason = "Metalworking skill book — master" },
        { id = "Base.BookTailoring1",     basePrice = 30.00, reason = "Tailoring skill book — beginner" },
        { id = "Base.BookTailoring2",     basePrice = 35.00, reason = "Tailoring skill book — intermediate" },
        { id = "Base.BookTailoring3",     basePrice = 40.00, reason = "Tailoring skill book — advanced" },
        { id = "Base.BookTailoring4",     basePrice = 45.00, reason = "Tailoring skill book — expert" },
        { id = "Base.BookTailoring5",     basePrice = 50.00, reason = "Tailoring skill book — master" },
        { id = "Base.BookTrapping1",      basePrice = 35.00, reason = "Trapping skill book — beginner" },
        { id = "Base.BookTrapping2",      basePrice = 40.00, reason = "Trapping skill book — intermediate" },
        { id = "Base.BookTrapping3",      basePrice = 45.00, reason = "Trapping skill book — advanced" },
        { id = "Base.BookTrapping4",      basePrice = 50.00, reason = "Trapping skill book — expert" },
        { id = "Base.BookTrapping5",      basePrice = 55.00, reason = "Trapping skill book — master" },

        -- ── Entertainment (low value — morale only) ────────────
        { id = "Base.ComicBook_Retail",   basePrice = 2.00,  reason = "Entertainment only — morale boost" },
    },
}
