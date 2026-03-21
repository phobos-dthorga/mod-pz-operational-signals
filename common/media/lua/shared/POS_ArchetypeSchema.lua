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
    fields = {
        schemaVersion = { type = "number", required = true },
        id            = { type = "string", required = true },
        name          = { type = "string", required = true },
        description   = { type = "string", default = "" },
        behaviour     = { type = "string", required = true, enum = {
            "baseline_trader", "speculator", "wholesaler",
            "smuggler", "military_logistics", "specialist_crafter",
        }},
        tuning = { type = "table", required = true, fields = {
            reliability   = { type = "number", min = 0, max = 1, default = 0.55 },
            volatility    = { type = "number", min = 0, max = 1, default = 0.30 },
            stockBias     = { type = "string", default = "medium", enum = { "none", "low", "medium", "high" } },
            priceBias     = { type = "number", min = -1, max = 1, default = 0.0 },
            refreshDays   = { type = "number", min = 1, max = 30, default = 2 },
            influence     = { type = "number", min = 0, max = 10, default = 1 },
            secrecy       = { type = "number", min = 0, max = 1, default = 0.20 },
            rumorRate     = { type = "number", min = 0, max = 1, default = 0.10 },
            riskTolerance = { type = "number", min = 0, max = 1, default = 0.50 },
        }},
        affinities = { type = "table", required = true },
        enabled    = { type = "boolean", default = true },
    }
}
