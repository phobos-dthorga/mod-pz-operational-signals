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
-- POS_SignalModifierRegistry.lua
-- Schema-validated registry for signal ecology modifiers.
-- Built-in modifiers (weather, infrastructure, market, season)
-- are loaded from Definitions/SignalModifiers/.
-- Addon mods can register custom modifiers via getRegistry().
--
-- See design-guidelines.md §26 for data-pack architecture.
---------------------------------------------------------------

require "PhobosLib"

POS_SignalModifierRegistry = {}

local _TAG = "[POS:SignalModifierRegistry]"

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

local _registry
local _initialised = false

local BUILTIN_PATHS = {
    "Definitions/SignalModifiers/weather",
    "Definitions/SignalModifiers/infrastructure",
    "Definitions/SignalModifiers/market",
    "Definitions/SignalModifiers/season",
}

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Initialise the signal modifier registry. Loads built-in definitions.
--- Safe to call multiple times (idempotent).
function POS_SignalModifierRegistry.init()
    if _initialised then return end
    _initialised = true

    local schema = require("POS_SignalModifierSchema")
    _registry = PhobosLib.createRegistry({
        name           = "SignalModifiers",
        schema         = schema,
        idField        = "id",
        allowOverwrite = true,
        tag            = _TAG,
    })

    PhobosLib.loadDefinitions({
        registry = _registry,
        paths    = BUILTIN_PATHS,
        tag      = _TAG,
    })

    PhobosLib.debug("POS", _TAG,
        "Loaded " .. _registry:count() .. " signal modifier(s)")
end

--- Get a signal modifier definition by ID.
---@param modifierId string  e.g. "rain_heavy"
---@return table|nil
function POS_SignalModifierRegistry.get(modifierId)
    POS_SignalModifierRegistry.init()
    return _registry:get(modifierId)
end

--- Get all registered signal modifiers as an array.
---@return table[]
function POS_SignalModifierRegistry.getAll()
    POS_SignalModifierRegistry.init()
    return _registry:getAll()
end

--- Get all modifiers for a specific pillar.
---@param pillarName string  "propagation", "infrastructure", or "saturation"
---@return table[]
function POS_SignalModifierRegistry.getByPillar(pillarName)
    POS_SignalModifierRegistry.init()
    local result = {}
    for _, modifier in ipairs(_registry:getAll()) do
        if modifier.pillar == pillarName and modifier.enabled ~= false then
            result[#result + 1] = modifier
        end
    end
    return result
end

--- Get all modifiers matching a specific trigger.
---@param triggerName string  e.g. "rain_heavy", "grid_off"
---@return table[]
function POS_SignalModifierRegistry.getByTrigger(triggerName)
    POS_SignalModifierRegistry.init()
    local result = {}
    for _, modifier in ipairs(_registry:getAll()) do
        if modifier.trigger == triggerName and modifier.enabled ~= false then
            result[#result + 1] = modifier
        end
    end
    return result
end

--- Expose the underlying registry for addon mods.
---@return table PhobosLib registry instance
function POS_SignalModifierRegistry.getRegistry()
    POS_SignalModifierRegistry.init()
    return _registry
end
