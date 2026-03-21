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
-- POS_MarketAgent.lua
-- Agent factory and archetype accessors for the Living Market
-- simulation. Loads archetype definitions from data-only Lua
-- files via PhobosLib registry/schema infrastructure.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MarketAgent = POS_MarketAgent or {}

local _TAG = "[POS:MarketAgent]"

---------------------------------------------------------------
-- Archetype registry (created at file-load time)
---------------------------------------------------------------

local _archetypeSchema = require "POS_ArchetypeSchema"

local _archetypeRegistry = PhobosLib.createRegistry({
    name    = "Archetypes",
    schema  = _archetypeSchema,
    idField = "id",
    allowOverwrite = false,
    tag     = "[POS:Archetype]",
})

---------------------------------------------------------------
-- Built-in definition paths
---------------------------------------------------------------

local BUILTIN_ARCHETYPE_PATHS = {
    "Definitions/Archetypes/scavenger_trader",
    "Definitions/Archetypes/quartermaster",
    "Definitions/Archetypes/wholesaler",
}

---------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------

local _initialised = false

--- Load built-in archetype definitions. Called from
--- POS_MarketSimulation.init() during OnGameStart.
--- Safe to call multiple times (idempotent).
function POS_MarketAgent.init()
    if _initialised then return end
    _initialised = true

    PhobosLib.loadDefinitions({
        registry = _archetypeRegistry,
        paths    = BUILTIN_ARCHETYPE_PATHS,
        tag      = "[POS:Archetype:Loader]",
    })

    PhobosLib.debug("POS", _TAG,
        "Initialised with " .. _archetypeRegistry:count() .. " archetypes")
end

---------------------------------------------------------------
-- Registry access (for addon mods)
---------------------------------------------------------------

--- Get the archetype registry. Addon mods use this to register
--- custom archetypes: POS_MarketAgent.getRegistry():register(def)
---@return table PhobosLib registry instance
function POS_MarketAgent.getRegistry()
    return _archetypeRegistry
end

---------------------------------------------------------------
-- Agent factory
---------------------------------------------------------------

--- Create a new market agent from an archetype definition.
--- The agent's numeric parameters are copied from the archetype
--- definition loaded from the registry. Hidden state meters
--- (pressure, greed, exposure, surplus, trustShift) are initialised to 0.
---@param id          string  Unique agent identifier
---@param archetype   string  One of the POS_Constants.AGENT_ARCHETYPE_* values
---@param zoneId      string  Market zone this agent belongs to
---@param displayName string  Human-readable name (e.g. "Old Jake")
---@param categories  table|nil  Optional category override table
---@return table|nil  Agent table, or nil if archetype is unknown
function POS_MarketAgent.createAgent(id, archetype, zoneId, displayName, categories)
    local def = _archetypeRegistry:get(archetype)
    if not def then
        PhobosLib.debug("POS", _TAG, "Unknown archetype: " .. tostring(archetype))
        return nil
    end

    local tuning = def.tuning
    return {
        id            = id,
        archetype     = archetype,
        zoneId        = zoneId,
        displayName   = displayName or id,
        categories    = categories or {},
        -- Copied from archetype definition
        reliability   = tuning.reliability,
        volatility    = tuning.volatility,
        stockBias     = tuning.stockBias,
        priceBias     = tuning.priceBias,
        refreshDays   = tuning.refreshDays,
        influence     = tuning.influence,
        secrecy       = tuning.secrecy,
        rumorRate     = tuning.rumorRate,
        riskTolerance = tuning.riskTolerance,
        -- Hidden state meters (transient, not serialised)
        pressure      = 0.0,
        greed         = 0.0,
        exposure      = 0.0,
        surplus       = 0.0,
        trustShift    = 0.0,
        -- Lifecycle
        lastUpdateDay = 0,
        active        = true,
    }
end

---------------------------------------------------------------
-- Accessors
---------------------------------------------------------------

--- Get the tuning table for an archetype from the registry.
---@param archetype string  Archetype ID
---@return table|nil        Tuning table or nil if unknown
function POS_MarketAgent.getProfile(archetype)
    local def = _archetypeRegistry:get(archetype)
    return def and def.tuning or nil
end

--- Get an agent's category affinity weight from the registry.
---@param archetype  string  Archetype ID
---@param categoryId string  Category key (e.g. "food", "fuel")
---@return number            Affinity weight (0 if not defined)
function POS_MarketAgent.getAffinityWeight(archetype, categoryId)
    local def = _archetypeRegistry:get(archetype)
    if not def or not def.affinities then return 0 end
    return def.affinities[categoryId] or 0
end

--- Get the display name for an archetype from its definition.
---@param archetype string  Archetype ID
---@return string           Display name, or the archetype ID as fallback
function POS_MarketAgent.getDisplayName(archetype)
    local def = _archetypeRegistry:get(archetype)
    if def and def.name then return def.name end
    return archetype
end
