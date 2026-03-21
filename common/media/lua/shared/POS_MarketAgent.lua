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
-- simulation. Creates agent tables from archetype profiles
-- defined in POS_Constants.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MarketAgent = POS_MarketAgent or {}

local _TAG = "[POS:MarketAgent]"

--- Translation key suffix lookup: archetype ID → UI key fragment.
local ARCHETYPE_UI_KEYS = {
    [POS_Constants.AGENT_ARCHETYPE_SCAVENGER]            = "ScavengerTrader",
    [POS_Constants.AGENT_ARCHETYPE_QUARTERMASTER]        = "Quartermaster",
    [POS_Constants.AGENT_ARCHETYPE_WHOLESALER]           = "Wholesaler",
    [POS_Constants.AGENT_ARCHETYPE_SMUGGLER]             = "Smuggler",
    [POS_Constants.AGENT_ARCHETYPE_MILITARY_LOGISTICIAN] = "MilitaryLogistician",
    [POS_Constants.AGENT_ARCHETYPE_SPECULATOR]           = "Speculator",
    [POS_Constants.AGENT_ARCHETYPE_SPECIALIST_CRAFTER]   = "SpecialistCrafter",
}


--- Create a new market agent from an archetype profile.
--- The agent's numeric parameters are copied from the archetype profile
--- in POS_Constants.AGENT_ARCHETYPE_PROFILES. Hidden state meters
--- (pressure, greed, exposure, surplus, trustShift) are initialised to 0.
---@param id          string  Unique agent identifier
---@param archetype   string  One of the POS_Constants.AGENT_ARCHETYPE_* values
---@param zoneId      string  Market zone this agent belongs to
---@param displayName string  Human-readable name (e.g. "Old Jake")
---@param categories  table|nil  Optional category override table
---@return table|nil  Agent table, or nil if archetype is unknown
function POS_MarketAgent.createAgent(id, archetype, zoneId, displayName, categories)
    local profile = POS_Constants.AGENT_ARCHETYPE_PROFILES[archetype]
    if not profile then
        PhobosLib.debug("POS", _TAG, "Unknown archetype: " .. tostring(archetype))
        return nil
    end

    return {
        id            = id,
        archetype     = archetype,
        zoneId        = zoneId,
        displayName   = displayName or id,
        categories    = categories or {},
        -- Copied from archetype profile
        reliability   = profile.reliability,
        volatility    = profile.volatility,
        stockBias     = profile.stockBias,
        priceBias     = profile.priceBias,
        refreshDays   = profile.refreshDays,
        influence     = profile.influence,
        secrecy       = profile.secrecy,
        rumorRate     = profile.rumorRate,
        riskTolerance = profile.riskTolerance,
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


--- Get the archetype profile table from constants.
---@param archetype string  Archetype ID
---@return table|nil        Profile table or nil if unknown
function POS_MarketAgent.getProfile(archetype)
    return POS_Constants.AGENT_ARCHETYPE_PROFILES[archetype]
end


--- Get an agent's category affinity weight.
---@param archetype  string  Archetype ID
---@param categoryId string  Category key (e.g. "food", "fuel")
---@return number            Affinity weight (0 if not defined)
function POS_MarketAgent.getAffinityWeight(archetype, categoryId)
    local affinities = POS_Constants.AGENT_CATEGORY_AFFINITIES[archetype]
    if not affinities then return 0 end
    return affinities[categoryId] or 0
end


--- Get the localised display name for an archetype.
---@param archetype string  Archetype ID
---@return string           Localised name, or the archetype ID as fallback
function POS_MarketAgent.getDisplayName(archetype)
    local suffix = ARCHETYPE_UI_KEYS[archetype]
    if not suffix then return archetype end
    return PhobosLib.safeGetText("UI_POS_Agent_" .. suffix)
end
