---------------------------------------------------------------
-- Common mission title text pool.
-- Tokens: {category}, {zoneName}, {difficulty}
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "titles_common",
    description = "Generic mission title fragments for all categories",
    entries = {
        { id = "title_recon_01",     text = "Field Recon: {zoneName}",                weight = 10 },
        { id = "title_recon_02",     text = "Intelligence Sweep: {category}",         weight = 10 },
        { id = "title_recon_03",     text = "Sector Survey: {zoneName}",              weight = 8 },
        { id = "title_supply_01",    text = "Supply Run: {category}",                 weight = 10 },
        { id = "title_supply_02",    text = "Procurement Order: {category}",          weight = 8 },
        { id = "title_delivery_01",  text = "Courier Assignment: {zoneName}",         weight = 10 },
        { id = "title_delivery_02",  text = "Package Transfer: {zoneName}",           weight = 8 },
        { id = "title_intercept_01", text = "Signal Intercept: Band {bandName}",      weight = 8 },
        { id = "title_intercept_02", text = "Frequency Monitor: {zoneName}",          weight = 8 },
        { id = "title_trade_01",     text = "Trade Operation: {category}",            weight = 10 },
        { id = "title_trade_02",     text = "Market Acquisition: {category}",         weight = 8 },
        { id = "title_generic_01",   text = "Operation {operationCode}",              weight = 6 },
        { id = "title_generic_02",   text = "Assignment #{operationCode}",            weight = 6 },
        { id = "title_urgent_01",    text = "URGENT: {category} — {zoneName}",        weight = 4, conditions = { minDifficulty = 4 } },
        { id = "title_urgent_02",    text = "PRIORITY: {zoneName} Sector",            weight = 4, conditions = { minDifficulty = 4 } },
        { id = "title_routine_01",   text = "Routine Check: {zoneName}",              weight = 6, conditions = { maxDifficulty = 2 } },
        { id = "title_routine_02",   text = "Standard Assignment: {category}",        weight = 6, conditions = { maxDifficulty = 2 } },
        { id = "title_critical_01",  text = "CRITICAL: {category} Emergency",         weight = 3, conditions = { minDifficulty = 5 } },
        { id = "title_targeted_01",  text = "Targeted Recon: {targetName}",           weight = 8 },
        { id = "title_targeted_02",  text = "Site Investigation: {targetName}",       weight = 8 },
    },
}
