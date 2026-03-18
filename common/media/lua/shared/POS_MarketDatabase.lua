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
-- Intel record storage and aggregation. Uses player modData.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MarketDatabase = {}

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

local function getStore()
    local player = getSpecificPlayer(0)
    if not player then return {} end
    local md = player:getModData()
    if not md then return {} end
    if not md[POS_Constants.MD_MARKET_INTEL] then
        md[POS_Constants.MD_MARKET_INTEL] = {}
    end
    return md[POS_Constants.MD_MARKET_INTEL]
end

local function getCurrentDay()
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

--- Add a new intel record.
--- @param record table Intel record (see schema in market-exchange-design.md)
---   Optional fields: items (table of {fullType, price}), sourceTier ("field"|"broadcast"), quality (0-100)
--- @return boolean success
function POS_MarketDatabase.addRecord(record)
    if not record or not record.id then return false end
    local store = getStore()
    -- Duplicate check
    for i = 1, #store do
        if store[i].id == record.id then return false end
    end
    -- Preserve optional extended fields
    if record.items ~= nil and type(record.items) ~= "table" then
        record.items = nil
    end
    if record.sourceTier and record.sourceTier ~= "field" and record.sourceTier ~= "broadcast" then
        record.sourceTier = nil
    end
    if record.quality then
        record.quality = math.max(0, math.min(100, tonumber(record.quality) or 0))
    end
    table.insert(store, record)
    PhobosLib.debug("POS", "[POS:MarketDB]",
        "Added intel record: " .. record.id .. " (cat: " .. (record.categoryId or "?") .. ")")
    return true
end

--- Get all records for a category, filtered by freshness.
--- @param categoryId string
--- @param maxAgeDays number|nil Override max age (default: sandbox setting)
--- @return table[] Array of records
function POS_MarketDatabase.getRecords(categoryId, maxAgeDays)
    local store = getStore()
    local currentDay = getCurrentDay()
    local maxAge = maxAgeDays or getMaxAgeDays()
    local results = {}
    for i = 1, #store do
        local r = store[i]
        if r.categoryId == categoryId then
            local age = currentDay - (r.recordedDay or 0)
            if age <= maxAge then
                table.insert(results, r)
            end
        end
    end
    return results
end

--- Get aggregated summary for a category.
--- @param categoryId string
--- @return table { low, high, avg, sourceCount, freshestDay, confidence, trend }
function POS_MarketDatabase.getSummary(categoryId)
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
        if r.price then
            if not summary.low or r.price < summary.low then
                summary.low = r.price
            end
            if not summary.high or r.price > summary.high then
                summary.high = r.price
            end
            -- Weight by sourceTier: field=1.0, broadcast=0.7, default=0.85
            local w = 0.85
            if r.sourceTier == "field" then
                w = 1.0
            elseif r.sourceTier == "broadcast" then
                w = 0.7
            end
            weightedTotal = weightedTotal + (r.price * w)
            totalWeight = totalWeight + w
        end
        if r.source then
            sources[r.source] = true
        end
        if r.recordedDay and r.recordedDay > summary.freshestDay then
            summary.freshestDay = r.recordedDay
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
    local store = getStore()
    local currentDay = getCurrentDay()
    local startDay = currentDay - (days or 7)

    -- Group prices by day
    local byDay = {}
    for _, r in ipairs(store) do
        if r.categoryId == categoryId and r.price and r.recordedDay then
            if r.recordedDay >= startDay then
                local day = r.recordedDay
                if not byDay[day] then
                    byDay[day] = { total = 0, count = 0 }
                end
                byDay[day].total = byDay[day].total + r.price
                byDay[day].count = byDay[day].count + 1
            end
        end
    end

    -- Build sorted history
    local history = {}
    for day, data in pairs(byDay) do
        table.insert(history, {
            day = day,
            avg = math.floor((data.total / data.count) * 100 + 0.5) / 100,
            count = data.count,
        })
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
                    if (r.recordedDay or 0) > entry.lastSeen then
                        entry.lastSeen = r.recordedDay or 0
                    end
                end
            end
        end
    end

    local result = {}
    for _, entry in pairs(itemMap) do
        table.insert(result, {
            fullType = entry.fullType,
            avgPrice = math.floor((entry.totalPrice / entry.priceCount) * 100 + 0.5) / 100,
            priceCount = entry.priceCount,
            lastSeen = entry.lastSeen,
        })
    end
    table.sort(result, function(a, b) return a.fullType < b.fullType end)

    return result
end

--- Get all known traders (across all categories).
--- @return table[] Array of { source, location, categories[] }
function POS_MarketDatabase.getKnownTraders()
    local store = getStore()
    local currentDay = getCurrentDay()
    local maxAge = getMaxAgeDays()
    local traderMap = {}

    for _, r in ipairs(store) do
        if r.source and (currentDay - (r.recordedDay or 0)) <= maxAge then
            local key = r.source
            if not traderMap[key] then
                traderMap[key] = {
                    source = r.source,
                    location = r.location or "",
                    categories = {},
                }
            end
            traderMap[key].categories[r.categoryId or "unknown"] = true
        end
    end

    local traders = {}
    for _, t in pairs(traderMap) do
        local cats = {}
        for catId in pairs(t.categories) do
            table.insert(cats, catId)
        end
        table.sort(cats)
        table.insert(traders, {
            source = t.source,
            location = t.location,
            categories = cats,
        })
    end
    table.sort(traders, function(a, b) return a.source < b.source end)

    return traders
end

--- Purge expired records older than maxDays.
--- @param maxDays number|nil Override (default: sandbox setting)
--- @return number count Number of records purged
function POS_MarketDatabase.purgeExpired(maxDays)
    local store = getStore()
    local currentDay = getCurrentDay()
    local maxAge = maxDays or getMaxAgeDays()
    local purged = 0

    local i = 1
    while i <= #store do
        local age = currentDay - (store[i].recordedDay or 0)
        if age > maxAge then
            table.remove(store, i)
            purged = purged + 1
        else
            i = i + 1
        end
    end

    if purged > 0 then
        PhobosLib.debug("POS", "[POS:MarketDB]",
            "Purged " .. purged .. " expired intel records")
    end
    return purged
end
