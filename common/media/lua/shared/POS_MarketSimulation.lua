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
-- See docs/living-market-design.md for the full specification.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_MarketAgent"
require "POS_WholesalerService"

POS_MarketSimulation = POS_MarketSimulation or {}

local _TAG = "[POS:MarketSim]"

--- Internal agent registry, keyed by agent.id.
local _agents = {}

--- Translation key suffix lookups.
local ZONE_UI_KEYS = {
    [POS_Constants.MARKET_ZONE_MULDRAUGH]         = "Muldraugh",
    [POS_Constants.MARKET_ZONE_WEST_POINT]        = "WestPoint",
    [POS_Constants.MARKET_ZONE_RIVERSIDE]          = "Riverside",
    [POS_Constants.MARKET_ZONE_LOUISVILLE_EDGE]   = "LouisvilleEdge",
    [POS_Constants.MARKET_ZONE_MILITARY_CORRIDOR] = "MilitaryCorridor",
    [POS_Constants.MARKET_ZONE_RURAL_EAST]        = "RuralEast",
}

local EVENT_UI_KEYS = {
    [POS_Constants.MARKET_EVENT_BULK_ARRIVAL]       = "BulkArrival",
    [POS_Constants.MARKET_EVENT_CONVOY_DELAY]       = "ConvoyDelay",
    [POS_Constants.MARKET_EVENT_THEFT_RAID]         = "TheftRaid",
    [POS_Constants.MARKET_EVENT_CONTROLLED_RELEASE] = "ControlledRelease",
    [POS_Constants.MARKET_EVENT_WITHHOLDING]        = "Withholding",
    [POS_Constants.MARKET_EVENT_REQUISITION]        = "Requisition",
}


--- Initialise the simulation.
--- Stub: will bootstrap market zones into POS_WorldState and seed
--- initial agents using regional composition patterns from the design doc.
function POS_MarketSimulation.init()
    -- TODO: Bootstrap zones, seed agents, load wholesalers from WorldState
    PhobosLib.debug("POS", _TAG, "init() stub — Living Market not yet active")
end


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


--- Get the current state of a market zone.
--- Stub: returns a default-initialised zone table.
---@param zoneId string  Market zone ID
---@return table         Zone state { supply, demand, volatility, pressure }
function POS_MarketSimulation.getZoneState(zoneId)
    -- TODO: Read from POS_WorldState.getMarketZones()
    return {
        id         = zoneId,
        supply     = {},
        demand     = {},
        volatility = POS_Constants.SIMULATION_ZONE_DEFAULT_VOLATILITY,
        pressure   = {},
    }
end


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


--- Get the localised display name for a market zone.
---@param zoneId string  Market zone ID
---@return string        Localised name, or the zone ID as fallback
function POS_MarketSimulation.getZoneDisplayName(zoneId)
    local suffix = ZONE_UI_KEYS[zoneId]
    if not suffix then return zoneId end
    return PhobosLib.safeGetText("UI_POS_Zone_" .. suffix)
end


--- Get the localised display name for a market event type.
---@param eventType string  Event type ID
---@return string           Localised name, or the event ID as fallback
function POS_MarketSimulation.getEventDisplayName(eventType)
    local suffix = EVENT_UI_KEYS[eventType]
    if not suffix then return eventType end
    return PhobosLib.safeGetText("UI_POS_MarketEvent_" .. suffix)
end
