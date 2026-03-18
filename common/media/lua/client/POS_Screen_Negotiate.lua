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
require "POS_Reputation"
require "POS_RewardCalculator"
require "POS_MapMarkers"
require "POS_OperationLog"
require "PhobosLib_Address"

local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

---------------------------------------------------------------
-- Negotiation mechanics
---------------------------------------------------------------

local MAX_ATTEMPTS = 3

--- Base success chance by reputation tier (1-5).
local TIER_SUCCESS_CHANCE = {
    [1] = 30,   -- Untrusted
    [2] = 50,   -- Known
    [3] = 70,   -- Trusted
    [4] = 85,   -- Established
    [5] = 85,   -- Legendary (same as IV)
}

--- Calculate the success chance for a negotiation attempt.
---@param player any IsoPlayer
---@return number Chance as 0-100
local function getSuccessChance(player)
    local tier = POS_Reputation.getTier(player)
    local base = TIER_SUCCESS_CHANCE[tier] or 30
    local bonus = POS_Sandbox and POS_Sandbox.getNegotiationSuccessBonus
        and POS_Sandbox.getNegotiationSuccessBonus() or 0
    return math.max(0, math.min(100, base + bonus))
end

--- Roll for negotiation success.
---@param chance number 0-100
---@return boolean
local function rollSuccess(chance)
    return ZombRand(100) < chance
end

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_NEGOTIATE

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = POS_TerminalWidgets.COLOURS
    local pw = contentPanel:getWidth()
    local y = 0
    local lineH = 20
    local btnH = 28
    local btnW = pw - 10
    local btnX = 5

    local opId = params and params.operationId
    if not opId then
        W.createLabel(contentPanel, 0, y, "ERROR: No operation specified.", C.error)
        return
    end

    local op = POS_OperationLog.get(opId)
    if not op then
        W.createLabel(contentPanel, 0, y, "ERROR: Operation not found.", C.error)
        return
    end

    local player = getSpecificPlayer(0)
    local obj = op.objectives and op.objectives[1]
    local isDelivery = obj and obj.type == "delivery"

    -- Track negotiation state on the operation table
    op.negotiationAttempts = op.negotiationAttempts or 0
    if not op.originalReward then
        if isDelivery then
            op.originalReward = op.estimatedReward
        else
            op.originalReward = op.scaledReward
        end
    end
    if not op.originalExpiryDay then
        op.originalExpiryDay = op.expiryDay
    end

    local attemptsLeft = MAX_ATTEMPTS - op.negotiationAttempts
    local chance = getSuccessChance(player)
    local lastResult = params and params.lastResult

    -- Header
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_Negotiate_Header"), C.textBright)
    y = y + lineH

    W.createSeparator(contentPanel, 0, y, 40)
    y = y + lineH

    -- Mission details
    W.createLabel(contentPanel, 8, y,
        safeGetText(op.nameKey or "???"), C.text)
    y = y + lineH

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
            targetStr = safeGetText("UI_POS_Delivery_Pickup") .. ": " .. locStr
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
            targetStr = safeGetText("UI_POS_Ops_Target") .. ": " .. locStr
        end
        W.createLabel(contentPanel, 8, y, "  " .. targetStr, C.dim)
        y = y + lineH
    end

    y = y + 4
    W.createSeparator(contentPanel, 0, y, 40, "-")
    y = y + lineH

    -- Current offer
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_Negotiate_CurrentOffer"), C.textBright)
    y = y + lineH

    local reward = isDelivery and (op.estimatedReward or 0) or (op.scaledReward or 0)
    W.createLabel(contentPanel, 8, y,
        "  " .. safeGetText("UI_POS_Delivery_Reward") .. ": $" .. reward, C.warn)
    y = y + lineH

    if op.expiryDay then
        local gameTime = getGameTime()
        local currentDay = gameTime and gameTime:getNightsSurvived() or 0
        local daysLeft = (op.expiryDay or 0) - currentDay
        if daysLeft < 0 then daysLeft = 0 end
        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Delivery_ExpiresIn", tostring(daysLeft)), C.dim)
        y = y + lineH
    end

    if not isDelivery and op.baseReputation then
        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Ops_Reputation") .. ": +"
            .. POS_RewardCalculator.scaleReputation(op.baseReputation), C.dim)
        y = y + lineH
    end

    -- Negotiation status
    y = y + 4
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_Negotiate_AttemptsLeft", tostring(attemptsLeft))
        .. "  (" .. chance .. "%)", C.dim)
    y = y + lineH

    -- Last result feedback
    if lastResult == "success" then
        W.createLabel(contentPanel, 0, y,
            safeGetText("UI_POS_Negotiate_Success"), C.textBright)
        y = y + lineH
    elseif lastResult == "failed" then
        W.createLabel(contentPanel, 0, y,
            safeGetText("UI_POS_Negotiate_Failed"), C.error)
        y = y + lineH
    end

    y = y + 4
    W.createSeparator(contentPanel, 0, y, 40, "-")
    y = y + lineH + 4

    -- Negotiation buttons (if attempts remain)
    if attemptsLeft > 0 then
        -- [1] Request higher pay
        W.createButton(contentPanel, btnX, y, btnW, btnH,
            "[1] " .. safeGetText("UI_POS_Negotiate_HigherPay"), nil,
            function()
                op.negotiationAttempts = op.negotiationAttempts + 1
                if rollSuccess(chance) then
                    -- +20% reward, -1 day deadline
                    local bonus = math.floor(reward * 0.20)
                    if isDelivery then
                        op.estimatedReward = (op.estimatedReward or 0) + bonus
                    else
                        op.scaledReward = (op.scaledReward or 0) + bonus
                    end
                    if op.expiryDay then
                        op.expiryDay = op.expiryDay - 1
                    end
                    op.negotiated = true
                    POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_NEGOTIATE,
                        { operationId = opId, lastResult = "success" })
                else
                    POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_NEGOTIATE,
                        { operationId = opId, lastResult = "failed" })
                end
            end)
        y = y + btnH + 4

        -- [2] Request more time
        W.createButton(contentPanel, btnX, y, btnW, btnH,
            "[2] " .. safeGetText("UI_POS_Negotiate_MoreTime"), nil,
            function()
                op.negotiationAttempts = op.negotiationAttempts + 1
                if rollSuccess(chance) then
                    -- +2 days, -15% reward
                    local cut = math.floor(reward * 0.15)
                    if isDelivery then
                        op.estimatedReward = math.max(0, (op.estimatedReward or 0) - cut)
                    else
                        op.scaledReward = math.max(0, (op.scaledReward or 0) - cut)
                    end
                    if op.expiryDay then
                        op.expiryDay = op.expiryDay + 2
                    end
                    op.negotiated = true
                    POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_NEGOTIATE,
                        { operationId = opId, lastResult = "success" })
                else
                    POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_NEGOTIATE,
                        { operationId = opId, lastResult = "failed" })
                end
            end)
        y = y + btnH + 4
    else
        W.createLabel(contentPanel, 0, y,
            safeGetText("UI_POS_Negotiate_MaxAttempts"), C.warn)
        y = y + lineH + 4
    end

    -- [3] Accept current terms
    W.createButton(contentPanel, btnX, y, btnW, btnH,
        "[3] " .. safeGetText("UI_POS_Negotiate_Accept"), nil,
        function()
            op.status = "active"
            -- Place waypoint for recon
            if not isDelivery and POS_MapMarkers then
                POS_MapMarkers.placeMarker(op)
            end
            POS_ScreenManager.markDirty()
            POS_ScreenManager.goBack()
        end)
    y = y + btnH + 4

    -- [0] Decline
    W.createButton(contentPanel, btnX, y, btnW, btnH,
        "[0] " .. safeGetText("UI_POS_Negotiate_Decline"), nil,
        function() POS_ScreenManager.goBack() end)
end

function screen.destroy()
    if POS_TerminalUI and POS_TerminalUI.instance
       and POS_TerminalUI.instance.contentPanel then
        POS_TerminalWidgets.clearPanel(POS_TerminalUI.instance.contentPanel)
    end
end

function screen.refresh(_params)
    -- Stateful screen — no auto-refresh
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
