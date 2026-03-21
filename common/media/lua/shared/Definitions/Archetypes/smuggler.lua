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
    id = "smuggler",
    name = "Smuggler",
    displayNameKey = "UI_POS_Agent_Smuggler",
    description = "Black-market operator dealing in contraband and hard-to-find goods through covert channels.",
    behaviour = "smuggler",
    tuning = {
        reliability   = 0.45,
        volatility    = 0.50,
        stockBias     = "low",
        priceBias     = 0.25,
        refreshDays   = 2,
        influence     = 2,
        secrecy       = 0.60,
        rumorRate     = 0.30,
        riskTolerance = 0.90,
    },
    affinities = {
        food       = 0.2,
        medicine   = 0.8,
        ammunition = 1.0,
        fuel       = 0.7,
        tools      = 0.3,
        radio      = 0.9,
        weapons    = 0.6,
    },
    enabled = true,
}
