---------------------------------------------------------------
-- Smuggler agent state messages — covert, tense, shadow-ops.
-- Operates outside the law. Radio silence is standard.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_smuggler_agent_states",
    description = "Smuggler free agent state transition messages",
    entries = {
        { id = "smug_st_drafted",    text = "Understood. Going dark after this.", weight = 10, conditions = { state = "drafted" } },
        { id = "smug_st_assembling", text = "Stashing the goods. Taking the back routes.", weight = 10, conditions = { state = "assembling" } },
        { id = "smug_st_transit",    text = "Moving quiet. Radio silence until I am clear.", weight = 10, conditions = { state = "transit" } },
        { id = "smug_st_negotiate",  text = "At the meet. Feeling it out. These people do not trust easy.", weight = 10, conditions = { state = "negotiation" } },
        { id = "smug_st_settle",     text = "Goods exchanged. Getting out before anyone notices.", weight = 10, conditions = { state = "settlement" } },
        { id = "smug_st_complete",   text = "Clean getaway. Money is yours minus my percentage.", weight = 10, conditions = { state = "completed" } },
        { id = "smug_st_delayed",    text = "Patrol activity. Laying low until the heat passes.", weight = 10, conditions = { state = "delayed" } },
        { id = "smug_st_compromised", text = "Cover blown. Dumping excess cargo. Salvaging what I can.", weight = 10, conditions = { state = "compromised" } },
        { id = "smug_st_failed",     text = "They got me. Cargo is gone. I barely got out.", weight = 10, conditions = { state = "failed" } },
    },
}
