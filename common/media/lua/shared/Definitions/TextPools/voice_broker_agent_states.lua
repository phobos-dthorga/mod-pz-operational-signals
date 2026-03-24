---------------------------------------------------------------
-- Broker agent state messages — smooth, confident, deal-focused.
-- A smooth-talker with a ham radio who knows everyone.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_broker_agent_states",
    description = "Broker free agent state transition messages",
    entries = {
        { id = "brok_st_drafted",    text = "I have your order. Let me work my contacts.", weight = 10, conditions = { state = "drafted" } },
        { id = "brok_st_assembling", text = "Sourcing the goods through my network. Stand by.", weight = 10, conditions = { state = "assembling" } },
        { id = "brok_st_transit",    text = "Goods are moving. My people are handling transport.", weight = 10, conditions = { state = "transit" } },
        { id = "brok_st_negotiate",  text = "In talks with the buyer. The price is moving in our favour.", weight = 10, conditions = { state = "negotiation" } },
        { id = "brok_st_settle",     text = "Deal is closed. Finalising the paperwork.", weight = 10, conditions = { state = "settlement" } },
        { id = "brok_st_complete",   text = "All done. Smooth transaction. Your cut is on the way.", weight = 10, conditions = { state = "completed" } },
        { id = "brok_st_delayed",    text = "Supply chain holdup. Adjusting timeline. Nothing to worry about.", weight = 10, conditions = { state = "delayed" } },
        { id = "brok_st_compromised", text = "Complications. One of my contacts backed out. Working alternatives.", weight = 10, conditions = { state = "compromised" } },
        { id = "brok_st_failed",     text = "Deal fell through. The market shifted before I could close. My apologies.", weight = 10, conditions = { state = "failed" } },
    },
}
