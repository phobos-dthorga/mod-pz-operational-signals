---------------------------------------------------------------
-- Cross-mod mission: PIP Specimen Collection
-- Only activates when PhobosIndustrialPathology is installed.
-- A research facility needs biological specimens for pathology
-- analysis — but the collection sites are deep in infected
-- territory. Not a job for the faint-hearted.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "crossmod_specimen_collection",
    name = "Biological Specimen Collection",
    description = "Collect pathology specimens from hazardous sites.",
    category = "recovery",
    difficultyMin = 3,
    difficultyMax = 5,
    briefingPools = {
        title      = "titles_common",
        situation  = "situations_common",
        tasking    = "taskings_common",
        constraints = "constraints_common",
        submission = "submissions_common",
    },
    objectives = {
        { type = "visit",   description = "Navigate to the collection site" },
        { type = "acquire", description = "Collect biological specimens" },
        { type = "deliver", description = "Transport specimens to the research facility" },
        { type = "confirm", description = "Confirm delivery via terminal" },
    },
    rewardMin = 180,
    rewardMax = 500,
    reputationMin = 12,
    reputationMax = 30,
    expiryDaysMin = 3,
    expiryDaysMax = 6,
    requiredBands = { "POSnet_Tactical" },
    crossModRequires = "PhobosIndustrialPathology",
}
