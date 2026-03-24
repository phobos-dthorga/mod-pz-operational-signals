---------------------------------------------------------------
-- Courier agent state messages — professional, ex-military.
-- Reliable operators who get the job done by the book.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_courier_agent_states",
    description = "Courier free agent state transition messages",
    entries = {
        { id = "cour_st_drafted",    text = "Assignment received. Preparing for departure.", weight = 10, conditions = { state = "drafted" } },
        { id = "cour_st_assembling", text = "Staging cargo. ETA to departure: minimal.", weight = 10, conditions = { state = "assembling" } },
        { id = "cour_st_transit",    text = "En route to destination. Maintaining radio contact.", weight = 10, conditions = { state = "transit" } },
        { id = "cour_st_negotiate",  text = "At the exchange point. Verifying terms with the contact.", weight = 10, conditions = { state = "negotiation" } },
        { id = "cour_st_settle",     text = "Transaction complete. Securing payment for return.", weight = 10, conditions = { state = "settlement" } },
        { id = "cour_st_complete",   text = "Mission accomplished. Cargo delivered, payment secured. Returning to base.", weight = 10, conditions = { state = "completed" } },
        { id = "cour_st_delayed",    text = "Encountering delays. Route obstruction. Rerouting.", weight = 10, conditions = { state = "delayed" } },
        { id = "cour_st_compromised", text = "Situation deteriorating. Implementing contingency plan.", weight = 10, conditions = { state = "compromised" } },
        { id = "cour_st_failed",     text = "Mission failed. Cargo lost in transit. Apologies.", weight = 10, conditions = { state = "failed" } },
    },
}
