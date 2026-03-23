---------------------------------------------------------------
-- Common submission text pool.
-- Describes how and where to submit completed work.
-- Tokens: {zoneName}, {rewardCash}, {sponsorName}, {deadlineDay}
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "submissions_common",
    description = "Generic completion/submission instructions",
    entries = {
        { id = "sub_terminal_01",  text = "Submit findings via your POSnet terminal. Compensation of ${rewardCash} will be credited upon verification.", weight = 10 },
        { id = "sub_terminal_02",  text = "File your report through the terminal's assignment interface. Payment processes automatically on confirmation.", weight = 10 },
        { id = "sub_terminal_03",  text = "Upload observations to POSnet. Data will be cross-referenced against existing records. Verified submissions earn ${rewardCash}.", weight = 8 },
        { id = "sub_sponsor_01",   text = "{sponsorName} will review submitted data. Expect compensation within one business day of acceptance.", weight = 8 },
        { id = "sub_sponsor_02",   text = "Report directly to {sponsorName} via the terminal. Bonus compensation available for exceeding data quality thresholds.", weight = 6 },
        { id = "sub_deadline_01",  text = "Deadline: day {deadlineDay}. Submit via terminal before expiry. Late submissions receive 50% compensation.", weight = 8 },
        { id = "sub_deadline_02",  text = "Time-sensitive. All data must be submitted by day {deadlineDay}. No exceptions.", weight = 6, conditions = { minDifficulty = 3 } },
        { id = "sub_quality_01",   text = "Higher confidence data earns bonus compensation above the base rate of ${rewardCash}. Use recording equipment for best results.", weight = 8 },
        { id = "sub_quality_02",   text = "Data quality matters. Camera-compiled reports earn a 50% premium over raw field observations.", weight = 6 },
        { id = "sub_auto_01",      text = "Completion is automatic once all objectives are verified. ${rewardCash} credited to your account immediately.", weight = 10 },
        { id = "sub_auto_02",      text = "The system will detect objective completion automatically. No manual submission required.", weight = 8 },
        { id = "sub_partial_01",   text = "Partial completion accepted. Compensation scales with the percentage of objectives completed.", weight = 8, conditions = { minDifficulty = 2 } },
        { id = "sub_bonus_01",     text = "Base compensation: ${rewardCash}. Speed bonus available for completion within 24 hours of assignment.", weight = 6 },
        { id = "sub_reputation_01", text = "Successful completion improves your operator reputation, unlocking higher-tier assignments in future.", weight = 8 },
        { id = "sub_reputation_02", text = "Your track record matters. Consistent quality submissions build reputation and access to premium contracts.", weight = 6 },
        { id = "sub_failure_01",   text = "WARNING: Failure to complete by deadline incurs a reputation penalty. Cancellation is preferred to expiry.", weight = 6, conditions = { minDifficulty = 3 } },
        { id = "sub_network_01",   text = "Data will be distributed across the POSnet network upon submission, benefiting all connected operators.", weight = 8 },
        { id = "sub_classified_01", text = "CLASSIFIED: Do not share operation details post-submission. Data is for POSnet network use only.", weight = 4, conditions = { minDifficulty = 4 } },
        { id = "sub_simple_01",    text = "Submit via terminal when complete. ${rewardCash} on confirmation.", weight = 10, conditions = { maxDifficulty = 2 } },
        { id = "sub_simple_02",    text = "Straightforward submission. Complete objectives, submit, collect ${rewardCash}. Good luck, operator.", weight = 8, conditions = { maxDifficulty = 2 } },
    },
}
