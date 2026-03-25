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

--- POS_WBN_ClientListener — Client-side listener that captures received
--- WBN broadcasts into player ModData for history display on terminal
--- screens.
---
--- Hooks into the vanilla Events.OnDeviceText callback to intercept radio
--- text arriving on devices tuned to WBN frequencies. Captured broadcasts
--- are stored as indexed entries under the player's POSNET ModData table
--- with FIFO trimming to a configurable maximum.
---
--- @module POS_WBN_ClientListener

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_WBN"

local _TAG = "WBN:Client"
POS_WBN_ClientListener = {}

--- Check if a device frequency belongs to a WBN channel.
--- Uses AZAS-resolved frequencies for accurate per-world matching.
--- @param freq number  The frequency to check
--- @return boolean     true if this is a WBN frequency
--- @return string|nil  The station class id, or nil
local function isWBNFrequency(freq)
    if not freq then return false, nil end
    local azas = POS_AZASIntegration
    if azas and azas.getWBNMarketFrequency
        and freq == azas.getWBNMarketFrequency() then
        return true, POS_Constants.WBN_STATION_CIVILIAN_MARKET
    end
    if azas and azas.getWBNEmergencyFrequency
        and freq == azas.getWBNEmergencyFrequency() then
        return true, POS_Constants.WBN_STATION_EMERGENCY
    end
    return false, nil
end

--- Add a bulletin to the broadcast history log in player ModData.
--- Entries are stored with string keys under POSNET.[historyKey] for
--- Java table compatibility. Oldest entries are trimmed via FIFO when
--- the maximum is exceeded.
--- @param text           string  The broadcast text content
--- @param stationClassId string  Station class from POS_Constants.WBN_STATION_*
local function addToHistory(text, stationClassId)
    local player = getPlayer()
    if not player then return end

    local md = player:getModData()
    if not md then return end

    local posData = md.POSNET
    if not posData then
        md.POSNET = {}
        posData = md.POSNET
    end

    local history = posData[POS_Constants.WBN_HISTORY_MODDATA_KEY]
    if not history then
        posData[POS_Constants.WBN_HISTORY_MODDATA_KEY] = {}
        history = posData[POS_Constants.WBN_HISTORY_MODDATA_KEY]
    end

    -- Determine next entry index (string keys for Java table safety)
    local worldHours = getGameTime() and getGameTime():getWorldAgeHours() or 0
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    local entryIdx = 0
    for _ in pairs(history) do entryIdx = entryIdx + 1 end
    entryIdx = entryIdx + 1

    history[tostring(entryIdx)] = {
        text         = text or "",
        stationClass = stationClassId or "",
        day          = day,
        gameHours    = worldHours,
    }

    -- Trim to max entries (FIFO — remove oldest by lowest index)
    local maxEntries = POS_Constants.WBN_HISTORY_MAX_ENTRIES
    local count = 0
    for _ in pairs(history) do count = count + 1 end
    if count > maxEntries then
        local minIdx = nil
        for k, _ in pairs(history) do
            local n = tonumber(k)
            if n and (not minIdx or n < minIdx) then minIdx = n end
        end
        if minIdx then history[tostring(minIdx)] = nil end
    end
end

--- Vanilla PZ OnDeviceText callback. Fires when a radio device receives
--- text. Checks if the device is tuned to a WBN frequency and captures
--- the text into player ModData history.
--- @param guid   string         Device GUID
--- @param codes  userdata       Message codes
--- @param x      number         World X coordinate
--- @param y      number         World Y coordinate
--- @param z      number         World Z coordinate
--- @param text   string|userdata  The broadcast text or RadioLine object
--- @param device userdata       The radio device instance
local function onDeviceText(guid, codes, x, y, z, text, device)
    if not device then return end

    local data = nil
    if device.getDeviceData then
        data = device:getDeviceData()
    end
    if not data then return end

    -- Device must be turned on
    if data.getIsTurnedOn and data:getIsTurnedOn() ~= true then return end

    -- Check if tuned to a WBN frequency
    local freq = 0
    if data.getChannel then freq = data:getChannel() end
    local isWBN, stationId = isWBNFrequency(freq)
    if not isWBN then return end

    -- Extract text from either a plain string or a RadioLine object
    local lineText = ""
    if type(text) == "string" then
        lineText = text
    elseif text and text.getText then
        lineText = text:getText() or ""
    end

    if lineText ~= "" then
        addToHistory(lineText, stationId)
        PhobosLib.debug("POS", _TAG,
            "captured broadcast on " .. tostring(stationId) .. ": " .. lineText:sub(1, 50))
    end
end

-- Register with vanilla PZ event system
if Events and Events.OnDeviceText then
    Events.OnDeviceText.Add(onDeviceText)
    PhobosLib.debug("POS", _TAG, "registered OnDeviceText listener")
end

--- Get broadcast history for display on terminal screens.
--- Returns an array of history entries sorted newest-first.
--- @return table  Array of { text, stationClass, day, gameHours }
function POS_WBN_ClientListener.getHistory()
    local player = getPlayer()
    if not player then return {} end
    local md = player:getModData()
    if not md or not md.POSNET then return {} end
    local history = md.POSNET[POS_Constants.WBN_HISTORY_MODDATA_KEY]
    if not history then return {} end

    -- Collect and sort by index descending (newest first)
    local result = {}
    for k, v in pairs(history) do
        if type(v) == "table" then
            v._sortIdx = tonumber(k) or 0
            result[#result + 1] = v
        end
    end
    table.sort(result, function(a, b) return (a._sortIdx or 0) > (b._sortIdx or 0) end)
    return result
end
