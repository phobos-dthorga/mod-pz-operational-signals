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
    -- medicine (clean supplies only — Wound/Bandage are blood-soaked states)
    FirstAid            = "medicine",
    -- food
    Food                = "food",
    Cooking             = "food",
    CookingWeapon       = "food",
    -- ammunition
    Ammo                = "ammunition",
    Explosives          = "ammunition",
    WeaponPart          = "ammunition",
    -- tools
    Tool                = "tools",
    ToolWeapon          = "tools",
    Material            = "tools",
    RecipeResource      = "tools",
    VehicleMaintenance  = "automotive",
    Gardening           = "agriculture",
    Household           = "tools",
    Paint               = "tools",
    Security            = "tools",
    -- radio / electronics
    Electronics         = "radio",
    Communications      = "radio",
    LightSource         = "radio",
    -- survival
    Camping             = "survival",
    Fishing             = "survival",
    Trapping            = "survival",
    WaterContainer      = "survival",
    Bag                 = "survival",
    FireSource          = "survival",
    Water               = "survival",
    -- weapons
    Weapon              = "weapons",
    WeaponCrafted       = "weapons",
    -- clothing
    Clothing            = "clothing",
    ProtectiveGear      = "clothing",
    -- literature
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
    -- NOTE: "bandages" and "wound_care" sub-categories removed — their
    -- DisplayCategories (Bandage, Wound) are blood-soaked body states,
    -- not tradeable items. Clean bandages use DisplayCategory "FirstAid".
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
        parentCategory = "automotive",
        labelKey = "UI_POS_SubCat_VehicleParts",
        weight = 0.9,
        displayCategories = { "VehicleMaintenance" },
        namePatterns = nil,
    },
    {
        id = "gardening",
        parentCategory = "agriculture",
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

-- NOTE: Do NOT capture POS_Constants.CATEGORY_PRICE_MULTIPLIERS at load time.
-- POS_Constants_Market.lua may not have loaded yet (load order is alphabetical).
-- Resolve at call time inside calculateBasePrice() instead.

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
--- @param fullType string
--- @param hasCondition boolean
--- @return number basePrice
--- @return boolean isLuxury
local function calculateBasePrice(fullType, itemWeight, categoryId, hasCondition)
    local condMult = hasCondition and POS_Constants.ITEM_POOL_CONDITION_MULTIPLIER or 1.0

    -- Check curated override registry first (O(1) lookup)
    if POS_ItemValueRegistry then
        local override = POS_ItemValueRegistry.getOverride(fullType)
        if override then
            local price = math.max(
                POS_Constants.ITEM_POOL_MIN_BASE_PRICE,
                override.basePrice * condMult)
            return price, override.isLuxury or false
        end
    end

    -- Packaging detection (Tier 1 pricing: §59):
    -- Items ending in _Box, _Carton, _Case, _Pack, _Boxed, _Crate get their
    -- base item's price × packaging multiplier. This automatically handles
    -- bulk containers without needing per-item curation for every variant.
    local suffixes = POS_Constants.PACKAGING_SUFFIXES
    if suffixes then
        -- Extract the short name (strip module prefix, e.g. "Base.Bullets9mmBox" → "Bullets9mmBox")
        local shortName = fullType:match("%.(.+)$") or fullType
        for _, pkg in ipairs(suffixes) do
            local suf = pkg.suffix
            if shortName:sub(-#suf) == suf then
                -- Strip suffix to find base item name, reconstruct fullType
                local baseName = shortName:sub(1, -#suf - 1)
                local modulePrefix = fullType:match("^(.+%.)") or ""
                local baseFullType = modulePrefix .. baseName

                -- Try curated base item price first
                local basePrice = nil
                if POS_ItemValueRegistry then
                    local baseOverride = POS_ItemValueRegistry.getOverride(baseFullType)
                    if baseOverride then
                        basePrice = baseOverride.basePrice
                    end
                end

                -- If base item has a curated price, multiply it
                if basePrice and basePrice > 0 then
                    return math.max(
                        POS_Constants.ITEM_POOL_MIN_BASE_PRICE,
                        basePrice * pkg.mult * condMult
                    ), false
                end

                -- No curated base item — use weight fallback with packaging multiplier
                local w = itemWeight or 1.0
                local mults = POS_Constants.CATEGORY_PRICE_MULTIPLIERS
                local catMult = (mults and mults[categoryId]) or 1.0
                return math.max(
                    POS_Constants.ITEM_POOL_MIN_BASE_PRICE,
                    w * POS_Constants.ITEM_POOL_WEIGHT_MULTIPLIER * catMult * condMult * pkg.mult
                ), false
            end
        end
    end

    -- Fallback: weight-based formula with property bonuses (Tier 3: §58)
    local w = itemWeight or 1.0
    local mults = POS_Constants.CATEGORY_PRICE_MULTIPLIERS
    local catMult = (mults and mults[categoryId]) or 1.0

    -- Property-bonus: read item script data for utility-driven price differentiation.
    -- IMPORTANT: ScriptItem methods (getCalories, getMaxDamage, etc.) only exist on
    -- specific subclasses. Calling a missing method crashes PZ's Kahlua VM with a Java
    -- exception that pcall CANNOT catch. We must check method existence BEFORE calling.
    local bonus = 1.0
    local script = nil
    if ScriptManager and ScriptManager.instance and ScriptManager.instance.getItem then
        script = ScriptManager.instance:getItem(fullType)
    end
    if script then
        -- Damage bonus (weapons + tools): higher damage = more valuable
        local maxDmg = script.getMaxDamage and script:getMaxDamage() or 0
        if type(maxDmg) == "number" and maxDmg > 0 then
            bonus = bonus + (maxDmg * POS_Constants.PRICING_DAMAGE_SCALE)
        end

        -- Calorie bonus (food): higher calorie content = more survival value
        local cal = script.getCalories and script:getCalories() or 0
        if type(cal) == "number" and cal > 0 then
            local calBonus = cal / POS_Constants.PRICING_CALORIE_DIVISOR
            if calBonus > POS_Constants.PRICING_CALORIE_CAP then
                calBonus = POS_Constants.PRICING_CALORIE_CAP
            end
            bonus = bonus + calBonus
        end

        -- Medical potency bonus: pain reduction + infection treatment
        local painRed = script.getPainReduction and script:getPainReduction() or 0
        if type(painRed) == "number" and painRed > 0 then
            bonus = bonus + (painRed * POS_Constants.PRICING_PAIN_SCALE)
        end
        local infRed = script.getReduceInfectionPower and script:getReduceInfectionPower() or 0
        if type(infRed) == "number" and infRed > 0 then
            bonus = bonus + (infRed * POS_Constants.PRICING_INFECTION_SCALE)
        end

        -- Condition durability bonus: high-durability items are more valuable
        local condMax = script.getConditionMax and script:getConditionMax() or 0
        if type(condMax) == "number"
                and condMax > POS_Constants.PRICING_CONDITION_THRESHOLD then
            bonus = bonus + (condMax / POS_Constants.PRICING_CONDITION_DIVISOR)
        end

        -- Range bonus (ranged weapons): longer range = higher tactical value
        local maxRng = script.getMaxRange and script:getMaxRange() or 0
        if type(maxRng) == "number"
                and maxRng > POS_Constants.PRICING_RANGE_THRESHOLD then
            bonus = bonus + (maxRng * POS_Constants.PRICING_RANGE_SCALE)
        end
    end

    return math.max(
        POS_Constants.ITEM_POOL_MIN_BASE_PRICE,
        w * POS_Constants.ITEM_POOL_WEIGHT_MULTIPLIER * catMult * condMult * bonus
    ), false
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

    -- Load curated item value overrides before the ScriptManager scan
    -- so that calculateBasePrice() can use them during indexing.
    if POS_ItemValueRegistry then
        POS_ItemValueRegistry.init()
    end

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

                -- ── Curation filter ──────────────────────────
                -- Skip items whose DisplayCategory is blacklisted
                local excluded = false
                local excludedCats = POS_Constants.ITEM_POOL_EXCLUDED_CATEGORIES
                if excludedCats and displayCat and excludedCats[displayCat] then
                    excluded = true
                end
                -- Skip items matching blacklisted name patterns
                if not excluded and POS_Constants.ITEM_POOL_EXCLUDED_PATTERNS then
                    for _, pat in ipairs(POS_Constants.ITEM_POOL_EXCLUDED_PATTERNS) do
                        if string.find(fullType, pat, 1, true) then
                            excluded = true
                            break
                        end
                    end
                end

                if not excluded then
                    local itemWeight  = script:getActualWeight()
                    local condMax     = script:getConditionMax()
                    local daysFresh   = script:getDaysFresh()
                    local daysRotten  = script:getDaysTotallyRotten()
                    local isPerishable = (daysFresh and daysFresh > 0)
                        or (daysRotten and daysRotten > 0)

                    local categoryId = resolveCommodityCategory(displayCat, fullType)
                    local subCatId   = resolveSubCategory(fullType, displayCat, categoryId, isPerishable)
                    local hasCondition = condMax and condMax > 0
                    local basePrice, isLuxury = calculateBasePrice(fullType, itemWeight, categoryId, hasCondition)

                    local record = {
                        fullType         = fullType,
                        displayCategory  = displayCat,
                        commodityCategory = categoryId,
                        subCategory      = subCatId,
                        weight           = itemWeight,
                        conditionMax     = condMax,
                        basePrice        = basePrice,
                        isLuxury         = isLuxury,
                    }

                    indexItem(record)
                end
            end
        end
    end

    initialised = true

    -- Log pool statistics for diagnostics
    local totalIndexed = 0
    for _, items in pairs(pool) do totalIndexed = totalIndexed + #items end
    PhobosLib.debug("POS", "ItemPool", "Initialised: " .. tostring(totalIndexed) .. " items indexed from ScriptManager")
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

--- Retrieve the full item record for a given fullType.
--- Used by PriceEngine for luxury zone scaling.
--- @param fullType string
--- @return table|nil  Record with basePrice, isLuxury, commodityCategory, etc.
function POS_ItemPool.getRecord(fullType)
    ensureInit()
    return itemIndex[fullType]
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

--- Select a random subset of items from a category pool.
--- Lightweight wrapper for intel-driven item discovery.
--- @param categoryId string Commodity category ID
--- @param count number Number of items to select
--- @return table[] Array of item records (may be shorter than count)
function POS_ItemPool.selectRandomItems(categoryId, count)
    local ok, items = PhobosLib.safecall(POS_ItemPool.getItemsForCategory, categoryId)
    if not ok or not items then return {} end
    return PhobosLib.selectRandomFromPool(items, count)
end

-- Use direct guard instead of lazyInit — allows retry if init() fails
-- partway (e.g. due to load order issues with POS_Constants split files).
ensureInit = function()
    if not initialised then
        POS_ItemPool.init()
    end
end
