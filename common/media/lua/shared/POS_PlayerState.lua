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
-- Scalar state (rep, cash, intel access, UI prefs) remains in
-- player modData. Growth-prone arrays (watchlist, alerts,
-- orders, holdings) are delegated to POS_PlayerFileStore
-- which persists them to Zomboid/Lua/POSNET/ flat files.
---------------------------------------------------------------

require "POS_Constants"
require "POS_PlayerFileStore"

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
--- For watchlist/alerts/orders/holdings, use the dedicated getters.
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
-- Alerts (delegated to file store)
---------------------------------------------------------------

--- Add an alert to the player's alert queue (capped).
function POS_PlayerState.addAlert(player, alert)
    local alerts = POS_PlayerFileStore.getAlerts(player)
    local maxAlerts = POS_Sandbox and POS_Sandbox.getMaxPlayerAlerts
        and POS_Sandbox.getMaxPlayerAlerts() or POS_Constants.MAX_PLAYER_ALERTS
    PhobosLib.pushRolling(alerts, alert, maxAlerts)
    POS_PlayerFileStore.save(player)
end

--- Get player alerts.
function POS_PlayerState.getAlerts(player)
    return POS_PlayerFileStore.getAlerts(player)
end

---------------------------------------------------------------
-- Watchlist (delegated to file store)
---------------------------------------------------------------

--- Get player watchlist.
function POS_PlayerState.getWatchlist(player)
    return POS_PlayerFileStore.getWatchlist(player)
end

--- Check if a category is on the player's watchlist.
--- @param player IsoPlayer
--- @param categoryId string
--- @return boolean
function POS_PlayerState.isWatching(player, categoryId)
    local wl = POS_PlayerFileStore.getWatchlist(player)
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
    local wl = POS_PlayerFileStore.getWatchlist(player)
    local maxEntries = POS_Constants.WATCHLIST_MAX_ENTRIES
    if #wl >= maxEntries then return false end
    local gt = getGameTime and getGameTime()
    local day = gt and gt:getNightsSurvived() or 0
    table.insert(wl, {
        categoryId = categoryId,
        addedDay = day,
        lastSnapshotAvg = nil,
        lastSnapshotDay = 0,
    })
    POS_PlayerFileStore.save(player)
    return true
end

--- Remove a category from the player's watchlist.
--- @param player IsoPlayer
--- @param categoryId string
--- @return boolean true if removed
function POS_PlayerState.removeFromWatchlist(player, categoryId)
    local wl = POS_PlayerFileStore.getWatchlist(player)
    for i, entry in ipairs(wl) do
        if entry.categoryId == categoryId then
            table.remove(wl, i)
            POS_PlayerFileStore.save(player)
            return true
        end
    end
    return false
end
