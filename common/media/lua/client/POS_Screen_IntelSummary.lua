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
    local _TAG = "[POS:IntelSummary]"
    PhobosLib.debug("POS", "[POS:IntelSummary]", "create() START")
    local ok, err = PhobosLib.safecall(function()
        PhobosLib.debug("POS", "[POS:IntelSummary]", "A: inside safecall")
        local W = POS_TerminalWidgets
        local C = W.COLOURS
        PhobosLib.debug("POS", "[POS:IntelSummary]", "B: initLayout")
        local ctx = W.initLayout(contentPanel)
        PhobosLib.debug("POS", "[POS:IntelSummary]", "C: drawHeader")
        W.drawHeader(ctx, "UI_POS_IntelSummary_Title")
        PhobosLib.debug("POS", "[POS:IntelSummary]", "D: getSpecificPlayer")
        local player = getSpecificPlayer(0)
        PhobosLib.debug("POS", "[POS:IntelSummary]", "E: gatherCategorySummaries")
        local summOk, summaries = PhobosLib.safecall(gatherCategorySummaries)
        if not summOk then summaries = {} end
        summaries = summaries or {}
        PhobosLib.debug("POS", "[POS:IntelSummary]", "F: summaries=" .. tostring(#summaries))
        local catOk, visibleCats = PhobosLib.safecall(
            POS_MarketRegistry.getVisibleCategories, {})
        local totalCategories = (catOk and visibleCats) and #visibleCats or 0
        PhobosLib.debug("POS", "[POS:IntelSummary]", "G: totalCategories=" .. tostring(totalCategories))
        -- Dump first summary for diagnosis
        if #summaries > 0 then
            local s1 = summaries[1]
            PhobosLib.debug("POS", "[POS:IntelSummary]", "G2: first summary cat=" .. tostring(s1.categoryId)
                .. " avg=" .. tostring(s1.avgPrice)
                .. " low=" .. tostring(s1.lowPrice)
                .. " high=" .. tostring(s1.highPrice)
                .. " fresh=" .. tostring(s1.freshnessKey)
                .. " conf=" .. tostring(s1.confidenceKey)
                .. " trend=" .. tostring(s1.trendKey)
                .. " trendPct=" .. tostring(s1.trendPct))
        end
        if #summaries == 0 then
            PhobosLib.debug("POS", "[POS:IntelSummary]", "H: no data, showing empty state")
            W.createLabel(ctx.panel, 8, ctx.y,
                W.safeGetText("UI_POS_IntelSummary_NoData"), C.dim)
            ctx.y = ctx.y + ctx.lineH * 2
            PhobosLib.debug("POS", "[POS:IntelSummary]", "I: drawFooter")
            W.drawFooter(ctx)
            PhobosLib.debug("POS", "[POS:IntelSummary]", "J: returning from no-data path")
            return
        end

        -- === MARKET COVERAGE ===
        W.createLabel(ctx.panel, 0, ctx.y,
            "=== " .. W.safeGetText("UI_POS_IntelSummary_Coverage") .. " ===", C.textBright)
        ctx.y = ctx.y + ctx.lineH

        local coveragePct = totalCategories > 0
            and math.floor(#summaries / totalCategories * 100 + 0.5) or 0
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_IntelSummary_CategoriesTracked") .. ":  "
            .. tostring(#summaries) .. "/" .. tostring(totalCategories), C.text)
        ctx.y = ctx.y + ctx.lineH
        W.createProgressBar(ctx.panel, 8, ctx.y, ctx.pw - 16, coveragePct, C.text)
        ctx.y = ctx.y + ctx.lineH

        -- Freshness summary (compact single line)
        local fresh, stale, expired = countByFreshness(summaries)
        local freshnessLine = W.safeGetText("UI_POS_IntelSummary_FreshCount",
                tostring(POS_Constants.MARKET_FRESH_DAYS)) .. ": " .. tostring(fresh)
            .. "   " .. W.safeGetText("UI_POS_IntelSummary_StaleCount",
                tostring(POS_Constants.MARKET_FRESH_DAYS),
                tostring(POS_Constants.MARKET_STALE_DAYS)) .. ": " .. tostring(stale)
            .. "   " .. W.safeGetText("UI_POS_IntelSummary_ExpiredCount",
                tostring(POS_Constants.MARKET_STALE_DAYS)) .. ": " .. tostring(expired)
        W.createLabel(ctx.panel, 8, ctx.y, freshnessLine, C.text)
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

        -- === CATEGORY TRENDS (compact) ===
        W.createLabel(ctx.panel, 0, ctx.y,
            "=== " .. W.safeGetText("UI_POS_IntelSummary_Trends") .. " ===", C.textBright)
        ctx.y = ctx.y + ctx.lineH

        local rising, stable, falling = 0, 0, 0
        for _, s in ipairs(summaries) do
            if s.trendKey == "UI_POS_Market_Trend_Rising" then
                rising = rising + 1
            elseif s.trendKey == "UI_POS_Market_Trend_Falling" then
                falling = falling + 1
            else
                stable = stable + 1
            end
        end

        local trendLine = W.safeGetText("UI_POS_IntelSummary_TrendRising") .. ": " .. tostring(rising)
            .. "    " .. W.safeGetText("UI_POS_IntelSummary_TrendStable") .. ": " .. tostring(stable)
            .. "    " .. W.safeGetText("UI_POS_IntelSummary_TrendFalling") .. ": " .. tostring(falling)
        W.createLabel(ctx.panel, 8, ctx.y, trendLine, C.text)
        ctx.y = ctx.y + ctx.lineH + 4

        -- === FIELD NOTES ===
        W.createLabel(ctx.panel, 0, ctx.y,
            "=== " .. W.safeGetText("UI_POS_IntelSummary_FieldNotes") .. " ===", C.textBright)
        ctx.y = ctx.y + ctx.lineH

        local noteOk, noteCount = PhobosLib.safecall(function()
            return player and POS_MarketIngestion.countNotes(player) or 0
        end)
        noteCount = (noteOk and noteCount) or 0
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_IntelSummary_UnprocessedNotes") .. ":   " .. tostring(noteCount),
            noteCount > 0 and C.text or C.dim)
        ctx.y = ctx.y + ctx.lineH + 4

        -- === RECORDER STATUS === (only if equipped)
        local recOk, recorder = PhobosLib.safecall(function()
            return player and POS_DataRecorderService.findEquippedRecorder(player)
        end)
        recorder = recOk and recorder or nil
        if recorder then
            local statOk, status = PhobosLib.safecall(
                POS_DataRecorderService.getStatus, recorder)
            status = statOk and status or nil
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
                    .. tostring(status.bufferCount or 0) .. "/" .. tostring(status.bufferCapacity or 0),
                    C.text)
                ctx.y = ctx.y + ctx.lineH

                if status.hasMedia then
                    W.createLabel(ctx.panel, 8, ctx.y,
                        W.safeGetText("UI_POS_Recorder_Media") .. ": "
                        .. tostring(status.mediaUsed or 0) .. "/" .. tostring(status.mediaCap or 0),
                        C.text)
                    ctx.y = ctx.y + ctx.lineH
                end

                ctx.y = ctx.y + 4
            end
        end

        -- === WATCHLIST ===
        local watchOk, watchEnabled = PhobosLib.safecall(function()
            return POS_Sandbox and POS_Sandbox.getEnableWatchlist
                and POS_Sandbox.getEnableWatchlist()
        end)
        if watchOk and watchEnabled and player then
            W.createLabel(ctx.panel, 0, ctx.y,
                "=== " .. W.safeGetText("UI_POS_IntelSummary_Watchlist") .. " ===", C.textBright)
            ctx.y = ctx.y + ctx.lineH

            local alertOk, alertCount = PhobosLib.safecall(
                POS_WatchlistService.countPendingAlerts, player)
            alertCount = (alertOk and alertCount) or 0
            W.createLabel(ctx.panel, 8, ctx.y,
                W.safeGetText("UI_POS_IntelSummary_ActiveAlerts") .. ":       "
                .. tostring(alertCount),
                alertCount > 0 and C.warn or C.dim)
            ctx.y = ctx.y + ctx.lineH + 4
        end

        -- Footer
        W.drawFooter(ctx)
    end)

    if not ok then
        print(_TAG .. " ERROR in screen.create: " .. tostring(err))
        PhobosLib.debug("POS", _TAG, "screen.create failed: " .. tostring(err))
        -- Show error on screen if possible
        local W = POS_TerminalWidgets
        if W and contentPanel then
            PhobosLib.safecall(function()
                local C = W.COLOURS
                W.createLabel(contentPanel, 8, 60,
                    "ERROR: " .. tostring(err), C.warn or { r=1, g=0.5, b=0, a=1 })
            end)
        end
    end
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function(_params)
    local ok, data = PhobosLib.safecall(function()
        local result = {}
        local summaries = gatherCategorySummaries()
        table.insert(result, { type = "kv",
            key = POS_TerminalWidgets.safeGetText("UI_POS_IntelSummary_CategoriesTracked"),
            value = tostring(#summaries) })
        return result
    end)
    return (ok and data) or {}
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
