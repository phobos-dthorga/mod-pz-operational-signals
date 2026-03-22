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
-- POS_Constants_Trade.lua
-- Trade terminal constants: tuning, state gates, stock
-- indicators, thresholds, aliases, page sizes, SIGINT XP.
---------------------------------------------------------------

require "POS_Constants"

---------------------------------------------------------------
-- Trade Terminal
---------------------------------------------------------------

POS_Constants.SCREEN_TRADE_TERMINAL    = "pos.markets.trade"
POS_Constants.SCREEN_TRADE_CATALOG     = "pos.markets.trade.catalog"
POS_Constants.SCREEN_TRADE_CONFIRM     = "pos.markets.trade.confirm"
POS_Constants.SCREEN_TRADE_RECEIPT     = "pos.markets.trade.receipt"

-- Trade tuning
POS_Constants.TRADE_STOCK_DEPLETION_PER_UNIT   = 0.02
POS_Constants.TRADE_STOCK_REPLENISH_PER_UNIT   = 0.015
POS_Constants.TRADE_MAX_QUANTITY_PER_TX        = 50
POS_Constants.TRADE_SELL_PRICE_RATIO_DEFAULT   = 0.65
POS_Constants.TRADE_BULK_THRESHOLD_DEFAULT     = 10
POS_Constants.TRADE_BULK_DISCOUNT_PCT_DEFAULT  = 10
POS_Constants.TRADE_SIGINT_REQ_DEFAULT         = 1
POS_Constants.TRADE_DUMPING_EXTRA_DISCOUNT     = 0.10

-- Trade state gates
POS_Constants.TRADE_BLOCKED_BUY_STATES = {
    [POS_Constants.WHOLESALER_STATE_WITHHOLDING] = true,
    [POS_Constants.WHOLESALER_STATE_COLLAPSING]  = true,
}
POS_Constants.TRADE_BLOCKED_SELL_STATES = {
    [POS_Constants.WHOLESALER_STATE_COLLAPSING] = true,
}

-- Trade stock indicators
POS_Constants.TRADE_STOCK_ABUNDANT  = 0.70
POS_Constants.TRADE_STOCK_MODERATE  = 0.40
POS_Constants.TRADE_STOCK_LOW       = 0.15

-- Trade stock threshold tiers (for resolveThresholdTier)
POS_Constants.TRADE_STOCK_THRESHOLDS = {
    { threshold = POS_Constants.TRADE_STOCK_LOW,      result = "UI_POS_Trade_StockLow" },
    { threshold = POS_Constants.TRADE_STOCK_MODERATE,  result = "UI_POS_Trade_StockModerate" },
    { threshold = POS_Constants.TRADE_STOCK_ABUNDANT,  result = "UI_POS_Trade_StockAbundant" },
}

-- Trade aliases (used by POS_TradeService as direct lookups)
POS_Constants.TRADE_DEFAULT_SELL_RATIO       = POS_Constants.TRADE_SELL_PRICE_RATIO_DEFAULT
POS_Constants.TRADE_BULK_DISCOUNT_THRESHOLD  = POS_Constants.TRADE_BULK_THRESHOLD_DEFAULT
POS_Constants.TRADE_BULK_DISCOUNT_PERCENT    = POS_Constants.TRADE_BULK_DISCOUNT_PCT_DEFAULT

-- Trade page sizes
POS_Constants.PAGE_SIZE_TRADE_WHOLESALERS = 5
POS_Constants.PAGE_SIZE_TRADE_ITEMS       = 6

-- Trade SIGINT XP
POS_Constants.SIGINT_XP_TRADE_BASE        = 2
POS_Constants.SIGINT_XP_TRADE_BULK_BONUS  = 1

-- Trade WMD key
POS_Constants.WMD_TRADE_HISTORY = "POSNET.TradeHistory"
