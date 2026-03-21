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
    id = "west_point_consolidated",
    name = "West Point Consolidated",
    description = "Medium-scale civilian distributor serving the regional hub.",
    regionId = "west_point",
    archetype = "wholesaler",
    categoryWeights = {
        food       = 0.9,
        medicine   = 0.6,
        ammunition = 0.2,
        fuel       = 0.5,
        tools      = 0.7,
        radio      = 0.1,
    },
    stockLevel      = 0.75,
    throughput      = 0.60,
    resilience      = 0.65,
    visibility      = 0.45,
    reliability     = 0.80,
    influence       = 0.65,
    secrecy         = 0.20,
    markupBias      = -0.03,
    panicThreshold  = 0.25,
    dumpThreshold   = 0.88,
    enabled = true,
}
