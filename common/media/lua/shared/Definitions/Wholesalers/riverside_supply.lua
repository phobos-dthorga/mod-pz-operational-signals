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
    id = "riverside_supply",
    name = "Riverside Supply Co-op",
    displayNameKey = "UI_POS_Wholesaler_Name_RiversideSupply",
    description = "Community-run supply cooperative focused on food and medical aid.",
    regionId = "riverside",
    archetype = "wholesaler",
    categoryWeights = {
        food     = 1.0,
        medicine = 0.8,
        fuel     = 0.3,
        tools    = 0.4,
    },
    stockLevel      = 0.65,
    throughput      = 0.50,
    resilience      = 0.60,
    visibility      = 0.55,
    reliability     = 0.85,
    influence       = 0.50,
    secrecy         = 0.10,
    markupBias      = -0.05,
    panicThreshold  = 0.20,
    dumpThreshold   = 0.92,
    enabled = true,
}
