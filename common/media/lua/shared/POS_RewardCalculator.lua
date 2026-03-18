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

--- Scale a base currency reward by the global RewardMultiplier.
---@param baseReward number Base reward in dollars
---@return number Scaled reward (integer)
function POS_RewardCalculator.scaleReward(baseReward)
    local multiplier = POS_Sandbox and POS_Sandbox.getRewardMultiplier
        and POS_Sandbox.getRewardMultiplier() or 100
    return math.floor((baseReward or 0) * multiplier / 100)
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

    PhobosLib.debug("POS", "[Reward] Paid $" .. actualReward
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
