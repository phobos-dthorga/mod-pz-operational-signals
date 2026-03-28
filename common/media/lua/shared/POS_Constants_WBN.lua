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
-- POS_Constants_WBN.lua
-- World Broadcast Network constants: frequencies, UUIDs,
-- editorial scoring, thresholds, cadence, colours, domains,
-- event types, archetypes, and phrase keys.
---------------------------------------------------------------

require "POS_Constants"

-- AZAS station keys (registered at module-load time in POS_AZASIntegration)
POS_Constants.AZAS_WBN_MARKET_KEY    = "POSnet_WBN_Market"
POS_Constants.AZAS_WBN_EMERGENCY_KEY = "POSnet_WBN_Emergency"

-- Default fallback frequencies (used when AZAS is unavailable)
POS_Constants.WBN_DEFAULT_FREQ_CIVILIAN_MARKET = 91400
POS_Constants.WBN_DEFAULT_FREQ_EMERGENCY       = 103800

-- Backward-compat aliases (prefer AZAS accessors at runtime)
POS_Constants.WBN_FREQ_CIVILIAN_MARKET = POS_Constants.WBN_DEFAULT_FREQ_CIVILIAN_MARKET
POS_Constants.WBN_FREQ_EMERGENCY       = POS_Constants.WBN_DEFAULT_FREQ_EMERGENCY

-- Channel UUIDs (must be stable for DynamicRadio persistence)
POS_Constants.WBN_UUID_CIVILIAN_MARKET  = "POS-WBN-CMN-01"
POS_Constants.WBN_UUID_EMERGENCY        = "POS-WBN-EBS-01"

-- Channel display name translation keys
POS_Constants.WBN_CHANNEL_NAME_CIVILIAN = "UI_WBN_Channel_CivilianMarket"
POS_Constants.WBN_CHANNEL_NAME_EMERGENCY = "UI_WBN_Channel_Emergency"

-- Station class identifiers
POS_Constants.WBN_STATION_CIVILIAN_MARKET = "civilian_market"
POS_Constants.WBN_STATION_EMERGENCY       = "emergency"

-- Station tag translation keys (prefixed on each bulletin line)
POS_Constants.WBN_TAG_KEY_CIVILIAN = "UI_WBN_StationTag_CMN"
POS_Constants.WBN_TAG_KEY_EMERGENCY = "UI_WBN_StationTag_EBS"

-- Editorial scoring weights (sum = 1.0)
POS_Constants.WBN_SCORE_W_SEVERITY     = 0.35
POS_Constants.WBN_SCORE_W_FRESHNESS    = 0.25
POS_Constants.WBN_SCORE_W_CONFIDENCE   = 0.20
POS_Constants.WBN_SCORE_W_PUBLIC       = 0.10
POS_Constants.WBN_SCORE_W_DOMAIN_BOOST = 0.10

-- Editorial thresholds
POS_Constants.WBN_EDITORIAL_SCORE_FLOOR     = 0.35
POS_Constants.WBN_EDITORIAL_FRESHNESS_FLOOR = 0.3
POS_Constants.WBN_EDITORIAL_REPEAT_WINDOW   = 5  -- suppress same domain+zone+type for N bulletins

-- Broadcast significance thresholds (percentage change)
POS_Constants.WBN_THRESHOLD_IGNORE   = 2   -- |delta| < 2%: never broadcast
POS_Constants.WBN_THRESHOLD_LIGHT    = 3   -- 3-6%: light mention
POS_Constants.WBN_THRESHOLD_NORMAL   = 7   -- 7-12%: normal bulletin
POS_Constants.WBN_THRESHOLD_STRONG   = 13  -- 13-20%: strong movement
POS_Constants.WBN_THRESHOLD_HEADLINE = 20  -- 20%+: headline

-- Cadence (minimum game-minutes between bulletins per station)
POS_Constants.WBN_CADENCE_CIVILIAN_MIN = 10
POS_Constants.WBN_CADENCE_EMERGENCY_MIN = 5

-- Queue caps (max pending bulletins per station)
POS_Constants.WBN_QUEUE_MAX_CIVILIAN  = 8
POS_Constants.WBN_QUEUE_MAX_EMERGENCY = 4

-- Broadcast history (client-side, player ModData)
POS_Constants.WBN_HISTORY_MAX_ENTRIES = 50
POS_Constants.WBN_HISTORY_MODDATA_KEY = "BroadcastHistory"

-- Candidate expiry (hours after generation)
POS_Constants.WBN_CANDIDATE_EXPIRY_HOURS = 18

-- RadioLine colours (normalised 0.0-1.0 RGB)
POS_Constants.WBN_COLOUR_ECONOMY   = { r = 0.9, g = 0.8, b = 0.3 }
POS_Constants.WBN_COLOUR_EMERGENCY = { r = 0.9, g = 0.3, b = 0.3 }
POS_Constants.WBN_COLOUR_TAG       = { r = 0.6, g = 0.6, b = 0.6 }

-- RadioLine priority (vanilla PZ: higher = more important)
POS_Constants.WBN_RADIO_LINE_PRIORITY = 5

-- Domain identifiers
POS_Constants.WBN_DOMAIN_ECONOMY        = "economy"
POS_Constants.WBN_DOMAIN_INFRASTRUCTURE = "infrastructure"

-- Event type identifiers
POS_Constants.WBN_EVENT_SCARCITY_ALERT  = "scarcity_alert"
POS_Constants.WBN_EVENT_SURPLUS_NOTICE  = "surplus_notice"
POS_Constants.WBN_EVENT_PRICE_STABLE    = "price_stable"
POS_Constants.WBN_EVENT_GRID_WARNING    = "grid_warning"
POS_Constants.WBN_EVENT_BLACKOUT        = "blackout"

-- Direction identifiers
POS_Constants.WBN_DIR_UP    = "up"
POS_Constants.WBN_DIR_DOWN  = "down"
POS_Constants.WBN_DIR_MIXED = "mixed"
POS_Constants.WBN_DIR_STABLE = "stable"

-- Confidence bands
POS_Constants.WBN_CONF_HIGH   = "high"
POS_Constants.WBN_CONF_MEDIUM = "medium"
POS_Constants.WBN_CONF_LOW    = "low"

-- Voice pack section names for WBN (must match VOICE_ALL_OVERRIDE_SECTIONS)
POS_Constants.WBN_VP_SECTION_OPENER = POS_Constants.VOICE_SECTION_WBN_OPENER
POS_Constants.WBN_VP_SECTION_CLOSER = POS_Constants.VOICE_SECTION_WBN_CLOSER

-- Archetype IDs used in Phase 1
POS_Constants.WBN_ARCHETYPE_QUARTERMASTER = "quartermaster"
POS_Constants.WBN_ARCHETYPE_FIELD_REPORTER = "field_reporter"

-- Cause tags
POS_Constants.WBN_CAUSE_SCARCITY     = "scarcity"
POS_Constants.WBN_CAUSE_SURPLUS      = "surplus"
POS_Constants.WBN_CAUSE_BLACKOUT     = "blackout"
POS_Constants.WBN_CAUSE_CONVOY_LOSS  = "convoy_loss"
POS_Constants.WBN_CAUSE_PANIC        = "panic"
POS_Constants.WBN_CAUSE_RECOVERY     = "recovery"

-- Pressure-to-percentage conversion factor
-- Pressure is 0.0-1.0 clamped; multiply by this to get approximate % change
POS_Constants.WBN_PRESSURE_TO_PERCENT = 25

-- Weather broadcast thresholds (from ClimateManager API)
POS_Constants.WBN_WEATHER_RAIN_MODERATE  = 0.3   -- getRainIntensity() >= this
POS_Constants.WBN_WEATHER_RAIN_HEAVY     = 0.7
POS_Constants.WBN_WEATHER_SNOW_THRESHOLD = 0.2   -- getSnowIntensity() >= this
POS_Constants.WBN_WEATHER_FOG_THRESHOLD  = 0.4   -- getFogIntensity() >= this
POS_Constants.WBN_WEATHER_WIND_STRONG_KPH = 40   -- getWindspeedKph() >= this
POS_Constants.WBN_WEATHER_WIND_STORM_KPH  = 70
POS_Constants.WBN_WEATHER_COLD_EXTREME_C  = 0    -- getTemperature() <= this (Celsius)
POS_Constants.WBN_WEATHER_HEAT_EXTREME_C  = 35   -- getTemperature() >= this

-- Power grid broadcast severities
POS_Constants.WBN_POWER_SEVERITY_FAILURE   = 0.95
POS_Constants.WBN_POWER_SEVERITY_RESTORED  = 0.80
POS_Constants.WBN_POWER_SEVERITY_REMINDER  = 0.30
POS_Constants.WBN_POWER_SEVERITY_STATUS    = 0.20

-- World-state domains and event types
POS_Constants.WBN_DOMAIN_WEATHER        = "weather"
POS_Constants.WBN_DOMAIN_POWER          = "power"
POS_Constants.WBN_DOMAIN_COLOUR         = "colour"
POS_Constants.WBN_EVENT_WEATHER_REPORT  = "weather_report"
POS_Constants.WBN_EVENT_POWER_STATUS    = "power_status"
POS_Constants.WBN_EVENT_COLOUR          = "colour_broadcast"

-- Signal fragment constants (Tier 0.5 intelligence)
POS_Constants.WBN_FRAGMENT_CONF_SCALE    = 0.6   -- broadcast conf * this = fragment conf
POS_Constants.WBN_FRAGMENT_CONF_MIN      = 0.20
POS_Constants.WBN_FRAGMENT_CONF_MAX      = 0.60
POS_Constants.WBN_FRAGMENT_MAX_STORED    = 30    -- rolling cap in player ModData
POS_Constants.WBN_FRAGMENT_MODDATA_KEY   = "SignalFragments"
POS_Constants.FRAGMENTS_PAGE_SIZE        = 8

-- Rumour confidence modifiers from broadcast corroboration
POS_Constants.WBN_RUMOUR_REINFORCE_BOOST = 0.05  -- same-direction boost
POS_Constants.WBN_RUMOUR_CONTRADICT_DROP = 0.10  -- contradicting penalty
POS_Constants.WBN_RUMOUR_CONF_FLOOR      = 0.10

-- PN notification throttle (game-minutes between intel toasts)
POS_Constants.WBN_PN_INTEL_THROTTLE_MIN  = 5

-- Archetype weight tables for station scheduling (sum = 100 per station)
POS_Constants.WBN_ARCHETYPE_WEIGHTS_MARKET = {
    quartermaster = 40, trader = 25, wholesaler = 15,
    crafter = 10, speculator = 10,
}
POS_Constants.WBN_ARCHETYPE_WEIGHTS_EMERGENCY = {
    field_reporter = 50, military = 30, scavenger = 20,
}
POS_Constants.WBN_ARCHETYPE_WEIGHTS_OPERATIONS = {
    field_reporter = 40, military = 35, scavenger = 25,
}

---------------------------------------------------------------
-- Operations Net channel (Phase 2 — tactical broadcast, 148.5 MHz)
---------------------------------------------------------------

POS_Constants.AZAS_WBN_OPERATIONS_KEY        = "POSnet_WBN_Operations"
POS_Constants.WBN_DEFAULT_FREQ_OPERATIONS    = 148500
POS_Constants.WBN_FREQ_OPERATIONS            = POS_Constants.WBN_DEFAULT_FREQ_OPERATIONS
POS_Constants.WBN_UUID_OPERATIONS            = "POS-WBN-OPN-01"
POS_Constants.WBN_CHANNEL_NAME_OPERATIONS    = "UI_WBN_Channel_Operations"
POS_Constants.WBN_STATION_OPERATIONS         = "operations"
POS_Constants.WBN_TAG_KEY_OPERATIONS         = "UI_WBN_StationTag_OPN"
POS_Constants.WBN_CADENCE_OPERATIONS_MIN     = 8
POS_Constants.WBN_QUEUE_MAX_OPERATIONS       = 6

-- Operations domain + event types
POS_Constants.WBN_DOMAIN_OPERATIONS          = "operations"
POS_Constants.WBN_EVENT_AGENT_DEPLOYED       = "agent_deployed"
POS_Constants.WBN_EVENT_AGENT_STATE_CHANGE   = "agent_state_change"
POS_Constants.WBN_EVENT_MISSION_COMPLETED    = "mission_completed"
POS_Constants.WBN_EVENT_WHOLESALER_POSTURE   = "wholesaler_posture"
POS_Constants.WBN_EVENT_ZONE_WARNING         = "zone_warning"

-- SIGINT gate for Operations Net (minimum level to receive clearly)
POS_Constants.WBN_OPS_SIGINT_MIN             = 2

-- Operations severity thresholds
POS_Constants.WBN_OPS_HIGH_SEVERITY_GATE     = 0.6   -- market events routed to ops if >= this

-- Ambient broadcast generation (fallback when no pressure deltas occur)
POS_Constants.WBN_AMBIENT_PRESSURE_FLOOR = 0.05   -- min absolute pressure to generate ambient candidate
POS_Constants.WBN_AMBIENT_SEVERITY       = 0.3    -- base severity for ambient market reports
POS_Constants.WBN_AMBIENT_CONFIDENCE     = 0.5    -- base confidence for ambient market reports
POS_Constants.WBN_AMBIENT_FRESHNESS      = 0.8    -- freshness for ambient candidates
POS_Constants.WBN_AMBIENT_MAX_PER_TICK   = 3      -- max ambient candidates generated per economy tick
POS_Constants.WBN_AMBIENT_CONF_VARIANCE  = 0.1    -- +/- random variance applied to ambient confidence

-- Forecast system
POS_Constants.WBN_FORECAST_CONF_WEATHER    = 0.85  -- high: engine knows future weather
POS_Constants.WBN_FORECAST_CONF_ECONOMY    = 0.55  -- medium: extrapolation from drift
POS_Constants.WBN_FORECAST_CONF_POWER      = 0.35  -- low: speculative grid analysis
POS_Constants.WBN_FORECAST_HORIZON_MIN     = 1     -- minimum days ahead
POS_Constants.WBN_FORECAST_HORIZON_MAX     = 3     -- maximum days ahead
POS_Constants.WBN_FORECAST_REPEAT_WINDOW   = 8     -- wider dedup window for forecasts
POS_Constants.WBN_FORECAST_MAX_PER_TICK    = 2     -- max forecast candidates per economy tick
POS_Constants.WBN_FORECAST_CADENCE_TICKS   = 2     -- generate forecasts every Nth economy tick
POS_Constants.WBN_FORECAST_POWER_WARN_DAYS = 3     -- start warning N days before shutoff
POS_Constants.WBN_FORECAST_SEVERITY_DAMPEN = 0.8   -- forecasts are 80% as severe as real events

-- Delta-driven candidate severity bands (HarvestService economy tick)
POS_Constants.WBN_SEVERITY_BASE_LIGHT    = 0.3   -- default severity for light pressure changes
POS_Constants.WBN_SEVERITY_NORMAL        = 0.6   -- severity for normal-threshold changes
POS_Constants.WBN_SEVERITY_STRONG        = 0.8   -- severity for strong-threshold changes
POS_Constants.WBN_SEVERITY_HEADLINE      = 1.0   -- severity for headline-threshold events
POS_Constants.WBN_CONFIDENCE_MARKET_SIM  = 0.65  -- confidence for market simulation candidates
POS_Constants.WBN_SEVERITY_POWER_DEFAULT = 0.3   -- fallback severity for unrecognised power transitions
POS_Constants.WBN_PRESSURE_DEFAULT       = 0.5   -- fallback absolute pressure for market events

-- Scheduler bulletin metadata cache
POS_Constants.WBN_BULLETIN_META_MAX      = 50    -- rolling cap for bulletin → candidate metadata cache

-- Fragment → MarketDatabase bridge
POS_Constants.WBN_FRAGMENT_SOURCE        = "radio_broadcast"  -- source tag for DB records
