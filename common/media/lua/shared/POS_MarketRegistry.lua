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
-- POS_MarketRegistry.lua
-- Registry for commodity categories and data providers.
-- NOT the same as POS_Registry (which handles screens).
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MarketRegistry = POS_MarketRegistry or {}

local _TAG = "[POS:MarketReg]"

local categories = {}
local subCategories = {}
local dataProviders = {}

--- Register a commodity category for the market system.
--- @param def table { id, labelKey, sortOrder, shouldShow, weight, volatility, broadcastFrequencyMult, isEssential }
function POS_MarketRegistry.registerCategory(def)
    assert(type(def) == "table", "registerCategory: definition must be a table")
    assert(type(def.id) == "string", "registerCategory: 'id' is required")
    assert(type(def.labelKey) == "string", "registerCategory: 'labelKey' is required")

    if categories[def.id] then
        PhobosLib.debug("POS", _TAG, "Duplicate category: " .. def.id)
        return
    end

    categories[def.id] = {
        id = def.id,
        labelKey = def.labelKey,
        sortOrder = def.sortOrder or 1000,
        shouldShow = def.shouldShow,
        weight = def.weight or 1.0,
        volatility = def.volatility or 1.0,
        broadcastFrequencyMult = def.broadcastFrequencyMult or 1.0,
        isEssential = def.isEssential or false,
    }

    PhobosLib.debug("POS", _TAG, "Registered category: " .. def.id)
end

--- Register a sub-category within a parent commodity category.
--- @param def table { id, parentCategory, labelKey, weight, displayCategories, namePatterns }
function POS_MarketRegistry.registerSubCategory(def)
    assert(type(def) == "table", "registerSubCategory: definition must be a table")
    assert(type(def.id) == "string", "registerSubCategory: 'id' is required")
    assert(type(def.parentCategory) == "string", "registerSubCategory: 'parentCategory' is required")

    if not subCategories[def.parentCategory] then
        subCategories[def.parentCategory] = {}
    end

    subCategories[def.parentCategory][def.id] = {
        id = def.id,
        parentCategory = def.parentCategory,
        labelKey = def.labelKey or ("UI_POS_Market_SubCat_" .. def.id),
        weight = def.weight or 1.0,
        displayCategories = def.displayCategories,
        namePatterns = def.namePatterns,
    }

    PhobosLib.debug("POS", _TAG,
        "Registered sub-category '" .. def.id .. "' under '" .. def.parentCategory .. "'")
end

--- Get all sub-categories for a parent category.
--- @param categoryId string
--- @return table[] Array of sub-category definitions
function POS_MarketRegistry.getSubCategories(categoryId)
    local subs = subCategories[categoryId]
    if not subs then return {} end
    local result = {}
    for _, sub in pairs(subs) do
        table.insert(result, sub)
    end
    return result
end

--- Get visible sub-categories for a parent category (filtered by context).
--- @param categoryId string
--- @param ctx table|nil Context with sandbox/player info
--- @return table[] Filtered array of sub-category definitions
function POS_MarketRegistry.getVisibleSubCategories(categoryId, ctx)
    local allSubs = POS_MarketRegistry.getSubCategories(categoryId)
    if not ctx then return allSubs end

    local result = {}
    for _, sub in ipairs(allSubs) do
        -- Sub-categories are visible by default; extend filtering here as needed
        table.insert(result, sub)
    end
    return result
end

--- Get the weight for a category (checks sandbox override first).
--- @param categoryId string
--- @return number
function POS_MarketRegistry.getCategoryWeight(categoryId)
    -- Check sandbox override
    if POS_Sandbox and POS_Sandbox.getCategoryWeight then
        local override = POS_Sandbox.getCategoryWeight(categoryId)
        if override then return override end
    end
    local cat = categories[categoryId]
    return cat and cat.weight or 1.0
end

--- Get the volatility for a category.
--- @param categoryId string
--- @return number
function POS_MarketRegistry.getCategoryVolatility(categoryId)
    local cat = categories[categoryId]
    return cat and cat.volatility or 1.0
end

--- Register a data provider for a commodity category.
--- Third-party mods can inject custom data sources.
--- @param categoryId string
--- @param provider table { id (string), getRecords (function(ctx) -> table[]) }
function POS_MarketRegistry.registerDataProvider(categoryId, provider)
    assert(type(categoryId) == "string", "registerDataProvider: categoryId required")
    assert(type(provider) == "table", "registerDataProvider: provider must be a table")
    assert(type(provider.id) == "string", "registerDataProvider: provider.id required")

    if not dataProviders[categoryId] then
        dataProviders[categoryId] = {}
    end
    dataProviders[categoryId][provider.id] = provider

    PhobosLib.debug("POS", _TAG,
        "Registered data provider '" .. provider.id .. "' for category '" .. categoryId .. "'")
end

--- Get all visible commodity categories for the given context.
--- @param ctx table|nil Context with sandbox/player info
--- @return table[] Sorted array of category definitions
function POS_MarketRegistry.getVisibleCategories(ctx)
    local result = {}
    for _, cat in pairs(categories) do
        local visible = (not cat.shouldShow) or cat.shouldShow(ctx or {})
        if visible then
            table.insert(result, cat)
        end
    end
    table.sort(result, function(a, b)
        return (a.sortOrder or 1000) < (b.sortOrder or 1000)
    end)
    return result
end

--- Get a category definition by ID.
--- @param categoryId string
--- @return table|nil
function POS_MarketRegistry.getCategory(categoryId)
    return categories[categoryId]
end

--- Get all data providers for a category.
--- @param categoryId string
--- @return table[] Array of provider definitions
function POS_MarketRegistry.getProviders(categoryId)
    local providers = dataProviders[categoryId]
    if not providers then return {} end
    local result = {}
    for _, p in pairs(providers) do
        table.insert(result, p)
    end
    return result
end

--- Get all registered category IDs (for debugging).
--- @return string[]
function POS_MarketRegistry.getAllCategoryIds()
    local ids = {}
    for id, _ in pairs(categories) do
        table.insert(ids, id)
    end
    table.sort(ids)
    return ids
end

---------------------------------------------------------------
-- Default commodity categories
---------------------------------------------------------------

POS_MarketRegistry.registerCategory({ id = "fuel",       labelKey = "UI_POS_Market_Cat_Fuel",       sortOrder = 10, weight = 1.5, volatility = 1.3, broadcastFrequencyMult = 1.2, isEssential = true })
POS_MarketRegistry.registerCategory({ id = "medicine",   labelKey = "UI_POS_Market_Cat_Medicine",   sortOrder = 20, weight = 1.4, volatility = 0.8, broadcastFrequencyMult = 1.1, isEssential = true })
POS_MarketRegistry.registerCategory({ id = "weapons",    labelKey = "UI_POS_Market_Cat_Weapons",    sortOrder = 25, weight = 1.1, volatility = 1.2, isEssential = false })
POS_MarketRegistry.registerCategory({ id = "food",       labelKey = "UI_POS_Market_Cat_Food",       sortOrder = 30, weight = 1.0, volatility = 1.0, broadcastFrequencyMult = 1.0, isEssential = true })
POS_MarketRegistry.registerCategory({ id = "survival",   labelKey = "UI_POS_Market_Cat_Survival",   sortOrder = 35, weight = 0.8, volatility = 0.9, isEssential = false })
POS_MarketRegistry.registerCategory({ id = "ammunition", labelKey = "UI_POS_Market_Cat_Ammunition", sortOrder = 40, weight = 1.3, volatility = 1.5, broadcastFrequencyMult = 0.8, isEssential = false })
POS_MarketRegistry.registerCategory({ id = "tools",      labelKey = "UI_POS_Market_Cat_Tools",      sortOrder = 50, weight = 0.9, volatility = 0.7, broadcastFrequencyMult = 0.7, isEssential = false })
POS_MarketRegistry.registerCategory({ id = "clothing",   labelKey = "UI_POS_Market_Cat_Clothing",   sortOrder = 55, weight = 0.5, volatility = 0.5, isEssential = false })
POS_MarketRegistry.registerCategory({ id = "radio",      labelKey = "UI_POS_Market_Cat_Radio",      sortOrder = 60, weight = 0.6, volatility = 1.0, broadcastFrequencyMult = 0.5, isEssential = false })
POS_MarketRegistry.registerCategory({ id = "literature", labelKey = "UI_POS_Market_Cat_Literature", sortOrder = 65, weight = 0.3, volatility = 0.3, isEssential = false })
POS_MarketRegistry.registerCategory({ id = "miscellaneous", labelKey = "UI_POS_Market_Cat_Misc",    sortOrder = 99, weight = 0.1, volatility = 0.5, isEssential = false })

---------------------------------------------------------------
-- Screen navigation categories (registered when POS_API available)
---------------------------------------------------------------

local function registerScreenCategories()
    if POS_API and POS_API.registerCategory then
        POS_API.registerCategory({
            id = "pos.markets",
            parent = "pos.main",
            titleKey = "UI_POS_Markets_Title",
            sortOrder = 40,
        })
        POS_API.registerCategory({
            id = "pos.exchange",
            parent = "pos.main",
            titleKey = "UI_POS_Exchange_Title",
            sortOrder = 50,
        })
    end
end

-- Defer to OnGameStart so POS_API is available
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(registerScreenCategories)
end
