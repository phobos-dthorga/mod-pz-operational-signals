---------------------------------------------------------------
-- Urgent shortage situation text pools.
-- People are dying. The tone should reflect that.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "contract_situations_urgent",
    description = "Emergency shortage situations",
    entries = {
        { id = "cs_urg_01", text = "EMERGENCY: {zoneName} medical station is out of {category}. People are dying. They will pay whatever it takes for the first supplier who can deliver.", weight = 10 },
        { id = "cs_urg_02", text = "Distress call intercepted from {zoneName}. Their {category} reserves are gone. Three days, maybe less, before they start losing people.", weight = 10 },
        { id = "cs_urg_03", text = "The {zoneName} safehouse is broadcasting on open frequencies now. That is how desperate they are. {category} supplies needed immediately. No time for negotiation.", weight = 8 },
        { id = "cs_urg_04", text = "A runner from {zoneName} reached the relay with a handwritten note: they need {category} or they are abandoning the settlement. This is real.", weight = 8 },
        { id = "cs_urg_05", text = "Static-heavy transmission from {zoneName}: multiple casualties, {category} depleted, requesting any available supply. Signal is degrading. They may not be able to transmit again.", weight = 6 },
    },
}
