---------------------------------------------------------------
-- Scavenger voice pack — scrappy, street-level, informal.
-- Overrides "situation" section when a scavenger archetype
-- sponsors a mission or contract.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_scavenger_situations",
    description = "Scavenger-voiced situation descriptions",
    entries = {
        { id = "scav_sit_01", text = "Found some {category} stashed in a basement near {zoneName}. Not much, but it is something. You want in or not?", weight = 10 },
        { id = "scav_sit_02", text = "Been picking through {zoneName} all week. {category} is getting harder to find. The easy pickings are gone.", weight = 10 },
        { id = "scav_sit_03", text = "There is a building on the edge of {zoneName} that nobody has hit yet. Could have decent {category} inside. Could also have company.", weight = 8 },
        { id = "scav_sit_04", text = "Word is someone cleared out a {category} cache near {zoneName} yesterday. If there is anything left, it will not last long.", weight = 8 },
        { id = "scav_sit_05", text = "I make runs through {zoneName} every few days. {category} shows up in weird places if you know where to look.", weight = 8 },
    },
}
