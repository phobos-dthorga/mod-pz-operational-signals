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
-- Sub-menu rule: multiple actions on one object are grouped
-- into a sub-menu rather than cluttering the top-level menu.
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

    PhobosLib.say(player, PhobosLib.safeGetText("UI_POS_ContextMenu_InsertMedia") .. ": "
        .. tostring(mediaItem:getDisplayName()))
end

local function onEjectMedia(items, player, recorder)
    if not recorder then return end
    POS_DataRecorderService.ejectMedia(recorder)
    PhobosLib.say(player, PhobosLib.safeGetText("UI_POS_DataManagement_MediaEjected"))
end

local function onViewStatus(items, player, recorder)
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

            -- Data-Recorder sub-menu
            if fullType == POS_Constants.ITEM_DATA_RECORDER then
                local recorderMenu = context:getNew(context)
                local subOption = context:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_DataRecorder"),
                    items, nil)
                context:addSubMenu(subOption, recorderMenu)

                -- Insert Media (nested submenu)
                local insertOption = recorderMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_InsertMedia"),
                    items, nil)

                -- Check if media already inserted
                if POS_DataRecorderService.hasMedia(invItem) then
                    insertOption.notAvailable = true
                    local tt = ISWorldObjectContextMenu.addToolTip()
                    tt.description = PhobosLib.safeGetText("UI_POS_ContextMenu_MediaAlreadyInserted")
                    insertOption.toolTip = tt
                else
                    -- Build insert media submenu with available media
                    local insertMenu = context:getNew(context)
                    context:addSubMenu(insertOption, insertMenu)

                    local inv = player:getInventory()
                    local mediaTypes = {
                        POS_Constants.ITEM_BLANK_FLOPPY_DISK,
                        POS_Constants.ITEM_RECORDED_FLOPPY_DISK,
                        POS_Constants.ITEM_WORN_FLOPPY_DISK,
                        POS_Constants.ITEM_MICROCASSETTE,
                        POS_Constants.ITEM_RECORDED_MICROCASSETTE,
                        POS_Constants.ITEM_REWOUND_MICROCASSETTE,
                        POS_Constants.ITEM_BLANK_VHS_TAPE,
                        POS_Constants.ITEM_REFURBISHED_TAPE,
                        POS_Constants.ITEM_SPLICED_TAPE,
                        POS_Constants.ITEM_IMPROVISED_TAPE,
                    }

                    local foundMedia = false
                    for _, mt in ipairs(mediaTypes) do
                        local mediaItems = inv:getItemsFromFullType(mt)
                        if mediaItems and mediaItems:size() > 0 then
                            local media = mediaItems:get(0)
                            if POS_MediaManager.isUsableMedia(media) then
                                insertMenu:addOption(
                                    media:getDisplayName(),
                                    items, onInsertMedia, media, player, invItem)
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

                -- Eject Media
                local ejectOpt = recorderMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_EjectMedia"),
                    items, onEjectMedia, player, invItem)
                if not POS_DataRecorderService.hasMedia(invItem) then
                    ejectOpt.notAvailable = true
                end

                -- View Status
                recorderMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_ContextMenu_ViewStatus"),
                    items, onViewStatus, player, invItem)

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
