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

---------------------------------------------------------------
-- Radio tier detection (dynamic — works with any radio item)
---------------------------------------------------------------

local TIER_CONFIDENCE = {
    [1] = POS_Constants.RADIO_CONFIDENCE_TIER1,
    [2] = POS_Constants.RADIO_CONFIDENCE_TIER2,
    [3] = POS_Constants.RADIO_CONFIDENCE_TIER3,
    [4] = POS_Constants.RADIO_CONFIDENCE_TIER4,
}

--- Determine the scanner tier of a radio item (1-4) or nil if not usable.
local function getRadioTier(item)
    if not item then return nil end
    local ok, dd = pcall(function()
        return item.getDeviceData and item:getDeviceData()
    end)
    if not ok or not dd then return nil end

    -- Must be turned on
    local isOn = false
    pcall(function() isOn = dd:getIsTurnedOn() end)
    if not isOn then return nil end

    -- Check power: battery OR grid
    local hasPower = false
    pcall(function()
        if dd.getIsBatteryPowered and dd:getIsBatteryPowered() then
            local power = dd.getPower and dd:getPower() or 0
            if power > 0 then hasPower = true end
        end
    end)
    if not hasPower then
        pcall(function()
            local parent = dd.getParent and dd:getParent()
            if parent then
                local sq = parent:getSquare and parent:getSquare()
                if sq and sq:haveElectricity() then hasPower = true end
            end
        end)
    end
    if not hasPower then return nil end

    -- Get transmit range for tier classification
    local range = 0
    pcall(function() range = dd.getTransmitRange and dd:getTransmitRange() or 0 end)

    if range == 0 then return 1 end  -- Receive-only FM
    if range <= POS_Constants.RADIO_TIER_THRESHOLD_BASIC then return 2 end
    if range <= POS_Constants.RADIO_TIER_THRESHOLD_ADVANCED then return 3 end
    return 4  -- Military/high-end
end

--- Calculate the scan radius for a radio based on its TransmitRange.
local function getRadioScanRadius(radioItem)
    local range = 0
    pcall(function()
        local dd = radioItem:getDeviceData()
        range = dd:getTransmitRange() or 0
    end)
    local radius = math.floor(range / POS_Constants.RADIO_RANGE_DIVISOR)
    return math.max(1, math.min(radius, POS_Constants.RADIO_MAX_SCAN_RADIUS))
end

--- Perform a passive radio scan for nearby buildings.
--- Tier 1 (FM receivers) receive broadcasts only — no active building scan.
local function performRadioScan(player, radioItem, tier)
    if tier == 1 then
        -- Tier 1 (FM receivers): broadcast listening only, no active scan
        -- They receive market broadcasts but don't scan buildings
        return
    end

    local px = player:getX()
    local py = player:getY()
    local radius = getRadioScanRadius(radioItem)

    -- Find nearby buildings (same as device scan)
    local buildings = nil
    if PhobosLib and PhobosLib.findNearbyBuildings then
        buildings = PhobosLib.findNearbyBuildings(px, py, radius,
            POS_BuildingCache and POS_BuildingCache.RECON_ROOMS or nil)
    end
    if not buildings or #buildings == 0 then return end

    -- Find tape for recording (optional — radio can work without tape)
    local tape = POS_TapeManager and POS_TapeManager.findUsableTape(player) or nil
    local day = POS_WorldState and POS_WorldState.getWorldDay() or 0
    local confidenceMod = TIER_CONFIDENCE[tier] or POS_Constants.RADIO_CONFIDENCE_TIER2
    local recorded = 0

    for _, bldg in ipairs(buildings) do
        if tape and POS_TapeManager.isFull(tape) then break end

        local roomType = (bldg.rooms and bldg.rooms[1]) or "unknown"
        local category = POS_RoomCategoryMap and POS_RoomCategoryMap.getCategory(roomType) or nil

        local baseConfidence = 50
        -- Apply tier confidence modifier (BPS -> percentage adjustment)
        baseConfidence = math.max(10, baseConfidence + math.floor(confidenceMod / 100))

        local entry = {
            roomType = roomType,
            category = category,
            x = bldg.x,
            y = bldg.y,
            day = day,
            confidence = baseConfidence,
            scanType = "signal",
        }

        -- Record to tape if available
        if tape and POS_TapeManager and POS_TapeManager.recordEntry then
            if POS_TapeManager.recordEntry(tape, entry) then
                recorded = recorded + 1
            end
        end

        -- Also add to building cache
        if POS_BuildingCache and POS_BuildingCache.addToCache then
            POS_BuildingCache.addToCache(bldg.x, bldg.y, bldg.rooms)
        end
    end

    if recorded > 0 then
        PhobosLib.debug("POS", "[PassiveRecon] Radio tier " .. tostring(tier)
            .. " recorded " .. tostring(recorded) .. " entries")
    end
end

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

    -- Dynamic radio scanner check (any powered-on radio in inventory)
    local inv = player:getInventory()
    if inv then
        local allItems = inv:getItems()
        if allItems then
            for i = 0, allItems:size() - 1 do
                local item = allItems:get(i)
                local tier = getRadioTier(item)
                if tier then
                    performRadioScan(player, item, tier)
                    break  -- Only scan with the best radio found (stagger)
                end
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
