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
-- POS_Constants_Satellite.lua
-- Satellite uplink, wiring, power, sprites, SIGINT XP for
-- Tier IV broadcast operations.
---------------------------------------------------------------

require "POS_Constants"

---------------------------------------------------------------
-- Satellite Uplink (Tier IV -- Broadcast)
---------------------------------------------------------------

POS_Constants.SATELLITE_VISIT_KEY_PREFIX       = "POS_SatelliteVisit_"
POS_Constants.SATELLITE_CALIBRATED_KEY_PREFIX  = "POS_SatelliteCalibrated_"
POS_Constants.SATELLITE_LINK_RANGE             = 50   -- tiles
POS_Constants.SATELLITE_BROADCAST_COOLDOWN_DEFAULT = 24  -- hours
POS_Constants.SATELLITE_CALIBRATION_TIME_DEFAULT   = 300 -- seconds
POS_Constants.SATELLITE_BROADCAST_TIME_DEFAULT     = 120 -- seconds
POS_Constants.SATELLITE_DECALIBRATION_DAYS         = 7

-- Broadcast reputation values (hundredths of rep point)
POS_Constants.SATELLITE_REP_SURVEY             = 30
POS_Constants.SATELLITE_REP_REPORT             = 50
POS_Constants.SATELLITE_REP_BULLETIN           = 100

-- Staleness multipliers (per artifact tier)
POS_Constants.SATELLITE_STALENESS_SURVEY       = 1.5
POS_Constants.SATELLITE_STALENESS_REPORT       = 2.0
POS_Constants.SATELLITE_STALENESS_BULLETIN     = 2.5

-- Power management
POS_Constants.SATELLITE_FUEL_DRAIN_CALIBRATE   = 0.05
POS_Constants.SATELLITE_FUEL_DRAIN_BROADCAST   = 0.10
POS_Constants.SATELLITE_LOW_FUEL_THRESHOLD     = 0.20
POS_Constants.SATELLITE_LOW_FUEL_PENALTY       = 0.25

-- Satellite Wiring
POS_Constants.SATELLITE_WIRING_ITEM              = "Base.ElectricWire"
POS_Constants.SATELLITE_WIRING_TOOL_SCREWDRIVER  = "Base.Screwdriver"
POS_Constants.SATELLITE_WIRING_TOOL_PLIERS       = "Base.Pliers"
POS_Constants.SATELLITE_WIRING_MIN_ELECTRICAL    = 2
POS_Constants.SATELLITE_WIRING_MAX_RANGE_DEFAULT = 100
POS_Constants.SATELLITE_WIRING_Z_PENALTY         = 5
POS_Constants.SATELLITE_WIRING_KEY_PREFIX        = "POS_SatelliteWiring_"
POS_Constants.SATELLITE_WIRING_TIME_PER_TILE     = 3
POS_Constants.SATELLITE_WIRING_TIME_MIN          = 30
POS_Constants.SATELLITE_WIRING_TIME_MAX          = 600
POS_Constants.SATELLITE_WIRING_RETURN_PCT        = 75
POS_Constants.SATELLITE_DISCONNECT_TIME          = 60
POS_Constants.SATELLITE_LINK_TYPE_WIRED          = "hardwired_satellite"

-- Satellite dish sprites (vanilla satellite dish, 2 rotations)
POS_Constants.SATELLITE_DISH_SPRITES           = {
    "appliances_com_01_20",
    "appliances_com_01_21",
}

-- Equipment condition threshold for bonus
POS_Constants.SATELLITE_DISH_CONDITION_BONUS_MIN = 80

-- SIGINT XP from satellite operations
POS_Constants.SIGINT_XP_SATELLITE_CALIBRATE  = 2
