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

    local ok, spriteName = pcall(function()
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
    if not building then return nil end

    local bx, by = 0, 0
    pcall(function()
        local def = building:getDef()
        if def then
            bx = def:getX()
            by = def:getY()
        end
    end)
    return tostring(bx) .. "_" .. tostring(by)
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
    local ok, val = pcall(function()
        return ModData.getOrCreate("POS_Satellite")[key]
    end)
    return ok and val == true
end

--- Set calibration state for a satellite dish.
---@param sq IsoGridSquare
---@param calibrated boolean
function POS_SatelliteService.setCalibrated(sq, calibrated)
    local key = POS_SatelliteService.getCalibrationKey(sq)
    if not key then return end

    pcall(function()
        ModData.getOrCreate("POS_Satellite")[key] = calibrated
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
            local ok = pcall(function()
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
            local ok, fuel = pcall(function() return gen:getFuel() end)
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
---@param sq IsoGridSquare Satellite dish square
---@return boolean
function POS_SatelliteService.hasTerminalLink(sq)
    if not sq then return false end

    -- Look for a computer within SATELLITE_LINK_RANGE tiles
    -- This is a simplified check — full check would use building scanning
    if PhobosLib.findNearbyObjectByKeywords then
        local computer = PhobosLib.findNearbyObjectByKeywords(
            sq, POS_Constants.SATELLITE_LINK_RANGE,
            { "computer", "desktop" })
        return computer ~= nil
    end
    return false
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
        pcall(function()
            local satData = ModData.getOrCreate("POS_Satellite")
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
---@return table status { calibrated, hasPower, onCooldown, hoursLeft, hasLink, fuelLow }
function POS_SatelliteService.getStatus(player, sq)
    return {
        calibrated = POS_SatelliteService.isCalibrated(sq),
        hasPower = POS_SatelliteService.hasPower(sq),
        onCooldown = POS_SatelliteService.isOnCooldown(player),
        hasLink = POS_SatelliteService.hasTerminalLink(sq),
        fuelLow = POS_SatelliteService.isFuelLow(sq),
    }
end

---------------------------------------------------------------
-- Decalibration Check (called from economy tick)
---------------------------------------------------------------

--- Check all known calibrated dishes and decalibrate if power lost.
--- Called periodically (e.g., from POS_EconomyTick).
function POS_SatelliteService.checkDecalibration()
    local ok, satData = pcall(function() return ModData.getOrCreate("POS_Satellite") end)
    if not ok or not satData then return end

    -- This would iterate world modData entries to find calibrated dishes
    -- and check if their buildings have lost power for > DECALIBRATION_DAYS.
    -- Full implementation deferred to when the satellite sprites are known
    -- and we can test with actual world objects.
    PhobosLib.debug("POS", _TAG, "Decalibration check (stub)")
end
