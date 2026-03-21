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

-- ============================================================================
-- Zone Definition Template
-- ============================================================================
-- Copy this file and rename it to create a new market zone.
-- Place the new file in this same directory (Definitions/Zones/).
--
-- The loader discovers all .lua files in this folder automatically.
-- Files starting with "_" are ignored by the loader.
--
-- All fields are validated against POS_ZoneSchema.lua at load time.
-- ============================================================================

return {
    -- Schema version (must be 1 for current format)
    schemaVersion = 1,

    -- Unique identifier for this zone (must be unique across all zones)
    id = "my_zone",

    -- Display name shown in the terminal UI
    name = "My Custom Zone",

    -- Short description of the zone's character and trade environment
    description = "A brief description of this zone.",

    -- Base price volatility for this zone (0.0 = perfectly stable, 2.0 = extreme swings)
    -- Typical range: 0.15 (stable) to 0.30 (volatile)
    baseVolatility = 0.20,

    -- Population density affects demand volume and trader frequency.
    -- Valid values: "sparse", "medium", "dense"
    population = "medium",

    -- List of zone IDs that border this zone for trade route calculations.
    -- Must reference valid zone IDs defined in other zone files.
    adjacentZones = {},

    -- Set to true to activate this zone. Templates ship disabled.
    enabled = false,
}
