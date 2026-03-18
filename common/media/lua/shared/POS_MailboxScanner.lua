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
-- POS_MailboxScanner.lua
-- World-scoped mailbox cache for delivery missions.
--
-- Mailboxes are cached in world ModData via POS_WorldState
-- as they are discovered through right-click interaction
-- (POS_DeliveryContextMenu). The cache persists across saves
-- and grows as the player explores.
--
-- Sprite IDs sourced from Paper Trails mod research:
--   Residential mailboxes: street_decoration_01_18..21
--   Collection/post boxes: street_decoration_01_8..11
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MailboxScanner = POS_MailboxScanner or {}

--- Sprite names for mailbox/postbox objects.
POS_MailboxScanner.MAILBOX_SPRITES = {
    -- Residential mailboxes
    "street_decoration_01_18",
    "street_decoration_01_19",
    "street_decoration_01_20",
    "street_decoration_01_21",
    -- Collection / post boxes
    "street_decoration_01_8",
    "street_decoration_01_9",
    "street_decoration_01_10",
    "street_decoration_01_11",
}

--- Minimum distance between two cached mailboxes to avoid duplicates (tiles).
local DEDUP_RADIUS = 3

--- Scan radius for the one-time initial mailbox scan (tiles).
local INITIAL_SCAN_RADIUS = 250

--- Maximum random pair attempts for ideal-distance matching.
local MAX_PAIR_ATTEMPTS = 100

--- Maximum mailbox indices to sample in the fallback pair search.
local MAX_CACHE_SAMPLE = 50

--- Maximum inner-loop range when checking pairs in the fallback search.
local MAX_PAIR_CHECK = 30

--- Minimum separation between two mailboxes to form a valid pair (tiles).
local MIN_PAIR_DISTANCE = 20

---------------------------------------------------------------
-- Cache management
---------------------------------------------------------------

--- Get the discovered mailbox cache from world ModData.
--- Each entry: { x = number, y = number }
---@return table Array of { x, y } positions
function POS_MailboxScanner.getCache()
    if POS_WorldState and POS_WorldState.getMailboxes then
        local mailboxes = POS_WorldState.getMailboxes()
        mailboxes.entries = mailboxes.entries or {}
        return mailboxes.entries
    end
    -- Fallback for when world state not yet initialized
    return {}
end

--- Add a mailbox position to the discovery cache.
--- Deduplicates against existing entries within DEDUP_RADIUS.
---@param x number World X coordinate
---@param y number World Y coordinate
---@return boolean True if added (not a duplicate)
function POS_MailboxScanner.addToCache(x, y)
    local cache = POS_MailboxScanner.getCache()

    -- Check for nearby duplicate
    for _, entry in ipairs(cache) do
        if math.abs(entry.x - x) <= DEDUP_RADIUS
           and math.abs(entry.y - y) <= DEDUP_RADIUS then
            return false  -- Already known
        end
    end

    table.insert(cache, { x = x, y = y })

    PhobosLib.debug("POS", "[MailboxScanner] Discovered mailbox at "
        .. math.floor(x) .. ", " .. math.floor(y)
        .. " (total: " .. #cache .. ")")

    return true
end

--- Get total count of discovered mailboxes.
---@return number
function POS_MailboxScanner.getCacheCount()
    return #POS_MailboxScanner.getCache()
end

---------------------------------------------------------------
-- Sprite detection
---------------------------------------------------------------

--- Check if a sprite name is a mailbox sprite.
---@param spriteName string Sprite name to check
---@return boolean
function POS_MailboxScanner.isMailboxSprite(spriteName)
    if not spriteName then return false end
    for _, name in ipairs(POS_MailboxScanner.MAILBOX_SPRITES) do
        if spriteName == name then return true end
    end
    return false
end

---------------------------------------------------------------
-- Initial retroactive scan
---------------------------------------------------------------

--- One-time retroactive scan on first mod load.
--- Scans a large radius to catch mailboxes the player has already visited.
--- Gated by world ModData flag so it only runs once per save.
function POS_MailboxScanner.initialScan()
    local player = getSpecificPlayer(0)
    if not player then return end

    local meta = POS_WorldState and POS_WorldState.getMeta()
    if meta and meta.mailboxScanDone then return end

    if not POS_Sandbox or not POS_Sandbox.isDeliveryEnabled
       or not POS_Sandbox.isDeliveryEnabled() then return end

    -- Try loading from external cache first
    if POS_WorldState and POS_WorldState.loadMailboxCache then
        local cached = POS_WorldState.loadMailboxCache()
        if cached and #cached > 0 then
            for _, entry in ipairs(cached) do
                POS_MailboxScanner.addToCache(entry.x, entry.y)
            end
            PhobosLib.debug("POS", "[MailboxScanner] Loaded " .. tostring(#cached) .. " mailboxes from external cache")
        end
    end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())

    -- Large radius scan (loaded chunks)
    local scanRadius = POS_Sandbox and POS_Sandbox.getInitialScanRadius
        and POS_Sandbox.getInitialScanRadius() or INITIAL_SCAN_RADIUS
    local found = PhobosLib.findWorldObjectsBySprite(
        px, py, scanRadius, POS_MailboxScanner.MAILBOX_SPRITES)

    local added = 0
    for _, entry in ipairs(found) do
        if POS_MailboxScanner.addToCache(entry.x, entry.y) then
            added = added + 1
        end
    end

    if meta then meta.mailboxScanDone = true end

    -- Persist to external cache if new mailboxes were discovered
    if added > 0 and POS_WorldState and POS_WorldState.saveMailboxCache then
        POS_WorldState.saveMailboxCache()
    end

    PhobosLib.debug("POS", "[MailboxScanner] Initial scan complete: "
        .. added .. " new mailboxes from " .. #found .. " found")
end

---------------------------------------------------------------
-- Pair selection (from cache)
---------------------------------------------------------------

--- Select a valid pair of mailboxes for a delivery mission.
--- Uses the world-scoped cache rather than scanning loaded chunks.
---
---@return table|nil { pickup={x,y}, dropoff={x,y}, straightLine=n } or nil
function POS_MailboxScanner.selectDeliveryPair()
    local cache = POS_MailboxScanner.getCache()

    if #cache < 2 then
        PhobosLib.debug("POS",
            "[MailboxScanner] Not enough discovered mailboxes ("
            .. #cache .. "), need at least 2")
        return nil
    end

    local roadFactor = POS_Sandbox and POS_Sandbox.getDeliveryRoadFactor
        and POS_Sandbox.getDeliveryRoadFactor() or 1.3
    local minRoad = POS_Sandbox and POS_Sandbox.getMinDeliveryDistance
        and POS_Sandbox.getMinDeliveryDistance() or 4400
    local maxRoad = POS_Sandbox and POS_Sandbox.getMaxDeliveryDistance
        and POS_Sandbox.getMaxDeliveryDistance() or 11000

    -- Convert road distance constraints to straight-line equivalents
    local minStraight = minRoad / roadFactor
    local maxStraight = maxRoad / roadFactor

    -- Try random pairs (up to 100 attempts) for ideal distance
    local attempts = math.min(MAX_PAIR_ATTEMPTS, #cache * (#cache - 1))
    for _ = 1, attempts do
        local a = cache[ZombRand(#cache) + 1]
        local b = cache[ZombRand(#cache) + 1]

        if a ~= b then
            local dist = PhobosLib.euclideanDistance(a.x, a.y, b.x, b.y)
            if dist >= minStraight and dist <= maxStraight then
                return {
                    pickup = { x = a.x, y = a.y },
                    dropoff = { x = b.x, y = b.y },
                    straightLine = dist,
                }
            end
        end
    end

    -- Fallback: pick the best pair from whatever we have.
    -- Prefer the longest distance available (more interesting missions).
    local bestPair = nil
    local bestDist = 0

    -- Sample pairs (limit iterations for large caches)
    local maxI = math.min(#cache, MAX_CACHE_SAMPLE)
    for i = 1, maxI do
        for j = i + 1, math.min(i + MAX_PAIR_CHECK, #cache) do
            local dist = PhobosLib.euclideanDistance(
                cache[i].x, cache[i].y,
                cache[j].x, cache[j].y)
            -- Accept any pair with at least 20 tiles separation
            if dist > bestDist and dist >= MIN_PAIR_DISTANCE then
                bestDist = dist
                bestPair = {
                    pickup = { x = cache[i].x, y = cache[i].y },
                    dropoff = { x = cache[j].x, y = cache[j].y },
                    straightLine = dist,
                }
            end
        end
    end

    if bestPair then
        PhobosLib.debug("POS",
            "[MailboxScanner] Fallback pair: "
            .. math.floor(bestPair.straightLine) .. " tiles (target: "
            .. math.floor(minStraight) .. "-" .. math.floor(maxStraight) .. ")")
    end

    return bestPair
end
