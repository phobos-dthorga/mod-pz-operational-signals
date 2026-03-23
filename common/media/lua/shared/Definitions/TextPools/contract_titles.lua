---------------------------------------------------------------
-- Contract title text pools — all contract kinds.
-- Tokens: {category}, {zoneName}, {quantity}, {targetName}
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "contract_titles_procurement",
    description = "Procurement contract titles",
    entries = {
        { id = "ct_proc_01", text = "Supply Request: {category} — {zoneName}", weight = 10 },
        { id = "ct_proc_02", text = "Procurement: {quantity}x {targetName}", weight = 10 },
        { id = "ct_proc_03", text = "Resupply Needed: {zoneName} Sector", weight = 8 },
        { id = "ct_proc_04", text = "Inventory Shortfall: {category}", weight = 8 },
        { id = "ct_proc_05", text = "Standing Request: {category} Supplies", weight = 6 },
    },
}
