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
        schemaVersion  = { type = "number", required = true },
        id             = { type = "string", required = true },
        name           = { type = "string", required = true },
        description    = { type = "string", default = "" },
        baseVolatility = { type = "number", min = 0, max = 2, default = 0.20 },
        population     = { type = "string", default = "medium", enum = { "sparse", "medium", "dense" } },
        adjacentZones  = { type = "array" },
        luxuryDemand   = { type = "number", min = 0, max = 5, default = 1.0 },
        enabled        = { type = "boolean", default = true },
    }
}
