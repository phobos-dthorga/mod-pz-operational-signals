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
-- POS_OperationService.lua
-- Shared service for operation lifecycle management.
-- Encapsulates all state mutations (complete, cancel, expire),
-- reputation grants, reward payments, and penalty calculations.
-- UI screens delegate all operation actions here.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_OperationService = {}

local _TAG = "[POS:OpService]"

---------------------------------------------------------------
-- Generation + Registration
---------------------------------------------------------------

--- Generate a new recon operation and register it in the log.
--- Delegates to POS_ReconGenerator for generation and
--- POS_OperationLog for persistence.
---@param player any IsoPlayer
---@param minTier number Minimum tier to generate (default 1)
---@param maxTier number Maximum tier to generate (default 2)
---@return table|nil operation The generated operation, or nil
function POS_OperationService.generateAndRegister(player, minTier, maxTier)
    if not player then return nil end
    if not POS_ReconGenerator or not POS_ReconGenerator.generate then return nil end
    if not POS_OperationLog or not POS_OperationLog.addOperation then return nil end

    local op = POS_ReconGenerator.generate(player)
    if not op then return nil end

    local tier = op.tier or 1
    if tier < (minTier or 1) or tier > (maxTier or 2) then
        return nil
    end

    if POS_OperationLog.addOperation(op) then
        return op
    end
    return nil
end

---------------------------------------------------------------
-- Activation
---------------------------------------------------------------

--- Activate an operation (transition from available → active).
--- Places a map marker if applicable.
---@param operation table The operation to activate
function POS_OperationService.activateOperation(operation)
    if not operation then return end
    operation.status = POS_Constants.STATUS_ACTIVE
    if POS_MapMarkers and POS_MapMarkers.placeMarker then
        POS_MapMarkers.placeMarker(operation)
    end

    -- Tutorial: first operation received milestone
    if POS_TutorialService and POS_TutorialService.tryAward and operation._player then
        POS_TutorialService.tryAward(operation._player, POS_Constants.TUTORIAL_FIRST_OP_RECEIVED)
    end
end

---------------------------------------------------------------
-- Completion
---------------------------------------------------------------

--- Complete an operation: mark status, pay reward, grant reputation,
--- and remove map marker.
---@param operation table The operation to complete
---@param player any IsoPlayer
function POS_OperationService.completeOperation(operation, player)
    if not operation or not player then return end

    -- Mark objective completed
    if operation.objectives and operation.objectives[1] then
        operation.objectives[1].completed = true
    end

    operation.status = POS_Constants.STATUS_COMPLETED

    -- Pay reward and grant reputation via RewardCalculator
    local reward = operation.scaledReward or 0
    local baseRep = operation.baseReputation or 0
    if POS_RewardCalculator and POS_RewardCalculator.payReward then
        POS_RewardCalculator.payReward(player, reward, baseRep)
    end

    -- Remove map marker
    if POS_MapMarkers and POS_MapMarkers.removeMarker then
        POS_MapMarkers.removeMarker(operation.id)
    end

    -- Tutorial: first operation completed milestone
    if POS_TutorialService and POS_TutorialService.tryAward then
        POS_TutorialService.tryAward(player, POS_Constants.TUTORIAL_FIRST_OP_COMPLETED)
    end

    PhobosLib.debug("POS", _TAG, "Operation completed: " .. (operation.id or "?"))
end

--- Remove the matching field report from the player's inventory.
--- Used during the turn-in flow.
---@param player any IsoPlayer
---@param operationId string
function POS_OperationService.consumeFieldReport(player, operationId)
    if not player or not operationId then return end
    local inv = player:getInventory()
    if not inv then return end
    PhobosLib.safecall(function()
        local items = inv:getItemsFromFullType(POS_Constants.ITEM_FIELD_REPORT)
        if not items then return end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local md = item:getModData()
            if md and md[POS_Constants.MD_OPERATION_ID] == operationId then
                inv:Remove(item)
                return
            end
        end
    end)
end

---------------------------------------------------------------
-- Cancellation
---------------------------------------------------------------

--- Cancel an active operation: apply tier-scaled reputation penalty,
--- remove map marker, and clean up delivery items.
---@param operation table The operation to cancel
---@param player any IsoPlayer
---@return boolean True if cancelled successfully
function POS_OperationService.cancelOperation(operation, player)
    if not operation then return false end
    if operation.status ~= POS_Constants.STATUS_ACTIVE then return false end

    operation.status = POS_Constants.STATUS_CANCELLED

    -- Apply cancellation penalty
    if player and POS_RewardCalculator
       and POS_RewardCalculator.applyCancellationPenalty then
        POS_RewardCalculator.applyCancellationPenalty(player, operation)
    end

    -- Remove map marker
    if POS_MapMarkers and POS_MapMarkers.removeMarker then
        POS_MapMarkers.removeMarker(operation.id)
    end

    -- For deliveries: remove package item from inventory if picked up
    local obj = operation.objectives and operation.objectives[1]
    if obj and obj.type == POS_Constants.OBJECTIVE_TYPE_DELIVERY
       and obj.pickedUp and player then
        PhobosLib.safecall(function()
            local inv = player:getInventory()
            if not inv then return end
            local items = inv:getItemsFromFullType(POS_Constants.ITEM_POSNET_PACKAGE)
            if not items then return end
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                local md = item:getModData()
                if md and md[POS_Constants.MD_OPERATION_ID] == operation.id then
                    inv:Remove(item)
                    return
                end
            end
        end)
    end

    PhobosLib.debug("POS", _TAG, "Operation cancelled: " .. (operation.id or "?"))
    return true
end

---------------------------------------------------------------
-- Expiry
---------------------------------------------------------------

--- Expire a single operation and apply reputation penalty.
---@param operation table The operation to expire
function POS_OperationService.expireOperation(operation)
    if not operation then return end
    operation.status = POS_Constants.STATUS_EXPIRED

    local penalty = POS_Sandbox and POS_Sandbox.getExpiryReputationPenalty
        and POS_Sandbox.getExpiryReputationPenalty()
        or POS_Constants.EXPIRY_REPUTATION_PENALTY_DEFAULT
    if penalty > 0 and POS_Reputation then
        local player = getSpecificPlayer(0)
        if player then
            POS_Reputation.add(player, -penalty)
        end
    end

    PhobosLib.debug("POS", _TAG, "Operation expired: " .. (operation.id or "?"))
end

--- Check all active operations for expiry and expire those past deadline.
---@param operations table Array of operation tables
---@param currentDay number Current game day (nightsSurvived)
function POS_OperationService.checkExpiry(operations, currentDay)
    if not operations or not currentDay then return end
    for i = 1, #operations do
        local op = operations[i]
        if op.status == POS_Constants.STATUS_ACTIVE and op.expiryDay then
            if currentDay >= op.expiryDay then
                POS_OperationService.expireOperation(op)
            end
        end
    end
end

---------------------------------------------------------------
-- Tick handler — checks objectives and expiry
---------------------------------------------------------------

local lastCheckHour = -1

--- Periodic tick: check expiry and auto-complete operations.
--- Should be called from EveryOneMinute (hourly gated).
function POS_OperationService.onEveryOneMinute()
    local gameTime = getGameTime()
    if not gameTime then return end
    local hour = gameTime:getHour()
    if hour == lastCheckHour then return end
    lastCheckHour = hour

    local player = getSpecificPlayer(0)
    if not player then return end

    -- Get operations store
    local ops = POS_OperationLog and POS_OperationLog.getAll
        and POS_OperationLog.getAll() or {}

    -- Check expiry
    local currentDay = gameTime:getNightsSurvived()
    POS_OperationService.checkExpiry(ops, currentDay)

    -- Check completion for active operations
    if POS_CompletionDetector and POS_CompletionDetector.checkOperation then
        for i = 1, #ops do
            local op = ops[i]
            if op.status == POS_Constants.STATUS_ACTIVE then
                if POS_CompletionDetector.checkOperation(player, op) then
                    POS_OperationService.completeOperation(op, player)
                end
            end
        end
    end
end

--- Initialise the operation service tick handler.
function POS_OperationService.init()
    Events.EveryOneMinute.Add(POS_OperationService.onEveryOneMinute)
    PhobosLib.debug("POS", _TAG, "Operation service initialised")
end
