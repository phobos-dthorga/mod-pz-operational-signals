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
    id = "speculator",
    name = "Speculator",
    displayNameKey = "UI_POS_Agent_Speculator",
    description = "Crisis hoarder who stockpiles essentials and manipulates prices during shortages.",
    behaviour = "speculator",
    tuning = {
        reliability   = 0.35,
        volatility    = 0.60,
        stockBias     = "low",
        priceBias     = 0.35,
        refreshDays   = 2,
        influence     = 3,
        secrecy       = 0.55,
        rumorRate     = 0.25,
        riskTolerance = 0.70,
    },
    affinities = {
        food       = 1.0,
        medicine   = 0.8,
        ammunition = 0.5,
        fuel       = 0.8,
        tools      = 0.3,
        radio      = 0.2,
        weapons    = 0.3,
    },
    enabled = true,
}
