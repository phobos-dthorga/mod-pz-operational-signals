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
-- POS_Screen_Watchlist.lua
-- Watchlist management: shows watched categories, current prices,
-- and recent alerts. Allows unwatching from this screen.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketService"
require "POS_MarketRegistry"
require "POS_PlayerState"
require "POS_WatchlistService"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_WATCHLIST
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_Market_Watchlist"
screen.sortOrder = 50
screen.shouldShow = function(_player, _ctx)
    return true
end

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Market_Watchlist")

    local player = getSpecificPlayer(0)
    if not player then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    local watchlist = POS_PlayerState.getWatchlist(player)

    if not watchlist or #watchlist == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_WatchlistEmpty"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_Watchlist_HowToAdd"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (params and params.watchPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = watchlist,
            pageSize = POS_Constants.PAGE_SIZE_WATCHLIST,
            currentPage = currentPage,
            x = ctx.btnX,
            y = ctx.y,
            width = ctx.btnW,
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, rw, entry, _idx)
                -- Category name + current avg price
                local catDef = POS_MarketRegistry.getCategory(entry.categoryId)
                local catLabel = catDef and W.safeGetText(catDef.labelKey)
                    or entry.categoryId
                local summary = POS_MarketService.getCommoditySummary(entry.categoryId)
                local priceStr = summary and summary.avgPrice
                    and string.format("$%.2f", summary.avgPrice) or "—"

                W.createLabel(parent, rx, ry,
                    catLabel .. " — " .. priceStr, C.textBright)
                ry = ry + ctx.lineH

                -- Change from snapshot
                local changeStr = ""
                if entry.lastSnapshotAvg and summary and summary.avgPrice then
                    local changePct = ((summary.avgPrice - entry.lastSnapshotAvg)
                        / entry.lastSnapshotAvg) * 100
                    if entry.lastSnapshotAvg > 0 then
                        local sign = changePct >= 0 and "+" or ""
                        changeStr = W.safeGetText("UI_POS_Market_PriceChange")
                            .. ": " .. sign .. string.format("%.1f%%", changePct)
                    end
                end
                if changeStr ~= "" then
                    W.createLabel(parent, rx + 8, ry, changeStr, C.dim)
                else
                    W.createLabel(parent, rx + 8, ry,
                        W.safeGetText("UI_POS_Market_WatchedSince")
                        .. " " .. (entry.addedDay or "?"), C.dim)
                end
                ry = ry + ctx.lineH

                -- History + Unwatch buttons
                local catIdCopy = entry.categoryId
                local histBtnW = 80
                local unwatchBtnW = math.min(rw / 2, 120)
                local btnGap = 4

                W.createButton(parent, rx + 8, ry, histBtnW, ctx.btnH,
                    W.safeGetText("UI_POS_Watchlist_History"), nil,
                    function()
                        POS_ScreenManager.navigateTo(
                            POS_Constants.SCREEN_COMMODITY_DETAIL,
                            { categoryId = catIdCopy })
                    end)

                W.createButton(parent, rx + 8 + histBtnW + btnGap, ry,
                    unwatchBtnW, ctx.btnH,
                    W.safeGetText("UI_POS_Market_UnwatchCategory"), nil,
                    function()
                        local p = getSpecificPlayer(0)
                        if p then
                            POS_PlayerState.removeFromWatchlist(p, catIdCopy)
                            POS_ScreenManager.markDirty()
                        end
                    end)
                ry = ry + ctx.btnH + 4

                return (ctx.lineH * 2) + ctx.btnH + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(
                    POS_Constants.SCREEN_WATCHLIST,
                    { watchPage = newPage })
            end,
        })
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
    local player = getSpecificPlayer(0)
    if player then
        local wl = POS_PlayerState.getWatchlist(player)
        table.insert(data, { type = "kv", key = "UI_POS_Market_Watchlist",
            value = tostring(#wl) })
        local alertCount = POS_WatchlistService.countPendingAlerts(player)
        if alertCount > 0 then
            table.insert(data, { type = "kv", key = "UI_POS_Market_AlertCount",
                value = tostring(alertCount) })
        end
    end
    return data
end

---------------------------------------------------------------
-- Starlit reactive refresh
---------------------------------------------------------------

if POS_Events and POS_Events.OnTradeCompleted then
    POS_Events.OnTradeCompleted:addListener(function()
        if POS_ScreenManager.currentScreen == screen.id then
            POS_ScreenManager.markDirty()
        end
    end)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
