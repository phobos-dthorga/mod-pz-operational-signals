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
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_Reputation"
require "POS_ReconGenerator"
require "POS_RewardCalculator"
require "POS_BuildingCache"
require "POS_MapMarkers"
require "POS_OperationLog"
require "PhobosLib_Pagination"

local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

local C = POS_TerminalWidgets.COLOURS
local GOOD = { r = 0.20, g = 0.90, b = 0.50, a = 1.0 }

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
    local results = {}
    local ops = POS_OperationLog.getByStatus("available")
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == "recon" then
            table.insert(results, op)
        end
    end

    -- On-demand generation if none available
    if #results == 0 and POS_Sandbox and POS_Sandbox.isReconEnabled
       and POS_Sandbox.isReconEnabled() then
        local player = getSpecificPlayer(0)
        if player then
            local op = POS_ReconGenerator.generate(player)
            if op and POS_OperationLog then
                POS_OperationLog.addOperation(op)
                table.insert(results, op)
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
screen.id = "OPERATIONS"

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
        safeGetText("UI_POS_Ops_Header"), C.textBright)
    y = y + lineH

    W.createSeparator(contentPanel, 0, y, 40)
    y = y + lineH

    -- Player reputation + tier
    local player = getSpecificPlayer(0)
    local rep = POS_Reputation.get(player)
    local tierDef = POS_Reputation.getPlayerTierDef(player)
    local cap = POS_Sandbox and POS_Sandbox.getReputationCap
        and POS_Sandbox.getReputationCap() or 2500

    W.createLabel(contentPanel, 0, y,
        "  " .. safeGetText("UI_POS_Ops_Reputation") .. ": "
        .. rep .. " / " .. cap
        .. " [" .. safeGetText(tierDef and tierDef.key or "UI_POS_Rep_Tier_Untrusted") .. "]",
        C.text)
    y = y + lineH + 4

    -- ── Active recon ──
    local active = getActiveRecon()

    if active then
        W.createLabel(contentPanel, 0, y,
            safeGetText("UI_POS_Ops_ActiveMission"), C.textBright)
        y = y + lineH

        W.createSeparator(contentPanel, 0, y, 40, "-")
        y = y + lineH

        local tierColour = TIER_COLOURS[active.tier or 1] or C.text

        W.createLabel(contentPanel, 8, y,
            safeGetText(active.nameKey or "???"), tierColour)
        y = y + lineH

        local obj = active.objectives[1]
        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Ops_Target") .. ": "
            .. math.floor(obj.targetBuildingX) .. ", "
            .. math.floor(obj.targetBuildingY), C.text)
        y = y + lineH

        -- Multi-step status
        local status
        if obj.notesWritten then
            status = safeGetText("UI_POS_Ops_Status_ReturnToTerminal")
        elseif obj.photographed then
            status = safeGetText("UI_POS_Ops_Status_NotesNeeded")
        elseif obj.entered then
            status = safeGetText("UI_POS_Ops_Status_Photographed")
        else
            status = safeGetText("UI_POS_Ops_Status_Pending")
        end
        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Ops_Status") .. ": " .. status, C.text)
        y = y + lineH

        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Delivery_Reward") .. ": $"
            .. (active.scaledReward or "???"), C.warn)
        y = y + lineH

        W.createLabel(contentPanel, 8, y,
            "  " .. safeGetText("UI_POS_Ops_Reputation") .. ": +"
            .. POS_RewardCalculator.scaleReputation(active.baseReputation or 0), C.dim)
        y = y + lineH

        -- Turn In Report button — shown when player has matching FieldReport
        if obj.notesWritten then
            local hasReport = false
            local player2 = getSpecificPlayer(0)
            if player2 then
                local inv = player2:getInventory()
                if inv then
                    pcall(function()
                        local items = inv:getItemsFromFullType("PhobosOperationalSignals.FieldReport")
                        if items then
                            for i = 0, items:size() - 1 do
                                local item = items:get(i)
                                local md = item:getModData()
                                if md and md.POS_OperationId == active.id then
                                    hasReport = true
                                end
                            end
                        end
                    end)
                end
            end

            if hasReport then
                y = y + 4
                local activeId = active.id
                local activeReward = active.scaledReward or 0
                local activeRep = active.baseReputation or 0
                W.createButton(contentPanel, btnX, y, btnW, btnH,
                    safeGetText("UI_POS_Ops_TurnIn"), nil,
                    function()
                        local p = getSpecificPlayer(0)
                        if not p then return end

                        -- Remove the FieldReport from inventory
                        local pInv = p:getInventory()
                        if pInv then
                            pcall(function()
                                local reportItems = pInv:getItemsFromFullType(
                                    "PhobosOperationalSignals.FieldReport")
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

                        p:Say(safeGetText("UI_POS_Ops_TurnInComplete",
                            tostring(activeReward),
                            tostring(POS_RewardCalculator.scaleReputation(activeRep))))

                        POS_ScreenManager.markDirty()
                    end)
                y = y + btnH + 4
            end
        end

        -- Cancel button
        local cancelPenalty = POS_RewardCalculator.previewCancellationPenalty(active)
        local cancelLabel
        if cancelPenalty <= 0 then
            cancelLabel = safeGetText("UI_POS_Cancel_NoPenalty")
        else
            cancelLabel = safeGetText("UI_POS_Cancel_WithPenalty",
                tostring(cancelPenalty))
        end
        local cancelActiveId = active.id
        W.createButton(contentPanel, btnX, y, btnW, btnH, cancelLabel, nil,
            function()
                POS_OperationLog.cancelOperation(cancelActiveId)
                POS_ScreenManager.markDirty()
            end)
        y = y + btnH + 4

        y = y + 4
    else
        -- ── Available operations ──
        W.createLabel(contentPanel, 0, y,
            safeGetText("UI_POS_Ops_Available"), C.textBright)
        y = y + lineH

        W.createSeparator(contentPanel, 0, y, 40, "-")
        y = y + lineH

        local available = getAvailableRecons()

        if #available == 0 then
            local cacheCount = POS_BuildingCache.getCacheCount()
            if cacheCount == 0 then
                W.createLabel(contentPanel, 8, y,
                    safeGetText("UI_POS_Ops_NeedBuildings"), C.dim)
            else
                W.createLabel(contentPanel, 8, y,
                    safeGetText("UI_POS_Ops_NoAvailable"), C.dim)
            end
            y = y + lineH
        else
            local currentPage = (_params and _params.opsPage) or 1
            y = PhobosLib_Pagination.create(contentPanel, {
                items = available,
                pageSize = 5,
                currentPage = currentPage,
                x = btnX,
                y = y,
                width = btnW,
                colours = {
                    text = C.text, dim = C.dim,
                    bgDark = C.bgDark, bgHover = C.bgHover,
                    border = C.border,
                },
                renderItem = function(parent, rx, ry, rw, op, _idx)
                    local tierLabel = "T" .. (op.tier or "?")
                    local label = "[" .. tierLabel .. "] "
                        .. safeGetText(op.nameKey or "???")
                        .. " — $" .. (op.scaledReward or "???")
                    local opId = op.id
                    W.createButton(parent, rx, ry, rw, btnH, label, nil,
                        function()
                            -- Route through negotiate screen if enabled
                            local negotiateEnabled = POS_Sandbox
                                and POS_Sandbox.isNegotiationEnabled
                                and POS_Sandbox.isNegotiationEnabled()
                            if negotiateEnabled then
                                POS_ScreenManager.navigateTo("NEGOTIATE",
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
                    return btnH + 4
                end,
                onPageChange = function(newPage)
                    POS_ScreenManager.replaceCurrent("OPERATIONS",
                        { opsPage = newPage })
                end,
            })
        end
    end

    -- ── Completed operations ──
    local completed = getCompletedRecons()
    if #completed > 0 then
        y = y + 4
        W.createLabel(contentPanel, 0, y,
            safeGetText("UI_POS_Ops_Recent"), C.textBright)
        y = y + lineH

        W.createSeparator(contentPanel, 0, y, 40, "-")
        y = y + lineH

        local shown = 0
        for i = #completed, 1, -1 do
            if shown >= 5 then break end
            local op = completed[i]
            local tierColour = TIER_COLOURS[op.tier or 1] or C.text
            local line = "  [OK] [T" .. (op.tier or "?") .. "] "
                .. safeGetText(op.nameKey or "???")
                .. " — $" .. (op.scaledReward or "?")
            W.createLabel(contentPanel, 0, y, line, GOOD)
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
    local terminal = POS_TerminalUI.instance
    if terminal and terminal.contentPanel then
        screen.destroy()
        screen.create(terminal.contentPanel, params, terminal)
    end
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
