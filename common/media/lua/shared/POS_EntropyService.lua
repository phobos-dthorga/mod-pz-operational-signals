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
-- POS_EntropyService.lua
-- Fog-of-market entropy system for POSnet.
--
-- Manages per-zone/category information quality state (certainty,
-- freshness, rumourLoad, contradiction, trust, silenceDays).
-- Called from POS_MarketSimulation each economy tick. Reads are
-- used by POS_PriceEngine and terminal UI screens.
--
-- Design reference: docs/architecture/entropy-system-design.md
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_Entropy"

POS_EntropyService = {}

local _TAG = "[POS:Entropy]"

---------------------------------------------------------------
-- Internal: zone intel state cache (mirrors zone state)
---------------------------------------------------------------

--- Reference to _zoneStates from POS_MarketSimulation. Set during tick
--- via the zoneState parameter.
local _zoneStatesRef = {}

--- Notification throttle cache: "zoneId:categoryId" → last notify minute
local _notifyThrottle = {}

---------------------------------------------------------------
-- Intel state lifecycle
---------------------------------------------------------------

--- Ensure an intelState entry exists for a zone/category pair.
--- Creates with defaults if absent. Returns the state table.
---@param zoneState table  Zone state table (must have .intelState)
---@param categoryId string Category identifier
---@return table  The intelState entry for this category
function POS_EntropyService.ensureIntelState(zoneState, categoryId)
    if not zoneState then return nil end
    zoneState.intelState = zoneState.intelState or {}
    if not zoneState.intelState[categoryId] then
        zoneState.intelState[categoryId] = {
            certainty     = POS_Constants.ENTROPY_DEFAULT_CERTAINTY,
            freshness     = POS_Constants.ENTROPY_DEFAULT_FRESHNESS,
            rumourLoad    = 0.00,
            contradiction = 0.00,
            trust         = POS_Constants.ENTROPY_TRUST_DEFAULT,
            silenceDays   = 0,
            concealment   = 0.00,
            _observedThisTick = false,
            _prevBand         = nil,
        }
    end
    return zoneState.intelState[categoryId]
end

---------------------------------------------------------------
-- Main tick (called once per economy tick per zone)
---------------------------------------------------------------

--- Update fog-of-market entropy for all categories in a zone.
--- Called from POS_MarketSimulation Phase 2 after pressure aggregation.
---@param zoneState table   Zone state table with .intelState
---@param zoneId    string  Zone identifier
---@param currentDay number Current game day
function POS_EntropyService.tickZoneEntropy(zoneState, zoneId, currentDay)
    if not zoneState or not zoneState.intelState then return end

    for categoryId, state in pairs(zoneState.intelState) do
        -- Freshness decay (multiplicative, per design doc)
        state.freshness = PhobosLib.decayMultiplicative(
            state.freshness,
            POS_Constants.ENTROPY_FRESHNESS_DECAY, 0)

        -- Silence tracking
        if state._observedThisTick then
            -- Fresh data arrived this tick — reset silence
            if state.silenceDays > POS_Constants.ENTROPY_SILENCE_STALE_DAYS then
                -- Was stale, now recovered — notify
                POS_EntropyService._notifyRecovery(zoneId, categoryId)
            end
            state.silenceDays = 0
            state._observedThisTick = false
        else
            state.silenceDays = state.silenceDays + 1
        end

        -- Certainty erosion from silence + noise
        local silencePenalty = state.silenceDays
            * POS_Constants.ENTROPY_CERTAINTY_SILENCE_RATE
        local noisePenalty = state.rumourLoad
            * POS_Constants.ENTROPY_CERTAINTY_NOISE_RATE
        state.certainty = PhobosLib.clamp(
            state.certainty - silencePenalty - noisePenalty, 0, 1)

        -- Contradiction natural decay
        state.contradiction = PhobosLib.decayMultiplicative(
            state.contradiction,
            POS_Constants.ENTROPY_CONTRADICTION_DECAY, 0)

        -- RumourLoad natural decay (slow)
        state.rumourLoad = PhobosLib.decayMultiplicative(
            state.rumourLoad,
            POS_Constants.ENTROPY_RUMOUR_LOAD_DECAY, 0)

        -- Trust is clamped (Phase 1: no active trust changes, just bounds)
        state.trust = PhobosLib.clamp(state.trust,
            POS_Constants.ENTROPY_TRUST_MIN,
            POS_Constants.ENTROPY_TRUST_MAX)

        -- Detect atmospheric band transitions for notifications
        local band = POS_EntropyService._resolveBand(state.certainty)
        if state._prevBand and band.name ~= state._prevBand then
            POS_EntropyService._notifyTransition(
                zoneId, categoryId, band, currentDay)
        end
        state._prevBand = band.name

        -- Cold market notification
        if state.silenceDays == POS_Constants.ENTROPY_SILENCE_COLD_DAYS then
            POS_EntropyService._notifyCold(zoneId, categoryId)
        end
    end

    PhobosLib.debug("POS", _TAG, "tickZoneEntropy: " .. tostring(zoneId))
end

---------------------------------------------------------------
-- Effective pressure (read by POS_PriceEngine)
---------------------------------------------------------------

--- Apply fog-of-market attenuation to raw zone pressure.
--- Formula: rawPressure * certainty * trust * (1.0 - rumourLoad * noiseWeight)
---@param zoneId     string  Zone identifier
---@param categoryId string  Category identifier
---@param rawPressure number Raw zone pressure from wholesalers + events
---@return number            Attenuated effective pressure
function POS_EntropyService.getEffectivePressure(zoneId, categoryId, rawPressure)
    local state = POS_EntropyService.getIntelState(zoneId, categoryId)
    if not state then return rawPressure end

    local certaintyMod = PhobosLib.clamp(state.certainty, 0.1, 1.0)
    local trustMod     = PhobosLib.clamp(state.trust, 0.1, 1.0)
    local noiseMod     = 1.0 - state.rumourLoad * POS_Constants.ENTROPY_NOISE_WEIGHT

    return rawPressure * certaintyMod * trustMod * math.max(0.1, noiseMod)
end

---------------------------------------------------------------
-- Event writers (called from other services)
---------------------------------------------------------------

--- Record a contradiction event from fragment/rumour mismatch.
---@param zoneId     string  Zone identifier
---@param categoryId string  Category identifier
---@param damage     number  Contradiction damage amount (e.g. 0.10)
function POS_EntropyService.addContradiction(zoneId, categoryId, damage)
    local state = POS_EntropyService._getOrCreateState(zoneId, categoryId)
    if not state then return end

    state.contradiction = PhobosLib.clamp(
        state.contradiction + (damage or 0), 0, 1)
    -- Contradiction also reduces certainty
    state.certainty = PhobosLib.clamp(
        state.certainty - (damage or 0) * 0.5, 0, 1)

    PhobosLib.debug("POS", _TAG,
        "addContradiction: " .. tostring(zoneId) .. "/" .. tostring(categoryId)
        .. " dmg=" .. tostring(damage)
        .. " contradiction=" .. string.format("%.2f", state.contradiction))

    -- Notify if threshold crossed
    if state.contradiction >= POS_Constants.ENTROPY_PN_CONTRADICTION_THRESHOLD then
        POS_EntropyService._notifyContradiction(zoneId, categoryId)
    end
end

--- Record a fresh observation arriving (resets silence, boosts freshness).
---@param zoneId     string  Zone identifier
---@param categoryId string  Category identifier
---@param confidence number  Observation confidence (0-1, scales boost)
function POS_EntropyService.recordObservation(zoneId, categoryId, confidence)
    local state = POS_EntropyService._getOrCreateState(zoneId, categoryId)
    if not state then return end

    -- Confidence may arrive as a string tier ("high"/"medium"/"low") or
    -- a number. Normalise to numeric 0-1 for arithmetic.
    if type(confidence) == "string" then
        if confidence == "high" then confidence = 0.80
        elseif confidence == "medium" then confidence = 0.50
        elseif confidence == "low" then confidence = 0.25
        else confidence = 0.50 end
    end
    confidence = tonumber(confidence) or 0.5

    -- Boost freshness
    state.freshness = PhobosLib.clamp(
        state.freshness + POS_Constants.ENTROPY_OBSERVATION_FRESHNESS_BOOST * confidence,
        0, 1)

    -- Boost certainty (scaled by confidence)
    state.certainty = PhobosLib.clamp(
        state.certainty + POS_Constants.ENTROPY_OBSERVATION_CERTAINTY_BOOST * confidence,
        0, 1)

    -- Mark observed this tick (silence will reset during tick)
    state._observedThisTick = true

    PhobosLib.debug("POS", _TAG,
        "recordObservation: " .. tostring(zoneId) .. "/" .. tostring(categoryId)
        .. " conf=" .. string.format("%.2f", confidence)
        .. " certainty=" .. string.format("%.2f", state.certainty))
end

--- Record rumour chatter (increases rumourLoad).
---@param zoneId     string  Zone identifier
---@param categoryId string  Category identifier
---@param amount     number  Noise amount to add
function POS_EntropyService.addRumourNoise(zoneId, categoryId, amount)
    local state = POS_EntropyService._getOrCreateState(zoneId, categoryId)
    if not state then return end

    state.rumourLoad = PhobosLib.clamp(
        state.rumourLoad + (amount or 0), 0, 1)
end

---------------------------------------------------------------
-- Query API (read by terminal UI + other services)
---------------------------------------------------------------

--- Get the intelState bundle for a zone/category.
---@param zoneId     string  Zone identifier
---@param categoryId string  Category identifier
---@return table|nil         The intelState bundle, or nil if unavailable
function POS_EntropyService.getIntelState(zoneId, categoryId)
    if not POS_MarketSimulation or not POS_MarketSimulation._getZoneState then
        return nil
    end
    local ok, zoneState = PhobosLib.safecall(
        POS_MarketSimulation._getZoneState, zoneId)
    if not ok or not zoneState or not zoneState.intelState then return nil end
    return zoneState.intelState[categoryId]
end

--- Get the atmospheric label translation key from a certainty value.
---@param certainty number  Certainty value (0-1)
---@return string           Translation key for the atmospheric label
function POS_EntropyService.getAtmosphericLabelKey(certainty)
    local band = POS_EntropyService._resolveBand(certainty or 0)
    return band.key
end

--- Get the full atmospheric band for a certainty value.
---@param certainty number  Certainty value (0-1)
---@return table            Band definition { name, min, key, r, g, b }
function POS_EntropyService.getAtmosphericBand(certainty)
    return POS_EntropyService._resolveBand(certainty or 0)
end

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

--- Resolve atmospheric band from certainty using PhobosLib utility.
---@param certainty number
---@return table Band definition
function POS_EntropyService._resolveBand(certainty)
    return PhobosLib.resolveQualitativeBand(
        certainty, POS_Constants.ENTROPY_ATMOSPHERIC_BANDS)
end

--- Get or create intel state for a zone/category pair.
--- Looks up via POS_MarketSimulation zone state if available.
---@param zoneId     string
---@param categoryId string
---@return table|nil
function POS_EntropyService._getOrCreateState(zoneId, categoryId)
    if not POS_MarketSimulation or not POS_MarketSimulation._getZoneState then
        return nil
    end
    local ok, zoneState = PhobosLib.safecall(
        POS_MarketSimulation._getZoneState, zoneId)
    if not ok or not zoneState then return nil end
    return POS_EntropyService.ensureIntelState(zoneState, categoryId)
end

---------------------------------------------------------------
-- Notifications (via PhobosLib.notifyOrSay)
---------------------------------------------------------------

--- Check throttle for a zone/category notification.
---@param key string Throttle key
---@return boolean True if notification is allowed
function POS_EntropyService._canNotify(key)
    local now = 0
    if getGameTime then
        local gt = getGameTime()
        if gt and gt.getWorldAgeHours then
            now = gt:getWorldAgeHours() * 60
        end
    end
    local last = _notifyThrottle[key] or 0
    if now - last < POS_Constants.ENTROPY_PN_THROTTLE_MIN then
        return false
    end
    _notifyThrottle[key] = now
    return true
end

--- Notify: category going cold (silenceDays threshold reached).
function POS_EntropyService._notifyCold(zoneId, categoryId)
    local key = "cold:" .. tostring(zoneId) .. ":" .. tostring(categoryId)
    if not POS_EntropyService._canNotify(key) then return end

    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    PhobosLib.notifyOrSay(player, {
        title    = PhobosLib.safeGetText("UI_POS_Entropy_PN_ColdTitle"),
        message  = PhobosLib.safeGetText("UI_POS_Entropy_PN_Cold",
            tostring(categoryId), tostring(zoneId)),
        colour   = "warning",
        priority = "normal",
        channel  = POS_Constants.PN_CHANNEL_MARKET,
    })
end

--- Notify: contradiction spike in a zone/category.
function POS_EntropyService._notifyContradiction(zoneId, categoryId)
    local key = "contra:" .. tostring(zoneId) .. ":" .. tostring(categoryId)
    if not POS_EntropyService._canNotify(key) then return end

    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    PhobosLib.notifyOrSay(player, {
        title    = PhobosLib.safeGetText("UI_POS_Entropy_PN_ContradictionTitle"),
        message  = PhobosLib.safeGetText("UI_POS_Entropy_PN_Contradiction",
            tostring(categoryId), tostring(zoneId)),
        colour   = "warning",
        priority = "high",
        channel  = POS_Constants.PN_CHANNEL_INTEL,
    })
end

--- Notify: atmospheric band transition (certainty crossed a threshold).
function POS_EntropyService._notifyTransition(zoneId, categoryId, band, currentDay)
    -- Only notify on downward transitions (getting worse)
    if band.name == "clear" then return end

    local key = "trans:" .. tostring(zoneId) .. ":" .. tostring(categoryId)
    if not POS_EntropyService._canNotify(key) then return end

    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    local label = PhobosLib.safeGetText(band.key)
    PhobosLib.notifyOrSay(player, {
        title    = PhobosLib.safeGetText("UI_POS_Entropy_PN_TransitionTitle"),
        message  = PhobosLib.safeGetText("UI_POS_Entropy_PN_Transition",
            tostring(categoryId), label),
        colour   = "info",
        priority = "low",
        channel  = POS_Constants.PN_CHANNEL_MARKET,
    })
end

--- Notify: data recovered after prolonged silence.
function POS_EntropyService._notifyRecovery(zoneId, categoryId)
    local key = "recov:" .. tostring(zoneId) .. ":" .. tostring(categoryId)
    if not POS_EntropyService._canNotify(key) then return end

    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    PhobosLib.notifyOrSay(player, {
        title    = PhobosLib.safeGetText("UI_POS_Entropy_PN_RecoveryTitle"),
        message  = PhobosLib.safeGetText("UI_POS_Entropy_PN_Recovery",
            tostring(categoryId), tostring(zoneId)),
        colour   = "success",
        priority = "low",
        channel  = POS_Constants.PN_CHANNEL_INTEL,
    })
end
