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
-- POS_ReconDeviceRegistry.lua
-- Device type definitions with unique qualities per device.
-- Extensible registry pattern.
---------------------------------------------------------------

require "POS_Constants"

POS_ReconDeviceRegistry = {}

local devices = {}

--- Register a passive recon device type.
--- @param def table { id, itemType, scanRadius, intelQuality, confidenceMod,
---   requiresTape, requiresEquipped, equipSlot, carryBonus, noiseLevelPct,
---   scanType, labelKey }
function POS_ReconDeviceRegistry.register(def)
    if not def or not def.id then return end
    devices[def.id] = {
        id = def.id,
        itemType = def.itemType,
        scanRadius = def.scanRadius or 0,
        intelQuality = def.intelQuality or "low",       -- "high", "medium", "low", "very_low"
        confidenceMod = def.confidenceMod or 0,          -- BPS modifier
        requiresTape = def.requiresTape or false,
        requiresEquipped = def.requiresEquipped or false,
        equipSlot = def.equipSlot or nil,                -- "secondary" or "belt"
        carryBonus = def.carryBonus or 0,                -- BPS confidence bonus when in inventory
        noiseLevelPct = def.noiseLevelPct or 0,          -- noise increase while active
        scanType = def.scanType or "building",           -- "building", "environment", "signal"
        labelKey = def.labelKey or "",
        internalCapacity = def.internalCapacity or 0,    -- entries stored without tape (0 = tape required)
    }
end

function POS_ReconDeviceRegistry.get(deviceId)
    return devices[deviceId]
end

function POS_ReconDeviceRegistry.getAll()
    local result = {}
    for _, dev in pairs(devices) do
        result[#result + 1] = dev
    end
    return result
end

function POS_ReconDeviceRegistry.getByItemType(fullType)
    for _, dev in pairs(devices) do
        if dev.itemType == fullType then return dev end
    end
    return nil
end

-- Register built-in devices

POS_ReconDeviceRegistry.register({
    id = "camcorder",
    itemType = POS_Constants.ITEM_RECON_CAMCORDER,
    scanRadius = POS_Constants.RECON_CAMCORDER_SCAN_RADIUS,
    intelQuality = "high",
    confidenceMod = 0,
    requiresTape = true,
    requiresEquipped = true,
    equipSlot = "secondary",
    carryBonus = POS_Constants.CAMCORDER_CARRY_CONFIDENCE_BONUS,
    noiseLevelPct = POS_Constants.CAMCORDER_NOISE_LEVEL_DEFAULT,
    scanType = "building",
    labelKey = "UI_POS_Device_Camcorder",
    internalCapacity = 0,
})

POS_ReconDeviceRegistry.register({
    id = "logger",
    itemType = POS_Constants.ITEM_FIELD_SURVEY_LOGGER,
    scanRadius = POS_Constants.RECON_LOGGER_SCAN_RADIUS,
    intelQuality = "medium",
    confidenceMod = 0,
    requiresTape = false,
    requiresEquipped = true,
    equipSlot = "belt",
    carryBonus = POS_Constants.LOGGER_CARRY_CONFIDENCE_BONUS,
    noiseLevelPct = 0,
    scanType = "environment",
    labelKey = "UI_POS_Device_Logger",
    internalCapacity = POS_Constants.RECON_LOGGER_INTERNAL_CAP,
})

POS_ReconDeviceRegistry.register({
    id = "calculator",
    itemType = POS_Constants.ITEM_DATA_CALCULATOR,
    scanRadius = 0,
    intelQuality = "compiler",
    confidenceMod = 0,
    requiresTape = false,
    requiresEquipped = false,
    equipSlot = nil,
    carryBonus = POS_Constants.CALCULATOR_CARRY_CONFIDENCE_BONUS,
    noiseLevelPct = 0,
    scanType = "none",
    labelKey = "UI_POS_Device_Calculator",
    internalCapacity = 0,
})
