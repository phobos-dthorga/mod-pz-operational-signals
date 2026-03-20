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

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_DataRecorderService"
require "POS_ChunkProcessor"
require "POS_MediaManager"
require "POS_TerminalWidgets"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_DATA_MANAGEMENT
screen.menuPath = {"pos.main"}
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

    -- Header
    W.drawHeader(ctx, "UI_POS_DataManagement_Header")

    local player = getSpecificPlayer(0)
    local recorder = player and POS_DataRecorderService.findEquippedRecorder(player)
    if not recorder then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_DataManagement_NoRecorder"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    local status = POS_DataRecorderService.getStatus(recorder)
    if not status then
        W.drawFooter(ctx)
        return
    end

    -- Power level with progress bar
    local powerPct = status.condition or 0
    W.drawProgressBar(ctx, "UI_POS_Recorder_Power", powerPct)

    -- Buffer status with progress bar
    local bufferCap = status.bufferCapacity or 1
    local bufferPct = math.floor((status.bufferCount or 0) / bufferCap * 100 + 0.5)
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Recorder_Buffer") .. ": "
        .. tostring(status.bufferCount) .. "/" .. tostring(bufferCap), C.text)
    ctx.y = ctx.y + ctx.lineH
    W.createProgressBar(ctx.panel, 8, ctx.y, ctx.pw - 16, bufferPct, C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Media status
    if status.hasMedia then
        local mediaText = W.safeGetText("UI_POS_Recorder_Media") .. ": "
            .. tostring(status.mediaUsed) .. "/" .. tostring(status.mediaCap)
        W.createLabel(ctx.panel, 8, ctx.y, mediaText, C.text)
        ctx.y = ctx.y + ctx.lineH
    else
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Recorder_NoMedia"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    end

    -- Recording source
    if status.sourceId then
        local sourceLabel = W.safeGetText("UI_POS_Recorder_Recording", status.sourceId)
        W.createLabel(ctx.panel, 8, ctx.y, sourceLabel, C.success)
        ctx.y = ctx.y + ctx.lineH
    else
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Recorder_Idle"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    end

    W.createSeparator(ctx.panel, 0, ctx.y)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Total chunks available for processing
    local totalChunks = (status.bufferCount or 0) + (status.mediaUsed or 0)
    local totalText = W.safeGetText("UI_POS_DataManagement_ChunksAvailable",
        tostring(totalChunks))
    W.createLabel(ctx.panel, 8, ctx.y,
        totalText, totalChunks > 0 and C.text or C.dim)
    ctx.y = ctx.y + ctx.lineH

    W.createSeparator(ctx.panel, 0, ctx.y)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Action buttons
    if totalChunks > 0 then
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[1] " .. W.safeGetText("UI_POS_DataManagement_ProcessAll"), nil,
            function()
                local processed = POS_ChunkProcessor.processAll(player, recorder)
                if processed > 0 then
                    PhobosLib.notifyOrSay(player, {
                        title   = W.safeGetText("UI_POS_DataManagement_Header"),
                        message = W.safeGetText("UI_POS_DataManagement_ProcessingComplete",
                            tostring(processed)),
                        icon    = POS_Constants.ITEM_DATA_RECORDER,
                        colour  = "success",
                        channel = POS_Constants.PN_CHANNEL_ID,
                    })
                else
                    PhobosLib.notifyOrSay(player, {
                        message = W.safeGetText("UI_POS_DataManagement_NoData"),
                        colour  = "info",
                        channel = POS_Constants.PN_CHANNEL_ID,
                    })
                end
                W.dynamicRefresh(screen, params)
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    end

    if (status.bufferCount or 0) > 0 and status.hasMedia then
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[2] " .. W.safeGetText("UI_POS_DataManagement_FlushBuffer"), nil,
            function()
                local flushed = POS_DataRecorderService.flushBufferToMedia(recorder)
                if flushed > 0 then
                    PhobosLib.notifyOrSay(player, {
                        title   = W.safeGetText("UI_POS_DataManagement_Header"),
                        message = W.safeGetText("UI_POS_DataManagement_BufferFlushed",
                            tostring(flushed)),
                        icon    = POS_Constants.ITEM_DATA_RECORDER,
                        colour  = "success",
                        channel = POS_Constants.PN_CHANNEL_ID,
                    })
                end
                W.dynamicRefresh(screen, params)
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    end

    if status.hasMedia then
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[3] " .. W.safeGetText("UI_POS_DataManagement_EjectMedia"), nil,
            function()
                POS_DataRecorderService.ejectMedia(recorder)
                PhobosLib.notifyOrSay(player, {
                    message = W.safeGetText("UI_POS_DataManagement_MediaEjected"),
                    icon    = POS_Constants.ITEM_DATA_RECORDER,
                    colour  = "info",
                    channel = POS_Constants.PN_CHANNEL_ID,
                })
                W.dynamicRefresh(screen, params)
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(_params)
    POS_TerminalWidgets.dynamicRefresh(screen, _params)
end

--- Context panel data for the right sidebar.
screen.getContextData = function(_params)
    local player = getSpecificPlayer(0)
    local recorder = player and POS_DataRecorderService.findEquippedRecorder(player)
    if not recorder then return {} end

    local status = POS_DataRecorderService.getStatus(recorder)
    if not status then return {} end

    local data = {}
    table.insert(data, { type = "header", text = POS_TerminalWidgets.safeGetText("UI_POS_Recorder_Status") })
    table.insert(data, { type = "kv", key = POS_TerminalWidgets.safeGetText("UI_POS_Recorder_Power"),
        value = string.format("%d%%", status.condition or 0) })
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

---------------------------------------------------------------

POS_API.registerScreen(screen)
