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
-- POS_Screen_Commodities.lua
-- Paginated list of commodity categories from the market
-- registry. Each entry shows category name, source count,
-- and a freshness indicator.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketRegistry"
require "POS_MarketDatabase"
require "POS_MarketService"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_COMMODITIES
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_Market_CommodityMarkets"
screen.sortOrder = 10

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Market_CommodityMarkets")

    -- Fetch visible categories
    local categories = POS_MarketRegistry.getVisibleCategories({})

    if #categories == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (_params and _params.commodPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = categories,
            pageSize = POS_Constants.PAGE_SIZE_COMMODITIES,
            currentPage = currentPage,
            x = ctx.btnX,
            y = ctx.y,
            width = ctx.btnW,
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, rw, cat, _idx)
                local summary = POS_MarketDatabase.getSummary(cat.id)
                local label
                if summary then
                    local freshnessKey = POS_MarketService.getFreshnessKey(summary.freshestDay)
                    local freshness = W.safeGetText(freshnessKey)
                    local sources = summary.sourceCount or 0
                    label = W.safeGetText(cat.labelKey)
                        .. " — " .. sources .. " "
                        .. W.safeGetText("UI_POS_Market_Sources")
                        .. " [" .. freshness .. "]"
                else
                    label = W.safeGetText(cat.labelKey)
                        .. " — " .. W.safeGetText("UI_POS_Market_NoData")
                end

                local catId = cat.id
                W.createButton(parent, rx, ry, rw, ctx.btnH, label, nil,
                    function()
                        POS_ScreenManager.navigateTo(
                            POS_Constants.SCREEN_COMMODITY_DETAIL,
                            { categoryId = catId })
                    end)
                return ctx.btnH + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_COMMODITIES,
                    { commodPage = newPage })
            end,
        })
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.getContextData = function(_params)
    local data = {}
    local categories = POS_MarketRegistry.getVisibleCategories({})
    if #categories > 0 then
        table.insert(data, { type = "kv", key = "UI_POS_Market_Categories",
            value = tostring(#categories) })
    end
    return data
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
