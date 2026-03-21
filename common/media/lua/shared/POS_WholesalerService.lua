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
-- POS_WholesalerService.lua
-- Wholesaler lifecycle, supply pressure contribution, and
-- signal generation for the Living Market simulation.
-- Wholesaler definitions are loaded from data-only Lua files
-- via PhobosLib registry/schema infrastructure.
-- See docs/living-market-design.md §8 for the full schema.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_WholesalerService = POS_WholesalerService or {}

local _TAG = "[POS:WholesalerSvc]"

---------------------------------------------------------------
-- Wholesaler definition registry
---------------------------------------------------------------

local _wholesalerSchema = require "POS_WholesalerSchema"

local _wholesalerRegistry = PhobosLib.createRegistry({
    name    = "Wholesalers",
    schema  = _wholesalerSchema,
    idField = "id",
    allowOverwrite = false,
    tag     = "[POS:Wholesaler]",
})

--- Get the wholesaler definition registry for external registration.
---@return table PhobosLib registry instance
function POS_WholesalerService.getRegistry()
    return _wholesalerRegistry
end

--- Create a wholesaler from a registered definition.
---@param id string  Wholesaler definition ID
---@return table|nil Wholesaler instance, or nil if not found
function POS_WholesalerService.createFromRegistry(id)
    local def = _wholesalerRegistry:get(id)
    if not def then return nil end
    return POS_WholesalerService.createWholesaler(def)
end

--- Translation key suffix lookup: operational state → UI key fragment.
local STATE_UI_KEYS = {
    [POS_Constants.WHOLESALER_STATE_STABLE]      = "Stable",
    [POS_Constants.WHOLESALER_STATE_TIGHT]       = "Tight",
    [POS_Constants.WHOLESALER_STATE_STRAINED]    = "Strained",
    [POS_Constants.WHOLESALER_STATE_DUMPING]     = "Dumping",
    [POS_Constants.WHOLESALER_STATE_WITHHOLDING] = "Withholding",
    [POS_Constants.WHOLESALER_STATE_COLLAPSING]  = "Collapsing",
}


--- Create a new wholesaler from a definition table.
--- Missing fields are filled with sensible defaults.
---@param def table  Wholesaler definition (id, name, regionId, archetype required)
---@return table     Fully-initialised wholesaler table
function POS_WholesalerService.createWholesaler(def)
    return {
        id              = def.id,
        name            = def.name or def.id,
        regionId        = def.regionId,
        archetype       = def.archetype or POS_Constants.AGENT_ARCHETYPE_WHOLESALER,
        faction         = def.faction,
        active          = def.active ~= false,
        categoryWeights = def.categoryWeights or {},
        stockLevel      = def.stockLevel      or 0.75,
        throughput      = def.throughput       or 0.60,
        resilience      = def.resilience       or 0.70,
        visibility      = def.visibility       or 0.35,
        reliability     = def.reliability      or 0.80,
        influence       = def.influence        or 0.85,
        secrecy         = def.secrecy          or 0.20,
        markupBias      = def.markupBias       or -0.08,
        panicThreshold  = def.panicThreshold   or 0.25,
        dumpThreshold   = def.dumpThreshold    or 0.90,
        convoyState     = def.convoyState or {
            inTransit     = false,
            etaDay        = nil,
            cargoStrength = 0.0,
        },
        pressure        = 0.0,
        disruption      = 0.0,
        lastUpdateDay   = 0,
    }
end


--- Resolve the operational state of a wholesaler based on its
--- current pressure, disruption, and stock levels.
--- Stub: always returns STABLE. Will implement the full
--- six-state machine when the simulation is activated.
---@param wholesaler table  Wholesaler table
---@return string           One of POS_Constants.WHOLESALER_STATE_* values
function POS_WholesalerService.resolveOperationalState(wholesaler)
    -- TODO: Implement state machine based on pressure/disruption/stockLevel
    PhobosLib.debug("POS", _TAG, "resolveOperationalState stub for " .. tostring(wholesaler.id))
    return POS_Constants.WHOLESALER_STATE_STABLE
end


--- Compute a wholesaler's supply pressure contribution for a category.
--- Formula: influence * categoryWeight * (disruption + pressure - stockLevel - throughput * THROUGHPUT_FACTOR)
--- Stub: returns 0. Will be implemented with the simulation tick.
---@param wholesaler table   Wholesaler table
---@param categoryId string  Category key
---@return number            Pressure contribution (can be negative)
function POS_WholesalerService.computePressureContribution(wholesaler, categoryId)
    -- TODO: Implement pressure formula
    PhobosLib.debug("POS", _TAG, "computePressureContribution stub for "
        .. tostring(wholesaler.id) .. " / " .. tostring(categoryId))
    return 0
end


--- Run one simulation tick for a single wholesaler.
--- Stub: logs and returns. Will implement the five-phase lifecycle:
--- natural drift, demand pull, event roll, market influence, signal emission.
---@param wholesaler table   Wholesaler table
---@param currentDay number  Current in-game day
function POS_WholesalerService.tickWholesaler(wholesaler, currentDay)
    -- TODO: Implement wholesaler tick lifecycle
    PhobosLib.debug("POS", _TAG, "tickWholesaler stub for " .. tostring(wholesaler.id)
        .. " on day " .. tostring(currentDay))
end


--- Get modifier hints for downstream agent behaviour.
--- Stub: returns empty table.
---@param wholesaler     table   Wholesaler table
---@param targetArchetype string  Archetype of the downstream agent
---@return table                  Modifier hints (empty for now)
function POS_WholesalerService.getDownstreamInfluence(wholesaler, targetArchetype)
    return {}
end


--- Get the localised display name for a wholesaler operational state.
---@param state string  One of POS_Constants.WHOLESALER_STATE_* values
---@return string       Localised name, or the state ID as fallback
function POS_WholesalerService.getStateDisplayName(state)
    local suffix = STATE_UI_KEYS[state]
    if not suffix then return state end
    return PhobosLib.safeGetText("UI_POS_Wholesaler_State_" .. suffix)
end
