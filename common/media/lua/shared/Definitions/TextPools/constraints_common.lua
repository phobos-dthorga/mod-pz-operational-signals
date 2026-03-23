---------------------------------------------------------------
-- Common constraints text pool.
-- Describes difficulty modifiers and restrictions.
-- Only shown for difficulty >= 2 (skipped for routine missions).
-- Tokens: {zoneName}, {deadlineDay}, {difficulty}
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "constraints_common",
    description = "Difficulty modifiers and operational restrictions",
    entries = {
        { id = "con_deadline_01",    text = "Time-critical: all objectives must be completed before day {deadlineDay}. Late submissions will not be compensated.", weight = 10 },
        { id = "con_deadline_02",    text = "Hard deadline: day {deadlineDay}. No extensions available.", weight = 8 },
        { id = "con_hostile_01",     text = "The {zoneName} area has elevated threat levels. Exercise caution during field operations and maintain situational awareness.", weight = 8, conditions = { minDifficulty = 3 } },
        { id = "con_hostile_02",     text = "WARNING: Active hostiles reported in the operational zone. Armed escort recommended for {zoneName} operations.", weight = 6, conditions = { minDifficulty = 4 } },
        { id = "con_stealth_01",     text = "Operational security is paramount. Avoid broadcasting on open frequencies while in the {zoneName} sector.", weight = 8, conditions = { minDifficulty = 3 } },
        { id = "con_stealth_02",     text = "Maintain low profile. Other operators are active in {zoneName} and may be hostile to POSnet-affiliated personnel.", weight = 6, conditions = { minDifficulty = 4 } },
        { id = "con_equipment_01",   text = "Recommended equipment: recording device, writing materials, portable radio. Data quality bonuses apply for documented observations.", weight = 10, conditions = { minDifficulty = 2 } },
        { id = "con_equipment_02",   text = "Optimal results require a data recorder and blank media. Terminal analysis yields higher confidence ratings.", weight = 8, conditions = { minDifficulty = 2 } },
        { id = "con_weather_01",     text = "Weather conditions may affect radio reception in {zoneName}. Signal intercept operations should account for atmospheric interference.", weight = 6 },
        { id = "con_competition_01", text = "Competing intelligence operators have been spotted in {zoneName}. Priority goes to the first confirmed report.", weight = 6, conditions = { minDifficulty = 3 } },
        { id = "con_accuracy_01",    text = "High accuracy required: only verified observations will be accepted. Unconfirmed rumours do not qualify for completion.", weight = 8, conditions = { minDifficulty = 3 } },
        { id = "con_accuracy_02",    text = "Data quality threshold: minimum 60% confidence rating required for submission to count.", weight = 6, conditions = { minDifficulty = 4 } },
        { id = "con_distance_01",    text = "Operational area is remote. Plan for extended travel time and ensure adequate supplies.", weight = 8 },
        { id = "con_power_01",       text = "Extended monitoring operations will consume significant power. Ensure generator fuel reserves before committing.", weight = 6, conditions = { minDifficulty = 3 } },
        { id = "con_solo_01",        text = "This is a solo operation. Do not share briefing details with other operators.", weight = 6, conditions = { minDifficulty = 4 } },
        { id = "con_multi_obj_01",   text = "Multiple objectives must be completed in sequence. Partial completion will result in reduced compensation.", weight = 8, conditions = { minDifficulty = 2 } },
        { id = "con_night_01",       text = "Night operations offer better signal conditions but increased personal risk. Plan accordingly.", weight = 6, conditions = { minDifficulty = 3 } },
        { id = "con_verify_01",      text = "Cross-verification required: data must be corroborated by at least two independent sources.", weight = 4, conditions = { minDifficulty = 5 } },
        { id = "con_minimal_01",     text = "Standard operating procedures apply. No special restrictions.", weight = 10, conditions = { maxDifficulty = 2 } },
        { id = "con_budget_01",      text = "Budget constraints apply. Expenditure must not exceed the allocated compensation amount.", weight = 8 },
    },
}
