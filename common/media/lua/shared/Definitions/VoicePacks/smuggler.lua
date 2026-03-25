return {
    schemaVersion = 1,
    id = "voice_smuggler",
    archetypeId = "smuggler",
    description = "Shadowy, informal, off-the-books language",
    overrides = {
        situation  = "voice_smuggler_situations",
        submission = "voice_smuggler_submissions",
        agentState = "voice_smuggler_agent_states",
        investment = "voice_smuggler_investments",
        wbn_opener             = "voice_wbn_smuggler_openers",
        wbn_closer             = "voice_wbn_smuggler_closers",
        wbn_weather            = "voice_wbn_smuggler_weather",
        wbn_power              = "voice_wbn_smuggler_power",
        wbn_flavour_market     = "voice_wbn_smuggler_flavour_market",
        wbn_flavour_emergency  = "voice_wbn_smuggler_flavour_emergency",
    },
}
