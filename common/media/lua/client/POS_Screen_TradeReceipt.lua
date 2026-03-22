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
-- POS_Screen_TradeReceipt.lua
-- Trade receipt screen. Shows a summary of a completed
-- buy/sell transaction with navigation options.
-- Presentation only — no business logic.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_TRADE_RECEIPT
screen.menuPath = {"pos.markets.trade.confirm"}
screen.titleKey = "UI_POS_Trade_Receipt_Title"

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    local receipt = params and params.receipt

    W.drawHeader(ctx, "UI_POS_Trade_Receipt_Title")

    if not receipt then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Trade_NoReceipt"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- Transaction type label
    local isBuy = receipt.mode == "buy"
    local txLabel = isBuy
        and W.safeGetText("UI_POS_Trade_Receipt_Purchased")
        or W.safeGetText("UI_POS_Trade_Receipt_Sold")

    local displayName = receipt.displayName or receipt.fullType or "???"
    local quantity = receipt.quantity or 0
    local totalCost = receipt.totalCost or 0

    -- "Purchased/Sold Nx ItemName for $Total"
    W.createLabel(ctx.panel, 8, ctx.y,
        txLabel .. " " .. tostring(quantity) .. "x " .. displayName, C.textBright)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Trade_Receipt_Total") .. ": $"
        .. string.format("%.2f", totalCost), C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Discount line (if applicable)
    if receipt.discountAmount and receipt.discountAmount > 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Trade_BulkDiscount") .. ": -$"
            .. string.format("%.2f", receipt.discountAmount), C.success)
        ctx.y = ctx.y + ctx.lineH
    end

    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, nil, "-")
    ctx.y = ctx.y + ctx.lineH + 4

    -- New balance
    local newBalance = receipt.newBalance or 0
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Trade_Receipt_NewBalance") .. ": $"
        .. string.format("%.2f", newBalance), C.textBright)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, nil, "-")
    ctx.y = ctx.y + ctx.lineH + 4

    -- Navigation buttons
    local wsId = receipt.wholesalerId
    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        "[1] " .. W.safeGetText("UI_POS_Trade_BackToCatalog"), nil,
        function()
            POS_ScreenManager.navigateTo(POS_Constants.SCREEN_TRADE_CATALOG,
                { wholesalerId = wsId })
        end)
    ctx.y = ctx.y + ctx.btnH + 4

    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        "[2] " .. W.safeGetText("UI_POS_Trade_BackToTerminal"), nil,
        function()
            POS_ScreenManager.navigateTo(POS_Constants.SCREEN_TRADE_TERMINAL, {})
        end)
    ctx.y = ctx.y + ctx.btnH + 4
end

screen.getContextData = function(params)
    local data = {}
    if params and params.receipt then
        local r = params.receipt
        local desc = (r.displayName or r.fullType or "")
            .. " x" .. tostring(r.quantity or 0)
        table.insert(data, { type = "kv", key = "UI_POS_Trade_Receipt_Title",
            value = desc })
    end
    return data
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
