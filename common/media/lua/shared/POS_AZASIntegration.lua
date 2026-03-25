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
-- Registers POSnet with AZAS Frequency Index as four stations:
--   - POSnet_Operations  (amateur band)  — civilian data net
--   - POSnet_Tactical    (military band) — tactical data net
--   - POSnet_WBN_Market  (amateur band)  — Market Broadcast Service
--   - POSnet_WBN_Emergency (amateur band) — Emergency Broadcast Service
--
-- Must execute at module-load time (before OnGameStart) so
-- that AZAS_FrequencyIndex.apply() picks up the stations.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_WBN"

POS_AZASIntegration = {}

local _TAG = "[POS:AZAS]"

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

-- WBN broadcast channels (public radio — receivable on any civilian radio)
AZAS_STATIONS[POS_Constants.AZAS_WBN_MARKET_KEY] = {
    id           = POS_Constants.AZAS_WBN_MARKET_KEY,
    name         = "POSnet Market Broadcast Service",
    device_type  = "amateur",
    frequency_request = POS_Constants.WBN_DEFAULT_FREQ_CIVILIAN_MARKET,
}

AZAS_STATIONS[POS_Constants.AZAS_WBN_EMERGENCY_KEY] = {
    id           = POS_Constants.AZAS_WBN_EMERGENCY_KEY,
    name         = "POSnet Emergency Broadcast Service",
    device_type  = "amateur",
    frequency_request = POS_Constants.WBN_DEFAULT_FREQ_EMERGENCY,
}

PhobosLib.debug("POS", _TAG, "[AZAS] Registered 4 POSnet stations:"
    .. " Operations (amateur, 130.0 kHz), Tactical (military, 155.0 kHz),"
    .. " WBN_Market (amateur, 91.4 MHz), WBN_Emergency (amateur, 103.8 MHz)")

---------------------------------------------------------------
-- Frequency accessors (cached after first AZAS lookup)
---------------------------------------------------------------

local cachedOpsFreq = nil
local cachedTacFreq = nil
local cachedWbnMarketFreq = nil
local cachedWbnEmergencyFreq = nil

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

--- Get the AZAS-assigned frequency for the WBN Market Broadcast channel.
---@return number frequency in Hz
function POS_AZASIntegration.getWBNMarketFrequency()
    if cachedWbnMarketFreq then return cachedWbnMarketFreq end
    if AZAS_FrequencyIndex and AZAS_FrequencyIndex.assignFrequency then
        local freq = AZAS_FrequencyIndex.assignFrequency(
            POS_Constants.AZAS_WBN_MARKET_KEY, "amateur",
            POS_Constants.WBN_DEFAULT_FREQ_CIVILIAN_MARKET)
        if freq then
            cachedWbnMarketFreq = freq
            return freq
        end
    end
    return POS_Constants.WBN_DEFAULT_FREQ_CIVILIAN_MARKET
end

--- Get the AZAS-assigned frequency for the WBN Emergency Broadcast channel.
---@return number frequency in Hz
function POS_AZASIntegration.getWBNEmergencyFrequency()
    if cachedWbnEmergencyFreq then return cachedWbnEmergencyFreq end
    if AZAS_FrequencyIndex and AZAS_FrequencyIndex.assignFrequency then
        local freq = AZAS_FrequencyIndex.assignFrequency(
            POS_Constants.AZAS_WBN_EMERGENCY_KEY, "amateur",
            POS_Constants.WBN_DEFAULT_FREQ_EMERGENCY)
        if freq then
            cachedWbnEmergencyFreq = freq
            return freq
        end
    end
    return POS_Constants.WBN_DEFAULT_FREQ_EMERGENCY
end

--- Match a tuned frequency against all POSnet stations (data + broadcast).
--- Returns the band name if it matches, or nil.
---@param tunedFreq number The radio's current tuned frequency
---@return string|nil "operations", "tactical", "wbn_market", "wbn_emergency", or nil
function POS_AZASIntegration.matchFrequency(tunedFreq)
    if not tunedFreq then return nil end
    if tunedFreq == POS_AZASIntegration.getOperationsFrequency() then
        return "operations"
    end
    if tunedFreq == POS_AZASIntegration.getTacticalFrequency() then
        return "tactical"
    end
    if tunedFreq == POS_AZASIntegration.getWBNMarketFrequency() then
        return "wbn_market"
    end
    if tunedFreq == POS_AZASIntegration.getWBNEmergencyFrequency() then
        return "wbn_emergency"
    end
    return nil
end

--- Clear cached frequencies (for testing / world reload).
function POS_AZASIntegration.clearCache()
    cachedOpsFreq = nil
    cachedTacFreq = nil
    cachedWbnMarketFreq = nil
    cachedWbnEmergencyFreq = nil
end
