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
-- POS_RewardCalculator.lua
-- Unified reward and reputation scaling for all POSnet systems.
--
-- All base reward/reputation values pass through this module's
-- scalers, which apply the global RewardMultiplier and
-- ReputationMultiplier sandbox settings.
---------------------------------------------------------------

require "PhobosLib"

POS_RewardCalculator = POS_RewardCalculator or {}

local _TAG = "[POS:Reward]"

--- Cancellation penalty multiplier step per tier above I.
local TIER_MULTIPLIER_STEP = 0.5

--- Discount applied to cancellation penalty when player has made progress.
local PROGRESS_DISCOUNT = 0.75

--- Scale a base currency reward by the global RewardMultiplier.
---@param baseReward number Base reward in dollars
---@return number Scaled reward (integer)
function POS_RewardCalculator.scaleReward(baseReward)
    local multiplier = POS_Sandbox and POS_Sandbox.getRewardMultiplier
        and POS_Sandbox.getRewardMultiplier() or 100

    -- Apply signal strength multiplier from active terminal
    local signalMult = 1.0
    if POS_RadioPower and POS_RadioPower.getRewardMultiplier
       and POS_TerminalUI and POS_TerminalUI.instance
       and POS_TerminalUI.instance.signalStrength then
        signalMult = POS_RadioPower.getRewardMultiplier(
            POS_TerminalUI.instance.signalStrength)
    end

    return math.floor((baseReward or 0) * multiplier / 100 * signalMult)
end

--- Scale a base reputation delta by the global ReputationMultiplier.
--- Note: POS_Reputation.add() already applies this scaling internally.
--- Use this only when you need the scaled value without applying it.
---@param baseRep number Base reputation delta
---@return number Scaled reputation (integer)
function POS_RewardCalculator.scaleReputation(baseRep)
    local multiplier = POS_Sandbox and POS_Sandbox.getReputationMultiplier
        and POS_Sandbox.getReputationMultiplier() or 100
    return math.floor((baseRep or 0) * multiplier / 100)
end

--- Pay a player currency reward (scaled) and grant reputation (scaled).
--- Convenience function that combines both operations.
---@param player any IsoPlayer
---@param baseReward number Base currency reward
---@param baseReputation number Base reputation grant
---@return number actualReward The scaled reward paid
---@return number newReputation The player's new reputation
function POS_RewardCalculator.payReward(player, baseReward, baseReputation)
    if not player then return 0, 0 end

    local actualReward = POS_RewardCalculator.scaleReward(baseReward)
    if actualReward > 0 then
        PhobosLib.addMoney(player, actualReward)
    end

    local newRep = 0
    if baseReputation and baseReputation ~= 0 then
        newRep = POS_Reputation.add(player, baseReputation)
    end

    PhobosLib.debug("POS", _TAG, "[Reward] Paid $" .. actualReward
        .. " (base $" .. (baseReward or 0) .. ")"
        .. (baseReputation and baseReputation ~= 0
            and (", rep +" .. baseReputation) or ""))

    return actualReward, newRep
end

--- Apply a reputation penalty (e.g. for mission expiry/abandonment).
---@param player any IsoPlayer
---@param basePenalty number Base penalty (positive number, applied as negative)
---@return number New reputation after penalty
function POS_RewardCalculator.applyPenalty(player, basePenalty)
    if not player or not basePenalty or basePenalty <= 0 then return 0 end
    return POS_Reputation.add(player, -basePenalty)
end

--- Calculate the cancellation penalty for an operation (pure computation).
--- Tier I missions have zero penalty. Tiers II-IV scale upward.
--- Deliveries use a separate base penalty; doubles if package picked up.
--- A 25% progress discount applies if the player started objectives.
---@param operation table Operation data table
---@return number penalty The computed penalty (≥0)
local function calculateCancellationPenalty(operation)
    if not operation then return 0 end

    if POS_Sandbox and POS_Sandbox.isCancellationPenaltyEnabled
       and not POS_Sandbox.isCancellationPenaltyEnabled() then
        return 0
    end

    local tier = operation.tier or 1
    if tier <= 1 then return 0 end

    local obj = operation.objectives and operation.objectives[1]
    local isDelivery = obj and obj.type == POS_Constants.OBJECTIVE_TYPE_DELIVERY

    local basePenalty
    if isDelivery then
        basePenalty = POS_Sandbox and POS_Sandbox.getBaseCancelPenaltyDelivery
            and POS_Sandbox.getBaseCancelPenaltyDelivery() or 15
        if obj and obj.pickedUp then basePenalty = basePenalty * 2 end
    else
        basePenalty = POS_Sandbox and POS_Sandbox.getBaseCancelPenalty
            and POS_Sandbox.getBaseCancelPenalty() or 30
    end

    local tierMultiplier = (tier - 1) * TIER_MULTIPLIER_STEP
    local penalty = math.floor(basePenalty * tierMultiplier)

    if obj then
        local hasProgress = obj.entered or obj.photographed
            or obj.notesWritten or obj.pickedUp
        if hasProgress then
            penalty = math.floor(penalty * PROGRESS_DISCOUNT)
        end
    end

    return math.max(0, penalty)
end

--- Calculate and apply the cancellation reputation penalty for an operation.
---@param player any IsoPlayer
---@param operation table Operation data table
---@return number penalty The actual penalty applied (0 if none)
function POS_RewardCalculator.applyCancellationPenalty(player, operation)
    if not player or not operation then return 0 end

    local penalty = calculateCancellationPenalty(operation)
    if penalty <= 0 then return 0 end

    local newRep = POS_Reputation.add(player, -penalty)

    PhobosLib.debug("POS", _TAG, "[Reward] Cancel penalty: -" .. penalty
        .. " rep (tier=" .. (operation.tier or 1)
        .. ") → " .. newRep)

    return penalty
end

--- Preview the cancellation penalty without applying it.
---@param operation table Operation data table
---@return number penalty The penalty that would be applied
function POS_RewardCalculator.previewCancellationPenalty(operation)
    return calculateCancellationPenalty(operation)
end
