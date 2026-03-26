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
-- POS_SignalEcologyService.lua
-- Core Signal Ecology v2 service. Computes the five-pillar
-- composite signal value that gates all POSnet operations.
--
-- Pillars:
--   1. Propagation   — weather & season conditions
--   2. Infrastructure — power grid state
--   3. Clarity        — reputation tier contribution
--   4. Saturation     — agent count & market pressure
--   5. Intent         — stub (always 1.0 until Tier V Phase E)
--
-- Formula:
--   raw = propagation * infrastructure * max(0, clarity - noise) * (1 - saturation) * intent
--   composite = clamp(raw, tierFloor, tierCeiling)
--
-- Recalculates once per game hour. Always active (no sandbox toggle).
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_Signal"
require "POS_Events"

POS_SignalEcologyService = {}

local _TAG = "[POS:SignalEcology]"

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

local _cache = nil
local _cacheHour = -1
local _powerCallback = nil  -- injected by client for infrastructure pillar

---------------------------------------------------------------
-- Power callback injection
---------------------------------------------------------------

--- Register a power-state callback from the client side.
--- Called during OnGameStart from client code.
---@param fn function callback(playerSquare) -> boolean (true = has power)
function POS_SignalEcologyService.setPowerCallback(fn)
    _powerCallback = fn
end

---------------------------------------------------------------
-- Season resolution
---------------------------------------------------------------

--- Determine the current season from the game month.
--- Kentucky (Northern Hemisphere): Jun-Aug = summer, Sep-Nov = autumn,
--- Dec-Feb = winter, Mar-May = spring.
---@return string season trigger name
local function _resolveSeason()
    local gt = getGameTime()
    if not gt then return "summer" end
    local month = gt:getMonth()
    -- getMonth() returns 0-based (0=Jan, 11=Dec)
    if month >= 5 and month <= 7 then return "summer" end
    if month >= 8 and month <= 10 then return "autumn" end
    if month <= 1 or month == 11 then return "winter" end
    return "spring"
end

---------------------------------------------------------------
-- Weather trigger resolution
---------------------------------------------------------------

--- Determine the active weather trigger from ClimateManager.
---@return string trigger name for the current weather condition
local function _resolveWeatherTrigger()
    local climate = getClimateManager()
    if not climate then return "clear_skies" end

    local rain = PhobosLib.safecall(function() return climate:getRainIntensity() end) or 0
    local snow = PhobosLib.safecall(function() return climate:getSnowIntensity() end) or 0
    local fog = PhobosLib.safecall(function() return climate:getFogIntensity() end) or 0
    local wind = PhobosLib.safecall(function() return climate:getWindIntensity() end) or 0

    -- Check storm first (high rain + high wind)
    if rain > 0.6 and wind > 0.5 then return "storm" end
    -- Wind storm (high wind, regardless of rain)
    if wind > 0.7 then return "wind_storm" end
    -- Heavy rain
    if rain > 0.5 then return "rain_heavy" end
    -- Snow
    if snow > 0.3 then return "snow" end
    -- Moderate rain
    if rain > 0.2 then return "rain_moderate" end
    -- Strong wind
    if wind > 0.4 then return "wind_strong" end
    -- Fog
    if fog > 0.3 then return "fog" end
    -- Clear
    return "clear_skies"
end

---------------------------------------------------------------
-- Pillar calculators
---------------------------------------------------------------

--- Calculate the propagation pillar value.
--- Reads climate state, applies matching weather modifier and seasonal modifier.
---@return number propagation value 0.0 to 1.0
local function _calculatePropagation()
    local totalPropMod = 0

    -- Weather modifier
    local weatherTrigger = _resolveWeatherTrigger()
    local weatherMods = POS_SignalModifierRegistry.getByTrigger(weatherTrigger)
    for _, mod in ipairs(weatherMods) do
        totalPropMod = totalPropMod + (mod.propagation or 0)
    end

    -- Seasonal modifier
    local seasonTrigger = _resolveSeason()
    local seasonMods = POS_SignalModifierRegistry.getByTrigger(seasonTrigger)
    for _, mod in ipairs(seasonMods) do
        totalPropMod = totalPropMod + (mod.propagation or 0)
    end

    return PhobosLib.clamp(POS_Constants.SIGNAL_PROPAGATION_BASE + totalPropMod, 0, 1)
end

--- Calculate the infrastructure pillar value.
--- Uses power callback if available, otherwise assumes grid on.
---@return number infrastructure value 0.0 to 1.0
local function _calculateInfrastructure()
    local infraMod = 0
    local trigger = "grid_on"

    if _powerCallback then
        local hasPower = PhobosLib.safecall(_powerCallback)
        if hasPower then
            trigger = "grid_on"
        else
            trigger = "grid_off"
        end
    end

    local mods = POS_SignalModifierRegistry.getByTrigger(trigger)
    for _, mod in ipairs(mods) do
        infraMod = infraMod + (mod.infrastructure or 0)
    end

    return PhobosLib.clamp(POS_Constants.SIGNAL_INFRASTRUCTURE_BASE + infraMod, 0, 1)
end

--- Calculate the clarity pillar value from reputation tier.
---@param tier number reputation tier (1-5)
---@return number clarity value 0.0 to 1.0
local function _calculateClarity(tier)
    return POS_Constants.SIGNAL_CLARITY_BY_TIER[tier] or POS_Constants.SIGNAL_CLARITY_BY_TIER[1]
end

--- Calculate the saturation pillar value.
--- Combines active agent count with market state modifier.
---@return number saturation value 0.0 to 1.0
local function _calculateSaturation()
    -- Agent contribution
    local agentCount = 0
    if POS_FreeAgentService and POS_FreeAgentService.getActive then
        local agents = PhobosLib.safecall(POS_FreeAgentService.getActive)
        if agents then
            agentCount = #agents
        end
    end
    local agentSat = math.min(
        agentCount * POS_Constants.SIGNAL_AGENT_SAT_PER_AGENT,
        POS_Constants.SIGNAL_AGENT_SAT_CAP
    )

    -- Market state modifier
    local marketSat = 0
    local seasonTrigger = _resolveSeason()
    local seasonMods = POS_SignalModifierRegistry.getByTrigger(seasonTrigger)
    for _, mod in ipairs(seasonMods) do
        marketSat = marketSat + (mod.saturation or 0)
    end

    -- Also check all saturation-pillar modifiers that might be active
    -- (market modifiers are triggered externally, so we check all enabled ones
    -- with pillar == "saturation" and trust the trigger system)

    return PhobosLib.clamp(POS_Constants.SIGNAL_SATURATION_BASE + agentSat + marketSat, 0, 1)
end

--- Calculate total noise from all active weather and market modifiers.
---@return number total noise (unbounded, subtracted from clarity)
local function _calculateNoise()
    local totalNoise = 0

    -- Weather noise
    local weatherTrigger = _resolveWeatherTrigger()
    local weatherMods = POS_SignalModifierRegistry.getByTrigger(weatherTrigger)
    for _, mod in ipairs(weatherMods) do
        totalNoise = totalNoise + (mod.noise or 0)
    end

    -- Market noise (check all saturation-pillar modifiers)
    local allMods = POS_SignalModifierRegistry.getByPillar("saturation")
    for _, mod in ipairs(allMods) do
        totalNoise = totalNoise + (mod.noise or 0)
    end

    return totalNoise
end

---------------------------------------------------------------
-- Qualitative state resolution
---------------------------------------------------------------

--- Resolve the qualitative signal state from a composite value.
---@param composite number 0.0 to 1.0
---@return string state name
local function _resolveQualitativeState(composite)
    if composite >= POS_Constants.SIGNAL_STATE_LOCKED_MIN then return "locked" end
    if composite >= POS_Constants.SIGNAL_STATE_CLEAR_MIN then return "clear" end
    if composite >= POS_Constants.SIGNAL_STATE_FADED_MIN then return "faded" end
    if composite >= POS_Constants.SIGNAL_STATE_FRAGMENTED_MIN then return "fragmented" end
    if composite >= POS_Constants.SIGNAL_STATE_GHOSTED_MIN then return "ghosted" end
    return "lost"
end

---------------------------------------------------------------
-- Core recalculation
---------------------------------------------------------------

--- Perform a full signal ecology recalculation.
--- Updates the internal cache and fires state transition events.
---@return table cache the updated signal state
local function _recalculate()
    local propagation = _calculatePropagation()
    local infrastructure = _calculateInfrastructure()
    local tier = 2  -- TODO: get from POS_PlayerState when reputation tiers exist
    local clarity = _calculateClarity(tier)
    local saturation = _calculateSaturation()
    local noise = _calculateNoise()
    local intent = POS_Constants.SIGNAL_INTENT_STUB

    local raw = propagation * infrastructure * math.max(0, clarity - noise) * (1 - saturation) * intent

    -- Tier clamping
    local baseline = POS_Constants.SIGNAL_TIER_BASELINES[tier] or POS_Constants.SIGNAL_TIER_BASELINES[2]
    local composite = PhobosLib.clamp(raw, baseline.floor, baseline.ceiling)

    local oldState = _cache and _cache.qualitativeState or nil
    local qualState = _resolveQualitativeState(composite)

    _cache = {
        composite = composite,
        qualitativeState = qualState,
        tier = tier,
        pillars = {
            propagation = propagation,
            infrastructure = infrastructure,
            clarity = clarity,
            saturation = saturation,
            intent = intent,
        },
        noise = noise,
        lastCalculatedHour = _cacheHour,
    }

    -- Fire event on state transition
    if oldState and qualState ~= oldState then
        if POS_Events and POS_Events.OnSignalStateChanged then
            POS_Events.OnSignalStateChanged:trigger({
                oldState = oldState,
                newState = qualState,
                composite = composite,
            })
        end
        PhobosLib.debug("POS", _TAG, "state changed: " .. tostring(oldState) .. " -> " .. qualState
            .. " (composite: " .. string.format("%.2f", composite) .. ")")
    end

    return _cache
end

---------------------------------------------------------------
-- Cache freshness
---------------------------------------------------------------

--- Ensure the cache is fresh (recalculate if stale).
---@return table cache the current signal state
local function _ensureFresh()
    local gt = getGameTime()
    local currentHour = gt and math.floor(gt:getWorldAgeHours()) or 0
    if not _cache or currentHour ~= _cacheHour then
        _cacheHour = currentHour
        _recalculate()
    end
    return _cache or {
        composite = POS_Constants.SIGNAL_FALLBACK_COMPOSITE,
        qualitativeState = "faded",
        pillars = {
            propagation = POS_Constants.SIGNAL_PROPAGATION_BASE,
            infrastructure = POS_Constants.SIGNAL_INFRASTRUCTURE_BASE,
            clarity = POS_Constants.SIGNAL_CLARITY_BY_TIER[2],
            saturation = POS_Constants.SIGNAL_SATURATION_BASE,
            intent = POS_Constants.SIGNAL_INTENT_STUB,
        },
        noise = 0,
        tier = 2,
    }
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Get the full signal ecology state (composite, pillars, qualitative state, etc.).
---@return table signalState { composite, qualitativeState, tier, pillars, noise, lastCalculatedHour }
function POS_SignalEcologyService.getSignalState()
    return _ensureFresh()
end

--- Get the composite signal value (0.0 to 1.0).
---@return number composite
function POS_SignalEcologyService.getComposite()
    local state = _ensureFresh()
    return state.composite
end

--- Get the qualitative signal state name.
---@return string state one of: "locked", "clear", "faded", "fragmented", "ghosted", "lost"
function POS_SignalEcologyService.getQualitativeState()
    local state = _ensureFresh()
    return state.qualitativeState
end

--- Force cache invalidation. Next call to any getter will recalculate.
function POS_SignalEcologyService.invalidate()
    _cacheHour = -1
end

---------------------------------------------------------------
-- Event hooks — initialisation
---------------------------------------------------------------

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        PhobosLib.debug("POS", _TAG, "Signal Ecology initialised (core tenet — always active)")
        _recalculate()
    end)
end

---------------------------------------------------------------
-- Event hooks — invalidation subscriptions
---------------------------------------------------------------

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        -- Subscribe to market events for saturation invalidation
        if POS_Events and POS_Events.OnMarketEvent then
            POS_Events.OnMarketEvent:addListener(function()
                POS_SignalEcologyService.invalidate()
            end)
        end

        -- Subscribe to free agent state changes for saturation invalidation
        if POS_Events and POS_Events.OnFreeAgentStateChanged then
            POS_Events.OnFreeAgentStateChanged:addListener(function()
                POS_SignalEcologyService.invalidate()
            end)
        end

        -- Subscribe to stock tick for periodic invalidation
        if POS_Events and POS_Events.OnStockTickClosed then
            POS_Events.OnStockTickClosed:addListener(function()
                POS_SignalEcologyService.invalidate()
            end)
        end
    end)
end
