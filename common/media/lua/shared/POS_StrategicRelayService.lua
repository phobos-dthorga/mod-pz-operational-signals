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
-- POS_StrategicRelayService.lua
-- Core service for Tier V Strategic Relay facility state
-- management and remote operations.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_Relay"

POS_StrategicRelayService = {}

local _TAG = "POS:Relay"

---------------------------------------------------------------
-- Internal Helpers
---------------------------------------------------------------

--- Get or create the relay registry from world ModData.
---@return table registry
local function _getRegistry()
    local ok, reg = PhobosLib.safecall(function()
        return PhobosLib.getWorldModData(POS_Constants.RELAY_REGISTRY_KEY)
    end)
    if not ok or not reg then
        return {}
    end
    return reg
end

--- Persist relay state to world ModData.
---@param siteId string
---@param relay table
local function _saveRelay(siteId, relay)
    PhobosLib.safecall(function()
        local reg = PhobosLib.getWorldModData(POS_Constants.RELAY_REGISTRY_KEY)
        reg[siteId] = relay
    end)
end

--- Create unique site ID from square coordinates.
---@param sq IsoGridSquare
---@return string
local function _generateSiteId(sq)
    return "relay_" .. tostring(sq:getX()) .. "_" .. tostring(sq:getY()) .. "_" .. tostring(sq:getZ())
end

---------------------------------------------------------------
-- Discovery
---------------------------------------------------------------

--- Create a new relay site record from a detected dish location.
---@param player IsoPlayer
---@param sq IsoGridSquare
---@return table|nil relay The new site record, or nil on failure
function POS_StrategicRelayService.discoverRelay(player, sq)
    if not player or not sq then return nil end

    local siteId = _generateSiteId(sq)

    -- Check if already discovered
    local existing = POS_StrategicRelayService.getRelay(siteId)
    if existing then
        PhobosLib.debug("POS", _TAG, "Relay already discovered: " .. siteId)
        return existing
    end

    local gameTime = getGameTime()
    local currentDay = gameTime and gameTime:getNightsSurvived() or 0

    local relay = {
        siteId             = siteId,
        x                  = sq:getX(),
        y                  = sq:getY(),
        z                  = sq:getZ(),
        calibrationState   = POS_Constants.RELAY_CALIBRATION_INITIAL,
        bandwidthMode      = POS_Constants.RELAY_BW_BALANCED,
        powerDraw          = POS_Constants.RELAY_POWER_IDLE,
        networkHealth      = 1.0,
        isCalibrating      = false,
        calibrationProgress = 0.0,
        discoveredDay      = currentDay,
        lastTickDay        = currentDay,
    }

    _saveRelay(siteId, relay)

    -- Award SIGINT XP for discovery
    local ok1, POS_SIGINTSkill = PhobosLib.safecall(require, "POS_SIGINTSkill")
    if ok1 and POS_SIGINTSkill and POS_SIGINTSkill.addXP then
        PhobosLib.safecall(POS_SIGINTSkill.addXP, player, POS_Constants.SIGINT_XP_RELAY_DISCOVER)
    end

    -- Tutorial: first relay discovery
    if POS_TutorialService and POS_TutorialService.tryAward then
        POS_TutorialService.tryAward(player, POS_Constants.TUTORIAL_FIRST_RELAY_DISCOVERY)
    end

    -- Fire discovery event
    if POS_Events and POS_Events.OnRelayDiscovered then
        PhobosLib.safecall(function()
            POS_Events.OnRelayDiscovered:trigger({ siteId = siteId, x = relay.x, y = relay.y, z = relay.z })
        end)
    end

    PhobosLib.debug("POS", _TAG, "Relay discovered: " .. siteId)
    return relay
end

---------------------------------------------------------------
-- Queries
---------------------------------------------------------------

--- Get relay state from world ModData registry.
---@param siteId string
---@return table|nil relay
function POS_StrategicRelayService.getRelay(siteId)
    if not siteId then return nil end
    local reg = _getRegistry()
    return reg[siteId]
end

--- Get all discovered relay sites.
---@return table relays Array of site records
function POS_StrategicRelayService.getAllRelays()
    local reg = _getRegistry()
    local results = {}
    for _, relay in pairs(reg) do
        if type(relay) == "table" and relay.siteId then
            table.insert(results, relay)
        end
    end
    return results
end

--- Rich status for UI display.
---@param siteId string
---@return table|nil status
function POS_StrategicRelayService.getRelayStatus(siteId)
    local relay = POS_StrategicRelayService.getRelay(siteId)
    if not relay then return nil end

    local calState = relay.calibrationState or POS_Constants.RELAY_CALIBRATION_INITIAL
    local isOperational = calState >= POS_Constants.RELAY_CALIBRATION_MIN_OPERATIONAL
    local isDegraded = calState < POS_Constants.RELAY_CALIBRATION_DEGRADED_THRESHOLD

    return {
        calibrationState    = calState,
        calibrationProgress = relay.calibrationProgress or 0.0,
        isCalibrating       = relay.isCalibrating or false,
        bandwidthMode       = relay.bandwidthMode or POS_Constants.RELAY_BW_BALANCED,
        powerDraw           = relay.powerDraw or POS_Constants.RELAY_POWER_IDLE,
        networkHealth       = relay.networkHealth or 1.0,
        isOperational       = isOperational,
        isDegraded          = isDegraded,
    }
end

---------------------------------------------------------------
-- Wired Link
---------------------------------------------------------------

--- Check wired link exists between relay and terminal.
--- Tier V REQUIRES wired link (no wireless fallback).
---@param siteId string
---@param terminalSq IsoGridSquare
---@return boolean
function POS_StrategicRelayService.isRelayLinked(siteId, terminalSq)
    if not siteId then return false end

    local relay = POS_StrategicRelayService.getRelay(siteId)
    if not relay then return false end

    -- Get the relay's square from stored coordinates
    local relaySq = getSquare and getSquare(relay.x, relay.y, relay.z) or nil

    -- Primary: delegate to Tier IV wiring system (building-key based).
    -- POS_SatelliteService.isWired(sq) checks if wiring data exists for the
    -- building containing this square — works for both Tier IV and Tier V
    -- since the wiring action stores data by building key.
    if relaySq and POS_SatelliteService and POS_SatelliteService.isWired then
        local ok, wired = PhobosLib.safecall(POS_SatelliteService.isWired, relaySq)
        if ok and wired then return true end
    end

    -- Fallback for unloaded chunks: log warning
    if not relaySq then
        PhobosLib.debug("POS", _TAG,
            "isRelayLinked: relay square unloaded for " .. tostring(siteId)
            .. " — cannot verify wiring")
    end

    return false
end

--- Establish a remote data link between a relay and the player's terminal.
--- For Tier V, "wiring" is a digital data link — the player doesn't need
--- to physically run cable to the rooftop. They initiate from the terminal.
--- Uses Tier IV wiring format for compatibility with the existing system.
---@param siteId string  Relay site ID
---@param player userdata  The player at a terminal
---@return boolean success
---@return string|nil errorKey  Translation key if failed
function POS_StrategicRelayService.wireRemote(siteId, player)
    if not siteId or not player then return false, "UI_POS_Relay_WiringFailed" end

    local relay = POS_StrategicRelayService.getRelay(siteId)
    if not relay then return false, "UI_POS_Relay_NoRelay" end

    local playerSq = player:getCurrentSquare()
    if not playerSq then return false, "UI_POS_Relay_WiringFailed" end

    -- Get the relay's square
    local relaySq = getSquare and getSquare(relay.x, relay.y, relay.z)
    if not relaySq then return false, "UI_POS_Relay_WiringFailed" end

    -- Store wiring using Tier IV format (building-key based) for compatibility.
    -- This is a data link, not physical cable — no wire consumption needed.
    if POS_SatelliteService and POS_SatelliteService.setWiringData then
        local currentDay = 0
        local gt = getGameTime and getGameTime()
        if gt then currentDay = math.floor((gt:getWorldAgeHours() or 0) / 24) end

        local ok = PhobosLib.safecall(POS_SatelliteService.setWiringData,
            relaySq, {
                targetX    = playerSq:getX(),
                targetY    = playerSq:getY(),
                targetZ    = playerSq:getZ(),
                wireCount  = 0,  -- remote data link, no physical wire
                createdDay = currentDay,
                linkType   = "relay_data_link",
            })
        if ok then
            PhobosLib.debug("POS", _TAG,
                "wireRemote: data link established for " .. tostring(siteId))
            return true
        end
    end

    return false, "UI_POS_Relay_WiringFailed"
end

---------------------------------------------------------------
-- Calibration
---------------------------------------------------------------

--- Start remote calibration from terminal.
---@param player IsoPlayer
---@param siteId string
---@return boolean success, string|nil errorReason
function POS_StrategicRelayService.calibrateRemote(player, siteId)
    if not player or not siteId then
        return false, "invalid_args"
    end

    local relay = POS_StrategicRelayService.getRelay(siteId)
    if not relay then
        return false, "relay_not_found"
    end

    -- Validate wired link
    local terminalSq = player:getSquare()
    if not POS_StrategicRelayService.isRelayLinked(siteId, terminalSq) then
        return false, "no_wired_link"
    end

    -- Check power (relay must have grid power or generator)
    local ok, relaySq = PhobosLib.safecall(getSquare, relay.x, relay.y, relay.z)
    if ok and relaySq then
        local hasPower = PhobosLib.safecall(function()
            return relaySq:haveElectricity()
        end)
        if not hasPower then
            return false, "no_power"
        end
    end

    -- Already calibrating
    if relay.isCalibrating then
        return false, "already_calibrating"
    end

    -- Start calibration (non-blocking)
    relay.isCalibrating = true
    relay.calibrationProgress = 0.0
    relay.powerDraw = POS_Constants.RELAY_POWER_CALIBRATING
    _saveRelay(siteId, relay)

    PhobosLib.debug("POS", _TAG, "Remote calibration started: " .. siteId)
    return true, nil
end

--- Abort in-progress calibration.
---@param siteId string
function POS_StrategicRelayService.cancelCalibration(siteId)
    if not siteId then return end

    local relay = POS_StrategicRelayService.getRelay(siteId)
    if not relay then return end

    relay.isCalibrating = false
    -- Retain whatever calibrationState was achieved
    relay.powerDraw = relay.calibrationState >= POS_Constants.RELAY_CALIBRATION_MIN_OPERATIONAL
        and POS_Constants.RELAY_POWER_ACTIVE
        or POS_Constants.RELAY_POWER_IDLE
    _saveRelay(siteId, relay)

    PhobosLib.debug("POS", _TAG, "Calibration cancelled: " .. siteId)
end

---------------------------------------------------------------
-- Bandwidth
---------------------------------------------------------------

--- Change bandwidth allocation mode.
---@param siteId string
---@param mode string One of RELAY_BW_MODES
---@return boolean success
function POS_StrategicRelayService.setBandwidthMode(siteId, mode)
    if not siteId or not mode then return false end

    -- Validate mode
    local validMode = false
    for _, m in ipairs(POS_Constants.RELAY_BW_MODES) do
        if m == mode then
            validMode = true
            break
        end
    end
    if not validMode then
        PhobosLib.debug("POS", _TAG, "Invalid bandwidth mode: " .. tostring(mode))
        return false
    end

    local relay = POS_StrategicRelayService.getRelay(siteId)
    if not relay then return false end

    relay.bandwidthMode = mode

    -- Update power draw based on mode multiplier
    local mult = POS_Constants.RELAY_BW_POWER_MULT[mode] or 1.0
    relay.powerDraw = POS_Constants.RELAY_POWER_ACTIVE * mult

    _saveRelay(siteId, relay)
    PhobosLib.debug("POS", _TAG, "Bandwidth mode set to " .. mode .. " for " .. siteId)
    return true
end

---------------------------------------------------------------
-- Tick: Main Relay Update (EveryTenMinutes)
---------------------------------------------------------------

--- Main relay tick -- calibration drift, network health, power.
function POS_StrategicRelayService.tick()
    local relays = POS_StrategicRelayService.getAllRelays()
    if #relays == 0 then return end

    -- Drift per tick: DRIFT_PER_DAY / (24 hours * 6 ten-minute intervals per hour)
    local driftPerTick = POS_Constants.RELAY_CALIBRATION_DRIFT_PER_DAY / (24 * 6)

    for _, relay in ipairs(relays) do
        local changed = false

        -- (a) Calibration drift (approach toward degradation)
        if not relay.isCalibrating and relay.calibrationState > 0 then
            local drifted = PhobosLib.approach(relay.calibrationState, 0.0, driftPerTick)
            relay.calibrationState = PhobosLib.clamp(drifted, 0.0, POS_Constants.RELAY_CALIBRATION_MAX)
            changed = true
        end

        -- (b) Calibration progress (handled in calibrationTick for finer resolution)

        -- (c) Update network health based on calibrationState
        local targetHealth = relay.calibrationState
        if relay.powerDraw <= 0 then
            targetHealth = 0.0
        end
        relay.networkHealth = PhobosLib.approach(
            relay.networkHealth or 1.0,
            targetHealth,
            POS_Constants.RELAY_CALIBRATION_DRIFT_PER_DAY / (24 * 6)
        )
        relay.networkHealth = PhobosLib.clamp(relay.networkHealth, 0.0, 1.0)

        -- (d) Clamp calibration state
        relay.calibrationState = PhobosLib.clamp(
            relay.calibrationState,
            0.0,
            POS_Constants.RELAY_CALIBRATION_MAX
        )

        if changed or true then
            _saveRelay(relay.siteId, relay)
        end
    end
end

---------------------------------------------------------------
-- Tick: Calibration Progress (EveryOneMinute)
---------------------------------------------------------------

--- Fast tick for calibration progress -- only processes actively calibrating relays.
function POS_StrategicRelayService.calibrationTick()
    local relays = POS_StrategicRelayService.getAllRelays()
    if #relays == 0 then return end

    -- Get local player SIGINT level for calibration speed bonus
    local sigintLevel = 0
    local ok, POS_SIGINTSkill = PhobosLib.safecall(require, "POS_SIGINTSkill")
    if ok and POS_SIGINTSkill and POS_SIGINTSkill.getLevel then
        local player = getPlayer and getPlayer()
        if player then
            local ok2, lvl = PhobosLib.safecall(POS_SIGINTSkill.getLevel, player)
            if ok2 and lvl then sigintLevel = lvl end
        end
    end

    local speedBase = POS_Constants.RELAY_CALIBRATION_SPEED_BASE
    local speedBonus = POS_Constants.RELAY_CALIBRATION_SPEED_SIGINT_BONUS
    local progressPerTick = speedBase + (sigintLevel * speedBonus)

    for _, relay in ipairs(relays) do
        if relay.isCalibrating then
            relay.calibrationProgress = (relay.calibrationProgress or 0.0) + progressPerTick

            if relay.calibrationProgress >= 1.0 then
                -- Calibration complete
                relay.calibrationState = POS_Constants.RELAY_CALIBRATION_MAX
                relay.isCalibrating = false
                relay.calibrationProgress = 1.0
                relay.powerDraw = POS_Constants.RELAY_POWER_ACTIVE

                -- Award SIGINT XP
                local player = getPlayer and getPlayer()
                if player then
                    local ok3, skill = PhobosLib.safecall(require, "POS_SIGINTSkill")
                    if ok3 and skill and skill.addXP then
                        PhobosLib.safecall(skill.addXP, player, POS_Constants.SIGINT_XP_RELAY_CALIBRATE)
                    end
                end

                -- Fire calibration complete event
                if POS_Events and POS_Events.OnRelayCalibrated then
                    PhobosLib.safecall(function()
                        POS_Events.OnRelayCalibrated:trigger({ siteId = relay.siteId })
                    end)
                end

                PhobosLib.debug("POS", _TAG, "Calibration complete: " .. relay.siteId)
            end

            relay.calibrationProgress = PhobosLib.clamp(relay.calibrationProgress, 0.0, 1.0)
            _saveRelay(relay.siteId, relay)

            -- Fire progress event for live UI updates
            if POS_Events and POS_Events.OnBackgroundProgressUpdated then
                PhobosLib.safecall(
                    POS_Events.OnBackgroundProgressUpdated.trigger,
                    POS_Events.OnBackgroundProgressUpdated, {
                        processId = "relay_calibration",
                        progress  = relay.calibrationProgress,
                        label     = relay.siteId,
                    })
            end
        end
    end
end

---------------------------------------------------------------
-- Event Hooks
---------------------------------------------------------------

if Events and Events.EveryTenMinutes then
    Events.EveryTenMinutes.Add(POS_StrategicRelayService.tick)
end
if Events and Events.EveryOneMinute then
    Events.EveryOneMinute.Add(POS_StrategicRelayService.calibrationTick)
end
