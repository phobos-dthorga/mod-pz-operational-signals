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
-- Schema for text pool definition files.
-- Text pools contain weighted text entries with optional
-- conditions.  Used by the Mission Briefing Resolver for
-- compositional briefing generation.
-- See design-guidelines.md §32.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    fields = {
        schemaVersion = { type = "number", required = true },
        id            = { type = "string",  required = true },
        description   = { type = "string",  default = "" },
        entries       = { type = "array" },
    }
}
