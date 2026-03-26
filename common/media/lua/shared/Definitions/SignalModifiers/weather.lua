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
-- Definitions/SignalModifiers/weather.lua
-- Weather-related signal propagation modifiers.
-- Returns an array of records for PhobosLib.loadDefinition().
---------------------------------------------------------------

return {
    {
        schemaVersion = 1,
        id = "rain_moderate",
        pillar = "propagation",
        trigger = "rain_moderate",
        propagation = -0.10,
        noise = 0.05,
        severity = 0.3,
        description = "Moderate rain degrades signal propagation",
    },
    {
        schemaVersion = 1,
        id = "rain_heavy",
        pillar = "propagation",
        trigger = "rain_heavy",
        propagation = -0.20,
        noise = 0.10,
        severity = 0.6,
        description = "Heavy rain severely degrades signal propagation",
    },
    {
        schemaVersion = 1,
        id = "storm",
        pillar = "propagation",
        trigger = "storm",
        propagation = -0.25,
        noise = 0.20,
        severity = 0.9,
        description = "Storms cause major signal disruption and noise",
    },
    {
        schemaVersion = 1,
        id = "fog",
        pillar = "propagation",
        trigger = "fog",
        propagation = -0.05,
        noise = 0.03,
        severity = 0.2,
        description = "Fog slightly attenuates signal propagation",
    },
    {
        schemaVersion = 1,
        id = "wind_strong",
        pillar = "propagation",
        trigger = "wind_strong",
        propagation = -0.08,
        noise = 0.02,
        severity = 0.3,
        description = "Strong winds introduce minor signal degradation",
    },
    {
        schemaVersion = 1,
        id = "wind_storm",
        pillar = "propagation",
        trigger = "wind_storm",
        propagation = -0.15,
        noise = 0.08,
        severity = 0.7,
        description = "Storm-force winds cause significant signal interference",
    },
    {
        schemaVersion = 1,
        id = "snow",
        pillar = "propagation",
        trigger = "snow",
        propagation = -0.12,
        noise = 0.04,
        severity = 0.4,
        description = "Snowfall degrades signal propagation",
    },
    {
        schemaVersion = 1,
        id = "clear_skies",
        pillar = "propagation",
        trigger = "clear_skies",
        propagation = 0.05,
        noise = 0,
        severity = 0.0,
        description = "Clear skies provide optimal propagation conditions",
    },
}
