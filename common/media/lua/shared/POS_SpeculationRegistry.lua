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
-- POS_SpeculationRegistry.lua
-- Schema-validated registry for speculative rumour templates.
-- Built-in templates are loaded from Definitions/Speculation/.
-- Addon mods can register custom speculation types via getRegistry().
--
-- See design-guidelines.md §26, §59 and entropy-system-design.md.
---------------------------------------------------------------

require "PhobosLib"

POS_SpeculationRegistry = {}

local _TAG = "[POS:SpeculationReg]"

local _registry
local _initialised = false

local BUILTIN_PATHS = {
    "Definitions/Speculation/default_speculation",
}

--- Initialise the speculation registry. Loads built-in templates.
function POS_SpeculationRegistry.init()
    if _initialised then return end
    _initialised = true

    local schema = require("POS_SpeculationSchema")
    _registry = PhobosLib.createRegistry({
        name           = "Speculation",
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
        "Loaded " .. _registry:count() .. " speculation template(s)")
end

--- Get all enabled speculation templates.
---@return table[] Array of template definitions
function POS_SpeculationRegistry.getAll()
    POS_SpeculationRegistry.init()
    local result = {}
    for _, def in ipairs(_registry:getAll()) do
        if def.enabled ~= false then
            result[#result + 1] = def
        end
    end
    return result
end

--- Pick a random speculation template using weighted selection.
---@return table|nil Selected template definition
function POS_SpeculationRegistry.pickWeighted()
    local templates = POS_SpeculationRegistry.getAll()
    if #templates == 0 then return nil end

    local totalWeight = 0
    for _, t in ipairs(templates) do
        totalWeight = totalWeight + (t.weight or 10)
    end
    if totalWeight <= 0 then return templates[1] end

    local roll = ZombRand(totalWeight)
    local cumulative = 0
    for _, t in ipairs(templates) do
        cumulative = cumulative + (t.weight or 10)
        if roll < cumulative then return t end
    end
    return templates[#templates]
end

--- Expose the underlying registry for addon mods.
---@return table PhobosLib registry instance
function POS_SpeculationRegistry.getRegistry()
    POS_SpeculationRegistry.init()
    return _registry
end
