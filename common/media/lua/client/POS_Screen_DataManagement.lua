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
-- POS_Screen_DataManagement.lua
-- Terminal screen for Data-Recorder management.
-- Process chunks, manage media, view buffer status.
---------------------------------------------------------------

require "POS_Constants"
require "POS_DataRecorderService"
require "POS_ChunkProcessor"
require "POS_MediaManager"
require "POS_TerminalWidgets"

local screen = {}
screen.id = POS_Constants.SCREEN_DATA_MANAGEMENT
screen.menuPath = "pos.main"
screen.sortOrder = 25
screen.titleKey = "UI_POS_DataManagement_Header"

--- Guard: requires an equipped Data-Recorder.
screen.canOpen = function()
    local player = getSpecificPlayer(0)
    if not player then return false, "UI_POS_DataManagement_NoRecorder" end
    local recorder = POS_DataRecorderService.findEquippedRecorder(player)
    if not recorder then return false, "UI_POS_DataManagement_NoRecorder" end
    if not POS_DataRecorderService.isPowered(recorder) then return false, "UI_POS_DataManagement_NoPower" end
    return true
end

--- Create the Data Management screen layout.
function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    local player = getSpecificPlayer(0)
    local recorder = player and POS_DataRecorderService.findEquippedRecorder(player)
    if not recorder then
        W.createLabel(ctx, W.safeGetText("UI_POS_DataManagement_NoRecorder"), C.dim)
        return
    end

    local status = POS_DataRecorderService.getStatus(recorder)
    if not status then return end

    -- Header: Recorder Status
    W.createLabel(ctx, W.safeGetText("UI_POS_Recorder_Status"), C.header)
    W.createSeparator(ctx)

    -- Power level
    local powerText = W.safeGetText("UI_POS_Recorder_Power") .. ": "
        .. string.format("%d%%", status.condition)
    W.createLabel(ctx, powerText, status.condition > 20 and C.value or C.alert)

    -- Buffer status
    local bufferText = W.safeGetText("UI_POS_Recorder_Buffer") .. ": "
        .. tostring(status.bufferCount) .. "/" .. tostring(status.bufferCapacity)
    W.createLabel(ctx, bufferText, C.label)

    -- Media status
    if status.hasMedia then
        local mediaName = W.safeGetText("UI_POS_Media_" ..
            (status.mediaType and "VHS" or "Unknown"))
        local mediaText = W.safeGetText("UI_POS_Recorder_Media") .. ": "
            .. tostring(status.mediaUsed) .. "/" .. tostring(status.mediaCap)
        W.createLabel(ctx, mediaText, C.value)
    else
        W.createLabel(ctx, W.safeGetText("UI_POS_Recorder_NoMedia"), C.dim)
    end

    -- Recording source
    if status.sourceId then
        local sourceLabel = W.safeGetText("UI_POS_Recorder_Recording", status.sourceId)
        W.createLabel(ctx, sourceLabel, C.value)
    else
        W.createLabel(ctx, W.safeGetText("UI_POS_Recorder_Idle"), C.dim)
    end

    W.createSeparator(ctx)

    -- Total chunks available for processing
    local totalChunks = status.bufferCount + status.mediaUsed
    local totalText = W.safeGetText("UI_POS_DataManagement_ChunksAvailable", tostring(totalChunks))
    W.createLabel(ctx, totalText, totalChunks > 0 and C.value or C.dim)

    W.createSeparator(ctx)

    -- Action buttons
    if totalChunks > 0 then
        W.createButton(ctx, W.safeGetText("UI_POS_DataManagement_ProcessAll"), function()
            local processed = POS_ChunkProcessor.processAll(player, recorder)
            if processed > 0 then
                PhobosLib.say(player, W.safeGetText("UI_POS_DataManagement_ProcessingComplete",
                    tostring(processed)))
            else
                PhobosLib.say(player, W.safeGetText("UI_POS_DataManagement_NoData"))
            end
            W.dynamicRefresh(screen, params)
        end)
    end

    if status.bufferCount > 0 and status.hasMedia then
        W.createButton(ctx, W.safeGetText("UI_POS_DataManagement_FlushBuffer"), function()
            local flushed = POS_DataRecorderService.flushBufferToMedia(recorder)
            if flushed > 0 then
                PhobosLib.say(player, W.safeGetText("UI_POS_DataManagement_BufferFlushed",
                    tostring(flushed)))
            end
            W.dynamicRefresh(screen, params)
        end)
    end

    if status.hasMedia then
        W.createButton(ctx, W.safeGetText("UI_POS_DataManagement_EjectMedia"), function()
            POS_DataRecorderService.ejectMedia(recorder)
            PhobosLib.say(player, W.safeGetText("UI_POS_DataManagement_MediaEjected"))
            W.dynamicRefresh(screen, params)
        end)
    end
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(_params)
    POS_TerminalWidgets.dynamicRefresh(screen, _params)
end

--- Context panel data for the right sidebar.
screen.getContextData = function(params)
    local player = getSpecificPlayer(0)
    local recorder = player and POS_DataRecorderService.findEquippedRecorder(player)
    if not recorder then return {} end

    local status = POS_DataRecorderService.getStatus(recorder)
    if not status then return {} end

    local data = {}
    table.insert(data, { type = "header", text = POS_TerminalWidgets.safeGetText("UI_POS_Recorder_Status") })
    table.insert(data, { type = "kv", key = POS_TerminalWidgets.safeGetText("UI_POS_Recorder_Power"),
        value = string.format("%d%%", status.condition) })
    table.insert(data, { type = "kv", key = POS_TerminalWidgets.safeGetText("UI_POS_Recorder_Buffer"),
        value = tostring(status.bufferCount) .. "/" .. tostring(status.bufferCapacity) })

    if status.hasMedia then
        table.insert(data, { type = "kv", key = POS_TerminalWidgets.safeGetText("UI_POS_Recorder_Media"),
            value = tostring(status.mediaUsed) .. "/" .. tostring(status.mediaCap) })
    end

    table.insert(data, { type = "kv", key = POS_TerminalWidgets.safeGetText("UI_POS_Recorder_TotalRecorded"),
        value = tostring(status.totalRecorded) })

    return data
end

POS_API.registerScreen(screen)
