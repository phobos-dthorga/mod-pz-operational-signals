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
-- Player-bound ModData accessor for POSnet state.
-- Stores reputation, cash, watchlist, orders, holdings, alerts,
-- and UI preferences on the player's modData table.
---------------------------------------------------------------

require "POS_Constants"

POS_PlayerState = {}

local PLAYER_SCHEMA_VERSION = POS_Constants.SCHEMA_VERSION

---------------------------------------------------------------
-- Default player state template
---------------------------------------------------------------

local function createDefaultState()
    return {
        schemaVersion = PLAYER_SCHEMA_VERSION,
        rep = 0,
        cash = 0,
        watchlist = {},
        openOrders = {},
        holdings = {},
        intelAccess = {
            civilianBand = true,
            militaryBand = false,
        },
        alerts = {},
        uiPrefs = {},
        lastMarketSyncDay = 0,
    }
end

---------------------------------------------------------------
-- Core accessor
---------------------------------------------------------------

--- Get or create the POSnet player state table.
--- @param player IsoPlayer
--- @return table The POSNET player state sub-table
function POS_PlayerState.get(player)
    if not player then return createDefaultState() end
    local md = player:getModData()
    if not md.POSNET then
        md.POSNET = createDefaultState()
    end
    -- Ensure all fields exist (forward compat)
    local ps = md.POSNET
    ps.schemaVersion = ps.schemaVersion or PLAYER_SCHEMA_VERSION
    ps.rep = ps.rep or 0
    ps.cash = ps.cash or 0
    ps.watchlist = ps.watchlist or {}
    ps.openOrders = ps.openOrders or {}
    ps.holdings = ps.holdings or {}
    ps.intelAccess = ps.intelAccess or { civilianBand = true, militaryBand = false }
    ps.alerts = ps.alerts or {}
    ps.uiPrefs = ps.uiPrefs or {}
    ps.lastMarketSyncDay = ps.lastMarketSyncDay or 0
    return ps
end

---------------------------------------------------------------
-- Convenience helpers
---------------------------------------------------------------

--- Add an alert to the player's alert queue (capped).
function POS_PlayerState.addAlert(player, alert)
    local ps = POS_PlayerState.get(player)
    local maxAlerts = POS_Sandbox and POS_Sandbox.getMaxPlayerAlerts
        and POS_Sandbox.getMaxPlayerAlerts() or POS_Constants.MAX_PLAYER_ALERTS
    PhobosLib.pushRolling(ps.alerts, alert, maxAlerts)
end

--- Get player alerts.
function POS_PlayerState.getAlerts(player)
    return POS_PlayerState.get(player).alerts
end

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

--- Get player watchlist.
function POS_PlayerState.getWatchlist(player)
    return POS_PlayerState.get(player).watchlist
end
