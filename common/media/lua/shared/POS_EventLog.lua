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
-- Append-only event logs and snapshot read/write via PZ's
-- getFileWriter() / getFileReader() API.
-- Server-only writes; clients may read snapshots.
---------------------------------------------------------------

require "POS_Constants"

POS_EventLog = {}

local LOG_DIR      = POS_Constants.EVENT_LOG_DIR          -- "POSNET/events/"
local SNAPSHOT_DIR = POS_Constants.EVENT_SNAPSHOT_DIR      -- "POSNET/snapshots/"
local FIELD_SEP    = POS_Constants.EVENT_LOG_SEPARATOR     -- "|"
local LOG_VERSION  = POS_Constants.EVENT_LOG_VERSION       -- 1

---------------------------------------------------------------
-- Path helpers
---------------------------------------------------------------

--- Get the log file path for a given system and day.
--- Uses flat file names (PZ getFileWriter does not create subdirectories).
function POS_EventLog.getLogPath(system, day)
    return "POSNET_" .. system .. "_day" .. tostring(day) .. ".log"
end

---------------------------------------------------------------
-- Append
---------------------------------------------------------------

--- Append a single event record to the appropriate log file.
--- Server-only. Guarded internally.
function POS_EventLog.append(system, eventType, entityId, regionId, actorId, qty, priceBps, cause)
    if not POS_WorldState or not POS_WorldState.isAuthority() then return false end

    local enableLogs = POS_Sandbox and POS_Sandbox.getEnableEventLogs
        and POS_Sandbox.getEnableEventLogs()
    if enableLogs == false then return false end

    local day = POS_WorldState.getWorldDay()
    local path = POS_EventLog.getLogPath(system, day)

    local writer = getFileWriter(path, true, false)
    if not writer then
        PhobosLib.debug("POS", "[EventLog] Failed to open writer: " .. tostring(path))
        return false
    end

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

    writer:write(line .. "\n")
    writer:close()
    return true
end

---------------------------------------------------------------
-- Snapshots
---------------------------------------------------------------

--- Write a snapshot file for fast reload.
--- Server-only.
function POS_EventLog.writeSnapshot(snapshotType, headerLine, dataLines)
    if not POS_WorldState or not POS_WorldState.isAuthority() then return false end

    local path = "POSNET_snapshot_" .. snapshotType .. ".txt"
    local writer = getFileWriter(path, false, false)  -- overwrite
    if not writer then
        PhobosLib.debug("POS", "[EventLog] Failed to open snapshot writer: " .. tostring(path))
        return false
    end

    writer:write(headerLine .. "\n")
    writer:write("---\n")
    for i = 1, #dataLines do
        writer:write(dataLines[i] .. "\n")
    end
    writer:close()
    return true
end

--- Read a snapshot file. Returns header string and data array, or nil.
function POS_EventLog.readSnapshot(snapshotType)
    local path = "POSNET_snapshot_" .. snapshotType .. ".txt"
    local reader = getFileReader(path, false)
    if not reader then return nil, nil end

    local headerLine = reader:readLine()
    local separator = reader:readLine()  -- "---"

    if not headerLine or not separator then
        reader:close()
        return nil, nil
    end

    local dataLines = {}
    local line = reader:readLine()
    while line do
        dataLines[#dataLines + 1] = line
        line = reader:readLine()
    end
    reader:close()

    return headerLine, dataLines
end

---------------------------------------------------------------
-- Purge
---------------------------------------------------------------

--- Purge event log files older than maxAgeDays.
--- Server-only.
function POS_EventLog.purgeOldLogs(maxAgeDays)
    if not POS_WorldState or not POS_WorldState.isAuthority() then return 0 end
    -- Note: PZ's Lua sandbox does not provide directory listing.
    -- Purging is best-effort: we track the current day and delete known
    -- old files by constructing their expected paths.
    local currentDay = POS_WorldState.getWorldDay()
    local systems = {
        POS_Constants.EVENT_SYSTEM_ECONOMY,
        POS_Constants.EVENT_SYSTEM_STOCKS,
        POS_Constants.EVENT_SYSTEM_RECON,
    }
    local purged = 0

    for _, system in ipairs(systems) do
        for day = math.max(0, currentDay - maxAgeDays - POS_Constants.EVENT_LOG_PURGE_BUFFER),
                  math.max(0, currentDay - maxAgeDays) do
            -- We cannot delete files in PZ Lua, but we can overwrite them empty
            local path = POS_EventLog.getLogPath(system, day)
            local writer = getFileWriter(path, false, false)
            if writer then
                writer:write("")  -- truncate
                writer:close()
                purged = purged + 1
            end
        end
    end

    return purged
end
