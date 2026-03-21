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
    id = "wholesaler",
    name = "Wholesaler",
    description = "A bulk distributor whose stock levels drive regional supply and scarcity.",
    behaviour = "wholesaler",
    tuning = {
        reliability   = 0.80,
        volatility    = 0.20,
        stockBias     = "high",
        priceBias     = -0.05,
        refreshDays   = 3,
        influence     = 5,
        secrecy       = 0.15,
        rumorRate     = 0.08,
        riskTolerance = 0.40,
    },
    affinities = {
        food       = 1.0,
        medicine   = 0.6,
        ammunition = 0.3,
        fuel       = 0.4,
        tools      = 0.4,
        radio      = 0.1,
        weapons    = 0.1,
    },
}
