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
-- Shows discovered items with prices, observation counts,
-- and inline buy controls ([-] qty [+] [Buy $X.XX]).
-- Paginated.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketService"
require "POS_MarketRegistry"
require "POS_ItemPool"
require "POS_TradeService"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local getItemDisplayName = PhobosLib.getItemDisplayName

-- Per-item quantity state (reset on screen create)
local _quantities = {}

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_COMMODITY_ITEMS
screen.menuPath = {"pos.markets.commodities"}
screen.titleKey = "UI_POS_Market_CommodityItems"
screen.sortOrder = 20

---------------------------------------------------------------
-- Buy handler
---------------------------------------------------------------

local function executeBuyAction(fullType, categoryId, qty, avgPrice)
    local player = getPlayer()
    if not player then return end

    local totalCost = math.floor(avgPrice * qty * 100 + 0.5) / 100

    -- Check balance
    local balance = POS_TradeService.getPlayerBalance(player)
    if balance < totalCost then
        if PhobosLib.notifyOrSay then
            PhobosLib.notifyOrSay("POSnet",
                PhobosLib.safeGetText("UI_POS_Trade_Err_NoMoney"),
                "error")
        end
        return
    end

    -- Deduct money
    local okPay = PhobosLib.safecall(PhobosLib.removeMoney, player, totalCost)
    if not okPay then
        PhobosLib.warn("POS", "[Trade]", "Failed to deduct payment")
        return
    end

    -- Grant items (exceed weight is OK per design)
    local okGrant = PhobosLib.safecall(PhobosLib.grantItems, player, fullType, qty)
    if not okGrant then
        -- Rollback: refund money
        PhobosLib.safecall(PhobosLib.addMoney, player, totalCost)
        PhobosLib.warn("POS", "[Trade]", "Failed to grant items, refunded payment")
        return
    end

    -- Success notification
    local displayName = getItemDisplayName(fullType) or fullType
    if PhobosLib.notifyOrSay then
        PhobosLib.notifyOrSay("POSnet",
            "Purchased " .. tostring(qty) .. "x " .. displayName
            .. " for $" .. string.format("%.2f", totalCost),
            "success")
    end

    -- Emit trade event (Starlit)
    if POS_Events and POS_Events.OnTradeCompleted then
        POS_Events.OnTradeCompleted:trigger({
            type = "buy",
            fullType = fullType,
            quantity = qty,
            totalCost = totalCost,
            categoryId = categoryId,
        })
    end

    -- Reset quantity for this item
    _quantities[fullType] = 1

    -- Refresh screen
    POS_ScreenManager.refreshCurrentScreen()
end

---------------------------------------------------------------
-- Screen creation
---------------------------------------------------------------

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

    -- Category label
    local catDef = POS_MarketRegistry.getCategory(categoryId)
    local catLabel = catDef and W.safeGetText(catDef.labelKey) or categoryId

    W.drawHeader(ctx, "UI_POS_Market_CommodityItems")
    W.createLabel(ctx.panel, 0, ctx.y, catLabel, C.textBright)
    ctx.y = ctx.y + ctx.lineH

    -- Player balance
    local player = getPlayer()
    local balance = POS_TradeService.getPlayerBalance(player)
    W.createLabel(ctx.panel, 0, ctx.y,
        W.safeGetText("UI_POS_Trade_Balance") .. ": $"
        .. string.format("%.2f", balance), C.text)
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

    -- Fetch items
    local items = POS_MarketService.getFilteredCommodityItems(categoryId, activeSubCat)

    if #items == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoItemsYet"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoItemsHint"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (params and params.itemPage) or 1
        local catIdCopy = categoryId
        local activeSubCopy = activeSubCat
        local pageSize = POS_Constants.PAGE_SIZE_COMMODITY_ITEMS
        if #subCats > 0 then
            pageSize = math.max(3, pageSize - #subCats - 2)
        end

        -- Capture for closures
        local balanceCopy = balance
        local categoryIdCopy = categoryId

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
            renderItem = function(parent, rx, ry, rw, item, _idx)
                local ft = item.fullType
                local name = getItemDisplayName(ft) or ft
                local priceStr = item.avgPrice
                    and string.format("$%.2f", item.avgPrice) or "?"
                local obsCount = item.priceCount or 0

                -- Row 1: Item name + price + observations
                W.createLabel(parent, rx, ry,
                    name .. "  " .. priceStr, C.textBright)
                ry = ry + ctx.lineH

                local obsStr = "  " .. obsCount .. " "
                    .. W.safeGetText("UI_POS_Market_ItemObservations")
                local freshnessKey = POS_MarketService.getFreshnessKey(item.lastSeen)
                obsStr = obsStr .. " [" .. W.safeGetText(freshnessKey) .. "]"
                W.createLabel(parent, rx, ry, obsStr, C.dim)
                ry = ry + ctx.lineH

                -- Row 2: Buy controls [-] qty [+] [Buy $total]
                if item.avgPrice and item.avgPrice > 0 then
                    if not _quantities[ft] then _quantities[ft] = 1 end
                    local qty = _quantities[ft]
                    local maxQty = math.min(
                        obsCount > 0 and obsCount or POS_Constants.TRADE_MAX_QUANTITY_PER_TX,
                        POS_Constants.TRADE_MAX_QUANTITY_PER_TX)
                    if maxQty < 1 then maxQty = 1 end

                    local btnSize = 24
                    local bx = rx

                    -- [-] button
                    W.createButton(parent, bx, ry, btnSize, ctx.btnH,
                        "-", nil,
                        function()
                            _quantities[ft] = math.max(1, (_quantities[ft] or 1) - 1)
                            POS_ScreenManager.refreshCurrentScreen()
                        end)
                    bx = bx + btnSize + 2

                    -- Qty label
                    W.createLabel(parent, bx + 4, ry + 2,
                        tostring(qty), C.textBright)
                    bx = bx + 28

                    -- [+] button
                    W.createButton(parent, bx, ry, btnSize, ctx.btnH,
                        "+", nil,
                        function()
                            _quantities[ft] = math.min(maxQty, (_quantities[ft] or 1) + 1)
                            POS_ScreenManager.refreshCurrentScreen()
                        end)
                    bx = bx + btnSize + 8

                    -- [Buy $X.XX] button
                    local totalCost = math.floor(item.avgPrice * qty * 100 + 0.5) / 100
                    local canAfford = balanceCopy >= totalCost
                    local buyLabel = W.safeGetText("UI_POS_Trade_BuyBtn")
                        .. " $" .. string.format("%.2f", totalCost)

                    if canAfford then
                        local ftCopy = ft
                        local priceCopy = item.avgPrice
                        W.createButton(parent, bx, ry, rw - bx + rx, ctx.btnH,
                            buyLabel, nil,
                            function()
                                local q = _quantities[ftCopy] or 1
                                executeBuyAction(ftCopy, categoryIdCopy, q, priceCopy)
                            end)
                    else
                        W.createDisabledButton(parent, bx, ry, rw - bx + rx, ctx.btnH,
                            buyLabel,
                            W.safeGetText("UI_POS_Trade_Err_NoMoney"))
                    end

                    ry = ry + ctx.btnH + 4
                else
                    ry = ry + 4
                end

                return ry - (ry - ctx.lineH * 2 - ctx.btnH - 4)
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(
                    POS_Constants.SCREEN_COMMODITY_ITEMS,
                    { categoryId = catIdCopy, subCategoryId = activeSubCopy,
                      itemPage = newPage })
            end,
        })

        -- Discovery counter
        local totalPoolItems = POS_ItemPool.getItemsForCategory(categoryId)
        local poolCount = totalPoolItems and #totalPoolItems or 0
        if poolCount > 0 then
            ctx.y = ctx.y + 4
            W.createLabel(ctx.panel, 8, ctx.y,
                tostring(#items) .. " of ~" .. tostring(poolCount)
                .. " " .. W.safeGetText("UI_POS_Market_ItemsDiscovered"),
                C.dim)
            ctx.y = ctx.y + ctx.lineH
        end
    end

    W.drawFooter(ctx)
end

screen.destroy = function()
    _quantities = {}
    POS_TerminalWidgets.defaultDestroy()
end

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

        -- Show balance in context panel too
        local balance = POS_TradeService.getPlayerBalance(getPlayer())
        table.insert(data, { type = "separator" })
        table.insert(data, { type = "kv", key = "UI_POS_Trade_Balance",
            value = "$" .. string.format("%.2f", balance) })
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
