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

    -- Use seed for deterministic drift
    local rng = newrandom()
    rng:seed(seed)
    local halfRange = POS_Constants.PRICE_DRIFT_RANGE / 2
    local baseDrift = (rng:random(POS_Constants.PRICE_DRIFT_RANGE) - halfRange)
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
    if not (POS_Sandbox and POS_Sandbox.getReputationAffectsVariance
            and POS_Sandbox.getReputationAffectsVariance()) then
        return 1.0
    end
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
--- @param ctx        table|nil  { player, sourceTier, roomModifier }
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
            sdFactor = math.max(-0.1, math.min(0.1, (summary.sourceCount - 5) * 0.01))
        end
    end

    -- Variance based on source tier and reputation
    local variancePct = POS_Constants.PRICE_BASE_VARIANCE_PCT
    if ctx and ctx.sourceTier == "broadcast" then
        variancePct = POS_Constants.PRICE_BROADCAST_VARIANCE_PCT
    end

    local repMult = 1.0
    if ctx and ctx.player then
        repMult = POS_PriceEngine.getVarianceMultiplier(ctx.player)
    end

    local doubleVariance = variancePct * 2 + 1
    local variance = ((ZombRand(doubleVariance) - variancePct) / 100) * repMult

    -- Room modifier (optional, e.g. proximity to certain rooms)
    local roomMod = (ctx and ctx.roomModifier) or 0

    -- Final calculation
    local price = basePrice * volatility * (1 + drift) * (1 + sdFactor) * (1 + variance + roomMod)
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
