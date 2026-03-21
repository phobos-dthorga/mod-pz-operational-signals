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
    id = "louisville_arms",
    name = "Louisville Arms Exchange",
    description = "Black-market broker operating on the Louisville fringe. High-value, high-risk goods.",
    regionId = "louisville_edge",
    archetype = "wholesaler",
    categoryWeights = {
        ammunition = 1.0,
        radio      = 0.8,
        medicine   = 0.6,
        weapons    = 0.7,
        fuel       = 0.3,
    },
    stockLevel      = 0.55,
    throughput      = 0.45,
    resilience      = 0.40,
    visibility      = 0.25,
    reliability     = 0.60,
    influence       = 0.75,
    secrecy         = 0.70,
    markupBias      = 0.15,
    panicThreshold  = 0.35,
    dumpThreshold   = 0.85,
    enabled = true,
}
