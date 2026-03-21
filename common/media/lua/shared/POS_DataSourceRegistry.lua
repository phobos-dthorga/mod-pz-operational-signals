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
-- POS_DataSourceRegistry.lua
-- Formal data source interface for the Data-Recorder pipeline.
-- Sources register with canRecord/getSignalQuality/generateChunk
-- callbacks. The recorder queries available sources during scan.
---------------------------------------------------------------

require "POS_Constants"

POS_DataSourceRegistry = {}

local _TAG = "[POS:DataSrcReg]"

local sources = {}

--- Register a data source that can feed chunks to the Data-Recorder.
--- @param def table {
---   id: string,                          -- unique source identifier
---   type: string,                        -- DATA_SOURCE_RADIO | DATA_SOURCE_RECON | DATA_SOURCE_PASSIVE
---   displayNameKey: string,              -- translation key for UI display
---   canRecord: function(player, item),   -- returns boolean: is this source active and recordable?
---   getSignalQuality: function(player, item), -- returns number: BPS confidence modifier
---   generateChunk: function(player, item),    -- returns table: chunk data or nil
--- }
function POS_DataSourceRegistry.register(def)
    if not def or not def.id then
        PhobosLib.debug("POS", _TAG, "register: missing id")
        return false
    end
    if sources[def.id] then
        PhobosLib.debug("POS", _TAG, "register: duplicate id '" .. def.id .. "'")
        return false
    end
    sources[def.id] = {
        id             = def.id,
        type           = def.type or POS_Constants.DATA_SOURCE_PASSIVE,
        displayNameKey = def.displayNameKey or "",
        canRecord      = def.canRecord or function() return false end,
        getSignalQuality = def.getSignalQuality or function() return 0 end,
        generateChunk  = def.generateChunk or function() return nil end,
    }
    PhobosLib.debug("POS", _TAG, "registered source: " .. def.id)
    return true
end

--- Get a registered source by ID.
function POS_DataSourceRegistry.get(id)
    return sources[id]
end

--- Get all registered sources.
function POS_DataSourceRegistry.getAll()
    local result = {}
    for _, src in pairs(sources) do
        result[#result + 1] = src
    end
    return result
end

--- Get sources that are currently available for a given player.
--- Calls each source's canRecord() to filter.
function POS_DataSourceRegistry.getAvailableSources(player)
    if not player then return {} end
    local result = {}
    for _, src in pairs(sources) do
        local ok, canRec = pcall(src.canRecord, player, nil)
        if ok and canRec then
            result[#result + 1] = src
        end
    end
    return result
end

--- Get sources compatible with a specific recorder instance.
--- Checks canRecord with the recorder's context.
function POS_DataSourceRegistry.getSourcesForRecorder(player, recorder)
    if not player or not recorder then return {} end
    local result = {}
    for _, src in pairs(sources) do
        local ok, canRec = pcall(src.canRecord, player, recorder)
        if ok and canRec then
            result[#result + 1] = src
        end
    end
    return result
end

--- Get sources filtered by type category.
function POS_DataSourceRegistry.getByType(sourceType)
    local result = {}
    for _, src in pairs(sources) do
        if src.type == sourceType then
            result[#result + 1] = src
        end
    end
    return result
end
