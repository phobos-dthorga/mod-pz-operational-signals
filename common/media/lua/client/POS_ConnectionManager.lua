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
-- POS_ConnectionManager.lua
-- Physical setup validation for POSnet connections.
--
-- Validates that the player has the required equipment:
--   1. A radio (world object or inventory item)
--   2. A computer (desktop nearby OR portable computer in inventory)
--
-- Desktop Computer: Base.Mov_DesktopComputer
--   Sprites: appliances_com_01_72 through appliances_com_01_75
--
-- Portable Computer: PhobosOperationalSignals.PortableComputer
--   Replaces desktop requirement when carried in inventory.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_ConnectionManager = {}

--- Desktop computer sprite names (base + 3 rotations).
local DESKTOP_SPRITES = {
    ["appliances_com_01_72"] = true,
    ["appliances_com_01_73"] = true,
    ["appliances_com_01_74"] = true,
    ["appliances_com_01_75"] = true,
}

--- Search radius for nearby desktop computers (tiles).
local DESKTOP_SEARCH_RADIUS = 3

--- Full item type for the POSnet portable computer.
local PORTABLE_COMPUTER_TYPE = POS_Constants.ITEM_PORTABLE_COMPUTER

--- Check if an IsoObject has a desktop computer sprite.
--- @param obj any IsoObject
--- @return boolean
local function isDesktopComputer(obj)
    if not obj then return false end
    local ok, spriteName = pcall(function()
        local sprite = obj:getSprite()
        if sprite and sprite.getName then
            return sprite:getName()
        end
        return nil
    end)
    if not ok or not spriteName then return false end
    return DESKTOP_SPRITES[spriteName] == true
end

--- Check if a desktop computer is within range of the given square.
--- @param playerSquare any IsoGridSquare
--- @return boolean
function POS_ConnectionManager.isDesktopNearby(playerSquare)
    if not playerSquare then return false end
    return PhobosLib.scanNearbySquares(playerSquare, DESKTOP_SEARCH_RADIUS, function(sq)
        local objs = sq:getObjects()
        if not objs then return false end
        for i = 0, objs:size() - 1 do
            if isDesktopComputer(objs:get(i)) then
                return true
            end
        end
        return false
    end)
end

--- Check if an inventory item is a POSnet portable computer.
--- @param item any InventoryItem
--- @return boolean
function POS_ConnectionManager.isPortableComputer(item)
    if not item then return false end
    if not item.getFullType then return false end
    return item:getFullType() == PORTABLE_COMPUTER_TYPE
end

--- Check if the player has a portable computer in their inventory.
--- @param player any IsoPlayer
--- @return boolean
function POS_ConnectionManager.hasPortableComputer(player)
    if not player then return false end
    local inv = player:getInventory()
    if not inv then return false end
    return inv:containsTypeEval(PORTABLE_COMPUTER_TYPE)
end

--- Find the player's portable computer item (for battery drain tracking).
--- @param player any IsoPlayer
--- @return any|nil InventoryItem
function POS_ConnectionManager.findPortableComputer(player)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end
    return inv:getFirstTypeEval(PORTABLE_COMPUTER_TYPE)
end

--- Check if a world object is a radio (IsoWaveSignal).
--- @param obj any World object
--- @return boolean
function POS_ConnectionManager.isWorldRadio(obj)
    if not obj then return false end
    return instanceof(obj, "IsoWaveSignal")
end

--- Check if an inventory item is a radio device.
--- @param item any InventoryItem
--- @return boolean
function POS_ConnectionManager.isInventoryRadio(item)
    if not item then return false end
    if not item.getDeviceData then return false end
    local ok, result = pcall(function()
        return item:getDeviceData() ~= nil
    end)
    return ok and result == true
end

--- Get DeviceData from a radio (world object or inventory item).
--- @param radioObj any IsoWaveSignal or InventoryItem
--- @return any|nil DeviceData
function POS_ConnectionManager.getDeviceData(radioObj)
    if not radioObj then return nil end
    if not radioObj.getDeviceData then return nil end
    local ok, dd = pcall(function()
        return radioObj:getDeviceData()
    end)
    if ok and dd then return dd end
    return nil
end

--- Check if an IsoObject is a desktop computer (public wrapper).
--- @param obj any IsoObject
--- @return boolean
function POS_ConnectionManager.isDesktopComputer(obj)
    return isDesktopComputer(obj)
end

--- Validate all requirements for a POSnet connection.
--- @param player any IsoPlayer
--- @param radioObj any Radio world object or inventory item
--- @return boolean success
--- @return string|nil reasonKey Translation key for failure reason
--- @return table|nil extraData Additional data for tooltip formatting
--- @return string|nil band "operations" or "tactical" (if frequency matched)
function POS_ConnectionManager.canConnect(player, radioObj)
    if not player or not radioObj then
        return false, nil
    end

    -- Check device data exists
    local dd = POS_ConnectionManager.getDeviceData(radioObj)
    if not dd then
        return false, "UI_POS_RadioOff"
    end

    -- Check radio is turned on
    local ok, isOn = pcall(function() return dd:getIsTurnedOn() end)
    if not ok or not isOn then
        return false, "UI_POS_RadioOff"
    end

    -- Check power (battery or electricity)
    local hasPower = false
    pcall(function()
        if dd:getIsBatteryPowered() then
            local power = dd:getPower()
            if power and power > 0 then
                hasPower = true
            end
        end
    end)
    if not hasPower then
        pcall(function()
            local parent = dd:getParent()
            if parent then
                local sq = parent:getSquare()
                if sq and sq:haveElectricity() then
                    hasPower = true
                end
            end
        end)
    end
    if not hasPower then
        return false, "UI_POS_NoPower"
    end

    -- Check frequency matches a POSnet band
    -- PZ B42 DeviceData uses getChannel() not getFrequency()
    local tunedFreq = nil
    pcall(function()
        if dd.getChannel then
            tunedFreq = dd:getChannel()
        elseif dd.getFrequency then
            tunedFreq = dd:getFrequency()
        end
    end)
    local band = POS_AZASIntegration and POS_AZASIntegration.matchFrequency
        and POS_AZASIntegration.matchFrequency(tunedFreq)
    if not band then
        local opsFreq = POS_AZASIntegration and POS_AZASIntegration.getOperationsFrequency
            and POS_AZASIntegration.getOperationsFrequency() or 130000
        local tacFreq = POS_AZASIntegration and POS_AZASIntegration.getTacticalFrequency
            and POS_AZASIntegration.getTacticalFrequency() or 155000
        return false, "UI_POS_FrequencyMismatch", {
            opsFreqMHz = string.format("%.1f", opsFreq / 1000),
            tacFreqMHz = string.format("%.1f", tacFreq / 1000),
        }
    end

    -- Check signal strength (if enabled)
    if POS_Sandbox.isSignalStrengthEnabled() then
        local power = POS_RadioPower.getPower(radioObj)
        local signal = POS_RadioPower.calculateSignalStrength(power)
        if not POS_RadioPower.meetsThreshold(signal) then
            local pct = string.format("%.0f", signal * 100)
            return false, "UI_POS_SignalTooWeak", { signalPct = pct }
        end
    end

    -- Check for computer access (desktop nearby OR portable in inventory)
    local playerSquare = PhobosLib.getSquareFromPlayer(player)
    local hasDesktop = POS_ConnectionManager.isDesktopNearby(playerSquare)
    if not hasDesktop then
        if not POS_ConnectionManager.hasPortableComputer(player) then
            return false, "UI_POS_NoComputer"
        end
    end

    -- Desktop computer requires electricity at its location
    if hasDesktop and playerSquare and not playerSquare:haveElectricity() then
        return false, POS_Constants.ERR_NO_POWER
    end

    return true, nil, nil, band
end

--- Open the POSnet terminal UI.
--- @param player any IsoPlayer
--- @param radioObj any Radio object
function POS_ConnectionManager.connect(player, radioObj)
    local canDo, reason, _extra, band = POS_ConnectionManager.canConnect(player, radioObj)
    if not canDo then
        PhobosLib.debug("POS", "Connection failed: " .. (reason or "unknown"))
        return
    end

    -- Get radio name for display
    local radioName = "Radio"
    pcall(function()
        local dd = radioObj:getDeviceData()
        if dd then
            local parent = dd:getParent()
            if parent and parent.getObjectName then
                radioName = parent:getObjectName() or radioName
            end
        end
    end)
    pcall(function()
        if radioObj.getName then
            local n = radioObj:getName()
            if n and n ~= "" then radioName = n end
        end
    end)

    -- Calculate signal strength
    local power = POS_RadioPower.getPower(radioObj)
    local signalStrength = POS_RadioPower.calculateSignalStrength(power)

    -- Determine if using portable computer (for battery drain)
    local portablePC = nil
    local playerSquare = PhobosLib.getSquareFromPlayer(player)
    if not POS_ConnectionManager.isDesktopNearby(playerSquare) then
        portablePC = POS_ConnectionManager.findPortableComputer(player)
    end

    -- Get the frequency for the connected band
    local freq
    if band == "tactical" then
        freq = POS_AZASIntegration.getTacticalFrequency()
    else
        freq = POS_AZASIntegration.getOperationsFrequency()
    end

    POS_TerminalUI.open(radioName, freq, portablePC, signalStrength, band)

    PhobosLib.debug("POS", "Connected to POSnet via " .. radioName
        .. " [" .. (band or "?") .. "] (signal: "
        .. string.format("%.0f%%", signalStrength * 100) .. ")")
end
