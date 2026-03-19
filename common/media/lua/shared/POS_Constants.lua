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
-- Source tier weights (market intel averaging)
---------------------------------------------------------------

POS_Constants.SOURCE_TIER_WEIGHT_FIELD     = 1.0
POS_Constants.SOURCE_TIER_WEIGHT_BROADCAST = 0.7
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
-- Per-player file storage (Zomboid/Lua/POSNET/)
---------------------------------------------------------------

POS_Constants.PLAYER_FILE_PREFIX    = "POSNET/player_"
POS_Constants.PLAYER_FILE_EXT       = ".dat"
POS_Constants.PLAYER_FILE_SEPARATOR = "|"

---------------------------------------------------------------
-- Context menu intel states
---------------------------------------------------------------

POS_Constants.INTEL_STATE_READY          = "ready"
POS_Constants.INTEL_STATE_WRONG_LOCATION = "wrong_location"
POS_Constants.INTEL_STATE_DANGER_NEARBY  = "danger_nearby"
POS_Constants.INTEL_STATE_MISSING_ITEMS  = "missing_items"
POS_Constants.INTEL_STATE_ON_COOLDOWN    = "on_cooldown"
