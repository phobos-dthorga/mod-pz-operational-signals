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
        schemaVersion    = { type = "number", required = true },
        id               = { type = "string", required = true },
        systemName       = { type = "string", default = "POSNET BBS" },
        postBootPauseSec = { type = "number", min = 0, max = 5, default = 1.0 },
        durationSeconds  = { type = "number", min = 5, max = 120, default = 15 },
        lines            = { type = "array",  required = true },
    }
}
