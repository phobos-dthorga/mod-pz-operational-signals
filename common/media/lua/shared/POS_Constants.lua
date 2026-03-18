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
POS_Constants.SCREEN_TRADERS            = "pos.markets.traders"
POS_Constants.SCREEN_REPORTS            = "pos.markets.reports"
POS_Constants.SCREEN_LEDGER             = "pos.markets.ledger"
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

POS_Constants.PAGE_SIZE_COMMODITIES    = 8
POS_Constants.PAGE_SIZE_MARKET_REPORTS = 5

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
