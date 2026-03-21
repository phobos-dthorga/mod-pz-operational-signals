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
-- POS_WatchlistService.lua
-- Comparison logic and alert generation for watched categories.
-- Detects significant price changes and emits alerts.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_PlayerState"
require "POS_MarketService"
require "POS_MarketRegistry"

POS_WatchlistService = {}

---------------------------------------------------------------
-- Core: check watchlist for alerts
---------------------------------------------------------------

--- Check all watched categories for significant price changes.
--- Updates snapshots and returns any alerts generated.
--- @param player IsoPlayer
--- @return table[] Array of alert objects { categoryId, labelKey, oldAvg, newAvg, changePct }
function POS_WatchlistService.checkForAlerts(player)
    if not player then return {} end
    if not POS_Sandbox or not POS_Sandbox.getEnableWatchlist() then return {} end

    local wl = POS_PlayerState.getWatchlist(player)
    local threshold = POS_Sandbox.getWatchlistAlertThresholdPct()
    local alerts = {}

    local gt = getGameTime and getGameTime()
    local currentDay = gt and gt:getNightsSurvived() or 0

    for _, entry in ipairs(wl) do
        local summary = POS_MarketService.getCommoditySummary(entry.categoryId)
        if summary and summary.avgPrice and summary.avgPrice > 0 then
            local newAvg = summary.avgPrice

            if entry.lastSnapshotAvg and entry.lastSnapshotAvg > 0 then
                local changePct = ((newAvg - entry.lastSnapshotAvg) / entry.lastSnapshotAvg) * 100
                if math.abs(changePct) >= threshold then
                    local catDef = POS_MarketRegistry.getCategory(entry.categoryId)
                    table.insert(alerts, {
                        categoryId = entry.categoryId,
                        labelKey = catDef and catDef.labelKey
                            or ("UI_POS_Market_Cat_" .. entry.categoryId),
                        oldAvg = entry.lastSnapshotAvg,
                        newAvg = newAvg,
                        changePct = changePct,
                    })
                end
            end

            -- Update snapshot
            entry.lastSnapshotAvg = newAvg
            entry.lastSnapshotDay = currentDay
        end
    end

    return alerts
end

--- Fire alerts through PhobosNotifications (with say() fallback).
--- @param player IsoPlayer
--- @param alerts table[] from checkForAlerts
function POS_WatchlistService.fireNotifications(player, alerts)
    if not alerts or #alerts == 0 then return end

    for _, alert in ipairs(alerts) do
        local catLabel = PhobosLib.safeGetText(alert.labelKey)
        local direction = alert.changePct >= 0 and "+" or ""
        local message = catLabel .. ": " .. direction
            .. string.format("%.1f%%", alert.changePct)

        PhobosLib.notifyOrSay(player, {
            title    = PhobosLib.safeGetText("UI_POS_Market_PriceAlert"),
            message  = message,
            colour   = alert.changePct >= 0 and "success" or "warning",
            channel  = POS_Constants.PN_CHANNEL_ID,
            priority = "normal",
        })

        -- Also store as player alert for in-terminal history
        POS_PlayerState.addAlert(player, {
            type = "watchlist",
            categoryId = alert.categoryId,
            changePct = alert.changePct,
            day = getGameTime and getGameTime():getNightsSurvived() or 0,
        })
    end
end

--- Convenience: check and fire in one call.
--- Always flushes snapshot updates to the player file store so that
--- in-memory mutations survive game saves and unexpected exits.
--- @param player IsoPlayer
function POS_WatchlistService.refresh(player)
    local alerts = POS_WatchlistService.checkForAlerts(player)
    POS_WatchlistService.fireNotifications(player, alerts)
    -- Flush snapshot mutations even when no alerts fired
    POS_PlayerFileStore.save(player)
end

--- Count pending alerts for a player (used by Markets hub badge).
--- @param player IsoPlayer
--- @return number
function POS_WatchlistService.countPendingAlerts(player)
    if not player then return 0 end
    local playerAlerts = POS_PlayerState.getAlerts(player)
    local count = 0
    for _, a in ipairs(playerAlerts) do
        if a.type == "watchlist" then
            count = count + 1
        end
    end
    return count
end
