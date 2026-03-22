--  ________________________________________________________________________
-- / Copyright (c) 2026 Phobos A. D'thorga                                \
-- |                                                                        |
-- |           /\_/\                                                         |
-- |         =/ o o \=    Phobos' PZ Modding                                |
-- |          (  V  )     All rights reserved.                              |
-- |     /\  / \   / \                                                      |
-- |    /  \/   '-'   \   This source code is part of the Phobos            |
-- |   /  /  \  ^  /\  \  mod suite for Project Zomboid (Build 42).         |
-- |  (__/    \_/ \/  \__)                                                  |
-- |     |   | |  | |     Unauthorised copying, modification, or            |
-- |     |___|_|  |_|     distribution of this file is prohibited.          |
-- |                                                                        |
-- \________________________________________________________________________/
--

return {
    schemaVersion = 1,
    id = "military_field_hospital",
    name = "Corridor Field Hospital",
    displayNameKey = "UI_POS_Wholesaler_Name_MilitaryFieldHospital",
    description = "Mobile medical staging area supporting military operations. Limited civilian access.",
    regionId = "military_corridor",
    archetype = "wholesaler",
    categoryWeights = {
        medicine = 1.0,
        food     = 0.4,
        tools    = 0.6,
    },
    stockLevel      = 0.70,
    throughput      = 0.60,
    resilience      = 0.75,
    visibility      = 0.15,
    reliability     = 0.85,
    influence       = 0.55,
    secrecy         = 0.55,
    markupBias      = -0.05,
    panicThreshold  = 0.20,
    dumpThreshold   = 0.92,
    enabled = true,
}
