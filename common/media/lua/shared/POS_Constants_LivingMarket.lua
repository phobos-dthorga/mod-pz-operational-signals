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
-- POS_Constants_LivingMarket.lua
-- Living Market Layer 0 economy: agent archetypes, wholesaler
-- states, market zones, events, simulation tuning, signal
-- emission, rumour system, field notes.
---------------------------------------------------------------

require "POS_Constants"

---------------------------------------------------------------
-- Living Market: Agent Archetypes
---------------------------------------------------------------

POS_Constants.AGENT_ARCHETYPE_SCAVENGER            = "scavenger_trader"
POS_Constants.AGENT_ARCHETYPE_QUARTERMASTER        = "quartermaster"
POS_Constants.AGENT_ARCHETYPE_WHOLESALER           = "wholesaler"
POS_Constants.AGENT_ARCHETYPE_SMUGGLER             = "smuggler"
POS_Constants.AGENT_ARCHETYPE_MILITARY_LOGISTICIAN = "military_logistician"
POS_Constants.AGENT_ARCHETYPE_SPECULATOR           = "speculator"
POS_Constants.AGENT_ARCHETYPE_SPECIALIST_CRAFTER   = "specialist_crafter"

--- Archetype profiles and category affinities are loaded from
--- data-only Lua definition files in Definitions/Archetypes/.
--- See POS_MarketAgent.lua and POS_ArchetypeSchema.lua.

---------------------------------------------------------------
-- Living Market: Zone Agent Composition
-- Defines which archetypes spawn per zone based on population.
-- See living-market-design.md § Regional Composition Examples.
---------------------------------------------------------------

POS_Constants.ZONE_AGENT_COMPOSITION = {
    sparse = {
        { archetype = "scavenger_trader", count = 2 },
        { archetype = "quartermaster",    count = 1 },
        { archetype = "specialist_crafter", count = 1 },
    },
    medium = {
        { archetype = "scavenger_trader", count = 1 },
        { archetype = "quartermaster",    count = 1 },
        { archetype = "wholesaler",       count = 1 },
        { archetype = "smuggler",         count = 1 },
        { archetype = "specialist_crafter", count = 1 },
    },
    dense = {
        { archetype = "wholesaler",            count = 2 },
        { archetype = "quartermaster",         count = 2 },
        { archetype = "smuggler",              count = 2 },
        { archetype = "speculator",            count = 1 },
        { archetype = "military_logistician",  count = 1 },
    },
}

---------------------------------------------------------------
-- Living Market: Wholesaler Operational States
---------------------------------------------------------------

POS_Constants.WHOLESALER_STATE_STABLE      = "stable"
POS_Constants.WHOLESALER_STATE_TIGHT       = "tight"
POS_Constants.WHOLESALER_STATE_STRAINED    = "strained"
POS_Constants.WHOLESALER_STATE_DUMPING     = "dumping"
POS_Constants.WHOLESALER_STATE_WITHHOLDING = "withholding"
POS_Constants.WHOLESALER_STATE_COLLAPSING  = "collapsing"

---------------------------------------------------------------
-- Living Market: Market Zones
---------------------------------------------------------------

POS_Constants.MARKET_ZONE_MULDRAUGH          = "muldraugh"
POS_Constants.MARKET_ZONE_WEST_POINT         = "west_point"
POS_Constants.MARKET_ZONE_RIVERSIDE          = "riverside"
POS_Constants.MARKET_ZONE_LOUISVILLE_EDGE    = "louisville_edge"
POS_Constants.MARKET_ZONE_MILITARY_CORRIDOR  = "military_corridor"
POS_Constants.MARKET_ZONE_RURAL_EAST         = "rural_east"

--- Ordered array of all market zone IDs (Phase 1 set).
POS_Constants.MARKET_ZONES = {
    POS_Constants.MARKET_ZONE_MULDRAUGH,
    POS_Constants.MARKET_ZONE_WEST_POINT,
    POS_Constants.MARKET_ZONE_RIVERSIDE,
    POS_Constants.MARKET_ZONE_LOUISVILLE_EDGE,
    POS_Constants.MARKET_ZONE_MILITARY_CORRIDOR,
    POS_Constants.MARKET_ZONE_RURAL_EAST,
}

-- Zone ID → translation key suffix mapping.
-- Zone IDs are snake_case; translation keys use PascalCase.
-- Usage: PhobosLib.safeGetText("UI_POS_Zone_" .. ZONE_DISPLAY_KEY[zoneId])
POS_Constants.ZONE_DISPLAY_KEY = {
    [POS_Constants.MARKET_ZONE_MULDRAUGH]         = "Muldraugh",
    [POS_Constants.MARKET_ZONE_WEST_POINT]        = "WestPoint",
    [POS_Constants.MARKET_ZONE_RIVERSIDE]          = "Riverside",
    [POS_Constants.MARKET_ZONE_LOUISVILLE_EDGE]   = "LouisvilleEdge",
    [POS_Constants.MARKET_ZONE_MILITARY_CORRIDOR] = "MilitaryCorridor",
    [POS_Constants.MARKET_ZONE_RURAL_EAST]        = "RuralEast",
}

---------------------------------------------------------------
-- Living Market: Event Types
---------------------------------------------------------------

POS_Constants.MARKET_EVENT_BULK_ARRIVAL       = "bulk_arrival"
POS_Constants.MARKET_EVENT_CONVOY_DELAY       = "convoy_delay"
POS_Constants.MARKET_EVENT_THEFT_RAID         = "theft_raid"
POS_Constants.MARKET_EVENT_CONTROLLED_RELEASE = "controlled_release"
POS_Constants.MARKET_EVENT_WITHHOLDING        = "strategic_withholding"
POS_Constants.MARKET_EVENT_REQUISITION        = "requisition_diversion"

---------------------------------------------------------------
-- Living Market: Signal Classes
---------------------------------------------------------------

POS_Constants.SIGNAL_CLASS_HARD       = "hard"
POS_Constants.SIGNAL_CLASS_SOFT       = "soft"
POS_Constants.SIGNAL_CLASS_STRUCTURAL = "structural"

---------------------------------------------------------------
-- Living Market: Event Service
---------------------------------------------------------------

POS_Constants.EVENT_PROBABILITY_MULTIPLIER  = 1.0   -- sandbox-scalable
POS_Constants.EVENT_MAX_ACTIVE_PER_ZONE     = 3
POS_Constants.EVENT_COOLDOWN_DAYS           = 2     -- min days between events per zone
POS_Constants.EVENT_DEFAULT_DURATION_DAYS   = 3
POS_Constants.EVENT_MAX_RECENT              = 30    -- rolling recent events log cap
POS_Constants.EVENT_PRESSURE_CLAMP_MIN      = -1.0
POS_Constants.EVENT_PRESSURE_CLAMP_MAX      = 1.0

---------------------------------------------------------------
-- Living Market: Simulation Defaults
---------------------------------------------------------------

POS_Constants.SIMULATION_TICK_INTERVAL_DEFAULT    = 20
POS_Constants.SIMULATION_PRESSURE_CLAMP_MIN       = -2.0
POS_Constants.SIMULATION_PRESSURE_CLAMP_MAX       = 2.0
POS_Constants.SIMULATION_THROUGHPUT_FACTOR         = 0.5
POS_Constants.SIMULATION_ZONE_DEFAULT_VOLATILITY   = 0.20

-- Save migration
POS_Constants.MARKET_SCHEMA_VERSION = 1

-- Economy tick interval
POS_Constants.ECONOMY_TICK_INTERVAL_HOURS_DEFAULT = 24

---------------------------------------------------------------
-- Living Market: Natural Drift Rates (per tick)
---------------------------------------------------------------

POS_Constants.SIMULATION_PRESSURE_DECAY_RATE       = 0.15
POS_Constants.SIMULATION_DISRUPTION_DECAY_RATE     = 0.10
POS_Constants.SIMULATION_STOCK_REPLENISH_RATE      = 0.05

---------------------------------------------------------------
-- Living Market: Demand Pull (per population tier)
---------------------------------------------------------------

POS_Constants.SIMULATION_DEMAND_PULL = {
    sparse = 0.02,
    medium = 0.04,
    dense  = 0.07,
}

--- Essential categories subject to demand pull each tick.
POS_Constants.SIMULATION_ESSENTIAL_CATEGORIES = {
    "food", "medicine", "fuel",
}

---------------------------------------------------------------
-- Living Market: Wholesaler State Machine Thresholds
---------------------------------------------------------------

POS_Constants.WHOLESALER_PRESSURE_TIGHT_THRESHOLD       = 0.30
POS_Constants.WHOLESALER_PRESSURE_STRAINED_THRESHOLD    = 0.60
POS_Constants.WHOLESALER_DISRUPTION_STRAINED_THRESHOLD  = 0.40
POS_Constants.WHOLESALER_DISRUPTION_COLLAPSING_THRESHOLD = 0.70
POS_Constants.WHOLESALER_STOCK_COLLAPSING_THRESHOLD     = 0.15
POS_Constants.WHOLESALER_STOCK_WITHHOLDING_FLOOR        = 0.50

---------------------------------------------------------------
-- Living Market: Wholesaler Property Bounds
---------------------------------------------------------------

POS_Constants.WHOLESALER_STOCK_MIN      = 0.0
POS_Constants.WHOLESALER_STOCK_MAX      = 1.0
POS_Constants.WHOLESALER_PRESSURE_MIN   = 0.0
POS_Constants.WHOLESALER_PRESSURE_MAX   = 1.0
POS_Constants.WHOLESALER_DISRUPTION_MIN = 0.0
POS_Constants.WHOLESALER_DISRUPTION_MAX = 1.0

---------------------------------------------------------------
-- Living Market: Event Effects
---------------------------------------------------------------

POS_Constants.SIMULATION_EVENT_PROBABILITY_MULT        = 1.0
POS_Constants.EVENT_STOCK_EFFECT_BULK_ARRIVAL           = 0.20
POS_Constants.EVENT_STOCK_EFFECT_THEFT_RAID             = -0.15
POS_Constants.EVENT_STOCK_EFFECT_CONTROLLED_RELEASE     = 0.10
POS_Constants.EVENT_STOCK_EFFECT_REQUISITION            = -0.10
POS_Constants.EVENT_DISRUPTION_THEFT_RAID               = 0.25
POS_Constants.EVENT_DISRUPTION_REQUISITION              = 0.15

---------------------------------------------------------------
-- Living Market: Downstream Influence
---------------------------------------------------------------

POS_Constants.WHOLESALER_DOWNSTREAM_DELAY_DAYS = 2

---------------------------------------------------------------
-- Living Market: Convoy Mechanics
---------------------------------------------------------------

POS_Constants.CONVOY_OVERDUE_TOLERANCE_DAYS = 1

---------------------------------------------------------------
-- Living Market: All Commodity Category IDs
---------------------------------------------------------------

POS_Constants.MARKET_CATEGORIES = {
    "food", "medicine", "ammunition", "fuel", "tools", "radio", "weapons", "vehicles",
}

---------------------------------------------------------------
-- Living Market: Agent Meter Rates (per tick)
---------------------------------------------------------------

POS_Constants.AGENT_PRESSURE_APPROACH_RATE   = 0.20
POS_Constants.AGENT_GREED_VOLATILITY_FACTOR  = 0.10
POS_Constants.AGENT_EXPOSURE_DECAY_RATE      = 0.08
POS_Constants.AGENT_SURPLUS_APPROACH_RATE    = 0.15
POS_Constants.AGENT_TRUST_DECAY_RATE         = 0.05

-- Agent observation generation
POS_Constants.AGENT_OBS_GREED_THRESHOLD      = 0.5
POS_Constants.AGENT_OBS_GREED_MULTIPLIER     = 0.15
POS_Constants.AGENT_OBS_EXPOSURE_THRESHOLD   = 0.3
POS_Constants.AGENT_OBS_SURPLUS_THRESHOLD    = 0.6
POS_Constants.AGENT_OBS_SURPLUS_MULTIPLIER   = 0.10
POS_Constants.AGENT_OBS_SMUGGLER_INVERSION   = 0.05
POS_Constants.AGENT_OBS_SPECULATOR_MARKUP    = 1.2
POS_Constants.AGENT_OBS_SCAVENGER_NOISE      = 0.20
POS_Constants.AGENT_OBS_DEFAULT_NOISE        = 0.10
POS_Constants.AGENT_OBS_SOURCE_PREFIX        = "agent_"

-- SIGINT XP from market events
POS_Constants.SIGINT_XP_MARKET_EVENT_BASE    = 5
POS_Constants.SIGINT_XP_COLLAPSING_MULT      = 3.0
POS_Constants.SIGINT_XP_WITHHOLDING_MULT     = 2.0
POS_Constants.SIGINT_XP_STRAINED_MULT        = 1.5
POS_Constants.SIGINT_XP_DEFAULT_MULT         = 1.0

-- Passive recon zone pressure
POS_Constants.RECON_PRESSURE_NOISE_MIN       = 0.05
POS_Constants.RECON_PRESSURE_NOISE_MAX       = 0.30

---------------------------------------------------------------
-- Living Market: Simulation Tuning
---------------------------------------------------------------

POS_Constants.SIMULATION_PRESSURE_DECAY_RATE       = 0.12
POS_Constants.SIMULATION_DISRUPTION_DECAY_RATE     = 0.08
POS_Constants.SIMULATION_STOCK_REPLENISH_RATE      = 0.10
POS_Constants.SIMULATION_EVENT_PROBABILITY_MULT    = 1.0

POS_Constants.SIMULATION_DEMAND_PULL = {
    low    = 0.02,
    medium = 0.05,
    high   = 0.10,
    dense  = 0.15,
}

POS_Constants.SIMULATION_ESSENTIAL_CATEGORIES = {
    "food", "medicine", "fuel",
}

---------------------------------------------------------------
-- Living Market: Event Effects
---------------------------------------------------------------

POS_Constants.EVENT_STOCK_EFFECT_BULK_ARRIVAL       =  0.25
POS_Constants.EVENT_STOCK_EFFECT_THEFT_RAID         = -0.20
POS_Constants.EVENT_STOCK_EFFECT_CONTROLLED_RELEASE =  0.15
POS_Constants.EVENT_STOCK_EFFECT_REQUISITION        = -0.30
POS_Constants.EVENT_DISRUPTION_THEFT_RAID           =  0.15
POS_Constants.EVENT_DISRUPTION_REQUISITION          =  0.25

---------------------------------------------------------------
-- Living Market: Wholesaler Stock Bounds
---------------------------------------------------------------

POS_Constants.WHOLESALER_STOCK_MIN = 0.0
POS_Constants.WHOLESALER_STOCK_MAX = 1.0

---------------------------------------------------------------
-- Living Market: World ModData
---------------------------------------------------------------

POS_Constants.WMD_MARKET_ZONES = "POSNET.MarketZones"

---------------------------------------------------------------
-- Living Market: Signal Emission
---------------------------------------------------------------

-- State -> price multiplier applied to category base price
POS_Constants.WHOLESALER_PRICE_MULTIPLIER = {
    [POS_Constants.WHOLESALER_STATE_STABLE]      = 1.00,
    [POS_Constants.WHOLESALER_STATE_TIGHT]       = 1.05,
    [POS_Constants.WHOLESALER_STATE_STRAINED]    = 1.15,
    [POS_Constants.WHOLESALER_STATE_DUMPING]     = 0.75,
    [POS_Constants.WHOLESALER_STATE_WITHHOLDING] = 1.25,
    [POS_Constants.WHOLESALER_STATE_COLLAPSING]  = 1.40,
}

-- Category base prices ("average street price" per category).
POS_Constants.CATEGORY_BASE_PRICE = {
    food          = 120,
    medicine      = 150,
    ammunition    = 70,
    fuel          = 160,
    tools         = 100,
    radio         = 180,
    weapons       = 250,
    survival      = 80,
    clothing      = 60,
    literature    = 40,
    miscellaneous = 50,
    chemicals     = 45,
    agriculture   = 20,
    biofuel       = 120,
    specimens     = 200,
    biohazard     = 300,
    vehicles      = 180,
}

-- Price noise range (+/-%) applied to each emitted observation
POS_Constants.SIGNAL_PRICE_NOISE = 0.10

-- Stock level tiers for PhobosLib.getQualityTier()
-- Maps stockLevel (0-100 after x100) to display bucket
POS_Constants.STOCK_LEVEL_TIERS = {
    { name = "UI_POS_Stock_Abundant", min = 70 },
    { name = "UI_POS_Stock_Moderate", min = 40 },
    { name = "UI_POS_Stock_Low",     min = 20 },
    { name = "UI_POS_Stock_Scarce",  min = 0 },
}

-- Confidence tiers for PhobosLib.getQualityTier()
-- Maps reliability (0-100 after x100) to confidence string
POS_Constants.CONFIDENCE_TIERS = {
    { name = "high",   min = 70 },
    { name = "medium", min = 40 },
    { name = "low",    min = 0 },
}

-- Record ID prefix for Living Market observations
POS_Constants.SIGNAL_RECORD_PREFIX = "lm_"

-- Rumour system
POS_Constants.RUMOUR_MAX_ACTIVE     = 20
POS_Constants.RUMOUR_EXPIRY_DAYS    = 7
POS_Constants.RUMOUR_CONFIDENCE     = "low"
POS_Constants.RUMOUR_SOURCE_TIER    = "field"
POS_Constants.RUMOUR_KEY_PREFIX     = "POS_Rumour_"
POS_Constants.WMD_RUMOURS           = "POSNET.Rumours"
POS_Constants.NOTE_TYPE_MARKET      = "market"
POS_Constants.NOTE_TYPE_RUMOUR      = "rumour"
POS_Constants.SCREEN_BBS_RUMOURS    = "pos.bbs.rumours"

-- Rumour impact directions
POS_Constants.RUMOUR_IMPACT_SHORTAGE   = "shortage"
POS_Constants.RUMOUR_IMPACT_SURPLUS    = "surplus"
POS_Constants.RUMOUR_IMPACT_DISRUPTION = "disruption"

-- Rumour event message key lookup
POS_Constants.RUMOUR_EVENT_KEYS = {
    bulk_arrival           = "UI_POS_Rumour_BulkArrival",
    convoy_delay           = "UI_POS_Rumour_ConvoyDelay",
    theft_raid             = "UI_POS_Rumour_TheftRaid",
    controlled_release     = "UI_POS_Rumour_ControlledRelease",
    strategic_withholding  = "UI_POS_Rumour_StrategicWithholding",
    requisition_diversion  = "UI_POS_Rumour_Requisition",
}

-- Rumour impact hint key lookup
POS_Constants.RUMOUR_IMPACT_KEYS = {
    shortage   = "UI_POS_Rumour_ShortageExpected",
    surplus    = "UI_POS_Rumour_SurplusExpected",
    disruption = "UI_POS_Rumour_DisruptionReported",
}

---------------------------------------------------------------
-- Living Market: Field Notes from State Transitions (Phase 7C)
---------------------------------------------------------------

--- States that trigger field note generation on transition.
POS_Constants.FIELD_NOTE_STATES = { "collapsing", "dumping" }

--- Per-wholesaler modData key storing the last day a note was generated.
POS_Constants.FIELD_NOTE_COOLDOWN_KEY = "_lastNoteDay"
