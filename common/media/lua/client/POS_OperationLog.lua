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
-- Player-side operation journal — persistence layer.
--
-- Stores active, completed, and expired operations in the
-- player's modData. Provides add/remove/query functions.
-- All business logic (completion, cancellation, expiry,
-- reputation, rewards) is in POS_OperationService.
--
-- Operations are stored under modData key POS_Constants.MODDATA_OPERATIONS.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_OperationService"

POS_OperationLog = {}

local _TAG = "[POS:OpLog]"

--- Get the operations array from player modData, creating if needed.
--- @param player IsoPlayer
--- @return table Array of operation tables
local function getOperationsStore(player)
    if not player then return {} end
    local md = PhobosLib.getModData(player)
    if not md then return {} end
    if not md[POS_Constants.MODDATA_OPERATIONS] then
        md[POS_Constants.MODDATA_OPERATIONS] = {}
    end
    return md[POS_Constants.MODDATA_OPERATIONS]
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

    -- Count current active operations (pairs() for ModData compat)
    local activeCount = 0
    for _, op in pairs(ops) do
        if type(op) == "table" and op.status == POS_Constants.STATUS_ACTIVE then
            activeCount = activeCount + 1
        end
    end

    if activeCount >= maxActive then
        PhobosLib.debug("POS", _TAG, "Max active operations reached (" .. maxActive .. ") — rejecting new operation")
        return false
    end

    -- Check for duplicate
    for _, op in pairs(ops) do
        if type(op) == "table" and op.id == operation.id then
            PhobosLib.debug("POS", _TAG, "Duplicate operation ID: " .. operation.id)
            return false
        end
    end

    -- Append using explicit index (table.insert crashes on Java ModData)
    local nextIdx = 0
    for k, _ in pairs(ops) do
        if type(k) == "number" and k > nextIdx then nextIdx = k end
    end
    ops[nextIdx + 1] = operation
    PhobosLib.debug("POS", _TAG, "Operation added to log: " .. operation.id)
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
    for _, op in pairs(all) do
        if type(op) == "table" and op.status == status then
            results[#results + 1] = op
        end
    end
    return results
end

--- Get a specific operation by ID.
--- @param operationId string
--- @return table|nil
function POS_OperationLog.get(operationId)
    local all = POS_OperationLog.getAll()
    for _, op in pairs(all) do
        if type(op) == "table" and op.id == operationId then
            return op
        end
    end
    return nil
end

--- Mark an operation as completed.
--- Delegates to POS_OperationService for reward/reputation logic.
--- @param operationId string
--- @return boolean
function POS_OperationLog.completeOperation(operationId)
    local op = POS_OperationLog.get(operationId)
    if not op then return false end
    local player = getSpecificPlayer(0)
    POS_OperationService.completeOperation(op, player)
    return true
end

--- Cancel an active operation.
--- Delegates to POS_OperationService for penalty/cleanup logic.
--- @param operationId string
--- @return boolean True if cancelled successfully
function POS_OperationLog.cancelOperation(operationId)
    local op = POS_OperationLog.get(operationId)
    if not op then return false end
    local player = getSpecificPlayer(0)
    return POS_OperationService.cancelOperation(op, player)
end

--- Get count of operations by status.
--- @return table Map of status → count
function POS_OperationLog.getCounts()
    local all = POS_OperationLog.getAll()
    local counts = {
        [POS_Constants.STATUS_ACTIVE]    = 0,
        [POS_Constants.STATUS_COMPLETED] = 0,
        [POS_Constants.STATUS_EXPIRED]   = 0,
        [POS_Constants.STATUS_FAILED]    = 0,
        [POS_Constants.STATUS_CANCELLED] = 0,
    }
    for _, op in pairs(all) do
        if type(op) == "table" then
            local s = op.status or POS_Constants.STATUS_ACTIVE
            counts[s] = (counts[s] or 0) + 1
        end
    end
    return counts
end

--- Initialise the operation service tick handler.
function POS_OperationLog.init()
    POS_OperationService.init()
    PhobosLib.debug("POS", _TAG, "Operation log initialised")
end

Events.OnGameStart.Add(POS_OperationLog.init)
