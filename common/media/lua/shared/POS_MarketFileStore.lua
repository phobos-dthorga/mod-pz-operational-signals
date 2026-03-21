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
-- File-backed storage for market observations and rolling
-- closes. Replaces Global ModData as the authoritative store
-- for server/SP, reducing save file I/O and MP sync overhead.
--
-- File format: section-header based, pipe-delimited fields.
-- See plan Appendix A for full format specification.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MarketFileStore = {}

local _TAG = "[POS:MktFile]"

---------------------------------------------------------------
-- Session cache and dirty flag
---------------------------------------------------------------

--- { [catId] = { observations = {}, rollingCloses = {} } }
local cache = {}

--- Set true when addRecord modifies data; cleared on save.
local dirty = false

---------------------------------------------------------------
-- Serialisation helpers (private)
---------------------------------------------------------------

local SEP = POS_Constants.CACHE_FILE_SEPARATOR  -- "|"
local ITEM_SEP = POS_Constants.MARKET_FILE_ITEM_SEP  -- ";"
local KV_SEP = POS_Constants.MARKET_FILE_ITEM_KV_SEP  -- ":"

--- Serialize an items array to a flat string.
--- { {fullType="Base.Axe", price=5.5}, ... } → "Base.Axe:5.50;Base.Hammer:3.20"
---@param items table[] Array of {fullType, price}
---@return string
local function serializeItems(items)
    if not items or #items == 0 then return "" end
    local parts = {}
    for _, item in ipairs(items) do
        if item.fullType and item.price then
            parts[#parts + 1] = tostring(item.fullType) .. KV_SEP
                .. string.format("%.2f", item.price)
        end
    end
    return table.concat(parts, ITEM_SEP)
end

--- Deserialize a flat string back to an items array.
---@param str string
---@return table[]
local function deserializeItems(str)
    if not str or str == "" then return nil end
    local items = {}
    local pairs_ = PhobosLib.split(str, ITEM_SEP)
    if not pairs_ then return nil end
    for _, pair in ipairs(pairs_) do
        local kv = PhobosLib.split(pair, KV_SEP)
        if kv and #kv >= 2 then
            items[#items + 1] = {
                fullType = kv[1],
                price = tonumber(kv[2]) or 0,
            }
        end
    end
    return #items > 0 and items or nil
end

--- Build one pipe-delimited line from an observation table.
--- 10 fields: id|day|price|stock|source|location|confidence|sourceTier|quality|items
---@param obs table Observation record
---@return string
local function serializeObservation(obs)
    return table.concat({
        tostring(obs.id or ""),
        tostring(obs.day or 0),
        string.format("%.2f", obs.price or 0),
        tostring(obs.stock or ""),
        tostring(obs.source or ""),
        tostring(obs.location or ""),
        tostring(obs.confidence or 0),
        tostring(obs.sourceTier or ""),
        tostring(obs.quality or 0),
        serializeItems(obs.items),
    }, SEP)
end

--- Parse one pipe-delimited line back to an observation table.
---@param line string
---@return table|nil
local function deserializeObservation(line)
    local parts = PhobosLib.split(line, SEP)
    if not parts or #parts < 9 then return nil end
    local obs = {
        id = parts[1],
        day = tonumber(parts[2]) or 0,
        price = tonumber(parts[3]) or 0,
        stock = parts[4] ~= "" and parts[4] or nil,
        source = parts[5] ~= "" and parts[5] or nil,
        location = parts[6] ~= "" and parts[6] or nil,
        confidence = tonumber(parts[7]) or 0,
        sourceTier = parts[8] ~= "" and parts[8] or nil,
        quality = tonumber(parts[9]) or 0,
    }
    -- Field 10: items (optional, may be empty or absent)
    if parts[10] and parts[10] ~= "" then
        obs.items = deserializeItems(parts[10])
    end
    return obs
end

---------------------------------------------------------------
-- File I/O
---------------------------------------------------------------

--- Load all market data from the .dat file into the session cache.
--- Called once during bootstrap. Non-destructive: merges with
--- any data already in cache (e.g., from migration).
function POS_MarketFileStore.load()
    local reader = getFileReader(POS_Constants.MARKET_DATA_FILE, false)
    if not reader then
        PhobosLib.debug("POS", _TAG,
            "No market data file found — starting with empty cache")
        return
    end

    local currentCatId = nil
    local currentSection = nil
    local loadedCats = 0
    local loadedObs = 0

    local line = reader:readLine()
    while line do
        -- Check for category header: [CATEGORY:fuel]
        if string.sub(line, 1, #POS_Constants.MARKET_FILE_SECTION_PREFIX)
                == POS_Constants.MARKET_FILE_SECTION_PREFIX then
            local catId = string.sub(line,
                #POS_Constants.MARKET_FILE_SECTION_PREFIX + 1,
                #line - #POS_Constants.MARKET_FILE_SECTION_SUFFIX)
            if catId and catId ~= "" then
                currentCatId = catId
                currentSection = nil
                if not cache[catId] then
                    cache[catId] = { observations = {}, rollingCloses = {} }
                end
                loadedCats = loadedCats + 1
            end

        elseif line == POS_Constants.MARKET_FILE_OBS_HEADER then
            currentSection = "obs"

        elseif line == POS_Constants.MARKET_FILE_CLOSES_HEADER then
            currentSection = "closes"

        elseif currentCatId and currentSection and line ~= "" then
            if currentSection == "obs" then
                local obs = deserializeObservation(line)
                if obs then
                    table.insert(cache[currentCatId].observations, obs)
                    loadedObs = loadedObs + 1
                end
            elseif currentSection == "closes" then
                -- Rolling closes: single pipe-delimited line of numbers
                local nums = PhobosLib.split(line, SEP)
                if nums then
                    cache[currentCatId].rollingCloses = {}
                    for _, n in ipairs(nums) do
                        local v = tonumber(n)
                        if v then
                            table.insert(cache[currentCatId].rollingCloses, v)
                        end
                    end
                end
            end
        end

        line = reader:readLine()
    end
    reader:close()

    PhobosLib.debug("POS", _TAG,
        "Loaded market data: " .. tostring(loadedCats)
        .. " categories, " .. tostring(loadedObs) .. " observations")
end

--- Write the entire session cache to the .dat file.
--- Clears the dirty flag on success.
function POS_MarketFileStore.save()
    local writer = getFileWriter(POS_Constants.MARKET_DATA_FILE, false, false)
    if not writer then
        PhobosLib.debug("POS", _TAG,
            "Failed to open market data file for writing")
        return
    end

    local totalObs = 0
    local totalCats = 0

    for catId, catData in pairs(cache) do
        totalCats = totalCats + 1

        -- Category header
        writer:writeln(POS_Constants.MARKET_FILE_SECTION_PREFIX
            .. catId .. POS_Constants.MARKET_FILE_SECTION_SUFFIX)

        -- Observations section
        writer:writeln(POS_Constants.MARKET_FILE_OBS_HEADER)
        if catData.observations then
            for _, obs in ipairs(catData.observations) do
                writer:writeln(serializeObservation(obs))
                totalObs = totalObs + 1
            end
        end

        -- Rolling closes section
        writer:writeln(POS_Constants.MARKET_FILE_CLOSES_HEADER)
        if catData.rollingCloses and #catData.rollingCloses > 0 then
            local nums = {}
            for _, v in ipairs(catData.rollingCloses) do
                nums[#nums + 1] = string.format("%.2f", v)
            end
            writer:writeln(table.concat(nums, SEP))
        end
    end

    writer:close()
    dirty = false

    PhobosLib.debug("POS", _TAG,
        "Saved market data: " .. tostring(totalCats)
        .. " categories, " .. tostring(totalObs) .. " observations")
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
        cache[catId] = { observations = {}, rollingCloses = {} }
    end
    return cache[catId]
end

--- Return the entire cache table for iteration.
---@return table { [catId] = { observations, rollingCloses } }
function POS_MarketFileStore.getAllCategories()
    return cache
end

--- Mark the cache as dirty (data has changed since last save).
function POS_MarketFileStore.markDirty()
    dirty = true
end

--- Check if the cache has unsaved changes.
---@return boolean
function POS_MarketFileStore.isDirty()
    return dirty
end

--- Reset the session cache (for testing or disconnect).
function POS_MarketFileStore.clearCache()
    cache = {}
    dirty = false
    PhobosLib.debug("POS", _TAG, "Session cache cleared")
end
