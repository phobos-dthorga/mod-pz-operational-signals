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
-- POS_SpeculationSchema.lua
-- Schema for speculative rumour template definitions.
-- Validated by PhobosLib_Schema via the Speculation registry.
--
-- See design-guidelines.md §59 and entropy-system-design.md §4.2.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    fields = {
        schemaVersion  = { type = "number",  required = true },
        id             = { type = "string",  required = true },
        impactHint     = { type = "string",  required = true, enum = { "shortage", "surplus", "disruption" } },
        weight         = { type = "number",  default = 10, min = 1 },
        confidenceMin  = { type = "number",  default = 0.10, min = 0, max = 1 },
        confidenceMax  = { type = "number",  default = 0.35, min = 0, max = 1 },
        descriptionKey = { type = "string",  default = "" },
        enabled        = { type = "boolean", default = true },
    }
}
