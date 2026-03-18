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

local categories = {}
local dataProviders = {}

--- Register a commodity category for the market system.
--- @param def table { id (string), labelKey (string), sortOrder (number), shouldShow (function|nil) }
function POS_MarketRegistry.registerCategory(def)
    assert(type(def) == "table", "registerCategory: definition must be a table")
    assert(type(def.id) == "string", "registerCategory: 'id' is required")
    assert(type(def.labelKey) == "string", "registerCategory: 'labelKey' is required")

    if categories[def.id] then
        PhobosLib.debug("POS", "[POS:MarketReg]", "Duplicate category: " .. def.id)
        return
    end

    categories[def.id] = {
        id = def.id,
        labelKey = def.labelKey,
        sortOrder = def.sortOrder or 1000,
        shouldShow = def.shouldShow,
    }

    PhobosLib.debug("POS", "[POS:MarketReg]", "Registered category: " .. def.id)
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

    PhobosLib.debug("POS", "[POS:MarketReg]",
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

POS_MarketRegistry.registerCategory({ id = "fuel",       labelKey = "UI_POS_Market_Cat_Fuel",       sortOrder = 10 })
POS_MarketRegistry.registerCategory({ id = "medicine",   labelKey = "UI_POS_Market_Cat_Medicine",   sortOrder = 20 })
POS_MarketRegistry.registerCategory({ id = "food",       labelKey = "UI_POS_Market_Cat_Food",       sortOrder = 30 })
POS_MarketRegistry.registerCategory({ id = "ammunition", labelKey = "UI_POS_Market_Cat_Ammunition", sortOrder = 40 })
POS_MarketRegistry.registerCategory({ id = "tools",      labelKey = "UI_POS_Market_Cat_Tools",      sortOrder = 50 })
POS_MarketRegistry.registerCategory({ id = "radio",      labelKey = "UI_POS_Market_Cat_Radio",      sortOrder = 60 })

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
