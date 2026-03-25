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
-- POS_VoicePackRegistry.lua
-- Data-pack-driven voice pack system mapping market agent
-- archetypes to text pool overrides for briefing sections.
--
-- Supports: situation, submission, agentState, investment.
--
-- Addon mods extend via Definitions/VoicePacks/*.lua files
-- following POS_VoicePackSchema.
--
-- See design-guidelines.md §32.7.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_VoicePackRegistry = {}

local _TAG = "[POS:VoicePacks]"

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

-- archetypeId -> { sectionName -> textPoolId }
local _overrides = {}
local _registry = nil
local _initialised = false

---------------------------------------------------------------
-- Built-in definition paths
---------------------------------------------------------------

local BUILTIN_PATHS = {
    "Definitions/VoicePacks/scavenger",
    "Definitions/VoicePacks/quartermaster",
    "Definitions/VoicePacks/wholesaler",
    "Definitions/VoicePacks/smuggler",
    "Definitions/VoicePacks/military",
    "Definitions/VoicePacks/trader",
    "Definitions/VoicePacks/speculator",
    "Definitions/VoicePacks/crafter",
    "Definitions/VoicePacks/field_reporter",
}

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Initialise the voice pack registry from definition files.
--- Uses PhobosLib data-pack pattern (schema → registry → definitions).
function POS_VoicePackRegistry.init()
    if _initialised then return end
    _initialised = true

    local schema = require("POS_VoicePackSchema")
    _registry = PhobosLib.createRegistry({
        name           = "VoicePacks",
        schema         = schema,
        idField        = "id",
        allowOverwrite = true,
        tag            = _TAG,
    })

    -- Load built-in definitions
    for _, path in ipairs(BUILTIN_PATHS) do
        local ok, data = pcall(require, path)
        if ok and type(data) == "table" then
            _registry:register(data)
            -- Apply overrides from definition
            if data.archetypeId and data.overrides then
                POS_VoicePackRegistry.registerPack(data.archetypeId, data.overrides)
            end
        else
            PhobosLib.warn("POS", _TAG, "Failed to load voice pack: " .. tostring(path))
        end
    end

    PhobosLib.debug("POS", _TAG,
        "Loaded " .. tostring(_registry:count()) .. " voice pack(s)")
end

--- Register a voice pack override for an archetype + section.
--- Validates section against VOICE_ALL_OVERRIDE_SECTIONS.
---@param archetypeId string Market agent archetype ID
---@param sectionName string Briefing section constant
---@param textPoolId string Text pool ID to use
function POS_VoicePackRegistry.register(archetypeId, sectionName, textPoolId)
    if not archetypeId or not sectionName or not textPoolId then return end

    -- Validate section against extended override list
    local allowed = false
    for _, s in ipairs(POS_Constants.VOICE_ALL_OVERRIDE_SECTIONS) do
        if s == sectionName then
            allowed = true
            break
        end
    end
    if not allowed then return end

    if not _overrides[archetypeId] then
        _overrides[archetypeId] = {}
    end
    _overrides[archetypeId][sectionName] = textPoolId
end

--- Get the text pool override for an archetype + section.
---@param archetypeId string
---@param sectionName string
---@return string|nil Text pool ID, or nil for default
function POS_VoicePackRegistry.getOverride(archetypeId, sectionName)
    if not archetypeId or not _overrides[archetypeId] then return nil end
    return _overrides[archetypeId][sectionName]
end

--- Register all overrides from a voice pack definition table.
---@param archetypeId string
---@param overrides table Map of sectionName → textPoolId
function POS_VoicePackRegistry.registerPack(archetypeId, overrides)
    if not archetypeId or type(overrides) ~= "table" then return end
    for section, poolId in pairs(overrides) do
        POS_VoicePackRegistry.register(archetypeId, section, poolId)
    end
end

--- Get the underlying registry for addon mods.
---@return table|nil Registry instance
function POS_VoicePackRegistry.getRegistry()
    return _registry
end

--- Legacy compatibility: initBuiltIn() now delegates to init().
function POS_VoicePackRegistry.initBuiltIn()
    POS_VoicePackRegistry.init()
end
