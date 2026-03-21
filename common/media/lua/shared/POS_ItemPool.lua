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
-- POS_ItemPool.lua
-- Manages the pool of tradeable items by querying PZ's
-- ScriptManager at runtime, mapping DisplayCategory to
-- commodity categories with weights and sub-categories.
---------------------------------------------------------------

require "POS_Constants"

POS_ItemPool = {}

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

local pool = {}          -- categoryId -> { item, item, ... }
local subPool = {}       -- subCategoryId -> { item, item, ... }
local itemIndex = {}     -- fullType -> item record
local initialised = false

---------------------------------------------------------------
-- DisplayCategory -> Commodity category mapping
---------------------------------------------------------------

local function getCategoryWeight(categoryId)
    if POS_MarketRegistry and POS_MarketRegistry.getCategoryWeight then
        return POS_MarketRegistry.getCategoryWeight(categoryId)
    end
    return 1.0
end

local DISPLAY_CATEGORY_MAP = {
    FirstAid            = "medicine",
    Wound               = "medicine",
    Bandage             = "medicine",
    Food                = "food",
    Cooking             = "food",
    CookingWeapon       = "food",
    Ammo                = "ammunition",
    Explosives          = "ammunition",
    WeaponPart          = "ammunition",
    Tool                = "tools",
    ToolWeapon          = "tools",
    Material            = "tools",
    RecipeResource      = "tools",
    VehicleMaintenance  = "tools",
    Gardening           = "tools",
    Electronics         = "radio",
    Communications      = "radio",
    LightSource         = "radio",
    Camping             = "survival",
    Fishing             = "survival",
    Trapping            = "survival",
    WaterContainer      = "survival",
    Weapon              = "weapons",
    WeaponCrafted       = "weapons",
    Clothing            = "clothing",
    ProtectiveGear      = "clothing",
    Literature          = "literature",
    SkillBook           = "literature",
    Cartography         = "literature",
}

---------------------------------------------------------------
-- Fuel detection patterns (no direct DisplayCategory)
---------------------------------------------------------------

local FUEL_PATTERNS = {
    "Gasoline", "Petrol", "Propane", "Kerosene", "MotorOil", "FuelCan",
}

---------------------------------------------------------------
-- Sub-category definitions
---------------------------------------------------------------

local SUB_CATEGORY_DEFS = {
    -- ammunition
    {
        id = "rifle_ammo",
        parentCategory = "ammunition",
        labelKey = "UI_POS_SubCat_RifleAmmo",
        weight = 1.3,
        displayCategories = { "Ammo" },
        namePatterns = { "Rifle", "308", "223", "3030", "556" },
    },
    {
        id = "shotgun_ammo",
        parentCategory = "ammunition",
        labelKey = "UI_POS_SubCat_ShotgunAmmo",
        weight = 1.2,
        displayCategories = { "Ammo" },
        namePatterns = { "Shotgun", "Gauge" },
    },
    {
        id = "pistol_ammo",
        parentCategory = "ammunition",
        labelKey = "UI_POS_SubCat_PistolAmmo",
        weight = 1.0,
        displayCategories = { "Ammo" },
        namePatterns = { "Pistol", "9mm", "45", "38" },
    },
    {
        id = "explosives",
        parentCategory = "ammunition",
        labelKey = "UI_POS_SubCat_Explosives",
        weight = 0.8,
        displayCategories = { "Explosives" },
        namePatterns = nil,
    },
    -- medicine
    {
        id = "first_aid",
        parentCategory = "medicine",
        labelKey = "UI_POS_SubCat_FirstAid",
        weight = 1.5,
        displayCategories = { "FirstAid" },
        namePatterns = nil,
    },
    {
        id = "bandages",
        parentCategory = "medicine",
        labelKey = "UI_POS_SubCat_Bandages",
        weight = 1.0,
        displayCategories = { "Bandage" },
        namePatterns = nil,
    },
    {
        id = "wound_care",
        parentCategory = "medicine",
        labelKey = "UI_POS_SubCat_WoundCare",
        weight = 0.8,
        displayCategories = { "Wound" },
        namePatterns = nil,
    },
    -- food
    {
        id = "canned_food",
        parentCategory = "food",
        labelKey = "UI_POS_SubCat_CannedFood",
        weight = 1.2,
        displayCategories = { "Food" },
        namePatterns = { "Canned", "TinCan" },
    },
    {
        id = "fresh_food",
        parentCategory = "food",
        labelKey = "UI_POS_SubCat_FreshFood",
        weight = 0.8,
        displayCategories = { "Food" },
        namePatterns = nil,
        requirePerishable = true,
    },
    {
        id = "dry_goods",
        parentCategory = "food",
        labelKey = "UI_POS_SubCat_DryGoods",
        weight = 1.0,
        displayCategories = { "Food" },
        namePatterns = { "Rice", "Pasta", "Flour", "Sugar", "Coffee" },
    },
    {
        id = "beverages",
        parentCategory = "food",
        labelKey = "UI_POS_SubCat_Beverages",
        weight = 0.6,
        displayCategories = { "Food" },
        namePatterns = { "Pop", "Soda", "Beer", "Wine", "Whiskey", "Water" },
    },
    -- tools
    {
        id = "hand_tools",
        parentCategory = "tools",
        labelKey = "UI_POS_SubCat_HandTools",
        weight = 1.2,
        displayCategories = { "Tool" },
        namePatterns = nil,
    },
    {
        id = "building_materials",
        parentCategory = "tools",
        labelKey = "UI_POS_SubCat_BuildingMaterials",
        weight = 1.0,
        displayCategories = { "Material" },
        namePatterns = nil,
    },
    {
        id = "vehicle_parts",
        parentCategory = "tools",
        labelKey = "UI_POS_SubCat_VehicleParts",
        weight = 0.9,
        displayCategories = { "VehicleMaintenance" },
        namePatterns = nil,
    },
    {
        id = "gardening",
        parentCategory = "tools",
        labelKey = "UI_POS_SubCat_Gardening",
        weight = 0.7,
        displayCategories = { "Gardening" },
        namePatterns = nil,
    },
    -- weapons
    {
        id = "firearms",
        parentCategory = "weapons",
        labelKey = "UI_POS_SubCat_Firearms",
        weight = 1.3,
        displayCategories = { "Weapon" },
        namePatterns = { "Pistol", "Rifle", "Shotgun" },
    },
    {
        id = "melee",
        parentCategory = "weapons",
        labelKey = "UI_POS_SubCat_Melee",
        weight = 0.8,
        displayCategories = { "Weapon", "ToolWeapon" },
        namePatterns = nil,
        excludePatterns = { "Pistol", "Rifle", "Shotgun" },
    },
    {
        id = "crafted",
        parentCategory = "weapons",
        labelKey = "UI_POS_SubCat_CraftedWeapons",
        weight = 0.6,
        displayCategories = { "WeaponCrafted" },
        namePatterns = nil,
    },
}

---------------------------------------------------------------
-- Base price multipliers per category
---------------------------------------------------------------

local CATEGORY_PRICE_MULTIPLIERS = POS_Constants.CATEGORY_PRICE_MULTIPLIERS

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

--- Check whether a fullType matches any of the fuel identification patterns.
--- @param fullType string
--- @return boolean
local function isFuelItem(fullType)
    for _, pattern in ipairs(FUEL_PATTERNS) do
        if string.find(fullType, pattern, 1, true) then
            return true
        end
    end
    return false
end

--- Determine the commodity category for a given DisplayCategory and fullType.
--- @param displayCat string|nil
--- @param fullType string
--- @return string categoryId
local function resolveCommodityCategory(displayCat, fullType)
    -- Fuel items have no dedicated DisplayCategory; detect by name pattern
    if isFuelItem(fullType) then
        return "fuel"
    end
    if displayCat and DISPLAY_CATEGORY_MAP[displayCat] then
        return DISPLAY_CATEGORY_MAP[displayCat]
    end
    -- Catch weapon-derived display categories (e.g. AxeWeapon, SpearWeapon)
    if displayCat and string.find(displayCat, "Weapon", 1, true) then
        return "weapons"
    end
    return "miscellaneous"
end

--- Check whether a fullType matches any pattern in a list.
--- @param fullType string
--- @param patterns string[]|nil
--- @return boolean
local function matchesAnyPattern(fullType, patterns)
    if not patterns then return false end
    for _, pat in ipairs(patterns) do
        if string.find(fullType, pat, 1, true) then
            return true
        end
    end
    return false
end

--- Determine the sub-category for an item.
--- @param fullType string
--- @param displayCat string|nil
--- @param categoryId string
--- @param isPerishable boolean
--- @return string|nil subCategoryId
local function resolveSubCategory(fullType, displayCat, categoryId, isPerishable)
    for _, def in ipairs(SUB_CATEGORY_DEFS) do
        if def.parentCategory == categoryId then
            -- Check excludePatterns first
            if def.excludePatterns and matchesAnyPattern(fullType, def.excludePatterns) then
                -- skip this sub-category
            else
                local dcMatch = false
                if def.displayCategories then
                    for _, dc in ipairs(def.displayCategories) do
                        if dc == displayCat then
                            dcMatch = true
                            break
                        end
                    end
                end

                if dcMatch then
                    -- If namePatterns specified, item must match at least one
                    if def.namePatterns then
                        if matchesAnyPattern(fullType, def.namePatterns) then
                            return def.id
                        end
                    elseif def.requirePerishable then
                        if isPerishable then
                            return def.id
                        end
                    else
                        return def.id
                    end
                end
            end
        end
    end
    return nil
end

--- Calculate the base price for an item record.
--- @param itemWeight number
--- @param categoryId string
--- @param hasCondition boolean
--- @return number
local function calculateBasePrice(itemWeight, categoryId, hasCondition)
    local w = itemWeight or 1.0
    local catMult = CATEGORY_PRICE_MULTIPLIERS[categoryId] or 1.0
    local condMult = hasCondition and POS_Constants.ITEM_POOL_CONDITION_MULTIPLIER or 1.0
    return math.max(
        POS_Constants.ITEM_POOL_MIN_BASE_PRICE,
        w * POS_Constants.ITEM_POOL_WEIGHT_MULTIPLIER * catMult * condMult
    )
end

--- Insert an item record into the appropriate pool tables.
--- @param record table
local function indexItem(record)
    local catId = record.commodityCategory
    if not pool[catId] then pool[catId] = {} end
    pool[catId][#pool[catId] + 1] = record

    if record.subCategory then
        if not subPool[record.subCategory] then subPool[record.subCategory] = {} end
        subPool[record.subCategory][#subPool[record.subCategory] + 1] = record
    end

    itemIndex[record.fullType] = record
end

---------------------------------------------------------------
-- Lazy bootstrap — deferred to first access instead of OnGameStart.
-- Iterating all base items (~2000+) is the most expensive single
-- operation in POSnet's init; deferring it moves the cost from
-- frame 0 to first market terminal open or mission generation.
---------------------------------------------------------------

local ensureInit  -- forward declaration; assigned after init() below

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Initialise the item pool by scanning all items via ScriptManager.
--- Safe to call multiple times; subsequent calls are no-ops.
function POS_ItemPool.init()
    if initialised then return end

    local sm = ScriptManager.instance
    if not sm then return end

    local allItems = sm:getAllItems()
    if not allItems then return end

    for i = 0, allItems:size() - 1 do
        local script = allItems:get(i)
        if script then
            -- Only include vanilla (Base) items by default
            -- Cross-mod items are registered separately via registerItem()
            local moduleName = nil
            pcall(function() moduleName = script:getModule() and script:getModule():getName() end)
            if moduleName and moduleName ~= "Base" then
                -- Skip: non-vanilla items use registerItem() for cross-mod support
            else
                local fullType    = script:getFullName()
                local displayCat  = script:getDisplayCategory()
                local itemWeight  = script:getActualWeight()
                local condMax     = script:getConditionMax()
                local daysFresh   = script:getDaysFresh()
                local daysRotten  = script:getDaysTotallyRotten()
                local isPerishable = (daysFresh and daysFresh > 0)
                    or (daysRotten and daysRotten > 0)

                local categoryId = resolveCommodityCategory(displayCat, fullType)
                local subCatId   = resolveSubCategory(fullType, displayCat, categoryId, isPerishable)
                local hasCondition = condMax and condMax > 0
                local basePrice  = calculateBasePrice(itemWeight, categoryId, hasCondition)

                local record = {
                    fullType         = fullType,
                    displayCategory  = displayCat,
                    commodityCategory = categoryId,
                    subCategory      = subCatId,
                    weight           = itemWeight,
                    conditionMax     = condMax,
                    basePrice        = basePrice,
                }

                indexItem(record)
            end
        end
    end

    initialised = true
end

--- Return all item records for a given commodity category.
--- @param categoryId string
--- @return table[]
function POS_ItemPool.getItemsForCategory(categoryId)
    ensureInit()
    return pool[categoryId] or {}
end

--- Return all item records for a given sub-category.
--- @param subCategoryId string
--- @return table[]
function POS_ItemPool.getItemsForSubCategory(subCategoryId)
    ensureInit()
    return subPool[subCategoryId] or {}
end

--- Randomly select `count` items from a commodity category.
--- Uses PhobosLib.weightedRandom / weightedRandomMultiple when available.
--- @param categoryId string
--- @param count number
--- @param ctx table|nil  Optional context (unused currently, reserved for future filtering)
--- @return table[]
function POS_ItemPool.selectItems(categoryId, count, ctx)
    ensureInit()
    local items = pool[categoryId]
    if not items or #items == 0 then return {} end

    -- Off-category chance: small probability of pulling from a random other category
    if ctx and ZombRand then
        local roll = ZombRand(POS_Constants.ITEM_POOL_WEIGHT_PRECISION)
        local threshold = POS_Constants.ITEM_POOL_OFF_CATEGORY_CHANCE
            * (POS_Constants.ITEM_POOL_WEIGHT_PRECISION / 100)
        if roll < threshold then
            -- Pick a random alternative category
            local altCategories = {}
            for catId, catItems in pairs(pool) do
                if catId ~= categoryId and #catItems > 0 then
                    altCategories[#altCategories + 1] = catId
                end
            end
            if #altCategories > 0 then
                local altCat = altCategories[ZombRand(#altCategories) + 1]
                items = pool[altCat]
            end
        end
    end

    -- Build weighted entries for selection
    local entries = {}
    for _, item in ipairs(items) do
        local catWeight = getCategoryWeight(item.commodityCategory)
        entries[#entries + 1] = {
            value = item,
            weight = math.floor(catWeight * POS_Constants.ITEM_POOL_WEIGHT_PRECISION),
        }
    end

    -- Weight accessor for entries
    local function getWeight(entry) return entry.weight or 1 end

    -- Unwrap helper: extract .value from weighted entry wrappers
    local function unwrapEntries(wrapped)
        local unwrapped = {}
        for i = 1, #wrapped do
            unwrapped[i] = wrapped[i].value or wrapped[i]
        end
        return unwrapped
    end

    -- Use PhobosLib weighted selection if available
    if PhobosLib and PhobosLib.weightedRandomMultiple and count > 1 then
        return unwrapEntries(PhobosLib.weightedRandomMultiple(entries, count, getWeight))
    elseif PhobosLib and PhobosLib.weightedRandom then
        local result = {}
        for _ = 1, count do
            local entry = PhobosLib.weightedRandom(entries, getWeight)
            result[#result + 1] = entry and entry.value or entry
        end
        return result
    end

    -- Fallback: uniform random selection
    local result = {}
    for _ = 1, count do
        result[#result + 1] = items[ZombRand(#items) + 1]
    end
    return result
end

--- Return the base price for a given fullType.
--- @param fullType string
--- @return number|nil
function POS_ItemPool.getBasePrice(fullType)
    ensureInit()
    local record = itemIndex[fullType]
    return record and record.basePrice or nil
end

--- Manually register (or override) an item in the pool.
--- Useful for cross-mod items that are not in the vanilla script database.
--- @param fullType string
--- @param categoryId string
--- @param basePrice number
function POS_ItemPool.registerItem(fullType, categoryId, basePrice)
    ensureInit()
    local existing = itemIndex[fullType]
    if existing then
        -- Remove from old pools before re-indexing
        local oldCat = existing.commodityCategory
        if pool[oldCat] then
            for j = #pool[oldCat], 1, -1 do
                if pool[oldCat][j].fullType == fullType then
                    table.remove(pool[oldCat], j)
                    break
                end
            end
        end
        if existing.subCategory and subPool[existing.subCategory] then
            for j = #subPool[existing.subCategory], 1, -1 do
                if subPool[existing.subCategory][j].fullType == fullType then
                    table.remove(subPool[existing.subCategory], j)
                    break
                end
            end
        end
    end

    local record = {
        fullType          = fullType,
        displayCategory   = nil,
        commodityCategory = categoryId,
        subCategory       = nil,
        weight            = 1.0,
        conditionMax      = nil,
        basePrice         = math.max(POS_Constants.ITEM_POOL_MIN_BASE_PRICE, basePrice),
    }
    indexItem(record)
end

--- Return the sub-category definitions for a given parent commodity category.
--- @param categoryId string
--- @return table[]
function POS_ItemPool.getSubCategories(categoryId)
    local result = {}
    for _, def in ipairs(SUB_CATEGORY_DEFS) do
        if def.parentCategory == categoryId then
            result[#result + 1] = def
        end
    end
    return result
end

--- Return the commodity category for a given fullType.
--- @param fullType string
--- @return string|nil
function POS_ItemPool.getCategoryForItem(fullType)
    ensureInit()
    local record = itemIndex[fullType]
    return record and record.commodityCategory or nil
end

ensureInit = PhobosLib.lazyInit(POS_ItemPool.init)
