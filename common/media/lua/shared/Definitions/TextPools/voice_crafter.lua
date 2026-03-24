---------------------------------------------------------------
-- Specialist Crafter voice pack — technical, workshop-focused.
-- Overrides "situation" section when the mission sponsor is a
-- specialist_crafter archetype.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_crafter_situations",
    description = "Specialist crafter situation descriptions — workshop tone",
    entries = {
        { id = "craft_sit_01", text = "The workshop needs {category} materials for a special order in {zoneName}. The client is paying premium for quality components and I cannot source them through my usual channels.", weight = 10 },
        { id = "craft_sit_02", text = "I have been working on a custom fabrication project that requires specific {category} supplies from {zoneName}. The specifications are precise and substitutes will not do.", weight = 8 },
        { id = "craft_sit_03", text = "A technical problem has emerged in the {zoneName} workshop district. {category} components are failing quality checks and fresh stock is needed before the next production run.", weight = 8 },
        { id = "craft_sit_04", text = "The repair backlog is growing. Every settlement within range of {zoneName} needs {category} parts and my current inventory cannot keep up with demand.", weight = 8 },
        { id = "craft_sit_05", text = "I have blueprints for something that could change how we operate in {zoneName}, but the {category} materials required are not something I can forge from scrap. Field procurement is the only option.", weight = 6, conditions = { minDifficulty = 3 } },
    },
}
