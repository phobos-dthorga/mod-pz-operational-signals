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
-- POS_Screen_IntelSummary.lua
-- Read-only aggregation screen showing market coverage,
-- confidence overview, category trends, field note count,
-- recorder status, and watchlist alerts.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketRegistry"
require "POS_MarketService"
require "POS_MarketIngestion"
require "POS_DataRecorderService"
require "POS_WatchlistService"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_INTEL_SUMMARY
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_IntelSummary_Title"
screen.sortOrder = 5

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Gather summaries for all visible market categories.
--- @return table[] Array of commodity summaries (from POS_MarketService)
local function gatherCategorySummaries()
    local categories = POS_MarketRegistry.getVisibleCategories({})
    local summaries = {}
    for _, cat in ipairs(categories) do
        local s = POS_MarketService.getCommoditySummary(cat.id)
        if s then
            table.insert(summaries, s)
        end
    end
    return summaries
end

--- Count summaries by freshness key.
--- @param summaries table[]
--- @return number fresh, number stale, number expired
local function countByFreshness(summaries)
    local fresh, stale, expired = 0, 0, 0
    for _, s in ipairs(summaries) do
        if s.freshnessKey == "UI_POS_Market_Fresh" then
            fresh = fresh + 1
        elseif s.freshnessKey == "UI_POS_Market_Stale" then
            stale = stale + 1
        elseif s.freshnessKey == "UI_POS_Market_Expired" then
            expired = expired + 1
        end
    end
    return fresh, stale, expired
end

--- Count summaries by confidence key.
--- @param summaries table[]
--- @return number high, number medium, number low
local function countByConfidence(summaries)
    local high, med, low = 0, 0, 0
    for _, s in ipairs(summaries) do
        if s.confidenceKey == "UI_POS_Market_Confidence_High" then
            high = high + 1
        elseif s.confidenceKey == "UI_POS_Market_Confidence_Medium" then
            med = med + 1
        elseif s.confidenceKey == "UI_POS_Market_Confidence_Low" then
            low = low + 1
        end
    end
    return high, med, low
end

---------------------------------------------------------------
-- Screen
---------------------------------------------------------------

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_IntelSummary_Title")

    local player = getSpecificPlayer(0)
    local summaries = gatherCategorySummaries()
    local totalCategories = #(POS_MarketRegistry.getVisibleCategories({}) or {})

    -- If no data at all, show empty state
    if #summaries == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_IntelSummary_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH * 2
        W.drawFooter(ctx)
        return
    end

    -- === MARKET COVERAGE ===
    W.createLabel(ctx.panel, 0, ctx.y,
        "=== " .. W.safeGetText("UI_POS_IntelSummary_Coverage") .. " ===", C.textBright)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_IntelSummary_CategoriesTracked") .. ":  "
        .. tostring(#summaries) .. "/" .. tostring(totalCategories), C.text)
    ctx.y = ctx.y + ctx.lineH

    local fresh, stale, expired = countByFreshness(summaries)
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_IntelSummary_FreshCount",
            tostring(POS_Constants.MARKET_FRESH_DAYS)) .. ":    " .. tostring(fresh),
        fresh > 0 and C.success or C.dim)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_IntelSummary_StaleCount",
            tostring(POS_Constants.MARKET_FRESH_DAYS),
            tostring(POS_Constants.MARKET_STALE_DAYS)) .. ":    " .. tostring(stale),
        stale > 0 and C.warn or C.dim)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_IntelSummary_ExpiredCount",
            tostring(POS_Constants.MARKET_STALE_DAYS)) .. ":    " .. tostring(expired),
        expired > 0 and C.error or C.dim)
    ctx.y = ctx.y + ctx.lineH + 4

    -- === CONFIDENCE OVERVIEW ===
    W.createLabel(ctx.panel, 0, ctx.y,
        "=== " .. W.safeGetText("UI_POS_IntelSummary_Confidence") .. " ===", C.textBright)
    ctx.y = ctx.y + ctx.lineH

    local high, med, low = countByConfidence(summaries)
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_IntelSummary_HighConfidence") .. ":     " .. tostring(high),
        high > 0 and C.success or C.dim)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_IntelSummary_MedConfidence") .. ":   " .. tostring(med),
        med > 0 and C.text or C.dim)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_IntelSummary_LowConfidence") .. ":      " .. tostring(low),
        low > 0 and C.warn or C.dim)
    ctx.y = ctx.y + ctx.lineH + 4

    -- === CATEGORY TRENDS ===
    W.createLabel(ctx.panel, 0, ctx.y,
        "=== " .. W.safeGetText("UI_POS_IntelSummary_Trends") .. " ===", C.textBright)
    ctx.y = ctx.y + ctx.lineH

    for _, s in ipairs(summaries) do
        local catLabel = W.safeGetText(s.labelKey)
        local trendLabel
        local trendColour = C.text
        if s.trendKey == "UI_POS_Market_Trend_Rising" then
            trendLabel = W.safeGetText("UI_POS_IntelSummary_TrendRising")
            if s.trendPct then
                trendLabel = trendLabel .. "  +" .. string.format("%.1f%%", s.trendPct)
            end
            trendColour = C.success
        elseif s.trendKey == "UI_POS_Market_Trend_Falling" then
            trendLabel = W.safeGetText("UI_POS_IntelSummary_TrendFalling")
            if s.trendPct then
                trendLabel = trendLabel .. "  " .. string.format("%.1f%%", s.trendPct)
            end
            trendColour = C.warn
        else
            trendLabel = W.safeGetText("UI_POS_IntelSummary_TrendStable")
            trendColour = C.dim
        end

        -- Pad category name for alignment (rough monospace alignment)
        local padded = catLabel
        local padLen = 18 - #catLabel
        if padLen > 0 then
            padded = catLabel .. string.rep(" ", padLen)
        end

        W.createLabel(ctx.panel, 8, ctx.y, padded .. trendLabel, trendColour)
        ctx.y = ctx.y + ctx.lineH
    end
    ctx.y = ctx.y + 4

    -- === FIELD NOTES ===
    W.createLabel(ctx.panel, 0, ctx.y,
        "=== " .. W.safeGetText("UI_POS_IntelSummary_FieldNotes") .. " ===", C.textBright)
    ctx.y = ctx.y + ctx.lineH

    local noteCount = player and POS_MarketIngestion.countNotes(player) or 0
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_IntelSummary_UnprocessedNotes") .. ":   " .. tostring(noteCount),
        noteCount > 0 and C.text or C.dim)
    ctx.y = ctx.y + ctx.lineH + 4

    -- === RECORDER STATUS === (only if equipped)
    local recorder = player and POS_DataRecorderService.findEquippedRecorder(player)
    if recorder then
        local status = POS_DataRecorderService.getStatus(recorder)
        if status then
            W.createLabel(ctx.panel, 0, ctx.y,
                "=== " .. W.safeGetText("UI_POS_IntelSummary_RecorderStatus") .. " ===",
                C.textBright)
            ctx.y = ctx.y + ctx.lineH

            W.createLabel(ctx.panel, 8, ctx.y,
                W.safeGetText("UI_POS_IntelSummary_TotalChunks") .. ":  "
                .. tostring(status.totalRecorded or 0), C.text)
            ctx.y = ctx.y + ctx.lineH

            W.createLabel(ctx.panel, 8, ctx.y,
                W.safeGetText("UI_POS_Recorder_Buffer") .. ": "
                .. tostring(status.bufferCount) .. "/" .. tostring(status.bufferCapacity),
                C.text)
            ctx.y = ctx.y + ctx.lineH

            if status.hasMedia then
                W.createLabel(ctx.panel, 8, ctx.y,
                    W.safeGetText("UI_POS_Recorder_Media") .. ": "
                    .. tostring(status.mediaUsed) .. "/" .. tostring(status.mediaCap),
                    C.text)
                ctx.y = ctx.y + ctx.lineH
            end

            ctx.y = ctx.y + 4
        end
    end

    -- === WATCHLIST ===
    if player and POS_Sandbox and POS_Sandbox.getEnableWatchlist
        and POS_Sandbox.getEnableWatchlist() then
        W.createLabel(ctx.panel, 0, ctx.y,
            "=== " .. W.safeGetText("UI_POS_IntelSummary_Watchlist") .. " ===", C.textBright)
        ctx.y = ctx.y + ctx.lineH

        local alertCount = POS_WatchlistService.countPendingAlerts(player)
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_IntelSummary_ActiveAlerts") .. ":       "
            .. tostring(alertCount),
            alertCount > 0 and C.warn or C.dim)
        ctx.y = ctx.y + ctx.lineH + 4
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function(_params)
    local data = {}
    local summaries = gatherCategorySummaries()
    table.insert(data, { type = "kv",
        key = POS_TerminalWidgets.safeGetText("UI_POS_IntelSummary_CategoriesTracked"),
        value = tostring(#summaries) })
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
