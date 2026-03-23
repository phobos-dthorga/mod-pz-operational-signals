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

---------------------------------------------------------------
-- Schema for data-driven mission definitions.
-- Each mission definition specifies categories, difficulty
-- ranges, briefing pool references, objectives, and reward
-- ranges.  See design-guidelines.md §32.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    fields = {
        schemaVersion  = { type = "number", required = true },
        id             = { type = "string",  required = true },
        name           = { type = "string",  required = true },
        description    = { type = "string",  default = "" },
        category       = { type = "string",  required = true },
        difficultyMin  = { type = "number",  min = 1, max = 5, default = 1 },
        difficultyMax  = { type = "number",  min = 1, max = 5, default = 3 },
        briefingPools  = { type = "table" },
        objectives     = { type = "array" },
        rewardMin      = { type = "number",  min = 0, default = 50 },
        rewardMax      = { type = "number",  min = 0, default = 200 },
        reputationMin  = { type = "number",  default = 5 },
        reputationMax  = { type = "number",  default = 20 },
        expiryDaysMin  = { type = "number",  min = 1, default = 3 },
        expiryDaysMax  = { type = "number",  min = 1, default = 7 },
        enabled        = { type = "boolean", default = true },
    }
}
