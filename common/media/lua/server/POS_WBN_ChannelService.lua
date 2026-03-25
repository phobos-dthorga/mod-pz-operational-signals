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

--- POS_WBN_ChannelService — Server-side service that registers WBN
--- DynamicRadio channels and emits composed bulletins to the PZ radio system.
---
--- Follows the Unseasonal Weather UW_RF_DynamicChannel_Server.lua pattern:
--- channels are created via DynamicRadioChannel.new(), registered with the
--- script manager, and bulletins are emitted as RadioBroadCast instances.
---
--- @module POS_WBN_ChannelService

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_WBN"
require "POS_AZASIntegration"

local _TAG = "WBN:Channel"
POS_WBN_ChannelService = {}

--- Resolve the AZAS-assigned frequency for a WBN station class.
--- Falls back to the hardcoded default if AZAS is unavailable.
--- @param stationId string  Station class id
--- @return number           Frequency in Hz
local function resolveFrequency(stationId)
    if stationId == POS_Constants.WBN_STATION_CIVILIAN_MARKET then
        return POS_AZASIntegration.getWBNMarketFrequency()
    elseif stationId == POS_Constants.WBN_STATION_EMERGENCY then
        return POS_AZASIntegration.getWBNEmergencyFrequency()
    end
    return 0
end

-- Channel definitions (Phase 1: 2 channels)
-- NOTE: freq is resolved dynamically via resolveFrequency() at registration
-- time, not stored statically. The freq field here is a fallback default only.
local CHANNEL_DEFS = {
    {
        id       = POS_Constants.WBN_STATION_CIVILIAN_MARKET,
        nameKey  = POS_Constants.WBN_CHANNEL_NAME_CIVILIAN,
        freq     = POS_Constants.WBN_DEFAULT_FREQ_CIVILIAN_MARKET,
        uuid     = POS_Constants.WBN_UUID_CIVILIAN_MARKET,
        category = "Amateur",  -- resolved to ChannelCategory.Amateur at runtime
    },
    {
        id       = POS_Constants.WBN_STATION_EMERGENCY,
        nameKey  = POS_Constants.WBN_CHANNEL_NAME_EMERGENCY,
        freq     = POS_Constants.WBN_DEFAULT_FREQ_EMERGENCY,
        uuid     = POS_Constants.WBN_UUID_EMERGENCY,
        category = "Emergency",
    },
}

-- Cached channel references (keyed by station class id)
local _channels = {}

--- Resolve a ChannelCategory enum value from its string name.
--- Falls back to ChannelCategory.Other when the name is unrecognised.
--- @param catName string  Category name ("Amateur", "Emergency", etc.)
--- @return userdata|nil   The ChannelCategory enum value, or nil if unavailable
local function resolveCategoryEnum(catName)
    if ChannelCategory then
        return ChannelCategory[catName] or ChannelCategory.Other
    end
    return nil
end

--- Ensure all WBN channels are registered with PZ's DynamicRadio system.
--- Safe to call multiple times; already-registered channels are skipped.
--- Called automatically on Events.OnLoadRadioScripts and Events.OnGameStart.
--- @param scriptManager userdata|nil  Optional radio script manager override
function POS_WBN_ChannelService.ensureChannels(scriptManager)
    if not DynamicRadio then
        PhobosLib.debug("POS", _TAG, "DynamicRadio not available — skipping channel registration")
        return
    end
    if not DynamicRadioChannel or not DynamicRadioChannel.new then
        PhobosLib.debug("POS", _TAG, "DynamicRadioChannel.new not available — skipping")
        return
    end

    DynamicRadio.channels = DynamicRadio.channels or {}
    DynamicRadio.cache = DynamicRadio.cache or {}

    local mgr = scriptManager or (getRadioScriptManager and getRadioScriptManager())

    for _, def in ipairs(CHANNEL_DEFS) do
        -- Skip if already cached
        if DynamicRadio.cache[def.uuid] then
            _channels[def.id] = DynamicRadio.cache[def.uuid]
            goto nextDef
        end

        -- Resolve AZAS-assigned frequency (falls back to default)
        local freq = resolveFrequency(def.id)

        -- Avoid duplicate entries in the channel list
        local found = false
        for _, ch in ipairs(DynamicRadio.channels) do
            if ch.uuid == def.uuid then found = true; break end
        end
        if not found then
            table.insert(DynamicRadio.channels, {
                name     = PhobosLib.safeGetText(def.nameKey),
                freq     = freq,
                category = def.category,
                uuid     = def.uuid,
                register = true,
            })
        end

        -- Create and register the channel instance
        local cat = resolveCategoryEnum(def.category)
        local channel = DynamicRadioChannel.new(
            PhobosLib.safeGetText(def.nameKey), freq, cat, def.uuid)

        if channel then
            if channel.setAirCounterMultiplier then
                channel:setAirCounterMultiplier(1.0)
            end
            if mgr and mgr.AddChannel then
                mgr:AddChannel(channel, false)
            end
            DynamicRadio.cache[def.uuid] = channel
            _channels[def.id] = channel
            PhobosLib.debug("POS", _TAG,
                "registered channel: " .. def.id .. " at " .. tostring(freq) .. " Hz"
                .. " (AZAS: " .. tostring(freq ~= def.freq) .. ")")
        end

        ::nextDef::
    end
end

--- Emit a composed bulletin on the specified station class channel.
--- Creates a global RadioBroadCast (x=-1, y=-1), populates it with
--- RadioLine instances from the supplied bulletin lines, and sets it
--- as the channel's airing broadcast.
--- @param stationClassId string  Station class from POS_Constants.WBN_STATION_*
--- @param bulletinLines  table   Array of { text, r, g, b } from CompositionService
--- @return boolean               true if the broadcast was emitted successfully
function POS_WBN_ChannelService.emit(stationClassId, bulletinLines)
    local channel = _channels[stationClassId]
    if not channel then
        PhobosLib.debug("POS", _TAG, "emit: channel not found for " .. tostring(stationClassId))
        return false
    end
    if not bulletinLines or #bulletinLines == 0 then return false end
    if not RadioBroadCast or not RadioLine then
        PhobosLib.debug("POS", _TAG, "emit: RadioBroadCast/RadioLine API not available")
        return false
    end

    local bcId = "POS-WBN-" .. stationClassId .. "-" .. tostring(ZombRand(1, 99999))
    local bc = RadioBroadCast.new(bcId, -1, -1)

    for _, lineData in ipairs(bulletinLines) do
        local line = RadioLine.new(
            lineData.text or "",
            lineData.r or 1.0,
            lineData.g or 1.0,
            lineData.b or 1.0)
        if line then
            if line.setPriority then line:setPriority(POS_Constants.WBN_RADIO_LINE_PRIORITY) end
            if line.setLoop then line:setLoop(false) end
            bc:AddRadioLine(line)
        end
    end

    -- Validate broadcast has at least one line before emitting
    if bc.getRadioLines and bc:getRadioLines() then
        local radioLines = bc:getRadioLines()
        if radioLines.isEmpty and radioLines:isEmpty() then
            PhobosLib.debug("POS", _TAG, "emit: broadcast has zero lines, skipping")
            return false
        end
    end

    channel:setAiringBroadcast(bc)
    PhobosLib.debug("POS", _TAG,
        "emit: broadcast on " .. stationClassId .. " (" .. tostring(#bulletinLines) .. " lines)")
    return true
end

--- Get the AZAS-assigned radio frequency for a given station class.
--- @param stationClassId string  Station class from POS_Constants.WBN_STATION_*
--- @return number|nil            Frequency in Hz, or nil if not found
function POS_WBN_ChannelService.getFrequency(stationClassId)
    local freq = resolveFrequency(stationClassId)
    return freq > 0 and freq or nil
end

--- Check whether a frequency belongs to a WBN channel.
--- Uses AZAS-resolved frequencies for accurate matching.
--- @param freq number  Frequency to check
--- @return boolean     true if this is a WBN frequency
--- @return string|nil  The station class id, or nil
function POS_WBN_ChannelService.isWBNFrequency(freq)
    if not freq then return false, nil end
    if freq == POS_AZASIntegration.getWBNMarketFrequency() then
        return true, POS_Constants.WBN_STATION_CIVILIAN_MARKET
    end
    if freq == POS_AZASIntegration.getWBNEmergencyFrequency() then
        return true, POS_Constants.WBN_STATION_EMERGENCY
    end
    return false, nil
end

-- Register channels on relevant PZ lifecycle events
if Events then
    if Events.OnLoadRadioScripts then
        Events.OnLoadRadioScripts.Add(POS_WBN_ChannelService.ensureChannels)
    end
    if Events.OnGameStart then
        Events.OnGameStart.Add(function()
            POS_WBN_ChannelService.ensureChannels()
        end)
    end
end
