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
-- POS_Screen_Deliveries.lua
-- Terminal screen for the POSnet Courier Service.
-- Shows available delivery missions, active delivery status,
-- and recent completed deliveries.
-- Widget-based: uses ISButton/ISLabel children in contentPanel.
---------------------------------------------------------------

require "PhobosLib"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_PathTracker"

local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

local C = POS_TerminalWidgets.COLOURS
local BBS_GOOD = { r = 0.20, g = 0.90, b = 0.50, a = 1.0 }

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Find the active delivery from the operation log.
local function getActiveDelivery()
    if not POS_OperationLog then return nil end
    local ops = POS_OperationLog.getByStatus("active")
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == "delivery" then
            return op
        end
    end
    return nil
end

--- Find completed deliveries from the operation log.
local function getCompletedDeliveries()
    if not POS_OperationLog then return {} end
    local results = {}
    local ops = POS_OperationLog.getByStatus("completed")
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == "delivery" then
            table.insert(results, op)
        end
    end
    return results
end

--- Get available (not yet accepted) deliveries.
local function getAvailableDeliveries()
    if not POS_OperationLog then return {} end
    local results = {}
    local ops = POS_OperationLog.getByStatus("available")
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == "delivery" then
            table.insert(results, op)
        end
    end
    return results
end

---------------------------------------------------------------

local screen = {}
screen.id = "DELIVERIES"

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local pw = contentPanel:getWidth()
    local y = 0
    local lineH = 20
    local btnH = 28
    local btnW = pw - 10
    local btnX = 5

    -- Header
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_Delivery_Header"), C.textBright)
    y = y + lineH

    W.createSeparator(contentPanel, 0, y, 40)
    y = y + lineH

    -- ── Active delivery ──
    local active = getActiveDelivery()

    if active then
        W.createLabel(contentPanel, 0, y,
            safeGetText("UI_POS_Delivery_Active"), C.textBright)
        y = y + lineH

        W.createSeparator(contentPanel, 0, y, 40, "-")
        y = y + lineH

        local obj = active.objectives[1]

        -- Status
        local status
        if not obj.pickedUp then
            status = safeGetText("UI_POS_Delivery_Status_AwaitingPickup")
        else
            status = safeGetText("UI_POS_Delivery_Status_InTransit")
        end
        W.createLabel(contentPanel, 8, y, "  Status: " .. status, C.text)
        y = y + lineH

        -- Item
        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Delivery_Item") .. ": "
            .. (obj.itemType or "???"), C.text)
        y = y + lineH

        -- Pickup location
        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Delivery_Pickup") .. ": "
            .. math.floor(obj.pickupX) .. ", " .. math.floor(obj.pickupY), C.text)
        y = y + lineH

        -- Dropoff location
        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Delivery_Dropoff") .. ": "
            .. math.floor(obj.dropoffX) .. ", " .. math.floor(obj.dropoffY), C.text)
        y = y + lineH

        -- Straight-line distance
        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Delivery_Distance") .. ": "
            .. math.floor(active.straightLineDistance or 0) .. " "
            .. safeGetText("UI_POS_Delivery_Tiles"), C.dim)
        y = y + lineH

        -- Distance walked/driven so far
        if obj.pickedUp then
            local walked = POS_PathTracker.getDistance(active.id)
            W.createLabel(contentPanel, 8, y,
                "  " .. safeGetText("UI_POS_Delivery_DistanceWalked") .. ": "
                .. math.floor(walked) .. " "
                .. safeGetText("UI_POS_Delivery_Tiles"), C.dim)
            y = y + lineH
        end

        -- Estimated reward
        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Delivery_Reward") .. ": ~$"
            .. (active.estimatedReward or "???"), C.warn)
        y = y + lineH

        y = y + 4
    else
        -- ── Available deliveries ──
        W.createLabel(contentPanel, 0, y,
            safeGetText("UI_POS_Delivery_Available"), C.textBright)
        y = y + lineH

        W.createSeparator(contentPanel, 0, y, 40, "-")
        y = y + lineH

        local available = getAvailableDeliveries()

        if #available == 0 then
            W.createLabel(contentPanel, 8, y,
                safeGetText("UI_POS_Delivery_NoAvailable"), C.dim)
            y = y + lineH
        else
            for i, op in ipairs(available) do
                local obj = op.objectives[1]
                local label = "[" .. i .. "] "
                    .. (obj.itemType or "Package")
                    .. " — ~" .. math.floor(op.estimatedRoadDistance or 0) .. " "
                    .. safeGetText("UI_POS_Delivery_Tiles")
                    .. " — ~$" .. (op.estimatedReward or "???")

                local opId = op.id
                W.createButton(contentPanel, btnX, y, btnW, btnH, label, nil,
                    function()
                        -- Accept delivery: change status to active
                        if POS_OperationLog and POS_OperationLog.get then
                            local operation = POS_OperationLog.get(opId)
                            if operation then
                                operation.status = "active"
                                POS_ScreenManager.markDirty()
                            end
                        end
                    end)
                y = y + btnH + 4
            end
        end
    end

    -- ── Completed deliveries ──
    local completed = getCompletedDeliveries()
    if #completed > 0 then
        y = y + 4
        W.createLabel(contentPanel, 0, y,
            safeGetText("UI_POS_Delivery_Recent"), C.textBright)
        y = y + lineH

        W.createSeparator(contentPanel, 0, y, 40, "-")
        y = y + lineH

        local shown = 0
        for i = #completed, 1, -1 do
            if shown >= 5 then break end
            local op = completed[i]
            local reward = op.finalReward or op.estimatedReward or 0
            local dist = op.actualDistance or op.straightLineDistance or 0
            local line = "  [OK] $" .. reward
                .. " — " .. math.floor(dist) .. " "
                .. safeGetText("UI_POS_Delivery_Tiles")
            W.createLabel(contentPanel, 0, y, line, BBS_GOOD)
            y = y + lineH
            shown = shown + 1
        end
    end

    -- Footer
    y = y + 4
    W.createSeparator(contentPanel, 0, y, 40, "-")
    y = y + lineH + 4

    W.createButton(contentPanel, btnX, y, btnW, btnH,
        "[0] " .. safeGetText("UI_POS_BackPrompt"), nil,
        function() POS_ScreenManager.goBack() end)
end

function screen.destroy()
    if POS_TerminalUI.instance and POS_TerminalUI.instance.contentPanel then
        POS_TerminalWidgets.clearPanel(POS_TerminalUI.instance.contentPanel)
    end
end

function screen.refresh(params)
    -- Dynamic data — full rebuild
    local terminal = POS_TerminalUI.instance
    if terminal and terminal.contentPanel then
        screen.destroy()
        screen.create(terminal.contentPanel, params, terminal)
    end
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
