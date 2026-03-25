return {
    schemaVersion = 1,
    id = "voice_military",
    archetypeId = "military_logistics",
    description = "Formal, terse, procedural military language",
    overrides = {
        situation  = "voice_military_situations",
        submission = "voice_military_submissions",
        agentState = "voice_military_agent_states",
        investment = "voice_military_investments",
        wbn_opener             = "voice_wbn_military_openers",
        wbn_closer             = "voice_wbn_military_closers",
        wbn_weather            = "voice_wbn_military_weather",
        wbn_power              = "voice_wbn_military_power",
        wbn_flavour_market     = "voice_wbn_military_flavour_market",
        wbn_flavour_emergency  = "voice_wbn_military_flavour_emergency",
    },
}
