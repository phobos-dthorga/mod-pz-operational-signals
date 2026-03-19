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
-- POS_MarketDatabase.lua
-- Intel record storage and aggregation.
-- Server/SP: reads/writes from world-scoped Global ModData.
-- Client (MP): reads from a local ephemeral cache.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MarketDatabase = {}

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

--- Ephemeral client-side cache (MP clients only).
local clientCache = {}

--- Get the observations array for a category from world state.
--- On server/SP: reads from ModData.getOrCreate("POSNET.World")
--- On client in MP: reads from local cache
local function getWorldCategoryData(categoryId)
    if POS_WorldState and POS_WorldState.isAuthority() then
        -- Server/SP: read from world ModData
        local world = POS_WorldState.getWorld()
        if not world.categories then world.categories = {} end
        if not world.categories[categoryId] then
            world.categories[categoryId] = { observations = {}, rollingCloses = {}, aggregate = {} }
        end
        return world.categories[categoryId]
    else
        -- MP client: read from local cache
        if not clientCache[categoryId] then
            clientCache[categoryId] = { observations = {}, rollingCloses = {}, aggregate = {} }
        end
        return clientCache[categoryId]
    end
end

local function getCurrentDay()
    if POS_WorldState and POS_WorldState.getWorldDay then
        return POS_WorldState.getWorldDay()
    end
    local gt = getGameTime and getGameTime()
    if gt then return gt:getNightsSurvived() end
    return 0
end

local function getMaxAgeDays()
    if POS_Sandbox and POS_Sandbox.getIntelFreshnessDecayDays then
        return POS_Sandbox.getIntelFreshnessDecayDays()
    end
    return POS_Constants.MARKET_EXPIRED_DAYS
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Add a new intel record. Server-only: clients must submit
--- via sendClientCommand(CMD_SUBMIT_OBSERVATION).
--- @param record table Intel record (see schema in market-exchange-design.md)
--- @return boolean success
function POS_MarketDatabase.addRecord(record)
    -- Server-only: clients must submit via sendClientCommand
    if not POS_WorldState or not POS_WorldState.isAuthority() then
        PhobosLib.debug("POS", "[MarketDB] addRecord rejected — not authority")
        return false
    end

    if not record or not record.categoryId then return false end

    -- Dedup check
    local catData = getWorldCategoryData(record.categoryId)
    for _, existing in ipairs(catData.observations) do
        if existing.id and existing.id == record.id then return false end
    end

    -- Validate optional fields
    if record.items ~= nil and type(record.items) ~= "table" then
        record.items = nil
    end
    if record.sourceTier and record.sourceTier ~= POS_Constants.SOURCE_TIER_FIELD and record.sourceTier ~= POS_Constants.SOURCE_TIER_BROADCAST then
        record.sourceTier = nil
    end
    if record.quality then
        record.quality = math.max(0, math.min(100, tonumber(record.quality) or 0))
    end

    -- Add observation with rolling window cap
    local maxObs = POS_Sandbox and POS_Sandbox.getMaxObservationsPerCategory
        and POS_Sandbox.getMaxObservationsPerCategory()
        or POS_Constants.MAX_OBSERVATIONS_PER_CATEGORY

    local obs = {
        id = record.id,
        day = record.recordedDay or getCurrentDay(),
        price = record.price,
        stock = record.stock,
        source = record.source,
        location = record.location,
        confidence = record.confidence,
        sourceTier = record.sourceTier or POS_Constants.SOURCE_TIER_FIELD,
        quality = record.quality,
    }

    -- Store items if present
    if record.items then obs.items = record.items end

    PhobosLib.pushRolling(catData.observations, obs, maxObs)

    -- Also log to event log
    if POS_EventLog and POS_EventLog.append then
        POS_EventLog.append(POS_Constants.EVENT_SYSTEM_ECONOMY, "observation",
            record.categoryId, "", "", 0,
            POS_BasisPoints and POS_BasisPoints.toBps(record.price or 0) or 0,
            record.sourceTier or POS_Constants.SOURCE_TIER_FIELD)
    end

    PhobosLib.debug("POS", "[MarketDB] Added intel record: "
        .. tostring(record.id) .. " (cat: " .. tostring(record.categoryId) .. ")")

    return true
end

--- Get all records for a category, filtered by freshness.
--- @param categoryId string
--- @param maxAgeDays number|nil Override max age (default: sandbox setting)
--- @return table[] Array of observation records
function POS_MarketDatabase.getRecords(categoryId, maxAgeDays)
    local catData = getWorldCategoryData(categoryId)
    if not catData or not catData.observations then return {} end

    local maxAge = maxAgeDays or getMaxAgeDays()
    local day = getCurrentDay()
    local result = {}

    for _, obs in ipairs(catData.observations) do
        if day - (obs.day or 0) <= maxAge then
            result[#result + 1] = obs
        end
    end

    return result
end

--- Get aggregated summary for a category.
--- Uses pre-computed aggregate if available (from economy tick),
--- otherwise computes on the fly.
--- @param categoryId string
--- @return table { low, high, avg, sourceCount, freshestDay, confidence, trend }
function POS_MarketDatabase.getSummary(categoryId)
    local catData = getWorldCategoryData(categoryId)

    -- If aggregate is pre-computed (by economy tick), return it
    if catData.aggregate and catData.aggregate.avgPrice and catData.aggregate.avgPrice > 0 then
        return {
            low = catData.aggregate.lowPrice,
            high = catData.aggregate.highPrice,
            avg = catData.aggregate.avgPrice,
            sourceCount = catData.aggregate.sourceCount or 0,
            freshestDay = catData.aggregate.freshestDay or 0,
            confidence = catData.aggregate.confidence or "low",
            trend = "unknown",
        }
    end

    -- Otherwise compute on the fly (SP without economy tick, or first access)
    local records = POS_MarketDatabase.getRecords(categoryId)
    local summary = {
        low = nil,
        high = nil,
        avg = nil,
        sourceCount = 0,
        freshestDay = 0,
        confidence = "low",
        trend = "unknown",
    }

    if #records == 0 then return summary end

    local weightedTotal = 0
    local totalWeight = 0
    local sources = {}

    for _, r in ipairs(records) do
        local price = r.price
        if price then
            if not summary.low or price < summary.low then
                summary.low = price
            end
            if not summary.high or price > summary.high then
                summary.high = price
            end
            -- Weight by sourceTier
            local w = POS_Constants.SOURCE_TIER_WEIGHT_DEFAULT
            if r.sourceTier == POS_Constants.SOURCE_TIER_FIELD then
                w = POS_Constants.SOURCE_TIER_WEIGHT_FIELD
            elseif r.sourceTier == POS_Constants.SOURCE_TIER_BROADCAST then
                w = POS_Constants.SOURCE_TIER_WEIGHT_BROADCAST
            end
            weightedTotal = weightedTotal + (price * w)
            totalWeight = totalWeight + w
        end
        if r.source then
            sources[r.source] = true
        end
        local rDay = r.day or r.recordedDay or 0
        if rDay > summary.freshestDay then
            summary.freshestDay = rDay
        end
    end

    if totalWeight > 0 then
        summary.avg = math.floor((weightedTotal / totalWeight) * 100 + 0.5) / 100
    end

    -- Count distinct sources
    for _ in pairs(sources) do
        summary.sourceCount = summary.sourceCount + 1
    end

    -- Calculate confidence
    local currentDay = getCurrentDay()
    local daysSince = currentDay - summary.freshestDay
    if summary.sourceCount >= 5 and daysSince <= POS_Constants.MARKET_FRESH_DAYS then
        summary.confidence = "high"
    elseif summary.sourceCount >= 2 and daysSince <= POS_Constants.MARKET_STALE_DAYS then
        summary.confidence = "medium"
    else
        summary.confidence = "low"
    end

    -- Calculate trend from price history
    local history = POS_MarketDatabase.getPriceHistory(categoryId, 7)
    if #history >= 2 then
        local recent = history[#history].avg
        local previous = history[#history - 1].avg
        if previous and previous > 0 then
            if recent > previous * (1 + POS_Constants.TREND_RISING_PCT) then
                summary.trend = "rising"
            elseif recent < previous * (1 - POS_Constants.TREND_FALLING_PCT) then
                summary.trend = "falling"
            else
                summary.trend = "stable"
            end
        end
    end

    return summary
end

--- Get price history for a category (daily averages).
--- @param categoryId string
--- @param days number Number of days to look back
--- @return table[] Array of { day, avg, count }
function POS_MarketDatabase.getPriceHistory(categoryId, days)
    local catData = getWorldCategoryData(categoryId)
    if not catData or not catData.observations then return {} end

    local currentDay = getCurrentDay()
    local startDay = currentDay - (days or 7)

    -- Group prices by day
    local byDay = {}
    for _, obs in ipairs(catData.observations) do
        local obsDay = obs.day or obs.recordedDay
        if obs.price and obsDay and obsDay >= startDay then
            if not byDay[obsDay] then
                byDay[obsDay] = { total = 0, count = 0 }
            end
            byDay[obsDay].total = byDay[obsDay].total + obs.price
            byDay[obsDay].count = byDay[obsDay].count + 1
        end
    end

    -- Build sorted history
    local history = {}
    for day, data in pairs(byDay) do
        history[#history + 1] = {
            day = day,
            avg = math.floor((data.total / data.count) * 100 + 0.5) / 100,
            count = data.count,
        }
    end
    table.sort(history, function(a, b) return a.day < b.day end)

    return history
end

--- Get item-level data aggregated from records that have an items field.
--- @param categoryId string
--- @param maxAgeDays number|nil Override max age (default: sandbox setting)
--- @return table[] Array of { fullType, avgPrice, priceCount, lastSeen }
function POS_MarketDatabase.getItemRecords(categoryId, maxAgeDays)
    local records = POS_MarketDatabase.getRecords(categoryId, maxAgeDays)
    local itemMap = {}

    for _, r in ipairs(records) do
        if r.items and type(r.items) == "table" then
            for _, item in ipairs(r.items) do
                if item.fullType and item.price then
                    local entry = itemMap[item.fullType]
                    if not entry then
                        entry = { fullType = item.fullType, totalPrice = 0, priceCount = 0, lastSeen = 0 }
                        itemMap[item.fullType] = entry
                    end
                    entry.totalPrice = entry.totalPrice + item.price
                    entry.priceCount = entry.priceCount + 1
                    local rDay = r.day or r.recordedDay or 0
                    if rDay > entry.lastSeen then
                        entry.lastSeen = rDay
                    end
                end
            end
        end
    end

    local result = {}
    for _, entry in pairs(itemMap) do
        result[#result + 1] = {
            fullType = entry.fullType,
            avgPrice = math.floor((entry.totalPrice / entry.priceCount) * 100 + 0.5) / 100,
            priceCount = entry.priceCount,
            lastSeen = entry.lastSeen,
        }
    end
    table.sort(result, function(a, b) return a.fullType < b.fullType end)

    return result
end

--- Get all known traders (across all categories).
--- @return table[] Array of { source, location, categories[] }
function POS_MarketDatabase.getKnownTraders()
    local currentDay = getCurrentDay()
    local maxAge = getMaxAgeDays()
    local traderMap = {}

    -- Iterate all known categories from world state
    local categories = {}
    if POS_WorldState and POS_WorldState.isAuthority() then
        local world = POS_WorldState.getWorld()
        if world and world.categories then categories = world.categories end
    else
        categories = clientCache
    end

    for catId, catData in pairs(categories) do
        if catData.observations then
            for _, obs in ipairs(catData.observations) do
                if obs.source and (currentDay - (obs.day or 0)) <= maxAge then
                    local key = obs.source
                    if not traderMap[key] then
                        traderMap[key] = {
                            source = obs.source,
                            location = obs.location or "",
                            categories = {},
                        }
                    end
                    traderMap[key].categories[catId] = true
                end
            end
        end
    end

    local traders = {}
    for _, t in pairs(traderMap) do
        local cats = {}
        for catId in pairs(t.categories) do
            cats[#cats + 1] = catId
        end
        table.sort(cats)
        traders[#traders + 1] = {
            source = t.source,
            location = t.location,
            categories = cats,
        }
    end
    table.sort(traders, function(a, b) return a.source < b.source end)

    return traders
end

--- Purge expired observations older than maxDays.
--- Server-only. Uses PhobosLib.trimByAge.
--- @param maxDays number|nil Override (default: sandbox setting)
--- @return number count Number of observations purged
function POS_MarketDatabase.purgeExpired(maxDays)
    if not POS_WorldState or not POS_WorldState.isAuthority() then return 0 end

    local world = POS_WorldState.getWorld()
    if not world.categories then return 0 end

    local day = getCurrentDay()
    local maxAge = maxDays or getMaxAgeDays()
    local total = 0

    for catId, catData in pairs(world.categories) do
        if catData.observations then
            total = total + PhobosLib.trimByAge(catData.observations, "day", maxAge, day)
        end
    end

    if total > 0 then
        PhobosLib.debug("POS", "[MarketDB] Purged " .. total .. " expired observations")
    end

    return total
end

---------------------------------------------------------------
-- Client cache management (MP)
---------------------------------------------------------------

--- Update the local client cache for a category (called when
--- receiving a snapshot from the server in MP).
--- @param categoryId string
--- @param data table Category data { observations, rollingCloses, aggregate }
function POS_MarketDatabase.updateClientCache(categoryId, data)
    clientCache[categoryId] = data
end

--- Clear the entire client cache (e.g. on disconnect).
function POS_MarketDatabase.clearClientCache()
    clientCache = {}
end
