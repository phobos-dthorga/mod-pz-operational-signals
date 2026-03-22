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
    id = "muldraugh_general",
    name = "Muldraugh General Supply",
    displayNameKey = "UI_POS_Wholesaler_Name_MuldraughGeneral",
    description = "Small-town civilian wholesaler dealing in essentials and hardware.",
    regionId = "muldraugh",
    archetype = "wholesaler",
    categoryWeights = {
        food     = 1.0,
        medicine = 0.3,
        tools    = 0.8,
        fuel     = 0.4,
    },
    stockLevel      = 0.60,
    throughput      = 0.40,
    resilience      = 0.55,
    visibility      = 0.50,
    reliability     = 0.70,
    influence       = 0.40,
    secrecy         = 0.15,
    markupBias      = 0.05,
    panicThreshold  = 0.30,
    dumpThreshold   = 0.90,
    enabled = true,
}
