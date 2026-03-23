---------------------------------------------------------------
-- Military voice pack — formal, terse, procedural language.
-- Overrides "situation" and "submission" sections when the
-- mission sponsor is a military_logistics archetype.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_military_situations",
    description = "Military-voiced situation descriptions",
    entries = {
        { id = "mil_sit_01", text = "SITREP: {category} supply status in {zoneName} AO is degraded. Current intel is {difficulty}-day stale. Field verification required.", weight = 10 },
        { id = "mil_sit_02", text = "Standing order: assess {category} infrastructure in {zoneName} sector. Previous reports indicate potential supply chain compromise.", weight = 10 },
        { id = "mil_sit_03", text = "Intelligence gap identified in {zoneName} coverage area. {category} logistics data requires immediate update for operational planning.", weight = 8 },
        { id = "mil_sit_04", text = "Command has flagged {zoneName} for priority assessment. {category} availability directly impacts operational readiness.", weight = 8 },
        { id = "mil_sit_05", text = "Routine surveillance of {category} assets in {zoneName} AO. Maintain standard reporting protocol.", weight = 8, conditions = { maxDifficulty = 2 } },
    },
}
