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
--
-- BREAKING CHANGE: All passive scan data now routes through an
-- equipped Data-Recorder. No recorder = no passive scanning.
-- Direct tape writes and internal device buffers are removed.
-- Sensor devices register as data sources via POS_DataSourceRegistry.
---------------------------------------------------------------

require "POS_Constants"
require "POS_ReconDeviceRegistry"
require "POS_DataSourceRegistry"
require "POS_DataRecorderService"
require "POS_MediaManager"

POS_PassiveRecon = {}

local _TAG = "[POS:PassRecon]"

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
    local ok, dd = PhobosLib.safecall(function()
        return item.getDeviceData and item:getDeviceData()
    end)
    if not ok or not dd then return nil end

    -- Must be turned on
    local isOn = false
    PhobosLib.safecall(function() isOn = dd:getIsTurnedOn() end)
    if not isOn then return nil end

    -- Check power: battery OR grid
    local hasPower = false
    PhobosLib.safecall(function()
        if dd.getIsBatteryPowered and dd:getIsBatteryPowered() then
            local power = dd.getPower and dd:getPower() or 0
            if power > 0 then hasPower = true end
        end
    end)
    if not hasPower then
        PhobosLib.safecall(function()
            local parent = dd.getParent and dd:getParent()
            if parent then
                local sq = parent.getSquare and parent:getSquare()
                if sq and PhobosLib.hasPower(sq) then hasPower = true end
            end
        end)
    end
    if not hasPower then return nil end

    -- Get transmit range for tier classification
    local range = 0
    PhobosLib.safecall(function() range = dd.getTransmitRange and dd:getTransmitRange() or 0 end)

    if range == 0 then return 1 end  -- Receive-only FM
    if range <= POS_Constants.RADIO_TIER_THRESHOLD_BASIC then return 2 end
    if range <= POS_Constants.RADIO_TIER_THRESHOLD_ADVANCED then return 3 end
    return 4  -- Military/high-end
end

--- Calculate the scan radius for a radio based on its TransmitRange.
local function getRadioScanRadius(radioItem)
    local range = 0
    PhobosLib.safecall(function()
        local dd = radioItem:getDeviceData()
        range = dd:getTransmitRange() or 0
    end)
    local radius = math.floor(range / POS_Constants.RADIO_RANGE_DIVISOR)
    return math.max(1, math.min(radius, POS_Constants.RADIO_MAX_SCAN_RADIUS))
end

---------------------------------------------------------------
-- Data source: generate chunks from sensor devices
---------------------------------------------------------------

--- Generate a building scan chunk from a device scan.
local function generateBuildingScanChunk(player, deviceDef, bldg, day, confidenceBps)
    local roomType = (bldg.rooms and bldg.rooms[1]) or "unknown"
    local category = POS_RoomCategoryMap and POS_RoomCategoryMap.getCategory(roomType) or nil
    return {
        type       = POS_Constants.CHUNK_TYPE_BUILDING_SCAN,
        entityId   = roomType,
        category   = category,
        x          = bldg.x,
        y          = bldg.y,
        region     = bldg.region or "",
        day        = day,
        confidence = confidenceBps,
        mediaMod   = 0,  -- set by recorder at write time
        carryMod   = 0,
        signalMod  = 0,
        scanType   = deviceDef and deviceDef.scanType or "building",
    }
end

--- Generate a radio intercept chunk.
--- Signal Ecology composite is wired into signalMod so that weather, power,
--- market volatility, and SIGINT tier all affect intercept quality at capture
--- time. Building scans are excluded (visual devices, not RF-based).
local function generateRadioInterceptChunk(player, radioItem, tier, bldg, day)
    local roomType = (bldg.rooms and bldg.rooms[1]) or "unknown"
    local tierConf = TIER_CONFIDENCE[tier] or POS_Constants.RADIO_CONFIDENCE_TIER2
    local baseBps = POS_Constants.CONFIDENCE_BASE_EFFECTIVE * POS_Constants.CONFIDENCE_BPS_DIVISOR

    -- Signal Ecology bonus: maps composite (0-1) deviation from 0.5 midpoint
    -- to a BPS bonus/penalty. At 0.5 (faded): +0. At 0.85 (locked): +1400.
    -- At 0.1 (ghosted): -1600. Scale defined by SIGNAL_ECOLOGY_BPS_SCALE.
    local ecologyBonus = 0
    local signalState = nil
    if POS_SignalEcologyService and POS_SignalEcologyService.getComposite then
        local ok, composite = PhobosLib.safecall(POS_SignalEcologyService.getComposite)
        if ok and type(composite) == "number" then
            ecologyBonus = math.floor(
                (composite - 0.5) * POS_Constants.SIGNAL_ECOLOGY_BPS_SCALE)
        end
        local okS, state = PhobosLib.safecall(POS_SignalEcologyService.getQualitativeState)
        if okS and state then signalState = state end
    end

    return {
        type        = POS_Constants.CHUNK_TYPE_RADIO_INTERCEPT,
        entityId    = roomType,
        category    = POS_RoomCategoryMap and POS_RoomCategoryMap.getCategory(roomType) or nil,
        x           = bldg.x,
        y           = bldg.y,
        region      = bldg.region or "",
        day         = day,
        confidence  = baseBps + tierConf + ecologyBonus,
        mediaMod    = 0,
        carryMod    = 0,
        signalMod   = tierConf + ecologyBonus,
        signalState = signalState,
        scanType    = "signal",
    }
end

---------------------------------------------------------------
-- Scanning logic (recorder-mandatory)
---------------------------------------------------------------

--- Perform a passive device scan cycle, routing all output through the recorder.
local function performDeviceScan(player, deviceDef, device, recorder)
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

    local day = POS_WorldState and POS_WorldState.getWorldDay() or 0
    local recorded = 0

    -- Calculate device confidence in BPS
    local deviceConfBps = POS_Constants.DEVICE_CONFIDENCE_CAMCORDER
    if deviceDef.id == "logger" then
        deviceConfBps = POS_Constants.DEVICE_CONFIDENCE_LOGGER
    end

    for _, bldg in ipairs(buildings) do
        local chunk = generateBuildingScanChunk(player, deviceDef, bldg, day, deviceConfBps)

        -- Add carry bonus from inventory devices
        chunk.carryMod = POS_PassiveRecon.getCarryConfidenceBonus(player)

        -- Route through recorder
        if POS_DataRecorderService.appendChunk(recorder, chunk) then
            recorded = recorded + 1
        else
            break  -- storage full
        end

        -- Also add to building cache (shared discovery)
        if POS_BuildingCache and POS_BuildingCache.addToCache then
            POS_BuildingCache.addToCache(bldg.x, bldg.y, bldg.rooms)
        end
    end

    -- Drain device battery proportional to scan effort
    if device and recorded > 0 then
        local drain = math.max(1, math.floor(recorded / 2))
        local newCond = math.max(0, device:getCondition() - drain)
        device:setCondition(newCond)
    end

    if recorded > 0 then
        PhobosLib.debug("POS", _TAG, deviceDef.id .. " recorded " .. tostring(recorded) .. " chunks via recorder")
    end
end

--- Perform a passive radio scan, routing output through the recorder.
local function performRadioScan(player, radioItem, tier, recorder)
    if tier == 1 then return end  -- Tier 1 (FM receivers): broadcast only, no scan

    local px = player:getX()
    local py = player:getY()
    local radius = getRadioScanRadius(radioItem)

    local buildings = nil
    if PhobosLib and PhobosLib.findNearbyBuildings then
        buildings = PhobosLib.findNearbyBuildings(px, py, radius,
            POS_BuildingCache and POS_BuildingCache.RECON_ROOMS or nil)
    end
    if not buildings or #buildings == 0 then return end

    local day = POS_WorldState and POS_WorldState.getWorldDay() or 0
    local recorded = 0

    for _, bldg in ipairs(buildings) do
        local chunk = generateRadioInterceptChunk(player, radioItem, tier, bldg, day)
        chunk.carryMod = POS_PassiveRecon.getCarryConfidenceBonus(player)

        if POS_DataRecorderService.appendChunk(recorder, chunk) then
            recorded = recorded + 1
        else
            break  -- storage full
        end

        if POS_BuildingCache and POS_BuildingCache.addToCache then
            POS_BuildingCache.addToCache(bldg.x, bldg.y, bldg.rooms)
        end
    end

    if recorded > 0 then
        PhobosLib.debug("POS", _TAG, "radio tier " .. tostring(tier) .. " recorded " .. tostring(recorded) .. " chunks via recorder")
    end
end

--- Check if a device is actively scanning (equipped + powered).
local function isDeviceActive(player, deviceDef)
    if not deviceDef.requiresEquipped then return false end

    local inv = player:getInventory()
    if not inv then return false end

    local items = inv:getItemsFromFullType(deviceDef.itemType)
    if not items or items:size() == 0 then return false end

    local device = items:get(0)
    if not device then return false end

    -- Check battery
    if device:getCondition() <= 0 then return false end

    return true, device
end

---------------------------------------------------------------
-- Main scan tick
---------------------------------------------------------------

--- Main scan tick -- called every game minute.
function POS_PassiveRecon.onEveryOneMinute()
    local player = getSpecificPlayer(0)
    if not player then return end

    -- BREAKING: Recorder is mandatory for ALL passive scanning
    local recorder = POS_DataRecorderService.findEquippedRecorder(player)
    if not recorder then return end
    if not POS_DataRecorderService.isPowered(recorder) then return end

    POS_DataRecorderService.ensureInitialized(recorder)

    -- Danger detection gate
    if PhobosLib and PhobosLib.isDangerNearby then
        local radius = POS_Constants.DANGER_CHECK_RADIUS
        if PhobosLib.isDangerNearby(player, radius) then
            PhobosLib.debug("POS", _TAG, "scanning paused — danger nearby")
            return
        end
    end

    -- Scan with registered devices (one per minute = stagger)
    local allDevices = POS_ReconDeviceRegistry.getAll()
    local scanned = false

    for _, deviceDef in ipairs(allDevices) do
        if not scanned and deviceDef.scanType ~= "none" and not deviceDef.dynamic then
            local active, device = isDeviceActive(player, deviceDef)
            if active and device then
                performDeviceScan(player, deviceDef, device, recorder)
                scanned = true  -- stagger: one device per tick
            end
        end
    end

    -- Dynamic radio scanner check (any powered-on radio in inventory)
    if not scanned then
        local inv = player:getInventory()
        if inv then
            local allItems = inv:getItems()
            if allItems then
                for i = 0, allItems:size() - 1 do
                    local item = allItems:get(i)
                    local tier = getRadioTier(item)
                    if tier then
                        performRadioScan(player, item, tier, recorder)
                        break  -- stagger: one radio per tick
                    end
                end
            end
        end
    end

    -- Living Market zone pressure sampling (Phase 7A)
    do
        local ok, POS_MarketSimulation = PhobosLib.safecall(require, "POS_MarketSimulation")
        if ok and POS_MarketSimulation and POS_MarketSimulation.getZonePressure then
            -- Get player SIGINT level for noise scaling
            local sigintLevel = 0
            local okSig, POS_SIGINTSkill = PhobosLib.safecall(require, "POS_SIGINTSkill")
            if okSig and POS_SIGINTSkill and POS_SIGINTSkill.getLevel then
                sigintLevel = POS_SIGINTSkill.getLevel(player) or 0
            end
            local noise = PhobosLib.lerp(
                POS_Constants.RECON_PRESSURE_NOISE_MAX,
                POS_Constants.RECON_PRESSURE_NOISE_MIN,
                sigintLevel / 10)

            local day = POS_WorldState and POS_WorldState.getWorldDay() or 0
            local pressureRecorded = 0

            for _, zoneId in ipairs(POS_Constants.MARKET_ZONES) do
                for _, catId in ipairs(POS_Constants.MARKET_CATEGORIES) do
                    local pressure = POS_MarketSimulation.getZonePressure(zoneId, catId)
                    if pressure and pressure ~= 0 then
                        local noisyPressure = pressure + PhobosLib.randFloat(-noise, noise)
                        local chunk = {
                            type       = POS_Constants.CHUNK_TYPE_MARKET_OBSERVATION,
                            entityId   = catId,
                            category   = catId,
                            x          = player:getX(),
                            y          = player:getY(),
                            region     = zoneId,
                            day        = day,
                            confidence = POS_Constants.CONFIDENCE_BASE_EFFECTIVE
                                * POS_Constants.CONFIDENCE_BPS_DIVISOR,
                            mediaMod   = 0,
                            carryMod   = 0,
                            signalMod  = 0,
                            scanType   = "market_pressure",
                            pressure   = noisyPressure,
                        }
                        chunk.carryMod = POS_PassiveRecon.getCarryConfidenceBonus(player)

                        if POS_DataRecorderService.appendChunk(recorder, chunk) then
                            pressureRecorded = pressureRecorded + 1
                        else
                            break  -- storage full
                        end
                    end
                end
            end

            if pressureRecorded > 0 then
                PhobosLib.debug("POS", _TAG,
                    "zone pressure recorded " .. tostring(pressureRecorded)
                    .. " chunks (noise=" .. string.format("%.2f", noise) .. ")")
            end
        end
    end

    -- Drain recorder power (1 minute = 1/60 hour)
    POS_DataRecorderService.drainPower(recorder, 1 / 60)
end

--- Get total carry confidence bonus from all recon devices in inventory.
function POS_PassiveRecon.getCarryConfidenceBonus(player)
    if not player then return 0 end
    local inv = player:getInventory()
    if not inv then return 0 end

    local totalBonus = 0
    local allDevices = POS_ReconDeviceRegistry.getAll()

    for _, deviceDef in ipairs(allDevices) do
        if deviceDef.carryBonus > 0 and deviceDef.itemType then
            local items = inv:getItemsFromFullType(deviceDef.itemType)
            if items and items:size() > 0 then
                totalBonus = totalBonus + deviceDef.carryBonus
            end
        end
    end

    return totalBonus
end

---------------------------------------------------------------
-- Satellite scanning (called from POS_Screen_SatelliteScan)
---------------------------------------------------------------

--- Generate a satellite intercept chunk with Signal Ecology integration.
--- Higher quality than handheld radio (satellite-grade base confidence).
--- Zone and category are randomised (satellite covers wide area).
---@param player userdata  The player character
---@param day number       Current game day
---@return table chunk     The generated chunk table
function POS_PassiveRecon.generateSatelliteChunk(player, day)
    -- Pick random zone and category
    local zones = POS_Constants.MARKET_ZONES or {}
    local categories = {}
    local catMults = POS_Constants.CATEGORY_PRICE_MULTIPLIERS or {}
    for catId, _ in pairs(catMults) do
        categories[#categories + 1] = catId
    end

    local zoneId = #zones > 0 and zones[ZombRand(#zones) + 1] or "muldraugh"
    local categoryId = #categories > 0 and categories[ZombRand(#categories) + 1] or "miscellaneous"

    -- Signal Ecology bonus (same pattern as radio intercepts)
    local ecologyBonus = 0
    local signalState = nil
    if POS_SignalEcologyService and POS_SignalEcologyService.getComposite then
        local ok, composite = PhobosLib.safecall(POS_SignalEcologyService.getComposite)
        if ok and type(composite) == "number" then
            ecologyBonus = math.floor(
                (composite - 0.5) * POS_Constants.SIGNAL_ECOLOGY_BPS_SCALE)
        end
        local okS, state = PhobosLib.safecall(POS_SignalEcologyService.getQualitativeState)
        if okS and state then signalState = state end
    end

    return {
        type        = POS_Constants.CHUNK_TYPE_SATELLITE_INTERCEPT,
        entityId    = zoneId,
        category    = categoryId,
        region      = zoneId,
        x           = player and player:getX() or 0,
        y           = player and player:getY() or 0,
        day         = day,
        confidence  = POS_Constants.SAT_SCAN_CONFIDENCE_BASE + ecologyBonus,
        mediaMod    = 0,
        carryMod    = 0,
        signalMod   = ecologyBonus,
        signalState = signalState,
        scanType    = "satellite",
    }
end

--- Generate a satellite discovery chunk (rare find).
---@param player userdata     The player character
---@param day number          Current game day
---@param discoveryType string  Discovery type from SAT_DISCOVERY_TYPES
---@return table chunk        The generated discovery chunk
function POS_PassiveRecon.generateSatelliteDiscovery(player, day, discoveryType)
    local zones = POS_Constants.MARKET_ZONES or {}
    local zoneId = #zones > 0 and zones[ZombRand(#zones) + 1] or "muldraugh"

    local signalState = nil
    if POS_SignalEcologyService and POS_SignalEcologyService.getQualitativeState then
        local ok, state = PhobosLib.safecall(POS_SignalEcologyService.getQualitativeState)
        if ok and state then signalState = state end
    end

    local descKey = POS_Constants.SAT_DISCOVERY_KEYS
        and POS_Constants.SAT_DISCOVERY_KEYS[discoveryType]
        or "UI_POS_SatScan_Discovery_Unknown"

    return {
        type          = POS_Constants.CHUNK_TYPE_SATELLITE_DISCOVERY,
        discoveryType = discoveryType,
        entityId      = zoneId,
        region        = zoneId,
        x             = player and player:getX() or 0,
        y             = player and player:getY() or 0,
        day           = day,
        confidence    = POS_Constants.SAT_SCAN_CONFIDENCE_BASE + 2000, -- high confidence
        signalState   = signalState,
        description   = descKey,
        scanType      = "satellite_discovery",
    }
end

-- Hook into game events
Events.EveryOneMinute.Add(POS_PassiveRecon.onEveryOneMinute)
