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
local PORTABLE_COMPUTER_TYPE = "PhobosOperationalSignals.PortableComputer"

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

--- Validate all requirements for a POSnet connection.
--- @param player any IsoPlayer
--- @param radioObj any Radio world object or inventory item
--- @return boolean success
--- @return string|nil reasonKey Translation key for failure reason
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

    -- Check for computer access (desktop nearby OR portable in inventory)
    local playerSquare = PhobosLib.getSquareFromPlayer(player)
    if not POS_ConnectionManager.isDesktopNearby(playerSquare) then
        if not POS_ConnectionManager.hasPortableComputer(player) then
            return false, "UI_POS_NoComputer"
        end
    end

    return true, nil
end

--- Open the POSnet terminal UI.
--- @param player any IsoPlayer
--- @param radioObj any Radio object
function POS_ConnectionManager.connect(player, radioObj)
    local canDo, reason = POS_ConnectionManager.canConnect(player, radioObj)
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

    -- Determine if using portable computer (for battery drain)
    local portablePC = nil
    local playerSquare = PhobosLib.getSquareFromPlayer(player)
    if not POS_ConnectionManager.isDesktopNearby(playerSquare) then
        portablePC = POS_ConnectionManager.findPortableComputer(player)
    end

    local freq = POS_Sandbox.getPOSnetFrequency()
    POS_TerminalUI.open(radioName, freq, portablePC)

    PhobosLib.debug("POS", "Connected to POSnet via " .. radioName)
end
