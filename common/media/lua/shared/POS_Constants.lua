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
-- POS_Constants.lua
-- Single source of truth for cross-file string and ID constants.
--
-- CORE file: creates the global table and defines foundational
-- constants. Domain-specific constants are split across:
--   POS_Constants_Market.lua      -- market intel, pricing, camera
--   POS_Constants_Media.lua       -- VHS, microcassette, floppy, recorder
--   POS_Constants_Satellite.lua   -- satellite uplink, wiring, power
--   POS_Constants_LivingMarket.lua -- Layer 0 autonomous economy
--   POS_Constants_Trade.lua       -- trade terminal
--
-- PZ loads all shared/ Lua files alphabetically, so the split
-- files (POS_Constants_*) load after this file automatically.
---------------------------------------------------------------

POS_Constants = {}

---------------------------------------------------------------
-- Server / client command protocol
---------------------------------------------------------------

POS_Constants.CMD_MODULE = "POS"

-- Server -> client
POS_Constants.CMD_NEW_OPERATION       = "NewOperation"
POS_Constants.CMD_NEW_INVESTMENT      = "NewInvestment"
POS_Constants.CMD_INVESTMENT_RESOLVED = "InvestmentResolved"
POS_Constants.CMD_INVESTMENT_ACK      = "InvestmentAcknowledged"

-- Client -> server
POS_Constants.CMD_PLAYER_INVESTED     = "PlayerInvested"
POS_Constants.CMD_REQUEST_OPERATION   = "RequestOperation"
POS_Constants.CMD_REQUEST_PAYOUTS     = "RequestPendingPayouts"

---------------------------------------------------------------
-- Screen IDs (POS_ScreenManager navigation targets)
---------------------------------------------------------------

POS_Constants.SCREEN_MAIN_MENU   = "pos.main"
POS_Constants.SCREEN_BBS_HUB     = "pos.bbs"
POS_Constants.SCREEN_BBS_LIST    = "pos.bbs.investments"
POS_Constants.SCREEN_BBS_POST    = "pos.bbs.investments.detail"
POS_Constants.SCREEN_OPERATIONS  = "pos.bbs.operations"
POS_Constants.SCREEN_DELIVERIES  = "pos.bbs.deliveries"
POS_Constants.SCREEN_NEGOTIATE   = "pos.negotiate"
POS_Constants.SCREEN_BBS_RUMOURS = "pos.bbs.rumours"
POS_Constants.SCREEN_STOCKMARKET = "pos.stockmarket"
POS_Constants.SCREEN_DATA_RESET  = "pos.datareset"

---------------------------------------------------------------
-- Mission type identifiers
---------------------------------------------------------------

POS_Constants.MISSION_TYPE_RECON = "recon"

---------------------------------------------------------------
-- Item full types
---------------------------------------------------------------

POS_Constants.ITEM_PORTABLE_COMPUTER = "PhobosOperationalSignals.PortableComputer"
POS_Constants.ITEM_FIELD_REPORT      = "PhobosOperationalSignals.FieldReport"
POS_Constants.ITEM_RECON_PHOTOGRAPH  = "PhobosOperationalSignals.ReconPhotograph"
POS_Constants.ITEM_POSNET_PACKAGE    = "PhobosOperationalSignals.POSnetPackage"

---------------------------------------------------------------
-- ModData keys (used across multiple files)
---------------------------------------------------------------

POS_Constants.MD_OPERATION_ID = "POS_OperationId"

---------------------------------------------------------------
-- AZAS integration
---------------------------------------------------------------

POS_Constants.AZAS_OPS_KEY          = "POSnet_Operations"
POS_Constants.AZAS_TAC_KEY          = "POSnet_Tactical"
POS_Constants.AZAS_DEFAULT_OPS_FREQ = 130000
POS_Constants.AZAS_DEFAULT_TAC_FREQ = 155000

---------------------------------------------------------------
-- POSnet API version for extension compatibility
---------------------------------------------------------------

POS_Constants.API_VERSION = 1

---------------------------------------------------------------
-- Error translation keys
---------------------------------------------------------------

POS_Constants.ERR_UNKNOWN_SCREEN  = "UI_POS_Error_UnknownScreen"
POS_Constants.ERR_NO_SIGNAL       = "UI_POS_Error_NoSignal"
POS_Constants.ERR_WRONG_BAND      = "UI_POS_Error_WrongBand"
POS_Constants.ERR_NOT_CONNECTED   = "UI_POS_Error_NotConnected"
POS_Constants.ERR_EXTENSION_FAIL  = "UI_POS_Error_ExtensionFailed"
POS_Constants.ERR_SCREEN_BLOCKED  = "UI_POS_Error_ScreenBlocked"
POS_Constants.ERR_NO_POWER        = "UI_POS_Error_NoPower"
POS_Constants.ERR_NO_RECORDER     = "UI_POS_Error_NoRecorder"
POS_Constants.MSG_POWER_LOST      = "UI_POS_PowerLost"

---------------------------------------------------------------
-- Power drain modData keys
---------------------------------------------------------------

POS_Constants.MD_POWER_DRAIN_RATE    = "POS_PowerDrainRate"
POS_Constants.MD_POWER_DRAIN_SESSION = "POS_PowerDrainSession"
POS_Constants.POWER_CHECK_INTERVAL   = 60

---------------------------------------------------------------
-- Terminal UI layout
---------------------------------------------------------------

POS_Constants.TERMINAL_DEFAULT_WIDTH_PCT    = 0.75  -- 75% of screen width
POS_Constants.TERMINAL_DEFAULT_HEIGHT_PCT   = 0.75  -- 75% of screen height
POS_Constants.UI_SIGNAL_PANEL_WIDTH_PCT     = 0.20  -- 20% of terminal width
POS_Constants.UI_CONTEXT_PANEL_WIDTH_PCT    = 0.20  -- 20% of terminal width
POS_Constants.UI_SIGNAL_PANEL_MIN_WIDTH     = 160   -- minimum px width
POS_Constants.UI_CONTEXT_PANEL_MIN_WIDTH    = 180   -- minimum px width
POS_Constants.UI_CONTEXT_COLLAPSE_THRESHOLD = 700   -- collapse context panel below this terminal width
POS_Constants.UI_SCREEN_PADDING             = 8
POS_Constants.UI_PANEL_GAP                  = 4

---------------------------------------------------------------
-- Free Agent risk model (§46)
---------------------------------------------------------------

POS_Constants.FREE_AGENT_MAX_EFFECTIVE_RISK              = 0.75
POS_Constants.FREE_AGENT_SIGINT_RISK_REDUCTION_PER_LEVEL = 0.03
POS_Constants.SIGNAL_ENTRY_TYPE_AGENT                    = "agent"
POS_Constants.FREE_AGENT_TICK_INTERVAL_TICKS             = 1200
POS_Constants.ZONE_DEFAULT_VOLATILITY                    = 0.20
POS_Constants.PERK_SIGINT                                = "SIGINT"

---------------------------------------------------------------
-- Market Overview display constants (§33)
---------------------------------------------------------------

POS_Constants.PRESSURE_COLOUR_THRESHOLD    = 0.3
POS_Constants.ZONE_TOP_PRESSURES           = 3
POS_Constants.ZONE_PRESSURE_BAR_WIDTH      = 20
POS_Constants.PRESSURE_HIGH_THRESHOLD      = 0.5
POS_Constants.ZONE_SEPARATOR_WIDTH         = 40
POS_Constants.HEADER_SEPARATOR_WIDTH       = 50
POS_Constants.CONFIDENCE_HIGH_THRESHOLD    = 2.5
POS_Constants.CONFIDENCE_MEDIUM_THRESHOLD  = 1.5
POS_Constants.SIGNAL_CLASS_HARD            = "hard"
POS_Constants.CONTACTS_ZONE_OFFSET         = 0.55
POS_Constants.SIGNALS_PAGE_SIZE            = 8
POS_Constants.SIGNALS_BADGE_OFFSET         = 60
POS_Constants.SIGNALS_TYPE_OFFSET          = 100
POS_Constants.SIGINT_HIGH_VISIBILITY_LEVEL = 7
POS_Constants.PAGE_SIZE_WHOLESALER_DIR     = 5

---------------------------------------------------------------
-- Event impact hints (Market Event System)
---------------------------------------------------------------

POS_Constants.EVENT_IMPACT_SHORTAGE   = "shortage"
POS_Constants.EVENT_IMPACT_SURPLUS    = "surplus"
POS_Constants.EVENT_IMPACT_DISRUPTION = "disruption"
POS_Constants.EVENT_DEFAULT_SIGNAL_CLASS = "soft"

---------------------------------------------------------------
-- Wholesaler operational state labels
---------------------------------------------------------------

POS_Constants.WHOLESALER_STATE_ACTIVE     = "active"
POS_Constants.WHOLESALER_STATE_SUSPENDED  = "suspended"
POS_Constants.WHOLESALER_STATE_BLOCKED    = "blocked"
POS_Constants.WHOLESALER_STATE_COLLAPSED  = "collapsed"
POS_Constants.WHOLESALER_STATE_STARTING   = "starting"
POS_Constants.WHOLESALER_STATE_RECOVERING = "recovering"

---------------------------------------------------------------
-- Pressure display normalisation
---------------------------------------------------------------

POS_Constants.PRESSURE_NORM_OFFSET  = 2    -- pressure range -2..+2
POS_Constants.PRESSURE_NORM_DIVISOR = 4    -- normalise to 0..1

---------------------------------------------------------------
-- Display layout
---------------------------------------------------------------

POS_Constants.WHOLESALER_LABEL_MAX_LENGTH = 16

---------------------------------------------------------------
-- Signal feed limits
---------------------------------------------------------------

POS_Constants.SIGNAL_FEED_MAX_ENTRIES   = 20
POS_Constants.ALERT_FEED_MAX_ENTRIES    = 10
POS_Constants.PROCESS_FEED_MAX_ENTRIES  = 5

---------------------------------------------------------------
-- Mission text compositor (§32)
---------------------------------------------------------------

POS_Constants.MISSION_BRIEFING_SECTIONS = {
    "title", "situation", "tasking", "constraints", "submission",
}
POS_Constants.MISSION_HISTORY_MAX_SIZE          = 10
POS_Constants.MISSION_MIN_DIFFICULTY            = 1
POS_Constants.MISSION_MAX_DIFFICULTY            = 5
POS_Constants.MISSION_VOICE_OVERRIDE_SECTIONS   = { "situation", "submission" }

-- Voice section name constants (avoid magic strings)
POS_Constants.VOICE_SECTION_SITUATION    = "situation"
POS_Constants.VOICE_SECTION_SUBMISSION   = "submission"
POS_Constants.VOICE_SECTION_AGENT_STATE  = "agentState"
POS_Constants.VOICE_SECTION_INVESTMENT   = "investment"
POS_Constants.VOICE_SECTION_WBN_OPENER  = "wbn_opener"
POS_Constants.VOICE_SECTION_WBN_CLOSER  = "wbn_closer"

-- Extended voice override sections (includes agent + investment + WBN)
POS_Constants.VOICE_ALL_OVERRIDE_SECTIONS = {
    "situation", "submission", "agentState", "investment",
    "wbn_opener", "wbn_closer",
}

---------------------------------------------------------------
-- Signal-based mission degradation (§5.4)
-- Simulates radio transmissions breaking up through static.
---------------------------------------------------------------

POS_Constants.SIGNAL_GARBLE_THRESHOLD  = 0.80  -- below this, briefings start garbling
POS_Constants.SIGNAL_GARBLE_MAX_PCT    = 0.60  -- max proportion of words replaced
POS_Constants.SIGNAL_GARBLE_FRAGMENTS  = {
    "...static...",
    "---",
    "[garbled]",
    "~*~",
    "...",
    "[inaudible]",
    "--bzzt--",
    "[break]",
    "~crackle~",
    "[lost]",
}

---------------------------------------------------------------
-- Free Agent System (§46)
-- Runners, brokers, couriers sent into the wasteland.
---------------------------------------------------------------

-- Agent states (state machine)
POS_Constants.AGENT_STATE_DRAFTED      = "drafted"
POS_Constants.AGENT_STATE_ASSEMBLING   = "assembling"
POS_Constants.AGENT_STATE_TRANSIT      = "transit"
POS_Constants.AGENT_STATE_NEGOTIATION  = "negotiation"
POS_Constants.AGENT_STATE_SETTLEMENT   = "settlement"
POS_Constants.AGENT_STATE_COMPLETED    = "completed"
POS_Constants.AGENT_STATE_FAILED       = "failed"
POS_Constants.AGENT_STATE_DELAYED      = "delayed"
POS_Constants.AGENT_STATE_COMPROMISED  = "compromised"

-- Agent archetypes
POS_Constants.FREE_AGENT_ARCHETYPE_RUNNER    = "runner"
POS_Constants.FREE_AGENT_ARCHETYPE_BROKER    = "broker"
POS_Constants.FREE_AGENT_ARCHETYPE_COURIER   = "courier"
POS_Constants.FREE_AGENT_ARCHETYPE_SMUGGLER  = "smuggler"
POS_Constants.FREE_AGENT_ARCHETYPE_CONTACT   = "wholesaler_contact"

-- State transition probabilities
POS_Constants.FREE_AGENT_DELAY_VS_COMPROMISE = 0.50
POS_Constants.FREE_AGENT_DELAY_RESOLVE_CHANCE = 0.60
POS_Constants.FREE_AGENT_COMPROMISE_FAIL_CHANCE = 0.30
POS_Constants.FREE_AGENT_COMPROMISE_RECOVER_CHANCE = 0.40

-- Risk display thresholds
POS_Constants.RISK_THRESHOLD_HIGH     = 0.20
POS_Constants.RISK_THRESHOLD_MODERATE = 0.10
POS_Constants.BETRAYAL_THRESHOLD_HIGH     = 0.15
POS_Constants.BETRAYAL_THRESHOLD_MODERATE = 0.05
POS_Constants.BETRAYAL_COLOUR_THRESHOLD   = 0.10

-- Display
POS_Constants.FREE_AGENT_PAGE_SIZE = 4

POS_Constants.FREE_AGENT_MAX_ACTIVE            = 3
POS_Constants.FREE_AGENT_ADVANCE_CHANCE        = 0.55   -- chance to advance per tick
POS_Constants.FREE_AGENT_DEFAULT_RISK          = 0.10
POS_Constants.FREE_AGENT_DEFAULT_COMMISSION    = 0.10
POS_Constants.FREE_AGENT_DEFAULT_ESTIMATED_DAYS = 4

POS_Constants.FREE_AGENT_COMMISSION_RATES = {
    runner             = 0.05,   -- cheap, fast, risky
    broker             = 0.15,   -- finds better prices, takes more
    courier            = 0.10,   -- professional, reliable
    smuggler           = 0.20,   -- best margins, may vanish
    wholesaler_contact = 0.08,   -- stable, predictable
}

POS_Constants.FREE_AGENT_RISK_LEVELS = {
    runner             = 0.20,   -- high risk, might not come back
    broker             = 0.05,   -- low risk, stays remote
    courier            = 0.10,   -- moderate, professional
    smuggler           = 0.25,   -- highest risk, operates outside the law
    wholesaler_contact = 0.03,   -- minimal risk, established routes
}

POS_Constants.FREE_AGENT_ESTIMATED_DAYS = {
    runner             = 2,
    broker             = 5,
    courier            = 3,
    smuggler           = 4,
    wholesaler_contact = 6,
}

---------------------------------------------------------------
-- PhobosNotifications channel IDs (§46.8)
---------------------------------------------------------------

POS_Constants.PN_CHANNEL_AGENTS    = "posnet_agents"
POS_Constants.PN_CHANNEL_CONTRACTS = "posnet_contracts"
POS_Constants.PN_CHANNEL_MARKET    = "posnet_market"
POS_Constants.PN_CHANNEL_TRADE     = "posnet_trade"
POS_Constants.PN_CHANNEL_INTEL     = "posnet_intel"

---------------------------------------------------------------
-- Mission categories & statuses
---------------------------------------------------------------

POS_Constants.MISSION_CATEGORIES = {
    "recon", "delivery", "trade", "sigint", "recovery", "survey",
}

POS_Constants.MISSION_STATUS_AVAILABLE = "available"
POS_Constants.MISSION_STATUS_ACTIVE    = "active"
POS_Constants.MISSION_STATUS_COMPLETED = "completed"
POS_Constants.MISSION_STATUS_FAILED    = "failed"
POS_Constants.MISSION_STATUS_EXPIRED   = "expired"

POS_Constants.MISSION_PAGE_SIZE = 5

---------------------------------------------------------------
-- Contract system (§43)
---------------------------------------------------------------

POS_Constants.CONTRACT_BRIEFING_SECTIONS = {
    "title", "situation", "tasking", "submission",
}
POS_Constants.CONTRACT_MAX_ACTIVE          = 3
POS_Constants.CONTRACT_MAX_AVAILABLE       = 8
POS_Constants.CONTRACT_HISTORY_MAX_SIZE    = 15
POS_Constants.CONTRACT_GENERATION_PRESSURE_THRESHOLD = 0.15
POS_Constants.CONTRACT_GENERATION_COOLDOWN_DAYS      = 1

POS_Constants.CONTRACT_STATUS_POSTED       = "posted"
POS_Constants.CONTRACT_STATUS_ACCEPTED     = "accepted"
POS_Constants.CONTRACT_STATUS_FULFILLED    = "fulfilled"
POS_Constants.CONTRACT_STATUS_SETTLED      = "settled"
POS_Constants.CONTRACT_STATUS_EXPIRED      = "expired"
POS_Constants.CONTRACT_STATUS_FAILED       = "failed"
POS_Constants.CONTRACT_STATUS_BETRAYED     = "betrayed"

---------------------------------------------------------------
-- Terminal frame geometry (telnet-style header + status bar)
---------------------------------------------------------------

POS_Constants.HEADER_BAR_HEIGHT  = 24
POS_Constants.STATUS_BAR_HEIGHT  = 24

---------------------------------------------------------------
-- Boot sequence timing
---------------------------------------------------------------

POS_Constants.BOOT_DURATION_SECONDS = 30
POS_Constants.BOOT_TARGET_FPS       = 60
POS_Constants.BOOT_PAUSE_FRAMES     = 60

---------------------------------------------------------------
-- Portable computer drain
---------------------------------------------------------------

POS_Constants.PORTABLE_DRAIN_DIVISOR_DEFAULT = 1800

---------------------------------------------------------------
-- Page sizes (terminal screens)
---------------------------------------------------------------

POS_Constants.PAGE_SIZE_COMMODITIES      = 8
POS_Constants.PAGE_SIZE_COMMODITY_ITEMS  = 8
POS_Constants.PAGE_SIZE_MARKET_REPORTS   = 5
POS_Constants.PAGE_SIZE_WATCHLIST        = 6
POS_Constants.PAGE_SIZE_BBS_RUMOURS      = 5
POS_Constants.WATCHLIST_MAX_ENTRIES      = 20
POS_Constants.WATCHLIST_PRICE_CHANGE_PCT = 10
POS_Constants.PAGE_SIZE_EVENT_LOG      = 8
POS_Constants.PAGE_SIZE_ZONE_OVERVIEW  = 6
POS_Constants.PAGE_SIZE_WHOLESALER_DIR = 6
POS_Constants.PAGE_SIZE_TRADE_TERMINAL = 6
POS_Constants.PAGE_SIZE_TRADE_CATALOG  = 8
POS_Constants.PAGE_SIZE_MARKET_OVERVIEW  = 6
POS_Constants.PAGE_SIZE_CONTACTS         = 6
POS_Constants.PAGE_SIZE_MARKET_SIGNALS   = 8
POS_Constants.PAGE_SIZE_ASSIGNMENTS      = 5

---------------------------------------------------------------
-- Signal bar display (POS_NavPanel)
---------------------------------------------------------------

POS_Constants.SIGNAL_BAR_LENGTH         = 10
POS_Constants.SIGNAL_THRESHOLD_HIGH_PCT = 80
POS_Constants.SIGNAL_THRESHOLD_MED_PCT  = 50
POS_Constants.SIGNAL_THRESHOLD_LOW_PCT  = 25

---------------------------------------------------------------
-- Font scale thresholds (pixels, window width breakpoints)
---------------------------------------------------------------

POS_Constants.FONT_SCALE_SMALL_WIDTH = 600
POS_Constants.FONT_SCALE_LARGE_WIDTH = 900

---------------------------------------------------------------
-- World ModData keys (Global ModData containers)
---------------------------------------------------------------

POS_Constants.WMD_WORLD               = "POSNET.World"
POS_Constants.WMD_EXCHANGE            = "POSNET.Exchange"
POS_Constants.WMD_WHOLESALERS         = "POSNET.Wholesalers"
POS_Constants.WMD_META                = "POSNET.Meta"
POS_Constants.WMD_BUILDINGS           = "POSNET.Buildings"
POS_Constants.WMD_MAILBOXES           = "POSNET.Mailboxes"
POS_Constants.WMD_CONTRACTS           = "POSNET.Contracts"
POS_Constants.WMD_FREE_AGENTS         = "POSNET.FreeAgents"
POS_Constants.WMD_ACTIVE_EVENTS       = "POSNET.ActiveEvents"
POS_Constants.WMD_RECENT_EVENTS       = "POSNET.RecentEvents"
POS_Constants.WMD_EVENT_LOG           = "POSNET.EventLog"
POS_Constants.WMD_BUILDING_CACHE      = "POSNET.BuildingCache"
POS_Constants.WMD_MAILBOX_CACHE       = "POSNET.MailboxCache"
POS_Constants.WMD_PENDING_RESOLUTIONS = "POS_PendingResolutions"
POS_Constants.PENDING_PAYOUT_PREFIX   = "POS_PendingPayouts_"

---------------------------------------------------------------
-- Schema versioning
---------------------------------------------------------------

POS_Constants.SCHEMA_VERSION = 1

---------------------------------------------------------------
-- Rolling window caps
---------------------------------------------------------------

POS_Constants.MAX_OBSERVATIONS_PER_CATEGORY = 24
POS_Constants.MAX_ROLLING_CLOSES            = 14
POS_Constants.MAX_GLOBAL_EVENTS             = 100
POS_Constants.MAX_PLAYER_ALERTS             = 20
POS_Constants.MAX_PLAYER_ORDERS             = 10

---------------------------------------------------------------
-- Basis points
---------------------------------------------------------------

POS_Constants.BPS_DIVISOR = 10000

---------------------------------------------------------------
-- Event log paths and format
---------------------------------------------------------------

-- DEPRECATED: Event logs now stored in world ModData (POSNET.EventLog)
-- POS_Constants.EVENT_LOG_DIR       = "POSNET/events/"
-- POS_Constants.EVENT_SNAPSHOT_DIR  = "POSNET/snapshots/"
POS_Constants.EVENT_LOG_SEPARATOR    = "|"
POS_Constants.EVENT_LOG_VERSION      = 1
POS_Constants.EVENT_LOG_PURGE_BUFFER = 5

-- Event log system names
POS_Constants.EVENT_SYSTEM_ECONOMY   = "economy"
POS_Constants.EVENT_SYSTEM_STOCKS    = "stocks"
POS_Constants.EVENT_SYSTEM_RECON     = "recon"

---------------------------------------------------------------
-- Server commands (persistence / snapshot protocol)
---------------------------------------------------------------

POS_Constants.CMD_SUBMIT_OBSERVATION      = "SubmitObservation"
POS_Constants.CMD_REQUEST_MARKET_SNAPSHOT = "RequestMarketSnapshot"
POS_Constants.CMD_MARKET_SNAPSHOT         = "MarketSnapshot"
POS_Constants.CMD_REQUEST_CATEGORY_DETAIL = "RequestCategoryDetail"
POS_Constants.CMD_CATEGORY_DETAIL         = "CategoryDetail"
POS_Constants.CMD_ECONOMY_TICK_COMPLETE   = "EconomyTickComplete"
POS_Constants.CMD_SUBMIT_BUILDING         = "SubmitBuilding"
POS_Constants.CMD_SUBMIT_MAILBOX          = "SubmitMailbox"
POS_Constants.CMD_BUILDING_CACHE_SYNC     = "BuildingCacheSync"
POS_Constants.CMD_MAILBOX_CACHE_SYNC      = "MailboxCacheSync"
POS_Constants.CMD_ADMIN_FORCE_TICK        = "AdminForceTick"
POS_Constants.CMD_ADMIN_DUMP_STATE        = "AdminDumpState"

---------------------------------------------------------------
-- UI text overflow prevention
---------------------------------------------------------------

POS_Constants.UI_BUTTON_TEXT_ELLIPSIS   = "..."
POS_Constants.UI_MIN_SEPARATOR_CHARS    = 10
POS_Constants.UI_BUTTON_TEXT_PADDING    = 16

---------------------------------------------------------------
-- UI Layout -- Pagination & progress bars
---------------------------------------------------------------

POS_Constants.UI_LEDGER_PAGE_SIZE      = 8
POS_Constants.UI_EXCHANGE_PAGE_SIZE    = 8
POS_Constants.UI_TRENDS_PAD_WIDTH      = 18
POS_Constants.UI_PROGRESS_FILL_CHAR    = "#"
POS_Constants.UI_PROGRESS_EMPTY_CHAR   = "-"

---------------------------------------------------------------
-- Scanner radio tiers (derived from vanilla TransmitRange)
---------------------------------------------------------------

POS_Constants.RADIO_RANGE_DIVISOR             = 500
POS_Constants.RADIO_MAX_SCAN_RADIUS           = 40
POS_Constants.RADIO_TIER_THRESHOLD_BASIC      = 2000
POS_Constants.RADIO_TIER_THRESHOLD_ADVANCED   = 10000
POS_Constants.RADIO_CONFIDENCE_TIER1          = -5000
POS_Constants.RADIO_CONFIDENCE_TIER2          = -3000
POS_Constants.RADIO_CONFIDENCE_TIER3          = -1000
POS_Constants.RADIO_CONFIDENCE_TIER4          = 0
POS_Constants.RADIO_BROADCAST_QUALITY_TIER1   = 30
POS_Constants.RADIO_BROADCAST_QUALITY_TIER2   = 50
POS_Constants.RADIO_BROADCAST_QUALITY_TIER3   = 70
POS_Constants.RADIO_BROADCAST_QUALITY_TIER4   = 90

---------------------------------------------------------------
-- Danger detection
---------------------------------------------------------------

POS_Constants.DANGER_CHECK_RADIUS = 15

-- DEPRECATED: Caches now stored in world ModData (POSNET.BuildingCache, POSNET.MailboxCache)
-- POS_Constants.CACHE_FILE_BUILDINGS  = "POSNET/buildings.dat"
-- POS_Constants.CACHE_FILE_MAILBOXES  = "POSNET/mailboxes.dat"
-- POS_Constants.CACHE_FILE_SEPARATOR  = "|"
-- POS_Constants.CACHE_FILE_ROOM_SEP   = ","

---------------------------------------------------------------
-- Operation statuses
---------------------------------------------------------------

POS_Constants.STATUS_AVAILABLE = "available"
POS_Constants.STATUS_ACTIVE    = "active"
POS_Constants.STATUS_COMPLETED = "completed"
POS_Constants.STATUS_EXPIRED   = "expired"
POS_Constants.STATUS_FAILED    = "failed"
POS_Constants.STATUS_CANCELLED = "cancelled"

---------------------------------------------------------------
-- Opportunity statuses
---------------------------------------------------------------

POS_Constants.OPP_STATUS_OPEN    = "open"
POS_Constants.OPP_STATUS_FUNDED  = "funded"
POS_Constants.OPP_STATUS_EXPIRED = "expired"

---------------------------------------------------------------
-- Investment statuses
---------------------------------------------------------------

POS_Constants.INV_STATUS_ACTIVE    = "active"
POS_Constants.INV_STATUS_MATURED   = "matured"
POS_Constants.INV_STATUS_DEFAULTED = "defaulted"

---------------------------------------------------------------
-- Stock levels
---------------------------------------------------------------

POS_Constants.STOCK_NONE   = "none"
POS_Constants.STOCK_LOW    = "low"
POS_Constants.STOCK_MEDIUM = "medium"
POS_Constants.STOCK_HIGH   = "high"

---------------------------------------------------------------
-- Confidence levels
---------------------------------------------------------------

POS_Constants.CONFIDENCE_LOW    = "low"
POS_Constants.CONFIDENCE_MEDIUM = "medium"
POS_Constants.CONFIDENCE_HIGH   = "high"

---------------------------------------------------------------
-- Negotiation parameters
---------------------------------------------------------------

POS_Constants.NEGOTIATE_MAX_ATTEMPTS     = 3
POS_Constants.NEGOTIATE_REWARD_BONUS_PCT = 20
POS_Constants.NEGOTIATE_REWARD_CUT_PCT   = 15
POS_Constants.NEGOTIATE_DAY_REDUCTION    = 1
POS_Constants.NEGOTIATE_DAY_EXTENSION    = 2
POS_Constants.NEGOTIATE_TIER_CHANCES     = { 30, 50, 70, 85, 85 }

---------------------------------------------------------------
-- Market recon thresholds
---------------------------------------------------------------

POS_Constants.STOCK_THRESHOLD_NONE           = 10
POS_Constants.STOCK_THRESHOLD_LOW            = 40
POS_Constants.STOCK_THRESHOLD_MEDIUM         = 75
POS_Constants.CONFIDENCE_TIER_HIGH           = 4
POS_Constants.CONFIDENCE_TIER_MEDIUM         = 2
POS_Constants.ITEM_SELECTION_POOL_SIZE_DEFAULT = 3
POS_Constants.CHARACTER_MUMBLE_CHANCE        = 300

---------------------------------------------------------------
-- Writing tool damage defaults
---------------------------------------------------------------

POS_Constants.WRITING_DAMAGE_CHANCE_DEFAULT  = 20
POS_Constants.WRITING_DAMAGE_AMOUNT_DEFAULT  = 7
POS_Constants.WRITING_DAMAGE_VARIANCE        = 5
POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET = 2

--- Writing implement full type names for damage targeting.
POS_Constants.WRITING_IMPLEMENTS = {
    ["Base.Pen"]            = true,
    ["Base.Pencil"]         = true,
    ["Base.RedPen"]         = true,
    ["Base.BluePen"]        = true,
    ["Base.GreenPen"]       = true,
    ["Base.PenMultiColor"]  = true,
    ["Base.PenFancy"]       = true,
    ["Base.PenSpiffo"]      = true,
    ["Base.PencilSpiffo"]   = true,
}

---------------------------------------------------------------
-- VHS media confidence threshold tiers (for resolveThresholdTier)
-- NOTE: Threshold tables are defined in POS_Constants_Media.lua
-- (loaded AFTER base constants) to avoid forward-reference crashes.
-- See POS_Constants_Media.lua lines 133-210 for the authoritative
-- definitions of VHS/MICROCASSETTE/FLOPPY_CONFIDENCE_THRESHOLDS.
---------------------------------------------------------------

---------------------------------------------------------------
-- Persistence modData keys (operations / investments)
---------------------------------------------------------------

POS_Constants.MODDATA_OPERATIONS    = "POS_Operations"
POS_Constants.MODDATA_OPPORTUNITIES = "POS_Opportunities"
POS_Constants.MODDATA_INVESTMENTS   = "POS_Investments"
POS_Constants.MODDATA_WATCHLIST     = "POS_Watchlist"
POS_Constants.MODDATA_ALERTS        = "POS_Alerts"

---------------------------------------------------------------
-- Operations display
---------------------------------------------------------------

POS_Constants.OPERATIONS_PAGE_SIZE              = 5
POS_Constants.OPERATIONS_COMPLETED_DISPLAY      = 5
POS_Constants.EXPIRY_REPUTATION_PENALTY_DEFAULT = 25

---------------------------------------------------------------
-- Objective types
---------------------------------------------------------------

POS_Constants.OBJECTIVE_TYPE_DELIVERY = "delivery"

---------------------------------------------------------------
-- Freshness labels (market data age)
---------------------------------------------------------------

POS_Constants.FRESHNESS_FRESH   = "fresh"
POS_Constants.FRESHNESS_STALE   = "stale"
POS_Constants.FRESHNESS_EXPIRED = "expired"

---------------------------------------------------------------
-- Difficulty labels (operation tier mapping)
---------------------------------------------------------------

POS_Constants.DIFFICULTY_EASY     = "easy"
POS_Constants.DIFFICULTY_MEDIUM   = "medium"
POS_Constants.DIFFICULTY_HARD     = "hard"
POS_Constants.DIFFICULTY_CRITICAL = "critical"
POS_Constants.DIFFICULTY_LEVELS   = { "easy", "medium", "hard", "critical" }

---------------------------------------------------------------
-- Delivery defaults
---------------------------------------------------------------

POS_Constants.DELIVERY_DIFFICULTY_THRESHOLD = 7500
POS_Constants.RECENT_RESULTS_DISPLAY_LIMIT = 5

---------------------------------------------------------------
-- PhobosNotifications channel
---------------------------------------------------------------

POS_Constants.PN_CHANNEL_ID        = "POSnet"
POS_Constants.PN_CHANNEL_LABEL_KEY = "UI_POS_Channel_POSnet"

---------------------------------------------------------------
-- SIGINT Skill (analytical throughline)
---------------------------------------------------------------

-- Perk registration
POS_Constants.SIGINT_PERK_ID                   = "SIGINT"
POS_Constants.SIGINT_PERK_PARENT               = "Passiv"
POS_Constants.SIGINT_MAX_LEVEL                 = 10

-- Qualitative tier thresholds
POS_Constants.SIGINT_TIER_NOISE_DROWNER        = 0   -- L0-2
POS_Constants.SIGINT_TIER_PATTERN_SEEKER       = 3   -- L3-5
POS_Constants.SIGINT_TIER_ANALYST              = 6   -- L6-8
POS_Constants.SIGINT_TIER_INTEL_OPERATOR       = 9   -- L9-10

-- Feature unlock levels
POS_Constants.SIGINT_CROSS_CORRELATION_LEVEL   = 6
POS_Constants.SIGINT_FALSE_DATA_DETECTION_LEVEL = 8

-- XP award values
POS_Constants.SIGINT_XP_TERMINAL_ANALYSIS      = 20
POS_Constants.SIGINT_XP_CROSS_CORRELATION      = 10
POS_Constants.SIGINT_XP_RESOLVE_CONTRADICTION  = 8
POS_Constants.SIGINT_XP_CAMERA_SURVEY          = 8
POS_Constants.SIGINT_XP_CAMERA_TAPE_REVIEW     = 6
POS_Constants.SIGINT_XP_CAMERA_BULLETIN        = 12
POS_Constants.SIGINT_XP_SATELLITE_BROADCAST    = 10
POS_Constants.SIGINT_XP_MANUAL_NOTE            = 3
POS_Constants.SIGINT_XP_VHS_REVIEW             = 5
POS_Constants.SIGINT_XP_MISSION_REPORT         = 5

-- Per-level modifier tables (indexed 1-11 for levels 0-10)
POS_Constants.SIGINT_CONFIDENCE_PER_LEVEL      = {0, 2, 4, 6, 8, 10, 13, 16, 19, 22, 25}
POS_Constants.SIGINT_NOISE_FILTER_PER_LEVEL    = {0, 5, 10, 20, 25, 35, 45, 55, 65, 80, 90}
POS_Constants.SIGINT_TIME_REDUCTION_PER_LEVEL  = {0, 3, 6, 10, 14, 18, 24, 28, 32, 38, 44}
POS_Constants.SIGINT_YIELD_PER_LEVEL           = {
    {1, 1}, {1, 1}, {1, 1},    -- L0-2: 1 output
    {1, 2}, {1, 2}, {1, 2},    -- L3-5: 1-2 outputs
    {2, 3}, {2, 3}, {2, 3},    -- L6-8: 2-3 outputs
    {2, 4}, {2, 4},            -- L9-10: 2-4 outputs
}

-- Trait IDs
POS_Constants.TRAIT_ANALYTICAL_MIND            = "POS_AnalyticalMind"
POS_Constants.TRAIT_RADIO_HOBBYIST             = "POS_RadioHobbyist"
POS_Constants.TRAIT_SYSTEMS_THINKER            = "POS_SystemsThinker"
POS_Constants.TRAIT_IMPATIENT                  = "POS_Impatient"
POS_Constants.TRAIT_DISORGANISED_THINKER       = "POS_DisorganisedThinker"
POS_Constants.TRAIT_SIGNAL_BLINDNESS           = "POS_SignalBlindness"

-- Trait costs (positive = costs points, negative = grants points)
POS_Constants.TRAIT_ANALYTICAL_MIND_COST       = 4
POS_Constants.TRAIT_RADIO_HOBBYIST_COST        = 2
POS_Constants.TRAIT_SYSTEMS_THINKER_COST       = 3
POS_Constants.TRAIT_IMPATIENT_COST             = -2
POS_Constants.TRAIT_DISORGANISED_THINKER_COST  = -3
POS_Constants.TRAIT_SIGNAL_BLINDNESS_COST      = -4

-- Trait effect values
POS_Constants.TRAIT_ANALYTICAL_MIND_XP_BONUS   = 0.25   -- +25% SIGINT XP
POS_Constants.TRAIT_RADIO_HOBBYIST_XP_BONUS    = 0.0    -- no XP bonus
POS_Constants.TRAIT_RADIO_HOBBYIST_SCAN_BONUS  = 0.20   -- +20% radio scan radius
POS_Constants.TRAIT_SYSTEMS_THINKER_CROSSCOR   = 4      -- cross-correlation unlocks at L4
POS_Constants.TRAIT_IMPATIENT_TIME_PENALTY     = 0.30   -- +30% analysis time
POS_Constants.TRAIT_DISORGANISED_XP_PENALTY    = 0.25   -- -25% SIGINT XP
POS_Constants.TRAIT_DISORGANISED_NOISE_PENALTY = 0.20   -- +20% noise
POS_Constants.TRAIT_SIGNAL_BLINDNESS_CAP       = 5      -- hard cap at Level 5

-- Trait starting SIGINT level bonus
POS_Constants.TRAIT_SIGINT_STARTING_BONUS      = 1      -- +1 for AnalyticalMind, RadioHobbyist

-- Field confidence: +1 per this many SIGINT levels (max +3)
POS_Constants.SIGINT_FIELD_CONFIDENCE_DIVISOR  = 3
POS_Constants.SIGINT_FIELD_CONFIDENCE_CAP      = 3

-- ModData keys
POS_Constants.MODDATA_SIGINT_TOTAL_XP          = "POS_SIGINT_TotalXP"
POS_Constants.MODDATA_SIGINT_CROSSCOR_COUNT    = "POS_SIGINT_CrossCorrelations"

-- SIGINT XP thresholds per level (before 1.5x multiplier)
POS_Constants.SIGINT_XP_THRESHOLDS = {75, 150, 300, 750, 1500, 3000, 4500, 6000, 7500, 9000}

-- Skill book item prefix
POS_Constants.ITEM_SIGINT_BOOK_PREFIX          = "PhobosOperationalSignals.SIGINTBook"

-- ZScienceSkill mirror ratio
POS_Constants.SIGINT_ZSCIENCE_MIRROR_RATIO     = 0.5

---------------------------------------------------------------
-- Terminal Analysis (Tier II -- Processing)
---------------------------------------------------------------

POS_Constants.SCREEN_ID_ANALYSIS               = "pos.bbs.analysis"
POS_Constants.ANALYSIS_BASE_TIME               = 180  -- seconds
POS_Constants.ANALYSIS_MAX_INPUTS              = 5
POS_Constants.ANALYSIS_BASE_JUNK_CHANCE        = 40   -- percentage at SIGINT 0
POS_Constants.ANALYSIS_COOLDOWN_MINUTES        = 30

-- Input diversity bonuses
POS_Constants.ANALYSIS_SOURCE_DIVERSITY_BONUS  = 3
POS_Constants.ANALYSIS_SOURCE_DIVERSITY_CAP    = 12
POS_Constants.ANALYSIS_CATEGORY_DIVERSITY_BONUS = 2
POS_Constants.ANALYSIS_CATEGORY_DIVERSITY_CAP  = 8

-- Input volume XP scaling (indexed 1-5 by input count)
POS_Constants.ANALYSIS_XP_PER_INPUT            = {15, 17, 19, 22, 25}

-- Satellite enhancement
POS_Constants.ANALYSIS_SATELLITE_CONFIDENCE    = 8
POS_Constants.ANALYSIS_SATELLITE_TIER_UPGRADE  = 15   -- percentage chance
POS_Constants.ANALYSIS_SATELLITE_CROSSCOR_REDUCTION = 1

-- Satellite passive accumulation thresholds (game days)
POS_Constants.ANALYSIS_SATELLITE_ACCUMULATE_T1 = 1
POS_Constants.ANALYSIS_SATELLITE_ACCUMULATE_T2 = 3
POS_Constants.ANALYSIS_SATELLITE_ACCUMULATE_T3 = 7

-- Fragment tier IDs
POS_Constants.FRAGMENT_TIER_FRAGMENTARY        = "fragmentary"
POS_Constants.FRAGMENT_TIER_UNVERIFIED         = "unverified"
POS_Constants.FRAGMENT_TIER_CORRELATED         = "correlated"
POS_Constants.FRAGMENT_TIER_CONFIRMED          = "confirmed"

-- Fragment item full types
POS_Constants.ITEM_INTEL_FRAGMENTARY           = "PhobosOperationalSignals.IntelFragmentary"
POS_Constants.ITEM_INTEL_UNVERIFIED            = "PhobosOperationalSignals.IntelUnverified"
POS_Constants.ITEM_INTEL_CORRELATED            = "PhobosOperationalSignals.IntelCorrelated"
POS_Constants.ITEM_INTEL_CONFIRMED             = "PhobosOperationalSignals.IntelConfirmed"

-- Item tags
POS_Constants.TAG_RAW_INTEL                    = "POS_RawIntel"
POS_Constants.TAG_INTEL_FRAGMENT               = "POS_IntelFragment"
POS_Constants.TAG_CAMERA_INPUT                 = "POS_CameraInput"
POS_Constants.TAG_INTELLIGENCE                 = "POS_Intelligence"

-- Analysis cooldown key prefix
POS_Constants.ANALYSIS_VISIT_KEY_PREFIX        = "POS_AnalysisVisit_"

---------------------------------------------------------------
-- Desktop computer sprites (vanilla, 4 rotations)
---------------------------------------------------------------

POS_Constants.DESKTOP_COMPUTER_SPRITES = {
    ["appliances_com_01_72"] = true,
    ["appliances_com_01_73"] = true,
    ["appliances_com_01_74"] = true,
    ["appliances_com_01_75"] = true,
}

---------------------------------------------------------------
-- Tutorial Milestones
---------------------------------------------------------------

POS_Constants.TUTORIAL_MOD_ID                   = "POS"

POS_Constants.TUTORIAL_FIRST_CONNECTION         = "first_connection"
POS_Constants.TUTORIAL_FIRST_OP_RECEIVED        = "first_operation_received"
POS_Constants.TUTORIAL_FIRST_OP_COMPLETED       = "first_operation_completed"
POS_Constants.TUTORIAL_FIRST_MARKET_NOTE        = "first_market_note"
POS_Constants.TUTORIAL_SIGINT_L3                = "sigint_level_3"
POS_Constants.TUTORIAL_SIGINT_L6                = "sigint_level_6"
POS_Constants.TUTORIAL_SIGINT_L9                = "sigint_level_9"
POS_Constants.TUTORIAL_FIRST_ANALYSIS           = "first_terminal_analysis"
POS_Constants.TUTORIAL_FIRST_CAMERA             = "first_camera_compile"
POS_Constants.TUTORIAL_FIRST_SATELLITE          = "first_satellite_broadcast"
POS_Constants.TUTORIAL_FIRST_INVESTMENT         = "first_investment"
POS_Constants.TUTORIAL_FIRST_DELIVERY           = "first_delivery"
POS_Constants.TUTORIAL_FIRST_DATA_RECORDER      = "first_data_recorder_use"
POS_Constants.TUTORIAL_FIRST_CROSS_CORRELATION  = "first_cross_correlation"

POS_Constants.TUTORIAL_TOAST_TAG                = "pos_tutorial"
POS_Constants.TUTORIAL_TOAST_COLOUR             = "tutorial"

-- Tutorial milestone group names (for PhobosLib_Milestone registry)
POS_Constants.TUTORIAL_GROUP_CORE               = "core"
POS_Constants.TUTORIAL_GROUP_SIGINT             = "sigint"
POS_Constants.TUTORIAL_GROUP_INTEL              = "intel"

-- Tutorial popup modData prefix (for mid-session popup queueing)
POS_Constants.TUTORIAL_POPUP_READY_PREFIX       = "POS_TutorialPopupReady_"
POS_Constants.TUTORIAL_POPUP_SHOWN_PREFIX       = "POS_TutorialPopupShown_"

-- SIGINT level thresholds for tutorial milestones
POS_Constants.TUTORIAL_SIGINT_THRESHOLD_L3      = 3
POS_Constants.TUTORIAL_SIGINT_THRESHOLD_L6      = 6
POS_Constants.TUTORIAL_SIGINT_THRESHOLD_L9      = 9

-- Legacy modData key (backward compat migration)
POS_Constants.MD_RECORDER_TUTORIAL_SHOWN_LEGACY = "MD_RECORDER_TUTORIAL_SHOWN"
