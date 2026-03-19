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
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_PathTracker"
require "POS_DeliveryGenerator"
require "POS_RewardCalculator"
require "POS_OperationLog"
require "POS_OperationService"
require "PhobosLib_Pagination"
require "PhobosLib_Address"
require "POS_API"

local C = POS_TerminalWidgets.COLOURS

local function formatLocation(x, y)
    if PhobosLib_Address and PhobosLib_Address.resolveAddress then
        local addr = PhobosLib_Address.resolveAddress(x, y)
        if addr and addr.street then
            return PhobosLib_Address.formatAddress(addr)
        end
    end
    return math.floor(x) .. ", " .. math.floor(y)
end

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Find the active delivery from the operation log.
local function getActiveDelivery()
    if not POS_OperationLog then return nil end
    local ops = POS_OperationLog.getByStatus(POS_Constants.STATUS_ACTIVE)
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == POS_Constants.OBJECTIVE_TYPE_DELIVERY then
            return op
        end
    end
    return nil
end

--- Find completed deliveries from the operation log.
local function getCompletedDeliveries()
    if not POS_OperationLog then return {} end
    local results = {}
    local ops = POS_OperationLog.getByStatus(POS_Constants.STATUS_COMPLETED)
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == POS_Constants.OBJECTIVE_TYPE_DELIVERY then
            table.insert(results, op)
        end
    end
    return results
end

--- Get available (not yet accepted) deliveries.
--- If none exist, attempts to generate one on-demand by scanning
--- for mailbox pairs near the player.
local function getAvailableDeliveries()
    if not POS_OperationLog then return {} end

    local results = {}
    local ops = POS_OperationLog.getByStatus(POS_Constants.STATUS_AVAILABLE)
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == POS_Constants.OBJECTIVE_TYPE_DELIVERY then
            table.insert(results, op)
        end
    end

    -- On-demand generation: if no available deliveries, try to create one
    if #results == 0 and POS_Sandbox.isDeliveryEnabled() then
        local player = getSpecificPlayer(0)
        if player then
            local delivery = POS_DeliveryGenerator.generate(player)
            if delivery then
                POS_OperationLog.addOperation(delivery)
                table.insert(results, delivery)
                PhobosLib.debug("POS",
                    "[Deliveries] Generated on-demand delivery: " .. delivery.id)
            end
        end
    end

    return results
end

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_DELIVERIES
screen.menuPath = {"pos.bbs"}
screen.titleKey = "UI_POS_Delivery_Header"
screen.sortOrder = 30
screen.shouldShow = function(_player, ctx)
    -- Deliveries not available on tactical band
    return (ctx.band or "") ~= "tactical"
end
screen.requires = { connected = true, bands = {"amateur"} }

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Delivery_Header")

    -- ── Active delivery ──
    local active = getActiveDelivery()

    if active then
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Delivery_Active"), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH

        local obj = active.objectives[1]

        -- Status
        local status
        if not obj.pickedUp then
            status = W.safeGetText("UI_POS_Delivery_Status_AwaitingPickup")
        else
            status = W.safeGetText("UI_POS_Delivery_Status_InTransit")
        end
        W.createLabel(ctx.panel, 8, ctx.y, "  Status: " .. status, C.text)
        ctx.y = ctx.y + ctx.lineH

        -- Item
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Delivery_Item") .. ": "
            .. (obj.itemType or "???"), C.text)
        ctx.y = ctx.y + ctx.lineH

        -- Pickup location
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Delivery_Pickup") .. ": "
            .. formatLocation(obj.pickupX, obj.pickupY), C.text)
        ctx.y = ctx.y + ctx.lineH

        -- Dropoff location
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Delivery_Dropoff") .. ": "
            .. formatLocation(obj.dropoffX, obj.dropoffY), C.text)
        ctx.y = ctx.y + ctx.lineH

        -- Show on Map button (shows relevant location based on delivery state)
        local mapX = obj.pickedUp and obj.dropoffX or obj.pickupX
        local mapY = obj.pickedUp and obj.dropoffY or obj.pickupY
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            W.safeGetText("UI_POS_Delivery_ShowOnMap"), nil,
            function()
                PhobosLib.showOnWorldMap(0, mapX, mapY, 20.0)
            end)
        ctx.y = ctx.y + ctx.btnH + 4

        -- Straight-line distance
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Delivery_Distance") .. ": "
            .. math.floor(active.straightLineDistance or 0) .. " "
            .. W.safeGetText("UI_POS_Delivery_Tiles"), C.dim)
        ctx.y = ctx.y + ctx.lineH

        -- Distance walked/driven so far
        if obj.pickedUp then
            local walked = POS_PathTracker.getDistance(active.id)
            W.createLabel(ctx.panel, 8, ctx.y,
                "  " .. W.safeGetText("UI_POS_Delivery_DistanceWalked") .. ": "
                .. math.floor(walked) .. " "
                .. W.safeGetText("UI_POS_Delivery_Tiles"), C.dim)
            ctx.y = ctx.y + ctx.lineH
        end

        -- Estimated reward
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Delivery_Reward") .. ": ~$"
            .. (active.estimatedReward or "???"), C.warn)
        ctx.y = ctx.y + ctx.lineH

        -- Cancel button
        local cancelPenalty = POS_RewardCalculator.previewCancellationPenalty(active)
        local cancelLabel
        if cancelPenalty <= 0 then
            cancelLabel = W.safeGetText("UI_POS_Cancel_NoPenalty")
        else
            cancelLabel = W.safeGetText("UI_POS_Cancel_WithPenalty",
                tostring(cancelPenalty))
        end
        local cancelActiveId = active.id
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH, cancelLabel, nil,
            function()
                POS_OperationLog.cancelOperation(cancelActiveId)
                POS_ScreenManager.markDirty()
            end)
        ctx.y = ctx.y + ctx.btnH + 4

        ctx.y = ctx.y + 4
    else
        -- ── Available deliveries ──
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Delivery_Available"), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH

        local available = getAvailableDeliveries()

        if #available == 0 then
            local cacheCount = POS_MailboxScanner
                and POS_MailboxScanner.getCacheCount() or 0
            if cacheCount < 2 then
                W.createLabel(ctx.panel, 8, ctx.y,
                    W.safeGetText("UI_POS_Delivery_NeedMailboxes"), C.dim)
                ctx.y = ctx.y + ctx.lineH
                W.createLabel(ctx.panel, 8, ctx.y,
                    W.safeGetText("UI_POS_Delivery_MailboxCount",
                        tostring(cacheCount)), C.dim)
            else
                W.createLabel(ctx.panel, 8, ctx.y,
                    W.safeGetText("UI_POS_Delivery_NoAvailable"), C.dim)
            end
            ctx.y = ctx.y + ctx.lineH
        else
            local currentPage = (_params and _params.delPage) or 1
            ctx.y = PhobosLib_Pagination.create(ctx.panel, {
                items = available,
                pageSize = 5,
                currentPage = currentPage,
                x = ctx.btnX,
                y = ctx.y,
                width = ctx.btnW,
                colours = {
                    text = C.text, dim = C.dim,
                    bgDark = C.bgDark, bgHover = C.bgHover,
                    border = C.border,
                },
                renderItem = function(parent, rx, ry, rw, op, _idx)
                    local dObj = op.objectives[1]
                    local label = (dObj.itemType or "Package")
                        .. " — ~" .. math.floor(op.estimatedRoadDistance or 0) .. " "
                        .. W.safeGetText("UI_POS_Delivery_Tiles")
                        .. " — ~$" .. (op.estimatedReward or "???")
                    local opId = op.id
                    W.createButton(parent, rx, ry, rw, ctx.btnH, label, nil,
                        function()
                            local negotiateEnabled = POS_Sandbox
                                and POS_Sandbox.isNegotiationEnabled
                                and POS_Sandbox.isNegotiationEnabled()
                            if negotiateEnabled then
                                POS_ScreenManager.navigateTo(POS_Constants.SCREEN_NEGOTIATE,
                                    { operationId = opId })
                            else
                                if POS_OperationLog and POS_OperationLog.get then
                                    local operation = POS_OperationLog.get(opId)
                                    if operation then
                                        POS_OperationService.activateOperation(operation)
                                        POS_ScreenManager.markDirty()
                                    end
                                end
                            end
                        end)
                    return ctx.btnH + 4
                end,
                onPageChange = function(newPage)
                    POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_DELIVERIES,
                        { delPage = newPage })
                end,
            })
        end
    end

    -- ── Completed deliveries ──
    local completed = getCompletedDeliveries()
    if #completed > 0 then
        ctx.y = ctx.y + 4
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Delivery_Recent"), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH

        local shown = 0
        for i = #completed, 1, -1 do
            if shown >= 5 then break end
            local op = completed[i]
            local reward = op.finalReward or op.estimatedReward or 0
            local dist = op.actualDistance or op.straightLineDistance or 0
            local line = "  [OK] $" .. reward
                .. " — " .. math.floor(dist) .. " "
                .. W.safeGetText("UI_POS_Delivery_Tiles")
            W.createLabel(ctx.panel, 0, ctx.y, line, C.success)
            ctx.y = ctx.y + ctx.lineH
            shown = shown + 1
        end
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function(_params)
    local data = {}
    local active = POS_OperationLog and POS_OperationLog.getByStatus
        and POS_OperationLog.getByStatus(POS_Constants.STATUS_ACTIVE)
    if active then
        for _, op in ipairs(active) do
            if op.objectives and op.objectives[1]
               and op.objectives[1].type == POS_Constants.OBJECTIVE_TYPE_DELIVERY then
                local obj = op.objectives[1]
                table.insert(data, { type = "header", text = "UI_POS_Context_MissionInfo" })
                if obj.pickupX and obj.pickupY then
                    local pickupStr = math.floor(obj.pickupX) .. ", " .. math.floor(obj.pickupY)
                    if PhobosLib_Address and PhobosLib_Address.resolveAddress then
                        local addr = PhobosLib_Address.resolveAddress(obj.pickupX, obj.pickupY)
                        if addr and addr.street then
                            pickupStr = PhobosLib_Address.formatAddress(addr)
                        end
                    end
                    table.insert(data, { type = "kv", key = "UI_POS_Context_Pickup", value = pickupStr })
                end
                if obj.dropoffX and obj.dropoffY then
                    local dropStr = math.floor(obj.dropoffX) .. ", " .. math.floor(obj.dropoffY)
                    if PhobosLib_Address and PhobosLib_Address.resolveAddress then
                        local addr = PhobosLib_Address.resolveAddress(obj.dropoffX, obj.dropoffY)
                        if addr and addr.street then
                            dropStr = PhobosLib_Address.formatAddress(addr)
                        end
                    end
                    table.insert(data, { type = "kv", key = "UI_POS_Context_Delivery", value = dropStr })
                end
                if op.expiryDay then
                    local currentDay = getGameTime and getGameTime():getNightsSurvived() or 0
                    local daysLeft = math.max(0, op.expiryDay - currentDay)
                    table.insert(data, { type = "kv", key = "UI_POS_Context_Deadline", value = tostring(daysLeft) .. "d" })
                end
                break  -- show first active delivery only
            end
        end
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
