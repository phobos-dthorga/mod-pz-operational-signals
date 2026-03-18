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
-- POS_ContextMenu.lua
-- Right-click context menu for POSnet radio connections.
--
-- Adds "Connect to POSnet" when the player right-clicks:
--   1. A world-placed radio (IsoWaveSignal)
--   2. A handheld radio in inventory
---------------------------------------------------------------

require "PhobosLib"
require "POS_TerminalWidgets"

POS_ContextMenu = {}

--- Callback for "Connect to POSnet" menu action (world radio).
--- @param worldObjects table Array of world objects
--- @param radioObj any The radio IsoWaveSignal
--- @param player any IsoPlayer
local function onConnectWorld(worldObjects, radioObj, player)
    POS_ConnectionManager.connect(player, radioObj)
end

--- Callback for "Connect to POSnet" menu action (inventory radio).
--- @param items table
--- @param radioItem any InventoryItem
--- @param player any IsoPlayer
local function onConnectInventory(items, radioItem, player)
    POS_ConnectionManager.connect(player, radioItem)
end

--- Add POSnet context menu option for world-placed radios.
--- @param playerNum number Player index
--- @param context any ISContextMenu
--- @param worldObjects table
--- @param test boolean
local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    for _, obj in ipairs(worldObjects) do
        -- Unwrap table of objects on a square
        local objects = obj
        if not instanceof(obj, "IsoObject") then
            if type(obj) == "table" then
                objects = obj
            else
                objects = { obj }
            end
        else
            objects = { obj }
        end

        for _, worldObj in ipairs(objects) do
            if POS_ConnectionManager.isWorldRadio(worldObj) then
                local canDo, reason, extra = POS_ConnectionManager.canConnect(player, worldObj)
                local label = POS_TerminalWidgets.safeGetText("UI_POS_ContextMenuConnect")

                if canDo then
                    context:addOption(label, worldObjects, onConnectWorld, worldObj, player)
                else
                    local option = context:addOption(label, worldObjects, nil)
                    option.notAvailable = true
                    local tooltip = ISWorldObjectContextMenu.addToolTip()
                    if reason == "UI_POS_FrequencyMismatch" and extra then
                        tooltip.description = POS_TerminalWidgets.safeGetText(reason,
                            extra.opsFreqMHz or "?", extra.tacFreqMHz or "?")
                    elseif reason == "UI_POS_SignalTooWeak" and extra then
                        tooltip.description = POS_TerminalWidgets.safeGetText(reason)
                            .. " (" .. (extra.signalPct or "0") .. "%)"
                    else
                        tooltip.description = POS_TerminalWidgets.safeGetText(reason or "UI_POS_RadioOff")
                    end
                    option.toolTip = tooltip
                end
                return
            end

            -- Desktop computer: show POSnet frequency info
            if POS_ConnectionManager.isDesktopComputer
               and POS_ConnectionManager.isDesktopComputer(worldObj) then
                local opsFreq = POS_AZASIntegration
                    and POS_AZASIntegration.getOperationsFrequency() or 130000
                local tacFreq = POS_AZASIntegration
                    and POS_AZASIntegration.getTacticalFrequency() or 155000
                local freqLabel = POS_TerminalWidgets.safeGetText("UI_POS_ComputerFrequencyInfo",
                    string.format("%.1f", opsFreq / 1000),
                    string.format("%.1f", tacFreq / 1000))
                local option = context:addOption(freqLabel, worldObjects, nil)
                option.notAvailable = true
            end
        end
    end
end

--- Add POSnet context menu option for inventory radios.
--- @param playerNum number Player index
--- @param context any ISContextMenu
--- @param items table Selected inventory items
local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    for _, item in ipairs(items) do
        -- Unwrap InventoryItem from table wrapper
        local invItem = item
        if type(item) == "table" then
            invItem = item.items and item.items[1]
        end

        if invItem and POS_ConnectionManager.isInventoryRadio(invItem) then
            local canDo, reason, extra = POS_ConnectionManager.canConnect(player, invItem)
            local label = POS_TerminalWidgets.safeGetText("UI_POS_ContextMenuConnect")

            if canDo then
                context:addOption(label, items, onConnectInventory, invItem, player)
            else
                local option = context:addOption(label, items, nil)
                option.notAvailable = true
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                if reason == "UI_POS_FrequencyMismatch" and extra then
                    tooltip.description = POS_TerminalWidgets.safeGetText(reason,
                        extra.opsFreqMHz or "?", extra.tacFreqMHz or "?")
                elseif reason == "UI_POS_SignalTooWeak" and extra then
                    tooltip.description = POS_TerminalWidgets.safeGetText(reason)
                        .. " (" .. (extra.signalPct or "0") .. "%)"
                else
                    tooltip.description = POS_TerminalWidgets.safeGetText(reason or "UI_POS_RadioOff")
                end
                option.toolTip = tooltip
            end
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
Events.OnPreFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
