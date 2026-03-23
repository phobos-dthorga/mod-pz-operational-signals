return {
    schemaVersion = 1,
    id = "urgent_shortage",
    name = "Emergency Shortage",
    description = "Desperate plea for critical supplies. Premium pricing, tight deadline.",
    kind = "urgent",
    categoryId = "",  -- resolved at generation: medicine, food, fuel
    quantityMin = 3,
    quantityMax = 15,
    payMultiplierMin = 1.5,
    payMultiplierMax = 2.5,
    deadlineDaysMin = 2,
    deadlineDaysMax = 4,
    urgency = 4,
    sigintRequired = 2,
    reputationMin = 5,
    archetypeId = "",  -- resolved: could be any archetype in distress
    betrayalChance = 0,
    briefingPools = {
        title     = "contract_titles_urgent",
        situation = "contract_situations_urgent",
        tasking   = "contract_taskings_urgent",
        submission = "contract_submissions_common",
    },
}
