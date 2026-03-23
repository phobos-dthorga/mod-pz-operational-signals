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
-- POS_ItemValueRegistry.lua
-- Registry for curated per-item base price overrides.
-- Uses the PhobosLib data-pack pattern (schema + registry +
-- definition files).  Items registered here bypass the default
-- weight-based pricing formula entirely.
--
-- Addon mods can extend via:
--   POS_ItemValueRegistry.getRegistry():register({ ... })
-- or bulk:
--   POS_ItemValueRegistry.registerOverrides({ ... })
---------------------------------------------------------------

require "PhobosLib"

POS_ItemValueRegistry = {}

local _TAG = "[POS:ItemValues]"

---------------------------------------------------------------
-- Private state
---------------------------------------------------------------

local _schema
local _registry
local _initialised = false
local _overrideIndex = {}  -- fullType -> { basePrice, isLuxury }

---------------------------------------------------------------
-- Built-in definition file paths
---------------------------------------------------------------

local BUILTIN_PATHS = {
    "Definitions/ItemValues/survival_critical",
    "Definitions/ItemValues/medicine",
    "Definitions/ItemValues/firearms",
    "Definitions/ItemValues/ammunition",
    "Definitions/ItemValues/tools",
    "Definitions/ItemValues/literature",
    "Definitions/ItemValues/communication",
    "Definitions/ItemValues/luxury",
    "Definitions/ItemValues/food",
    "Definitions/ItemValues/clothing",
    "Definitions/ItemValues/miscellaneous",
}

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

--- Load a single definition file containing an array of entries.
--- Each file returns { schemaVersion, entries = { ... } }.
--- @param path string require()-able path
local function loadDefinitionFile(path)
    local ok, data = pcall(require, path)
    if not ok or type(data) ~= "table" then
        PhobosLib.warn("POS", _TAG, "Failed to load definition: " .. tostring(path))
        return 0, 0
    end

    local entries = data.entries
    if type(entries) ~= "table" then
        PhobosLib.warn("POS", _TAG, "No 'entries' array in: " .. tostring(path))
        return 0, 0
    end

    local loaded = 0
    local failed = 0
    for _, entry in ipairs(entries) do
        -- Inherit schemaVersion from wrapper if not set on entry
        if not entry.schemaVersion then
            entry.schemaVersion = data.schemaVersion or 1
        end
        local regOk = _registry:register(entry)
        if regOk then
            loaded = loaded + 1
        else
            failed = failed + 1
        end
    end

    return loaded, failed
end

--- Build the fast O(1) lookup index from all registered entries.
local function rebuildIndex()
    _overrideIndex = {}
    local all = _registry:getAll()
    for _, entry in ipairs(all) do
        _overrideIndex[entry.id] = {
            basePrice = entry.basePrice,
            isLuxury  = entry.isLuxury or false,
        }
    end
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Initialise the item value override registry.
--- Called from POS_ItemPool.init() before the ScriptManager scan.
function POS_ItemValueRegistry.init()
    if _initialised then return end
    _initialised = true

    -- Load schema
    _schema = require("POS_ItemValueSchema")

    -- Create registry (allowOverwrite so addon mods can adjust prices)
    _registry = PhobosLib.createRegistry({
        name           = "ItemValues",
        schema         = _schema,
        idField        = "id",
        allowOverwrite = true,
        tag            = _TAG,
    })

    -- Load built-in definition files
    local totalLoaded = 0
    local totalFailed = 0
    for _, path in ipairs(BUILTIN_PATHS) do
        local ok, err = pcall(loadDefinitionFile, path)
        if ok then
            -- err is actually the loaded count in success case
            -- but pcall returns (true, retval1, retval2)
        else
            PhobosLib.warn("POS", _TAG, "Error loading " .. path .. ": " .. tostring(err))
        end
    end

    -- Rebuild lookup index
    rebuildIndex()

    totalLoaded = _registry:count()
    PhobosLib.debug("POS", _TAG,
        "Loaded " .. totalLoaded .. " item value override(s)")
end

--- Get the override entry for a given item fullType.
--- @param fullType string  PZ item fullType (e.g. "Base.Generator")
--- @return table|nil  { basePrice = number, isLuxury = boolean } or nil
function POS_ItemValueRegistry.getOverride(fullType)
    return _overrideIndex[fullType]
end

--- Check whether a given item is flagged as luxury.
--- @param fullType string
--- @return boolean
function POS_ItemValueRegistry.isLuxury(fullType)
    local entry = _overrideIndex[fullType]
    return entry and entry.isLuxury or false
end

--- Expose the underlying registry for addon mods.
--- @return table  PhobosLib registry instance
function POS_ItemValueRegistry.getRegistry()
    return _registry
end

--- Bulk-register overrides from an array of entries.
--- Convenience for addon mods that want to register multiple items.
--- @param entries table[]  Array of { id, basePrice, isLuxury?, reason? }
function POS_ItemValueRegistry.registerOverrides(entries)
    if not _registry then
        PhobosLib.warn("POS", _TAG, "Registry not initialised; call init() first")
        return
    end
    for _, entry in ipairs(entries) do
        if not entry.schemaVersion then entry.schemaVersion = 1 end
        _registry:register(entry)
    end
    -- Rebuild index to include new entries
    rebuildIndex()
end
