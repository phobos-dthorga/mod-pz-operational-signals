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
-- All server commands, screen IDs, item types, and shared modData
-- keys that appear in more than one file are defined here.
---------------------------------------------------------------

POS_Constants = {}

---------------------------------------------------------------
-- Server / client command protocol
---------------------------------------------------------------

POS_Constants.CMD_MODULE = "POS"

-- Server → client
POS_Constants.CMD_NEW_OPERATION       = "NewOperation"
POS_Constants.CMD_NEW_INVESTMENT      = "NewInvestment"
POS_Constants.CMD_INVESTMENT_RESOLVED = "InvestmentResolved"
POS_Constants.CMD_INVESTMENT_ACK      = "InvestmentAcknowledged"

-- Client → server
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
-- Market screen IDs (reserved for future implementation)
---------------------------------------------------------------

POS_Constants.SCREEN_MARKETS            = "pos.markets"
POS_Constants.SCREEN_COMMODITIES        = "pos.markets.commodities"
POS_Constants.SCREEN_COMMODITY_DETAIL   = "pos.markets.commodity.detail"
POS_Constants.SCREEN_COMMODITY_ITEMS   = "pos.markets.commodity.items"
POS_Constants.SCREEN_TRADERS            = "pos.markets.traders"
POS_Constants.SCREEN_REPORTS            = "pos.markets.reports"
POS_Constants.SCREEN_LEDGER             = "pos.markets.ledger"
POS_Constants.SCREEN_WATCHLIST          = "pos.markets.watchlist"
POS_Constants.SCREEN_EXCHANGE           = "pos.exchange"
POS_Constants.SCREEN_EXCHANGE_OVERVIEW  = "pos.exchange.overview"
POS_Constants.SCREEN_EXCHANGE_PORTFOLIO = "pos.exchange.portfolio"

---------------------------------------------------------------
-- Market modData keys
---------------------------------------------------------------

POS_Constants.MD_MARKET_INTEL  = "POS_MarketIntel"
POS_Constants.MD_PRICE_HISTORY = "POS_PriceHistory"

---------------------------------------------------------------
-- Market freshness thresholds (game days)
---------------------------------------------------------------

POS_Constants.MARKET_FRESH_DAYS   = 2
POS_Constants.MARKET_STALE_DAYS   = 7
POS_Constants.MARKET_EXPIRED_DAYS = 14

---------------------------------------------------------------
-- Market trend thresholds (percentage as decimal)
---------------------------------------------------------------

POS_Constants.TREND_RISING_PCT  = 0.02
POS_Constants.TREND_FALLING_PCT = 0.02

---------------------------------------------------------------
-- Market item types
---------------------------------------------------------------

POS_Constants.ITEM_RAW_MARKET_NOTE    = "PhobosOperationalSignals.RawMarketNote"
POS_Constants.ITEM_COMPILED_REPORT    = "PhobosOperationalSignals.CompiledMarketReport"

---------------------------------------------------------------
-- Market modData keys (item-level)
---------------------------------------------------------------

POS_Constants.MD_NOTE_TYPE       = "POS_NoteType"
POS_Constants.MD_NOTE_CATEGORY   = "POS_CategoryId"
POS_Constants.MD_NOTE_SOURCE     = "POS_Source"
POS_Constants.MD_NOTE_LOCATION   = "POS_Location"
POS_Constants.MD_NOTE_PRICE      = "POS_Price"
POS_Constants.MD_NOTE_STOCK      = "POS_Stock"
POS_Constants.MD_NOTE_RECORDED   = "POS_RecordedDay"
POS_Constants.MD_NOTE_CONFIDENCE = "POS_Confidence"
POS_Constants.MD_NOTE_ITEMS      = "POS_NoteItems"

POS_Constants.MD_REPORT_TYPE     = "POS_ReportType"
POS_Constants.MD_REPORT_REGION   = "POS_Region"
POS_Constants.MD_REPORT_LOW      = "POS_LowPrice"
POS_Constants.MD_REPORT_HIGH     = "POS_HighPrice"
POS_Constants.MD_REPORT_AVG      = "POS_AvgPrice"
POS_Constants.MD_REPORT_SOURCES  = "POS_SourceCount"
POS_Constants.MD_REPORT_COMPILED = "POS_CompiledDay"

---------------------------------------------------------------
-- Market action constants
---------------------------------------------------------------

POS_Constants.MARKET_NOTE_ACTION_TIME     = 300
POS_Constants.MARKET_REPEAT_DISCOUNT_PCT  = 50
POS_Constants.MARKET_REPEAT_WINDOW_DAYS   = 7
POS_Constants.MARKET_COMPILE_MIN_RECORDS  = 3

---------------------------------------------------------------
-- Market server commands
---------------------------------------------------------------

POS_Constants.CMD_MARKET_BROADCAST = "MarketBroadcast"

---------------------------------------------------------------
-- Item pool constants
---------------------------------------------------------------

POS_Constants.ITEM_POOL_WEIGHT_PRECISION     = 1000
POS_Constants.ITEM_POOL_OFF_CATEGORY_CHANCE  = 5
POS_Constants.ITEM_POOL_MIN_BASE_PRICE       = 0.50
POS_Constants.ITEM_POOL_WEIGHT_MULTIPLIER    = 2.0
POS_Constants.ITEM_POOL_CONDITION_MULTIPLIER = 1.5

---------------------------------------------------------------
-- Price engine constants
---------------------------------------------------------------

POS_Constants.PRICE_BASE_VARIANCE_PCT      = 30
POS_Constants.PRICE_BROADCAST_VARIANCE_PCT = 50
POS_Constants.PRICE_DRIFT_SEED_MULTIPLIER  = 31
POS_Constants.PRICE_DRIFT_RANGE            = 200
POS_Constants.PRICE_DRIFT_DIVISOR          = 5000
POS_Constants.PRICE_INTEL_BIAS_MAX         = 0.02
POS_Constants.PRICE_MIN_OUTPUT             = 0.01

-- Reputation variance multipliers (indexed by tier 1-5)
POS_Constants.REP_VARIANCE_MULTIPLIERS = { 1.5, 1.2, 1.0, 0.8, 0.6 }

---------------------------------------------------------------
-- Source tier identifiers
---------------------------------------------------------------

POS_Constants.SOURCE_TIER_FIELD     = "field"
POS_Constants.SOURCE_TIER_BROADCAST = "broadcast"

---------------------------------------------------------------
-- Source tier weights (market intel averaging)
---------------------------------------------------------------

POS_Constants.SOURCE_TIER_WEIGHT_FIELD     = 1.0
POS_Constants.SOURCE_TIER_WEIGHT_BROADCAST = 0.7
POS_Constants.SOURCE_TIER_WEIGHT_STUDIO   = 1.2
POS_Constants.SOURCE_TIER_WEIGHT_DEFAULT   = 0.85

---------------------------------------------------------------
-- Category price multipliers (item pool base pricing)
---------------------------------------------------------------

POS_Constants.CATEGORY_PRICE_MULTIPLIERS = {
    fuel          = 1.5,
    medicine      = 1.3,
    food          = 0.8,
    ammunition    = 1.4,
    tools         = 1.0,
    radio         = 1.2,
    survival      = 0.9,
    weapons       = 1.3,
    clothing      = 0.6,
    literature    = 0.4,
    miscellaneous = 0.3,
}

---------------------------------------------------------------
-- Supply/demand factor (price engine)
---------------------------------------------------------------

POS_Constants.PRICE_SD_FACTOR_PER_SOURCE = 0.01
POS_Constants.PRICE_SD_FACTOR_BASELINE   = 5
POS_Constants.PRICE_SD_FACTOR_CLAMP      = 0.1

---------------------------------------------------------------
-- Exchange engine
---------------------------------------------------------------

POS_Constants.EXCHANGE_INDEX_BASE_VALUE    = 100
POS_Constants.EXCHANGE_INDEX_LOOKBACK_DAYS = 30
POS_Constants.EXCHANGE_TREND_LOOKBACK_DAYS = 7

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
POS_Constants.WATCHLIST_MAX_ENTRIES      = 20
POS_Constants.WATCHLIST_PRICE_CHANGE_PCT = 10

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
-- Passive recon device item types
---------------------------------------------------------------

POS_Constants.ITEM_RECON_CAMCORDER      = "PhobosOperationalSignals.ReconCamcorder"
POS_Constants.ITEM_FIELD_SURVEY_LOGGER  = "PhobosOperationalSignals.FieldSurveyLogger"
POS_Constants.ITEM_DATA_CALCULATOR      = "PhobosOperationalSignals.DataCalculator"
POS_Constants.ITEM_BLANK_VHS_TAPE       = "PhobosOperationalSignals.BlankVHSCTape"
POS_Constants.ITEM_RECORDED_RECON_TAPE  = "PhobosOperationalSignals.RecordedReconTape"
POS_Constants.ITEM_WORN_VHS_TAPE        = "PhobosOperationalSignals.WornVHSTape"
POS_Constants.ITEM_DAMAGED_VHS_TAPE     = "PhobosOperationalSignals.DamagedVHSTape"
POS_Constants.ITEM_MAGNETIC_TAPE_SCRAP  = "PhobosOperationalSignals.MagneticTapeScrap"
POS_Constants.ITEM_REFURBISHED_TAPE     = "PhobosOperationalSignals.RefurbishedVHSCTape"
POS_Constants.ITEM_SPLICED_TAPE         = "PhobosOperationalSignals.SplicedReconTape"
POS_Constants.ITEM_IMPROVISED_TAPE      = "PhobosOperationalSignals.ImprovisedReconTape"

---------------------------------------------------------------
-- Passive recon scan parameters
---------------------------------------------------------------

POS_Constants.RECON_CAMCORDER_SCAN_RADIUS  = 40
POS_Constants.RECON_LOGGER_SCAN_RADIUS     = 25
POS_Constants.RECON_SCAN_INTERVAL_SECONDS  = 60
POS_Constants.RECON_LOGGER_INTERNAL_CAP    = 10

---------------------------------------------------------------
-- VHS tape parameters
---------------------------------------------------------------

POS_Constants.VHS_FACTORY_CAPACITY         = 20
POS_Constants.VHS_REFURBISHED_CAPACITY     = 15
POS_Constants.VHS_SPLICED_CAPACITY         = 8
POS_Constants.VHS_IMPROVISED_CAPACITY      = 4
POS_Constants.VHS_MIN_OPERATION_DAYS       = 3
POS_Constants.VHS_DEGRADATION_RATE_PCT     = 10

---------------------------------------------------------------
-- Tape confidence modifiers (basis points)
---------------------------------------------------------------

POS_Constants.VHS_CONFIDENCE_MOD_FACTORY      = 0
POS_Constants.VHS_CONFIDENCE_MOD_REFURBISHED  = -1000
POS_Constants.VHS_CONFIDENCE_MOD_SPLICED      = -2500
POS_Constants.VHS_CONFIDENCE_MOD_IMPROVISED   = -5000

---------------------------------------------------------------
-- Device inventory bonuses (when carried but not equipped)
---------------------------------------------------------------

POS_Constants.CAMCORDER_CARRY_CONFIDENCE_BONUS  = 1500   -- +15% in BPS
POS_Constants.LOGGER_CARRY_CONFIDENCE_BONUS     = 1000   -- +10% in BPS
POS_Constants.CALCULATOR_CARRY_CONFIDENCE_BONUS = 500    -- +5% in BPS

---------------------------------------------------------------
-- Camcorder noise
---------------------------------------------------------------

POS_Constants.CAMCORDER_NOISE_LEVEL_DEFAULT = 5

---------------------------------------------------------------
-- Tape modData keys
---------------------------------------------------------------

POS_Constants.MD_TAPE_ENTRIES     = "POS_TapeEntries"
POS_Constants.MD_TAPE_CAPACITY    = "POS_TapeCapacity"
POS_Constants.MD_TAPE_QUALITY     = "POS_TapeQuality"
POS_Constants.MD_TAPE_REGION      = "POS_TapeRegion"
POS_Constants.MD_TAPE_DURATION    = "POS_TapeDuration"
POS_Constants.MD_TAPE_ENTRY_COUNT = "POS_TapeEntryCount"
POS_Constants.MD_TAPE_WEAR        = "POS_TapeWear"

---------------------------------------------------------------
-- Intel gathering cooldown
---------------------------------------------------------------

POS_Constants.INTEL_COOLDOWN_DAYS_DEFAULT = 12
POS_Constants.INTEL_VISIT_KEY_PREFIX      = "POS_IntelVisit_"
POS_Constants.INTEL_CLEANUP_MULTIPLIER    = 2

---------------------------------------------------------------
-- VHS tape event log linking
---------------------------------------------------------------

POS_Constants.MD_TAPE_ID = "POS_TapeId"

---------------------------------------------------------------
-- VHS review at TV station
---------------------------------------------------------------

POS_Constants.VHS_REVIEW_TIME_PER_ENTRY    = 300
POS_Constants.VHS_REVIEW_SOURCE_LABEL      = "VHS Tape Review"
POS_Constants.NOTEBOOK_CONDITION_PER_NOTE  = 1

---------------------------------------------------------------
-- UI text overflow prevention
---------------------------------------------------------------

POS_Constants.UI_BUTTON_TEXT_ELLIPSIS   = "..."
POS_Constants.UI_MIN_SEPARATOR_CHARS    = 10
POS_Constants.UI_BUTTON_TEXT_PADDING    = 16

---------------------------------------------------------------
-- UI Layout — Pagination & progress bars
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

POS_Constants.CACHE_FILE_BUILDINGS  = "POSNET_buildings.dat"
POS_Constants.CACHE_FILE_MAILBOXES  = "POSNET_mailboxes.dat"
POS_Constants.CACHE_FILE_SEPARATOR  = "|"
POS_Constants.CACHE_FILE_ROOM_SEP   = ","

---------------------------------------------------------------
-- Market data file store (observations + rolling closes)
---------------------------------------------------------------

POS_Constants.MARKET_DATA_FILE            = "POSNET_market_data.dat"
POS_Constants.MARKET_FILE_SECTION_PREFIX  = "[CATEGORY:"
POS_Constants.MARKET_FILE_SECTION_SUFFIX  = "]"
POS_Constants.MARKET_FILE_OBS_HEADER      = "[OBS]"
POS_Constants.MARKET_FILE_CLOSES_HEADER   = "[CLOSES]"
POS_Constants.MARKET_FILE_ITEM_SEP        = ";"
POS_Constants.MARKET_FILE_ITEM_KV_SEP     = ":"
POS_Constants.MARKET_FILE_CHUNK_SIZE      = 4

---------------------------------------------------------------
-- Per-player file storage (Zomboid/Lua/POSNET/)
---------------------------------------------------------------

POS_Constants.PLAYER_FILE_PREFIX    = "POSNET/player_"
POS_Constants.PLAYER_FILE_EXT       = ".dat"
POS_Constants.PLAYER_FILE_SEPARATOR = "|"
POS_Constants.PLAYER_FILE_SECTION_WATCHLIST = "[WATCHLIST]"
POS_Constants.PLAYER_FILE_SECTION_ALERTS    = "[ALERTS]"
POS_Constants.PLAYER_FILE_SECTION_ORDERS    = "[ORDERS]"
POS_Constants.PLAYER_FILE_SECTION_HOLDINGS  = "[HOLDINGS]"

---------------------------------------------------------------
-- Context menu intel states
---------------------------------------------------------------

POS_Constants.INTEL_STATE_READY          = "ready"
POS_Constants.INTEL_STATE_WRONG_LOCATION = "wrong_location"
POS_Constants.INTEL_STATE_DANGER_NEARBY  = "danger_nearby"
POS_Constants.INTEL_STATE_MISSING_ITEMS  = "missing_items"
POS_Constants.INTEL_STATE_ON_COOLDOWN    = "on_cooldown"

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
-- Market note category base prices (fallback when PriceEngine
-- or ItemPool are not yet initialised)
---------------------------------------------------------------

POS_Constants.MARKET_NOTE_BASE_PRICES = {
    fuel       = 8.0,
    medicine   = 12.0,
    food       = 5.0,
    ammunition = 15.0,
    tools      = 10.0,
    radio      = 20.0,
    chemicals  = 18.0,
    agriculture = 6.0,
    biofuel    = 9.0,
    specimens  = 25.0,
    biohazard  = 30.0,
}
POS_Constants.MARKET_NOTE_BASE_PRICE_DEFAULT = 10.0

---------------------------------------------------------------
-- Data-Recorder screen IDs
---------------------------------------------------------------

POS_Constants.SCREEN_DATA_MANAGEMENT = "pos.data"

---------------------------------------------------------------
-- Data-Recorder item types
---------------------------------------------------------------

POS_Constants.ITEM_DATA_RECORDER          = "PhobosOperationalSignals.DataRecorder"
POS_Constants.ITEM_MICROCASSETTE          = "PhobosOperationalSignals.Microcassette"
POS_Constants.ITEM_RECORDED_MICROCASSETTE = "PhobosOperationalSignals.RecordedMicrocassette"
POS_Constants.ITEM_REWOUND_MICROCASSETTE  = "PhobosOperationalSignals.RewoundMicrocassette"
POS_Constants.ITEM_SPENT_MICROCASSETTE    = "PhobosOperationalSignals.SpentMicrocassette"
POS_Constants.ITEM_BLANK_FLOPPY_DISK     = "PhobosOperationalSignals.BlankFloppyDisk"
POS_Constants.ITEM_RECORDED_FLOPPY_DISK  = "PhobosOperationalSignals.RecordedFloppyDisk"
POS_Constants.ITEM_WORN_FLOPPY_DISK      = "PhobosOperationalSignals.WornFloppyDisk"
POS_Constants.ITEM_CORRUPT_FLOPPY_DISK   = "PhobosOperationalSignals.CorruptFloppyDisk"

---------------------------------------------------------------
-- Media family identifiers
---------------------------------------------------------------

POS_Constants.MEDIA_FAMILY_VHS          = "vhs"
POS_Constants.MEDIA_FAMILY_MICROCASSETTE = "microcassette"
POS_Constants.MEDIA_FAMILY_FLOPPY       = "floppy"

---------------------------------------------------------------
-- Media fidelity levels
---------------------------------------------------------------

POS_Constants.MEDIA_FIDELITY_STANDARD = "standard"
POS_Constants.MEDIA_FIDELITY_HIGH     = "high"
POS_Constants.MEDIA_FIDELITY_DIGITAL  = "digital"

---------------------------------------------------------------
-- Media capacity (entries)
---------------------------------------------------------------

POS_Constants.MICROCASSETTE_CAPACITY       = 10
POS_Constants.MICROCASSETTE_REWIND_CAP     = 10
POS_Constants.FLOPPY_CAPACITY              = 40

---------------------------------------------------------------
-- Media confidence modifiers (basis points)
---------------------------------------------------------------

POS_Constants.MICROCASSETTE_CONFIDENCE_MOD         = 1000
POS_Constants.MICROCASSETTE_REWOUND_CONFIDENCE_MOD = 500
POS_Constants.FLOPPY_CONFIDENCE_MOD                = 2000
POS_Constants.FLOPPY_WORN_CONFIDENCE_MOD           = 1000

---------------------------------------------------------------
-- Data-Recorder modData keys
---------------------------------------------------------------

POS_Constants.MD_RECORDER_ID             = "POS_RecorderId"
POS_Constants.MD_RECORDER_BUFFER_COUNT   = "POS_RecorderBufferCount"
POS_Constants.MD_RECORDER_BUFFER_CAP     = "POS_RecorderBufferCapacity"
POS_Constants.MD_RECORDER_MEDIA_TYPE     = "POS_RecorderMediaType"
POS_Constants.MD_RECORDER_MEDIA_ID       = "POS_RecorderMediaId"
POS_Constants.MD_RECORDER_MEDIA_USED     = "POS_RecorderMediaUsed"
POS_Constants.MD_RECORDER_MEDIA_CAP      = "POS_RecorderMediaCapacity"
POS_Constants.MD_RECORDER_TOTAL_RECORDED = "POS_RecorderTotalRecorded"
POS_Constants.MD_RECORDER_LAST_REGION    = "POS_RecorderLastRegion"
POS_Constants.MD_RECORDER_POWERED        = "POS_RecorderPowered"
POS_Constants.MD_RECORDER_SOURCE_ID      = "POS_RecorderSourceId"
POS_Constants.MD_RECORDER_TUTORIAL_SHOWN = "POS_RecorderTutorialShown"

---------------------------------------------------------------
-- Unified media modData keys (replaces POS_Tape* keys)
---------------------------------------------------------------

POS_Constants.MD_MEDIA_ID           = "POS_MediaId"
POS_Constants.MD_MEDIA_FAMILY       = "POS_MediaFamily"
POS_Constants.MD_MEDIA_ENTRY_COUNT  = "POS_MediaEntryCount"
POS_Constants.MD_MEDIA_CAPACITY     = "POS_MediaCapacity"
POS_Constants.MD_MEDIA_FIDELITY     = "POS_MediaFidelity"
POS_Constants.MD_MEDIA_CONF_MOD     = "POS_MediaConfidenceMod"
POS_Constants.MD_MEDIA_WEAR         = "POS_MediaWear"
POS_Constants.MD_MEDIA_REGION       = "POS_MediaRegion"
POS_Constants.MD_MEDIA_CYCLE_COUNT  = "POS_MediaCycleCount"
POS_Constants.MD_MEDIA_MIGRATED     = "POS_MediaMigrated"

---------------------------------------------------------------
-- Data chunk types
---------------------------------------------------------------

POS_Constants.CHUNK_TYPE_BUILDING_SCAN      = "building_scan"
POS_Constants.CHUNK_TYPE_RADIO_INTERCEPT    = "radio_intercept"
POS_Constants.CHUNK_TYPE_MARKET_OBSERVATION = "market_observation"
POS_Constants.CHUNK_TYPE_SIGNAL_PROBE       = "signal_probe"
POS_Constants.CHUNK_TYPE_ENVIRONMENTAL      = "environmental"

---------------------------------------------------------------
-- Data source categories
---------------------------------------------------------------

POS_Constants.DATA_SOURCE_RADIO   = "radio"
POS_Constants.DATA_SOURCE_RECON   = "recon"
POS_Constants.DATA_SOURCE_PASSIVE = "passive"

---------------------------------------------------------------
-- Device confidence base values (basis points)
---------------------------------------------------------------

POS_Constants.DEVICE_CONFIDENCE_CAMCORDER = 3000
POS_Constants.DEVICE_CONFIDENCE_LOGGER    = 1000
POS_Constants.DEVICE_CONFIDENCE_RECORDER  = 0

---------------------------------------------------------------
-- Recorder parameters
---------------------------------------------------------------

POS_Constants.RECORDER_INTERNAL_BUFFER_DEFAULT   = 8
POS_Constants.RECORDER_POWER_DRAIN_RATE_DEFAULT  = 50
POS_Constants.RECORDER_PROCESSING_TIME_DEFAULT   = 30
POS_Constants.RECORDER_CONDITION_BPS_PER_PERCENT = 50

---------------------------------------------------------------
-- Floppy disk corruption
---------------------------------------------------------------

POS_Constants.FLOPPY_CORRUPTION_CHANCE_DEFAULT = 5
POS_Constants.MICROCASSETTE_MAX_REWINDS_DEFAULT = 1

---------------------------------------------------------------
-- Data-Recorder event log types
---------------------------------------------------------------

POS_Constants.EVENT_RECORDER_CHUNK   = "recorder_chunk"
POS_Constants.EVENT_RECORDER_PROCESS = "recorder_process"
POS_Constants.EVENT_MEDIA_INSERT     = "media_insert"
POS_Constants.EVENT_MEDIA_EJECT      = "media_eject"

---------------------------------------------------------------
-- Confidence formula constants
---------------------------------------------------------------

POS_Constants.CONFIDENCE_MIN_EFFECTIVE  = 10
POS_Constants.CONFIDENCE_BASE_EFFECTIVE = 50
POS_Constants.CONFIDENCE_BPS_DIVISOR    = 100

---------------------------------------------------------------
-- PhobosNotifications channel
---------------------------------------------------------------

POS_Constants.PN_CHANNEL_ID        = "POSnet"
POS_Constants.PN_CHANNEL_LABEL_KEY = "UI_POS_Channel_POSnet"

---------------------------------------------------------------
-- Intelligence Summary screen
---------------------------------------------------------------

POS_Constants.SCREEN_INTEL_SUMMARY = "pos.markets.summary"

---------------------------------------------------------------
-- Camera Workstation (Tier III — Compilation)
---------------------------------------------------------------

POS_Constants.SOURCE_TIER_STUDIO              = "studio"
POS_Constants.ITEM_COMPILED_SITE_SURVEY       = "PhobosOperationalSignals.CompiledSiteSurvey"
POS_Constants.ITEM_VERIFIED_INTEL_REPORT      = "PhobosOperationalSignals.VerifiedIntelReport"
POS_Constants.ITEM_MARKET_BULLETIN            = "PhobosOperationalSignals.MarketBulletin"
POS_Constants.CAMERA_VISIT_KEY_PREFIX         = "POS_CameraVisit_"
POS_Constants.CAMERA_COMPILE_ACTION           = "compile"
POS_Constants.CAMERA_TAPE_REVIEW_ACTION       = "tape_review"
POS_Constants.CAMERA_BULLETIN_ACTION          = "bulletin"

---------------------------------------------------------------
-- Market Intel — Writing Tools & Paper (deduplicated)
---------------------------------------------------------------

POS_Constants.WRITING_TOOLS = {
    "Base.Pen", "Base.Pencil", "Base.RedPen", "Base.BluePen",
    "Base.GreenPen", "Base.PenMultiColor", "Base.PenFancy",
    "Base.PenSpiffo", "Base.PencilSpiffo",
}

POS_Constants.PAPER_TYPES = { "Base.SheetPaper2", "Base.Notebook" }

-- Camera confidence caps (percentage)
POS_Constants.CAMERA_SURVEY_CONFIDENCE_CAP    = 90
POS_Constants.CAMERA_REPORT_CONFIDENCE_CAP    = 95
POS_Constants.CAMERA_BULLETIN_CONFIDENCE_CAP  = 95

-- Camera quality multipliers
POS_Constants.CAMERA_SURVEY_MULTIPLIER        = 1.4
POS_Constants.CAMERA_REPORT_MULTIPLIER        = 1.5
POS_Constants.CAMERA_BULLETIN_MULTIPLIER      = 1.6

-- Camera confidence bonuses
POS_Constants.CAMERA_LOCATION_BONUS           = 10
POS_Constants.CAMERA_DIVERSITY_BONUS_PER_LOC  = 3
POS_Constants.CAMERA_DIVERSITY_BONUS_CAP      = 15
POS_Constants.CAMERA_CATEGORY_BONUS_PER_CAT   = 3
POS_Constants.CAMERA_CATEGORY_BONUS_CAP       = 15
POS_Constants.CAMERA_EQUIPMENT_BONUS          = 5
POS_Constants.CAMERA_EQUIPMENT_CONDITION_MIN  = 80

-- Camera action defaults
POS_Constants.CAMERA_COMPILE_TIME_DEFAULT     = 300
POS_Constants.CAMERA_TAPE_REVIEW_TIME_DEFAULT = 200
POS_Constants.CAMERA_BULLETIN_TIME_DEFAULT    = 450
POS_Constants.CAMERA_COMPILE_COOLDOWN_DEFAULT = 6    -- hours
POS_Constants.CAMERA_TAPE_COOLDOWN_DEFAULT    = 4    -- hours
POS_Constants.CAMERA_BULLETIN_COOLDOWN_DEFAULT = 12  -- hours

-- Camera reputation
POS_Constants.CAMERA_BULLETIN_REP_DEFAULT     = 50   -- hundredths of rep point

-- Camera workstation sprites (vanilla security camera monitors, 4 rotations)
POS_Constants.CAMERA_WORKSTATION_SPRITES      = {
    "appliances_com_01_44",
    "appliances_com_01_45",
    "appliances_com_01_46",
    "appliances_com_01_47",
}

-- Media building room types for location bonus
POS_Constants.CAMERA_MEDIA_ROOM_TYPES         = {
    "tvstudio", "broadcast", "avroom",
}

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
-- Terminal Analysis (Tier II — Processing)
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
-- Satellite Uplink (Tier IV — Broadcast)
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

-- Desktop computer sprites (vanilla, 4 rotations)
POS_Constants.DESKTOP_COMPUTER_SPRITES = {
    ["appliances_com_01_72"] = true,
    ["appliances_com_01_73"] = true,
    ["appliances_com_01_74"] = true,
    ["appliances_com_01_75"] = true,
}

-- Satellite dish sprites (vanilla satellite dish, 2 rotations)
POS_Constants.SATELLITE_DISH_SPRITES           = {
    "appliances_com_01_20",
    "appliances_com_01_21",
}

-- Equipment condition threshold for bonus
POS_Constants.SATELLITE_DISH_CONDITION_BONUS_MIN = 80

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
-- Living Market: Simulation Defaults
---------------------------------------------------------------

POS_Constants.SIMULATION_TICK_INTERVAL_DEFAULT    = 20
POS_Constants.SIMULATION_PRESSURE_CLAMP_MIN       = -2.0
POS_Constants.SIMULATION_PRESSURE_CLAMP_MAX       = 2.0
POS_Constants.SIMULATION_THROUGHPUT_FACTOR         = 0.5
POS_Constants.SIMULATION_ZONE_DEFAULT_VOLATILITY   = 0.20

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
    "food", "medicine", "ammunition", "fuel", "tools", "radio", "weapons",
}

---------------------------------------------------------------
-- Living Market: Agent Meter Rates (per tick)
---------------------------------------------------------------

POS_Constants.AGENT_PRESSURE_APPROACH_RATE   = 0.20
POS_Constants.AGENT_GREED_VOLATILITY_FACTOR  = 0.10
POS_Constants.AGENT_EXPOSURE_DECAY_RATE      = 0.08
POS_Constants.AGENT_SURPLUS_APPROACH_RATE    = 0.15
POS_Constants.AGENT_TRUST_DECAY_RATE         = 0.05

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

