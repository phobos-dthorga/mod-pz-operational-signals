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

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_WBN"
require "POS_Events"
require "POS_MarketSimulation"
require "POS_EventService"

local _TAG = "WBN:Harvest"
POS_WBN_HarvestService = {}

-- Previous-tick pressure snapshot (keyed by zoneId → categoryId → pressure)
local _previousPressure = {}

-- Candidate queue (consumed by editorial layer each scheduler tick)
local _candidateQueue = {}

--- Get and clear pending candidates.
--- @return table Array of candidate tables accumulated since last consume
function POS_WBN_HarvestService.consumeCandidates()
    local result = _candidateQueue
    _candidateQueue = {}
    return result
end

--- Generate a unique candidate ID.
--- @param domain string The broadcast domain (e.g. "economy")
--- @param zoneId string The market zone identifier
--- @return string A unique candidate identifier
local _candidateSeq = 0
local function nextCandidateId(domain, zoneId)
    _candidateSeq = _candidateSeq + 1
    return "cand_" .. domain .. "_" .. zoneId .. "_" .. tostring(_candidateSeq)
end

--- Convert raw pressure delta to rounded percentage.
--- @param delta number Raw pressure difference between ticks
--- @return number Rounded absolute percentage change
local function pressureToPercent(delta)
    return math.floor(math.abs(delta) * POS_Constants.WBN_PRESSURE_TO_PERCENT + 0.5)
end

--- Determine confidence band from event source type.
--- @param sourceType string The origin of the data (e.g. "market_event", "market_simulation")
--- @return string Confidence band constant
local function resolveConfidenceBand(sourceType)
    if sourceType == "market_event" then return POS_Constants.WBN_CONF_MEDIUM end
    return POS_Constants.WBN_CONF_LOW  -- simulation-derived = lower confidence
end

--- Map pressure delta + active events to a causeTag.
--- @param delta number Pressure change since last tick
--- @param zoneEvents table Array of active event tables for the zone
--- @return string Cause tag constant
local function resolveCauseTag(delta, zoneEvents)
    if zoneEvents and #zoneEvents > 0 then
        -- Use the strongest active event's signal class as cause hint
        local ev = zoneEvents[1]
        if ev.pressure and ev.pressure > 0 then return POS_Constants.WBN_CAUSE_SCARCITY end
        if ev.pressure and ev.pressure < 0 then return POS_Constants.WBN_CAUSE_SURPLUS end
    end
    if delta > 0 then return POS_Constants.WBN_CAUSE_SCARCITY end
    return POS_Constants.WBN_CAUSE_RECOVERY
end

--- Called when economy tick completes (via Starlit OnStockTickClosed).
--- Compares current zone pressure against previous snapshot and generates
--- economy candidates for any category with meaningful movement.
--- @param data table Tick data containing at least { day = number }
function POS_WBN_HarvestService.onEconomyTick(data)
    local currentDay = data and data.day or 0
    local worldHours = getGameTime() and getGameTime():getWorldAgeHours() or 0

    local zones = POS_Constants.MARKET_ZONES
    if not zones then return end

    local categoryMultipliers = POS_Constants.CATEGORY_PRICE_MULTIPLIERS or {}

    for _, zoneId in ipairs(zones) do
        local prevZone = _previousPressure[zoneId] or {}
        local currZone = {}

        -- Fetch active events for cause resolution
        local zoneEvents = {}
        if POS_EventService and POS_EventService.getActiveEventsForZone then
            local ok, evts = PhobosLib.safecall(
                POS_EventService.getActiveEventsForZone, zoneId, currentDay)
            if ok and evts then zoneEvents = evts end
        end

        for catId, _ in pairs(categoryMultipliers) do
            local pressure = 0
            if POS_MarketSimulation and POS_MarketSimulation.getZonePressure then
                local ok, p = PhobosLib.safecall(
                    POS_MarketSimulation.getZonePressure, zoneId, catId)
                if ok and type(p) == "number" then pressure = p end
            end
            currZone[catId] = pressure

            local prevPressure = prevZone[catId] or 0
            local delta = pressure - prevPressure
            local pctChange = pressureToPercent(delta)

            if pctChange >= POS_Constants.WBN_THRESHOLD_LIGHT then
                local direction = POS_Constants.WBN_DIR_STABLE
                if delta > 0 then direction = POS_Constants.WBN_DIR_UP end
                if delta < 0 then direction = POS_Constants.WBN_DIR_DOWN end

                local eventType = POS_Constants.WBN_EVENT_SCARCITY_ALERT
                if direction == POS_Constants.WBN_DIR_DOWN then
                    eventType = POS_Constants.WBN_EVENT_SURPLUS_NOTICE
                end

                -- Severity scales with threshold band
                local severity = 0.3
                if pctChange >= POS_Constants.WBN_THRESHOLD_HEADLINE then severity = 1.0
                elseif pctChange >= POS_Constants.WBN_THRESHOLD_STRONG then severity = 0.8
                elseif pctChange >= POS_Constants.WBN_THRESHOLD_NORMAL then severity = 0.6
                end

                local candidate = {
                    id             = nextCandidateId(POS_Constants.WBN_DOMAIN_ECONOMY, zoneId),
                    domain         = POS_Constants.WBN_DOMAIN_ECONOMY,
                    eventType      = eventType,
                    zoneId         = zoneId,
                    categoryId     = catId,
                    severity       = severity,
                    confidence     = 0.65,
                    freshness      = 1.0,
                    sourceType     = "market_simulation",
                    publicEligible = true,
                    expiresAt      = worldHours + POS_Constants.WBN_CANDIDATE_EXPIRY_HOURS,
                    percentChange  = pctChange,
                    direction      = direction,
                    causeTag       = resolveCauseTag(delta, zoneEvents),
                    day            = currentDay,
                }
                _candidateQueue[#_candidateQueue + 1] = candidate
            end
        end

        _previousPressure[zoneId] = currZone
    end

    if #_candidateQueue > 0 then
        PhobosLib.debug("POS", _TAG,
            "onEconomyTick: generated " .. tostring(#_candidateQueue) .. " candidates")
    end
end

--- Called when a market event fires (via Starlit OnMarketEvent).
--- Generates an infrastructure/emergency candidate if appropriate.
--- @param data table Event data containing at least { zoneId, pressure, categories }
function POS_WBN_HarvestService.onMarketEvent(data)
    if not data or not data.zoneId then return end
    local worldHours = getGameTime() and getGameTime():getWorldAgeHours() or 0

    local candidate = {
        id             = nextCandidateId(POS_Constants.WBN_DOMAIN_ECONOMY, data.zoneId),
        domain         = POS_Constants.WBN_DOMAIN_ECONOMY,
        eventType      = POS_Constants.WBN_EVENT_SCARCITY_ALERT,
        zoneId         = data.zoneId,
        categoryId     = (data.categories and data.categories[1]) or "miscellaneous",
        severity       = math.abs(data.pressure or 0.5),
        confidence     = 0.55,
        freshness      = 1.0,
        sourceType     = "market_event",
        publicEligible = true,
        expiresAt      = worldHours + POS_Constants.WBN_CANDIDATE_EXPIRY_HOURS,
        percentChange  = pressureToPercent(data.pressure or 0),
        direction      = (data.pressure or 0) > 0 and POS_Constants.WBN_DIR_UP or POS_Constants.WBN_DIR_DOWN,
        causeTag       = POS_Constants.WBN_CAUSE_SCARCITY,
        day            = 0,
    }
    _candidateQueue[#_candidateQueue + 1] = candidate
end

--- Subscribe to Starlit events. Called once at game start.
function POS_WBN_HarvestService.init()
    if POS_Events and POS_Events.OnStockTickClosed then
        POS_Events.OnStockTickClosed:addListener(POS_WBN_HarvestService.onEconomyTick)
    end
    if POS_Events and POS_Events.OnMarketEvent then
        POS_Events.OnMarketEvent:addListener(POS_WBN_HarvestService.onMarketEvent)
    end
    PhobosLib.debug("POS", _TAG, "init: subscribed to Starlit events")
end
