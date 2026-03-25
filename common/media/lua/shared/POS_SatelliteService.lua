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
-- POS_SatelliteService.lua
-- Business logic for Satellite Uplink (Tier IV — Broadcast).
-- Calibration state, broadcast strength, market effect,
-- terminal link detection, fuel drain, decalibration.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_SIGINTSkill"
require "POS_SIGINTService"

POS_SatelliteService = {}

local _TAG = "[POS:Satellite]"
local _TAG_WIRE = "POS:SatWire"

---------------------------------------------------------------
-- Satellite Dish Detection
---------------------------------------------------------------

--- Check if a world object is a satellite dish.
---@param worldObj IsoObject
---@return boolean
function POS_SatelliteService.isSatelliteDish(worldObj)
    if not worldObj then return false end
    local sprites = POS_Constants.SATELLITE_DISH_SPRITES
    if not sprites or #sprites == 0 then return false end

    local ok, spriteName = PhobosLib.safecall(function()
        local sprite = worldObj:getSprite()
        return sprite and sprite:getName()
    end)
    if not ok or not spriteName then return false end

    for _, name in ipairs(sprites) do
        if spriteName == name then return true end
    end
    return false
end

---------------------------------------------------------------
-- Building Identity
---------------------------------------------------------------

--- Get a stable building identity key.
---@param sq IsoGridSquare
---@return string|nil
local function getBuildingKey(sq)
    if not sq then return nil end
    local building = sq:getBuilding()
    if building then
        local bx, by = 0, 0
        PhobosLib.safecall(function()
            local def = building:getDef()
            if def then
                bx = def:getX()
                by = def:getY()
            end
        end)
        return "bld_" .. tostring(bx) .. "_" .. tostring(by)
    end
    -- Fallback for outdoor dishes: use square coordinates
    return "sq_" .. tostring(sq:getX()) .. "_" .. tostring(sq:getY())
end

---------------------------------------------------------------
-- Calibration State
---------------------------------------------------------------

--- Get the calibration key for a satellite dish at the given square.
---@param sq IsoGridSquare
---@return string|nil
function POS_SatelliteService.getCalibrationKey(sq)
    local bk = getBuildingKey(sq)
    if not bk then return nil end
    return POS_Constants.SATELLITE_CALIBRATED_KEY_PREFIX .. bk
end

--- Check if a satellite dish is calibrated.
---@param sq IsoGridSquare
---@return boolean
function POS_SatelliteService.isCalibrated(sq)
    local key = POS_SatelliteService.getCalibrationKey(sq)
    if not key then return false end

    -- Calibration stored in world modData (shared between players)
    local ok, val = PhobosLib.safecall(function()
        return PhobosLib.getWorldModData("POS_Satellite")[key]
    end)
    return ok and val == true
end

--- Set calibration state for a satellite dish.
---@param sq IsoGridSquare
---@param calibrated boolean
function POS_SatelliteService.setCalibrated(sq, calibrated)
    local key = POS_SatelliteService.getCalibrationKey(sq)
    if not key then return end

    PhobosLib.safecall(function()
        PhobosLib.getWorldModData("POS_Satellite")[key] = calibrated
    end)
end

---------------------------------------------------------------
-- Cooldown
---------------------------------------------------------------

--- Get broadcast cooldown key.
---@param player IsoPlayer
---@return string|nil
function POS_SatelliteService.getCooldownKey(player)
    if not player then return nil end
    local sq = player:getSquare()
    local bk = getBuildingKey(sq)
    if not bk then return nil end
    return POS_Constants.SATELLITE_VISIT_KEY_PREFIX .. bk
end

--- Check if broadcast is on cooldown.
---@param player IsoPlayer
---@return boolean onCooldown, number hoursLeft
function POS_SatelliteService.isOnCooldown(player)
    local key = POS_SatelliteService.getCooldownKey(player)
    if not key then return false, 0 end

    local modData = player:getModData()
    local lastHour = modData[key] or -9999
    local currentHour = getGameTime():getWorldAgeHours()
    local cooldownHours = POS_Sandbox and POS_Sandbox.getSatelliteBroadcastCooldownHours
        and POS_Sandbox.getSatelliteBroadcastCooldownHours()
        or POS_Constants.SATELLITE_BROADCAST_COOLDOWN_DEFAULT

    local hoursSince = currentHour - lastHour
    if hoursSince < cooldownHours then
        return true, math.ceil(cooldownHours - hoursSince)
    end
    return false, 0
end

--- Record broadcast cooldown.
---@param player IsoPlayer
function POS_SatelliteService.recordCooldown(player)
    local key = POS_SatelliteService.getCooldownKey(player)
    if not key then return end
    player:getModData()[key] = getGameTime():getWorldAgeHours()
end

---------------------------------------------------------------
-- Power & Fuel
---------------------------------------------------------------

--- Check if the satellite dish has power.
---@param sq IsoGridSquare
---@return boolean
function POS_SatelliteService.hasPower(sq)
    if not sq then return false end
    if PhobosLib.hasPower then
        return PhobosLib.hasPower(sq)
    end
    return false
end

--- Drain fuel from a nearby generator.
---@param sq IsoGridSquare
---@param amount number Fuel units to drain
---@return boolean success
function POS_SatelliteService.drainFuel(sq, amount)
    if not sq or not amount then return false end

    -- Only drain from generators (grid power = free)
    if PhobosLib.isGridPowerActive and PhobosLib.isGridPowerActive() then
        return true  -- grid power, no drain needed
    end

    if PhobosLib.findNearbyGenerator then
        local gen = PhobosLib.findNearbyGenerator(sq, 10)
        if gen then
            local ok = PhobosLib.safecall(function()
                local fuel = gen:getFuel()
                gen:setFuel(math.max(0, fuel - amount))
            end)
            return ok
        end
    end
    return false
end

--- Check if nearby generator fuel is low.
---@param sq IsoGridSquare
---@return boolean isLow, number|nil fuelLevel
function POS_SatelliteService.isFuelLow(sq)
    if not sq then return false, nil end
    if PhobosLib.isGridPowerActive and PhobosLib.isGridPowerActive() then
        return false, nil
    end

    if PhobosLib.findNearbyGenerator then
        local gen = PhobosLib.findNearbyGenerator(sq, 10)
        if gen then
            local ok, fuel = PhobosLib.safecall(function() return gen:getFuel() end)
            if ok and fuel then
                return fuel < POS_Constants.SATELLITE_LOW_FUEL_THRESHOLD, fuel
            end
        end
    end
    return false, nil
end

---------------------------------------------------------------
-- Terminal Link Detection
---------------------------------------------------------------

--- Check if a terminal is within link range of the satellite.
--- Checks wired link first, then falls back to wireless range scan.
---@param sq IsoGridSquare Satellite dish square
---@return boolean
function POS_SatelliteService.hasTerminalLink(sq)
    if not sq then return false end

    -- Priority 1: Wired connection
    if POS_SatelliteService.isWired(sq) then
        if POS_SatelliteService.validateWiredLink(sq) then
            return true
        end
        -- Stale wiring — desktop removed. Clear silently.
        POS_SatelliteService.clearWiringData(sq)
        PhobosLib.debug("POS", _TAG_WIRE, "Stale wired link cleared")
    end

    -- Priority 2: Wireless range scan (existing behaviour)
    local desktopSprites = POS_Constants.DESKTOP_COMPUTER_SPRITES
    if not desktopSprites then return false end

    return PhobosLib.scanNearbySquares(sq, POS_Constants.SATELLITE_LINK_RANGE,
        function(scanSq)
            local objs = scanSq:getObjects()
            if not objs then return false end
            for i = 0, objs:size() - 1 do
                local obj = objs:get(i)
                if obj then
                    local ok, spriteName = PhobosLib.safecall(function()
                        local sprite = obj:getSprite()
                        return sprite and sprite:getName()
                    end)
                    if ok and spriteName and desktopSprites[spriteName] then
                        return true
                    end
                end
            end
            return false
        end) or false
end

---------------------------------------------------------------
-- Broadcast Strength Calculation
---------------------------------------------------------------

--- Calculate broadcast strength for an artifact.
---@param player IsoPlayer
---@param artifact InventoryItem Intelligence artifact to broadcast
---@param sq IsoGridSquare Dish location
---@return number strength (0.0-1.0)
function POS_SatelliteService.calculateBroadcastStrength(player, artifact, sq)
    if not artifact then return 0 end

    local md = PhobosLib.getModData(artifact)
    local confidence = md and tonumber(md.POS_Confidence) or 0
    local baseStrength = confidence / 100

    -- SIGINT credibility bonus
    local credibility = POS_SIGINTService.getBroadcastCredibility(player)

    -- Equipment condition bonus
    local conditionBonus = 0
    local condPct = PhobosLib.getConditionPercent(artifact)
    if condPct and condPct > POS_Constants.SATELLITE_DISH_CONDITION_BONUS_MIN then
        conditionBonus = 0.05
    end

    -- Fuel bonus/penalty
    local fuelBonus = 0
    local isLow = POS_SatelliteService.isFuelLow(sq)
    if isLow then
        fuelBonus = -POS_Constants.SATELLITE_LOW_FUEL_PENALTY
    end

    local strength = baseStrength * (1.0 + credibility + conditionBonus + fuelBonus)
    return math.min(math.max(0, strength), 1.0)
end

---------------------------------------------------------------
-- Reputation by Artifact Type
---------------------------------------------------------------

--- Get the reputation award for broadcasting an artifact.
---@param artifact InventoryItem
---@return number Reputation in hundredths
function POS_SatelliteService.getReputationAward(artifact)
    if not artifact then return 0 end
    local md = PhobosLib.getModData(artifact)
    local artType = md and md.POS_ArtifactType

    if artType == POS_Constants.CAMERA_COMPILE_ACTION then
        return POS_Constants.SATELLITE_REP_SURVEY
    elseif artType == POS_Constants.CAMERA_TAPE_REVIEW_ACTION then
        return POS_Constants.SATELLITE_REP_REPORT
    elseif artType == POS_Constants.CAMERA_BULLETIN_ACTION then
        return POS_Constants.SATELLITE_REP_BULLETIN
    end

    -- Default for generic intelligence items
    return POS_Constants.SATELLITE_REP_SURVEY
end

--- Get the staleness multiplier for an artifact.
---@param artifact InventoryItem
---@return number Staleness multiplier (>1 = longer persistence)
function POS_SatelliteService.getStalenessMultiplier(artifact)
    if not artifact then return 1.0 end
    local md = PhobosLib.getModData(artifact)
    local artType = md and md.POS_ArtifactType

    if artType == POS_Constants.CAMERA_COMPILE_ACTION then
        return POS_Constants.SATELLITE_STALENESS_SURVEY
    elseif artType == POS_Constants.CAMERA_TAPE_REVIEW_ACTION then
        return POS_Constants.SATELLITE_STALENESS_REPORT
    elseif artType == POS_Constants.CAMERA_BULLETIN_ACTION then
        return POS_Constants.SATELLITE_STALENESS_BULLETIN
    end

    return 1.0
end

---------------------------------------------------------------
-- Core Actions
---------------------------------------------------------------

--- Calibrate the satellite dish.
---@param player IsoPlayer
---@param sq IsoGridSquare Dish square
---@return boolean success
function POS_SatelliteService.calibrate(player, sq)
    if not player or not sq then return false end

    -- Drain fuel
    POS_SatelliteService.drainFuel(sq, POS_Constants.SATELLITE_FUEL_DRAIN_CALIBRATE)

    -- Set calibrated
    POS_SatelliteService.setCalibrated(sq, true)

    -- Award XP (minor — calibration is a maintenance task)
    POS_SIGINTSkill.addXP(player, 2)

    -- Record last power timestamp (for decalibration tracking)
    local calKey = POS_SatelliteService.getCalibrationKey(sq)
    if calKey then
        PhobosLib.safecall(function()
            local satData = PhobosLib.getWorldModData("POS_Satellite")
            satData[calKey .. "_lastPower"] = getGameTime():getWorldAgeHours()
        end)
    end

    PhobosLib.debug("POS", _TAG, "Dish calibrated")
    return true
end

--- Broadcast a compiled intelligence artifact.
---@param player IsoPlayer
---@param artifact InventoryItem Intelligence artifact to broadcast
---@param sq IsoGridSquare Dish square
---@return table results { strength, reputation, staleness, consumed }
function POS_SatelliteService.broadcast(player, artifact, sq)
    local results = {
        strength = 0,
        reputation = 0,
        staleness = 1.0,
        consumed = false,
    }

    if not player or not artifact or not sq then return results end
    local inv = player:getInventory()
    if not inv then return results end

    -- Calculate broadcast parameters
    results.strength = POS_SatelliteService.calculateBroadcastStrength(player, artifact, sq)
    results.reputation = POS_SatelliteService.getReputationAward(artifact)
    results.staleness = POS_SatelliteService.getStalenessMultiplier(artifact)

    -- Drain fuel
    POS_SatelliteService.drainFuel(sq, POS_Constants.SATELLITE_FUEL_DRAIN_BROADCAST)

    -- Consume artifact
    if inv:contains(artifact) then
        inv:Remove(artifact)
        results.consumed = true
    end

    -- Apply market effect (delegate to MarketDatabase if available)
    if POS_MarketDatabase and POS_MarketDatabase.addRecord then
        local md = PhobosLib.getModData(artifact)
        if md then
            POS_MarketDatabase.addRecord({
                category = md.POS_Category or "mixed",
                confidence = md.POS_Confidence or 0,
                sourceTier = POS_Constants.SOURCE_TIER_STUDIO,
                strength = results.strength,
                staleness = results.staleness,
                day = getGameTime():getNightsSurvived(),
            })
        end
    end

    -- Phase 7D: Living Market zone summaries in satellite broadcast
    do
        local ok2, POS_MarketSim = PhobosLib.safecall(require, "POS_MarketSimulation")
        if ok2 and POS_MarketSim and POS_MarketSim.getZoneState then
            local zoneSummaries = {}
            local zoneCount = 0
            for _, zoneId in ipairs(POS_Constants.MARKET_ZONES or {}) do
                local state = POS_MarketSim.getZoneState(zoneId)
                if state then
                    zoneSummaries[zoneId] = {
                        volatility = state.volatility or 0,
                        pressure   = state.pressure or {},
                    }
                    zoneCount = zoneCount + 1
                end
            end
            if zoneCount > 0 then
                results.zoneSummaries = zoneSummaries
                PhobosLib.debug("POS", _TAG,
                    "Zone summaries included in broadcast (" .. zoneCount .. " zones)")
            end
        end
    end

    -- Grant reputation
    if PhobosLib.addPlayerReputation and results.reputation > 0 then
        PhobosLib.addPlayerReputation(player, "POS", results.reputation)
    end

    -- Award SIGINT XP
    POS_SIGINTSkill.addXP(player, POS_Constants.SIGINT_XP_SATELLITE_BROADCAST)

    -- Record cooldown
    POS_SatelliteService.recordCooldown(player)

    PhobosLib.debug("POS", _TAG,
        "Broadcast transmitted (strength: "
        .. string.format("%.2f", results.strength) .. ")")

    return results
end

--- Get the current status of a satellite dish.
---@param player IsoPlayer
---@param sq IsoGridSquare
---@return table status { calibrated, hasPower, onCooldown, hoursLeft, hasLink, fuelLow, isWired, wiredDistance }
function POS_SatelliteService.getStatus(player, sq)
    local wiringData = POS_SatelliteService.getWiringData(sq)
    return {
        calibrated = POS_SatelliteService.isCalibrated(sq),
        hasPower = POS_SatelliteService.hasPower(sq),
        onCooldown = POS_SatelliteService.isOnCooldown(player),
        hasLink = POS_SatelliteService.hasTerminalLink(sq),
        fuelLow = POS_SatelliteService.isFuelLow(sq),
        isWired = wiringData ~= nil,
        wiredDistance = wiringData and wiringData.wireCount or nil,
    }
end

---------------------------------------------------------------
-- Satellite Wiring
---------------------------------------------------------------

--- Read wiring data for a satellite dish from world modData.
-- @return table|nil {targetX, targetY, targetZ, wireCount, createdDay, linkType} or nil
function POS_SatelliteService.getWiringData(sq)
    if not sq then return nil end
    local buildingKey = getBuildingKey(sq)
    if not buildingKey then return nil end
    local satData = PhobosLib.getWorldModData("POS_Satellite")
    local prefix = POS_Constants.SATELLITE_WIRING_KEY_PREFIX .. buildingKey .. "_"
    local targetX = satData[prefix .. "targetX"]
    if not targetX then return nil end
    return {
        targetX    = targetX,
        targetY    = satData[prefix .. "targetY"],
        targetZ    = satData[prefix .. "targetZ"],
        wireCount  = satData[prefix .. "wireCount"],
        createdDay = satData[prefix .. "createdDay"],
        linkType   = satData[prefix .. "linkType"],
    }
end

function POS_SatelliteService.setWiringData(sq, data)
    if not sq or not data then return end
    local buildingKey = getBuildingKey(sq)
    if not buildingKey then return end
    local satData = PhobosLib.getWorldModData("POS_Satellite")
    local prefix = POS_Constants.SATELLITE_WIRING_KEY_PREFIX .. buildingKey .. "_"
    satData[prefix .. "targetX"]    = data.targetX
    satData[prefix .. "targetY"]    = data.targetY
    satData[prefix .. "targetZ"]    = data.targetZ
    satData[prefix .. "wireCount"]  = data.wireCount
    satData[prefix .. "createdDay"] = data.createdDay
    satData[prefix .. "linkType"]   = data.linkType
end

function POS_SatelliteService.clearWiringData(sq)
    if not sq then return end
    local buildingKey = getBuildingKey(sq)
    if not buildingKey then return end
    local satData = PhobosLib.getWorldModData("POS_Satellite")
    local prefix = POS_Constants.SATELLITE_WIRING_KEY_PREFIX .. buildingKey .. "_"
    satData[prefix .. "targetX"]    = nil
    satData[prefix .. "targetY"]    = nil
    satData[prefix .. "targetZ"]    = nil
    satData[prefix .. "wireCount"]  = nil
    satData[prefix .. "createdDay"] = nil
    satData[prefix .. "linkType"]   = nil
end

function POS_SatelliteService.isWired(sq)
    return POS_SatelliteService.getWiringData(sq) ~= nil
end

--- Validate that a wired link's target desktop still exists.
-- Returns true if the target square has a desktop sprite, or if the chunk is unloaded.
function POS_SatelliteService.validateWiredLink(sq)
    local data = POS_SatelliteService.getWiringData(sq)
    if not data then return false end
    local ok, targetSq = PhobosLib.safecall(getSquare, data.targetX, data.targetY, data.targetZ)
    if not ok or not targetSq then
        -- Chunk not loaded — assume valid
        return true
    end
    local desktopSprites = POS_Constants.DESKTOP_COMPUTER_SPRITES
    if not desktopSprites then return false end
    for i = 0, targetSq:getObjects():size() - 1 do
        local obj = targetSq:getObjects():get(i)
        local sprite = obj:getSprite()
        if sprite then
            local spriteName = sprite:getName()
            if spriteName and desktopSprites[spriteName] then
                return true
            end
        end
    end
    return false
end

--- Find desktop computers within wiring range of a satellite dish.
-- @return table Array of {x, y, z, wireCount} sorted by wireCount ascending
function POS_SatelliteService.findDesktopTargets(sq, maxRange)
    if not sq then return {} end
    maxRange = maxRange or POS_Constants.SATELLITE_WIRING_MAX_RANGE_DEFAULT
    local desktopSprites = POS_Constants.DESKTOP_COMPUTER_SPRITES
    if not desktopSprites then return {} end
    local targets = {}
    local sx, sy, sz = sq:getX(), sq:getY(), sq:getZ()

    local found = PhobosLib.scanNearbySquares(sq, maxRange, function(scanSq)
        for i = 0, scanSq:getObjects():size() - 1 do
            local obj = scanSq:getObjects():get(i)
            local sprite = obj:getSprite()
            if sprite then
                local spriteName = sprite:getName()
                if spriteName and desktopSprites[spriteName] then
                    local tx, ty, tz = scanSq:getX(), scanSq:getY(), scanSq:getZ()
                    local wireCount = PhobosLib.manhattanDistance(
                        sx, sy, sz, tx, ty, tz,
                        POS_Constants.SATELLITE_WIRING_Z_PENALTY)
                    if wireCount <= maxRange then
                        table.insert(targets, {
                            x = tx, y = ty, z = tz,
                            wireCount = wireCount,
                        })
                    end
                end
            end
        end
        return false -- keep scanning
    end)

    table.sort(targets, function(a, b) return a.wireCount < b.wireCount end)
    return targets
end

--- Wire a satellite dish to a terminal. Consumes wire from inventory.
function POS_SatelliteService.wireToTerminal(player, sq, targetX, targetY, targetZ, wireCount)
    if not player or not sq then return false end
    local consumed = PhobosLib.consumeItems(player, POS_Constants.SATELLITE_WIRING_ITEM, wireCount)
    if consumed < wireCount then
        -- Not enough wire — refund what was taken
        if consumed > 0 then
            PhobosLib.grantItems(player, POS_Constants.SATELLITE_WIRING_ITEM, consumed)
        end
        return false
    end
    local currentDay = 0
    local ok, gameTime = PhobosLib.safecall(getGameTime)
    if ok and gameTime then
        local ok2, day = PhobosLib.safecall(gameTime.getWorldAgeHours, gameTime)
        if ok2 and day then
            currentDay = math.floor(day / 24)
        end
    end
    POS_SatelliteService.setWiringData(sq, {
        targetX    = targetX,
        targetY    = targetY,
        targetZ    = targetZ,
        wireCount  = wireCount,
        createdDay = currentDay,
        linkType   = POS_Constants.SATELLITE_LINK_TYPE_WIRED,
    })
    -- Award SIGINT XP
    local ok3, sigintService = PhobosLib.safecall(require, "POS_SIGINTService")
    if ok3 and sigintService and sigintService.awardXP then
        PhobosLib.safecall(sigintService.awardXP, player, POS_Constants.SIGINT_XP_SATELLITE_CALIBRATE or 2)
    end
    PhobosLib.debug("POS", _TAG_WIRE, "Wired to terminal at " .. targetX .. "," .. targetY .. "," .. targetZ .. " (" .. wireCount .. " wires)")
    return true
end

--- Disconnect wiring from a satellite dish. Returns wire to player.
-- @return table|nil {returned = count} or nil if not wired
function POS_SatelliteService.disconnectWiring(player, sq)
    if not player or not sq then return nil end
    local data = POS_SatelliteService.getWiringData(sq)
    if not data then return nil end
    local returnCount = math.floor((data.wireCount or 0) * POS_Constants.SATELLITE_WIRING_RETURN_PCT / 100)
    if returnCount > 0 then
        PhobosLib.grantItems(player, POS_Constants.SATELLITE_WIRING_ITEM, returnCount)
    end
    POS_SatelliteService.clearWiringData(sq)
    PhobosLib.debug("POS", _TAG_WIRE, "Disconnected wiring, returned " .. returnCount .. " wires")
    return { returned = returnCount }
end

--- Check wiring requirements using PhobosLib.checkRequirements.
function POS_SatelliteService.checkWiringRequirements(player, wireCount)
    return PhobosLib.checkRequirements(player, {
        items = { POS_Constants.SATELLITE_WIRING_ITEM, wireCount },
        tools = {
            POS_Constants.SATELLITE_WIRING_TOOL_SCREWDRIVER,
            POS_Constants.SATELLITE_WIRING_TOOL_PLIERS,
        },
        minSkill  = POS_Constants.SATELLITE_WIRING_MIN_ELECTRICAL,
        skillType = "Electricity",
    })
end

---------------------------------------------------------------
-- Decalibration Check (called from economy tick)
---------------------------------------------------------------

--- Check all known calibrated dishes and decalibrate if power lost.
--- Called periodically (e.g., from POS_EconomyTick).
function POS_SatelliteService.checkDecalibration()
    local ok, satData = PhobosLib.safecall(function() return PhobosLib.getWorldModData("POS_Satellite") end)
    if not ok or not satData then return end

    -- This would iterate world modData entries to find calibrated dishes
    -- and check if their buildings have lost power for > DECALIBRATION_DAYS.
    -- Full implementation deferred to when the satellite sprites are known
    -- and we can test with actual world objects.
    PhobosLib.debug("POS", _TAG, "Decalibration check (stub)")
end
