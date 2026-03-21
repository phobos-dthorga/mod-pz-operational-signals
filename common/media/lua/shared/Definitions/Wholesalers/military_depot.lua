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
    id = "military_depot",
    name = "Fort Knox Surplus Depot",
    description = "Military surplus distribution point along the corridor. Controlled release of strategic reserves.",
    regionId = "military_corridor",
    archetype = "wholesaler",
    categoryWeights = {
        ammunition = 1.0,
        fuel       = 0.9,
        radio      = 0.7,
        weapons    = 0.5,
        tools      = 0.3,
    },
    stockLevel      = 0.80,
    throughput      = 0.70,
    resilience      = 0.85,
    visibility      = 0.20,
    reliability     = 0.90,
    influence       = 0.90,
    secrecy         = 0.60,
    markupBias      = -0.10,
    panicThreshold  = 0.15,
    dumpThreshold   = 0.95,
    enabled = true,
}
