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
-- POS_Screen_CommodityItems.lua
-- Item-level drill-down for a commodity category.
-- Shows individual items with average prices and observation
-- counts. Paginated.
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

--- Resolve a display name for a fullType via PhobosLib.
local getItemDisplayName = PhobosLib.getItemDisplayName

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_COMMODITY_ITEMS
screen.menuPath = {"pos.markets.commodities"}
screen.titleKey = "UI_POS_Market_CommodityItems"
screen.sortOrder = 20

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    local categoryId = params and params.categoryId
    if not categoryId then
        W.drawHeader(ctx, "UI_POS_Market_CommodityItems")
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- Category label for header
    local catDef = POS_MarketRegistry.getCategory(categoryId)
    local catLabel = catDef and W.safeGetText(catDef.labelKey) or categoryId

    W.drawHeader(ctx, "UI_POS_Market_CommodityItems")
    W.createLabel(ctx.panel, 0, ctx.y, catLabel, C.textBright)
    ctx.y = ctx.y + ctx.lineH

    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Sub-category filter buttons
    local subCats = POS_MarketRegistry.getVisibleSubCategories(categoryId, nil)
    local activeSubCat = params and params.subCategoryId
    local catIdForFilter = categoryId

    if #subCats > 0 then
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Market_FilterBy"), C.dim)
        ctx.y = ctx.y + ctx.lineH

        -- "View All" option
        if activeSubCat then
            W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
                W.safeGetText("UI_POS_Market_ViewAll"), nil,
                function()
                    POS_ScreenManager.replaceCurrent(
                        POS_Constants.SCREEN_COMMODITY_ITEMS,
                        { categoryId = catIdForFilter })
                end)
        else
            W.createLabel(ctx.panel, ctx.btnX + 4, ctx.y + 2,
                "> " .. W.safeGetText("UI_POS_Market_ViewAll"), C.textBright)
        end
        ctx.y = ctx.y + ctx.btnH + 2

        for _, sub in ipairs(subCats) do
            local subId = sub.id
            if activeSubCat == subId then
                W.createLabel(ctx.panel, ctx.btnX + 4, ctx.y + 2,
                    "> " .. W.safeGetText(sub.labelKey), C.textBright)
            else
                W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
                    W.safeGetText(sub.labelKey), nil,
                    function()
                        POS_ScreenManager.replaceCurrent(
                            POS_Constants.SCREEN_COMMODITY_ITEMS,
                            { categoryId = catIdForFilter, subCategoryId = subId })
                    end)
            end
            ctx.y = ctx.y + ctx.btnH + 2
        end

        ctx.y = ctx.y + 4
        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH
    end

    -- Fetch items (filtered by sub-category if active)
    local items = POS_MarketService.getFilteredCommodityItems(categoryId, activeSubCat)

    if #items == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoItems"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (params and params.itemPage) or 1
        local catIdCopy = categoryId
        local activeSubCopy = activeSubCat
        -- Reduce page size when sub-category filters consume vertical space
        local pageSize = POS_Constants.PAGE_SIZE_COMMODITY_ITEMS
        if #subCats > 0 then
            pageSize = math.max(3, pageSize - #subCats - 2)
        end
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = items,
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
            renderItem = function(parent, rx, ry, _rw, item, _idx)
                -- Item name + price
                local name = getItemDisplayName(item.fullType)
                local priceStr = item.avgPrice
                    and string.format("$%.2f", item.avgPrice) or "?"
                W.createLabel(parent, rx, ry,
                    name .. " — " .. priceStr, C.textBright)
                ry = ry + ctx.lineH

                -- Observation count + freshness
                local obsStr = "  " .. (item.priceCount or 0) .. " "
                    .. W.safeGetText("UI_POS_Market_ItemObservations")
                local freshnessKey = POS_MarketService.getFreshnessKey(item.lastSeen)
                obsStr = obsStr .. " ["
                    .. W.safeGetText(freshnessKey) .. "]"
                W.createLabel(parent, rx, ry, obsStr, C.dim)
                ry = ry + ctx.lineH + 4

                return (ctx.lineH * 2) + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(
                    POS_Constants.SCREEN_COMMODITY_ITEMS,
                    { categoryId = catIdCopy, subCategoryId = activeSubCopy,
                      itemPage = newPage })
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
    if params and params.categoryId then
        local catDef = POS_MarketRegistry.getCategory(params.categoryId)
        if catDef then
            table.insert(data, { type = "header", text = catDef.labelKey })
        end
        local items = POS_MarketService.getCommodityItems(params.categoryId)
        table.insert(data, { type = "kv", key = "UI_POS_Market_ItemCount",
            value = tostring(#items) })
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
