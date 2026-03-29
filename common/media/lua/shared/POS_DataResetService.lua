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
-- POS_DataResetService.lua
-- Shared service: wipes all POSnet-related data from
-- world ModData and player ModData.
-- UI lives in POS_Screen_DataReset.lua (client-side).
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

---------------------------------------------------------------

POS_DataResetService = POS_DataResetService or {}

local _TAG = "DataReset"

---------------------------------------------------------------
-- World-level ModData keys to clear (authority only)
---------------------------------------------------------------

local WORLD_KEYS = {
    "POSNET",                          -- EventLog, BuildingCache, MailboxCache
    POS_Constants.WMD_WORLD,
    POS_Constants.WMD_EXCHANGE,
    POS_Constants.WMD_WHOLESALERS,
    POS_Constants.WMD_META,
    POS_Constants.WMD_BUILDINGS,
    POS_Constants.WMD_MAILBOXES,
}

--- Collect additional world keys that may be defined in split constant files.
--- Called lazily so load order doesn't matter.
--- @return table
local function getAllWorldKeys()
    local keys = {}
    for _, k in ipairs(WORLD_KEYS) do
        keys[#keys + 1] = k
    end
    -- Keys from POS_Constants_LivingMarket / POS_Constants_Market (may not exist yet at file-load time)
    if POS_Constants.WMD_MARKET_ZONES then keys[#keys + 1] = POS_Constants.WMD_MARKET_ZONES end
    if POS_Constants.WMD_RUMOURS      then keys[#keys + 1] = POS_Constants.WMD_RUMOURS end
    if POS_Constants.WMD_MARKET_DATA  then keys[#keys + 1] = POS_Constants.WMD_MARKET_DATA end

    -- Keys from POS_Constants_Trade / core constants (may not exist yet at file-load time)
    if POS_Constants.WMD_TRADE_HISTORY      then keys[#keys + 1] = POS_Constants.WMD_TRADE_HISTORY end
    if POS_Constants.WMD_CONTRACTS          then keys[#keys + 1] = POS_Constants.WMD_CONTRACTS end
    if POS_Constants.WMD_FREE_AGENTS        then keys[#keys + 1] = POS_Constants.WMD_FREE_AGENTS end
    if POS_Constants.WMD_ACTIVE_EVENTS      then keys[#keys + 1] = POS_Constants.WMD_ACTIVE_EVENTS end
    if POS_Constants.WMD_RECENT_EVENTS      then keys[#keys + 1] = POS_Constants.WMD_RECENT_EVENTS end
    if POS_Constants.WMD_EVENT_LOG          then keys[#keys + 1] = POS_Constants.WMD_EVENT_LOG end
    if POS_Constants.WMD_BUILDING_CACHE     then keys[#keys + 1] = POS_Constants.WMD_BUILDING_CACHE end
    if POS_Constants.WMD_MAILBOX_CACHE      then keys[#keys + 1] = POS_Constants.WMD_MAILBOX_CACHE end
    if POS_Constants.WMD_PENDING_RESOLUTIONS then keys[#keys + 1] = POS_Constants.WMD_PENDING_RESOLUTIONS end

    -- Broadcast Influence System (Tier IV satellite broadcast records)
    if POS_Constants.WMD_BROADCAST_INFLUENCE then keys[#keys + 1] = POS_Constants.WMD_BROADCAST_INFLUENCE end

    -- Dynamic per-player payout key (world-level ModData keyed by username)
    if POS_Constants.PENDING_PAYOUT_PREFIX then
        local player = getSpecificPlayer(0)
        if player then
            local username = player:getUsername()
            if username then
                keys[#keys + 1] = POS_Constants.PENDING_PAYOUT_PREFIX .. username
            end
        end
    end

    -- Tier V Strategic Relay registry
    if POS_Constants.RELAY_REGISTRY_KEY then
        keys[#keys + 1] = POS_Constants.RELAY_REGISTRY_KEY
    end

    -- Satellite system world ModData (POS_Satellite container)
    keys[#keys + 1] = "POS_Satellite"

    return keys
end

--- Prefixes for scattered world ModData keys that need cleanup.
--- These are indexed by entity/location ID and can't be enumerated
--- from a single container — they must be scanned from the global
--- ModData table.
local WORLD_PREFIX_CLEANUP = {
    "POS_Relay_",
    "POS_SatelliteVisit_",
    "POS_SatelliteCalibrated_",
    "POS_SatelliteWiring_",
    "POS_SatTrust_",
    "POS_CameraVisit_",
    "POS_AnalysisVisit_",
    "POS_IntelVisit_",
}

---------------------------------------------------------------
-- Player-level ModData keys to clear
---------------------------------------------------------------

local PLAYER_KEYS = {
    "POSNET",
    POS_Constants.MODDATA_OPERATIONS,
    POS_Constants.MODDATA_OPPORTUNITIES,
    POS_Constants.MODDATA_INVESTMENTS,
    POS_Constants.MODDATA_WATCHLIST,
    POS_Constants.MODDATA_ALERTS,
    POS_Constants.MODDATA_SIGINT_TOTAL_XP,
    POS_Constants.MODDATA_SIGINT_CROSSCOR_COUNT,
}

--- Collect additional player keys that may be defined in split constant files.
--- @return table
local function getAllPlayerKeys()
    local keys = {}
    for _, k in ipairs(PLAYER_KEYS) do
        keys[#keys + 1] = k
    end
    if POS_Constants.DISCOVERY_NAMESPACE then keys[#keys + 1] = POS_Constants.DISCOVERY_NAMESPACE end

    -- Satellite broadcast history + scan session (player ModData)
    if POS_Constants.SAT_HISTORY_KEY then keys[#keys + 1] = POS_Constants.SAT_HISTORY_KEY end
    if POS_Constants.SAT_SCAN_SESSION_MODDATA_KEY then keys[#keys + 1] = POS_Constants.SAT_SCAN_SESSION_MODDATA_KEY end

    return keys
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Reset all world-level POSnet data.
--- Must only be called on authority (server / SP host).
--- @return number count of keys cleared
function POS_DataResetService.resetWorldData()
    local cleared = 0

    -- 1. Clear named containers
    local worldKeys = getAllWorldKeys()
    for _, key in ipairs(worldKeys) do
        local data = PhobosLib.getWorldModData(key)
        if data then
            -- Wipe all fields from the table (ModData tables can't be nilled)
            for field in pairs(data) do
                data[field] = nil
            end
            cleared = cleared + 1
            PhobosLib.debug("POS", _TAG, "Cleared world ModData: " .. tostring(key))
        end
    end

    -- 2. Clear prefix-indexed scattered keys (relay, satellite, visits).
    -- These are stored at the top level of POS_Satellite or other containers.
    -- Scan the POS_Satellite container for matching prefix keys.
    local satData = PhobosLib.getWorldModData("POS_Satellite")
    if satData then
        local prefixCleared = 0
        for key, _ in pairs(satData) do
            if type(key) == "string" then
                for _, prefix in ipairs(WORLD_PREFIX_CLEANUP) do
                    if key:sub(1, #prefix) == prefix then
                        satData[key] = nil
                        prefixCleared = prefixCleared + 1
                        break
                    end
                end
            end
        end
        if prefixCleared > 0 then
            PhobosLib.debug("POS", _TAG,
                "Cleared " .. tostring(prefixCleared) .. " prefix-indexed satellite/relay keys")
            cleared = cleared + prefixCleared
        end
    end

    return cleared
end

--- Reset all player-level POSnet data for the given player.
--- @param player IsoPlayer
--- @return number count of keys cleared
function POS_DataResetService.resetPlayerData(player)
    if not player then return 0 end
    local md = player:getModData()
    if not md then return 0 end

    local cleared = 0
    local playerKeys = getAllPlayerKeys()
    for _, key in ipairs(playerKeys) do
        if md[key] ~= nil then
            md[key] = nil
            cleared = cleared + 1
            PhobosLib.debug("POS", _TAG, "Cleared player ModData: " .. tostring(key))
        end
    end
    return cleared
end

--- Full reset: world (if authority) + current player.
--- @param player IsoPlayer
--- @return number worldCleared, number playerCleared
function POS_DataResetService.resetAll(player)
    local worldCleared = 0
    if isServer() or not isClient() then
        worldCleared = POS_DataResetService.resetWorldData()
    end
    local playerCleared = POS_DataResetService.resetPlayerData(player)
    PhobosLib.debug("POS", _TAG, "Full reset complete: " .. tostring(worldCleared) .. " world keys, " .. tostring(playerCleared) .. " player keys cleared")
    return worldCleared, playerCleared
end
