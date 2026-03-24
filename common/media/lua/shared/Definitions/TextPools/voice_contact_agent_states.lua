---------------------------------------------------------------
-- Contact agent state messages — established, reliable, routine.
-- A wholesaler route contact. Professional and predictable.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_contact_agent_states",
    description = "Contact free agent state transition messages",
    entries = {
        { id = "cont_st_drafted",    text = "Order logged. Adding to the next scheduled run.", weight = 10, conditions = { state = "drafted" } },
        { id = "cont_st_assembling", text = "Pulling from warehouse inventory. Loading manifest prepared.", weight = 10, conditions = { state = "assembling" } },
        { id = "cont_st_transit",    text = "Shipment dispatched via the usual supply route.", weight = 10, conditions = { state = "transit" } },
        { id = "cont_st_negotiate",  text = "Processing at the distribution node. Standard terms apply.", weight = 10, conditions = { state = "negotiation" } },
        { id = "cont_st_settle",     text = "Delivery confirmed. Invoice is being processed.", weight = 10, conditions = { state = "settlement" } },
        { id = "cont_st_complete",   text = "Order fulfilled through standard channels. Payment credited to your account.", weight = 10, conditions = { state = "completed" } },
        { id = "cont_st_delayed",    text = "Supply chain disruption on the main route. Rerouting through secondary network.", weight = 10, conditions = { state = "delayed" } },
        { id = "cont_st_compromised", text = "Route compromised. Diverting cargo to secure holding. Assessment in progress.", weight = 10, conditions = { state = "compromised" } },
        { id = "cont_st_failed",     text = "Shipment lost in transit. Insurance claim filed. Regret the inconvenience.", weight = 10, conditions = { state = "failed" } },
    },
}
