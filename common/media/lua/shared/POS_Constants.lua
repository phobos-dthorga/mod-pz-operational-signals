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

POS_Constants.UI_NAV_PANEL_WIDTH            = 180
POS_Constants.UI_CONTEXT_PANEL_WIDTH        = 200
POS_Constants.UI_CONTEXT_COLLAPSE_THRESHOLD = 900
POS_Constants.UI_SCREEN_PADDING             = 8
POS_Constants.UI_PANEL_GAP                  = 4

---------------------------------------------------------------
-- CRT bezel insets (proportion of terminal dimensions)
---------------------------------------------------------------

POS_Constants.BEZEL_INSET_LEFT   = 0.15
POS_Constants.BEZEL_INSET_RIGHT  = 0.15
POS_Constants.BEZEL_INSET_TOP    = 0.13
POS_Constants.BEZEL_INSET_BOTTOM = 0.30

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

POS_Constants.WMD_WORLD       = "POSNET.World"
POS_Constants.WMD_EXCHANGE    = "POSNET.Exchange"
POS_Constants.WMD_WHOLESALERS = "POSNET.Wholesalers"
POS_Constants.WMD_META        = "POSNET.Meta"
POS_Constants.WMD_BUILDINGS   = "POSNET.Buildings"
POS_Constants.WMD_MAILBOXES   = "POSNET.Mailboxes"

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

POS_Constants.EVENT_LOG_DIR          = "POSNET/events/"
POS_Constants.EVENT_SNAPSHOT_DIR     = "POSNET/snapshots/"
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

---------------------------------------------------------------
-- External cache file paths (flat, Zomboid/Lua/ directory)
---------------------------------------------------------------

POS_Constants.CACHE_FILE_BUILDINGS  = "POSNET/buildings.dat"
POS_Constants.CACHE_FILE_MAILBOXES  = "POSNET/mailboxes.dat"
POS_Constants.CACHE_FILE_SEPARATOR  = "|"
POS_Constants.CACHE_FILE_ROOM_SEP   = ","

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
