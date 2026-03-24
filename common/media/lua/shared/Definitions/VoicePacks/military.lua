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
    },
}
