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
-- POS_RadioPower.lua
-- Signal strength calculation for POSnet radio connections.
--
-- Uses inverse square law: signal = clamp(0, 1, (power / ref)^2)
-- Delegates hardware detection to PhobosLib_Radio.
---------------------------------------------------------------

require "PhobosLib"

POS_RadioPower = {}

---------------------------------------------------------------
-- Signal strength calculation
---------------------------------------------------------------

--- Get the transmit power of a radio.
--- Delegates to PhobosLib_Radio.getTransmitRange().
---@param radioObj any InventoryItem or IsoWaveSignal
---@return number TransmitRange value
function POS_RadioPower.getPower(radioObj)
    if PhobosLib_Radio and PhobosLib_Radio.getTransmitRange then
        return PhobosLib_Radio.getTransmitRange(radioObj)
    end
    return 0
end

--- Calculate signal strength using inverse square law.
--- Formula: signal = clamp(0, 1, (radioPower / referencePower)^2)
---@param radioPower number TransmitRange of the radio
---@return number signalStrength 0.0 to 1.0
function POS_RadioPower.calculateSignalStrength(radioPower)
    if not POS_Sandbox.isSignalStrengthEnabled() then
        return 1.0
    end
    local refPower = POS_Sandbox.getSignalReferencePower()
    if refPower <= 0 then return 1.0 end
    local ratio = (radioPower or 0) / refPower
    return math.min(1.0, math.max(0, ratio * ratio))
end

--- Check if a signal strength meets the minimum connection threshold.
---@param signalStrength number 0.0 to 1.0
---@return boolean
function POS_RadioPower.meetsThreshold(signalStrength)
    if not POS_Sandbox.isSignalStrengthEnabled() then
        return true
    end
    local threshold = POS_Sandbox.getMinSignalThreshold()
    return (signalStrength or 0) >= threshold
end

--- Calculate reward multiplier based on signal strength.
--- Returns 0.5 + 0.5 * signal (range: 50%–100%).
---@param signalStrength number 0.0 to 1.0
---@return number multiplier 0.5 to 1.0
function POS_RadioPower.getRewardMultiplier(signalStrength)
    if not POS_Sandbox.isSignalStrengthEnabled() then
        return 1.0
    end
    local clamped = math.min(1.0, math.max(0, signalStrength or 0))
    return 0.5 + 0.5 * clamped
end

--- Signal quality thresholds.
local SIGNAL_EXCELLENT = 0.8
local SIGNAL_GOOD = 0.5
local SIGNAL_WEAK = 0.25

--- Get a translation key describing signal quality.
---@param signalStrength number 0.0 to 1.0
---@return string translationKey
function POS_RadioPower.getQualityKey(signalStrength)
    if signalStrength >= SIGNAL_EXCELLENT then return "UI_POS_Signal_Excellent" end
    if signalStrength >= SIGNAL_GOOD then return "UI_POS_Signal_Good" end
    if signalStrength >= SIGNAL_WEAK then return "UI_POS_Signal_Weak" end
    return "UI_POS_Signal_Critical"
end
