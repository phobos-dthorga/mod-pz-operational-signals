return {
    schemaVersion = 1,
    id = "contract_submissions_military",
    description = "Military submission instructions — formal, procedural",
    entries = {
        { id = "csub_mil_01", text = "Submit requisitioned materials via terminal interface. Quartermaster will verify against specification. Payment: ${rewardCash} upon acceptance. Non-conforming submissions rejected.", weight = 10 },
        { id = "csub_mil_02", text = "Deliver {quantity}x {targetName} per standard military procurement protocol. Compensation authorised at ${rewardCash}. Deadline: day {deadlineDay}. No extensions.", weight = 10 },
        { id = "csub_mil_03", text = "Terminal submission required. Military channels only. Verified suppliers receive priority for future requisitions. Payment processed within one duty cycle.", weight = 8 },
    },
}
