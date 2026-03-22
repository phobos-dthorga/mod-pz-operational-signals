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
-- POS_Screen_TradeCatalog.lua
-- Buy/sell catalog for a specific wholesaler. Shows category
-- browser, then paginated item list with buy/sell mode toggle.
-- All business logic delegated to POS_TradeService.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_WorldState"
require "POS_WholesalerService"
require "POS_TradeService"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}

-- Per-session quantity selections, keyed by fullType. Reset on create/mode/page.
local _quantities = {}
screen.id = POS_Constants.SCREEN_TRADE_CATALOG
screen.menuPath = {"pos.markets.trade"}
screen.titleKey = "UI_POS_Trade_CatalogTitle"

---------------------------------------------------------------
-- Category browser (no categoryId selected)
---------------------------------------------------------------

local function renderCategoryBrowser(ctx, W, C, wholesaler, wsId, mode)
    local categories = wholesaler.categoryWeights
    if not categories or not next(categories) then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Trade_NoItems"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        return
    end

    -- Build sorted category list
    local catList = {}
    for catId, _weight in pairs(categories) do
        table.insert(catList, catId)
    end
    table.sort(catList)

    for _, catId in ipairs(catList) do
        local catLabel = W.safeGetText("UI_POS_Market_Category_" .. catId)
        if catLabel == "UI_POS_Market_Category_" .. catId then
            catLabel = catId
        end
        local cId = catId
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            catLabel, nil,
            function()
                POS_ScreenManager.replaceCurrent(
                    POS_Constants.SCREEN_TRADE_CATALOG,
                    { wholesalerId = wsId, mode = mode, categoryId = cId })
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    end
end

---------------------------------------------------------------
-- Paginated item list (categoryId selected)
---------------------------------------------------------------

local function renderItemList(ctx, W, C, params, player, balance)
    local wsId = params.wholesalerId
    local mode = params.mode or "buy"
    local categoryId = params.categoryId
    local currentPage = params.page or 1

    local items
    local emptyKey
    if mode == "buy" then
        items = POS_TradeService and POS_TradeService.getBuyableItems
            and POS_TradeService.getBuyableItems(wsId, categoryId, player)
        emptyKey = "UI_POS_Trade_NoDiscoveries"
    else
        items = POS_TradeService and POS_TradeService.getSellableItems
            and POS_TradeService.getSellableItems(wsId, categoryId, player)
        emptyKey = "UI_POS_Trade_NothingToSell"
    end

    if not items or #items == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText(emptyKey), C.dim)
        ctx.y = ctx.y + ctx.lineH
        return
    end

    -- Discovery count label (buy mode only)
    if mode == "buy" and items.totalCount then
        local discoveryText = W.safeGetText("UI_POS_Trade_DiscoveryCount")
        discoveryText = discoveryText:gsub("%%1", tostring(#items))
        discoveryText = discoveryText:gsub("%%2", tostring(items.totalCount))
        W.createLabel(ctx.panel, 8, ctx.y, discoveryText, C.dim)
        ctx.y = ctx.y + ctx.lineH + 4
    end

    ctx.y = PhobosLib_Pagination.create(ctx.panel, {
        items = items,
        pageSize = POS_Constants.PAGE_SIZE_TRADE_CATALOG,
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
            local itemY = 0
            local ft = item.fullType

            -- Item name
            local displayName = item.displayName or item.name or ft or "???"
            W.createLabel(parent, rx, ry + itemY, displayName, C.text)

            -- Price + stock/owned on same line
            local unitPrice
            local maxQty
            local detailStr
            if mode == "buy" then
                unitPrice = item.buyPrice or item.price or 0
                local stock = item.stock
                maxQty = stock or POS_Constants.TRADE_MAX_QUANTITY_PER_TX
                detailStr = "$" .. string.format("%.2f", unitPrice)
                if stock then
                    detailStr = detailStr .. "  "
                        .. W.safeGetText("UI_POS_Trade_Stock") .. ": " .. tostring(stock)
                end
            else
                unitPrice = item.sellPrice or item.price or 0
                local owned = item.ownedCount or 0
                maxQty = owned
                detailStr = "$" .. string.format("%.2f", unitPrice)
                    .. "  " .. W.safeGetText("UI_POS_Trade_Owned") .. ": " .. tostring(owned)
            end
            W.createLabel(parent, rx + rw * 0.55, ry + itemY, detailStr, C.dim)
            itemY = itemY + ctx.lineH

            -- Cap maxQty to the per-tx limit
            maxQty = math.min(maxQty or 1, POS_Constants.TRADE_MAX_QUANTITY_PER_TX)
            if maxQty < 1 then maxQty = 1 end

            -- Initialise quantity for this item if not set
            if not _quantities[ft] then _quantities[ft] = 1 end
            local qty = _quantities[ft]

            -- Inline quantity controls: [-] qty [+] [Confirm]
            local btnMinus   = 30
            local lblQtyW    = 40
            local btnPlus    = 30
            local gap        = 4
            local confirmX   = rx + btnMinus + lblQtyW + btnPlus + (gap * 3)
            local confirmW   = rw - (btnMinus + lblQtyW + btnPlus + (gap * 3))
            if confirmW < 60 then confirmW = 60 end

            -- [-] button
            W.createButton(parent, rx, ry + itemY, btnMinus, ctx.btnH,
                "-", nil,
                function()
                    _quantities[ft] = math.max((_quantities[ft] or 1) - 1, 1)
                    POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_TRADE_CATALOG,
                        { wholesalerId = wsId, mode = mode, categoryId = categoryId,
                          page = currentPage })
                end)

            -- Qty label
            W.createLabel(parent, rx + btnMinus + gap, ry + itemY + 2,
                tostring(qty), C.text)

            -- [+] button
            W.createButton(parent, rx + btnMinus + lblQtyW + (gap * 2),
                ry + itemY, btnPlus, ctx.btnH,
                "+", nil,
                function()
                    _quantities[ft] = math.min((_quantities[ft] or 1) + 1, maxQty)
                    POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_TRADE_CATALOG,
                        { wholesalerId = wsId, mode = mode, categoryId = categoryId,
                          page = currentPage })
                end)

            -- Determine if confirm button should be disabled
            local totalCost = unitPrice * qty
            local disabled = false
            if mode == "buy" then
                disabled = balance < totalCost
            else
                local owned = item.ownedCount or 0
                disabled = owned < qty
            end

            -- Confirm button label with total
            local confirmLabel
            if mode == "buy" then
                confirmLabel = W.safeGetText("UI_POS_Trade_BuyTotal")
                    :gsub("%%1", string.format("%.2f", totalCost))
            else
                confirmLabel = W.safeGetText("UI_POS_Trade_SellTotal")
                    :gsub("%%1", string.format("%.2f", totalCost))
            end

            local confirmColour = disabled and C.dim or nil
            local confirmCb = nil
            if not disabled then
                confirmCb = function()
                    local p = getSpecificPlayer(0)
                    if not p then return end
                    local success, receipt
                    if mode == "buy" then
                        success, receipt = POS_TradeService.executeBuy(
                            p, wsId, ft, qty)
                    else
                        success, receipt = POS_TradeService.executeSell(
                            p, wsId, ft, qty)
                    end
                    if success then
                        receipt.mode = mode
                        POS_ScreenManager.navigateTo(
                            POS_Constants.SCREEN_TRADE_RECEIPT,
                            { receipt = receipt })
                    end
                    -- On failure, TradeService already notifies via PN
                end
            end

            W.createButton(parent, confirmX, ry + itemY, confirmW, ctx.btnH,
                confirmLabel, confirmColour, confirmCb)
            itemY = itemY + ctx.btnH + 4

            -- Bulk discount hint
            local bulkThreshold = POS_Constants.TRADE_BULK_THRESHOLD_DEFAULT
            if qty >= bulkThreshold then
                W.createLabel(parent, rx + 8, ry + itemY,
                    W.safeGetText("UI_POS_Trade_BulkDiscount"), C.success)
                itemY = itemY + ctx.lineH
            end

            return itemY
        end,
        onPageChange = function(newPage)
            _quantities = {}
            POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_TRADE_CATALOG,
                { wholesalerId = wsId, mode = mode, categoryId = categoryId, page = newPage })
        end,
    })
end

---------------------------------------------------------------
-- Screen create
---------------------------------------------------------------

function screen.create(contentPanel, params, _terminal)
    _quantities = {}
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    local wsId = params and params.wholesalerId
    if not wsId then
        W.drawHeader(ctx, "UI_POS_Trade_CatalogTitle")
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Trade_NoItems"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- Resolve wholesaler data
    local wholesalers = POS_WorldState.getWholesalers()
    local wholesaler = wholesalers and wholesalers[wsId]
    if not wholesaler then
        W.drawHeader(ctx, "UI_POS_Trade_CatalogTitle")
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Trade_NoItems"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    local mode = (params and params.mode) or "buy"
    local categoryId = params and params.categoryId

    -- Header: wholesaler name
    local nameKey = wholesaler.nameKey or wholesaler.displayNameKey
    local headerName = nameKey and W.safeGetText(nameKey) or (wholesaler.name or wsId)
    W.drawHeader(ctx, "UI_POS_Trade_CatalogTitle")
    W.createLabel(ctx.panel, 8, ctx.y, headerName, C.textBright)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Player balance
    local player = getSpecificPlayer(0)
    local balance = 0
    if POS_TradeService and POS_TradeService.getPlayerBalance and player then
        balance = POS_TradeService.getPlayerBalance(player) or 0
    end
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Trade_YourBalance") .. ": $"
        .. string.format("%.2f", balance), C.text)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Mode toggle buttons: BUY / SELL
    local halfW = math.floor((ctx.btnW - 4) / 2)
    local buyColour = mode == "buy" and C.success or C.dim
    local sellColour = mode == "sell" and C.success or C.dim

    local buyBtn = W.createButton(ctx.panel, ctx.btnX, ctx.y, halfW, ctx.btnH,
        W.safeGetText("UI_POS_Trade_ModeBuy"), nil,
        function()
            _quantities = {}
            POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_TRADE_CATALOG,
                { wholesalerId = wsId, mode = "buy", categoryId = categoryId })
        end)
    buyBtn.textColor = { r = buyColour.r, g = buyColour.g, b = buyColour.b, a = buyColour.a }

    local sellBtn = W.createButton(ctx.panel, ctx.btnX + halfW + 4, ctx.y, halfW, ctx.btnH,
        W.safeGetText("UI_POS_Trade_ModeSell"), nil,
        function()
            _quantities = {}
            POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_TRADE_CATALOG,
                { wholesalerId = wsId, mode = "sell", categoryId = categoryId })
        end)
    sellBtn.textColor = { r = sellColour.r, g = sellColour.g, b = sellColour.b, a = sellColour.a }

    ctx.y = ctx.y + ctx.btnH + 4
    W.createSeparator(ctx.panel, 0, ctx.y, nil, "-")
    ctx.y = ctx.y + ctx.lineH + 4

    -- Content: category browser or item list
    if not categoryId then
        renderCategoryBrowser(ctx, W, C, wholesaler, wsId, mode)
    else
        renderItemList(ctx, W, C, params, player, balance)
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.getContextData = function(params)
    local data = {}
    if params and params.wholesalerId then
        table.insert(data, { type = "kv", key = "UI_POS_Trade_Wholesaler",
            value = params.wholesalerId })
    end
    return data
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
