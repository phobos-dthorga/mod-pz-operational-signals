---------------------------------------------------------------
-- Runner agent state messages — fast, scrappy, breathless.
-- A kid with a bike and a death wish. Quick updates, short words.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_runner_agent_states",
    description = "Runner free agent state transition messages",
    entries = {
        { id = "run_st_drafted",    text = "Got the job. Packing light.", weight = 10, conditions = { state = "drafted" } },
        { id = "run_st_assembling", text = "Loading up. Be ready to move in a sec.", weight = 10, conditions = { state = "assembling" } },
        { id = "run_st_transit",    text = "On the move. Will radio when I arrive.", weight = 10, conditions = { state = "transit" } },
        { id = "run_st_negotiate",  text = "Made contact. Haggling now.", weight = 10, conditions = { state = "negotiation" } },
        { id = "run_st_settle",     text = "Done. Heading back with the cash.", weight = 10, conditions = { state = "settlement" } },
        { id = "run_st_complete",   text = "Back safe. Cargo delivered. Payment incoming.", weight = 10, conditions = { state = "completed" } },
        { id = "run_st_delayed",    text = "Hit a detour. Gonna take longer than I thought.", weight = 10, conditions = { state = "delayed" } },
        { id = "run_st_compromised", text = "Things got messy. Trying to salvage what I can.", weight = 10, conditions = { state = "compromised" } },
        { id = "run_st_failed",     text = "Lost the cargo. Sorry. Did not make it.", weight = 10, conditions = { state = "failed" } },
    },
}
