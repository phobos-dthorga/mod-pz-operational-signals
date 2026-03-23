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
-- POS_BandRegistry.lua
-- Schema-validated registry for radio bands. Built-in bands
-- (Operations, Tactical) are loaded from Definitions/Bands/.
-- Addon mods can register custom bands via getRegistry().
--
-- See design-guidelines.md §45.
---------------------------------------------------------------

require "PhobosLib"

POS_BandRegistry = {}

local _TAG = "[POS:BandRegistry]"

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

local _registry
local _initialised = false

local BUILTIN_PATHS = {
    "Definitions/Bands/operations",
    "Definitions/Bands/tactical",
}

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Initialise the band registry. Loads built-in band definitions.
--- Safe to call multiple times (idempotent).
function POS_BandRegistry.init()
    if _initialised then return end
    _initialised = true

    local schema = require("POS_BandSchema")
    _registry = PhobosLib.createRegistry({
        name           = "Bands",
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
        "Loaded " .. _registry:count() .. " band(s)")
end

--- Get a band definition by ID.
--- @param bandId string  e.g. "POSnet_Operations"
--- @return table|nil
function POS_BandRegistry.get(bandId)
    POS_BandRegistry.init()
    return _registry:get(bandId)
end

--- Get all registered bands as an array.
--- @return table[]
function POS_BandRegistry.getAll()
    POS_BandRegistry.init()
    return _registry:getAll()
end

--- Get all enabled band IDs as a flat array.
--- @return string[]
function POS_BandRegistry.getEnabledBandIds()
    POS_BandRegistry.init()
    local result = {}
    for _, band in ipairs(_registry:getAll()) do
        if band.enabled ~= false then
            result[#result + 1] = band.id
        end
    end
    return result
end

--- Get the badge label for a band (e.g. "OPS", "TAC").
--- @param bandId string
--- @return string
function POS_BandRegistry.getBadgeLabel(bandId)
    local band = POS_BandRegistry.get(bandId)
    return band and band.badgeLabel or "?"
end

--- Expose the underlying registry for addon mods.
--- @return table PhobosLib registry instance
function POS_BandRegistry.getRegistry()
    POS_BandRegistry.init()
    return _registry
end
