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
-- POS_CompletionDetector.lua
-- Objective tracking and completion event handling.
--
-- Objective types (extensible):
--   "item_acquire"     — Player has item(s) of a given type
--   "location_visit"   — Player enters a target area
--   "entity_interact"  — Player interacts with a world object
--   "timed_survival"   — Player survives N hours in an area
--
-- External mods can register custom objective type checkers
-- via POS_CompletionDetector.registerChecker(type, func).
---------------------------------------------------------------

require "PhobosLib"

POS_CompletionDetector = {}

--- Registry of objective type checkers.
--- Each checker: function(player, objective) → boolean
local checkers = {}

--- Register a custom objective type checker.
--- @param objectiveType string The objective type identifier
--- @param checkerFunc function function(player, objective) → boolean
function POS_CompletionDetector.registerChecker(objectiveType, checkerFunc)
    if objectiveType and checkerFunc then
        checkers[objectiveType] = checkerFunc
    end
end

--- Check if a single objective is complete.
--- @param player IsoPlayer
--- @param objective table Objective data from the operation
--- @return boolean
function POS_CompletionDetector.checkObjective(player, objective)
    if not player or not objective then return false end
    if objective.completed then return true end

    local checker = checkers[objective.type]
    if checker then
        return checker(player, objective)
    end

    return false
end

--- Check all objectives in an operation and update their status.
--- @param player IsoPlayer
--- @param operation table Operation data table
--- @return boolean True if ALL objectives are now complete
function POS_CompletionDetector.checkOperation(player, operation)
    if not player or not operation or not operation.objectives then
        return false
    end

    local allComplete = true
    for i = 1, #operation.objectives do
        local obj = operation.objectives[i]
        if not obj.completed then
            if POS_CompletionDetector.checkObjective(player, obj) then
                obj.completed = true
                PhobosLib.debug("POS", "Objective completed: " .. (obj.description or "?"))
            else
                allComplete = false
            end
        end
    end

    return allComplete
end

---------------------------------------------------------------
-- Built-in objective type: item_acquire
-- objective.target = fullType string (e.g. "Base.Screwdriver")
-- objective.count  = required count (default 1)
---------------------------------------------------------------
POS_CompletionDetector.registerChecker("item_acquire", function(player, obj)
    if not obj.target then return false end
    local inv = player:getInventory()
    if not inv then return false end
    local count = obj.count or 1
    local found = inv:getCountTypeRecurse(obj.target)
    return found >= count
end)

---------------------------------------------------------------
-- Built-in objective type: delivery
-- Completion is handled by POS_DeliveryContextMenu via the
-- right-click "Deliver POSnet Package" action — NOT via
-- periodic polling. This checker simply reads the completion
-- flag that the context menu action sets.
---------------------------------------------------------------
POS_CompletionDetector.registerChecker(POS_Constants.OBJECTIVE_TYPE_DELIVERY, function(_player, obj)
    return obj.completed == true
end)

---------------------------------------------------------------
-- Built-in objective type: recon
-- Multi-step completion: enter room → photograph → craft notes → turn in.
-- This checker handles room entry detection (sets entered=true)
-- and reads notesWritten flag (set by craft callback).
-- Completion is NOT automatic — player must turn in at terminal.
---------------------------------------------------------------
--- Distance threshold for considering a player "at" the target building (tiles).
local ROOM_ENTRY_THRESHOLD = 100

POS_CompletionDetector.registerChecker(POS_Constants.MISSION_TYPE_RECON, function(player, obj)
    if obj.completed then return true end
    if not obj.targetRoomDefs or not obj.targetBuildingX then return false end

    -- Step 1: detect room entry (if not already entered)
    if not obj.entered then
        local roomName = PhobosLib.getPlayerRoomName(player)
        if roomName then
            for _, target in ipairs(obj.targetRoomDefs) do
                if roomName == target then
                    local bx, by = obj.targetBuildingX, obj.targetBuildingY
                    local px, py = player:getX(), player:getY()
                    local dist = math.abs(px - bx) + math.abs(py - by)
                    if dist < ROOM_ENTRY_THRESHOLD then
                        obj.entered = true
                        -- Notification handled by POS_ReconScanner
                    end
                end
            end
        end
    end

    -- Completion requires turn-in at terminal (not auto-complete)
    -- obj.completed is set by POS_Screen_Operations turn-in flow
    return false
end)
