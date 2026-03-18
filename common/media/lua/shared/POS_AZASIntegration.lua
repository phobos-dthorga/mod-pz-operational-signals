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
-- POS_AZASIntegration.lua
-- Registers POSnet with AZAS Frequency Index as two stations:
--   - POSnet_Operations (amateur band) — civilian ops
--   - POSnet_Tactical   (military band) — combat ops
--
-- Must execute at module-load time (before OnGameStart) so
-- that AZAS_FrequencyIndex.apply() picks up the stations.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_AZASIntegration = {}

---------------------------------------------------------------
-- Station registration (runs at require-time)
---------------------------------------------------------------

AZAS_STATIONS = AZAS_STATIONS or {}

AZAS_STATIONS[POS_Constants.AZAS_OPS_KEY] = {
    id           = POS_Constants.AZAS_OPS_KEY,
    name         = "POSnet Operations Network",
    device_type  = "amateur",
    frequency_request = POS_Constants.AZAS_DEFAULT_OPS_FREQ,
}

AZAS_STATIONS[POS_Constants.AZAS_TAC_KEY] = {
    id           = POS_Constants.AZAS_TAC_KEY,
    name         = "POSnet Tactical Network",
    device_type  = "military",
    frequency_request = POS_Constants.AZAS_DEFAULT_TAC_FREQ,
}

PhobosLib.debug("POS", "[AZAS] Registered POSnet_Operations (amateur, req 130.0 kHz)"
    .. " and POSnet_Tactical (military, req 155.0 kHz)")

---------------------------------------------------------------
-- Frequency accessors (cached after first AZAS lookup)
---------------------------------------------------------------

local cachedOpsFreq = nil
local cachedTacFreq = nil

--- Get the AZAS-assigned frequency for the Operations (amateur) station.
---@return number frequency in Hz
function POS_AZASIntegration.getOperationsFrequency()
    if cachedOpsFreq then return cachedOpsFreq end
    if AZAS_FrequencyIndex and AZAS_FrequencyIndex.assignFrequency then
        local freq = AZAS_FrequencyIndex.assignFrequency(
            POS_Constants.AZAS_OPS_KEY, "amateur", POS_Constants.AZAS_DEFAULT_OPS_FREQ)
        if freq then
            cachedOpsFreq = freq
            return freq
        end
    end
    return POS_Constants.AZAS_DEFAULT_OPS_FREQ
end

--- Get the AZAS-assigned frequency for the Tactical (military) station.
---@return number frequency in Hz
function POS_AZASIntegration.getTacticalFrequency()
    if cachedTacFreq then return cachedTacFreq end
    if AZAS_FrequencyIndex and AZAS_FrequencyIndex.assignFrequency then
        local freq = AZAS_FrequencyIndex.assignFrequency(
            POS_Constants.AZAS_TAC_KEY, "military", POS_Constants.AZAS_DEFAULT_TAC_FREQ)
        if freq then
            cachedTacFreq = freq
            return freq
        end
    end
    return POS_Constants.AZAS_DEFAULT_TAC_FREQ
end

--- Backward-compatible accessor (returns operations frequency).
---@return number frequency in Hz
function POS_AZASIntegration.getFrequency()
    return POS_AZASIntegration.getOperationsFrequency()
end

--- Match a tuned frequency against both POSnet stations.
--- Returns the band name if it matches, or nil.
---@param tunedFreq number The radio's current tuned frequency
---@return string|nil "operations", "tactical", or nil
function POS_AZASIntegration.matchFrequency(tunedFreq)
    if not tunedFreq then return nil end
    if tunedFreq == POS_AZASIntegration.getOperationsFrequency() then
        return "operations"
    end
    if tunedFreq == POS_AZASIntegration.getTacticalFrequency() then
        return "tactical"
    end
    return nil
end

--- Clear cached frequencies (for testing / world reload).
function POS_AZASIntegration.clearCache()
    cachedOpsFreq = nil
    cachedTacFreq = nil
end
