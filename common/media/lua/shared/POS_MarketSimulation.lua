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
-- Initialisation
---------------------------------------------------------------

local _initialised = false

--- Initialise the simulation. Loads archetype, zone, and event
--- definitions from data-only Lua files.
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
-- Zone state
---------------------------------------------------------------

--- Get the current state of a market zone.
--- Stub: returns a default-initialised zone table using
--- the zone definition's baseVolatility if available.
---@param zoneId string  Market zone ID
---@return table         Zone state { supply, demand, volatility, pressure }
function POS_MarketSimulation.getZoneState(zoneId)
    local def = _zoneRegistry:get(zoneId)
    local volatility = def and def.baseVolatility
        or POS_Constants.SIMULATION_ZONE_DEFAULT_VOLATILITY
    return {
        id         = zoneId,
        supply     = {},
        demand     = {},
        volatility = volatility,
        pressure   = {},
    }
end

---------------------------------------------------------------
-- Simulation tick
---------------------------------------------------------------

--- Run one full simulation tick.
--- Stub: logs and returns. Will iterate zones, tick wholesalers
--- via POS_WholesalerService, tick agents, emit observations.
---@param currentDay number  Current in-game day
function POS_MarketSimulation.tickSimulation(currentDay)
    -- TODO: Implement simulation tick loop
    PhobosLib.debug("POS", _TAG, "tickSimulation stub — day " .. tostring(currentDay))
end

--- Get the supply pressure for a specific category in a zone.
--- Stub: returns 0.
---@param zoneId     string  Market zone ID
---@param categoryId string  Category key
---@return number            Pressure value (positive = scarcity, negative = surplus)
function POS_MarketSimulation.getZonePressure(zoneId, categoryId)
    return 0
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
