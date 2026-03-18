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
-- POS_MarketService.lua
-- Read-only query facade for UI screens.
-- Bridges data layer to presentation.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_MarketDatabase"
require "POS_MarketRegistry"
require "POS_ExchangeEngine"

POS_MarketService = {}

---------------------------------------------------------------
-- Freshness helpers
---------------------------------------------------------------

local function getCurrentDay()
    local gt = getGameTime and getGameTime()
    if gt then return gt:getNightsSurvived() end
    return 0
end

--- Get freshness translation key for a recorded day.
--- @param freshestDay number Game day of most recent record
--- @return string Translation key
function POS_MarketService.getFreshnessKey(freshestDay)
    local age = getCurrentDay() - (freshestDay or 0)
    if age <= POS_Constants.MARKET_FRESH_DAYS then
        return "UI_POS_Market_Fresh"
    elseif age <= POS_Constants.MARKET_STALE_DAYS then
        return "UI_POS_Market_Stale"
    else
        return "UI_POS_Market_Expired"
    end
end

--- Get confidence translation key.
--- @param confidence string "low" | "medium" | "high"
--- @return string Translation key
function POS_MarketService.getConfidenceKey(confidence)
    if confidence == "high" then return "UI_POS_Market_Confidence_High" end
    if confidence == "medium" then return "UI_POS_Market_Confidence_Medium" end
    return "UI_POS_Market_Confidence_Low"
end

--- Get trend translation key.
--- @param direction string "rising" | "falling" | "stable" | "unknown"
--- @return string Translation key
function POS_MarketService.getTrendKey(direction)
    if direction == "rising" then return "UI_POS_Market_Trend_Rising" end
    if direction == "falling" then return "UI_POS_Market_Trend_Falling" end
    if direction == "stable" then return "UI_POS_Market_Trend_Stable" end
    return "UI_POS_Market_Trend_Unknown"
end

--- Get sentiment translation key.
--- @param sentiment string "bullish" | "bearish" | "neutral"
--- @return string Translation key
function POS_MarketService.getSentimentKey(sentiment)
    if sentiment == "bullish" then return "UI_POS_Market_Sentiment_Bullish" end
    if sentiment == "bearish" then return "UI_POS_Market_Sentiment_Bearish" end
    return "UI_POS_Market_Sentiment_Neutral"
end

---------------------------------------------------------------
-- Commodity queries
---------------------------------------------------------------

--- Get summary for a commodity category, ready for screen rendering.
--- @param categoryId string
--- @return table Summary with translated key references
function POS_MarketService.getCommoditySummary(categoryId)
    if not POS_MarketDatabase then return nil end
    local summary = POS_MarketDatabase.getSummary(categoryId)
    if not summary then return nil end
    local trend = POS_ExchangeEngine.getTrend(categoryId)
    local cat = POS_MarketRegistry.getCategory(categoryId)

    return {
        categoryId = categoryId,
        labelKey = cat and cat.labelKey or ("UI_POS_Market_Cat_" .. categoryId),
        lowPrice = summary.low,
        avgPrice = summary.avg,
        highPrice = summary.high,
        sourceCount = summary.sourceCount,
        freshestDay = summary.freshestDay,
        freshnessKey = POS_MarketService.getFreshnessKey(summary.freshestDay),
        confidenceKey = POS_MarketService.getConfidenceKey(summary.confidence),
        trendKey = POS_MarketService.getTrendKey(trend.direction),
        trendPct = trend.changePct,
    }
end

--- Get known traders for a category (or all if nil).
--- @param categoryId string|nil
--- @return table[] Array of trader info
function POS_MarketService.getTraders(categoryId)
    local allTraders = POS_MarketDatabase.getKnownTraders()
    if not categoryId then return allTraders end

    local filtered = {}
    for _, t in ipairs(allTraders) do
        for _, catId in ipairs(t.categories) do
            if catId == categoryId then
                table.insert(filtered, t)
                break
            end
        end
    end
    return filtered
end

--- Get exchange overview (all category indices + sentiment).
--- @return table { indices = { {categoryId, labelKey, index, trendKey, changePct} }, sentimentKey }
function POS_MarketService.getExchangeOverview()
    if not POS_MarketRegistry then return { indices = {}, sentimentKey = "UI_POS_Market_Sentiment_Neutral" } end
    local categories = POS_MarketRegistry.getVisibleCategories({})
    local indices = {}

    for _, cat in ipairs(categories) do
        local index = POS_ExchangeEngine.getIndex(cat.id)
        local trend = POS_ExchangeEngine.getTrend(cat.id)
        table.insert(indices, {
            categoryId = cat.id,
            labelKey = cat.labelKey,
            index = index,
            trendKey = POS_MarketService.getTrendKey(trend.direction),
            changePct = trend.changePct,
        })
    end

    local sentiment = POS_ExchangeEngine.getSentiment()

    return {
        indices = indices,
        sentimentKey = POS_MarketService.getSentimentKey(sentiment),
    }
end

--- Get item-level commodity data for a category.
--- @param categoryId string
--- @return table[] Array of { fullType, avgPrice, priceCount, lastSeen }
function POS_MarketService.getCommodityItems(categoryId)
    if not POS_MarketDatabase then return {} end
    local records = POS_MarketDatabase.getItemRecords(categoryId)
    return records or {}
end
