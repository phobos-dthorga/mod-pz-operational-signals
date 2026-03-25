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
-- POS_WBN_ForecastService.lua
-- Forward-looking forecast candidate generation for the WBN.
-- Produces weather, economy, and power grid forecasts that
-- complement the real-time candidates from HarvestService.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_WBN"

local _TAG = "WBN:Forecast"
POS_WBN_ForecastService = {}

-- Internal forecast candidate queue
local _forecastQueue = {}
-- Cadence counter (only generate every N economy ticks)
local _tickCounter = 0
-- Sequence counter for unique IDs
local _forecastSeq = 0

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

--- Pick a random forecast horizon between HORIZON_MIN and HORIZON_MAX (inclusive).
--- @return number Days ahead for the forecast
local function _pickHorizon()
    local min = POS_Constants.WBN_FORECAST_HORIZON_MIN
    local max = POS_Constants.WBN_FORECAST_HORIZON_MAX
    return min + ZombRand(max - min + 1)
end

--- Generate a unique forecast candidate ID.
--- @param domain string The forecast domain (e.g. "weather", "economy", "power")
--- @param horizonDays number Days ahead
--- @return string A unique candidate identifier
local function _forecastCandidateId(domain, horizonDays)
    _forecastSeq = _forecastSeq + 1
    return "wbn_forecast_" .. domain .. "_" .. tostring(horizonDays) .. "_" .. tostring(_forecastSeq)
end

---------------------------------------------------------------
-- Weather forecasts
---------------------------------------------------------------

--- Generate weather forecast candidates using the ClimateForecaster API.
--- Classifies DayForecast conditions and pushes a dampened-severity candidate.
--- @param currentDay number The current game day
--- @param worldHours number Total world-age hours
local function _generateWeatherForecasts(currentDay, worldHours)
    local climate = getClimateManager and getClimateManager()
    if not climate then return end

    local forecaster = climate.getClimateForecaster and climate:getClimateForecaster()
    if not forecaster then return end

    local horizonDays = _pickHorizon()

    local ok, forecast = PhobosLib.safecall(forecaster.getForecast, forecaster, horizonDays)
    if not ok or not forecast then return end

    -- Classify the DayForecast into a weather key and base severity
    local weatherKey = nil
    local severity = POS_Constants.WBN_AMBIENT_SEVERITY

    if forecast.isHasTropicalStorm and forecast:isHasTropicalStorm() then
        weatherKey = "forecast_storm"
        severity = 0.95
    elseif forecast.isHasStorm and forecast:isHasStorm() then
        weatherKey = "forecast_storm"
        severity = 0.85
    elseif forecast.isHasBlizzard and forecast:isHasBlizzard() then
        weatherKey = "forecast_blizzard"
        severity = 0.85
    elseif forecast.isHasHeavyRain and forecast:isHasHeavyRain() then
        weatherKey = "forecast_rain_heavy"
        severity = 0.70
    elseif forecast.isChanceOnSnow and forecast:isChanceOnSnow() then
        weatherKey = "forecast_snow"
        severity = 0.55
    elseif forecast.isHasFog and forecast:isHasFog() then
        weatherKey = "forecast_fog"
        severity = 0.50
    else
        -- Check temperature extremes
        local tempApi = forecast.getTemperature and forecast:getTemperature()
        local windApi = forecast.getWindPower and forecast:getWindPower()

        local tempMin = tempApi and tempApi.getTotalMin and tempApi:getTotalMin() or 10
        local tempMax = tempApi and tempApi.getTotalMax and tempApi:getTotalMax() or 20
        local windMax = windApi and windApi.getTotalMax and windApi:getTotalMax() or 0

        if tempMin <= POS_Constants.WBN_WEATHER_COLD_EXTREME_C then
            weatherKey = "forecast_cold_extreme"
            severity = 0.65
        elseif tempMax >= POS_Constants.WBN_WEATHER_HEAT_EXTREME_C then
            weatherKey = "forecast_heat_extreme"
            severity = 0.65
        elseif windMax >= POS_Constants.WBN_WEATHER_WIND_STRONG_KPH then
            weatherKey = "forecast_wind_strong"
            severity = 0.50
        else
            -- Benign forecast — clear or overcast
            weatherKey = "forecast_clear"
            severity = 0.15
        end
    end

    -- Build extraData from forecast temperature and wind APIs
    local extraData = {}
    local tempApi = forecast.getTemperature and forecast:getTemperature()
    local windApi = forecast.getWindPower and forecast:getWindPower()
    if tempApi then
        if tempApi.getTotalMin then extraData.tempMin = PhobosLib.round(tempApi:getTotalMin(), 0) end
        if tempApi.getTotalMax then extraData.tempMax = PhobosLib.round(tempApi:getTotalMax(), 0) end
    end
    if windApi and windApi.getTotalMax then
        extraData.windMax = PhobosLib.round(windApi:getTotalMax(), 0)
    end

    local candidate = {
        id                  = _forecastCandidateId(POS_Constants.WBN_DOMAIN_WEATHER, horizonDays),
        domain              = POS_Constants.WBN_DOMAIN_WEATHER,
        eventType           = POS_Constants.WBN_EVENT_WEATHER_REPORT,
        isForecast          = true,
        forecastHorizonDays = horizonDays,
        forecastConfidence  = POS_Constants.WBN_FORECAST_CONF_WEATHER,
        severity            = severity * POS_Constants.WBN_FORECAST_SEVERITY_DAMPEN,
        confidence          = POS_Constants.WBN_FORECAST_CONF_WEATHER,
        freshness           = 1.0,
        sourceType          = "climate_forecaster",
        publicEligible      = true,
        expiresAt           = worldHours + POS_Constants.WBN_CANDIDATE_EXPIRY_HOURS,
        day                 = currentDay,
        weatherKey          = weatherKey,
        extraData           = extraData,
    }
    _forecastQueue[#_forecastQueue + 1] = candidate

    PhobosLib.debug("POS", _TAG,
        "_generateWeatherForecasts: " .. weatherKey .. " horizon=" .. tostring(horizonDays)
        .. " severity=" .. tostring(candidate.severity))
end

---------------------------------------------------------------
-- Economy forecasts
---------------------------------------------------------------

--- Generate economy forecast candidates by simulating future drift.
--- Picks a random zone/category pair and projects price movement.
--- @param currentDay number The current game day
--- @param worldHours number Total world-age hours
local function _generateEconomyForecasts(currentDay, worldHours)
    local zones = POS_Constants.MARKET_ZONES
    local categoryMultipliers = POS_Constants.CATEGORY_PRICE_MULTIPLIERS or {}
    if not zones then return end

    -- Build pool of all zone x category pairs
    local pool = {}
    for _, zoneId in ipairs(zones) do
        for catId, _ in pairs(categoryMultipliers) do
            pool[#pool + 1] = { zoneId = zoneId, catId = catId }
        end
    end
    if #pool == 0 then return end

    -- Pick one random pair
    local pick = pool[ZombRand(#pool) + 1]
    local zoneId = pick.zoneId
    local catId = pick.catId
    local horizonDays = _pickHorizon()

    -- Simulate future drift
    local drift = 0
    if POS_PriceEngine and POS_PriceEngine.getDayDrift then
        local ok, d = PhobosLib.safecall(POS_PriceEngine.getDayDrift, zoneId, catId, currentDay + horizonDays)
        if ok and type(d) == "number" then drift = d end
    else
        -- Fallback: estimate from current zone pressure
        local pressure = 0
        if POS_MarketSimulation and POS_MarketSimulation.getZonePressure then
            local ok, p = PhobosLib.safecall(POS_MarketSimulation.getZonePressure, zoneId, catId)
            if ok and type(p) == "number" then pressure = p end
        end
        drift = pressure * (0.5 + ZombRand(100) / 100.0)
    end

    local percentChange = math.floor(math.abs(drift) * POS_Constants.WBN_PRESSURE_TO_PERCENT + 0.5)

    -- Skip insignificant forecasts
    if percentChange < POS_Constants.WBN_THRESHOLD_LIGHT then return end

    local direction = POS_Constants.WBN_DIR_STABLE
    if drift > 0 then direction = POS_Constants.WBN_DIR_UP end
    if drift < 0 then direction = POS_Constants.WBN_DIR_DOWN end

    local causeTag = (direction == POS_Constants.WBN_DIR_DOWN)
        and POS_Constants.WBN_CAUSE_RECOVERY
        or POS_Constants.WBN_CAUSE_SCARCITY

    -- Check convoy ETAs in target zone
    local convoyNote = nil
    if POS_MarketSimulation and POS_MarketSimulation.getWholesalers then
        local ok, wholesalers = PhobosLib.safecall(POS_MarketSimulation.getWholesalers)
        if ok and wholesalers then
            for _, w in pairs(wholesalers) do
                if w.zoneId == zoneId and w.convoyState and w.convoyState.inTransit then
                    local eta = w.convoyState.etaDay or 0
                    if eta > currentDay and eta <= currentDay + horizonDays then
                        convoyNote = { zoneId = zoneId, etaDays = eta - currentDay }
                        break
                    end
                end
            end
        end
    end

    local severity = 0.3
    if percentChange >= POS_Constants.WBN_THRESHOLD_HEADLINE then severity = 1.0
    elseif percentChange >= POS_Constants.WBN_THRESHOLD_STRONG then severity = 0.8
    elseif percentChange >= POS_Constants.WBN_THRESHOLD_NORMAL then severity = 0.6
    end

    local candidate = {
        id                  = _forecastCandidateId(POS_Constants.WBN_DOMAIN_ECONOMY, horizonDays),
        domain              = POS_Constants.WBN_DOMAIN_ECONOMY,
        eventType           = POS_Constants.WBN_EVENT_SCARCITY_ALERT,
        isForecast          = true,
        forecastHorizonDays = horizonDays,
        forecastConfidence  = POS_Constants.WBN_FORECAST_CONF_ECONOMY,
        severity            = severity * POS_Constants.WBN_FORECAST_SEVERITY_DAMPEN,
        confidence          = POS_Constants.WBN_FORECAST_CONF_ECONOMY,
        freshness           = 1.0,
        sourceType          = "economy_forecast",
        publicEligible      = true,
        expiresAt           = worldHours + POS_Constants.WBN_CANDIDATE_EXPIRY_HOURS,
        day                 = currentDay,
        zoneId              = zoneId,
        categoryId          = catId,
        percentChange       = percentChange,
        direction           = direction,
        causeTag            = causeTag,
        convoyNote          = convoyNote,
    }
    _forecastQueue[#_forecastQueue + 1] = candidate

    PhobosLib.debug("POS", _TAG,
        "_generateEconomyForecasts: " .. zoneId .. "/" .. catId
        .. " drift=" .. tostring(percentChange) .. "% dir=" .. direction
        .. " horizon=" .. tostring(horizonDays))
end

---------------------------------------------------------------
-- Power grid forecasts
---------------------------------------------------------------

--- Generate power grid forecast candidates based on sandbox shutoff schedule.
--- Warns players as the grid shutoff date approaches.
--- @param currentDay number The current game day
--- @param worldHours number Total world-age hours
local function _generatePowerForecasts(currentDay, worldHours)
    -- Only forecast when grid power is currently ON
    local world = getWorld and getWorld()
    if not world or not world.isHydroPowerOn or not world:isHydroPowerOn() then return end

    -- Check sandbox shutoff modifier
    local shutModifier = SandboxVars and SandboxVars.ElecShutModifier or 0
    if shutModifier <= -1 then return end  -- power never shuts off

    local daysUntilShutoff = shutModifier - currentDay
    if daysUntilShutoff < 1 or daysUntilShutoff > POS_Constants.WBN_FORECAST_POWER_WARN_DAYS then
        return
    end

    -- Severity ramps as shutoff approaches
    local severity = PhobosLib.lerp(0.5, 0.95,
        1.0 - (daysUntilShutoff / POS_Constants.WBN_FORECAST_POWER_WARN_DAYS))

    local candidate = {
        id                  = _forecastCandidateId(POS_Constants.WBN_DOMAIN_POWER, daysUntilShutoff),
        domain              = POS_Constants.WBN_DOMAIN_POWER,
        eventType           = POS_Constants.WBN_EVENT_POWER_STATUS,
        isForecast          = true,
        forecastHorizonDays = daysUntilShutoff,
        forecastConfidence  = POS_Constants.WBN_FORECAST_CONF_POWER,
        severity            = severity * POS_Constants.WBN_FORECAST_SEVERITY_DAMPEN,
        confidence          = POS_Constants.WBN_FORECAST_CONF_POWER,
        freshness           = 1.0,
        sourceType          = "power_forecast",
        publicEligible      = true,
        expiresAt           = worldHours + POS_Constants.WBN_CANDIDATE_EXPIRY_HOURS,
        day                 = currentDay,
        powerTransition     = "forecast_failure",
    }
    _forecastQueue[#_forecastQueue + 1] = candidate

    PhobosLib.debug("POS", _TAG,
        "_generatePowerForecasts: daysUntilShutoff=" .. tostring(daysUntilShutoff)
        .. " severity=" .. tostring(candidate.severity))
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Main entry point called from HarvestService on each economy tick.
--- Increments cadence counter and only generates every WBN_FORECAST_CADENCE_TICKS.
--- Calls all three forecast generators. Caps total output at WBN_FORECAST_MAX_PER_TICK.
--- @param currentDay number The current game day
--- @param worldHours number Total world-age hours
function POS_WBN_ForecastService.generateForecasts(currentDay, worldHours)
    _tickCounter = _tickCounter + 1
    if _tickCounter < POS_Constants.WBN_FORECAST_CADENCE_TICKS then return end
    _tickCounter = 0

    local queueSizeBefore = #_forecastQueue

    _generateWeatherForecasts(currentDay, worldHours)
    _generateEconomyForecasts(currentDay, worldHours)
    _generatePowerForecasts(currentDay, worldHours)

    -- Cap total new candidates at WBN_FORECAST_MAX_PER_TICK
    local newCount = #_forecastQueue - queueSizeBefore
    if newCount > POS_Constants.WBN_FORECAST_MAX_PER_TICK then
        local excess = newCount - POS_Constants.WBN_FORECAST_MAX_PER_TICK
        for _ = 1, excess do
            table.remove(_forecastQueue)
        end
        PhobosLib.debug("POS", _TAG,
            "generateForecasts: capped output to " .. tostring(POS_Constants.WBN_FORECAST_MAX_PER_TICK)
            .. " (trimmed " .. tostring(excess) .. " excess)")
    end
end

--- Drain and return the internal forecast candidate queue.
--- @return table Array of forecast candidate tables
function POS_WBN_ForecastService.consumeCandidates()
    local result = _forecastQueue
    _forecastQueue = {}
    return result
end

--- Clear all internal state (queue, counters).
function POS_WBN_ForecastService.reset()
    _forecastQueue = {}
    _tickCounter = 0
    _forecastSeq = 0
    PhobosLib.debug("POS", _TAG, "reset: internal state cleared")
end
