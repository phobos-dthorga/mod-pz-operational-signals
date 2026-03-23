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
        -- Recovery missions
        { id = "title_salvage_01",   text = "Salvage Op: {zoneName}",                weight = 8, conditions = { category = "recovery" } },
        { id = "title_salvage_02",   text = "Cache Recovery: {targetName}",           weight = 8, conditions = { category = "recovery" } },
        { id = "title_salvage_03",   text = "Asset Recovery: {zoneName} Sector",      weight = 6, conditions = { category = "recovery" } },
        -- Survey missions
        { id = "title_survey_01",    text = "Infrastructure Survey: {targetName}",    weight = 8, conditions = { category = "survey" } },
        { id = "title_survey_02",    text = "Facility Assessment: {zoneName}",        weight = 8, conditions = { category = "survey" } },
        -- Night operations
        { id = "title_night_01",     text = "NIGHT OPS: {zoneName} Sector",           weight = 6, conditions = { minDifficulty = 3 } },
        { id = "title_night_02",     text = "Covert Sweep: {zoneName}",               weight = 6, conditions = { minDifficulty = 3 } },
        -- Bulk/arbitrage
        { id = "title_bulk_01",      text = "Bulk Procurement: {category}",            weight = 6, conditions = { category = "trade" } },
        { id = "title_arb_01",       text = "Price Arbitrage: {category} — {zoneName}", weight = 6, conditions = { category = "trade" } },
    },
}
