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
-- POS_SIGINTTraits.lua
-- Trait effect queries for the 6 SIGINT character traits.
-- Pure read-only queries — traits are registered in
-- registries.lua and defined in POS_Traits.txt.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_SIGINTTraits = {}

---------------------------------------------------------------
-- XP Modifiers
---------------------------------------------------------------

--- Get the combined XP rate modifier for the player's traits.
--- Returns a multiplier (1.0 = no change, 1.25 = +25%, 0.75 = -25%).
---@param player IsoPlayer
---@return number XP multiplier
function POS_SIGINTTraits.getXPModifier(player)
    if not player then return 1.0 end

    local modifier = 1.0

    -- Analytical Mind: +25% SIGINT XP
    if PhobosLib.hasTrait(player, POS_Constants.TRAIT_ANALYTICAL_MIND) then
        modifier = modifier + POS_Constants.TRAIT_ANALYTICAL_MIND_XP_BONUS
    end

    -- Disorganised Thinker: -25% SIGINT XP
    if PhobosLib.hasTrait(player, POS_Constants.TRAIT_DISORGANISED_THINKER) then
        modifier = modifier - POS_Constants.TRAIT_DISORGANISED_XP_PENALTY
    end

    return math.max(0.1, modifier)  -- floor at 10% to prevent zero XP
end

---------------------------------------------------------------
-- Noise Modifier
---------------------------------------------------------------

--- Get the noise penalty from traits (Disorganised Thinker).
--- Returns a fraction representing the penalty (0.0 = no penalty, 0.20 = +20%).
---@param player IsoPlayer
---@return number Noise penalty fraction
function POS_SIGINTTraits.getNoisePenalty(player)
    if not player then return 0 end

    if PhobosLib.hasTrait(player, POS_Constants.TRAIT_DISORGANISED_THINKER) then
        return POS_Constants.TRAIT_DISORGANISED_NOISE_PENALTY
    end
    return 0
end

---------------------------------------------------------------
-- Time Modifier
---------------------------------------------------------------

--- Get the time penalty from traits (Impatient).
--- Returns a fraction representing additional time (0.0 = none, 0.30 = +30%).
---@param player IsoPlayer
---@return number Time penalty fraction
function POS_SIGINTTraits.getTimePenalty(player)
    if not player then return 0 end

    if PhobosLib.hasTrait(player, POS_Constants.TRAIT_IMPATIENT) then
        return POS_Constants.TRAIT_IMPATIENT_TIME_PENALTY
    end
    return 0
end

---------------------------------------------------------------
-- Cross-Correlation Override
---------------------------------------------------------------

--- Get the cross-correlation unlock level if overridden by a trait.
--- Systems Thinker lowers the threshold from L6 to L4.
---@param player IsoPlayer
---@return number|nil Override level, or nil if no trait override
function POS_SIGINTTraits.getCrossCorrelationLevel(player)
    if not player then return nil end

    if PhobosLib.hasTrait(player, POS_Constants.TRAIT_SYSTEMS_THINKER) then
        return POS_Constants.TRAIT_SYSTEMS_THINKER_CROSSCOR
    end
    return nil
end

---------------------------------------------------------------
-- Level Cap (Signal Blindness)
---------------------------------------------------------------

--- Whether the player has a SIGINT level cap from traits.
---@param player IsoPlayer
---@return boolean
function POS_SIGINTTraits.isLevelCapped(player)
    if not player then return false end

    return PhobosLib.hasTrait(player, POS_Constants.TRAIT_SIGNAL_BLINDNESS)
end

--- Get the SIGINT level cap for the player.
--- Returns nil if no cap applies.
---@param player IsoPlayer
---@return number|nil Hard level cap, or nil
function POS_SIGINTTraits.getLevelCap(player)
    if POS_SIGINTTraits.isLevelCapped(player) then
        return POS_Constants.TRAIT_SIGNAL_BLINDNESS_CAP
    end
    return nil
end

---------------------------------------------------------------
-- Radio Scan Bonus (Radio Hobbyist)
---------------------------------------------------------------

--- Get the radio scan radius bonus from traits.
--- Returns a fraction (0.0 = none, 0.20 = +20%).
---@param player IsoPlayer
---@return number Scan radius bonus fraction
function POS_SIGINTTraits.getRadioScanBonus(player)
    if not player then return 0 end

    if PhobosLib.hasTrait(player, POS_Constants.TRAIT_RADIO_HOBBYIST) then
        return POS_Constants.TRAIT_RADIO_HOBBYIST_SCAN_BONUS
    end
    return 0
end
