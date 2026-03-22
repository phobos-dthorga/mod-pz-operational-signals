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
require "POS_PriceEngine"
require "POS_MarketDatabase"

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
    "Definitions/Archetypes/smuggler",
    "Definitions/Archetypes/military_logistician",
    "Definitions/Archetypes/speculator",
    "Definitions/Archetypes/specialist_crafter",
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

---------------------------------------------------------------
-- Observation generation (Phase 4)
---------------------------------------------------------------

--- Generate market observations from an agent based on its
--- archetype, hidden-state meters, and zone conditions.
--- Records are inserted directly into POS_MarketDatabase.
---@param agent      table   Agent table (from createAgent)
---@param zoneState  table   Zone runtime state (from POS_MarketSimulation)
---@param currentDay number  Current in-game day
---@return number            Count of records added
function POS_MarketAgent.generateObservations(agent, zoneState, currentDay)
    local def = _archetypeRegistry:get(agent.archetype)
    if not def then
        PhobosLib.debug("POS", _TAG, "generateObservations: unknown archetype "
            .. tostring(agent.archetype))
        return 0
    end

    local profile = def.tuning
    local behaviour = def.behaviour or "baseline_trader"
    local affinities = def.affinities or {}

    -- Visibility gate: unreliable agents sometimes produce nothing
    if PhobosLib.randFloat(0, 1) >= profile.reliability then
        return 0
    end

    local count = 0

    for catId, affinity in pairs(affinities) do
        if type(affinity) == "number" and affinity > 0.1 then

            -- Specialist crafters only emit for high-affinity categories
            if behaviour == "specialist_crafter" and affinity < 0.8 then
                -- skip this category
            else
                -- Base price from category base price table + day drift
                local basePrice = POS_Constants.CATEGORY_BASE_PRICE[catId]
                    or POS_Constants.PRICE_MIN_OUTPUT
                local drift = POS_PriceEngine.getDayDrift(catId)
                local price = basePrice * (1 + drift)

                -- Hidden state modifiers
                if agent.greed > POS_Constants.AGENT_OBS_GREED_THRESHOLD then
                    price = price * (1 + agent.greed
                        * POS_Constants.AGENT_OBS_GREED_MULTIPLIER)
                end
                if agent.surplus > POS_Constants.AGENT_OBS_SURPLUS_THRESHOLD then
                    price = price * (1 - agent.surplus
                        * POS_Constants.AGENT_OBS_SURPLUS_MULTIPLIER)
                end

                -- Archetype-specific behaviour
                local noise = POS_Constants.AGENT_OBS_DEFAULT_NOISE

                if behaviour == "smuggler" or behaviour == "speculator" then
                    noise = POS_Constants.AGENT_OBS_SCAVENGER_NOISE
                end

                if behaviour == "speculator" then
                    price = price * POS_Constants.AGENT_OBS_SPECULATOR_MARKUP
                end

                -- Apply noise
                local noiseFactor = PhobosLib.randFloat(-noise, noise)
                price = price * (1 + noiseFactor)

                -- Round to 2 decimal places
                price = math.floor(price * 100 + 0.5) / 100
                price = math.max(POS_Constants.PRICE_MIN_OUTPUT, price)

                -- Determine confidence
                local confidence = "medium"
                if behaviour == "smuggler" then
                    confidence = "low"
                elseif agent.exposure < POS_Constants.AGENT_OBS_EXPOSURE_THRESHOLD then
                    confidence = "high"
                end

                -- Determine stock bucket
                local stock = "medium"
                if behaviour == "smuggler"
                        and PhobosLib.randFloat(0, 1)
                            < POS_Constants.AGENT_OBS_SMUGGLER_INVERSION then
                    -- Smuggler inversion: reported stock is opposite
                    local zonePressure = zoneState.pressure[catId] or 0
                    if zonePressure > 0 then
                        stock = "high"  -- scarcity reported as abundance
                    else
                        stock = "low"   -- surplus reported as scarcity
                    end
                else
                    -- Derive stock from zone pressure
                    local zonePressure = zoneState.pressure[catId] or 0
                    if zonePressure > 0.3 then
                        stock = "low"
                    elseif zonePressure < -0.3 then
                        stock = "high"
                    end
                end

                -- Build and submit record
                local record = {
                    categoryId = catId,
                    price      = price,
                    stock      = stock,
                    confidence = confidence,
                    source     = POS_Constants.AGENT_OBS_SOURCE_PREFIX .. agent.id,
                    sourceTier = POS_Constants.SOURCE_TIER_FIELD,
                    day        = currentDay,
                    zoneId     = agent.zoneId,
                }

                local ok = POS_MarketDatabase.addRecord(record)
                if ok then
                    count = count + 1
                end
            end
        end
    end

    return count
end
