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
-- Player-discovered mailbox cache for delivery missions.
--
-- Mailboxes are cached in player modData as they are discovered
-- through right-click interaction (POS_DeliveryContextMenu).
-- The cache persists across saves and grows as the player explores.
--
-- Sprite IDs sourced from Paper Trails mod research:
--   Residential mailboxes: street_decoration_01_18..21
--   Collection/post boxes: street_decoration_01_8..11
---------------------------------------------------------------

require "PhobosLib"

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

--- ModData key for the mailbox cache.
local CACHE_KEY = "POS_DiscoveredMailboxes"

--- Minimum distance between two cached mailboxes to avoid duplicates (tiles).
local DEDUP_RADIUS = 3

---------------------------------------------------------------
-- Cache management
---------------------------------------------------------------

--- Get the discovered mailbox cache from player modData.
--- Each entry: { x = number, y = number }
---@return table Array of { x, y } positions
function POS_MailboxScanner.getCache()
    local player = getSpecificPlayer(0)
    if not player then return {} end
    local md = player:getModData()
    if not md then return {} end
    md[CACHE_KEY] = md[CACHE_KEY] or {}
    return md[CACHE_KEY]
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
-- Pair selection (from cache)
---------------------------------------------------------------

--- Select a valid pair of mailboxes for a delivery mission.
--- Uses the player-discovered cache rather than scanning loaded chunks.
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
    local attempts = math.min(100, #cache * (#cache - 1))
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
    local maxI = math.min(#cache, 50)
    for i = 1, maxI do
        for j = i + 1, math.min(i + 30, #cache) do
            local dist = PhobosLib.euclideanDistance(
                cache[i].x, cache[i].y,
                cache[j].x, cache[j].y)
            -- Accept any pair with at least 20 tiles separation
            if dist > bestDist and dist >= 20 then
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
