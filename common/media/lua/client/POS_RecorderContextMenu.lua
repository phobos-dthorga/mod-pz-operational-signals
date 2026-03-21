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
-- POS_RecorderContextMenu.lua
-- Right-click context menu for Data-Recorder and data sources.
--
-- Sub-menu rule (§10.1): multiple actions on one object are
-- grouped into a sub-menu rather than cluttering the top-level.
--
-- Structure:
--   Data-Recorder (L1)
--     ├── Media Management (L2)
--     │    ├── Insert Media > (L3, family-grouped)
--     │    ├── Eject Media
--     │    ├── Auto-Feed [ON/OFF]
--     │    ├── Flush Buffer → Media
--     │    └── View Media Status
--     └── View Recorder Status
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_DataRecorderService"
require "POS_DataSourceRegistry"
require "POS_MediaManager"

POS_RecorderContextMenu = {}

---------------------------------------------------------------
-- Callbacks
---------------------------------------------------------------

local function onInsertMedia(items, mediaItem, player, recorder)
    if not recorder or not mediaItem then return end
    POS_DataRecorderService.insertMedia(recorder, mediaItem)

    -- Sync media entry count to actual media modData
    local mediaMd = PhobosLib.getModData(mediaItem)
    if mediaMd then
        mediaMd[POS_Constants.MD_MEDIA_ENTRY_COUNT] = POS_MediaManager.getEntryCount(mediaItem)
    end

    PhobosLib.notifyOrSay(player, {
        title   = PhobosLib.safeGetText("UI_POS_ContextMenu_InsertMedia"),
        message = tostring(mediaItem:getDisplayName()),
        icon    = POS_Constants.ITEM_DATA_RECORDER,
        colour  = "success",
        channel = POS_Constants.PN_CHANNEL_ID,
    })
end

local function onEjectMedia(items, player, recorder)
    if not recorder then return end
    POS_DataRecorderService.ejectMedia(recorder)
    PhobosLib.notifyOrSay(player, {
        message = PhobosLib.safeGetText("UI_POS_DataManagement_MediaEjected"),
        icon    = POS_Constants.ITEM_DATA_RECORDER,
        colour  = "info",
        channel = POS_Constants.PN_CHANNEL_ID,
    })
end

local function onToggleAutoFeed(items, player, recorder)
    if not recorder then return end
    local wasEnabled = POS_DataRecorderService.isAutoFeedEnabled(recorder)
    local newState = POS_DataRecorderService.setAutoFeed(recorder, not wasEnabled)

    if newState then
        PhobosLib.notifyOrSay(player, {
            message = PhobosLib.safeGetText("UI_POS_Recorder_AutoFeedEnabled"),
            icon    = POS_Constants.ITEM_DATA_RECORDER,
            colour  = "success",
            channel = POS_Constants.PN_CHANNEL_ID,
        })

        -- If toggled ON and no media present, trigger immediate deep search
        if not POS_DataRecorderService.hasMedia(recorder) then
            local media = POS_DataRecorderService.findUsableMediaDeep(player)
            if media then
                POS_DataRecorderService.insertMedia(recorder, media)
                PhobosLib.notifyOrSay(player, {
                    message = PhobosLib.safeGetText("UI_POS_Recorder_AutoFeedInserted", media:getDisplayName()),
                    icon    = POS_Constants.ITEM_DATA_RECORDER,
                    colour  = "success",
                    channel = POS_Constants.PN_CHANNEL_ID,
                })
            else
                POS_DataRecorderService.setAutoFeed(recorder, false)
                PhobosLib.notifyOrSay(player, {
                    message = PhobosLib.safeGetText("UI_POS_Recorder_AutoFeedNoMedia"),
                    icon    = POS_Constants.ITEM_DATA_RECORDER,
                    colour  = "warning",
                    channel = POS_Constants.PN_CHANNEL_ID,
                })
            end
        end
    else
        PhobosLib.notifyOrSay(player, {
            message = PhobosLib.safeGetText("UI_POS_Recorder_AutoFeedDisabled"),
            icon    = POS_Constants.ITEM_DATA_RECORDER,
            colour  = "info",
            channel = POS_Constants.PN_CHANNEL_ID,
        })
    end
end

local function onFlushBuffer(items, player, recorder)
    if not recorder then return end

    if not POS_DataRecorderService.hasMedia(recorder) then
        PhobosLib.notifyOrSay(player, {
            message = PhobosLib.safeGetText("UI_POS_Recorder_NoMediaForFlush"),
            icon    = POS_Constants.ITEM_DATA_RECORDER,
            colour  = "warning",
            channel = POS_Constants.PN_CHANNEL_ID,
        })
        return
    end

    local flushed = POS_DataRecorderService.flushBufferToMedia(recorder)
    if flushed > 0 then
        PhobosLib.notifyOrSay(player, {
            message = PhobosLib.safeGetText("UI_POS_Recorder_BufferFlushed", tostring(flushed)),
            icon    = POS_Constants.ITEM_DATA_RECORDER,
            colour  = "success",
            channel = POS_Constants.PN_CHANNEL_ID,
        })
    else
        PhobosLib.notifyOrSay(player, {
            message = PhobosLib.safeGetText("UI_POS_Recorder_BufferEmpty"),
            icon    = POS_Constants.ITEM_DATA_RECORDER,
            colour  = "info",
            channel = POS_Constants.PN_CHANNEL_ID,
        })
    end
end

local function onViewMediaStatus(items, player, recorder)
    if not recorder then return end
    local status = POS_DataRecorderService.getStatus(recorder)
    if not status then return end

    if not status.hasMedia then
        PhobosLib.say(player, PhobosLib.safeGetText("UI_POS_Recorder_MediaStatus_NoMedia"))
        return
    end

    local def = POS_MediaManager.getMediaDef({ getFullType = function() return status.mediaType end })
    local familyName = def and def.family or "?"
    local fidelity = def and def.fidelity or "?"

    local msg = PhobosLib.safeGetText("UI_POS_Recorder_MediaStatus_Family", familyName)
        .. " | " .. PhobosLib.safeGetText("UI_POS_Recorder_MediaStatus_Capacity",
            tostring(status.mediaUsed), tostring(status.mediaCap))
        .. " | " .. PhobosLib.safeGetText("UI_POS_Recorder_MediaStatus_Fidelity", fidelity)
    PhobosLib.say(player, msg)
end

local function onViewRecorderStatus(items, player, recorder)
    if not recorder then return end
    local status = POS_DataRecorderService.getStatus(recorder)
    if not status then return end

    local msg = PhobosLib.safeGetText("UI_POS_Recorder_Status") .. ": "
        .. string.format("%d%%", status.condition) .. " | "
        .. PhobosLib.safeGetText("UI_POS_Recorder_Buffer") .. ": "
        .. tostring(status.bufferCount) .. "/" .. tostring(status.bufferCapacity)
    if status.hasMedia then
        msg = msg .. " | " .. PhobosLib.safeGetText("UI_POS_Recorder_Media") .. ": "
            .. tostring(status.mediaUsed) .. "/" .. tostring(status.mediaCap)
    end
    PhobosLib.say(player, msg)
end

---------------------------------------------------------------
-- Insert Media sub-menu builder (family-grouped)
---------------------------------------------------------------

local function buildInsertMediaMenu(context, insertMenu, items, player, recorder)
    local inv = player:getInventory()
    local foundMedia = false
    local lastFamily = nil

    -- Iterate in search order; group by family with header labels
    for _, ft in ipairs(POS_Constants.USABLE_MEDIA_SEARCH_ORDER) do
        local mediaItems = inv:getItemsFromFullType(ft)
        if mediaItems and mediaItems:size() > 0 then
            local media = mediaItems:get(0)
            if POS_MediaManager.isUsableMedia(media) then
                -- Insert family header if family changed
                local def = POS_MediaManager.getMediaDef(media)
                local family = def and def.family or nil
                if family and family ~= lastFamily then
                    local labelKey = POS_Constants.MEDIA_FAMILY_LABEL_KEYS[family]
                    if labelKey then
                        local headerOpt = insertMenu:addOption(
                            PhobosLib.safeGetText(labelKey), items, nil)
                        headerOpt.notAvailable = true
                    end
                    lastFamily = family
                end

                -- Add the actual media item option
                local label = media:getDisplayName()
                if POS_MediaManager.isFull(media) then
                    label = label .. " (" .. PhobosLib.safeGetText("UI_POS_Market_NoData") .. ")"
                end
                local opt = insertMenu:addOption(
                    label, items, onInsertMedia, media, player, recorder)
                if POS_MediaManager.isFull(media) then
                    opt.notAvailable = true
                end
                foundMedia = true
            end
        end
    end

    if not foundMedia then
        local noMedia = insertMenu:addOption(
            PhobosLib.safeGetText("UI_POS_ContextMenu_NoMediaAvailable"), items, nil)
        noMedia.notAvailable = true
    end
end

---------------------------------------------------------------
-- Inventory context menu handler
---------------------------------------------------------------

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    for _, item in ipairs(items) do
        local invItem = item
        if type(item) == "table" then
            invItem = item.items and item.items[1]
        end

        if invItem and invItem.getFullType then
            local fullType = invItem:getFullType()

            -- Data-Recorder sub-menu (Level 1)
            if fullType == POS_Constants.ITEM_DATA_RECORDER then
                local recorderMenu = context:getNew(context)
                local subOption = context:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_DataRecorder"),
                    items, nil)
                context:addSubMenu(subOption, recorderMenu)

                -----------------------------------------------
                -- Media Management sub-menu (Level 2)
                -----------------------------------------------
                local mediaMenu = context:getNew(context)
                local mediaMgmtOption = recorderMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_MediaManagement"),
                    items, nil)
                context:addSubMenu(mediaMgmtOption, mediaMenu)

                -- Insert Media (Level 3, family-grouped)
                local insertOption = mediaMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_InsertMedia"),
                    items, nil)

                if POS_DataRecorderService.hasMedia(invItem) then
                    insertOption.notAvailable = true
                    local tt = ISWorldObjectContextMenu.addToolTip()
                    tt.description = PhobosLib.safeGetText("UI_POS_ContextMenu_MediaAlreadyInserted")
                    insertOption.toolTip = tt
                else
                    local insertMenu = context:getNew(context)
                    context:addSubMenu(insertOption, insertMenu)
                    buildInsertMediaMenu(context, insertMenu, items, player, invItem)
                end

                -- Eject Media
                local ejectOpt = mediaMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_EjectMedia"),
                    items, onEjectMedia, player, invItem)
                if not POS_DataRecorderService.hasMedia(invItem) then
                    ejectOpt.notAvailable = true
                end

                -- Auto-Feed toggle
                local autoFeedEnabled = POS_DataRecorderService.isAutoFeedEnabled(invItem)
                local autoFeedLabel = autoFeedEnabled
                    and PhobosLib.safeGetText("UI_POS_ContextMenu_AutoFeedOn")
                    or PhobosLib.safeGetText("UI_POS_ContextMenu_AutoFeedOff")
                mediaMenu:addOption(autoFeedLabel, items, onToggleAutoFeed, player, invItem)

                -- Flush Buffer → Media
                local flushOpt = mediaMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_FlushBuffer"),
                    items, onFlushBuffer, player, invItem)
                local hasMedia = POS_DataRecorderService.hasMedia(invItem)
                local bufCount = POS_DataRecorderService.getBufferCount(invItem)
                if not hasMedia or bufCount <= 0 then
                    flushOpt.notAvailable = true
                end

                -- View Media Status
                mediaMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_ViewMediaStatus"),
                    items, onViewMediaStatus, player, invItem)

                -----------------------------------------------
                -- View Recorder Status (Level 2, direct)
                -----------------------------------------------
                recorderMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_ViewRecorderStatus"),
                    items, onViewRecorderStatus, player, invItem)

                return
            end

            -- Source device sub-menu (camcorder, logger)
            local deviceReg = POS_ReconDeviceRegistry and POS_ReconDeviceRegistry.getByItemType(fullType)
            if deviceReg and deviceReg.scanType ~= "none" then
                local posnetMenu = context:getNew(context)
                local subOpt = context:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_POSnet"),
                    items, nil)
                context:addSubMenu(subOpt, posnetMenu)

                local recorder = POS_DataRecorderService.findEquippedRecorder(player)
                local recordOpt = posnetMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_RecordUsingRecorder"),
                    items, nil)
                if not recorder then
                    recordOpt.notAvailable = true
                    local tt = ISWorldObjectContextMenu.addToolTip()
                    tt.description = PhobosLib.safeGetText("UI_POS_DataManagement_NoRecorder")
                    recordOpt.toolTip = tt
                end
                return
            end
        end
    end
end

Events.OnPreFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
