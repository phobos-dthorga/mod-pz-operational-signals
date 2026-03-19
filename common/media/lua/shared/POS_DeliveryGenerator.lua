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
-- POS_DeliveryGenerator.lua
-- Generates delivery missions with mailbox pairs, distance-based
-- rewards, and expiry tracking.
--
-- Reward: $1,000 (5 min at 65 MPH) to $2,500 (12.5 min at 65 MPH)
-- Distance baseline: Muldraugh-to-Louisville road distance (~11,000 tiles)
-- All distance constants are sandbox-tunable.
---------------------------------------------------------------

require "PhobosLib"
require "POS_MailboxScanner"

POS_DeliveryGenerator = POS_DeliveryGenerator or {}

--- Reward bounds.
local MIN_REWARD = 1000
local MAX_REWARD = 2500

--- Number of days after creation before a delivery expires.
local DELIVERY_EXPIRY_DAYS = 3

--- Calculate reward from road distance (linear interpolation).
--- Called at accept time with estimated distance, and again at
--- completion with actual PathTracker distance.
---@param roadDistance number Distance in tiles (road/driven)
---@return number Reward in dollars (integer)
function POS_DeliveryGenerator.calculateReward(roadDistance)
    local minDist = POS_Sandbox and POS_Sandbox.getMinDeliveryDistance
        and POS_Sandbox.getMinDeliveryDistance() or 4400
    local maxDist = POS_Sandbox and POS_Sandbox.getMaxDeliveryDistance
        and POS_Sandbox.getMaxDeliveryDistance() or 11000

    local t = 0
    if maxDist > minDist then
        t = (roadDistance - minDist) / (maxDist - minDist)
    end
    t = math.max(0, math.min(1, t))
    return math.floor(MIN_REWARD + t * (MAX_REWARD - MIN_REWARD))
end

--- Generate a delivery operation for a player.
--- Selects a mailbox pair from the player-discovered cache
--- and creates an operation table with distance-based reward.
---@param player any IsoPlayer (unused — cache is player-specific)
---@return table|nil Operation table, or nil if no valid pair found
function POS_DeliveryGenerator.generate(player)
    if not player then return nil end

    local pair = POS_MailboxScanner.selectDeliveryPair()

    if not pair then
        PhobosLib.debug("POS", "[DeliveryGen] No valid mailbox pair found")
        return nil
    end

    local roadFactor = POS_Sandbox and POS_Sandbox.getDeliveryRoadFactor
        and POS_Sandbox.getDeliveryRoadFactor() or 1.3
    local estimatedRoad = pair.straightLine * roadFactor
    local estimatedReward = POS_DeliveryGenerator.calculateReward(estimatedRoad)

    local gameTime = getGameTime()
    local currentDay = gameTime and gameTime:getNightsSurvived() or 0

    local operation = {
        id = "POS_DEL_" .. tostring(getTimestampMs()),
        templateId = "pos_delivery_antibiotics",
        category = "Courier",
        difficulty = estimatedRoad > POS_Constants.DELIVERY_DIFFICULTY_THRESHOLD
            and POS_Constants.DIFFICULTY_MEDIUM or POS_Constants.DIFFICULTY_EASY,
        status = POS_Constants.STATUS_AVAILABLE,
        objectives = {
            {
                type = POS_Constants.OBJECTIVE_TYPE_DELIVERY,
                itemType = "Base.Antibiotics",
                pickupX = pair.pickup.x,
                pickupY = pair.pickup.y,
                dropoffX = pair.dropoff.x,
                dropoffY = pair.dropoff.y,
                pickedUp = false,
                completed = false,
            },
        },
        straightLineDistance = pair.straightLine,
        estimatedRoadDistance = estimatedRoad,
        estimatedReward = estimatedReward,
        createdDay = currentDay,
        expiryDay = currentDay + (POS_Sandbox and POS_Sandbox.getDeliveryExpiryDays
            and POS_Sandbox.getDeliveryExpiryDays() or DELIVERY_EXPIRY_DAYS),
    }

    PhobosLib.debug("POS", "[DeliveryGen] Generated delivery: "
        .. math.floor(pair.straightLine) .. " tiles straight-line, "
        .. math.floor(estimatedRoad) .. " tiles estimated road, "
        .. "$" .. estimatedReward .. " est. reward")

    return operation
end
