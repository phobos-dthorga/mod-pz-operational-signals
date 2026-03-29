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

    -- Phase 2: Fetch environmental modifiers from Signal Ecology
    local weatherDecayMult = 1.0
    local weatherNoiseMult = 0.0
    local weatherTrustDrift = 0.0
    local isBlackout = false
    if POS_SignalEcologyService and POS_SignalEcologyService.getSignalState then
        local ok_sig, sigState = PhobosLib.safecall(
            POS_SignalEcologyService.getSignalState)
        if ok_sig and sigState and sigState.pillars then
            -- Weather: propagation pillar (1.0 = clear, 0.3 = storm)
            local prop = sigState.pillars.propagation or 1.0
            weatherDecayMult = 1.0
                + (1.0 - prop) * POS_Constants.ENTROPY_WEATHER_DECAY_FACTOR
            weatherNoiseMult = (1.0 - prop)
                * POS_Constants.ENTROPY_WEATHER_NOISE_FACTOR
            if prop >= POS_Constants.ENTROPY_WEATHER_GOOD_THRESHOLD then
                weatherTrustDrift = POS_Constants.ENTROPY_WEATHER_TRUST_DRIFT_GOOD
            elseif prop < POS_Constants.ENTROPY_WEATHER_BAD_THRESHOLD then
                weatherTrustDrift = POS_Constants.ENTROPY_WEATHER_TRUST_DRIFT_BAD
            end
            -- Blackout: infrastructure pillar
            isBlackout = (sigState.pillars.infrastructure or 1.0)
                < POS_Constants.ENTROPY_BLACKOUT_INFRA_THRESHOLD
        end
    end

    -- Phase 3: Seasonal baseline modifiers (schema-driven via SignalModifierRegistry)
    local seasonDecayMult = 1.0
    local seasonNoiseMult = 1.0
    local seasonTrustDrift = 0.0
    if POS_SignalEcologyService and POS_SignalEcologyService._resolveSeason then
        local ok_season, seasonTrigger = PhobosLib.safecall(
            POS_SignalEcologyService._resolveSeason)
        if ok_season and seasonTrigger and POS_SignalModifierRegistry then
            local seasonMods = POS_SignalModifierRegistry.getByTrigger(seasonTrigger)
            if seasonMods and #seasonMods > 0 then
                local sm = seasonMods[1]
                seasonDecayMult  = sm.entropyDecayMult or 1.0
                seasonNoiseMult  = sm.entropyNoiseMult or 1.0
                seasonTrustDrift = sm.entropyTrustDrift or 0.0
            end
        end
    end

    -- Propagation value for shadow detection (reuse from weather block)
    local propagation = 1.0
    if POS_SignalEcologyService and POS_SignalEcologyService.getSignalState then
        local ok2, ss = PhobosLib.safecall(POS_SignalEcologyService.getSignalState)
        if ok2 and ss and ss.pillars then propagation = ss.pillars.propagation or 1.0 end
    end

    for categoryId, state in pairs(zoneState.intelState) do
        -- Ensure shadowState field exists (Phase 3 addition)
        state.shadowState = state.shadowState or 0.0

        -- Freshness decay (multiplicative, scaled by weather × season)
        state.freshness = PhobosLib.decayMultiplicative(
            state.freshness,
            POS_Constants.ENTROPY_FRESHNESS_DECAY * weatherDecayMult * seasonDecayMult, 0)

        -- Silence tracking
        if state._observedThisTick then
            if state.silenceDays > POS_Constants.ENTROPY_SILENCE_STALE_DAYS then
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

        -- Phase 2+3: Weather + seasonal rumour injection + trust drift
        local combinedNoise = weatherNoiseMult * seasonNoiseMult
        local combinedTrust = weatherTrustDrift + seasonTrustDrift
        state.rumourLoad = PhobosLib.clamp(
            state.rumourLoad + combinedNoise, 0, 1)
        state.trust = PhobosLib.clamp(
            state.trust + combinedTrust,
            POS_Constants.ENTROPY_TRUST_MIN,
            POS_Constants.ENTROPY_TRUST_MAX)

        -- Phase 2: Blackout penalties
        if isBlackout then
            state.certainty = PhobosLib.clamp(
                state.certainty - POS_Constants.ENTROPY_BLACKOUT_CERTAINTY_PENALTY,
                0, 1)
            state.rumourLoad = PhobosLib.clamp(
                state.rumourLoad + POS_Constants.ENTROPY_BLACKOUT_RUMOUR_BOOST,
                0, 1)
            state.trust = PhobosLib.clamp(
                state.trust + POS_Constants.ENTROPY_BLACKOUT_TRUST_DRIFT,
                POS_Constants.ENTROPY_TRUST_MIN,
                POS_Constants.ENTROPY_TRUST_MAX)
        end

        -- Phase 2: Concealment natural decay
        state.concealment = PhobosLib.decayMultiplicative(
            state.concealment,
            POS_Constants.ENTROPY_CONCEALMENT_DECAY, 0)

        -- Phase 3: Information shadow zones
        if propagation < POS_Constants.ENTROPY_SHADOW_PROPAGATION_MIN and isBlackout then
            state.shadowState = math.min(
                state.shadowState + POS_Constants.ENTROPY_SHADOW_ACCUMULATION, 1.0)
        else
            state.shadowState = PhobosLib.decayMultiplicative(
                state.shadowState, POS_Constants.ENTROPY_SHADOW_DECAY, 0)
        end

        -- Phase 3: Speculative rumour spawn when certainty is low
        if state.certainty < POS_Constants.ENTROPY_SPECULATION_THRESHOLD then
            local desperation = POS_EntropyService._getDesperationRaw(state, zoneId, categoryId)
            local spawnChance = (1.0 - state.certainty)
                * POS_Constants.ENTROPY_SPECULATION_SPAWN_MULT
                * (1.0 + desperation * POS_Constants.ENTROPY_DESPERATION_SPAWN_MULT)
            if ZombRand and ZombRand(100) < math.floor(spawnChance * 100) then
                if POS_RumourGenerator and POS_RumourGenerator.generateSpeculativeRumour then
                    PhobosLib.safecall(POS_RumourGenerator.generateSpeculativeRumour,
                        zoneId, categoryId, state.certainty, currentDay)
                end
            end
        end

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

    -- Phase 2: Blackout notification (once per zone per blackout onset)
    if isBlackout then
        POS_EntropyService._notifyBlackout(zoneId)
    end

    PhobosLib.debug("POS", _TAG, "tickZoneEntropy: " .. tostring(zoneId)
        .. " weather=" .. string.format("%.2f", weatherDecayMult)
        .. " blackout=" .. tostring(isBlackout))
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

    -- Broadcast Influence: perceived pressure layer (Phase A)
    local perceivedPressure = 0
    if POS_BroadcastInfluenceService
            and POS_BroadcastInfluenceService.getPerceivedPressure then
        local okP, pp = PhobosLib.safecall(
            POS_BroadcastInfluenceService.getPerceivedPressure, zoneId, categoryId)
        if okP and pp then perceivedPressure = pp end
    end

    local certaintyMod = PhobosLib.clamp(state.certainty, 0.1, 1.0)
    local trustMod     = PhobosLib.clamp(state.trust, 0.1, 1.0)
    local noiseMod     = 1.0 - state.rumourLoad * POS_Constants.ENTROPY_NOISE_WEIGHT
    -- Phase 3: shadow attenuation
    local shadowMod    = 1.0 - (state.shadowState or 0)
        * POS_Constants.ENTROPY_SHADOW_PRESSURE_ATTENUATION

    return (rawPressure + perceivedPressure) * certaintyMod * trustMod
        * math.max(0.1, noiseMod) * math.max(0.1, shadowMod)
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

    -- Phase 3: Desperation amplifies contradiction damage
    local desperation = POS_EntropyService._getDesperationRaw(state, zoneId, categoryId)
    local amplifier = 1.0 + desperation * POS_Constants.ENTROPY_DESPERATION_DAMAGE_MULT
    local amplifiedDamage = (damage or 0) * amplifier

    state.contradiction = PhobosLib.clamp(
        state.contradiction + amplifiedDamage, 0, 1)
    -- Contradiction also reduces certainty
    state.certainty = PhobosLib.clamp(
        state.certainty - amplifiedDamage * 0.5, 0, 1)

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

--- Update concealment level from wholesaler posture changes.
--- Sandbox-gated: does nothing when POS.EnableConcealmentEffects is OFF.
---@param zoneId     string  Zone identifier
---@param categoryId string  Category identifier
---@param amount     number  Concealment damage amount (e.g. 0.15 for strong)
function POS_EntropyService.updateConcealment(zoneId, categoryId, amount)
    -- Gated behind sandbox option (default OFF — opt-in feature)
    if POS_Sandbox and POS_Sandbox.isEnableConcealmentEffects
            and not POS_Sandbox.isEnableConcealmentEffects() then
        return
    end
    local state = POS_EntropyService._getOrCreateState(zoneId, categoryId)
    if not state then return end

    state.concealment = PhobosLib.clamp(
        state.concealment + (amount or 0), 0, 1)
    -- Concealment also damages certainty
    state.certainty = PhobosLib.clamp(
        state.certainty - (amount or 0) * POS_Constants.ENTROPY_CONCEALMENT_CERTAINTY_MULT,
        0, 1)

    PhobosLib.debug("POS", _TAG,
        "updateConcealment: " .. tostring(zoneId) .. "/" .. tostring(categoryId)
        .. " amount=" .. tostring(amount)
        .. " concealment=" .. string.format("%.2f", state.concealment))

    -- Notify if SIGINT-gated detection threshold crossed
    if state.concealment >= POS_Constants.ENTROPY_CONCEALMENT_LABEL_THRESHOLD then
        POS_EntropyService._notifyConcealment(zoneId, categoryId)
    end
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

    -- Tutorial: first entropy warning (any downward band transition)
    if POS_TutorialService and POS_TutorialService.tryAward then
        local tPlayer = getSpecificPlayer and getSpecificPlayer(0)
        if tPlayer then
            POS_TutorialService.tryAward(tPlayer, POS_Constants.TUTORIAL_FIRST_ENTROPY_WARNING)
        end
    end

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

--- Notify: blackout entropy spike (per zone, throttled).
function POS_EntropyService._notifyBlackout(zoneId)
    local key = "blackout:" .. tostring(zoneId)
    if not POS_EntropyService._canNotify(key) then return end

    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    PhobosLib.notifyOrSay(player, {
        title    = PhobosLib.safeGetText("UI_POS_Entropy_PN_BlackoutTitle"),
        message  = PhobosLib.safeGetText("UI_POS_Entropy_PN_Blackout",
            tostring(zoneId)),
        colour   = "error",
        priority = "high",
        channel  = POS_Constants.PN_CHANNEL_MARKET,
    })
end

--- Notify: concealment detected (SIGINT-gated, per zone/category, throttled).
function POS_EntropyService._notifyConcealment(zoneId, categoryId)
    -- SIGINT gate: only notify if player has sufficient skill
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    local sigintLevel = 0
    if POS_SIGINTSkill and POS_SIGINTSkill.getLevel then
        sigintLevel = POS_SIGINTSkill.getLevel(player) or 0
    end
    if sigintLevel < POS_Constants.ENTROPY_CONCEALMENT_SIGINT_GATE then return end

    local key = "conceal:" .. tostring(zoneId) .. ":" .. tostring(categoryId)
    if not POS_EntropyService._canNotify(key) then return end

    PhobosLib.notifyOrSay(player, {
        title    = PhobosLib.safeGetText("UI_POS_Entropy_PN_ConcealmentTitle"),
        message  = PhobosLib.safeGetText("UI_POS_Entropy_PN_Concealment",
            tostring(categoryId), tostring(zoneId)),
        colour   = "warning",
        priority = "normal",
        channel  = POS_Constants.PN_CHANNEL_INTEL,
    })
end

--- Notify: information shadow detected (per zone, throttled).
function POS_EntropyService._notifyShadow(zoneId, categoryId)
    local key = "shadow:" .. tostring(zoneId) .. ":" .. tostring(categoryId)
    if not POS_EntropyService._canNotify(key) then return end

    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    PhobosLib.notifyOrSay(player, {
        title    = PhobosLib.safeGetText("UI_POS_Entropy_PN_ShadowTitle"),
        message  = PhobosLib.safeGetText("UI_POS_Entropy_PN_Shadow",
            tostring(categoryId), tostring(zoneId)),
        colour   = "error",
        priority = "high",
        channel  = POS_Constants.PN_CHANNEL_MARKET,
    })
end

---------------------------------------------------------------
-- Phase 3: Desperation index
---------------------------------------------------------------

--- Compute raw desperation from an intelState + zone pressure.
--- Used internally; for public access use getDesperationIndex().
---@param state      table  intelState bundle
---@param zoneId     string
---@param categoryId string
---@return number    Desperation index (0-1)
function POS_EntropyService._getDesperationRaw(state, zoneId, categoryId)
    if not state then return 0 end

    local pressure = 0
    if POS_MarketSimulation and POS_MarketSimulation.getZonePressure then
        local ok_p, p = PhobosLib.safecall(
            POS_MarketSimulation.getZonePressure, zoneId, categoryId)
        if ok_p and p then pressure = math.abs(p) end
    end

    local pressureFactor      = PhobosLib.clamp(pressure, 0, 1)
    local certaintyFactor     = 1.0 - (state.certainty or 0.5)
    local trustFactor         = 1.0 - (state.trust or 0.5)
    local contradictionFactor = state.contradiction or 0

    return PhobosLib.clamp(
        pressureFactor      * POS_Constants.ENTROPY_DESPERATION_PRESSURE_WEIGHT
        + certaintyFactor   * POS_Constants.ENTROPY_DESPERATION_CERTAINTY_WEIGHT
        + trustFactor       * POS_Constants.ENTROPY_DESPERATION_TRUST_WEIGHT
        + contradictionFactor * POS_Constants.ENTROPY_DESPERATION_CONTRADICTION_WEIGHT,
        0, 1)
end

--- Get the desperation index for a zone/category (public API).
---@param zoneId     string
---@param categoryId string
---@return number    Desperation index (0-1)
function POS_EntropyService.getDesperationIndex(zoneId, categoryId)
    local state = POS_EntropyService.getIntelState(zoneId, categoryId)
    if not state then return 0 end
    return POS_EntropyService._getDesperationRaw(state, zoneId, categoryId)
end

---------------------------------------------------------------
-- Phase 3: Trust erosion from broadcast prediction validation
---------------------------------------------------------------

--- Validate broadcast accuracy when a new observation arrives.
--- Compares recent broadcast fragment directions with the actual
--- observation direction, adjusting trust accordingly.
---@param zoneId     string
---@param categoryId string
---@param obsDirection string "up" or "down" from the fresh observation
---@param currentDay number
function POS_EntropyService.validateBroadcastAccuracy(zoneId, categoryId, obsDirection, currentDay)
    if not obsDirection or not zoneId or not categoryId then return end

    local state = POS_EntropyService._getOrCreateState(zoneId, categoryId)
    if not state then return end

    -- Look for recent broadcast fragments in player ModData
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    local okMd, md = PhobosLib.safecall(function()
        return player:getModData()
    end)
    if not okMd or not md then return end

    local posnet = md.POSNET
    if not posnet or not posnet.SignalFragments then return end

    local lookback = POS_Constants.ENTROPY_BROADCAST_LOOKBACK_DAYS
    local found = false
    for _, frag in pairs(posnet.SignalFragments) do
        if frag and frag.categoryId == categoryId
                and frag.zoneId == zoneId
                and frag.receivedDay
                and (currentDay - frag.receivedDay) <= lookback then
            found = true
            if frag.direction == obsDirection then
                -- Broadcast was correct
                state.trust = PhobosLib.clamp(
                    state.trust + POS_Constants.ENTROPY_TRUST_ACCURACY_GAIN,
                    POS_Constants.ENTROPY_TRUST_MIN,
                    POS_Constants.ENTROPY_TRUST_MAX)
            else
                -- Broadcast was wrong
                state.trust = PhobosLib.clamp(
                    state.trust - POS_Constants.ENTROPY_TRUST_MISINFO_LOSS,
                    POS_Constants.ENTROPY_TRUST_MIN,
                    POS_Constants.ENTROPY_TRUST_MAX)
            end
            break  -- validate against first matching fragment
        end
    end

    if found then
        PhobosLib.debug("POS", _TAG,
            "validateBroadcastAccuracy: " .. tostring(zoneId) .. "/" .. tostring(categoryId)
            .. " obs=" .. tostring(obsDirection)
            .. " trust=" .. string.format("%.2f", state.trust))
    end
end
