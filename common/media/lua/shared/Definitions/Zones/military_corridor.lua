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
    id = "military_corridor",
    name = "Military Corridor",
    displayNameKey = "UI_POS_Zone_MilitaryCorridor",
    description = "Heavily patrolled supply route with controlled distribution.",
    baseVolatility = 0.15,
    population = "sparse",
    adjacentZones = { "louisville_edge", "rural_east" },
    luxuryDemand = 0.3,   -- military cares about gear, not gold
}
