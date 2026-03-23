---------------------------------------------------------------
-- Smuggler voice pack — shadier, more informal language.
-- Overrides "situation" and "submission" sections when the
-- mission sponsor is a smuggler archetype.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_smuggler_situations",
    description = "Smuggler-voiced situation descriptions",
    entries = {
        { id = "smug_sit_01", text = "Word on the street is {category} is getting scarce in {zoneName}. The usual channels are drying up and people are getting desperate.", weight = 10 },
        { id = "smug_sit_02", text = "I have a contact who says there is {category} moving through {zoneName} under the radar. Not exactly above board, but the margins are real.", weight = 8 },
        { id = "smug_sit_03", text = "Things are getting heated in {zoneName}. The {category} trade is drawing attention from people you do not want to meet. But opportunity favours the bold.", weight = 8 },
        { id = "smug_sit_04", text = "Look, I am not going to sugarcoat it. The {category} situation in {zoneName} is a mess. But messes are where the money is.", weight = 8 },
        { id = "smug_sit_05", text = "A little bird told me about a {category} stash in {zoneName}. Could be nothing, could be a goldmine. Only one way to find out.", weight = 6 },
    },
}
