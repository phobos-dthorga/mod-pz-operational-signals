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

-- Radio channel frequencies (integer Hz — 91400 = 91.4 MHz)
POS_Constants.WBN_FREQ_CIVILIAN_MARKET  = 91400
POS_Constants.WBN_FREQ_EMERGENCY        = 103800

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
