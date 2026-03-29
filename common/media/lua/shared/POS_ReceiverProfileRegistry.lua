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
-- POS_ReceiverProfileRegistry.lua
-- Schema-validated registry for receiver quality profiles.
-- Each profile maps a radio item type to a pre-computed base
-- quality factor. Profiles are loaded from
-- Definitions/ReceiverProfiles/.
--
-- Addon mods can register custom profiles for their radios
-- via getRegistry():register().
--
-- See design-guidelines.md §60 for receiver quality architecture.
---------------------------------------------------------------

require "PhobosLib"

POS_ReceiverProfileRegistry = {}

local _TAG = "[POS:ReceiverProfileReg]"

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

local _registry
local _initialised = false
local _fullTypeIndex = {}  -- fullType → profile (fast lookup)

local BUILTIN_PATHS = {
    "Definitions/ReceiverProfiles/vanilla_radios",
}

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Initialise the receiver profile registry. Loads built-in definitions.
--- Safe to call multiple times (idempotent).
function POS_ReceiverProfileRegistry.init()
    if _initialised then return end
    _initialised = true

    local schema = require("POS_ReceiverProfileSchema")
    _registry = PhobosLib.createRegistry({
        name           = "ReceiverProfiles",
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

    -- Build fullType index for fast lookups
    _fullTypeIndex = {}
    for _, profile in ipairs(_registry:getAll()) do
        if profile.fullType and profile.enabled ~= false then
            _fullTypeIndex[profile.fullType] = profile
        end
    end

    PhobosLib.debug("POS", _TAG,
        "Loaded " .. _registry:count() .. " receiver profile(s)")
end

--- Get a receiver profile by its definition ID.
---@param profileId string  e.g. "manpack_radio"
---@return table|nil
function POS_ReceiverProfileRegistry.get(profileId)
    POS_ReceiverProfileRegistry.init()
    return _registry:get(profileId)
end

--- Get a receiver profile by the radio item's full type.
--- This is the primary lookup used by PhobosLib_Radio.getReceiverQualityFactor().
---@param fullType string  e.g. "Base.ManPackRadio"
---@return table|nil
function POS_ReceiverProfileRegistry.getByFullType(fullType)
    POS_ReceiverProfileRegistry.init()
    return _fullTypeIndex[fullType]
end

--- Get all registered receiver profiles as an array.
---@return table[]
function POS_ReceiverProfileRegistry.getAll()
    POS_ReceiverProfileRegistry.init()
    return _registry:getAll()
end

--- Expose the underlying registry for addon mods.
--- After registering, call rebuildIndex() to refresh the fullType cache.
---@return table PhobosLib registry instance
function POS_ReceiverProfileRegistry.getRegistry()
    POS_ReceiverProfileRegistry.init()
    return _registry
end

--- Rebuild the fullType index after addon registrations.
function POS_ReceiverProfileRegistry.rebuildIndex()
    POS_ReceiverProfileRegistry.init()
    _fullTypeIndex = {}
    for _, profile in ipairs(_registry:getAll()) do
        if profile.fullType and profile.enabled ~= false then
            _fullTypeIndex[profile.fullType] = profile
        end
    end
end
