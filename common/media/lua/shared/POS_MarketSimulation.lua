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
-- POS_MarketSimulation.lua
-- Layer 0 simulation orchestrator for the Living Market.
-- Manages the agent registry, market zone state, and the
-- per-tick simulation loop that drives the autonomous economy.
-- Zone and event definitions are loaded from data-only Lua
-- files via PhobosLib registry/schema infrastructure.
-- See docs/living-market-design.md for the full specification.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_MarketAgent"
require "POS_WholesalerService"

POS_MarketSimulation = POS_MarketSimulation or {}

local _TAG = "[POS:MarketSim]"

---------------------------------------------------------------
-- Internal agent registry (runtime, not schema-validated)
---------------------------------------------------------------

local _agents = {}

---------------------------------------------------------------
-- Zone and event registries (schema-validated)
---------------------------------------------------------------

local _zoneSchema  = require "POS_ZoneSchema"
local _eventSchema = require "POS_EventSchema"

local _zoneRegistry = PhobosLib.createRegistry({
    name    = "MarketZones",
    schema  = _zoneSchema,
    idField = "id",
    allowOverwrite = false,
    tag     = "[POS:Zone]",
})

local _eventRegistry = PhobosLib.createRegistry({
    name    = "MarketEvents",
    schema  = _eventSchema,
    idField = "id",
    allowOverwrite = false,
    tag     = "[POS:Event]",
})

---------------------------------------------------------------
-- Built-in definition paths
---------------------------------------------------------------

local BUILTIN_ZONE_PATHS = {
    "Definitions/Zones/muldraugh",
    "Definitions/Zones/west_point",
    "Definitions/Zones/riverside",
    "Definitions/Zones/louisville_edge",
    "Definitions/Zones/military_corridor",
    "Definitions/Zones/rural_east",
}

local BUILTIN_EVENT_PATHS = {
    "Definitions/Events/bulk_arrival",
    "Definitions/Events/convoy_delay",
    "Definitions/Events/theft_raid",
    "Definitions/Events/controlled_release",
    "Definitions/Events/strategic_withholding",
    "Definitions/Events/requisition_diversion",
}

local BUILTIN_WHOLESALER_PATHS = {
    "Definitions/Wholesalers/muldraugh_general",
    "Definitions/Wholesalers/west_point_consolidated",
    "Definitions/Wholesalers/riverside_supply",
    "Definitions/Wholesalers/louisville_arms",
    "Definitions/Wholesalers/louisville_medical",
    "Definitions/Wholesalers/military_depot",
    "Definitions/Wholesalers/military_field_hospital",
    "Definitions/Wholesalers/rural_east_salvage",
}

---------------------------------------------------------------
-- Zone state cache (runtime, persisted via hybrid strategy)
---------------------------------------------------------------

local _zoneStates = {}
local _firstTickDone = false
local _migrationChecked = false

--- Ensure a zone runtime state exists. Creates it lazily from
--- the zone registry definition if not yet cached.
---@param zoneId string  Market zone ID
---@return table         Zone runtime state
local function _ensureZoneState(zoneId)
    if _zoneStates[zoneId] then return _zoneStates[zoneId] end

    local def = _zoneRegistry:get(zoneId)
    local volatility = def and def.baseVolatility
        or POS_Constants.SIMULATION_ZONE_DEFAULT_VOLATILITY

    local state = {
        id         = zoneId,
        supply     = {},
        demand     = {},
        volatility = volatility,
        pressure   = {},
    }

    -- Initialise pressure to 0 for all categories
    for _, catId in ipairs(POS_Constants.MARKET_CATEGORIES) do
        state.pressure[catId] = 0
    end

    -- Restore persisted zone state from ModData if available (Phase 5B)
    local zonesModData = POS_WorldState.getMarketZones()
    local persisted = zonesModData and zonesModData.entries
        and zonesModData.entries[zoneId]
    if persisted then
        if persisted.volatility then
            state.volatility = persisted.volatility
        end
        if persisted.pressure then
            for catId, val in pairs(persisted.pressure) do
                state.pressure[catId] = val
            end
        end
        PhobosLib.debug("POS", _TAG, "Restored zone state for " .. zoneId)
    end

    _zoneStates[zoneId] = state
    return state
end

---------------------------------------------------------------
-- Save migration validation
---------------------------------------------------------------

--- Validate and migrate a wholesaler's persisted state against
--- its current definition. Backfills missing fields from
--- definition defaults when the schema version has changed.
---@param wholesaler table  Persisted wholesaler state from ModData
---@param definition table  Wholesaler definition from registry
---@return boolean          true if migration was applied
local function _validateWholesalerState(wholesaler, definition)
    if wholesaler.schemaVersion == definition.schemaVersion then
        return false
    end

    PhobosLib.debug("POS", _TAG, "Migrating wholesaler " .. wholesaler.id
        .. " from schema v" .. tostring(wholesaler.schemaVersion or 0)
        .. " to v" .. tostring(definition.schemaVersion))

    -- Backfill missing numeric fields from definition or createWholesaler defaults
    local fieldDefaults = {
        stockLevel     = definition.stockLevel     or 0.75,
        throughput     = definition.throughput      or 0.60,
        resilience     = definition.resilience      or 0.70,
        visibility     = definition.visibility      or 0.35,
        reliability    = definition.reliability     or 0.80,
        influence      = definition.influence       or 0.85,
        secrecy        = definition.secrecy         or 0.20,
        markupBias     = definition.markupBias      or -0.08,
        panicThreshold = definition.panicThreshold  or 0.25,
        dumpThreshold  = definition.dumpThreshold   or 0.90,
    }

    for field, default in pairs(fieldDefaults) do
        if wholesaler[field] == nil then
            wholesaler[field] = default
        end
    end

    if wholesaler.categoryWeights == nil then
        wholesaler.categoryWeights = definition.categoryWeights or {}
    end

    wholesaler.schemaVersion = definition.schemaVersion
    return true
end

---------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------

local _initialised = false

--- Initialise the simulation. Loads archetype, zone, event, and
--- wholesaler definitions from data-only Lua files.
--- Called from OnGameStart when Living Market is enabled.
--- Safe to call multiple times (idempotent).
function POS_MarketSimulation.init()
    if _initialised then return end
    _initialised = true

    -- Load archetypes first (POS_MarketAgent owns this)
    POS_MarketAgent.init()

    -- Load zones
    PhobosLib.loadDefinitions({
        registry = _zoneRegistry,
        paths    = BUILTIN_ZONE_PATHS,
        tag      = "[POS:Zone:Loader]",
    })

    -- Load events
    PhobosLib.loadDefinitions({
        registry = _eventRegistry,
        paths    = BUILTIN_EVENT_PATHS,
        tag      = "[POS:Event:Loader]",
    })

    -- Load wholesalers
    PhobosLib.loadDefinitions({
        registry = POS_WholesalerService.getRegistry(),
        paths    = BUILTIN_WHOLESALER_PATHS,
        tag      = "[POS:Wholesaler:Loader]",
    })

    -- Pre-create zone states and populate agents
    for _, zoneId in ipairs(POS_Constants.MARKET_ZONES) do
        _ensureZoneState(zoneId)
    end

    -- Populate agents for each zone based on zone population tier
    POS_MarketSimulation._populateZoneAgents()

    -- Share zone registry with WholesalerService for display name resolution
    POS_WholesalerService._setZoneRegistry(_zoneRegistry)

    PhobosLib.debug("POS", _TAG, "init() — loaded "
        .. POS_MarketAgent.getRegistry():count() .. " archetypes, "
        .. _zoneRegistry:count() .. " zones, "
        .. _eventRegistry:count() .. " events, "
        .. POS_WholesalerService.getRegistry():count() .. " wholesalers")
end

---------------------------------------------------------------
-- Registry access (for addon mods)
---------------------------------------------------------------

--- Get the zone registry for external registration.
---@return table PhobosLib registry instance
function POS_MarketSimulation.getZoneRegistry()
    return _zoneRegistry
end

--- Get the event registry for external registration.
---@return table PhobosLib registry instance
function POS_MarketSimulation.getEventRegistry()
    return _eventRegistry
end

---------------------------------------------------------------
-- Agent management (runtime, not schema-validated)
---------------------------------------------------------------

--- Register an agent in the simulation.
---@param agent table  Agent table (must have agent.id)
function POS_MarketSimulation.registerAgent(agent)
    if not agent or not agent.id then
        PhobosLib.debug("POS", _TAG, "registerAgent: nil agent or missing id")
        return
    end
    _agents[agent.id] = agent
    PhobosLib.debug("POS", _TAG, "Registered agent: " .. agent.id
        .. " (" .. tostring(agent.archetype) .. ") in zone " .. tostring(agent.zoneId))
end

--- Populate agents for all zones based on zone population tier.
--- Uses ZONE_AGENT_COMPOSITION constants. Skips zones that
--- already have agents (idempotent for save reload).
function POS_MarketSimulation._populateZoneAgents()
    local composition = POS_Constants.ZONE_AGENT_COMPOSITION
    if not composition then
        PhobosLib.warn("POS", _TAG, "ZONE_AGENT_COMPOSITION not defined")
        return
    end

    local totalCreated = 0
    for _, zoneId in ipairs(POS_Constants.MARKET_ZONES) do
        -- Skip if zone already has agents
        local existing = POS_MarketSimulation.getAgentsForZone(zoneId)
        if #existing > 0 then
            PhobosLib.debug("POS", _TAG,
                "Zone " .. zoneId .. " already has " .. #existing .. " agents, skipping")
        else
            -- Determine population tier from zone definition
            local zoneDef = _zoneRegistry:get(zoneId)
            local pop = zoneDef and zoneDef.population or "medium"
            local slots = composition[pop]
            if not slots then
                PhobosLib.warn("POS", _TAG,
                    "No composition for population tier: " .. tostring(pop))
                slots = composition["medium"] or {}
            end

            -- Create agents for each slot
            for _, slot in ipairs(slots) do
                for i = 1, (slot.count or 1) do
                    local agentId = zoneId .. "_" .. slot.archetype .. "_" .. tostring(i)
                    -- Use archetype display name from definition, not translation key
                    local archetypeDef = POS_MarketAgent.getRegistry():get(slot.archetype)
                    local displayName = archetypeDef and archetypeDef.name or slot.archetype
                    local agent = POS_MarketAgent.createAgent(
                        agentId, slot.archetype, zoneId, displayName)
                    if agent then
                        POS_MarketSimulation.registerAgent(agent)
                        totalCreated = totalCreated + 1
                    end
                end
            end
        end
    end

    PhobosLib.debug("POS", _TAG,
        "Populated " .. totalCreated .. " agents across "
        .. #POS_Constants.MARKET_ZONES .. " zones")
end

--- Get all agents belonging to a specific market zone.
---@param zoneId string  Market zone ID
---@return table         Array of agent tables
function POS_MarketSimulation.getAgentsForZone(zoneId)
    local result = {}
    for _, agent in pairs(_agents) do
        if agent.zoneId == zoneId then
            result[#result + 1] = agent
        end
    end
    return result
end

---------------------------------------------------------------
-- Zone state (live, with hybrid persistence)
---------------------------------------------------------------

--- Get the current state of a market zone.
--- Returns the live cached zone state with pressure aggregated
--- from wholesaler contributions.
---@param zoneId string  Market zone ID
---@return table         Zone state { id, supply, demand, volatility, pressure }
function POS_MarketSimulation.getZoneState(zoneId)
    return _ensureZoneState(zoneId)
end

--- Get the supply pressure for a specific category in a zone.
--- Aggregates pressure contributions from all wholesalers in the zone.
--- Positive = scarcity, negative = surplus.
---@param zoneId     string  Market zone ID
---@param categoryId string  Category key
---@return number            Pressure value
function POS_MarketSimulation.getZonePressure(zoneId, categoryId)
    local wholesalerStore = POS_MarketSimulation._getWholesalerStore()
    local total = 0
    for _, w in pairs(wholesalerStore) do
        if w.regionId == zoneId and w._lastContributions then
            total = total + (w._lastContributions[categoryId] or 0)
        end
    end
    return PhobosLib.clamp(total,
        POS_Constants.SIMULATION_PRESSURE_CLAMP_MIN,
        POS_Constants.SIMULATION_PRESSURE_CLAMP_MAX)
end

--- Get the luxury demand multiplier for a zone.
--- Used by POS_PriceEngine to scale luxury item prices.
--- @param zoneId string  Zone key
--- @return number        Luxury demand multiplier (default 1.0)
function POS_MarketSimulation.getZoneLuxuryDemand(zoneId)
    if not _zoneRegistry then return 1.0 end
    local def = _zoneRegistry:get(zoneId)
    return def and def.luxuryDemand or 1.0
end

--- Get the base volatility for a zone.
--- Used by POS_FreeAgentService for zone-aware risk scaling.
--- @param zoneId string  Zone key
--- @return number        Base volatility (default from constants)
function POS_MarketSimulation.getZoneVolatility(zoneId)
    if not _zoneRegistry then return POS_Constants.ZONE_DEFAULT_VOLATILITY end
    local def = _zoneRegistry:get(zoneId)
    return def and def.baseVolatility or POS_Constants.ZONE_DEFAULT_VOLATILITY
end

---------------------------------------------------------------
-- Wholesaler lifecycle management
---------------------------------------------------------------

--- Get the persistent wholesaler store from world state.
---@return table  Wholesaler store (keyed by wholesaler ID)
function POS_MarketSimulation._getWholesalerStore()
    local ok, POS_WorldState = PhobosLib.safecall(require, "POS_WorldState")
    if ok and POS_WorldState and POS_WorldState.getWholesalers then
        return POS_WorldState.getWholesalers() or {}
    end
    return {}
end

--- Spawn wholesalers from registry definitions into the persistent store.
--- Called on first tick to populate the world with wholesaler entities.
---@param store table  Persistent wholesaler store to populate
function POS_MarketSimulation._spawnWholesalers(store)
    local allDefs = POS_WholesalerService.getRegistry():getAll()
    local count = 0
    for _, def in ipairs(allDefs) do
        if def.enabled ~= false and not store[def.id] then
            local w = POS_WholesalerService.createWholesaler(def)
            store[def.id] = w
            count = count + 1
        end
    end
    PhobosLib.debug("POS", _TAG, "Spawned " .. count .. " wholesalers from definitions")
end

---------------------------------------------------------------
-- Agent meter updates
---------------------------------------------------------------

--- Update hidden state meters for all registered agents based on
--- current zone conditions. Primes agents for Phase 2 observation
--- generation.
---@param zoneStates table  Table of zone states keyed by zoneId
local function _updateAgentMeters(zoneStates)
    for _, agent in pairs(_agents) do
        local zoneState = zoneStates[agent.zoneId]
        if zoneState then
            -- agent.pressure approaches zone pressure for primary category
            local primaryCat = nil
            local maxAffinity = 0
            for catId, weight in pairs(agent.categories or {}) do
                if type(weight) == "number" and weight > maxAffinity then
                    maxAffinity = weight
                    primaryCat = catId
                end
            end

            if primaryCat and zoneState.pressure[primaryCat] then
                agent.pressure = PhobosLib.approach(
                    agent.pressure or 0,
                    zoneState.pressure[primaryCat],
                    POS_Constants.AGENT_PRESSURE_APPROACH_RATE)
            end

            -- Greed nudged by zone volatility
            agent.greed = PhobosLib.clamp(
                (agent.greed or 0) + zoneState.volatility * POS_Constants.AGENT_GREED_VOLATILITY_FACTOR,
                0, 1)

            -- Exposure decays naturally toward 0
            agent.exposure = PhobosLib.approach(
                agent.exposure or 0, 0,
                POS_Constants.AGENT_EXPOSURE_DECAY_RATE)

            -- Surplus tracks inverse of average zone scarcity
            local avgPressure = 0
            local catCount = 0
            for _, p in pairs(zoneState.pressure) do
                avgPressure = avgPressure + p
                catCount = catCount + 1
            end
            if catCount > 0 then avgPressure = avgPressure / catCount end
            agent.surplus = PhobosLib.approach(
                agent.surplus or 0,
                PhobosLib.clamp(-avgPressure, 0, 1),
                POS_Constants.AGENT_SURPLUS_APPROACH_RATE)

            -- Trust shift decays toward 0
            agent.trustShift = PhobosLib.approach(
                agent.trustShift or 0, 0,
                POS_Constants.AGENT_TRUST_DECAY_RATE)
        end
    end
end

---------------------------------------------------------------
-- Simulation tick (orchestrator)
---------------------------------------------------------------

--- Run one full simulation tick.
--- Iterates zones, ticks wholesalers, aggregates zone pressure,
--- updates agent meters, and persists zone state.
--- See living-market-design.md §10 for the full specification.
---@param currentDay number  Current in-game day
function POS_MarketSimulation.tickSimulation(currentDay)
    POS_MarketSimulation.init()

    PhobosLib.debug("POS", _TAG, "tickSimulation — day " .. tostring(currentDay))

    local wholesalerStore = POS_MarketSimulation._getWholesalerStore()

    -- First tick: spawn wholesalers from definitions
    if not _firstTickDone then
        -- Use pairs() count instead of next() — Kahlua's next() can crash
        -- on Java-backed ModData tables (KahluaTableImpl)
        local storeCount = 0
        for _ in pairs(wholesalerStore) do storeCount = storeCount + 1 break end
        if storeCount == 0 then
            POS_MarketSimulation._spawnWholesalers(wholesalerStore)
        end
        _firstTickDone = true
    end

    -- One-time migration validation pass on first load
    if not _migrationChecked then
        local wsOk, wsRegistry = PhobosLib.safecall(POS_WholesalerService.getRegistry)
        if wsOk and wsRegistry and wsRegistry.get then
            for wId, w in pairs(wholesalerStore) do
                local defOk, def = PhobosLib.safecall(wsRegistry.get, wsRegistry, wId)
                if defOk and def then
                    if _validateWholesalerState(w, def) then
                        PhobosLib.debug("POS", _TAG,
                            "Migrated wholesaler " .. tostring(wId))
                    end
                elseif not defOk then
                    PhobosLib.debug("POS", _TAG,
                        "Migration lookup failed for: " .. tostring(wId))
                else
                    PhobosLib.debug("POS", _TAG,
                        "Orphaned wholesaler in save data: " .. tostring(wId)
                        .. " (no matching definition)")
                end
            end
        end
        _migrationChecked = true
    end

    -- Tick all active wholesalers
    PhobosLib.debug("POS", _TAG, "tickSimulation Phase 1: ticking wholesalers")
    local tickCount = 0
    for _, w in pairs(wholesalerStore) do
        if w.active ~= false then
            PhobosLib.safecall(POS_WholesalerService.tickWholesaler, w, currentDay)
            tickCount = tickCount + 1
        end
    end

    -- Aggregate zone pressure from wholesaler contributions
    PhobosLib.debug("POS", _TAG, "tickSimulation Phase 2: aggregating zone pressure")
    local ok_mr, POS_MarketRegistry = PhobosLib.safecall(require, "POS_MarketRegistry")
    local visibleCategories = (ok_mr and POS_MarketRegistry)
        and POS_MarketRegistry.getVisibleCategories({}) or {}
    for _, zoneId in ipairs(POS_Constants.MARKET_ZONES) do
        local zoneState = _ensureZoneState(zoneId)
        for _, cat in ipairs(visibleCategories) do
            zoneState.pressure[cat.id] = POS_MarketSimulation.getZonePressure(zoneId, cat.id)
        end
    end

    -- Update agent hidden state meters
    PhobosLib.debug("POS", _TAG, "tickSimulation Phase 3: updating agent meters")
    PhobosLib.safecall(_updateAgentMeters, _zoneStates)

    -- Phase 4: Generate agent observations
    local totalObs = 0
    for _, agent in pairs(_agents) do
        if agent.active ~= false then
            local zoneState = _zoneStates[agent.zoneId]
            if zoneState then
                local obsOk, obsCount = PhobosLib.safecall(
                    POS_MarketAgent.generateObservations, agent, zoneState, currentDay)
                if obsOk and type(obsCount) == "number" then
                    totalObs = totalObs + obsCount
                end
            end
        end
    end

    -- Phase 5: Market event generation (probability-based)
    if POS_EventService then
        local eventsFired = 0
        POS_EventService.purgeExpired(currentDay)
        for _, zoneId in ipairs(POS_Constants.MARKET_ZONES) do
            local firedOk, firedCount = PhobosLib.safecall(
                POS_EventService.rollEventsForZone, _eventRegistry, zoneId, currentDay)
            if firedOk and type(firedCount) == "number" then
                eventsFired = eventsFired + firedCount
            end
        end
        if eventsFired > 0 then
            PhobosLib.debug("POS", _TAG,
                "tickSimulation Phase 5: fired " .. eventsFired .. " market events")
        end
    end

    -- Hybrid persistence: save zone states to ModData
    local ok, POS_WorldState = PhobosLib.safecall(require, "POS_WorldState")
    if ok and POS_WorldState and POS_WorldState.getMarketZones then
        local zonesModData = POS_WorldState.getMarketZones()
        if zonesModData then
            zonesModData.entries = zonesModData.entries or {}
            for zoneId, zoneState in pairs(_zoneStates) do
                zonesModData.entries[zoneId] = {
                    pressure   = zoneState.pressure,
                    volatility = zoneState.volatility,
                }
            end
        end
    end

    PhobosLib.debug("POS", _TAG, "tickSimulation complete — day " .. tostring(currentDay)
        .. " (" .. tickCount .. " wholesalers, "
        .. tostring(#POS_Constants.MARKET_ZONES) .. " zones, "
        .. totalObs .. " observations)")
end

---------------------------------------------------------------
-- Display name accessors (read from registry definitions)
---------------------------------------------------------------

--- Get the display name for a market zone from its definition.
---@param zoneId string  Market zone ID
---@return string        Display name, or the zone ID as fallback
function POS_MarketSimulation.getZoneDisplayName(zoneId)
    local def = _zoneRegistry:get(zoneId)
    if def and def.name then return def.name end
    return zoneId
end

--- Get the display name for a market event from its definition.
---@param eventType string  Event type ID
---@return string           Display name, or the event ID as fallback
function POS_MarketSimulation.getEventDisplayName(eventType)
    local def = _eventRegistry:get(eventType)
    if def and def.name then return def.name end
    return eventType
end
