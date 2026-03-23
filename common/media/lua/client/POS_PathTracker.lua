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
-- POS_PathTracker.lua
-- Tracks actual distance travelled by sampling player position.
-- Accumulates path deltas for active delivery operations.
-- Ignores micro-movements (< 0.5 tiles) to avoid jitter noise.
---------------------------------------------------------------

POS_PathTracker = POS_PathTracker or {}

--- Active tracking sessions keyed by operation ID.
--- Each: { totalDistance, lastX, lastY }
local sessions = {}

--- Minimum movement delta to count (avoids idle jitter).
local MIN_DELTA = 0.5

--- Start tracking distance for an operation.
---@param operationId string
function POS_PathTracker.startTracking(operationId)
    if not operationId then return end
    local player = getSpecificPlayer(0)
    if not player then return end

    sessions[operationId] = {
        totalDistance = 0,
        lastX = player:getX(),
        lastY = player:getY(),
    }
end

--- Stop tracking and return total distance accumulated.
---@param operationId string
---@return number Total distance in tiles
function POS_PathTracker.stopTracking(operationId)
    local session = sessions[operationId]
    sessions[operationId] = nil
    return session and session.totalDistance or 0
end

--- Get current accumulated distance without stopping.
---@param operationId string
---@return number Distance in tiles (0 if not tracking)
function POS_PathTracker.getDistance(operationId)
    local session = sessions[operationId]
    return session and session.totalDistance or 0
end

--- Check if an operation is being tracked.
---@param operationId string
---@return boolean
function POS_PathTracker.isTracking(operationId)
    return sessions[operationId] ~= nil
end

---------------------------------------------------------------
-- Tick handler — samples player position every tick
---------------------------------------------------------------

--- Sample interval in ticks (~3 samples/sec at 30 FPS).
local SAMPLE_INTERVAL_TICKS = 10

--- Position sampling function — called by Starlit TaskManager.
local function doPositionSample()
    -- Skip if no active sessions
    local hasAny = false
    for _ in pairs(sessions) do hasAny = true; break end
    if not hasAny then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    local px = player:getX()
    local py = player:getY()

    for _, session in pairs(sessions) do
        local dx = px - session.lastX
        local dy = py - session.lastY
        local delta = math.sqrt(dx * dx + dy * dy)
        if delta > MIN_DELTA then
            session.totalDistance = session.totalDistance + delta
            session.lastX = px
            session.lastY = py
        end
    end
end

-- Register with Starlit TaskManager instead of manual OnTick counter
local TaskManager = require("Starlit/TaskManager")
TaskManager.repeatEveryTicks(doPositionSample, SAMPLE_INTERVAL_TICKS)
