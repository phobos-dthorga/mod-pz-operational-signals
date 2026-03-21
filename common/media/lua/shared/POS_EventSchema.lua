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
        schemaVersion      = { type = "number", required = true },
        id                 = { type = "string", required = true },
        name               = { type = "string", required = true },
        description        = { type = "string", default = "" },
        signalClass        = { type = "string", required = true, enum = { "hard", "soft", "structural" } },
        pressureEffect     = { type = "number", default = 0 },
        durationDays       = { type = "number", min = 1, default = 3 },
        affectedCategories = { type = "array" },
        probability        = { type = "number", min = 0, max = 1, default = 0.1 },
        enabled            = { type = "boolean", default = true },
    }
}
