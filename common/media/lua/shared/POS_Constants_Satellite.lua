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
POS_Constants.SIGINT_XP_SATELLITE_BROADCAST  = 3

---------------------------------------------------------------
-- Broadcast modes (Tier IV — 5 modes per design doc §5)
---------------------------------------------------------------

POS_Constants.SAT_MODE_SCARCITY      = "scarcity_alert"
POS_Constants.SAT_MODE_SURPLUS       = "surplus_notice"
POS_Constants.SAT_MODE_ROUTE_WARNING = "route_warning"
POS_Constants.SAT_MODE_CONTACT       = "contact_bulletin"
POS_Constants.SAT_MODE_RUMOUR        = "strategic_rumour"

-- Ordered list for UI display
POS_Constants.SAT_MODES = {
    POS_Constants.SAT_MODE_SCARCITY,
    POS_Constants.SAT_MODE_SURPLUS,
    POS_Constants.SAT_MODE_ROUTE_WARNING,
    POS_Constants.SAT_MODE_CONTACT,
    POS_Constants.SAT_MODE_RUMOUR,
}

-- Mode → display name translation key
POS_Constants.SAT_MODE_KEYS = {
    [POS_Constants.SAT_MODE_SCARCITY]      = "UI_POS_Satellite_Mode_Scarcity",
    [POS_Constants.SAT_MODE_SURPLUS]       = "UI_POS_Satellite_Mode_Surplus",
    [POS_Constants.SAT_MODE_ROUTE_WARNING] = "UI_POS_Satellite_Mode_RouteWarning",
    [POS_Constants.SAT_MODE_CONTACT]       = "UI_POS_Satellite_Mode_Contact",
    [POS_Constants.SAT_MODE_RUMOUR]        = "UI_POS_Satellite_Mode_Rumour",
}

-- Mode → WBN event type mapping (for WBN bridge)
POS_Constants.SAT_MODE_EVENT_MAP = {
    [POS_Constants.SAT_MODE_SCARCITY]      = "scarcity_alert",
    [POS_Constants.SAT_MODE_SURPLUS]       = "surplus_notice",
    [POS_Constants.SAT_MODE_ROUTE_WARNING] = "route_warning",
    [POS_Constants.SAT_MODE_CONTACT]       = "contact_bulletin",
    [POS_Constants.SAT_MODE_RUMOUR]        = "strategic_rumour",
}

-- Mode → WBN direction mapping
POS_Constants.SAT_MODE_DIRECTION = {
    [POS_Constants.SAT_MODE_SCARCITY]      = "up",
    [POS_Constants.SAT_MODE_SURPLUS]       = "down",
    [POS_Constants.SAT_MODE_ROUTE_WARNING] = "mixed",
    [POS_Constants.SAT_MODE_CONTACT]       = "stable",
    [POS_Constants.SAT_MODE_RUMOUR]        = "mixed",
}

-- Mode → WBN cause tag mapping
POS_Constants.SAT_MODE_CAUSE = {
    [POS_Constants.SAT_MODE_SCARCITY]      = "scarcity",
    [POS_Constants.SAT_MODE_SURPLUS]       = "surplus",
    [POS_Constants.SAT_MODE_ROUTE_WARNING] = "convoy_loss",
    [POS_Constants.SAT_MODE_CONTACT]       = "recovery",
    [POS_Constants.SAT_MODE_RUMOUR]        = "panic",
}

-- Trust impact per mode (positive = trust gain, negative = trust loss)
POS_Constants.SAT_TRUST_IMPACT = {
    [POS_Constants.SAT_MODE_SCARCITY]      =  0.03,
    [POS_Constants.SAT_MODE_SURPLUS]       =  0.02,
    [POS_Constants.SAT_MODE_ROUTE_WARNING] =  0.01,
    [POS_Constants.SAT_MODE_CONTACT]       =  0.04,
    [POS_Constants.SAT_MODE_RUMOUR]        = -0.08,  -- trust risk!
}

-- Trust initial value for new zones
POS_Constants.SAT_TRUST_INITIAL = 0.50
-- Trust bounds
POS_Constants.SAT_TRUST_MIN     = 0.0
POS_Constants.SAT_TRUST_MAX     = 1.0
-- Trust ModData key prefix
POS_Constants.SAT_TRUST_KEY_PREFIX = "POS_SatTrust_"

-- Broadcast history ModData key
POS_Constants.SAT_HISTORY_KEY      = "POS_SatBroadcastHistory"
POS_Constants.SAT_HISTORY_MAX      = 10

---------------------------------------------------------------
-- Active Satellite Scanning (Tier IV/V reconnaissance)
---------------------------------------------------------------

-- Scan cycle timing (game seconds)
POS_Constants.SAT_SCAN_CYCLE_SECONDS_BASE    = 30   -- base seconds per scan cycle
POS_Constants.SAT_SCAN_CYCLE_SIGINT_REDUCTION = 2   -- seconds faster per SIGINT level
POS_Constants.SAT_SCAN_CYCLE_MIN_SECONDS     = 15   -- minimum cycle duration (floor)

-- Buffer and session limits
POS_Constants.SAT_SCAN_BUFFER_MAX            = 40   -- max chunks before buffer full
POS_Constants.SAT_SCAN_SESSION_MODDATA_KEY   = "POS_SatScanSession"

-- Power consumption during active scanning
POS_Constants.SAT_SCAN_POWER_DRAIN           = 1.2  -- additional kW/h draw

-- Confidence for satellite intercepts (BPS — higher than handheld)
POS_Constants.SAT_SCAN_CONFIDENCE_BASE       = 6000

-- Rare discovery system
POS_Constants.SAT_SCAN_RARE_BASE_CHANCE      = 0.01  -- 1% base per cycle
POS_Constants.SAT_SCAN_RARE_SIGINT_BONUS     = 0.005 -- +0.5% per SIGINT level
POS_Constants.SAT_SCAN_RARE_MAX_CHANCE       = 0.10  -- 10% cap

-- SIGINT XP from active scanning
POS_Constants.SIGINT_XP_SATELLITE_SCAN_CHUNK    = 1
POS_Constants.SIGINT_XP_SATELLITE_SCAN_DISCOVERY = 5

-- Satellite discovery types
POS_Constants.SAT_DISCOVERY_CONVOY          = "convoy_route"
POS_Constants.SAT_DISCOVERY_CACHE           = "supply_cache"
POS_Constants.SAT_DISCOVERY_FACTION         = "faction_movement"
POS_Constants.SAT_DISCOVERY_ENCRYPTED       = "encrypted_transmission"
POS_Constants.SAT_DISCOVERY_INFRASTRUCTURE  = "infrastructure_assessment"
POS_Constants.SAT_DISCOVERY_SUPPLY_DROP     = "supply_drop_schedule"

-- Discovery type list (for random selection)
POS_Constants.SAT_DISCOVERY_TYPES = {
    POS_Constants.SAT_DISCOVERY_CONVOY,
    POS_Constants.SAT_DISCOVERY_CACHE,
    POS_Constants.SAT_DISCOVERY_FACTION,
    POS_Constants.SAT_DISCOVERY_ENCRYPTED,
    POS_Constants.SAT_DISCOVERY_INFRASTRUCTURE,
    POS_Constants.SAT_DISCOVERY_SUPPLY_DROP,
}

-- Discovery type → translation key
POS_Constants.SAT_DISCOVERY_KEYS = {
    [POS_Constants.SAT_DISCOVERY_CONVOY]          = "UI_POS_SatScan_Discovery_Convoy",
    [POS_Constants.SAT_DISCOVERY_CACHE]           = "UI_POS_SatScan_Discovery_Cache",
    [POS_Constants.SAT_DISCOVERY_FACTION]         = "UI_POS_SatScan_Discovery_Faction",
    [POS_Constants.SAT_DISCOVERY_ENCRYPTED]       = "UI_POS_SatScan_Discovery_Encrypted",
    [POS_Constants.SAT_DISCOVERY_INFRASTRUCTURE]  = "UI_POS_SatScan_Discovery_Infrastructure",
    [POS_Constants.SAT_DISCOVERY_SUPPLY_DROP]     = "UI_POS_SatScan_Discovery_SupplyDrop",
}

-- Encrypted discovery SIGINT gate
POS_Constants.SAT_DISCOVERY_ENCRYPTED_SIGINT_MIN = 6

-- New chunk types for satellite scanning
POS_Constants.CHUNK_TYPE_SATELLITE_INTERCEPT = "satellite_intercept"
POS_Constants.CHUNK_TYPE_SATELLITE_DISCOVERY = "satellite_discovery"

-- Screen ID
POS_Constants.SCREEN_SATELLITE_SCAN = "pos.network.satellite_scan"
