---------------------------------------------------------------
-- Contract situation text pools — apocalypse-flavoured.
-- These are desperate pleas, not corporate memos.
-- Tokens: {category}, {zoneName}, {quantity}, {targetName},
--         {deadlineDay}, {sponsorName}
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "contract_situations_procurement",
    description = "Standard procurement situations",
    entries = {
        { id = "cs_proc_01", text = "The {zoneName} settlement is running low on {category}. Their last supply run came back empty and they are asking the network for help before things get worse.", weight = 10 },
        { id = "cs_proc_02", text = "A contact in {zoneName} has put out word that they need {category} supplies. Nothing urgent yet, but the shelves are getting bare and winter is coming.", weight = 10 },
        { id = "cs_proc_03", text = "Traders passing through {zoneName} report that {category} stock is dwindling. Someone with inventory to spare could make a fair deal here.", weight = 8 },
        { id = "cs_proc_04", text = "The {zoneName} outpost has been burning through {category} faster than expected. They are looking for a reliable supplier before rationing kicks in.", weight = 8 },
        { id = "cs_proc_05", text = "Word came through the relay that {zoneName} needs {category}. Not desperate yet, but the smart move is to act before everyone else hears about it.", weight = 6 },
    },
}
