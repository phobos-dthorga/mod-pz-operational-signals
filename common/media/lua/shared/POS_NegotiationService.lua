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
-- POS_NegotiationService.lua
-- Shared service for mission negotiation logic.
-- Manages haggling attempts, success rolls, and reward/deadline
-- adjustments. UI screens delegate all state mutations here.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Reputation"

POS_NegotiationService = {}

---------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------

--- Prepare an operation for negotiation by recording original values.
---@param operation table  The operation table
function POS_NegotiationService.initNegotiation(operation)
    if not operation then return end
    operation.negotiationAttempts = operation.negotiationAttempts or 0

    if not operation.originalReward then
        local obj = operation.objectives and operation.objectives[1]
        local isDelivery = obj and obj.type == POS_Constants.OBJECTIVE_TYPE_DELIVERY
        if isDelivery then
            operation.originalReward = operation.estimatedReward
        else
            operation.originalReward = operation.scaledReward
        end
    end

    if not operation.originalExpiryDay then
        operation.originalExpiryDay = operation.expiryDay
    end
end

---------------------------------------------------------------
-- Query helpers
---------------------------------------------------------------

--- Check whether the operation has negotiation attempts remaining.
---@param operation table
---@return boolean
function POS_NegotiationService.canNegotiate(operation)
    if not operation then return false end
    local attempts = operation.negotiationAttempts or 0
    return attempts < POS_Constants.NEGOTIATE_MAX_ATTEMPTS
end

--- Get the number of attempts remaining.
---@param operation table
---@return number
function POS_NegotiationService.getAttemptsLeft(operation)
    if not operation then return 0 end
    return POS_Constants.NEGOTIATE_MAX_ATTEMPTS - (operation.negotiationAttempts or 0)
end

--- Calculate the success chance for a player's negotiation roll.
---@param player any IsoPlayer
---@return number  Chance as 0-100
function POS_NegotiationService.getSuccessChance(player)
    local tier = 1
    if POS_Reputation and POS_Reputation.getTier then
        tier = POS_Reputation.getTier(player)
    end
    local chances = POS_Constants.NEGOTIATE_TIER_CHANCES
    local base = chances[math.min(tier, #chances)] or chances[1]
    local bonus = POS_Sandbox and POS_Sandbox.getNegotiationSuccessBonus
        and POS_Sandbox.getNegotiationSuccessBonus() or 0
    return math.max(0, math.min(100, base + bonus))
end

---------------------------------------------------------------
-- Negotiation actions
---------------------------------------------------------------

--- Attempt to negotiate higher pay.
--- On success: reward increases, deadline shortens.
---@param operation table
---@param player any IsoPlayer
---@return boolean success, string resultKey  ("success" or "failed")
function POS_NegotiationService.attemptHigherPay(operation, player)
    if not operation or not player then return false, "failed" end

    operation.negotiationAttempts = (operation.negotiationAttempts or 0) + 1
    local chance = POS_NegotiationService.getSuccessChance(player)

    if PhobosLib.rollChance(chance) then
        local obj = operation.objectives and operation.objectives[1]
        local isDelivery = obj and obj.type == POS_Constants.OBJECTIVE_TYPE_DELIVERY
        local currentReward = isDelivery
            and (operation.estimatedReward or 0)
            or (operation.scaledReward or 0)
        local bonus = math.floor(currentReward * POS_Constants.NEGOTIATE_REWARD_BONUS_PCT / 100)

        if isDelivery then
            operation.estimatedReward = (operation.estimatedReward or 0) + bonus
        else
            operation.scaledReward = (operation.scaledReward or 0) + bonus
        end

        if operation.expiryDay then
            operation.expiryDay = operation.expiryDay - POS_Constants.NEGOTIATE_DAY_REDUCTION
        end

        operation.negotiated = true
        return true, "success"
    end

    return false, "failed"
end

--- Attempt to negotiate more time.
--- On success: deadline extends, reward decreases.
---@param operation table
---@param player any IsoPlayer
---@return boolean success, string resultKey  ("success" or "failed")
function POS_NegotiationService.attemptMoreTime(operation, player)
    if not operation or not player then return false, "failed" end

    operation.negotiationAttempts = (operation.negotiationAttempts or 0) + 1
    local chance = POS_NegotiationService.getSuccessChance(player)

    if PhobosLib.rollChance(chance) then
        local obj = operation.objectives and operation.objectives[1]
        local isDelivery = obj and obj.type == POS_Constants.OBJECTIVE_TYPE_DELIVERY
        local currentReward = isDelivery
            and (operation.estimatedReward or 0)
            or (operation.scaledReward or 0)
        local cut = math.floor(currentReward * POS_Constants.NEGOTIATE_REWARD_CUT_PCT / 100)

        if isDelivery then
            operation.estimatedReward = math.max(0, (operation.estimatedReward or 0) - cut)
        else
            operation.scaledReward = math.max(0, (operation.scaledReward or 0) - cut)
        end

        if operation.expiryDay then
            operation.expiryDay = operation.expiryDay + POS_Constants.NEGOTIATE_DAY_EXTENSION
        end

        operation.negotiated = true
        return true, "success"
    end

    return false, "failed"
end

--- Accept the current terms and activate the operation.
---@param operation table
function POS_NegotiationService.acceptOperation(operation)
    if not operation then return end
    operation.status = POS_Constants.STATUS_ACTIVE
end
