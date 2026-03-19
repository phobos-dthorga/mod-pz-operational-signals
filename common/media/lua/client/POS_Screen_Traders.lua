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
-- POS_Screen_Traders.lua
-- Paginated list of known traders from market intel.
-- Each entry shows source name, location, and categories.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketService"
require "POS_MarketRegistry"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_TRADERS
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_Market_KnownTraders"
screen.sortOrder = 20

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Market_KnownTraders")

    -- Get traders (optionally filtered by category)
    local filterCategory = params and params.filterCategory
    local traders = POS_MarketService.getTraders(filterCategory)

    if #traders == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (params and params.traderPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = traders,
            pageSize = 6,
            currentPage = currentPage,
            x = ctx.btnX,
            y = ctx.y,
            width = ctx.btnW,
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, _rw, trader, _idx)
                -- Source name
                W.createLabel(parent, rx, ry,
                    trader.source, C.textBright)
                ry = ry + ctx.lineH

                -- Location
                W.createLabel(parent, rx + 8, ry,
                    trader.location, C.text)
                ry = ry + ctx.lineH

                -- Categories they trade in
                local catLabels = {}
                for _, catId in ipairs(trader.categories) do
                    local catDef = POS_MarketRegistry.getCategory(catId)
                    local label = catDef and W.safeGetText(catDef.labelKey) or catId
                    table.insert(catLabels, label)
                end
                W.createLabel(parent, rx + 8, ry,
                    table.concat(catLabels, ", "), C.dim)
                ry = ry + ctx.lineH + 4

                return (ctx.lineH * 3) + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_TRADERS,
                    { traderPage = newPage, filterCategory = filterCategory })
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

screen.getContextData = function(params)
    local data = {}
    local filterCategory = params and params.filterCategory
    local traders = POS_MarketService.getTraders(filterCategory)
    table.insert(data, { type = "kv", key = "UI_POS_Market_TraderCount",
        value = tostring(#traders) })
    if filterCategory then
        local catDef = POS_MarketRegistry.getCategory(filterCategory)
        if catDef then
            table.insert(data, { type = "header",
                text = PhobosLib.safeGetText(catDef.labelKey) })
        end
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
