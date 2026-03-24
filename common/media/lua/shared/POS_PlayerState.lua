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
-- POS_PlayerState.lua
-- Player-bound state accessor for POSnet.
--
-- All player data lives in player modData (engine-managed,
-- auto-persisted on save). No custom file I/O.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_PlayerState = {}

local PLAYER_SCHEMA_VERSION = POS_Constants.SCHEMA_VERSION

---------------------------------------------------------------
-- Default player state template (scalar fields only)
---------------------------------------------------------------

local function createDefaultState()
    return {
        schemaVersion = PLAYER_SCHEMA_VERSION,
        rep = 0,
        cash = 0,
        intelAccess = {
            civilianBand = true,
            militaryBand = false,
        },
        uiPrefs = {},
        lastMarketSyncDay = 0,
    }
end

---------------------------------------------------------------
-- Core accessor (modData — scalars only)
---------------------------------------------------------------

--- Get or create the POSnet player state table (scalar fields).
--- For watchlist/alerts, use the dedicated getters.
--- @param player IsoPlayer
--- @return table The POSNET player state sub-table
function POS_PlayerState.get(player)
    if not player then return createDefaultState() end
    local md = player:getModData()
    if not md.POSNET then
        md.POSNET = createDefaultState()
    end
    -- Ensure scalar fields exist (forward compat)
    local ps = md.POSNET
    ps.schemaVersion = ps.schemaVersion or PLAYER_SCHEMA_VERSION
    ps.rep = ps.rep or 0
    ps.cash = ps.cash or 0
    ps.intelAccess = ps.intelAccess or { civilianBand = true, militaryBand = false }
    ps.uiPrefs = ps.uiPrefs or {}
    ps.lastMarketSyncDay = ps.lastMarketSyncDay or 0
    return ps
end

---------------------------------------------------------------
-- Cash helpers
---------------------------------------------------------------

--- Get player cash balance.
function POS_PlayerState.getCash(player)
    return POS_PlayerState.get(player).cash
end

--- Modify player cash (server-validated in MP).
function POS_PlayerState.modifyCash(player, amount)
    local ps = POS_PlayerState.get(player)
    ps.cash = math.max(0, (ps.cash or 0) + amount)
    return ps.cash
end

---------------------------------------------------------------
-- Alerts (player modData)
---------------------------------------------------------------

--- Add an alert to the player's alert queue (capped).
function POS_PlayerState.addAlert(player, alert)
    local alerts = PhobosLib.getPlayerModDataTable(player, POS_Constants.MODDATA_ALERTS)
    if not alerts then return end
    local maxAlerts = POS_Sandbox and POS_Sandbox.getMaxPlayerAlerts
        and POS_Sandbox.getMaxPlayerAlerts() or POS_Constants.MAX_PLAYER_ALERTS
    PhobosLib.pushRolling(alerts, alert, maxAlerts)
end

--- Get player alerts.
--- @param player IsoPlayer
--- @return table Array of alert entries
function POS_PlayerState.getAlerts(player)
    return PhobosLib.getPlayerModDataTable(player, POS_Constants.MODDATA_ALERTS) or {}
end

---------------------------------------------------------------
-- Watchlist (player modData)
---------------------------------------------------------------

--- Get player watchlist.
--- @param player IsoPlayer
--- @return table Array of watchlist entries
function POS_PlayerState.getWatchlist(player)
    return PhobosLib.getPlayerModDataTable(player, POS_Constants.MODDATA_WATCHLIST) or {}
end

--- Check if a category is on the player's watchlist.
--- @param player IsoPlayer
--- @param categoryId string
--- @return boolean
function POS_PlayerState.isWatching(player, categoryId)
    local wl = POS_PlayerState.getWatchlist(player)
    for _, entry in ipairs(wl) do
        if entry.categoryId == categoryId then return true end
    end
    return false
end

--- Add a category to the player's watchlist.
--- @param player IsoPlayer
--- @param categoryId string
--- @return boolean true if added, false if already watching or at max
function POS_PlayerState.addToWatchlist(player, categoryId)
    if POS_PlayerState.isWatching(player, categoryId) then return false end
    local wl = PhobosLib.getPlayerModDataTable(player, POS_Constants.MODDATA_WATCHLIST)
    if not wl then return false end
    -- Count entries using pairs() (# crashes on Java ModData)
    local entryCount = 0
    for k, _ in pairs(wl) do
        if type(k) == "number" then entryCount = entryCount + 1 end
    end
    local maxEntries = POS_Constants.WATCHLIST_MAX_ENTRIES
    if entryCount >= maxEntries then return false end
    local gt = getGameTime and getGameTime()
    local day = gt and gt:getNightsSurvived() or 0
    -- Append using explicit index (table.insert crashes on Java ModData)
    wl[entryCount + 1] = {
        categoryId = categoryId,
        addedDay = day,
        lastSnapshotAvg = nil,
        lastSnapshotDay = 0,
    }
    return true
end

--- Remove a category from the player's watchlist.
--- @param player IsoPlayer
--- @param categoryId string
--- @return boolean true if removed
function POS_PlayerState.removeFromWatchlist(player, categoryId)
    local wl = PhobosLib.getPlayerModDataTable(player, POS_Constants.MODDATA_WATCHLIST)
    if not wl then return false end
    -- Rebuild without the target entry (table.remove crashes on Java ModData)
    local found = false
    local rebuilt = {}
    local idx = 1
    for _, entry in pairs(wl) do
        if type(entry) == "table" then
            if not found and entry.categoryId == categoryId then
                found = true  -- skip this one
            else
                rebuilt[idx] = entry
                idx = idx + 1
            end
        end
    end
    if not found then return false end
    -- Clear and rewrite (ModData-safe)
    local keysToRemove = {}
    for k, _ in pairs(wl) do keysToRemove[#keysToRemove + 1] = k end
    for _, k in ipairs(keysToRemove) do wl[k] = nil end
    for k, v in pairs(rebuilt) do wl[k] = v end
    return true
end

---------------------------------------------------------------
-- Item discovery (intel-gated trade catalog)
---------------------------------------------------------------

--- Discover an item for the player via PhobosLib tracking.
--- @param player IsoPlayer
--- @param fullType string Item full type (e.g. "Base.Axe")
--- @param categoryId string Commodity category ID
--- @param day number|nil Game day of discovery (defaults to 0)
--- @return boolean true if newly discovered, false if already known
function POS_PlayerState.discoverItem(player, fullType, categoryId, day)
    return PhobosLib.trackDiscovery(player, POS_Constants.DISCOVERY_NAMESPACE,
        fullType, { categoryId = categoryId, day = day or 0 })
end

--- Check whether an item has been discovered by the player.
--- @param player IsoPlayer
--- @param fullType string Item full type
--- @return boolean
function POS_PlayerState.isItemDiscovered(player, fullType)
    return PhobosLib.isDiscovered(player, POS_Constants.DISCOVERY_NAMESPACE, fullType)
end

--- Get the full set of discovered items for a player.
--- @param player IsoPlayer
--- @return table Map of fullType -> discovery metadata
function POS_PlayerState.getDiscoveredItems(player)
    return PhobosLib.getDiscoveries(player, POS_Constants.DISCOVERY_NAMESPACE)
end
