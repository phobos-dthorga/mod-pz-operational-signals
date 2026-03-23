---------------------------------------------------------------
-- Mission Definition Template
-- Copy this file and modify for addon mission types.
-- See design-guidelines.md §32.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "template_mission",
    name = "Template Mission",
    description = "Example mission definition — not loaded (enabled = false).",
    category = "recon",
    difficultyMin = 1,
    difficultyMax = 3,
    briefingPools = {
        title      = "titles_common",
        situation  = "situations_common",
        tasking    = "taskings_common",
        constraints = "constraints_common",
        submission = "submissions_common",
    },
    objectives = {
        { type = "survey", description = "Survey the target area" },
    },
    rewardMin = 50,
    rewardMax = 200,
    reputationMin = 5,
    reputationMax = 15,
    expiryDaysMin = 3,
    expiryDaysMax = 7,
    enabled = false,
}
