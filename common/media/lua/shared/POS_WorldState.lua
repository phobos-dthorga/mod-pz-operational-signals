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
require "POS_MarketFileStore"

POS_WorldState = {}

local _TAG = "[POS:WorldState]"

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

function POS_WorldState.getMarketZones()
    return ModData.getOrCreate(POS_Constants.WMD_MARKET_ZONES)
end

function POS_WorldState.getRumours()
    return ModData.getOrCreate(POS_Constants.WMD_RUMOURS)
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

function POS_WorldState.getMarketData()
    return ModData.getOrCreate(POS_Constants.WMD_MARKET_DATA)
end

---------------------------------------------------------------
-- PZ API thin wrappers (forward-compatibility layer)
---------------------------------------------------------------

function POS_WorldState.getWorldDay()
    local gt = getGameTime and getGameTime()
    return gt and gt:getNightsSurvived() or 0
end

function POS_WorldState.isAuthority()
    -- Returns true in SP (server+client) and on dedicated/listen server.
    -- Returns false on MP clients only.
    -- NOTE: in SP, both isServer() and isClient() return false.
    -- A pure MP client has isClient() == true.
    if isClient and isClient() then return false end
    return true
end

function POS_WorldState.getWorldSeed()
    local meta = POS_WorldState.getMeta()
    return meta.worldSeed or 0
end

---------------------------------------------------------------
-- External cache persistence (flat files in Zomboid/Lua/)
---------------------------------------------------------------

--- Save the building discovery cache to an external flat file.
--- Save building discovery cache to world ModData.
--- Only the server/SP authority writes cache data.
function POS_WorldState.saveBuildingCache()
    if not POS_WorldState.isAuthority() then return end
    local buildings = POS_WorldState.getBuildings()
    if not buildings or not buildings.entries then return end

    local cache = PhobosLib.getWorldModDataTable("POSNET", "BuildingCache")
    -- Clear and repopulate (ModData tables can't be replaced wholesale)
    for k in pairs(cache) do cache[k] = nil end
    for i, entry in ipairs(buildings.entries) do
        cache[i] = {
            x = entry.x,
            y = entry.y,
            rooms = entry.rooms or {},
        }
    end
    PhobosLib.debug("POS", _TAG, "[WorldState] Building cache saved: " .. tostring(#buildings.entries) .. " entries")
end

--- Load building discovery cache from world ModData.
---@return table|nil Array of { x, y, rooms } entries, or nil if empty
function POS_WorldState.loadBuildingCache()
    local cache = PhobosLib.getWorldModDataTable("POSNET", "BuildingCache")
    local entries = {}
    for _, entry in pairs(cache) do
        if type(entry) == "table" and entry.x and entry.y then
            entries[#entries + 1] = {
                x = tonumber(entry.x),
                y = tonumber(entry.y),
                rooms = entry.rooms or {},
            }
        end
    end
    if #entries == 0 then return nil end
    PhobosLib.debug("POS", _TAG, "[WorldState] Building cache loaded: " .. tostring(#entries) .. " entries")
    return entries
end

--- Save mailbox discovery cache to world ModData.
function POS_WorldState.saveMailboxCache()
    if not POS_WorldState.isAuthority() then return end
    local mailboxes = POS_WorldState.getMailboxes()
    if not mailboxes or not mailboxes.entries then return end

    local cache = PhobosLib.getWorldModDataTable("POSNET", "MailboxCache")
    -- Clear and repopulate
    for k in pairs(cache) do cache[k] = nil end
    for i, entry in ipairs(mailboxes.entries) do
        cache[i] = { x = entry.x, y = entry.y }
    end
    PhobosLib.debug("POS", _TAG, "[WorldState] Mailbox cache saved: " .. tostring(#mailboxes.entries) .. " entries")
end

--- Load mailbox discovery cache from world ModData.
---@return table|nil Array of { x, y } entries, or nil if empty
function POS_WorldState.loadMailboxCache()
    local cache = PhobosLib.getWorldModDataTable("POSNET", "MailboxCache")
    local entries = {}
    for _, entry in pairs(cache) do
        if type(entry) == "table" and entry.x and entry.y then
            entries[#entries + 1] = {
                x = tonumber(entry.x),
                y = tonumber(entry.y),
            }
        end
    end
    if #entries == 0 then return nil end
    PhobosLib.debug("POS", _TAG, "[WorldState] Mailbox cache loaded: " .. tostring(#entries) .. " entries")
    return entries
end

--- Migrate building and mailbox caches from ModData to external files.
--- Runs once per world; sets meta.cachesMigrated = true on completion.
function POS_WorldState.migrateModDataCaches()
    local meta = POS_WorldState.getMeta()
    if meta.cachesMigrated then return end

    local buildings = POS_WorldState.getBuildings()
    if buildings and buildings.entries and #buildings.entries > 0 then
        local count = #buildings.entries
        POS_WorldState.saveBuildingCache()
        -- Clear from ModData after successful write
        buildings.entries = {}
        PhobosLib.debug("POS", _TAG, "[WorldState] Migrated " .. tostring(count) .. " building entries to external file")
    end

    local mailboxes = POS_WorldState.getMailboxes()
    if mailboxes and mailboxes.entries and #mailboxes.entries > 0 then
        local count = #mailboxes.entries
        POS_WorldState.saveMailboxCache()
        mailboxes.entries = {}
        PhobosLib.debug("POS", _TAG, "[WorldState] Migrated " .. tostring(count) .. " mailbox entries to external file")
    end

    meta.cachesMigrated = true
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
    meta.marketSchemaVersion = meta.marketSchemaVersion or POS_Constants.MARKET_SCHEMA_VERSION

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

    -- Ensure market zones container
    local zones = POS_WorldState.getMarketZones()
    zones.entries = zones.entries or {}

    -- Ensure rumours container
    local rumours = POS_WorldState.getRumours()
    rumours.entries = rumours.entries or {}

    -- Ensure building/mailbox containers
    local buildings = POS_WorldState.getBuildings()
    buildings.entries = buildings.entries or {}

    local mailboxes = POS_WorldState.getMailboxes()
    mailboxes.entries = mailboxes.entries or {}

    -- Ensure market data container (observations + rolling closes)
    local marketData = POS_WorldState.getMarketData()
    marketData.categories = marketData.categories or {}

    -- One-time migration from player modData to world ModData
    if not meta.migrated then
        local player = getSpecificPlayer(0)
        if player then
            local playerMd = player:getModData()

            -- Migrate market intel records
            local oldIntel = playerMd[POS_Constants.MD_MARKET_INTEL]
            if oldIntel and type(oldIntel) == "table" then
                PhobosLib.debug("POS", _TAG, "[WorldState] Migrating "
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

    -- Migrate building/mailbox caches from ModData to external files
    POS_WorldState.migrateModDataCaches()

    -- Initialise market file store (reads from ModData)
    POS_MarketFileStore.load()

    -- One-time migration of market observations/closes from
    -- world.categories into the dedicated MarketData container
    POS_WorldState.migrateMarketDataToModData()

    PhobosLib.debug("POS", _TAG, "[WorldState] Bootstrap complete, schema v"
        .. tostring(meta.schemaVersion) .. ", seed=" .. tostring(meta.worldSeed))
end

---------------------------------------------------------------
-- Market data migration (world.categories → dedicated ModData)
---------------------------------------------------------------

--- One-time migration: move observations and rollingCloses from
--- world.categories into the dedicated WMD_MARKET_DATA container.
--- Keeps aggregates in world.categories for MP client snapshot delivery.
function POS_WorldState.migrateMarketDataToModData()
    local meta = POS_WorldState.getMeta()
    if meta.marketDataMigrated then return end

    local world = POS_WorldState.getWorld()
    if not world.categories then
        meta.marketDataMigrated = true
        return
    end

    local migratedCats = 0
    local migratedObs = 0

    for catId, catData in pairs(world.categories) do
        local mdCat = POS_MarketFileStore.getCategory(catId)

        -- Transfer observations
        if catData.observations and #catData.observations > 0 then
            for _, obs in ipairs(catData.observations) do
                table.insert(mdCat.observations, obs)
            end
            migratedObs = migratedObs + #catData.observations
            catData.observations = nil
        end

        -- Transfer rolling closes
        if catData.rollingCloses and #catData.rollingCloses > 0 then
            mdCat.rollingCloses = catData.rollingCloses
            catData.rollingCloses = nil
        end

        -- Keep aggregate in world.categories (for MP snapshot delivery)
        migratedCats = migratedCats + 1
    end

    if migratedObs > 0 then
        PhobosLib.debug("POS", _TAG, "[WorldState] Migrated market data to ModData: "
            .. tostring(migratedCats) .. " categories, "
            .. tostring(migratedObs) .. " observations")
    end

    meta.marketDataMigrated = true
end

-- Hook bootstrap
Events.OnGameStart.Add(function()
    POS_WorldState.bootstrap()
end)
