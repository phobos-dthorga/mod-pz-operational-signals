---------------------------------------------------------------
-- Grey market situation text pools.
-- Shadowy. Terse. Trust no one.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "contract_situations_grey",
    description = "Grey market / smuggler situations",
    entries = {
        { id = "cs_grey_01", text = "Anonymous contact. Wants {category}. Cash up front, no names, no paperwork. Meet is in {zoneName}. You in or not?", weight = 10 },
        { id = "cs_grey_02", text = "Someone on the back channels is paying good money for {category}. The kind of deal where you do not ask questions and they do not answer them.", weight = 10 },
        { id = "cs_grey_03", text = "There is a buyer in {zoneName} who does not exist, if you know what I mean. Wants {quantity}x {targetName}. Payment is clean. The deal... less so.", weight = 8 },
        { id = "cs_grey_04", text = "Got a whisper about a {category} buyer operating out of {zoneName}. They pay above market but they have burned suppliers before. Your call.", weight = 8 },
        { id = "cs_grey_05", text = "Off-grid buyer. {category}. {zoneName} area. They are offering premium but the last operator who dealt with them has not been heard from since. Probably nothing.", weight = 6 },
    },
}
