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
-- Definitions/SignalModifiers/infrastructure.lua
-- Power grid and infrastructure signal modifiers.
-- Returns an array of records for PhobosLib.loadDefinition().
---------------------------------------------------------------

return {
    {
        schemaVersion = 1,
        id = "grid_on",
        pillar = "infrastructure",
        trigger = "grid_on",
        infrastructure = 0.20,
        severity = 0.0,
        description = "Grid power is active, boosting infrastructure pillar",
    },
    {
        schemaVersion = 1,
        id = "grid_failing",
        pillar = "infrastructure",
        trigger = "grid_failing",
        infrastructure = 0.05,
        severity = 0.5,
        description = "Grid power is failing, marginal infrastructure benefit",
    },
    {
        schemaVersion = 1,
        id = "grid_off",
        pillar = "infrastructure",
        trigger = "grid_off",
        infrastructure = -0.15,
        severity = 0.8,
        description = "Grid power is offline, significant infrastructure penalty",
    },
    {
        schemaVersion = 1,
        id = "generator_only",
        pillar = "infrastructure",
        trigger = "generator_only",
        infrastructure = -0.05,
        severity = 0.4,
        description = "Running on generator only, minor infrastructure penalty",
    },
}
