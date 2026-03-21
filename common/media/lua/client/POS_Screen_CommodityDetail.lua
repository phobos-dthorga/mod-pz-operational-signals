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
-- POS_Screen_CommodityDetail.lua
-- Summary-first layout for a single commodity category.
-- Shows low/avg/high price, source count, freshness,
-- confidence, trend, and sub-menu buttons.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketService"
require "POS_MarketIngestion"
require "POS_PlayerState"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_COMMODITY_DETAIL
screen.menuPath = {"pos.markets.commodities"}
screen.titleKey = "UI_POS_Market_CommodityDetail"
screen.sortOrder = 10

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    local categoryId = params and params.categoryId
    if not categoryId then
        W.drawHeader(ctx, "UI_POS_Market_CommodityDetail")
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    local summary = POS_MarketService.getCommoditySummary(categoryId)
    if not summary then
        W.drawHeader(ctx, "UI_POS_Market_CommodityDetail")
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- Header
    W.drawHeader(ctx, summary.labelKey)

    -- Price summary
    if summary.sourceCount == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_InsufficientData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        -- Lowest price
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_LowestPrice") .. ": $"
            .. string.format("%.2f", summary.lowPrice or 0), C.text)
        ctx.y = ctx.y + ctx.lineH

        -- Average price
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_AveragePrice") .. ": $"
            .. string.format("%.2f", summary.avgPrice or 0), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        -- Highest price
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_HighestPrice") .. ": $"
            .. string.format("%.2f", summary.highPrice or 0), C.text)
        ctx.y = ctx.y + ctx.lineH

        ctx.y = ctx.y + 4

        -- Source count
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_Sources") .. ": "
            .. summary.sourceCount, C.dim)
        ctx.y = ctx.y + ctx.lineH

        -- Freshness
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_Freshness") .. ": "
            .. W.safeGetText(summary.freshnessKey), C.dim)
        ctx.y = ctx.y + ctx.lineH

        -- Confidence
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_Confidence") .. ": "
            .. W.safeGetText(summary.confidenceKey), C.dim)
        ctx.y = ctx.y + ctx.lineH

        -- Trend
        local trendColour = C.dim
        if summary.trendKey == "UI_POS_Market_Trend_Rising" then
            trendColour = C.success
        elseif summary.trendKey == "UI_POS_Market_Trend_Falling" then
            trendColour = C.error
        end
        local trendStr = W.safeGetText(summary.trendKey)
        if summary.trendPct and summary.trendPct ~= 0 then
            trendStr = trendStr .. " (" .. string.format("%+.1f%%", summary.trendPct) .. ")"
        end
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_Trend") .. ": " .. trendStr, trendColour)
        ctx.y = ctx.y + ctx.lineH
    end

    -- Sub-menu buttons
    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH + 4

    -- Known Sellers
    local catId = categoryId
    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        "[1] " .. W.safeGetText("UI_POS_Market_KnownSellers"), nil,
        function()
            POS_ScreenManager.navigateTo(POS_Constants.SCREEN_TRADERS,
                { filterCategory = catId })
        end)
    ctx.y = ctx.y + ctx.btnH + 4

    -- Price History
    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        "[2] " .. W.safeGetText("UI_POS_Market_PriceHistory"), nil,
        function()
            POS_ScreenManager.navigateTo(POS_Constants.SCREEN_LEDGER,
                { categoryId = catId })
        end)
    ctx.y = ctx.y + ctx.btnH + 4

    -- Compile Report (if enough data)
    if POS_MarketIngestion.canCompileReport(categoryId) then
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[3] " .. W.safeGetText("UI_POS_Market_CompileReport"), nil,
            function()
                local player = getSpecificPlayer(0)
                POS_MarketIngestion.compileReport(catId, player)
                POS_ScreenManager.markDirty()
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    end

    -- View Items
    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        "[4] " .. W.safeGetText("UI_POS_Market_ViewItems"), nil,
        function()
            POS_ScreenManager.navigateTo(POS_Constants.SCREEN_COMMODITY_ITEMS,
                { categoryId = catId })
        end)
    ctx.y = ctx.y + ctx.btnH + 4

    -- Watch/Unwatch toggle (only when watchlist is enabled)
    if POS_Sandbox and POS_Sandbox.getEnableWatchlist
        and POS_Sandbox.getEnableWatchlist() then
        local player = getSpecificPlayer(0)
        if player then
            local isWatching = POS_PlayerState.isWatching(player, catId)
            local watchKey = isWatching
                and "UI_POS_Market_UnwatchCategory"
                or "UI_POS_Market_WatchCategory"
            W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
                "[5] " .. W.safeGetText(watchKey), nil,
                function()
                    local p = getSpecificPlayer(0)
                    if not p then return end
                    if POS_PlayerState.isWatching(p, catId) then
                        POS_PlayerState.removeFromWatchlist(p, catId)
                    else
                        POS_PlayerState.addToWatchlist(p, catId)
                    end
                    POS_ScreenManager.markDirty()
                end)
            ctx.y = ctx.y + ctx.btnH + 4
        end
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function(params)
    local data = {}
    if params and params.categoryId then
        local summary = POS_MarketService.getCommoditySummary(params.categoryId)
        table.insert(data, { type = "header", text = summary.labelKey })
        if summary.avgPrice then
            table.insert(data, { type = "kv", key = "UI_POS_Market_AveragePrice",
                value = "$" .. string.format("%.2f", summary.avgPrice) })
        end
        table.insert(data, { type = "kv", key = "UI_POS_Market_Sources",
            value = tostring(summary.sourceCount) })
        table.insert(data, { type = "kv", key = "UI_POS_Market_Trend",
            value = PhobosLib.safeGetText(summary.trendKey) })
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
