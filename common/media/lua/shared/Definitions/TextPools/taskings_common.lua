---------------------------------------------------------------
-- Common tasking text pool.
-- Describes what the player needs to do.
-- Tokens: {zoneName}, {category}, {targetName}, {rewardCash},
--         {deadlineDay}, {objectiveCount}
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "taskings_common",
    description = "Generic tasking/objective descriptions for mission briefings",
    entries = {
        { id = "task_recon_01",       text = "Survey the {zoneName} area and gather current {category} intelligence. Report findings via terminal before day {deadlineDay}.", weight = 10 },
        { id = "task_recon_02",       text = "Conduct a field assessment of {category} conditions in {zoneName}. Document pricing, stock levels, and any supply chain anomalies.", weight = 10 },
        { id = "task_recon_03",       text = "Verify current {category} data for the {zoneName} sector. Cross-reference with existing records and flag any significant deviations.", weight = 8 },
        { id = "task_targeted_01",    text = "Investigate {targetName} in the {zoneName} area. Assess {category} stock levels on-site and record observations.", weight = 10 },
        { id = "task_targeted_02",    text = "Visit {targetName} and conduct a detailed survey. Focus on {category} inventory, pricing indicators, and trade activity.", weight = 8 },
        { id = "task_delivery_01",    text = "Transport the designated cargo from {zoneName} to the drop-off point. Maintain radio contact and confirm delivery via terminal.", weight = 10 },
        { id = "task_delivery_02",    text = "Collect the {category} package and deliver it to the specified coordinates. Time-sensitive — deadline is day {deadlineDay}.", weight = 8 },
        { id = "task_procurement_01", text = "Acquire {category} goods from available sources in {zoneName}. Budget: ${rewardCash}. Maximise quantity within budget constraints.", weight = 10 },
        { id = "task_procurement_02", text = "Source and purchase {category} supplies. Target the best price-to-quantity ratio available in the {zoneName} market.", weight = 8 },
        { id = "task_intercept_01",   text = "Monitor radio frequencies associated with {zoneName} for {category}-related transmissions. Log all intercepted traffic and analyse for actionable intelligence.", weight = 8 },
        { id = "task_intercept_02",   text = "Establish a listening post and scan for {category} trade signals in the {zoneName} band. Minimum monitoring duration: 2 hours.", weight = 8 },
        { id = "task_analyse_01",     text = "Process the raw {category} data through terminal analysis. Compile findings into a structured report for distribution.", weight = 8 },
        { id = "task_generic_01",     text = "Complete the {objectiveCount} objective(s) outlined below. Compensation of ${rewardCash} upon verified completion.", weight = 6 },
        { id = "task_generic_02",     text = "Execute the assigned objectives in the {zoneName} sector. Full briefing details follow. Report status via terminal.", weight = 6 },
        { id = "task_urgent_01",      text = "IMMEDIATE: Deploy to {zoneName} and assess the {category} situation. Report preliminary findings within 24 game-hours. Full analysis to follow.", weight = 4, conditions = { minDifficulty = 4 } },
        { id = "task_covert_01",      text = "Conduct a discreet survey of {category} activity in {zoneName}. Avoid drawing attention to POSnet operations in the area.", weight = 6, conditions = { minDifficulty = 3 } },
        { id = "task_multisite_01",   text = "Survey multiple {category} sites across the {zoneName} region. Compile comparative data for market analysis.", weight = 8 },
        { id = "task_followup_01",    text = "Follow up on previous {category} intelligence from {zoneName}. Verify whether reported conditions still hold and note any changes.", weight = 8 },
        { id = "task_document_01",    text = "Document all {category} observations in the {zoneName} area. Use recording equipment where available for higher-confidence data.", weight = 8 },
        { id = "task_network_01",     text = "Map the {category} supply network in {zoneName}. Identify key nodes, bottlenecks, and alternative routes.", weight = 6, conditions = { minDifficulty = 3 } },
    },
}
