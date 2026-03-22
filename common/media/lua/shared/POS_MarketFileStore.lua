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
-- POS_MarketFileStore.lua
-- World ModData-backed storage for market observations and
-- rolling closes.  Data lives in the POSNET.MarketData Global
-- ModData container and is persisted automatically by PZ's
-- save system.
--
-- Public API is unchanged from the previous file-backed version
-- so callers (POS_MarketDatabase, POS_EconomyTick, etc.) do not
-- need modifications.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MarketFileStore = {}

local _TAG = "[POS:MktFile]"

---------------------------------------------------------------
-- Local cache reference (points directly to ModData table)
---------------------------------------------------------------

--- { [catId] = { observations = {}, rollingCloses = {}, aggregate = {} } }
--- After load(), this points to getMarketData().categories.
local cache = {}

---------------------------------------------------------------
-- Load / Save
---------------------------------------------------------------

--- Bind the local cache to the world ModData categories table.
--- Called once during bootstrap after POS_WorldState creates
--- the container.  If ModData is not yet available (edge case),
--- falls back to an empty table that will be replaced on the
--- next call.
function POS_MarketFileStore.load()
    if POS_WorldState and POS_WorldState.getMarketData then
        local md = POS_WorldState.getMarketData()
        md.categories = md.categories or {}
        cache = md.categories
    else
        cache = {}
    end

    -- Count for debug log
    local cats = 0
    local obs = 0
    for _, catData in pairs(cache) do
        cats = cats + 1
        if catData.observations then
            obs = obs + #catData.observations
        end
    end

    PhobosLib.debug("POS", _TAG,
        "Loaded market data from ModData: " .. tostring(cats)
        .. " categories, " .. tostring(obs) .. " observations")
end

--- No-op.  ModData is persisted automatically by PZ's save
--- system.  Retained for API compatibility.
function POS_MarketFileStore.save()
    -- ModData auto-persists; nothing to do.
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Get (or auto-create) the category data for a given category ID.
--- Returns a table with { observations = {}, rollingCloses = {} }.
---@param catId string
---@return table
function POS_MarketFileStore.getCategory(catId)
    if not cache[catId] then
        cache[catId] = { observations = {}, rollingCloses = {}, aggregate = {} }
    end
    return cache[catId]
end

--- Return the entire cache table for iteration.
---@return table { [catId] = { observations, rollingCloses } }
function POS_MarketFileStore.getAllCategories()
    return cache
end

--- No-op.  Retained for API compatibility.  ModData mutations
--- are automatically persisted so dirty tracking is unnecessary.
function POS_MarketFileStore.markDirty()
    -- no-op
end

--- Always returns false.  Retained for API compatibility.
---@return boolean
function POS_MarketFileStore.isDirty()
    return false
end

--- Re-bind cache to ModData (useful after a world reset).
function POS_MarketFileStore.clearCache()
    if POS_WorldState and POS_WorldState.getMarketData then
        local md = POS_WorldState.getMarketData()
        md.categories = md.categories or {}
        cache = md.categories
    else
        cache = {}
    end
    PhobosLib.debug("POS", _TAG, "Session cache re-bound to ModData")
end

---------------------------------------------------------------
-- Chunked save stubs (no-ops, retained for API compatibility)
---------------------------------------------------------------

--- No-op.  Retained so callers that guard-check this function
--- do not need changes.
---@return boolean Always false
function POS_MarketFileStore.startChunkedSave()
    return false
end

--- No-op.
---@return boolean Always false
function POS_MarketFileStore.tickChunkedSave()
    return false
end

--- Always returns false.
---@return boolean
function POS_MarketFileStore.isChunkedSaveInProgress()
    return false
end
