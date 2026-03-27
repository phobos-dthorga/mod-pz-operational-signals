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
-- POS_Constants_Relay.lua
-- Constants for Tier V Strategic Relay system.
-- Separate from POS_Constants_Satellite.lua (Tier IV).
---------------------------------------------------------------

require "POS_Constants"

---------------------------------------------------------------
-- Tier V Strategic Relay constants
---------------------------------------------------------------

-- Relay dish sprites — large commercial/institutional satellite dishes
-- found on civic building rooftops (fire stations, police stations, etc.).
-- These are DISTINCT from Tier IV portable dishes (appliances_com_01_20/21).
-- Verified against PZ Build 42 map data: _36/_37/_38 appear in 29 locations
-- (multi-tile satellite dish assembly). _39 has zero placements.
POS_Constants.RELAY_DISH_SPRITES = {
    "appliances_com_01_36",   -- large commercial dish tile (part of multi-tile assembly)
    "appliances_com_01_37",   -- large commercial dish tile (part of multi-tile assembly)
    "appliances_com_01_38",   -- large commercial dish tile (part of multi-tile assembly)
}

-- Building types that can host relay sites (PZ room definitions)
POS_Constants.RELAY_BUILDING_TYPES = {
    "firestation", "policestation", "armysurplus",
    "militarybase", "radiostation", "hospital",
    "warehouse", "factory",
}

-- Facility state model
POS_Constants.RELAY_MODDATA_PREFIX        = "POS_Relay_"
POS_Constants.RELAY_REGISTRY_KEY          = "POS_RelayRegistry"

-- Calibration
POS_Constants.RELAY_CALIBRATION_INITIAL   = 0.0   -- uncalibrated on discovery
POS_Constants.RELAY_CALIBRATION_MAX       = 1.0
POS_Constants.RELAY_CALIBRATION_DRIFT_PER_DAY = 0.02  -- -0.02 per game day
POS_Constants.RELAY_CALIBRATION_SPEED_BASE = 0.05  -- calibration gain per tick
POS_Constants.RELAY_CALIBRATION_SPEED_SIGINT_BONUS = 0.005  -- +0.005 per SIGINT level
POS_Constants.RELAY_CALIBRATION_MIN_OPERATIONAL = 0.30  -- below this, relay is offline
POS_Constants.RELAY_CALIBRATION_DEGRADED_THRESHOLD = 0.60  -- below this, degraded ops

-- Power draw (kW/h)
POS_Constants.RELAY_POWER_IDLE            = 0.05
POS_Constants.RELAY_POWER_ACTIVE          = 0.20
POS_Constants.RELAY_POWER_SWEEP           = 0.50
POS_Constants.RELAY_POWER_CALIBRATING     = 0.15

-- Bandwidth modes
POS_Constants.RELAY_BW_BALANCED           = "balanced"
POS_Constants.RELAY_BW_MARKETS            = "markets"
POS_Constants.RELAY_BW_AGENTS             = "agents"
POS_Constants.RELAY_BW_OPERATIONS         = "operations"
POS_Constants.RELAY_BW_INTERCEPTS         = "intercepts"

POS_Constants.RELAY_BW_MODES = {
    POS_Constants.RELAY_BW_BALANCED,
    POS_Constants.RELAY_BW_MARKETS,
    POS_Constants.RELAY_BW_AGENTS,
    POS_Constants.RELAY_BW_OPERATIONS,
    POS_Constants.RELAY_BW_INTERCEPTS,
}

-- Mode -> translation key
POS_Constants.RELAY_BW_MODE_KEYS = {
    [POS_Constants.RELAY_BW_BALANCED]   = "UI_POS_Relay_BW_Balanced",
    [POS_Constants.RELAY_BW_MARKETS]    = "UI_POS_Relay_BW_Markets",
    [POS_Constants.RELAY_BW_AGENTS]     = "UI_POS_Relay_BW_Agents",
    [POS_Constants.RELAY_BW_OPERATIONS] = "UI_POS_Relay_BW_Operations",
    [POS_Constants.RELAY_BW_INTERCEPTS] = "UI_POS_Relay_BW_Intercepts",
}

-- Mode -> power multiplier (multiplied with RELAY_POWER_ACTIVE)
POS_Constants.RELAY_BW_POWER_MULT = {
    [POS_Constants.RELAY_BW_BALANCED]   = 1.0,
    [POS_Constants.RELAY_BW_MARKETS]    = 0.8,
    [POS_Constants.RELAY_BW_AGENTS]     = 1.2,
    [POS_Constants.RELAY_BW_OPERATIONS] = 1.0,
    [POS_Constants.RELAY_BW_INTERCEPTS] = 2.5,  -- intercepts are expensive
}

-- Wiring (Tier V REQUIRES wired link -- no wireless fallback for remote ops)
POS_Constants.RELAY_WIRED_REQUIRED        = true
POS_Constants.RELAY_WIRING_RANGE_MAX      = 150  -- tiles (larger than Tier IV's 100)

-- Discovery
POS_Constants.RELAY_DISCOVERY_RANGE       = 5  -- tiles from dish to trigger discovery
POS_Constants.RELAY_DISCOVERY_SIGINT_MIN  = 0  -- no SIGINT requirement to discover

-- Network health thresholds
POS_Constants.RELAY_HEALTH_EXCELLENT      = 0.80
POS_Constants.RELAY_HEALTH_GOOD           = 0.60
POS_Constants.RELAY_HEALTH_DEGRADED       = 0.40
POS_Constants.RELAY_HEALTH_CRITICAL       = 0.20

-- SIGINT XP
POS_Constants.SIGINT_XP_RELAY_DISCOVER    = 5
POS_Constants.SIGINT_XP_RELAY_CALIBRATE   = 3
POS_Constants.SIGINT_XP_RELAY_BROADCAST   = 4

-- Screen ID
POS_Constants.SCREEN_RELAY_COMMAND        = "pos.network.relay_command"

-- Tick intervals (game minutes)
POS_Constants.RELAY_TICK_INTERVAL         = 10  -- relay ticks every 10 game minutes
POS_Constants.RELAY_CALIBRATION_TICK      = 1   -- calibration progress ticks every minute
