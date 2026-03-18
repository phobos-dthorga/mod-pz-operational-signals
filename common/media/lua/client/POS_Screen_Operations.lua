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
-- POS_Screen_Operations.lua
-- Terminal screen for POSnet recon operations.
-- Shows available missions (tier-gated), active operations,
-- and completed operations with rewards earned.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_Reputation"
require "POS_ReconGenerator"
require "POS_RewardCalculator"
require "POS_BuildingCache"
require "POS_MapMarkers"
require "POS_OperationLog"
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

--- Tier colour coding.
local TIER_COLOURS = {
    C.text,                                        -- Tier I: green
    C.warn,                                        -- Tier II: yellow
    { r = 1.00, g = 0.50, b = 0.20, a = 1.0 },   -- Tier III: orange
    C.error,                                       -- Tier IV: red
}

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

local function getActiveRecon()
    if not POS_OperationLog then return nil end
    local ops = POS_OperationLog.getByStatus("active")
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == "recon" then
            return op
        end
    end
    return nil
end

local function getAvailableRecons()
    if not POS_OperationLog then return {} end

    -- Determine tier filter based on connected band
    local terminal = POS_TerminalUI and POS_TerminalUI.instance
    local band = terminal and terminal.band or "operations"
    local minTier = band == "tactical" and 3 or 1
    local maxTier = band == "tactical" and 4 or 2

    local results = {}
    local ops = POS_OperationLog.getByStatus("available")
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == "recon" then
            local tier = op.tier or 1
            if tier >= minTier and tier <= maxTier then
                table.insert(results, op)
            end
        end
    end

    -- On-demand generation if none available
    if #results == 0 and POS_Sandbox and POS_Sandbox.isReconEnabled
       and POS_Sandbox.isReconEnabled() then
        local player = getSpecificPlayer(0)
        if player then
            local op = POS_ReconGenerator.generate(player)
            if op and POS_OperationLog then
                local tier = op.tier or 1
                if tier >= minTier and tier <= maxTier then
                    POS_OperationLog.addOperation(op)
                    table.insert(results, op)
                end
            end
        end
    end

    return results
end

local function getCompletedRecons()
    if not POS_OperationLog then return {} end
    local results = {}
    local ops = POS_OperationLog.getByStatus("completed")
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == "recon" then
            table.insert(results, op)
        end
    end
    return results
end

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_OPERATIONS
screen.menuPath = {"pos.bbs"}
screen.titleKey = "UI_POS_Ops_Header"
screen.sortOrder = 20
screen.requires = { connected = true, bands = {"amateur", "tactical"} }

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Ops_Header")

    -- Player reputation + tier
    local player = getSpecificPlayer(0)
    local rep = POS_Reputation.get(player)
    local tierDef = POS_Reputation.getPlayerTierDef(player)
    local cap = POS_Sandbox and POS_Sandbox.getReputationCap
        and POS_Sandbox.getReputationCap() or 2500

    W.createLabel(ctx.panel, 0, ctx.y,
        "  " .. W.safeGetText("UI_POS_Ops_Reputation") .. ": "
        .. rep .. " / " .. cap
        .. " [" .. W.safeGetText(tierDef and tierDef.key or "UI_POS_Rep_Tier_Untrusted") .. "]",
        C.text)
    ctx.y = ctx.y + ctx.lineH + 4

    -- ── Active recon ──
    local active = getActiveRecon()

    if active then
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Ops_ActiveMission"), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH

        local tierColour = TIER_COLOURS[active.tier or 1] or C.text

        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText(active.nameKey or "???"), tierColour)
        ctx.y = ctx.y + ctx.lineH

        local obj = active.objectives[1]
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Ops_Target") .. ": "
            .. formatLocation(obj.targetBuildingX, obj.targetBuildingY), C.text)
        ctx.y = ctx.y + ctx.lineH

        -- Show on Map button
        local mapTargetX = obj.targetBuildingX
        local mapTargetY = obj.targetBuildingY
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            W.safeGetText("UI_POS_Ops_ShowOnMap"), nil,
            function()
                PhobosLib.showOnWorldMap(0, mapTargetX, mapTargetY, 20.0)
            end)
        ctx.y = ctx.y + ctx.btnH + 4

        -- Multi-step status
        local status
        if obj.notesWritten then
            status = W.safeGetText("UI_POS_Ops_Status_ReturnToTerminal")
        elseif obj.photographed then
            status = W.safeGetText("UI_POS_Ops_Status_NotesNeeded")
        elseif obj.entered then
            status = W.safeGetText("UI_POS_Ops_Status_Photographed")
        else
            status = W.safeGetText("UI_POS_Ops_Status_Pending")
        end
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Ops_Status") .. ": " .. status, C.text)
        ctx.y = ctx.y + ctx.lineH

        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Delivery_Reward") .. ": $"
            .. (active.scaledReward or "???"), C.warn)
        ctx.y = ctx.y + ctx.lineH

        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Ops_Reputation") .. ": +"
            .. POS_RewardCalculator.scaleReputation(active.baseReputation or 0), C.dim)
        ctx.y = ctx.y + ctx.lineH

        -- Turn In Report button — shown when player has matching FieldReport
        if obj.notesWritten then
            local hasReport = false
            local player2 = getSpecificPlayer(0)
            if player2 then
                local inv = player2:getInventory()
                if inv then
                    pcall(function()
                        local items = inv:getItemsFromFullType(POS_Constants.ITEM_FIELD_REPORT)
                        if items then
                            for i = 0, items:size() - 1 do
                                local item = items:get(i)
                                local md = item:getModData()
                                if md and md[POS_Constants.MD_OPERATION_ID] == active.id then
                                    hasReport = true
                                end
                            end
                        end
                    end)
                end
            end

            if hasReport then
                ctx.y = ctx.y + 4
                local activeId = active.id
                local activeReward = active.scaledReward or 0
                local activeRep = active.baseReputation or 0
                W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
                    W.safeGetText("UI_POS_Ops_TurnIn"), nil,
                    function()
                        local p = getSpecificPlayer(0)
                        if not p then return end

                        -- Remove the FieldReport from inventory
                        local pInv = p:getInventory()
                        if pInv then
                            pcall(function()
                                local reportItems = pInv:getItemsFromFullType(
                                    POS_Constants.ITEM_FIELD_REPORT)
                                if reportItems then
                                    for i = 0, reportItems:size() - 1 do
                                        local rItem = reportItems:get(i)
                                        local rMd = rItem:getModData()
                                        if rMd and rMd.POS_OperationId == activeId then
                                            pInv:Remove(rItem)
                                            break
                                        end
                                    end
                                end
                            end)
                        end

                        -- Pay reward and grant reputation
                        POS_RewardCalculator.payReward(p, activeReward, activeRep)

                        -- Remove map marker
                        if POS_MapMarkers then
                            POS_MapMarkers.removeMarker(activeId)
                        end

                        -- Complete the operation
                        if POS_OperationLog then
                            local op = POS_OperationLog.get(activeId)
                            if op and op.objectives and op.objectives[1] then
                                op.objectives[1].completed = true
                            end
                            -- Note: don't call completeOperation() here as it would
                            -- double-pay. Just set status directly.
                            if op then op.status = "completed" end
                        end

                        p:Say(W.safeGetText("UI_POS_Ops_TurnInComplete",
                            tostring(activeReward),
                            tostring(POS_RewardCalculator.scaleReputation(activeRep))))

                        POS_ScreenManager.markDirty()
                    end)
                ctx.y = ctx.y + ctx.btnH + 4
            end
        end

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
        -- ── Available operations ──
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Ops_Available"), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH

        local available = getAvailableRecons()

        if #available == 0 then
            local cacheCount = POS_BuildingCache.getCacheCount()
            if cacheCount == 0 then
                W.createLabel(ctx.panel, 8, ctx.y,
                    W.safeGetText("UI_POS_Ops_NeedBuildings"), C.dim)
            else
                W.createLabel(ctx.panel, 8, ctx.y,
                    W.safeGetText("UI_POS_Ops_NoAvailable"), C.dim)
            end
            ctx.y = ctx.y + ctx.lineH
        else
            local currentPage = (_params and _params.opsPage) or 1
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
                    local tierLabel = "T" .. (op.tier or "?")
                    local label = "[" .. tierLabel .. "] "
                        .. W.safeGetText(op.nameKey or "???")
                        .. " — $" .. (op.scaledReward or "???")
                    local opId = op.id
                    W.createButton(parent, rx, ry, rw, ctx.btnH, label, nil,
                        function()
                            -- Route through negotiate screen if enabled
                            local negotiateEnabled = POS_Sandbox
                                and POS_Sandbox.isNegotiationEnabled
                                and POS_Sandbox.isNegotiationEnabled()
                            if negotiateEnabled then
                                POS_ScreenManager.navigateTo(POS_Constants.SCREEN_NEGOTIATE,
                                    { operationId = opId })
                            else
                                -- Direct accept (negotiation disabled)
                                if POS_OperationLog and POS_OperationLog.get then
                                    local operation = POS_OperationLog.get(opId)
                                    if operation then
                                        operation.status = "active"
                                        if POS_MapMarkers then
                                            POS_MapMarkers.placeMarker(operation)
                                        end
                                        POS_ScreenManager.markDirty()
                                    end
                                end
                            end
                        end)
                    return ctx.btnH + 4
                end,
                onPageChange = function(newPage)
                    POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_OPERATIONS,
                        { opsPage = newPage })
                end,
            })
        end
    end

    -- ── Completed operations ──
    local completed = getCompletedRecons()
    if #completed > 0 then
        ctx.y = ctx.y + 4
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Ops_Recent"), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH

        local shown = 0
        for i = #completed, 1, -1 do
            if shown >= 5 then break end
            local op = completed[i]
            local tierColour = TIER_COLOURS[op.tier or 1] or C.text
            local line = "  [OK] [T" .. (op.tier or "?") .. "] "
                .. W.safeGetText(op.nameKey or "???")
                .. " — $" .. (op.scaledReward or "?")
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
    -- Show active mission info if available
    local active = POS_OperationLog and POS_OperationLog.getByStatus
        and POS_OperationLog.getByStatus("active")
    if active and #active > 0 then
        local op = active[1]
        table.insert(data, { type = "header", text = "UI_POS_Context_MissionInfo" })
        if op.tier then
            table.insert(data, { type = "kv", key = "UI_POS_Context_Tier", value = tostring(op.tier) })
        end
        if op.objectives and op.objectives[1]
           and op.objectives[1].targetBuildingX and op.objectives[1].targetBuildingY then
            local dist = 0
            local player = getPlayer()
            if player then
                local px, py = player:getX(), player:getY()
                local tx = op.objectives[1].targetBuildingX
                local ty = op.objectives[1].targetBuildingY
                dist = math.floor(math.sqrt((tx - px)^2 + (ty - py)^2) / 100) / 10
            end
            table.insert(data, { type = "kv", key = "UI_POS_Context_Distance", value = string.format("%.1f km", dist) })
        end
        if op.expiryDay then
            local currentDay = 0
            if getGameTime then
                currentDay = getGameTime():getNightsSurvived()
            end
            local daysLeft = math.max(0, op.expiryDay - currentDay)
            table.insert(data, { type = "kv", key = "UI_POS_Context_Deadline", value = tostring(daysLeft) .. "d" })
        end
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
