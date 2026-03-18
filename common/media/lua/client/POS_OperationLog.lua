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
-- POS_OperationLog.lua
-- Player-side operation journal — persistence and management.
--
-- Stores active, completed, and expired operations in the
-- player's modData. Provides add/remove/query functions for
-- the UI layer and completion detector.
--
-- Operations are stored under modData key "POS_Operations"
-- as an array of operation tables.
---------------------------------------------------------------

require "PhobosLib"

POS_OperationLog = {}

local MODDATA_KEY = "POS_Operations"

--- Get the operations array from player modData, creating if needed.
--- @param player IsoPlayer
--- @return table Array of operation tables
local function getOperationsStore(player)
    if not player then return {} end
    local md = PhobosLib.getModData(player)
    if not md then return {} end
    if not md[MODDATA_KEY] then
        md[MODDATA_KEY] = {}
    end
    return md[MODDATA_KEY]
end

--- Add a new operation to the player's log.
--- Respects the MaxActiveOperations sandbox limit.
--- @param operation table Operation data from MissionGenerator
--- @return boolean True if added successfully
function POS_OperationLog.addOperation(operation)
    if not operation or not operation.id then return false end

    local player = getSpecificPlayer(0)
    if not player then return false end

    local ops = getOperationsStore(player)
    local maxActive = POS_Sandbox.getMaxActiveOperations()

    -- Count current active operations
    local activeCount = 0
    for i = 1, #ops do
        if ops[i].status == "active" then
            activeCount = activeCount + 1
        end
    end

    if activeCount >= maxActive then
        PhobosLib.debug("POS", "Max active operations reached (" .. maxActive .. ") — rejecting new operation")
        return false
    end

    -- Check for duplicate
    for i = 1, #ops do
        if ops[i].id == operation.id then
            PhobosLib.debug("POS", "Duplicate operation ID: " .. operation.id)
            return false
        end
    end

    table.insert(ops, operation)
    PhobosLib.debug("POS", "Operation added to log: " .. operation.id)
    return true
end

--- Get all operations from the player's log.
--- @return table Array of operation tables
function POS_OperationLog.getAll()
    local player = getSpecificPlayer(0)
    if not player then return {} end
    return getOperationsStore(player)
end

--- Get operations filtered by status.
--- @param status string "active", "completed", "expired", or "failed"
--- @return table Array of matching operations
function POS_OperationLog.getByStatus(status)
    local all = POS_OperationLog.getAll()
    local results = {}
    for i = 1, #all do
        if all[i].status == status then
            table.insert(results, all[i])
        end
    end
    return results
end

--- Get a specific operation by ID.
--- @param operationId string
--- @return table|nil
function POS_OperationLog.get(operationId)
    local all = POS_OperationLog.getAll()
    for i = 1, #all do
        if all[i].id == operationId then
            return all[i]
        end
    end
    return nil
end

--- Mark an operation as completed.
--- @param operationId string
--- @return boolean
function POS_OperationLog.completeOperation(operationId)
    local op = POS_OperationLog.get(operationId)
    if not op then return false end
    op.status = "completed"

    -- Grant reputation for completing recon missions
    if op.baseReputation and op.baseReputation > 0 then
        local player = getSpecificPlayer(0)
        if player and POS_Reputation then
            POS_Reputation.add(player, op.baseReputation)
        end
    end

    -- Pay reward for recon missions
    if op.scaledReward and op.scaledReward > 0
       and op.objectives and op.objectives[1]
       and op.objectives[1].type == "recon" then
        local player = getSpecificPlayer(0)
        if player then
            PhobosLib.addMoney(player, op.scaledReward)
        end
    end

    PhobosLib.debug("POS", "Operation completed: " .. operationId)
    return true
end

--- Cancel an active operation and apply tier-scaled reputation penalty.
--- Tier I missions incur no penalty; higher tiers scale upward.
--- @param operationId string
--- @return boolean True if cancelled successfully
function POS_OperationLog.cancelOperation(operationId)
    local op = POS_OperationLog.get(operationId)
    if not op then return false end
    if op.status ~= "active" then return false end

    op.status = "cancelled"

    -- Apply cancellation penalty
    local player = getSpecificPlayer(0)
    if player and POS_RewardCalculator
       and POS_RewardCalculator.applyCancellationPenalty then
        POS_RewardCalculator.applyCancellationPenalty(player, op)
    end

    -- Remove map marker
    if POS_MapMarkers and POS_MapMarkers.removeMarker then
        POS_MapMarkers.removeMarker(operationId)
    end

    -- For deliveries: remove package item from inventory if picked up
    local obj = op.objectives and op.objectives[1]
    if obj and obj.type == "delivery" and obj.pickedUp and player then
        pcall(function()
            local inv = player:getInventory()
            if not inv then return end
            local items = inv:getItemsFromFullType(
                "PhobosOperationalSignals.POSnetPackage")
            if items then
                for i = 0, items:size() - 1 do
                    local item = items:get(i)
                    local md = item:getModData()
                    if md and md.POS_OperationId == operationId then
                        inv:Remove(item)
                        break
                    end
                end
            end
        end)
    end

    PhobosLib.debug("POS", "Operation cancelled: " .. operationId)
    return true
end

--- Mark an operation as expired and apply reputation penalty.
--- @param operationId string
--- @return boolean
function POS_OperationLog.expireOperation(operationId)
    local op = POS_OperationLog.get(operationId)
    if not op then return false end
    op.status = "expired"

    -- Apply expiry reputation penalty
    local penalty = POS_Sandbox and POS_Sandbox.getExpiryReputationPenalty
        and POS_Sandbox.getExpiryReputationPenalty() or 25
    if penalty > 0 and POS_Reputation then
        local player = getSpecificPlayer(0)
        if player then
            POS_Reputation.add(player, -penalty)
        end
    end

    PhobosLib.debug("POS", "Operation expired: " .. operationId)
    return true
end

--- Check for expired operations and update their status.
--- Called periodically (e.g. every in-game hour).
function POS_OperationLog.checkExpiry()
    local player = getSpecificPlayer(0)
    if not player then return end

    local gameTime = getGameTime()
    if not gameTime then return end
    local currentDay = gameTime:getNightsSurvived()

    local ops = getOperationsStore(player)
    for i = 1, #ops do
        local op = ops[i]
        if op.status == "active" and op.expiryDay then
            if currentDay >= op.expiryDay then
                op.status = "expired"
                PhobosLib.debug("POS", "Operation auto-expired: " .. (op.id or "?"))
            end
        end
    end
end

--- Tick handler — checks objectives and expiry.
--- Runs once per in-game hour.
local lastCheckHour = -1

function POS_OperationLog.onEveryOneMinute()
    local gameTime = getGameTime()
    if not gameTime then return end
    local hour = gameTime:getHour()
    if hour == lastCheckHour then return end
    lastCheckHour = hour

    local player = getSpecificPlayer(0)
    if not player then return end

    -- Check expiry
    POS_OperationLog.checkExpiry()

    -- Check completion for active operations
    local ops = getOperationsStore(player)
    for i = 1, #ops do
        local op = ops[i]
        if op.status == "active" then
            if POS_CompletionDetector.checkOperation(player, op) then
                op.status = "completed"
                PhobosLib.debug("POS", "All objectives met — operation completed: " .. (op.id or "?"))
            end
        end
    end
end

--- Get count of operations by status.
--- @return table Map of status → count
function POS_OperationLog.getCounts()
    local all = POS_OperationLog.getAll()
    local counts = { active = 0, completed = 0, expired = 0, failed = 0, cancelled = 0 }
    for i = 1, #all do
        local s = all[i].status or "active"
        counts[s] = (counts[s] or 0) + 1
    end
    return counts
end

--- Initialise the operation log tick handler.
function POS_OperationLog.init()
    Events.EveryOneMinute.Add(POS_OperationLog.onEveryOneMinute)
    PhobosLib.debug("POS", "Operation log initialised")
end

Events.OnGameStart.Add(POS_OperationLog.init)
