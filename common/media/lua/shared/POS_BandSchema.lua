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
-- Schema for radio band definitions.
-- Each band represents a distinct POSnet frequency range
-- that gates which missions, contracts, and intel are visible.
-- Addon mods can register custom bands via the registry.
-- See design-guidelines.md §45.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    fields = {
        schemaVersion  = { type = "number", required = true },
        id             = { type = "string",  required = true },
        name           = { type = "string",  required = true },
        displayNameKey = { type = "string",  required = true },
        description    = { type = "string",  default = "" },
        azasBandType   = { type = "string",  required = true, enum = { "amateur", "tactical", "broadcast" } },
        badgeLabel     = { type = "string",  default = "" },
        sortOrder      = { type = "number",  default = 10 },
        enabled        = { type = "boolean", default = true },
    }
}
