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
-- POS_MapMarkers.lua
-- Manages world map markers for POSnet operations.
-- Places tier-coloured waypoints when missions are accepted
-- and removes them on completion or expiry.
---------------------------------------------------------------

require "PhobosLib"

POS_MapMarkers = POS_MapMarkers or {}

local _TAG = "[POS:MapMarkers]"

--- Tier colour definitions (r, g, b, a).
local TIER_COLOURS = {
    { r = 0.20, g = 0.90, b = 0.20, a = 1.0 },   -- Tier I: green
    { r = 0.90, g = 0.80, b = 0.10, a = 1.0 },   -- Tier II: yellow
    { r = 1.00, g = 0.50, b = 0.20, a = 1.0 },   -- Tier III: orange
    { r = 0.90, g = 0.25, b = 0.20, a = 1.0 },   -- Tier IV: red
}

--- Generate the marker ID string for an operation.
---@param operationId string
---@return string Marker ID
function POS_MapMarkers.getMarkerId(operationId)
    return "POSnet_" .. (operationId or "unknown")
end

--- Place a waypoint marker for an operation at its target coordinates.
---@param operation table Operation data with id, tier, and objective coordinates
---@return boolean True if marker was placed
function POS_MapMarkers.placeMarker(operation)
    if not operation or not operation.id then return false end
    local obj = operation.objectives and operation.objectives[1]
    if not obj then return false end

    local x = obj.targetBuildingX
    local y = obj.targetBuildingY
    if not x or not y then return false end

    local tier = operation.tier or 1
    local colour = TIER_COLOURS[tier] or TIER_COLOURS[1]

    local markerId = POS_MapMarkers.getMarkerId(operation.id)
    local placed = PhobosLib.addWorldMapMarker(
        markerId, x, y, colour.r, colour.g, colour.b, colour.a)

    if placed then
        PhobosLib.debug("POS", _TAG, "[MapMarkers] Placed marker '"
            .. markerId .. "' at " .. math.floor(x) .. ", " .. math.floor(y))
    end

    return placed
end

--- Remove the waypoint marker for an operation.
---@param operationId string Operation ID
---@return boolean True if removal was attempted
function POS_MapMarkers.removeMarker(operationId)
    if not operationId then return false end
    local markerId = POS_MapMarkers.getMarkerId(operationId)
    local removed = PhobosLib.removeWorldMapMarker(markerId)

    if removed then
        PhobosLib.debug("POS", _TAG, "[MapMarkers] Removed marker '" .. markerId .. "'")
    end

    return removed
end
