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
    id = "louisville_medical",
    name = "Louisville Medical Cache",
    description = "Pharmaceutical stockpile salvaged from urban hospital networks.",
    regionId = "louisville_edge",
    archetype = "wholesaler",
    categoryWeights = {
        medicine = 1.0,
        food     = 0.5,
        tools    = 0.3,
    },
    stockLevel      = 0.70,
    throughput      = 0.55,
    resilience      = 0.50,
    visibility      = 0.30,
    reliability     = 0.75,
    influence       = 0.60,
    secrecy         = 0.45,
    markupBias      = 0.08,
    panicThreshold  = 0.25,
    dumpThreshold   = 0.90,
    enabled = true,
}
