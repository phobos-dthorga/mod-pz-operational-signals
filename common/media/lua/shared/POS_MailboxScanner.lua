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
-- Scans loaded world chunks for mailbox/postbox IsoObjects
-- by matching their tile sprite names.
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

--- Find all mailbox objects in loaded chunks within radius of a point.
--- Delegates to PhobosLib.findWorldObjectsBySprite().
---@param centerX number World X coordinate
---@param centerY number World Y coordinate
---@param radius number  Search radius in tiles
---@return table Array of { object, x, y, z }
function POS_MailboxScanner.findNearbyMailboxes(centerX, centerY, radius)
    return PhobosLib.findWorldObjectsBySprite(
        centerX, centerY, radius, POS_MailboxScanner.MAILBOX_SPRITES)
end

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

--- Select a valid pair of mailboxes for a delivery mission.
--- Finds mailboxes near the player and picks a pair whose
--- straight-line distance falls within the configured range.
---
--- The straight-line distance is divided by ROAD_FACTOR to
--- estimate road distance for distance constraint filtering.
---
---@param playerX number Player world X
---@param playerY number Player world Y
---@param scanRadius number Search radius in tiles
---@return table|nil { pickup={x,y}, dropoff={x,y}, straightLine=n } or nil
function POS_MailboxScanner.selectDeliveryPair(playerX, playerY, scanRadius)
    local mailboxes = POS_MailboxScanner.findNearbyMailboxes(
        playerX, playerY, scanRadius)

    if #mailboxes < 2 then return nil end

    local roadFactor = POS_Sandbox and POS_Sandbox.getDeliveryRoadFactor
        and POS_Sandbox.getDeliveryRoadFactor() or 1.3
    local minRoad = POS_Sandbox and POS_Sandbox.getMinDeliveryDistance
        and POS_Sandbox.getMinDeliveryDistance() or 4400
    local maxRoad = POS_Sandbox and POS_Sandbox.getMaxDeliveryDistance
        and POS_Sandbox.getMaxDeliveryDistance() or 11000

    -- Convert road distance constraints to straight-line equivalents
    local minStraight = minRoad / roadFactor
    local maxStraight = maxRoad / roadFactor

    -- Try random pairs (up to 50 attempts) to find a valid distance
    local attempts = math.min(50, #mailboxes * (#mailboxes - 1))
    for _ = 1, attempts do
        local a = mailboxes[ZombRand(#mailboxes) + 1]
        local b = mailboxes[ZombRand(#mailboxes) + 1]

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

    -- Fallback: pick the pair closest to target range midpoint
    local targetStraight = (minStraight + maxStraight) / 2
    local bestPair = nil
    local bestDelta = math.huge

    for i = 1, #mailboxes do
        for j = i + 1, math.min(i + 20, #mailboxes) do
            local dist = PhobosLib.euclideanDistance(
                mailboxes[i].x, mailboxes[i].y,
                mailboxes[j].x, mailboxes[j].y)
            if dist >= minStraight * 0.7 then
                local delta = math.abs(dist - targetStraight)
                if delta < bestDelta then
                    bestDelta = delta
                    bestPair = {
                        pickup = { x = mailboxes[i].x, y = mailboxes[i].y },
                        dropoff = { x = mailboxes[j].x, y = mailboxes[j].y },
                        straightLine = dist,
                    }
                end
            end
        end
    end

    return bestPair
end
