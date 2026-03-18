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
-- POS_PassiveRecon.lua
-- The passive recon scanning engine.
-- Hooks into EveryOneMinute for performance.
---------------------------------------------------------------

require "POS_Constants"
require "POS_ReconDeviceRegistry"
require "POS_TapeManager"

POS_PassiveRecon = {}

local lastScanMinute = -1

--- Check if a device is actively scanning (equipped + powered + tape if required).
local function isDeviceActive(player, deviceDef)
    if not deviceDef.requiresEquipped then return false end

    -- Check if item is equipped
    local inv = player:getInventory()
    if not inv then return false end

    local items = inv:getItemsFromFullType(deviceDef.itemType)
    if not items or items:size() == 0 then return false end

    local device = items:get(0)
    if not device then return false end

    -- Check battery
    if device:getCondition() <= 0 then return false end

    -- Check tape requirement
    if deviceDef.requiresTape then
        local tape = POS_TapeManager.findUsableTape(player)
        if not tape then return false end
    end

    return true, device
end

--- Perform one passive scan cycle for a device.
local function performScan(player, deviceDef, device)
    local px = player:getX()
    local py = player:getY()

    -- Get scan radius (sandbox override or device default)
    local radius = deviceDef.scanRadius
    if deviceDef.id == "camcorder" and POS_Sandbox and POS_Sandbox.getCamcorderScanRadius then
        radius = POS_Sandbox.getCamcorderScanRadius()
    elseif deviceDef.id == "logger" and POS_Sandbox and POS_Sandbox.getLoggerScanRadius then
        radius = POS_Sandbox.getLoggerScanRadius()
    end

    if radius <= 0 then return end

    -- Find nearby buildings
    local buildings = nil
    if PhobosLib and PhobosLib.findNearbyBuildings then
        buildings = PhobosLib.findNearbyBuildings(px, py, radius,
            POS_BuildingCache and POS_BuildingCache.RECON_ROOMS or nil)
    end

    if not buildings or #buildings == 0 then return end

    -- Find active tape
    local tape = nil
    if deviceDef.requiresTape then
        tape = POS_TapeManager.findUsableTape(player)
        if not tape then return end
    end

    -- Use internal storage for devices that don't require tape
    local useInternal = not deviceDef.requiresTape and deviceDef.internalCapacity > 0

    local day = POS_WorldState and POS_WorldState.getWorldDay() or 0
    local recorded = 0

    for _, bldg in ipairs(buildings) do
        -- Check tape/internal capacity
        if tape and POS_TapeManager.isFull(tape) then break end

        -- Get room category for market intelligence
        local roomType = (bldg.rooms and bldg.rooms[1]) or "unknown"
        local category = POS_RoomCategoryMap and POS_RoomCategoryMap.getCategory(roomType) or nil

        local entry = {
            roomType = roomType,
            category = category,
            x = bldg.x,
            y = bldg.y,
            day = day,
            confidence = 50,  -- base confidence, modified by tape quality + device
            scanType = deviceDef.scanType,
        }

        -- Apply device quality modifier
        if deviceDef.intelQuality == "high" then
            entry.confidence = 80
        elseif deviceDef.intelQuality == "medium" then
            entry.confidence = 60
        elseif deviceDef.intelQuality == "low" then
            entry.confidence = 40
        end

        -- Record to tape or internal storage
        if tape then
            if POS_TapeManager.recordEntry(tape, entry) then
                recorded = recorded + 1
            end
        elseif useInternal then
            -- Store in device modData (limited internal capacity)
            local md = PhobosLib.getModData(device)
            if md then
                local count = tonumber(md[POS_Constants.MD_TAPE_ENTRY_COUNT]) or 0
                if count < deviceDef.internalCapacity then
                    md[POS_Constants.MD_TAPE_ENTRY_COUNT] = count + 1
                    local existing = md[POS_Constants.MD_TAPE_ENTRIES] or ""
                    local entryStr = tostring(entry.roomType) .. ":" .. tostring(entry.x)
                        .. ":" .. tostring(entry.y) .. ":" .. tostring(entry.day)
                        .. ":" .. tostring(entry.confidence)
                    md[POS_Constants.MD_TAPE_ENTRIES] = existing ~= "" and (existing .. "|" .. entryStr) or entryStr
                    recorded = recorded + 1
                end
            end
        end

        -- Also add to building cache (shared discovery)
        if POS_BuildingCache and POS_BuildingCache.addToCache then
            POS_BuildingCache.addToCache(bldg.x, bldg.y, bldg.rooms)
        end
    end

    -- Drain battery proportional to scan effort
    if device and recorded > 0 then
        local drain = math.max(1, math.floor(recorded / 2))
        local newCond = math.max(0, device:getCondition() - drain)
        device:setCondition(newCond)
    end

    if recorded > 0 then
        PhobosLib.debug("POS", "[PassiveRecon] " .. deviceDef.id .. " recorded " .. tostring(recorded) .. " entries")
    end
end

--- Main scan tick -- called every game minute.
function POS_PassiveRecon.onEveryOneMinute()
    -- Master toggle
    if POS_Sandbox and POS_Sandbox.getEnablePassiveRecon
            and not POS_Sandbox.getEnablePassiveRecon() then
        return
    end

    local player = getSpecificPlayer(0)
    if not player then return end

    -- Get all registered devices
    local allDevices = POS_ReconDeviceRegistry.getAll()

    for _, deviceDef in ipairs(allDevices) do
        if deviceDef.scanType ~= "none" then
            local active, device = isDeviceActive(player, deviceDef)
            if active and device then
                performScan(player, deviceDef, device)
            end
        end
    end
end

--- Get total carry confidence bonus from all recon devices in inventory.
function POS_PassiveRecon.getCarryConfidenceBonus(player)
    if not player then return 0 end
    local inv = player:getInventory()
    if not inv then return 0 end

    local totalBonus = 0
    local allDevices = POS_ReconDeviceRegistry.getAll()

    for _, deviceDef in ipairs(allDevices) do
        if deviceDef.carryBonus > 0 then
            local items = inv:getItemsFromFullType(deviceDef.itemType)
            if items and items:size() > 0 then
                totalBonus = totalBonus + deviceDef.carryBonus
            end
        end
    end

    return totalBonus
end

-- Hook into game events
Events.EveryOneMinute.Add(POS_PassiveRecon.onEveryOneMinute)
