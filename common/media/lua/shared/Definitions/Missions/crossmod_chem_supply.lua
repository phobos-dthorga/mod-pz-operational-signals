---------------------------------------------------------------
-- Cross-mod mission: PCP Chemistry Supply Run
-- Only activates when PhobosChemistryPathways is installed.
-- A desperate plea crackles through the radio: the settlement
-- lab is running dry and people need medicine that only a
-- chemist can produce — but the chemist needs reagents.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "crossmod_chem_supply",
    name = "Chemistry Reagent Supply",
    description = "Acquire chemical reagents for a settlement laboratory.",
    category = "trade",
    difficultyMin = 2,
    difficultyMax = 4,
    briefingPools = {
        title      = "titles_common",
        situation  = "situations_common",
        tasking    = "taskings_common",
        constraints = "constraints_common",
        submission = "submissions_common",
    },
    objectives = {
        { type = "acquire", description = "Source chemical reagents from available suppliers" },
        { type = "deliver", description = "Deliver reagents to the laboratory contact" },
        { type = "confirm", description = "Confirm delivery via terminal" },
    },
    rewardMin = 120,
    rewardMax = 380,
    reputationMin = 8,
    reputationMax = 22,
    expiryDaysMin = 3,
    expiryDaysMax = 7,
    requiredBands = { "POSnet_Operations" },
    crossModRequires = "PhobosChemistryPathways",
}
