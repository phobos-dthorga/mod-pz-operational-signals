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
-- POS_PriceEngine.lua
-- Price generation engine with day-to-day drift, speculation,
-- supply/demand factors, and reputation-scaled variance.
---------------------------------------------------------------

require "POS_Constants"

POS_PriceEngine = {}

---------------------------------------------------------------
-- Day-to-Day Drift (Speculation)
---------------------------------------------------------------

--- Calculate a deterministic day-based price drift for a category.
--- The drift is seeded from the category ID and current game day so
--- that all players in a multiplayer session see the same drift.
--- @param categoryId string
--- @return number  Drift as a decimal fraction (e.g. 0.02 = +2%)
function POS_PriceEngine.getDayDrift(categoryId)
    local day = getGameTime():getNightsSurvived()

    -- Simple hash of categoryId for seed
    local hash = 0
    for i = 1, #categoryId do
        hash = hash + string.byte(categoryId, i) * (i * POS_Constants.PRICE_DRIFT_SEED_MULTIPLIER)
    end
    local seed = hash + day * POS_Constants.PRICE_DRIFT_SEED_MULTIPLIER

    -- Deterministic pseudo-random from seed (no Java RNG dependency)
    -- Simple hash → float in [-1, 1] range, then scale to drift bounds
    local h = ((seed * 2654435761) % 4294967296) / 4294967296  -- Knuth multiplicative hash → [0, 1)
    local halfRange = POS_Constants.PRICE_DRIFT_RANGE / 2
    local baseDrift = ((h * POS_Constants.PRICE_DRIFT_RANGE) - halfRange)
        / POS_Constants.PRICE_DRIFT_DIVISOR

    -- Clamp to sandbox-configurable max daily drift
    local maxDrift = POS_Sandbox and POS_Sandbox.getDailyPriceDriftPct
        and POS_Sandbox.getDailyPriceDriftPct() or 2
    local maxFraction = maxDrift / 100
    baseDrift = math.max(-maxFraction, math.min(maxFraction, baseDrift))

    -- Intel influence: low-stock records push drift upward
    if POS_MarketDatabase then
        local records = POS_MarketDatabase.getRecords(categoryId)
        if records and #records > 0 then
            local lowStockCount = 0
            for _, r in ipairs(records) do
                if r.stock == "none" or r.stock == "low" then
                    lowStockCount = lowStockCount + 1
                end
            end
            local intelBias = (lowStockCount / #records)
                * POS_Constants.PRICE_INTEL_BIAS_MAX
            baseDrift = baseDrift + intelBias
        end
    end

    return baseDrift
end

---------------------------------------------------------------
-- Reputation-Scaled Variance
---------------------------------------------------------------

--- Return the variance multiplier for the given player based on
--- their reputation tier.  Higher reputation means tighter prices.
--- @param player IsoPlayer|nil
--- @return number
function POS_PriceEngine.getVarianceMultiplier(player)
    local tier = POS_Reputation and POS_Reputation.getTier(player) or 3
    return POS_Constants.REP_VARIANCE_MULTIPLIERS[tier]
        or POS_Constants.REP_VARIANCE_MULTIPLIERS[3]
end

---------------------------------------------------------------
-- Main Price Generation
---------------------------------------------------------------

--- Generate a single price for a given item.
---
--- Formula:
---   finalPrice = basePrice
---       x categoryVolatility
---       x (1 + dayDrift)
---       x (1 + supplyDemandFactor)
---       x (1 + randomVariance x repVarianceMultiplier)
---
--- @param fullType   string   Full item type (e.g. "Base.Axe")
--- @param categoryId string   Commodity category (e.g. "tools")
--- @param ctx        table|nil  { player, sourceTier, roomModifier, zoneId }
--- @return number  Final price rounded to 2 decimal places
function POS_PriceEngine.generatePrice(fullType, categoryId, ctx)
    local basePrice = POS_ItemPool.getBasePrice(fullType)
    if not basePrice then return POS_Constants.PRICE_MIN_OUTPUT end

    -- Category volatility from market registry
    local volatility = 1.0
    if POS_MarketRegistry then
        local cat = POS_MarketRegistry.getCategory(categoryId)
        if cat and cat.volatility then
            volatility = cat.volatility
        end
    end

    -- Day-to-day drift
    local drift = POS_PriceEngine.getDayDrift(categoryId)

    -- Supply/demand factor from intel density
    local sdFactor = 0
    if POS_MarketDatabase then
        local summary = POS_MarketDatabase.getSummary(categoryId)
        if summary and summary.sourceCount > 0 then
            -- More sources = more stable (closer to true price)
            sdFactor = math.max(-POS_Constants.PRICE_SD_FACTOR_CLAMP,
                math.min(POS_Constants.PRICE_SD_FACTOR_CLAMP,
                    (summary.sourceCount - POS_Constants.PRICE_SD_FACTOR_BASELINE)
                    * POS_Constants.PRICE_SD_FACTOR_PER_SOURCE))
        end
    end

    -- Zone pressure bias from Living Market (additive to S/D factor)
    local zoneId = ctx and ctx.zoneId
    if zoneId and POS_MarketSimulation
            and POS_MarketSimulation.getZonePressure then
        local ok, pressure = PhobosLib.safecall(
            POS_MarketSimulation.getZonePressure, zoneId, categoryId)
        if ok and pressure then
            local pressureFactor = pressure
                * POS_Constants.PRICE_ZONE_PRESSURE_WEIGHT
            pressureFactor = PhobosLib.clamp(pressureFactor,
                -POS_Constants.PRICE_ZONE_PRESSURE_CLAMP,
                POS_Constants.PRICE_ZONE_PRESSURE_CLAMP)
            sdFactor = sdFactor + pressureFactor
        end
    end

    -- Variance based on source tier and reputation
    local variancePct = POS_Constants.PRICE_BASE_VARIANCE_PCT
    if ctx and ctx.sourceTier == POS_Constants.SOURCE_TIER_BROADCAST then
        variancePct = POS_Constants.PRICE_BROADCAST_VARIANCE_PCT
    end

    local repMult = 1.0
    if ctx and ctx.player then
        repMult = POS_PriceEngine.getVarianceMultiplier(ctx.player)
    end

    local doubleVariance = variancePct * 2 + 1
    local variance = ((ZombRand(doubleVariance) - variancePct) / 100) * repMult

    -- Luxury zone scaling (Living Market integration)
    -- Items flagged isLuxury in the item value registry have their
    -- price scaled by the zone's luxuryDemand.  Urban zones (Louisville
    -- = 2.5x) inflate luxury prices; rural zones (Muldraugh = 0.5x)
    -- deflate them.
    local luxuryMult = 1.0
    local record = POS_ItemPool.getRecord and POS_ItemPool.getRecord(fullType)
    if record and record.isLuxury then
        local zoneId = ctx and ctx.zoneId
        if zoneId and POS_MarketSimulation
                and POS_MarketSimulation.getZoneLuxuryDemand then
            local ok, demand = PhobosLib.safecall(
                POS_MarketSimulation.getZoneLuxuryDemand, zoneId)
            if ok and demand then
                luxuryMult = demand
            end
        end
    end

    -- Room modifier (optional, e.g. proximity to certain rooms)
    local roomMod = (ctx and ctx.roomModifier) or 0

    -- Final calculation
    local price = basePrice * volatility * luxuryMult * (1 + drift) * (1 + sdFactor) * (1 + variance + roomMod)
    price = math.max(POS_Constants.PRICE_MIN_OUTPUT, price)

    -- Round to 2 decimal places
    return math.floor(price * 100 + 0.5) / 100
end

--- Generate prices for a list of items in bulk.
--- @param items      table[]  Array of records with .fullType field
--- @param categoryId string   Commodity category
--- @param ctx        table|nil  Context passed to generatePrice
--- @return table[]  Array of { fullType, price }
function POS_PriceEngine.generatePrices(items, categoryId, ctx)
    local result = {}
    for i = 1, #items do
        result[i] = {
            fullType = items[i].fullType,
            price = POS_PriceEngine.generatePrice(items[i].fullType, categoryId, ctx),
        }
    end
    return result
end
