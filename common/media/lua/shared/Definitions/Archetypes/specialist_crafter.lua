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
    id = "specialist_crafter",
    name = "Specialist Crafter",
    displayNameKey = "UI_POS_Agent_SpecialistCrafter",
    description = "Skilled artisan who converts raw materials into finished goods, buffering narrow tool and equipment categories.",
    behaviour = "specialist_crafter",
    tuning = {
        reliability   = 0.75,
        volatility    = 0.30,
        stockBias     = "medium",
        priceBias     = 0.10,
        refreshDays   = 2,
        influence     = 2,
        secrecy       = 0.15,
        rumorRate     = 0.08,
        riskTolerance = 0.45,
    },
    affinities = {
        food       = 0.1,
        medicine   = 0.5,
        ammunition = 0.6,
        fuel       = 0.2,
        tools      = 1.0,
        radio      = 0.7,
        weapons    = 0.4,
    },
    enabled = true,
}
