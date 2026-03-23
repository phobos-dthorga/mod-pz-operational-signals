---------------------------------------------------------------
-- Common situation text pool.
-- Describes the background context for the mission.
-- Tokens: {zoneName}, {category}, {sponsorName}, {targetName},
--         {difficulty}, {playerName}
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "situations_common",
    description = "Generic situation descriptions for mission briefings",
    entries = {
        { id = "sit_shortage_01",    text = "Reports indicate a {category} shortage developing in the {zoneName} region. Local supply chains have been disrupted and traders are struggling to meet demand.", weight = 10 },
        { id = "sit_shortage_02",    text = "The {zoneName} area is running critically low on {category} supplies. Without intervention, prices will spike further and availability will collapse.", weight = 8 },
        { id = "sit_intel_gap_01",   text = "Our intelligence on {category} activity in {zoneName} has gone stale. The last reliable report was days ago and the situation on the ground may have changed significantly.", weight = 10 },
        { id = "sit_intel_gap_02",   text = "There is a significant blind spot in our {category} coverage for the {zoneName} sector. Field verification is needed to update our models.", weight = 8 },
        { id = "sit_opportunity_01", text = "A contact in {zoneName} has flagged a potential {category} opportunity. The window is narrow but the margins could be significant for anyone positioned to act.", weight = 10 },
        { id = "sit_opportunity_02", text = "Market signals suggest an unusual {category} surplus in {zoneName}. This could be a procurement opportunity if we can confirm the data.", weight = 8 },
        { id = "sit_disruption_01",  text = "Trade routes through {zoneName} have been compromised. The {category} supply network is fragmenting and real-time intelligence is urgently needed.", weight = 8, conditions = { minDifficulty = 3 } },
        { id = "sit_disruption_02",  text = "A major disruption event has impacted {zoneName}. The {category} market is volatile and ground-truth data is the only way to assess the real situation.", weight = 6, conditions = { minDifficulty = 4 } },
        { id = "sit_signal_01",      text = "Unusual radio activity has been detected on frequencies associated with {zoneName}. The pattern suggests organised {category} movement that warrants closer monitoring.", weight = 8 },
        { id = "sit_signal_02",      text = "Our passive monitoring has picked up intermittent transmissions near {zoneName}. The signal profile matches known {category} trading networks.", weight = 8 },
        { id = "sit_routine_01",     text = "Standard operational review of {category} conditions in {zoneName}. No immediate concerns flagged but periodic verification keeps our data current.", weight = 10, conditions = { maxDifficulty = 2 } },
        { id = "sit_routine_02",     text = "Regular survey cycle for the {zoneName} sector. {category} data needs refreshing to maintain confidence in our pricing models.", weight = 8, conditions = { maxDifficulty = 2 } },
        { id = "sit_contact_01",     text = "{sponsorName} has requested field support for a {category} operation in {zoneName}. The details are outlined in the tasking section below.", weight = 8 },
        { id = "sit_contact_02",     text = "A request has come through from {sponsorName} regarding {category} activity near {zoneName}. They are offering compensation for verified intelligence.", weight = 8 },
        { id = "sit_crisis_01",      text = "CRITICAL: {category} infrastructure in {zoneName} is failing. Multiple sources confirm cascading supply chain collapse. Immediate field assessment required.", weight = 4, conditions = { minDifficulty = 5 } },
        { id = "sit_recovery_01",    text = "Following recent disruptions in {zoneName}, the {category} market is showing signs of recovery. Confirmation data would allow us to update our trading positions.", weight = 8 },
        { id = "sit_competitive_01", text = "Competing operators have been spotted surveying {category} assets in {zoneName}. We need our own assessment before they corner the market.", weight = 6, conditions = { minDifficulty = 3 } },
        { id = "sit_seasonal_01",    text = "Seasonal patterns suggest {category} availability in {zoneName} should be shifting. Field confirmation would validate our predictive models.", weight = 8 },
        { id = "sit_rumour_01",      text = "Unverified rumours suggest a hidden {category} cache somewhere in the {zoneName} area. The source is unreliable but the potential payoff justifies investigation.", weight = 6 },
        { id = "sit_military_01",    text = "Military convoy activity near {zoneName} has increased. This could affect {category} availability and pricing across the region.", weight = 6, conditions = { minDifficulty = 3 } },
    },
}
