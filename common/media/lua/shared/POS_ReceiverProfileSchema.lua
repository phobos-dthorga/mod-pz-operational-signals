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
-- POS_ReceiverProfileSchema.lua
-- Schema for receiver quality profile definitions.
-- Each profile maps a radio full type to a pre-computed base
-- quality factor (0.0 = perfect, 1.0 = worst).
-- Validated by PhobosLib_Schema via the ReceiverProfile registry.
--
-- See design-guidelines.md §60 for receiver quality architecture.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    fields = {
        schemaVersion = { type = "number",  required = true },
        id            = { type = "string",  required = true },
        fullType      = { type = "string",  required = true },
        category      = { type = "string",  required = true, enum = { "handheld", "ham", "commercial", "tv" } },
        baseFactor    = { type = "number",  required = true, min = 0, max = 1 },
        isMakeshift   = { type = "boolean", default = false },
        description   = { type = "string",  default = "" },
        enabled       = { type = "boolean", default = true },
    }
}
