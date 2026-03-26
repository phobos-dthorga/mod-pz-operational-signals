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
-- POS_SignalModifierSchema.lua
-- Schema for Signal Ecology environmental modifier definitions.
-- Validated by PhobosLib_Schema via the SignalModifier registry.
--
-- See design-guidelines.md §26 for data-pack architecture.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    fields = {
        schemaVersion  = { type = "number",  required = true },
        id             = { type = "string",  required = true },
        pillar         = { type = "string",  required = true, enum = { "propagation", "infrastructure", "saturation" } },
        trigger        = { type = "string",  required = true },
        propagation    = { type = "number",  default = 0 },
        noise          = { type = "number",  default = 0 },
        saturation     = { type = "number",  default = 0 },
        infrastructure = { type = "number",  default = 0 },
        severity       = { type = "number",  default = 0.5, min = 0, max = 1 },
        description    = { type = "string",  default = "" },
        enabled        = { type = "boolean", default = true },
    }
}
