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
-- Delegates signal composite to POS_SignalEcologyService.
-- Delegates hardware detection to PhobosLib_Radio.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

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

--- Calculate signal strength via the Signal Ecology service.
--- Delegates to POS_SignalEcologyService for the five-pillar composite value.
--- Falls back to SIGNAL_FALLBACK_COMPOSITE if the ecology service is unavailable.
---@param _radioPower number (unused — retained for API compatibility)
---@return number signalStrength 0.0 to 1.0
function POS_RadioPower.calculateSignalStrength(_radioPower)
    if POS_SignalEcologyService and POS_SignalEcologyService.getComposite then
        return POS_SignalEcologyService.getComposite()
    end
    return POS_Constants.SIGNAL_FALLBACK_COMPOSITE
end

--- Check if a signal strength meets the minimum connection threshold.
---@param signalStrength number 0.0 to 1.0
---@return boolean
function POS_RadioPower.meetsThreshold(signalStrength)
    local threshold = POS_Sandbox.getMinSignalThreshold()
    return (signalStrength or 0) >= threshold
end

--- Calculate reward multiplier based on signal strength.
--- Returns 0.5 + 0.5 * signal (range: 50%–100%).
---@param signalStrength number 0.0 to 1.0
---@return number multiplier 0.5 to 1.0
function POS_RadioPower.getRewardMultiplier(signalStrength)
    local clamped = math.min(1.0, math.max(0, signalStrength or 0))
    return 0.5 + 0.5 * clamped
end

--- Get a translation key describing signal quality via the 6-state ecology model.
--- Delegates to POS_SignalEcologyService for qualitative state resolution.
--- Falls back to "UI_POS_Signal_State_Faded" if the ecology service is unavailable.
---@param signalStrength number (unused — retained for API compatibility)
---@return string translationKey
function POS_RadioPower.getQualityKey(signalStrength)
    if POS_SignalEcologyService and POS_SignalEcologyService.getQualitativeState then
        local state = POS_SignalEcologyService.getQualitativeState()
        return "UI_POS_Signal_State_" .. state:sub(1, 1):upper() .. state:sub(2)
    end
    -- Fallback
    return "UI_POS_Signal_State_Faded"
end
