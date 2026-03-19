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
-- POS_Screen_Negotiate.lua
-- Negotiation screen — lets the player haggle mission terms
-- (reward, deadline) before accepting. Success chance is
-- reputation-weighted.
--
-- Navigation flow:
--   Operations/Deliveries → select mission → NEGOTIATE → accept/decline
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_NegotiationService"
require "POS_RewardCalculator"
require "POS_MapMarkers"
require "POS_OperationLog"
require "PhobosLib_Address"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_NEGOTIATE
screen.menuPath = {}  -- navigated programmatically, not in any menu
screen.titleKey = "UI_POS_Negotiate_Header"

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    local opId = params and params.operationId
    if not opId then
        W.createLabel(ctx.panel, 0, ctx.y, "ERROR: No operation specified.", C.error)
        return
    end

    local op = POS_OperationLog.get(opId)
    if not op then
        W.createLabel(ctx.panel, 0, ctx.y, "ERROR: Operation not found.", C.error)
        return
    end

    local player = getSpecificPlayer(0)
    local obj = op.objectives and op.objectives[1]
    local isDelivery = obj and obj.type == POS_Constants.OBJECTIVE_TYPE_DELIVERY

    -- Initialise negotiation state via service
    POS_NegotiationService.initNegotiation(op)

    local attemptsLeft = POS_NegotiationService.getAttemptsLeft(op)
    local chance = POS_NegotiationService.getSuccessChance(player)
    local lastResult = params and params.lastResult

    -- Header
    W.drawHeader(ctx, "UI_POS_Negotiate_Header")

    -- Mission details
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText(op.nameKey or "???"), C.text)
    ctx.y = ctx.y + ctx.lineH

    if obj then
        local targetStr
        if isDelivery then
            local locStr = "???"
            if PhobosLib_Address and PhobosLib_Address.resolveAddress then
                local addr = PhobosLib_Address.resolveAddress(obj.pickupX or 0, obj.pickupY or 0)
                if addr and addr.street then
                    locStr = PhobosLib_Address.formatAddress(addr)
                else
                    locStr = math.floor(obj.pickupX or 0) .. ", " .. math.floor(obj.pickupY or 0)
                end
            else
                locStr = math.floor(obj.pickupX or 0) .. ", " .. math.floor(obj.pickupY or 0)
            end
            targetStr = W.safeGetText("UI_POS_Delivery_Pickup") .. ": " .. locStr
        else
            local locStr = "???"
            if PhobosLib_Address and PhobosLib_Address.resolveAddress then
                local addr = PhobosLib_Address.resolveAddress(obj.targetBuildingX or 0, obj.targetBuildingY or 0)
                if addr and addr.street then
                    locStr = PhobosLib_Address.formatAddress(addr)
                else
                    locStr = math.floor(obj.targetBuildingX or 0) .. ", " .. math.floor(obj.targetBuildingY or 0)
                end
            else
                locStr = math.floor(obj.targetBuildingX or 0) .. ", " .. math.floor(obj.targetBuildingY or 0)
            end
            targetStr = W.safeGetText("UI_POS_Ops_Target") .. ": " .. locStr
        end
        W.createLabel(ctx.panel, 8, ctx.y, "  " .. targetStr, C.dim)
        ctx.y = ctx.y + ctx.lineH
    end

    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Current offer
    W.createLabel(ctx.panel, 0, ctx.y,
        W.safeGetText("UI_POS_Negotiate_CurrentOffer"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    local reward = isDelivery and (op.estimatedReward or 0) or (op.scaledReward or 0)
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Delivery_Reward") .. ": $" .. reward, C.warn)
    ctx.y = ctx.y + ctx.lineH

    if op.expiryDay then
        local gameTime = getGameTime()
        local currentDay = gameTime and gameTime:getNightsSurvived() or 0
        local daysLeft = (op.expiryDay or 0) - currentDay
        if daysLeft < 0 then daysLeft = 0 end
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Delivery_ExpiresIn", tostring(daysLeft)), C.dim)
        ctx.y = ctx.y + ctx.lineH
    end

    if not isDelivery and op.baseReputation then
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Ops_Reputation") .. ": +"
            .. POS_RewardCalculator.scaleReputation(op.baseReputation), C.dim)
        ctx.y = ctx.y + ctx.lineH
    end

    -- Negotiation status
    ctx.y = ctx.y + 4
    W.createLabel(ctx.panel, 0, ctx.y,
        W.safeGetText("UI_POS_Negotiate_AttemptsLeft", tostring(attemptsLeft))
        .. "  (" .. chance .. "%)", C.dim)
    ctx.y = ctx.y + ctx.lineH

    -- Last result feedback
    if lastResult == "success" then
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Negotiate_Success"), C.textBright)
        ctx.y = ctx.y + ctx.lineH
    elseif lastResult == "failed" then
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Negotiate_Failed"), C.error)
        ctx.y = ctx.y + ctx.lineH
    end

    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH + 4

    -- Negotiation buttons (if attempts remain)
    if attemptsLeft > 0 then
        -- [1] Request higher pay
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[1] " .. W.safeGetText("UI_POS_Negotiate_HigherPay"), nil,
            function()
                local _, result = POS_NegotiationService.attemptHigherPay(op, player)
                POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_NEGOTIATE,
                    { operationId = opId, lastResult = result })
            end)
        ctx.y = ctx.y + ctx.btnH + 4

        -- [2] Request more time
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[2] " .. W.safeGetText("UI_POS_Negotiate_MoreTime"), nil,
            function()
                local _, result = POS_NegotiationService.attemptMoreTime(op, player)
                POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_NEGOTIATE,
                    { operationId = opId, lastResult = result })
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    else
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Negotiate_MaxAttempts"), C.warn)
        ctx.y = ctx.y + ctx.lineH + 4
    end

    -- [3] Accept current terms
    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        "[3] " .. W.safeGetText("UI_POS_Negotiate_Accept"), nil,
        function()
            POS_NegotiationService.acceptOperation(op)
            -- Place waypoint for recon
            if not isDelivery and POS_MapMarkers then
                POS_MapMarkers.placeMarker(op)
            end
            POS_ScreenManager.markDirty()
            POS_ScreenManager.goBack()
        end)
    ctx.y = ctx.y + ctx.btnH + 4

    -- Footer separator + [0] Decline
    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH + 4

    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        "[0] " .. W.safeGetText("UI_POS_Negotiate_Decline"), nil,
        function() POS_ScreenManager.goBack() end)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(_params)
    POS_TerminalWidgets.dynamicRefresh(screen, _params)
end

screen.getContextData = function(params)
    local data = {}
    if not params then return data end
    table.insert(data, { type = "header", text = "UI_POS_Context_Negotiation" })
    if params.operationId then
        local op = POS_OperationLog and POS_OperationLog.get
            and POS_OperationLog.get(params.operationId)
        if op and op.negotiationAttempts then
            table.insert(data, { type = "kv", key = "UI_POS_Context_Attempts",
                value = tostring(op.negotiationAttempts) .. "/"
                    .. tostring(POS_Constants.NEGOTIATE_MAX_ATTEMPTS) })
        end
    end
    -- Negotiation chance calculation via service
    local player = getSpecificPlayer(0)
    if player and POS_NegotiationService then
        local finalChance = POS_NegotiationService.getSuccessChance(player)
        table.insert(data, { type = "separator" })
        table.insert(data, { type = "kv", key = "UI_POS_Context_Chance",
            value = tostring(finalChance) .. "%",
            colour = finalChance >= 60 and "success" or finalChance >= 40 and "warn" or "error" })
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
