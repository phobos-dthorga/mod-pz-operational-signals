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
-- POS_Reputation.lua
-- POSnet reputation system — tracks player standing and gates
-- mission tiers based on accumulated reputation.
--
-- Wraps PhobosLib.{get,set,add}PlayerReputation() with
-- POSnet-specific tier logic and sandbox-driven caps.
--
-- Tiers:
--   I   Untrusted    0–249     Low risk recon
--   II  Known        250–749   Moderate risk recon
--   III Trusted      750–1499  Elevated risk recon
--   IV  Established  1500–2499 High risk recon
--       Legendary    2500      All content unlocked
---------------------------------------------------------------

require "PhobosLib"

POS_Reputation = POS_Reputation or {}

local _TAG = "[POS:Reputation]"

--- Reputation mod key for PhobosLib storage.
local MOD_KEY = "POS"

---------------------------------------------------------------
-- Core accessors
---------------------------------------------------------------

--- Get the player's current POSnet reputation.
---@param player any IsoPlayer (nil → getSpecificPlayer(0))
---@return number Reputation (0 to cap)
function POS_Reputation.get(player)
    player = player or getSpecificPlayer(0)
    if not player then return 0 end
    return PhobosLib.getPlayerReputation(player, MOD_KEY, 0)
end

--- Set the player's POSnet reputation (clamped to 0..cap).
---@param player any IsoPlayer
---@param value number New reputation
function POS_Reputation.set(player, value)
    player = player or getSpecificPlayer(0)
    if not player then return end
    local cap = POS_Sandbox and POS_Sandbox.getReputationCap
        and POS_Sandbox.getReputationCap() or 2500
    PhobosLib.setPlayerReputation(player, MOD_KEY, value, 0, cap)
end

--- Add reputation (positive or negative), clamped to 0..cap.
--- Applies ReputationMultiplier sandbox scaling to the delta.
---@param player any IsoPlayer
---@param baseDelta number Base reputation change (before scaling)
---@return number New reputation after change
function POS_Reputation.add(player, baseDelta)
    player = player or getSpecificPlayer(0)
    if not player then return 0 end

    local multiplier = POS_Sandbox and POS_Sandbox.getReputationMultiplier
        and POS_Sandbox.getReputationMultiplier() or 100
    local scaledDelta = math.floor(baseDelta * multiplier / 100)

    local cap = POS_Sandbox and POS_Sandbox.getReputationCap
        and POS_Sandbox.getReputationCap() or 2500

    local newVal = PhobosLib.addPlayerReputation(
        player, MOD_KEY, scaledDelta, 0, cap)

    if scaledDelta ~= 0 then
        PhobosLib.debug("POS", _TAG, "[Reputation] "
            .. (scaledDelta > 0 and "+" or "") .. scaledDelta
            .. " (base " .. baseDelta .. " × " .. multiplier .. "%)"
            .. " → " .. newVal)
    end

    return newVal
end

---------------------------------------------------------------
-- Tier system
---------------------------------------------------------------

--- Tier definitions in ascending order.
--- Each: { id, name, translationKey, minRep }
POS_Reputation.TIERS = {
    { id = 1, name = "Untrusted",   key = "UI_POS_Rep_Tier_Untrusted",   minRep = 0 },
    { id = 2, name = "Known",       key = "UI_POS_Rep_Tier_Known",       minRep = 250 },
    { id = 3, name = "Trusted",     key = "UI_POS_Rep_Tier_Trusted",     minRep = 750 },
    { id = 4, name = "Established", key = "UI_POS_Rep_Tier_Established", minRep = 1500 },
    { id = 5, name = "Legendary",   key = "UI_POS_Rep_Tier_Legendary",   minRep = 2500 },
}

--- Get the player's current reputation tier (1-5).
---@param player any IsoPlayer
---@return number Tier ID (1-5)
function POS_Reputation.getTier(player)
    local rep = POS_Reputation.get(player)

    -- Use sandbox thresholds if available
    local thresholds = {
        0,
        POS_Sandbox and POS_Sandbox.getTierIIReputationReq and POS_Sandbox.getTierIIReputationReq() or 250,
        POS_Sandbox and POS_Sandbox.getTierIIIReputationReq and POS_Sandbox.getTierIIIReputationReq() or 750,
        POS_Sandbox and POS_Sandbox.getTierIVReputationReq and POS_Sandbox.getTierIVReputationReq() or 1500,
        POS_Sandbox and POS_Sandbox.getReputationCap and POS_Sandbox.getReputationCap() or 2500,
    }

    local tier = 1
    for i = #thresholds, 1, -1 do
        if rep >= thresholds[i] then
            tier = i
            break
        end
    end
    return tier
end

--- Get the tier definition for a given tier ID.
---@param tierId number 1-5
---@return table|nil Tier definition
function POS_Reputation.getTierDef(tierId)
    return POS_Reputation.TIERS[tierId]
end

--- Get the player's tier definition.
---@param player any IsoPlayer
---@return table Tier definition
function POS_Reputation.getPlayerTierDef(player)
    return POS_Reputation.TIERS[POS_Reputation.getTier(player)]
end

--- Check if the player's reputation meets a required tier.
---@param player any IsoPlayer
---@param requiredTier number Tier ID (1-4)
---@return boolean
function POS_Reputation.meetsTier(player, requiredTier)
    return POS_Reputation.getTier(player) >= (requiredTier or 1)
end

--- Get the maximum mission tier the player can access.
--- Returns 1-4 (Legendary tier 5 doesn't add new mission content,
--- just represents max standing).
---@param player any IsoPlayer
---@return number Max accessible mission tier (1-4)
function POS_Reputation.getMaxMissionTier(player)
    return math.min(POS_Reputation.getTier(player), 4)
end
