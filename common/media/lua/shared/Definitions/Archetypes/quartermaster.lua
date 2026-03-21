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
    id = "quartermaster",
    name = "Settlement Quartermaster",
    description = "A methodical community supply manager maintaining stable local trade.",
    behaviour = "baseline_trader",
    tuning = {
        reliability   = 0.85,
        volatility    = 0.15,
        stockBias     = "medium",
        priceBias     = 0.00,
        refreshDays   = 2,
        influence     = 3,
        secrecy       = 0.10,
        rumorRate     = 0.05,
        riskTolerance = 0.25,
    },
    affinities = {
        food       = 1.0,
        medicine   = 0.7,
        ammunition = 0.2,
        fuel       = 0.5,
        tools      = 0.6,
        radio      = 0.1,
        weapons    = 0.1,
    },
}
