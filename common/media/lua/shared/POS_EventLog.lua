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
-- POS_EventLog.lua
-- Append-only event logs and snapshot read/write via world
-- ModData (auto-persisted with save).  No file I/O.
-- Server-only writes; clients may read snapshots.
--
-- ModData layout under POSNET.EventLog:
--   logs = { ["economy_day821"] = "line1\nline2\n", ... }
--   snapshots = { ["economy"] = "header\n---\ndata\n", ... }
---------------------------------------------------------------

require "POS_Constants"
require "PhobosLib"

POS_EventLog = {}

local _TAG       = "[POS:EventLog]"
local _NAMESPACE = "POSNET"
local _LOG_KEY   = "EventLog"
local FIELD_SEP  = POS_Constants.EVENT_LOG_SEPARATOR     -- "|"
local LOG_VERSION = POS_Constants.EVENT_LOG_VERSION       -- 1

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

--- Get the logs sub-table from world ModData.
local function getLogStore()
    local el = PhobosLib.getWorldModDataTable(_NAMESPACE, _LOG_KEY)
    if not el.logs then el.logs = {} end
    return el.logs
end

--- Get the snapshots sub-table from world ModData.
local function getSnapshotStore()
    local el = PhobosLib.getWorldModDataTable(_NAMESPACE, _LOG_KEY)
    if not el.snapshots then el.snapshots = {} end
    return el.snapshots
end

--- Build the ModData key for a system+day log.
function POS_EventLog.getLogKey(system, day)
    return system .. "_day" .. tostring(day)
end

---------------------------------------------------------------
-- Append
---------------------------------------------------------------

--- Append a single event record to the appropriate log.
--- Server-only. Guarded internally.
function POS_EventLog.append(system, eventType, entityId, regionId, actorId, qty, priceBps, cause)
    if not POS_WorldState or not POS_WorldState.isAuthority() then return false end

    local day = POS_WorldState.getWorldDay()
    local key = POS_EventLog.getLogKey(system, day)

    local line = table.concat({
        tostring(day),
        tostring(system or ""),
        tostring(eventType or ""),
        tostring(entityId or ""),
        tostring(regionId or ""),
        tostring(actorId or ""),
        tostring(qty or 0),
        tostring(priceBps or 0),
        tostring(cause or ""),
        tostring(LOG_VERSION),
    }, FIELD_SEP)

    local logs = getLogStore()
    local existing = logs[key]
    if existing and type(existing) == "string" then
        logs[key] = existing .. line .. "\n"
    else
        logs[key] = line .. "\n"
    end
    return true
end

---------------------------------------------------------------
-- Snapshots
---------------------------------------------------------------

--- Write a snapshot for fast reload.
--- Server-only.
function POS_EventLog.writeSnapshot(snapshotType, headerLine, dataLines)
    if not POS_WorldState or not POS_WorldState.isAuthority() then return false end

    local content = headerLine .. "\n---\n"
    for i = 1, #dataLines do
        content = content .. dataLines[i] .. "\n"
    end

    local snapshots = getSnapshotStore()
    snapshots[snapshotType] = content
    return true
end

--- Read a snapshot. Returns header string and data array, or nil.
function POS_EventLog.readSnapshot(snapshotType)
    local snapshots = getSnapshotStore()
    local content = snapshots[snapshotType]
    if not content or type(content) ~= "string" then return nil, nil end

    local lines = PhobosLib.split(content, "\n")
    if #lines < 2 then return nil, nil end

    local headerLine = lines[1]
    -- lines[2] is "---" separator
    local dataLines = {}
    for i = 3, #lines do
        if lines[i] and lines[i] ~= "" then
            dataLines[#dataLines + 1] = lines[i]
        end
    end

    return headerLine, dataLines
end

---------------------------------------------------------------
-- Purge
---------------------------------------------------------------

--- Purge event logs older than maxAgeDays.
--- Server-only. Cleaner than file truncation — just deletes keys.
function POS_EventLog.purgeOldLogs(maxAgeDays)
    if not POS_WorldState or not POS_WorldState.isAuthority() then return 0 end

    local currentDay = POS_WorldState.getWorldDay()
    local systems = {
        POS_Constants.EVENT_SYSTEM_ECONOMY,
        POS_Constants.EVENT_SYSTEM_STOCKS,
        POS_Constants.EVENT_SYSTEM_RECON,
    }
    local purged = 0
    local logs = getLogStore()

    for _, system in ipairs(systems) do
        for day = math.max(0, currentDay - maxAgeDays - POS_Constants.EVENT_LOG_PURGE_BUFFER),
                  math.max(0, currentDay - maxAgeDays) do
            local key = POS_EventLog.getLogKey(system, day)
            if logs[key] then
                logs[key] = nil
                purged = purged + 1
            end
        end
    end

    if purged > 0 then
        PhobosLib.debug("POS", _TAG, "Purged " .. purged .. " old log entries")
    end
    return purged
end
