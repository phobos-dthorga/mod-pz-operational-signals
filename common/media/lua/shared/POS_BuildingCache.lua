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
-- POS_BuildingCache.lua
-- Player-discovered building cache for recon missions.
--
-- Buildings are cached in player modData as the player explores.
-- Each entry stores building coordinates and the room types found.
-- Passive scanning runs every in-game minute within a 50-tile radius.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_BuildingCache = POS_BuildingCache or {}

--- ModData key for the building cache.
local CACHE_KEY = "POS_DiscoveredBuildings"

--- Minimum distance between cached buildings to avoid duplicates (tiles).
local DEDUP_RADIUS = 10

--- Scan radius for the one-time initial building scan (tiles).
local INITIAL_SCAN_RADIUS = 250

--- Scan radius for passive periodic scans (tiles).
local PASSIVE_SCAN_RADIUS = 50

--- ModData flag key for gating the one-time initial scan.
local INITIAL_SCAN_FLAG = "POS_BuildingScanDone"

---------------------------------------------------------------
-- Cache management
---------------------------------------------------------------

--- Get the discovered building cache from player modData.
--- Each entry: { x, y, rooms = {"pharmacy", "office", ...} }
---@return table Array of building entries
function POS_BuildingCache.getCache()
    local player = getSpecificPlayer(0)
    if not player then return {} end
    local md = player:getModData()
    if not md then return {} end
    md[CACHE_KEY] = md[CACHE_KEY] or {}
    return md[CACHE_KEY]
end

--- Add a building to the discovery cache.
--- Deduplicates against existing entries within DEDUP_RADIUS.
---@param x number Building world X
---@param y number Building world Y
---@param rooms table Array of room name strings found in this building
---@return boolean True if added (not a duplicate)
function POS_BuildingCache.addToCache(x, y, rooms)
    if not rooms or #rooms == 0 then return false end

    local cache = POS_BuildingCache.getCache()

    -- Check for nearby duplicate
    for _, entry in ipairs(cache) do
        if math.abs(entry.x - x) <= DEDUP_RADIUS
           and math.abs(entry.y - y) <= DEDUP_RADIUS then
            -- Merge any new room types
            local existing = {}
            for _, r in ipairs(entry.rooms) do existing[r] = true end
            local added = false
            for _, r in ipairs(rooms) do
                if not existing[r] then
                    table.insert(entry.rooms, r)
                    existing[r] = true
                    added = true
                end
            end
            return added
        end
    end

    table.insert(cache, { x = x, y = y, rooms = rooms })

    PhobosLib.debug("POS", "[BuildingCache] Discovered building at "
        .. math.floor(x) .. ", " .. math.floor(y)
        .. " (" .. table.concat(rooms, ", ") .. ")"
        .. " — total: " .. #cache)

    return true
end

--- Get total count of discovered buildings.
---@return number
function POS_BuildingCache.getCacheCount()
    return #POS_BuildingCache.getCache()
end

--- Find cached buildings that contain a specific room type.
---@param roomName string Room name to search for (e.g. "pharmacy")
---@return table Array of { x, y, rooms } entries
function POS_BuildingCache.findByRoom(roomName)
    local cache = POS_BuildingCache.getCache()
    local results = {}
    for _, entry in ipairs(cache) do
        for _, r in ipairs(entry.rooms) do
            if r == roomName then
                table.insert(results, entry)
                break
            end
        end
    end
    return results
end

--- Find cached buildings matching ANY of the given room names.
---@param roomNames table Array of room name strings
---@return table Array of { x, y, rooms } entries
function POS_BuildingCache.findByAnyRoom(roomNames)
    if not roomNames or #roomNames == 0 then return {} end
    local lookupSet = {}
    for _, name in ipairs(roomNames) do lookupSet[name] = true end

    local cache = POS_BuildingCache.getCache()
    local results = {}
    for _, entry in ipairs(cache) do
        for _, r in ipairs(entry.rooms) do
            if lookupSet[r] then
                table.insert(results, entry)
                break
            end
        end
    end
    return results
end

---------------------------------------------------------------
-- Room types of interest for recon missions
---------------------------------------------------------------

--- All room names that are valid recon targets across all tiers.
POS_BuildingCache.RECON_ROOMS = {
    -- Tier I
    "bathroom", "kitchen", "office", "livingroom",
    -- Tier II
    "pharmacy", "medical", "grocerystorage", "store", "classroom",
    -- Tier III
    "policestation", "security", "firestation", "warehouse", "storage",
    "factory", "industrial",
    -- Tier IV
    "hospitalroom", "prisoncell", "mall", "military",
}

---------------------------------------------------------------
-- Passive scanning
---------------------------------------------------------------

--- One-time retroactive scan on first mod load.
--- Scans a large radius to catch buildings the player has already visited.
--- Gated by modData flag so it only runs once per save.
function POS_BuildingCache.initialScan()
    local player = getSpecificPlayer(0)
    if not player then return end

    local md = player:getModData()
    if not md then return end
    if md[INITIAL_SCAN_FLAG] then return end

    if not POS_Sandbox or not POS_Sandbox.isReconEnabled
       or not POS_Sandbox.isReconEnabled() then return end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())

    -- Large radius scan (loaded chunks, typically ~300 tiles in SP)
    local scanRadius = POS_Sandbox and POS_Sandbox.getInitialScanRadius
        and POS_Sandbox.getInitialScanRadius() or INITIAL_SCAN_RADIUS
    local buildings = PhobosLib.findNearbyBuildings(
        px, py, scanRadius, POS_BuildingCache.RECON_ROOMS)

    local added = 0
    for _, b in ipairs(buildings) do
        if POS_BuildingCache.addToCache(b.x, b.y, b.matchingRooms) then
            added = added + 1
        end
    end

    md[INITIAL_SCAN_FLAG] = true

    PhobosLib.debug("POS", "[BuildingCache] Initial scan complete: "
        .. added .. " new buildings from " .. #buildings .. " found")
end

--- Scan nearby loaded buildings and cache interesting ones.
--- Called periodically (every in-game minute).
function POS_BuildingCache.passiveScan()
    if not POS_Sandbox or not POS_Sandbox.isReconEnabled
       or not POS_Sandbox.isReconEnabled() then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())

    local scanRadius = POS_Sandbox and POS_Sandbox.getPassiveScanRadius
        and POS_Sandbox.getPassiveScanRadius() or PASSIVE_SCAN_RADIUS
    local buildings = PhobosLib.findNearbyBuildings(
        px, py, scanRadius, POS_BuildingCache.RECON_ROOMS)

    for _, b in ipairs(buildings) do
        POS_BuildingCache.addToCache(b.x, b.y, b.matchingRooms)
    end
end
