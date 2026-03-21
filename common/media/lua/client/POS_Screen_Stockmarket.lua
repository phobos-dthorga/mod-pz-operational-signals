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
-- POS_Screen_Stockmarket.lua
-- Exchange Hub — commodity indices, trends, and market sentiment.
-- Replaced the original "coming soon" placeholder.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketService"
require "POS_ExchangeEngine"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_STOCKMARKET
screen.menuPath = {"pos.main"}
screen.titleKey = "UI_POS_Stock_Header"
screen.sortOrder = 90
screen.shouldShow = function(_player, _ctx)
    return POS_Sandbox and POS_Sandbox.getEnableExchange and POS_Sandbox.getEnableExchange()
end

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Stock_Header")

    -- Exchange overview
    local overview = POS_MarketService.getExchangeOverview()

    -- Market sentiment
    W.createLabel(ctx.panel, 0, ctx.y,
        W.safeGetText("UI_POS_Exchange_MarketOverview"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Sentiment indicator
    local sentimentLabel = W.safeGetText(overview.sentimentKey)
    local sentimentColour = C.text
    if overview.sentimentKey == "UI_POS_Market_Sentiment_Bullish" then
        sentimentColour = C.success
    elseif overview.sentimentKey == "UI_POS_Market_Sentiment_Bearish" then
        sentimentColour = C.error
    end
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Exchange_Sentiment") .. ": " .. sentimentLabel,
        sentimentColour)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Commodity indices
    if #overview.indices == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Exchange_CommodityIndex"), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH

        --- Render a single index entry as a navigable button.
        local function renderIndexEntry(parent, rx, ry, rw, entry, _idx)
            local arrow = "="
            local colour = C.text
            if entry.trendKey == "UI_POS_Market_Trend_Rising" then
                arrow = "^"
                colour = C.success
            elseif entry.trendKey == "UI_POS_Market_Trend_Falling" then
                arrow = "v"
                colour = C.error
            end

            local changeStr = ""
            if entry.changePct and entry.changePct ~= 0 then
                changeStr = " (" .. string.format("%+.1f%%", entry.changePct) .. ")"
            end

            local line = "  " .. W.safeGetText(entry.labelKey)
                .. ": " .. string.format("%.1f", entry.index or 100)
                .. " " .. arrow .. changeStr

            local catId = entry.categoryId
            W.createButton(parent, rx, ry, rw, ctx.btnH, line, nil,
                function()
                    POS_ScreenManager.navigateTo(POS_Constants.SCREEN_COMMODITY_DETAIL,
                        { categoryId = catId })
                end)
            return ctx.btnH + 4
        end

        local pageSize = POS_Constants.UI_EXCHANGE_PAGE_SIZE
        if #overview.indices > pageSize then
            local currentPage = (_params and _params.indexPage) or 1
            ctx.y = PhobosLib_Pagination.create(ctx.panel, {
                items = overview.indices,
                pageSize = pageSize,
                currentPage = currentPage,
                x = ctx.btnX,
                y = ctx.y,
                width = ctx.btnW,
                colours = {
                    text = C.text, dim = C.dim,
                    bgDark = C.bgDark, bgHover = C.bgHover,
                    border = C.border,
                },
                renderItem = renderIndexEntry,
                onPageChange = function(newPage)
                    POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_STOCKMARKET,
                        { indexPage = newPage })
                end,
            })
        else
            for _, entry in ipairs(overview.indices) do
                local entryHeight = renderIndexEntry(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, entry, nil)
                ctx.y = ctx.y + entryHeight
            end
        end
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
    local overview = POS_MarketService.getExchangeOverview()
    table.insert(data, { type = "header", text = "UI_POS_Exchange_MarketOverview" })
    table.insert(data, { type = "kv", key = "UI_POS_Exchange_Sentiment",
        value = PhobosLib.safeGetText(overview.sentimentKey) })
    for _, entry in ipairs(overview.indices) do
        table.insert(data, { type = "kv",
            key = entry.labelKey,
            value = string.format("%.1f", entry.index or 100) })
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
