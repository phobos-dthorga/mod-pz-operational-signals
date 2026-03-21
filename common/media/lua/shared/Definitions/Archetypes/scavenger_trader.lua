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
    id = "scavenger_trader",
    name = "Backroad Scavenger",
    displayNameKey = "UI_POS_Agent_ScavengerTrader",
    description = "A small-time regional opportunist dealing in salvaged goods.",
    behaviour = "baseline_trader",
    tuning = {
        reliability   = 0.55,
        volatility    = 0.45,
        stockBias     = "low",
        priceBias     = 0.10,
        refreshDays   = 1,
        influence     = 1,
        secrecy       = 0.25,
        rumorRate     = 0.20,
        riskTolerance = 0.80,
    },
    affinities = {
        food       = 1.0,
        medicine   = 0.4,
        ammunition = 0.2,
        fuel       = 0.8,
        tools      = 1.0,
        radio      = 0.1,
        weapons    = 0.3,
    },
}
