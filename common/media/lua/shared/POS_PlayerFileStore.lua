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
-- POS_PlayerFileStore.lua
-- Per-player file-backed storage for growth-prone arrays.
-- Internal module — only required by POS_PlayerState.
--
-- Externalises watchlist, alerts, orders, and holdings to
-- flat pipe-delimited files in Zomboid/Lua/POSNET/ to avoid
-- player modData bloat in long-running games.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_PlayerFileStore = {}

local SEP = POS_Constants.PLAYER_FILE_SEPARATOR

---------------------------------------------------------------
-- Session cache (keyed by username)
---------------------------------------------------------------

local cache = {}

local function createEmpty()
    return {
        watchlist = {},
        alerts = {},
        orders = {},
        holdings = {},
    }
end

---------------------------------------------------------------
-- File path helper
---------------------------------------------------------------

local function getFilePath(player)
    if not player then return nil end
    local username = player:getUsername()
    if not username or username == "" then
        username = "singleplayer"
    end
    return POS_Constants.PLAYER_FILE_PREFIX .. username .. POS_Constants.PLAYER_FILE_EXT
end

---------------------------------------------------------------
-- Serialisation helpers
---------------------------------------------------------------

local function writeLine(writer, ...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[i] = tostring(v or "")
    end
    writer:writeln(table.concat(parts, SEP))
end

local function parseWatchlistLine(line)
    local parts = splitString(line, SEP)
    if not parts or #parts < 2 then return nil end
    return {
        categoryId = parts[1],
        addedDay = tonumber(parts[2]) or 0,
        lastSnapshotAvg = tonumber(parts[3]),
        lastSnapshotDay = tonumber(parts[4]) or 0,
    }
end

local function parseAlertLine(line)
    local parts = splitString(line, SEP)
    if not parts or #parts < 5 then return nil end
    return {
        categoryId = parts[1],
        changePercent = tonumber(parts[2]) or 0,
        oldAvg = tonumber(parts[3]) or 0,
        newAvg = tonumber(parts[4]) or 0,
        day = tonumber(parts[5]) or 0,
        acknowledged = parts[6] == "true",
    }
end

---------------------------------------------------------------
-- Load from file
---------------------------------------------------------------

local function loadFromFile(player)
    local path = getFilePath(player)
    if not path then return nil end

    local reader = getFileReader(path, false)
    if not reader then return nil end

    local data = createEmpty()
    local currentSection = nil

    local line = reader:readLine()
    while line do
        -- Section headers
        if line == POS_Constants.PLAYER_FILE_SECTION_WATCHLIST then
            currentSection = "watchlist"
        elseif line == POS_Constants.PLAYER_FILE_SECTION_ALERTS then
            currentSection = "alerts"
        elseif line == POS_Constants.PLAYER_FILE_SECTION_ORDERS then
            currentSection = "orders"
        elseif line == POS_Constants.PLAYER_FILE_SECTION_HOLDINGS then
            currentSection = "holdings"
        elseif currentSection and line ~= "" then
            if currentSection == "watchlist" then
                local entry = parseWatchlistLine(line)
                if entry then
                    table.insert(data.watchlist, entry)
                end
            elseif currentSection == "alerts" then
                local entry = parseAlertLine(line)
                if entry then
                    table.insert(data.alerts, entry)
                end
            end
            -- orders/holdings: future, skip lines for now
        end
        line = reader:readLine()
    end
    reader:close()

    PhobosLib.debug("POS", "[PlayerFileStore]",
        "Loaded player file: " .. tostring(#data.watchlist) .. " watchlist, "
        .. tostring(#data.alerts) .. " alerts")

    return data
end

---------------------------------------------------------------
-- Save to file
---------------------------------------------------------------

local function saveToFile(player, data)
    local path = getFilePath(player)
    if not path or not data then return false end

    local writer = getFileWriter(path, true, false)
    if not writer then
        PhobosLib.debug("POS", "[PlayerFileStore]",
            "Failed to open player file for writing: " .. path)
        return false
    end

    -- Watchlist section
    writer:writeln(POS_Constants.PLAYER_FILE_SECTION_WATCHLIST)
    for _, entry in ipairs(data.watchlist) do
        writeLine(writer,
            entry.categoryId,
            entry.addedDay,
            entry.lastSnapshotAvg,
            entry.lastSnapshotDay)
    end

    -- Alerts section
    writer:writeln(POS_Constants.PLAYER_FILE_SECTION_ALERTS)
    for _, entry in ipairs(data.alerts) do
        writeLine(writer,
            entry.categoryId,
            entry.changePercent,
            entry.oldAvg,
            entry.newAvg,
            entry.day,
            tostring(entry.acknowledged or false))
    end

    -- Orders section (future)
    writer:writeln(POS_Constants.PLAYER_FILE_SECTION_ORDERS)

    -- Holdings section (future)
    writer:writeln(POS_Constants.PLAYER_FILE_SECTION_HOLDINGS)

    writer:close()

    PhobosLib.debug("POS", "[PlayerFileStore]",
        "Saved player file: " .. tostring(#data.watchlist) .. " watchlist, "
        .. tostring(#data.alerts) .. " alerts")

    return true
end

---------------------------------------------------------------
-- Migration from player modData (one-shot)
---------------------------------------------------------------

local function migrateFromModData(player, data)
    local md = player:getModData()
    if not md or not md.POSNET then return false end
    local ps = md.POSNET
    if ps.fileStoreMigrated then return false end

    local migrated = false

    -- Migrate watchlist
    if ps.watchlist and type(ps.watchlist) == "table" and #ps.watchlist > 0 then
        for _, entry in ipairs(ps.watchlist) do
            table.insert(data.watchlist, entry)
        end
        PhobosLib.debug("POS", "[PlayerFileStore]",
            "Migrated " .. tostring(#ps.watchlist) .. " watchlist entries from modData")
        ps.watchlist = nil
        migrated = true
    end

    -- Migrate alerts
    if ps.alerts and type(ps.alerts) == "table" and #ps.alerts > 0 then
        for _, entry in ipairs(ps.alerts) do
            table.insert(data.alerts, entry)
        end
        PhobosLib.debug("POS", "[PlayerFileStore]",
            "Migrated " .. tostring(#ps.alerts) .. " alerts from modData")
        ps.alerts = nil
        migrated = true
    end

    -- Migrate openOrders
    if ps.openOrders and type(ps.openOrders) == "table" and #ps.openOrders > 0 then
        for _, entry in ipairs(ps.openOrders) do
            table.insert(data.orders, entry)
        end
        ps.openOrders = nil
        migrated = true
    end

    -- Migrate holdings
    if ps.holdings and type(ps.holdings) == "table" and #ps.holdings > 0 then
        for _, entry in ipairs(ps.holdings) do
            table.insert(data.holdings, entry)
        end
        ps.holdings = nil
        migrated = true
    end

    ps.fileStoreMigrated = true

    if migrated then
        PhobosLib.debug("POS", "[PlayerFileStore]",
            "Migration complete — legacy arrays cleared from modData")
    end

    return migrated
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Lazy-load player data from file (or migrate from modData).
--- Returns the session cache entry for this player.
---@param player IsoPlayer
---@return table { watchlist, alerts, orders, holdings }
function POS_PlayerFileStore.load(player)
    if not player then return createEmpty() end

    local username = player:getUsername()
    if not username or username == "" then
        username = "singleplayer"
    end

    -- Return cached data if already loaded this session
    if cache[username] then
        return cache[username]
    end

    -- Try loading from file
    local data = loadFromFile(player)

    if not data then
        -- No file exists yet — check for legacy modData to migrate
        data = createEmpty()
        local didMigrate = migrateFromModData(player, data)
        if didMigrate then
            saveToFile(player, data)
        end
    else
        -- File loaded — still mark migration done if not already
        local md = player:getModData()
        if md and md.POSNET and not md.POSNET.fileStoreMigrated then
            migrateFromModData(player, data)
            saveToFile(player, data)
        end
    end

    cache[username] = data
    return data
end

--- Flush the session cache for this player to file.
---@param player IsoPlayer
function POS_PlayerFileStore.save(player)
    if not player then return end

    local username = player:getUsername()
    if not username or username == "" then
        username = "singleplayer"
    end

    local data = cache[username]
    if not data then return end

    saveToFile(player, data)
end

--- Get the watchlist array for a player.
---@param player IsoPlayer
---@return table Array of watchlist entries
function POS_PlayerFileStore.getWatchlist(player)
    return POS_PlayerFileStore.load(player).watchlist
end

--- Get the alerts array for a player.
---@param player IsoPlayer
---@return table Array of alert entries
function POS_PlayerFileStore.getAlerts(player)
    return POS_PlayerFileStore.load(player).alerts
end

--- Get the orders array for a player (future use).
---@param player IsoPlayer
---@return table Array of order entries
function POS_PlayerFileStore.getOrders(player)
    return POS_PlayerFileStore.load(player).orders
end

--- Get the holdings array for a player (future use).
---@param player IsoPlayer
---@return table Array of holding entries
function POS_PlayerFileStore.getHoldings(player)
    return POS_PlayerFileStore.load(player).holdings
end

--- Clear the session cache (e.g. on disconnect).
function POS_PlayerFileStore.clearCache()
    cache = {}
    PhobosLib.debug("POS", "[PlayerFileStore]", "Session cache cleared")
end
