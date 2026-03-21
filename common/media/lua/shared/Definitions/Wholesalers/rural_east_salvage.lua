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
    id = "rural_east_salvage",
    name = "Eastern Salvage Yard",
    description = "Scrapyard operation consolidating salvaged tools and fuel from the rural hinterland.",
    regionId = "rural_east",
    archetype = "wholesaler",
    categoryWeights = {
        tools = 1.0,
        fuel  = 0.8,
        food  = 0.3,
        radio = 0.2,
    },
    stockLevel      = 0.55,
    throughput      = 0.35,
    resilience      = 0.50,
    visibility      = 0.60,
    reliability     = 0.55,
    influence       = 0.35,
    secrecy         = 0.20,
    markupBias      = 0.10,
    panicThreshold  = 0.35,
    dumpThreshold   = 0.85,
    enabled = true,
}
