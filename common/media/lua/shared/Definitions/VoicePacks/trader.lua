return {
    schemaVersion = 1,
    id = "voice_trader",
    archetypeId = "baseline_trader",
    description = "Mercantile, profit-focused, business language",
    overrides = {
        situation  = "voice_trader_situations",
        submission = "voice_trader_submissions",
        agentState = "voice_trader_agent_states",
        investment = "voice_trader_investments",
        wbn_opener = "voice_wbn_trader_openers",
        wbn_closer = "voice_wbn_trader_closers",
    },
}
