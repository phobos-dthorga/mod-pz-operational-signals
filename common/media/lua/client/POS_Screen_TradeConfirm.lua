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
-- POS_Screen_TradeConfirm.lua
-- Trade confirmation screen. Shows item details, quantity
-- adjustment, price breakdown, and confirm/cancel buttons.
-- All business logic delegated to POS_TradeService.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_TRADE_CONFIRM
screen.menuPath = {"pos.markets.trade.catalog"}
screen.titleKey = "UI_POS_Trade_ConfirmTitle"

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    local wsId = params and params.wholesalerId
    local fullType = params and params.fullType
    local mode = (params and params.mode) or "buy"
    local quantity = (params and params.quantity) or 1

    -- Validate required params
    if not wsId or not fullType then
        W.drawHeader(ctx, "UI_POS_Trade_ConfirmTitle")
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Trade_NoItems"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    W.drawHeader(ctx, "UI_POS_Trade_ConfirmTitle")

    -- Fetch item details from service (nil-safe)
    local itemInfo
    if POS_TradeService and POS_TradeService.getItemInfo then
        itemInfo = POS_TradeService.getItemInfo(wsId, fullType, mode)
    end

    local displayName = (itemInfo and itemInfo.displayName) or fullType
    local unitPrice = (itemInfo and (itemInfo.buyPrice or itemInfo.sellPrice or itemInfo.price)) or 0
    local maxQty = POS_Constants.TRADE_MAX_QUANTITY_PER_TX

    -- For sells, cap at player owned count
    local player = getSpecificPlayer(0)
    if mode == "sell" and itemInfo and itemInfo.ownedCount then
        maxQty = math.min(maxQty, itemInfo.ownedCount)
    end

    -- Clamp quantity
    quantity = math.max(1, math.min(quantity, maxQty))

    -- Bulk discount (if applicable)
    local bulkDiscount = 0
    if POS_TradeService and POS_TradeService.getBulkDiscount then
        bulkDiscount = POS_TradeService.getBulkDiscount(wsId, fullType, quantity, mode) or 0
    end

    local totalBeforeDiscount = unitPrice * quantity
    local discountAmount = totalBeforeDiscount * bulkDiscount
    local totalCost = totalBeforeDiscount - discountAmount

    -- Player balance
    local balance = 0
    if POS_TradeService and POS_TradeService.getPlayerBalance and player then
        balance = POS_TradeService.getPlayerBalance(player) or 0
    end
    local balanceAfter
    if mode == "buy" then
        balanceAfter = balance - totalCost
    else
        balanceAfter = balance + totalCost
    end

    -- Mode label
    local modeKey = mode == "buy" and "UI_POS_Trade_ModeBuy" or "UI_POS_Trade_ModeSell"
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText(modeKey), C.textBright)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Item name
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Trade_Item") .. ": " .. displayName, C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Quantity
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Trade_Quantity") .. ": " .. tostring(quantity), C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Unit price
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Trade_UnitPrice") .. ": $"
        .. string.format("%.2f", unitPrice), C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Bulk discount line (if applicable)
    if bulkDiscount > 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Trade_BulkDiscount") .. ": -$"
            .. string.format("%.2f", discountAmount)
            .. " (" .. string.format("%.0f%%", bulkDiscount * 100) .. ")", C.success)
        ctx.y = ctx.y + ctx.lineH
    end

    -- Total cost/revenue
    local totalKey = mode == "buy" and "UI_POS_Trade_TotalCost" or "UI_POS_Trade_TotalRevenue"
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText(totalKey) .. ": $"
        .. string.format("%.2f", totalCost), C.textBright)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, nil, "-")
    ctx.y = ctx.y + ctx.lineH + 4

    -- Current balance
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Trade_YourBalance") .. ": $"
        .. string.format("%.2f", balance), C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Balance after trade
    local afterColour = balanceAfter >= 0 and C.text or C.error
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Trade_BalanceAfter") .. ": $"
        .. string.format("%.2f", balanceAfter), afterColour)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, nil, "-")
    ctx.y = ctx.y + ctx.lineH + 4

    -- Quantity adjustment: [-] [+] buttons
    local thirdW = math.floor((ctx.btnW - 8) / 3)
    W.createButton(ctx.panel, ctx.btnX, ctx.y, thirdW, ctx.btnH,
        "[-]", nil,
        function()
            local newQty = math.max(1, quantity - 1)
            POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_TRADE_CONFIRM,
                { wholesalerId = wsId, fullType = fullType,
                  quantity = newQty, mode = mode })
        end)

    W.createLabel(ctx.panel, ctx.btnX + thirdW + 4, ctx.y + 4,
        W.safeGetText("UI_POS_Trade_Quantity") .. ": " .. tostring(quantity), C.text)

    W.createButton(ctx.panel, ctx.btnX + thirdW * 2 + 8, ctx.y, thirdW, ctx.btnH,
        "[+]", nil,
        function()
            local newQty = math.min(maxQty, quantity + 1)
            POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_TRADE_CONFIRM,
                { wholesalerId = wsId, fullType = fullType,
                  quantity = newQty, mode = mode })
        end)
    ctx.y = ctx.y + ctx.btnH + 4

    -- Error label placeholder (hidden by default)
    local errorLabel = W.createLabel(ctx.panel, 8, ctx.y, "", C.error)
    errorLabel:setVisible(false)
    local errorY = ctx.y
    ctx.y = ctx.y + ctx.lineH + 4

    -- Confirm button
    local canAfford = mode == "buy" and balanceAfter >= 0
    local canSell = mode == "sell" and maxQty >= quantity
    local canConfirm = (mode == "buy" and canAfford) or (mode == "sell" and canSell)

    if canConfirm then
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            W.safeGetText("UI_POS_Trade_Confirm"), nil,
            function()
                local p = getSpecificPlayer(0)
                if not p then return end
                local receipt, err
                if mode == "buy" then
                    if POS_TradeService and POS_TradeService.executeBuy then
                        receipt, err = POS_TradeService.executeBuy(wsId, fullType, quantity, p)
                    end
                else
                    if POS_TradeService and POS_TradeService.executeSell then
                        receipt, err = POS_TradeService.executeSell(wsId, fullType, quantity, p)
                    end
                end

                if receipt then
                    POS_ScreenManager.navigateTo(POS_Constants.SCREEN_TRADE_RECEIPT,
                        { receipt = receipt })
                else
                    errorLabel:setName(err or W.safeGetText("UI_POS_Trade_Error"))
                    errorLabel:setVisible(true)
                end
            end)
    else
        W.createDisabledButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            W.safeGetText("UI_POS_Trade_Confirm"))
    end
    ctx.y = ctx.y + ctx.btnH + 4

    -- Cancel button
    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        W.safeGetText("UI_POS_Trade_Cancel"), nil,
        function()
            POS_ScreenManager.goBack()
        end)
    ctx.y = ctx.y + ctx.btnH + 4
end

screen.getContextData = function(params)
    local data = {}
    if params and params.fullType then
        table.insert(data, { type = "kv", key = "UI_POS_Trade_Item",
            value = params.fullType })
    end
    return data
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
