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
        schemaVersion   = { type = "number", required = true },
        id              = { type = "string", required = true },
        name            = { type = "string", required = true },
        description     = { type = "string", default = "" },
        regionId        = { type = "string", required = true },
        archetype       = { type = "string", default = "wholesaler" },
        categoryWeights = { type = "table" },
        stockLevel      = { type = "number", min = 0, max = 1, default = 0.75 },
        throughput      = { type = "number", min = 0, max = 1, default = 0.60 },
        resilience      = { type = "number", min = 0, max = 1, default = 0.70 },
        visibility      = { type = "number", min = 0, max = 1, default = 0.35 },
        reliability     = { type = "number", min = 0, max = 1, default = 0.80 },
        influence       = { type = "number", min = 0, max = 1, default = 0.85 },
        secrecy         = { type = "number", min = 0, max = 1, default = 0.20 },
        markupBias      = { type = "number", min = -1, max = 1, default = -0.08 },
        panicThreshold  = { type = "number", min = 0, max = 1, default = 0.25 },
        dumpThreshold   = { type = "number", min = 0, max = 1, default = 0.90 },
        enabled         = { type = "boolean", default = true },
    }
}
