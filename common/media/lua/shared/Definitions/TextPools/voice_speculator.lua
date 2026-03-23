---------------------------------------------------------------
-- Speculator voice pack — anxious, hoarding mentality,
-- fearful language. Overrides "situation" section when a
-- speculator archetype sponsors a mission or contract.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_speculator_situations",
    description = "Speculator-voiced situation descriptions",
    entries = {
        { id = "spec_sit_01", text = "People are not paying attention to what is happening with {category} in {zoneName}. By the time they notice, the price will be triple. I need confirmation before I move.", weight = 10 },
        { id = "spec_sit_02", text = "There is a window opening on {category} and it will not stay open long. Someone in {zoneName} is sitting on supply. Find out who and how much.", weight = 10 },
        { id = "spec_sit_03", text = "I have been watching {category} prices in {zoneName} for weeks. Something does not add up. The numbers say surplus but the shelves say shortage.", weight = 8 },
        { id = "spec_sit_04", text = "Everyone thinks {category} is stable in {zoneName}. They are wrong. I can feel it. Get me the real numbers before the crash.", weight = 8 },
        { id = "spec_sit_05", text = "If {category} dips below my threshold in {zoneName}, I am buying everything I can carry. But I need eyes on the ground first. Trust but verify.", weight = 8 },
    },
}
