---------------------------------------------------------------
-- Wholesaler voice pack — businesslike, numbers-oriented, dry.
-- Overrides "situation" section when a wholesaler archetype
-- sponsors a mission or contract.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_wholesaler_situations",
    description = "Wholesaler-voiced situation descriptions",
    entries = {
        { id = "ws_sit_01", text = "My {category} throughput for {zoneName} is down twelve percent this quarter. I need current numbers to adjust my distribution model.", weight = 10 },
        { id = "ws_sit_02", text = "I have a convoy scheduled for {zoneName} but the {category} demand projections are based on week-old data. Verify before I commit inventory.", weight = 10 },
        { id = "ws_sit_03", text = "The {category} margins in {zoneName} have compressed. Either supply increased or someone is undercutting. I need to know which.", weight = 8 },
        { id = "ws_sit_04", text = "Two of my {zoneName} accounts are requesting increased {category} allocations. Before I reroute stock, confirm the demand is real.", weight = 8 },
        { id = "ws_sit_05", text = "Standard inventory audit cycle for {zoneName}. {category} variance is within tolerance but trending upward. Refresh the dataset.", weight = 8 },
    },
}
