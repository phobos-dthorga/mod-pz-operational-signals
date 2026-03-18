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
-- POS_WorldState.lua
-- World-scoped Global ModData wrapper.
-- Provides named accessors for six persistent ModData containers
-- plus thin PZ API wrappers for day, authority, and seed queries.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_WorldState = {}

---------------------------------------------------------------
-- Container accessors (all return persistent tables)
---------------------------------------------------------------

function POS_WorldState.getWorld()
    return ModData.getOrCreate(POS_Constants.WMD_WORLD)
end

function POS_WorldState.getExchange()
    return ModData.getOrCreate(POS_Constants.WMD_EXCHANGE)
end

function POS_WorldState.getWholesalers()
    return ModData.getOrCreate(POS_Constants.WMD_WHOLESALERS)
end

function POS_WorldState.getMeta()
    return ModData.getOrCreate(POS_Constants.WMD_META)
end

function POS_WorldState.getBuildings()
    return ModData.getOrCreate(POS_Constants.WMD_BUILDINGS)
end

function POS_WorldState.getMailboxes()
    return ModData.getOrCreate(POS_Constants.WMD_MAILBOXES)
end

---------------------------------------------------------------
-- PZ API thin wrappers (forward-compatibility layer)
---------------------------------------------------------------

function POS_WorldState.getWorldDay()
    local gt = getGameTime and getGameTime()
    return gt and gt:getNightsSurvived() or 0
end

function POS_WorldState.isAuthority()
    -- Returns true in SP (server+client) and on dedicated/listen server
    -- Returns false on MP clients
    if isServer then return isServer() end
    if isClient then return not isClient() end
    return true  -- SP fallback
end

function POS_WorldState.getWorldSeed()
    local meta = POS_WorldState.getMeta()
    return meta.worldSeed or 0
end

---------------------------------------------------------------
-- Bootstrap: called on server OnGameStart
---------------------------------------------------------------

function POS_WorldState.bootstrap()
    if not POS_WorldState.isAuthority() then return end

    local meta = POS_WorldState.getMeta()

    -- Schema version guard
    meta.schemaVersion = meta.schemaVersion or POS_Constants.SCHEMA_VERSION
    meta.lastProcessedDay = meta.lastProcessedDay or -1
    meta.buildingScanDone = meta.buildingScanDone or false
    meta.mailboxScanDone = meta.mailboxScanDone or false
    meta.migrated = meta.migrated or false

    -- World seed (deterministic per-world, set once)
    if not meta.worldSeed or meta.worldSeed == 0 then
        meta.worldSeed = ZombRand(1, 2147483647)
    end

    -- Ensure world container sub-tables exist
    local world = POS_WorldState.getWorld()
    world.categories = world.categories or {}
    world.recentEvents = world.recentEvents or {}
    world.regions = world.regions or {}

    -- Ensure exchange container
    local exchange = POS_WorldState.getExchange()
    exchange.companies = exchange.companies or {}

    -- Ensure wholesalers container
    local wholesalers = POS_WorldState.getWholesalers()
    wholesalers.entries = wholesalers.entries or {}

    -- Ensure building/mailbox containers
    local buildings = POS_WorldState.getBuildings()
    buildings.entries = buildings.entries or {}

    local mailboxes = POS_WorldState.getMailboxes()
    mailboxes.entries = mailboxes.entries or {}

    -- One-time migration from player modData to world ModData
    if not meta.migrated then
        local player = getSpecificPlayer(0)
        if player then
            local playerMd = player:getModData()

            -- Migrate market intel records
            local oldIntel = playerMd[POS_Constants.MD_MARKET_INTEL]
            if oldIntel and type(oldIntel) == "table" then
                PhobosLib.debug("POS", "[WorldState] Migrating "
                    .. tostring(#oldIntel) .. " intel records from player to world")
                if POS_MarketDatabase and POS_MarketDatabase.addRecord then
                    for _, record in ipairs(oldIntel) do
                        POS_MarketDatabase.addRecord(record)
                    end
                end
                playerMd[POS_Constants.MD_MARKET_INTEL] = nil
            end

            -- Migrate building cache
            local oldBuildings = playerMd["POS_DiscoveredBuildings"]
            if oldBuildings and type(oldBuildings) == "table" then
                buildings.entries = buildings.entries or {}
                for _, b in ipairs(oldBuildings) do
                    buildings.entries[#buildings.entries + 1] = b
                end
                playerMd["POS_DiscoveredBuildings"] = nil
                playerMd["POS_BuildingScanDone"] = nil
            end

            -- Migrate mailbox cache
            local oldMailboxes = playerMd["POS_DiscoveredMailboxes"]
            if oldMailboxes and type(oldMailboxes) == "table" then
                mailboxes.entries = mailboxes.entries or {}
                for _, m in ipairs(oldMailboxes) do
                    mailboxes.entries[#mailboxes.entries + 1] = m
                end
                playerMd["POS_DiscoveredMailboxes"] = nil
                playerMd["POS_MailboxScanDone"] = nil
            end
        end
        meta.migrated = true
    end

    PhobosLib.debug("POS", "[WorldState] Bootstrap complete, schema v"
        .. tostring(meta.schemaVersion) .. ", seed=" .. tostring(meta.worldSeed))
end

-- Hook bootstrap
Events.OnGameStart.Add(function()
    POS_WorldState.bootstrap()
end)
