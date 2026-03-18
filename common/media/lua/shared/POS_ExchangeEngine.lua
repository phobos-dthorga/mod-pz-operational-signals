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
-- POS_ExchangeEngine.lua
-- Commodity index calculation and market sentiment.
-- Reads from POS_MarketDatabase.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_MarketDatabase"
require "POS_MarketRegistry"

POS_ExchangeEngine = {}

local INDEX_BASE_VALUE = 100

---------------------------------------------------------------
-- Index calculation
---------------------------------------------------------------

--- Calculate a commodity index value for a category.
--- Base 100 — current value relative to earliest known average price.
--- @param categoryId string
--- @return number index Current index value (100 = baseline)
function POS_ExchangeEngine.getIndex(categoryId)
    local history = POS_MarketDatabase.getPriceHistory(categoryId, 30)
    if #history == 0 then return INDEX_BASE_VALUE end

    local baseline = history[1].avg
    if not baseline or baseline <= 0 then return INDEX_BASE_VALUE end

    local current = history[#history].avg
    if not current then return INDEX_BASE_VALUE end

    return math.floor((current / baseline) * INDEX_BASE_VALUE * 10 + 0.5) / 10
end

--- Get index history for a category.
--- @param categoryId string
--- @param days number Lookback period
--- @return table[] Array of { day, index }
function POS_ExchangeEngine.getIndexHistory(categoryId, days)
    local history = POS_MarketDatabase.getPriceHistory(categoryId, days or 30)
    if #history == 0 then return {} end

    local baseline = history[1].avg
    if not baseline or baseline <= 0 then return {} end

    local result = {}
    for _, entry in ipairs(history) do
        table.insert(result, {
            day = entry.day,
            index = math.floor((entry.avg / baseline) * INDEX_BASE_VALUE * 10 + 0.5) / 10,
        })
    end
    return result
end

---------------------------------------------------------------
-- Trend calculation
---------------------------------------------------------------

--- Get trend for a commodity category.
--- @param categoryId string
--- @return table { direction = "rising"|"falling"|"stable"|"unknown", changePct = number }
function POS_ExchangeEngine.getTrend(categoryId)
    local history = POS_MarketDatabase.getPriceHistory(categoryId, 7)

    if #history < 2 then
        return { direction = "unknown", changePct = 0 }
    end

    local recent = history[#history].avg
    local previous = history[#history - 1].avg

    if not recent or not previous or previous <= 0 then
        return { direction = "unknown", changePct = 0 }
    end

    local changePct = math.floor(((recent - previous) / previous) * 1000 + 0.5) / 10
    local direction = "stable"

    if recent > previous * (1 + POS_Constants.TREND_RISING_PCT) then
        direction = "rising"
    elseif recent < previous * (1 - POS_Constants.TREND_FALLING_PCT) then
        direction = "falling"
    end

    return { direction = direction, changePct = changePct }
end

---------------------------------------------------------------
-- Market sentiment
---------------------------------------------------------------

--- Get overall market sentiment across all tracked categories.
--- @return string "bullish" | "bearish" | "neutral"
function POS_ExchangeEngine.getSentiment()
    local categories = POS_MarketRegistry.getVisibleCategories({})
    if #categories == 0 then return "neutral" end

    local rising = 0
    local falling = 0

    for _, cat in ipairs(categories) do
        local trend = POS_ExchangeEngine.getTrend(cat.id)
        if trend.direction == "rising" then
            rising = rising + 1
        elseif trend.direction == "falling" then
            falling = falling + 1
        end
    end

    if rising > falling and rising >= 2 then return "bullish" end
    if falling > rising and falling >= 2 then return "bearish" end
    return "neutral"
end
