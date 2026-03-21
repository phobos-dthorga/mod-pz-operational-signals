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
-- POS_DataRecorderService.lua
-- Core recorder buffer management. The Data-Recorder is the
-- single mandatory ingestion point for all passive/automated
-- sensor data in the POSnet pipeline.
---------------------------------------------------------------

require "POS_Constants"
require "POS_MediaManager"

POS_DataRecorderService = {}

local _TAG = "[POS:DataRec]"

--- Find an equipped Data-Recorder on the player (belt slot or inventory).
function POS_DataRecorderService.findEquippedRecorder(player)
    if not player then return nil end

    -- Check belt (back) slot first — canonical location
    local belt = player:getClothingItem_Back()
    if belt and belt:getFullType() == POS_Constants.ITEM_DATA_RECORDER then
        return belt
    end

    -- Check secondary hand
    local secondary = player:getSecondaryHandItem()
    if secondary and secondary:getFullType() == POS_Constants.ITEM_DATA_RECORDER then
        return secondary
    end

    -- Fallback: check inventory
    local inv = player:getInventory()
    if inv then
        return PhobosLib.findItemByFullType(inv, POS_Constants.ITEM_DATA_RECORDER)
    end

    return nil
end

--- Check if recorder has power (condition > 0).
function POS_DataRecorderService.isPowered(recorder)
    if not recorder then return false end
    local cond = PhobosLib.getConditionPercent(recorder)
    return cond and cond > 0
end

--- Initialise recorder modData defaults (idempotent).
function POS_DataRecorderService.ensureInitialized(recorder)
    if not recorder then return false end
    local md = PhobosLib.getModData(recorder)
    if not md then return false end

    if not md[POS_Constants.MD_RECORDER_ID] then
        md[POS_Constants.MD_RECORDER_ID] = PhobosLib.generateId()
    end
    if not md[POS_Constants.MD_RECORDER_BUFFER_COUNT] then
        md[POS_Constants.MD_RECORDER_BUFFER_COUNT] = 0
    end
    if not md[POS_Constants.MD_RECORDER_BUFFER_CAP] then
        local cap = POS_Sandbox and POS_Sandbox.getRecorderInternalBufferSize
            and POS_Sandbox.getRecorderInternalBufferSize()
            or POS_Constants.RECORDER_INTERNAL_BUFFER_DEFAULT
        md[POS_Constants.MD_RECORDER_BUFFER_CAP] = cap
    end
    if not md[POS_Constants.MD_RECORDER_TOTAL_RECORDED] then
        md[POS_Constants.MD_RECORDER_TOTAL_RECORDED] = 0
    end
    if not md[POS_Constants.MD_RECORDER_POWERED] then
        md[POS_Constants.MD_RECORDER_POWERED] = true
    end

    return true
end

--- Get the current buffer entry count.
function POS_DataRecorderService.getBufferCount(recorder)
    if not recorder then return 0 end
    local md = PhobosLib.getModData(recorder)
    return md and tonumber(md[POS_Constants.MD_RECORDER_BUFFER_COUNT]) or 0
end

--- Get the buffer capacity.
function POS_DataRecorderService.getBufferCapacity(recorder)
    if not recorder then return 0 end
    local md = PhobosLib.getModData(recorder)
    if md and md[POS_Constants.MD_RECORDER_BUFFER_CAP] then
        return tonumber(md[POS_Constants.MD_RECORDER_BUFFER_CAP]) or POS_Constants.RECORDER_INTERNAL_BUFFER_DEFAULT
    end
    return POS_Sandbox and POS_Sandbox.getRecorderInternalBufferSize
        and POS_Sandbox.getRecorderInternalBufferSize()
        or POS_Constants.RECORDER_INTERNAL_BUFFER_DEFAULT
end

--- Check if the internal buffer is full.
function POS_DataRecorderService.isBufferFull(recorder)
    return POS_DataRecorderService.getBufferCount(recorder) >= POS_DataRecorderService.getBufferCapacity(recorder)
end

--- Check if recorder has media inserted.
function POS_DataRecorderService.hasMedia(recorder)
    if not recorder then return false end
    local md = PhobosLib.getModData(recorder)
    return md and md[POS_Constants.MD_RECORDER_MEDIA_ID] ~= nil
end

--- Get the media type currently inserted.
function POS_DataRecorderService.getInsertedMediaType(recorder)
    if not recorder then return nil end
    local md = PhobosLib.getModData(recorder)
    return md and md[POS_Constants.MD_RECORDER_MEDIA_TYPE] or nil
end

--- Get a status summary table for the recorder.
function POS_DataRecorderService.getStatus(recorder)
    if not recorder then return nil end
    POS_DataRecorderService.ensureInitialized(recorder)

    local md = PhobosLib.getModData(recorder)
    if not md then return nil end

    return {
        id             = md[POS_Constants.MD_RECORDER_ID],
        powered        = POS_DataRecorderService.isPowered(recorder),
        condition      = PhobosLib.getConditionPercent(recorder) or 0,
        bufferCount    = POS_DataRecorderService.getBufferCount(recorder),
        bufferCapacity = POS_DataRecorderService.getBufferCapacity(recorder),
        hasMedia       = POS_DataRecorderService.hasMedia(recorder),
        mediaType      = md[POS_Constants.MD_RECORDER_MEDIA_TYPE],
        mediaId        = md[POS_Constants.MD_RECORDER_MEDIA_ID],
        mediaUsed      = tonumber(md[POS_Constants.MD_RECORDER_MEDIA_USED]) or 0,
        mediaCap       = tonumber(md[POS_Constants.MD_RECORDER_MEDIA_CAP]) or 0,
        totalRecorded  = tonumber(md[POS_Constants.MD_RECORDER_TOTAL_RECORDED]) or 0,
        sourceId       = md[POS_Constants.MD_RECORDER_SOURCE_ID],
    }
end

--- Append a data chunk to the recorder.
--- Writes to inserted media first; falls back to internal buffer.
--- Returns true if chunk was stored, false if all storage is full.
function POS_DataRecorderService.appendChunk(recorder, chunk)
    if not recorder or not chunk then return false end
    if not POS_DataRecorderService.isPowered(recorder) then return false end

    POS_DataRecorderService.ensureInitialized(recorder)
    local md = PhobosLib.getModData(recorder)
    if not md then return false end

    -- Try media first
    if md[POS_Constants.MD_RECORDER_MEDIA_ID] then
        local mediaUsed = tonumber(md[POS_Constants.MD_RECORDER_MEDIA_USED]) or 0
        local mediaCap = tonumber(md[POS_Constants.MD_RECORDER_MEDIA_CAP]) or 0
        if mediaUsed < mediaCap then
            md[POS_Constants.MD_RECORDER_MEDIA_USED] = mediaUsed + 1
            md[POS_Constants.MD_RECORDER_TOTAL_RECORDED] = (tonumber(md[POS_Constants.MD_RECORDER_TOTAL_RECORDED]) or 0) + 1

            -- Log the chunk to event log with media ID as actor
            if POS_EventLog and POS_EventLog.append then
                POS_EventLog.append(
                    POS_Constants.EVENT_SYSTEM_RECON,
                    POS_Constants.EVENT_RECORDER_CHUNK,
                    chunk.entityId or "unknown",
                    chunk.region or "",
                    md[POS_Constants.MD_RECORDER_MEDIA_ID],
                    0,
                    chunk.confidence or 50,
                    tostring(chunk.x or 0) .. "," .. tostring(chunk.y or 0)
                )
            end

            -- Tutorial: first data recorder use milestone
            if chunk.player and POS_TutorialService and POS_TutorialService.tryAward then
                POS_TutorialService.tryAward(chunk.player, POS_Constants.TUTORIAL_FIRST_DATA_RECORDER)
            end

            PhobosLib.debug("POS", _TAG, "chunk written to media (" .. mediaUsed + 1 .. "/" .. mediaCap .. ")")
            return true
        end
    end

    -- Fallback to internal buffer
    local bufCount = POS_DataRecorderService.getBufferCount(recorder)
    local bufCap = POS_DataRecorderService.getBufferCapacity(recorder)
    if bufCount < bufCap then
        md[POS_Constants.MD_RECORDER_BUFFER_COUNT] = bufCount + 1
        md[POS_Constants.MD_RECORDER_TOTAL_RECORDED] = (tonumber(md[POS_Constants.MD_RECORDER_TOTAL_RECORDED]) or 0) + 1

        -- Log to event log with recorder ID as actor
        if POS_EventLog and POS_EventLog.append then
            POS_EventLog.append(
                POS_Constants.EVENT_SYSTEM_RECON,
                POS_Constants.EVENT_RECORDER_CHUNK,
                chunk.entityId or "unknown",
                chunk.region or "",
                md[POS_Constants.MD_RECORDER_ID],
                0,
                chunk.confidence or 50,
                tostring(chunk.x or 0) .. "," .. tostring(chunk.y or 0)
            )
        end

        PhobosLib.debug("POS", _TAG, "chunk written to buffer (" .. (bufCount + 1) .. "/" .. bufCap .. ")")
        return true
    end

    PhobosLib.debug("POS", _TAG, "all storage full — chunk lost")
    return false
end

--- Insert media into the recorder. Validates compatibility.
--- @param recorder InventoryItem The recorder item
--- @param mediaItem InventoryItem The media to insert
--- @return boolean success
function POS_DataRecorderService.insertMedia(recorder, mediaItem)
    if not recorder or not mediaItem then return false end
    if not POS_MediaManager.isUsableMedia(mediaItem) then return false end

    POS_DataRecorderService.ensureInitialized(recorder)
    local md = PhobosLib.getModData(recorder)
    if not md then return false end

    -- Cannot insert if media already present
    if md[POS_Constants.MD_RECORDER_MEDIA_ID] then
        PhobosLib.debug("POS", _TAG, "cannot insert — media already present")
        return false
    end

    POS_MediaManager.ensureInitialized(mediaItem)
    local mediaMd = PhobosLib.getModData(mediaItem)
    if not mediaMd then return false end

    -- Store media reference in recorder modData
    md[POS_Constants.MD_RECORDER_MEDIA_TYPE] = mediaItem:getFullType()
    md[POS_Constants.MD_RECORDER_MEDIA_ID] = mediaMd[POS_Constants.MD_MEDIA_ID]
    md[POS_Constants.MD_RECORDER_MEDIA_USED] = POS_MediaManager.getEntryCount(mediaItem)
    md[POS_Constants.MD_RECORDER_MEDIA_CAP] = POS_MediaManager.getCapacity(mediaItem)

    -- Log insertion
    if POS_EventLog and POS_EventLog.append then
        POS_EventLog.append(
            POS_Constants.EVENT_SYSTEM_RECON,
            POS_Constants.EVENT_MEDIA_INSERT,
            mediaItem:getFullType(),
            "",
            md[POS_Constants.MD_RECORDER_ID],
            0, 0, ""
        )
    end

    PhobosLib.debug("POS", _TAG, "media inserted: " .. mediaItem:getFullType())
    return true
end

--- Eject media from the recorder. Clears media reference.
--- @return string|nil The media ID that was ejected, or nil
function POS_DataRecorderService.ejectMedia(recorder)
    if not recorder then return nil end
    local md = PhobosLib.getModData(recorder)
    if not md then return nil end

    local mediaId = md[POS_Constants.MD_RECORDER_MEDIA_ID]
    if not mediaId then return nil end

    -- Log ejection
    if POS_EventLog and POS_EventLog.append then
        POS_EventLog.append(
            POS_Constants.EVENT_SYSTEM_RECON,
            POS_Constants.EVENT_MEDIA_EJECT,
            md[POS_Constants.MD_RECORDER_MEDIA_TYPE] or "",
            "",
            md[POS_Constants.MD_RECORDER_ID],
            0, 0, ""
        )
    end

    -- Clear media reference
    md[POS_Constants.MD_RECORDER_MEDIA_TYPE] = nil
    md[POS_Constants.MD_RECORDER_MEDIA_ID] = nil
    md[POS_Constants.MD_RECORDER_MEDIA_USED] = nil
    md[POS_Constants.MD_RECORDER_MEDIA_CAP] = nil

    PhobosLib.debug("POS", _TAG, "media ejected: " .. tostring(mediaId))
    return mediaId
end

--- Flush internal buffer entries to inserted media.
--- @return number Number of entries flushed
function POS_DataRecorderService.flushBufferToMedia(recorder)
    if not recorder then return 0 end
    local md = PhobosLib.getModData(recorder)
    if not md then return 0 end

    if not md[POS_Constants.MD_RECORDER_MEDIA_ID] then return 0 end

    local bufCount = tonumber(md[POS_Constants.MD_RECORDER_BUFFER_COUNT]) or 0
    if bufCount <= 0 then return 0 end

    local mediaUsed = tonumber(md[POS_Constants.MD_RECORDER_MEDIA_USED]) or 0
    local mediaCap = tonumber(md[POS_Constants.MD_RECORDER_MEDIA_CAP]) or 0
    local mediaFree = math.max(0, mediaCap - mediaUsed)

    local toFlush = math.min(bufCount, mediaFree)
    if toFlush <= 0 then return 0 end

    md[POS_Constants.MD_RECORDER_BUFFER_COUNT] = bufCount - toFlush
    md[POS_Constants.MD_RECORDER_MEDIA_USED] = mediaUsed + toFlush

    PhobosLib.debug("POS", _TAG, "flushed " .. toFlush .. " buffer entries to media")
    return toFlush
end

--- Drain recorder power (condition) over time.
--- @param recorder InventoryItem
--- @param hours number Elapsed hours
function POS_DataRecorderService.drainPower(recorder, hours)
    if not recorder or not hours or hours <= 0 then return end

    local drainRate = POS_Sandbox and POS_Sandbox.getRecorderPowerDrainRate
        and POS_Sandbox.getRecorderPowerDrainRate()
        or POS_Constants.RECORDER_POWER_DRAIN_RATE_DEFAULT

    -- drainRate is in hundredths of condition per hour
    local condLoss = (drainRate * hours) / 100
    local currentCond = recorder:getCondition()
    local newCond = math.max(0, currentCond - condLoss)
    recorder:setCondition(newCond)

    if newCond <= 0 then
        PhobosLib.debug("POS", _TAG, "recorder battery depleted")
    end
end

--- Get recorder condition-based BPS modifier.
--- Full condition = 0 modifier; lower condition = negative modifier.
function POS_DataRecorderService.getConditionMod(recorder)
    if not recorder then return 0 end
    local condPct = PhobosLib.getConditionPercent(recorder) or 100
    -- Each percent below 100 costs BPS
    local deficit = 100 - condPct
    return -(deficit * POS_Constants.RECORDER_CONDITION_BPS_PER_PERCENT)
end
