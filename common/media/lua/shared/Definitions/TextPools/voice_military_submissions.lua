return {
    schemaVersion = 1,
    id = "voice_military_submissions",
    description = "Military-voiced submission instructions — formal, procedural",
    entries = {
        { id = "mil_sub_01", text = "Report findings to command via secure terminal channel. Verification code will be issued on receipt. Compensation processed through standard disbursement.", weight = 10 },
        { id = "mil_sub_02", text = "Submit operational report through the designated terminal. Incomplete reports will be rejected. Full compensation of ${rewardCash} on verified completion.", weight = 10 },
        { id = "mil_sub_03", text = "File after-action report via POSnet terminal. Include all gathered intelligence. Payment authorised upon command review.", weight = 8 },
        { id = "mil_sub_04", text = "Operational debrief required. Submit all data through secure channels. Compensation contingent on data quality assessment.", weight = 8 },
        { id = "mil_sub_05", text = "Mission completion protocol: submit via terminal, await confirmation, collect disbursement. Dismissed.", weight = 6 },
    },
}
