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
    id = "military_logistician",
    name = "Military Logistician",
    displayNameKey = "UI_POS_Agent_MilitaryLogistician",
    description = "Authoritative military supply chain operator controlling ammunition, fuel, and communications equipment.",
    behaviour = "military_logistics",
    tuning = {
        reliability   = 0.90,
        volatility    = 0.25,
        stockBias     = "high",
        priceBias     = -0.10,
        refreshDays   = 3,
        influence     = 6,
        secrecy       = 0.50,
        rumorRate     = 0.12,
        riskTolerance = 0.35,
    },
    affinities = {
        food       = 0.2,
        medicine   = 0.8,
        ammunition = 1.0,
        fuel       = 0.9,
        tools      = 0.3,
        radio      = 0.9,
        weapons    = 0.5,
    },
    enabled = true,
}
