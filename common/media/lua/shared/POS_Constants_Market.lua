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
-- POS_Constants_Market.lua
-- Market screen IDs, modData keys, freshness, trend, pricing,
-- item pools, price engine, exchange engine, and market intel.
---------------------------------------------------------------

require "POS_Constants"

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
-- DEPRECATED: absorbed into other screens during consolidation (§33.4)
-- POS_Constants.SCREEN_ZONE_OVERVIEW     = "pos.markets.zones"       -- → Market Overview Tab 2
-- POS_Constants.SCREEN_EVENT_LOG         = "pos.markets.events"      -- → Market Signals (filtered)
-- POS_Constants.SCREEN_WHOLESALER_DIR    = "pos.markets.directory"   -- → Contacts Tab 2
POS_Constants.SCREEN_CONTRACTS         = "pos.markets.contracts"
POS_Constants.SCREEN_AGENT_DEPLOY      = "pos.bbs.agents.deploy"
POS_Constants.SCREEN_TRADE_TERMINAL    = "pos.markets.trade"
POS_Constants.SCREEN_TRADE_CATALOG     = "pos.markets.trade.catalog"
POS_Constants.SCREEN_TRADE_CONFIRM     = "pos.markets.trade.confirm"
POS_Constants.SCREEN_TRADE_RECEIPT     = "pos.markets.trade.receipt"

POS_Constants.WHOLESALER_VISIBLE_THRESHOLD = 0.3
POS_Constants.WHOLESALER_DIR_SIGINT_REQ    = 3
POS_Constants.TRADE_TERMINAL_SIGINT_REQ    = 4
POS_Constants.TRADE_MAX_QUANTITY_PER_TX    = 50

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

-- Packaging suffix → price multiplier (Tier 1 pricing: §59)
-- Items ending in these suffixes get their base item's price × multiplier.
-- If the base item has no curated override, weight fallback × multiplier is used.
POS_Constants.PRICING_BOX_MULT    = 3.0    -- Box: ~6-12 individual items
POS_Constants.PRICING_CARTON_MULT = 8.0    -- Carton: ~12+ boxes (bulk wholesale)
POS_Constants.PRICING_CASE_MULT   = 5.0    -- Case: mid-size container
POS_Constants.PRICING_PACK_MULT   = 2.0    -- Pack: small pack (2-6 items)
POS_Constants.PRICING_CRATE_MULT  = 10.0   -- Crate: large shipping container

-- Packaging suffix detection table (ordered longest-first for greedy matching)
POS_Constants.PACKAGING_SUFFIXES = {
    { suffix = "_Carton",  mult = POS_Constants.PRICING_CARTON_MULT },
    { suffix = "_Boxed",   mult = POS_Constants.PRICING_BOX_MULT },
    { suffix = "_Crate",   mult = POS_Constants.PRICING_CRATE_MULT },
    { suffix = "_Case",    mult = POS_Constants.PRICING_CASE_MULT },
    { suffix = "_Pack",    mult = POS_Constants.PRICING_PACK_MULT },
    { suffix = "_Box",     mult = POS_Constants.PRICING_BOX_MULT },
}

-- Property-bonus pricing scales (Tier 3: §58)
-- Applied to uncurated items in the weight-fallback path to differentiate
-- items within a category based on their actual utility/effectiveness.
POS_Constants.PRICING_DAMAGE_SCALE        = 1.5   -- MaxDamage × this = additive bonus
POS_Constants.PRICING_CALORIE_DIVISOR     = 500   -- calories / this = additive bonus (capped)
POS_Constants.PRICING_CALORIE_CAP         = 3.0   -- max calorie bonus multiplier
POS_Constants.PRICING_PAIN_SCALE          = 0.5   -- PainReduction × this = additive bonus
POS_Constants.PRICING_INFECTION_SCALE     = 2.0   -- ReduceInfectionPower × this = additive bonus
POS_Constants.PRICING_CONDITION_THRESHOLD = 5     -- conditionMax must exceed this for bonus
POS_Constants.PRICING_CONDITION_DIVISOR   = 20    -- conditionMax / this = additive bonus
POS_Constants.PRICING_RANGE_THRESHOLD     = 2.0   -- maxRange must exceed this for bonus
POS_Constants.PRICING_RANGE_SCALE         = 0.1   -- maxRange × this = additive bonus

---------------------------------------------------------------
-- Item pool curation: excluded DisplayCategories
-- Items with these DisplayCategories are NEVER included in
-- the tradeable item pool. See docs/item-pool-curation.md.
---------------------------------------------------------------

POS_Constants.ITEM_POOL_EXCLUDED_CATEGORIES = {
    -- Zombie / body damage textures
    ["ZedDmg"]       = true,   -- zombie damage clothing overlays
    ["Wound"]        = true,   -- blood-soaked bandage body states
    ["Bandage"]      = true,   -- blood-soaked bandage variants
    ["Corpse"]       = true,   -- body part items
    ["AnimalPart"]   = true,   -- skulls, organs, sinew
    -- Character cosmetics / body slots
    ["MaleBody"]     = true,
    ["Ears"]         = true,
    ["Tail"]         = true,
    ["Appearance"]   = true,   -- cosmetic character presets
    -- Debug / internal
    ["Hidden"]       = true,
    ["Bug"]          = true,
    -- Non-inventory world objects
    ["Furniture"]    = true,   -- world fixtures
    ["Container"]    = true,   -- structural containers
    -- Explicitly valueless
    ["Junk"]         = true,
    ["Memento"]      = true,   -- character-bound keepsakes
    ["Generic"]      = true,
    -- Animal / live entities
    ["Animal"]       = true,
    -- Animal corpse categories
    ["Raccoon"]      = true,
    ["Fox"]          = true,
    ["Duck"]         = true,
    ["Bunny"]        = true,
    ["Spider"]       = true,
    ["Mole"]         = true,
    ["Hedgehog"]     = true,
    ["Goblin"]       = true,
    ["Eye"]          = true,
    ["Badger"]       = true,
    ["Bear"]         = true,
    ["Beaver"]       = true,
    ["Dog"]          = true,
    ["Frog"]         = true,
    ["Squirrel"]     = true,
}

---------------------------------------------------------------
-- Item pool curation: excluded name patterns
-- Items matching ANY of these plain-text patterns are excluded
-- even if their DisplayCategory is otherwise whitelisted.
-- See docs/item-pool-curation.md.
---------------------------------------------------------------

POS_Constants.ITEM_POOL_EXCLUDED_PATTERNS = {
    "_Blood",       -- blood-soaked variants (e.g. Bandage_Abdomen_Blood)
    "ZedDmg_",      -- zombie damage prefix (belt-and-suspenders)
    "Wound_",       -- wound state prefix
    "Corpse",       -- any corpse-related item
    "_Broken",      -- broken item variants
}

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

-- Multipliers reflect apocalyptic economy where survival goods dominate
-- and pre-apocalypse luxuries collapse. Literature stays high because
-- skill books and recipe books are irreplaceable survival knowledge.
POS_Constants.CATEGORY_PRICE_MULTIPLIERS = {
    fuel          = 3.0,    -- irreplaceable energy: generators, vehicles, heating
    ammunition    = 2.8,    -- finite supply, each round matters
    medicine      = 2.5,    -- no hospitals, antibiotics are gold
    weapons       = 2.2,    -- defence is paramount
    literature    = 2.0,    -- knowledge is survival: skill books, recipe books
    automotive    = 2.0,    -- vehicle parts: hard to find, essential for mobility
    radio         = 1.8,    -- communication = coordination
    survival      = 1.6,    -- water/camping gear essential
    vehicles      = 1.6,    -- complete vehicles / vehicle-level items
    tools         = 2.0,    -- build, repair, survive (wrench→generator range)
    food          = 1.4,    -- caloric necessity
    agriculture   = 1.2,    -- seeds, trowels, watering cans: long-term value
    clothing      = 0.8,    -- weather/armour protection
    miscellaneous = 0.5,    -- low-value items, but not worthless
}

---------------------------------------------------------------
-- Supply/demand factor (price engine)
---------------------------------------------------------------

POS_Constants.PRICE_SD_FACTOR_PER_SOURCE = 0.01
POS_Constants.PRICE_SD_FACTOR_BASELINE   = 5
POS_Constants.PRICE_SD_FACTOR_CLAMP      = 0.1
POS_Constants.PRICE_ZONE_PRESSURE_WEIGHT = 0.05   -- pressure [-2,2] scaled by this -> +/-10% max
POS_Constants.PRICE_ZONE_PRESSURE_CLAMP  = 0.10   -- absolute cap on zone pressure effect

---------------------------------------------------------------
-- Exchange engine
---------------------------------------------------------------

POS_Constants.EXCHANGE_INDEX_BASE_VALUE    = 100
POS_Constants.EXCHANGE_INDEX_LOOKBACK_DAYS = 30
POS_Constants.EXCHANGE_TREND_LOOKBACK_DAYS = 7

---------------------------------------------------------------
-- Market data world ModData key
---------------------------------------------------------------

POS_Constants.WMD_MARKET_DATA = "POSNET.MarketData"

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
-- Intelligence Summary screen
---------------------------------------------------------------

POS_Constants.SCREEN_INTEL_SUMMARY = "pos.markets.summary"
POS_Constants.SCREEN_MARKET_OVERVIEW  = "pos.markets.overview"
POS_Constants.SCREEN_CONTACTS         = "pos.markets.contacts"
POS_Constants.SCREEN_MARKET_SIGNALS   = "pos.markets.signals"
POS_Constants.SCREEN_ASSIGNMENTS      = "pos.bbs.assignments"

---------------------------------------------------------------
-- Camera Workstation (Tier III -- Compilation)
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
-- Market Intel -- Writing Tools & Paper (deduplicated)
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
-- Ambient Intelligence (passive market data trickle)
---------------------------------------------------------------

POS_Constants.AMBIENT_INTEL_INTERVAL_DEFAULT   = 30    -- game minutes between ambient observations
POS_Constants.AMBIENT_INTEL_MIN_OBS            = 1     -- minimum observations per interval
POS_Constants.AMBIENT_INTEL_MAX_OBS            = 3     -- maximum observations per interval
POS_Constants.AMBIENT_INTEL_PRICE_NOISE        = 0.25  -- ±25% price variance
POS_Constants.AMBIENT_INTEL_MAX_RECORDS        = 50    -- max ambient records in database
POS_Constants.AMBIENT_INTEL_SOURCE_PREFIX      = "ambient_"
POS_Constants.AMBIENT_INTEL_HISTORY_SIZE       = 5     -- anti-repetition category history

---------------------------------------------------------------
-- Item discovery (intel-gated trade catalog)
---------------------------------------------------------------

POS_Constants.AMBIENT_INTEL_MIN_ITEMS  = 2
POS_Constants.AMBIENT_INTEL_MAX_ITEMS  = 5
POS_Constants.AGENT_OBS_MIN_ITEMS      = 3
POS_Constants.AGENT_OBS_MAX_ITEMS      = 8
POS_Constants.RECON_DISCOVER_MIN_ITEMS = 4
POS_Constants.RECON_DISCOVER_MAX_ITEMS = 10
POS_Constants.CAMERA_DISCOVER_MIN_ITEMS = 5
POS_Constants.CAMERA_DISCOVER_MAX_ITEMS = 12
POS_Constants.DISCOVERY_NAMESPACE      = "POSNET_Discoveries"
