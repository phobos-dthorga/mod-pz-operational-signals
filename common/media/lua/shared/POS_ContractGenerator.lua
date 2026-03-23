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
-- POS_ContractGenerator.lua
-- World-state-driven contract generation.
--
-- Called from the economy tick when zone pressure exceeds the
-- generation threshold.  Shortage drives demand, demand spawns
-- contracts.  A field hospital doesn't post a contract because
-- the economy says so — it posts one because people are bleeding
-- out and the medicine ran out three days ago.
--
-- Uses POS_MissionBriefingResolver for compositional briefing
-- text with apocalypse-flavoured voice packs.
--
-- See design-guidelines.md §43.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_ContractGenerator = {}

local _TAG = "[POS:ContractGen]"

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

local _contractRegistry
local _initialised = false
local _lastGenerationDay = 0

---------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------

local BUILTIN_PATHS = {
    "Definitions/Contracts/procurement",
    "Definitions/Contracts/urgent_shortage",
    "Definitions/Contracts/standing_supply",
    "Definitions/Contracts/grey_market",
    "Definitions/Contracts/military_requisition",
    "Definitions/Contracts/arbitrage",
}

function POS_ContractGenerator.init()
    if _initialised then return end
    _initialised = true

    local schema = require("POS_ContractSchema")
    _contractRegistry = PhobosLib.createRegistry({
        name           = "Contracts",
        schema         = schema,
        idField        = "id",
        allowOverwrite = true,
        tag            = _TAG,
    })

    for _, path in ipairs(BUILTIN_PATHS) do
        local ok, data = pcall(require, path)
        if ok and type(data) == "table" then
            _contractRegistry:register(data)
        else
            PhobosLib.warn("POS", _TAG, "Failed to load contract definition: " .. tostring(path))
        end
    end

    PhobosLib.debug("POS", _TAG,
        "Loaded " .. tostring(_contractRegistry:count()) .. " contract definition(s)")
end

---------------------------------------------------------------
-- Zone pressure analysis
---------------------------------------------------------------

--- Find categories under pressure in a given zone.
--- @param zoneId string
--- @return table Array of { categoryId, pressure } sorted by pressure desc
local function findShortages(zoneId)
    local shortages = {}
    if not POS_MarketSimulation or not POS_MarketSimulation.getZonePressure then
        return shortages
    end

    local categories = POS_MarketRegistry and POS_MarketRegistry.getAllCategories
        and POS_MarketRegistry.getAllCategories() or {}

    for _, cat in ipairs(categories) do
        local ok, pressure = PhobosLib.safecall(
            POS_MarketSimulation.getZonePressure, zoneId, cat.id)
        if ok and pressure and pressure >= POS_Constants.CONTRACT_GENERATION_PRESSURE_THRESHOLD then
            shortages[#shortages + 1] = { categoryId = cat.id, pressure = pressure }
        end
    end

    table.sort(shortages, function(a, b) return a.pressure > b.pressure end)
    return shortages
end

---------------------------------------------------------------
-- Contract instance creation
---------------------------------------------------------------

--- Build a concrete contract instance from a definition + world context.
--- @param definition table Contract definition from registry
--- @param categoryId string Resolved category
--- @param zoneId string Zone where the demand originated
--- @return table|nil Contract instance ready for POS_ContractService.post()
local function buildContract(definition, categoryId, zoneId)
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0

    -- Resolve quantity
    local qtyMin = definition.quantityMin or 5
    local qtyMax = definition.quantityMax or 20
    local quantity = qtyMin + ZombRand(qtyMax - qtyMin + 1)

    -- Resolve deadline
    local dlMin = definition.deadlineDaysMin or 3
    local dlMax = definition.deadlineDaysMax or 7
    local deadlineDays = dlMin + ZombRand(dlMax - dlMin + 1)

    -- Resolve payout (bid model: base × shortage × buyer type)
    local baseValue = 0
    if POS_ItemPool and POS_ItemPool.getItemsForCategory then
        local ok, items = PhobosLib.safecall(POS_ItemPool.getItemsForCategory, categoryId)
        if ok and items and #items > 0 then
            -- Average base price across the category
            local total = 0
            for _, item in ipairs(items) do
                total = total + (item.basePrice or 1)
            end
            baseValue = total / #items
        end
    end
    if baseValue <= 0 then baseValue = 10 end

    local payMin = definition.payMultiplierMin or 1.0
    local payMax = definition.payMultiplierMax or 1.5
    local payMult = payMin + (ZombRand(math.floor((payMax - payMin) * 100) + 1) / 100)
    local payout = math.floor(baseValue * quantity * payMult * 100 + 0.5) / 100

    -- Pick a random item from the category for fulfilment
    local resolvedItemType = nil
    if POS_ItemPool and POS_ItemPool.selectRandomItems then
        local ok, selected = PhobosLib.safecall(POS_ItemPool.selectRandomItems, categoryId, 1)
        if ok and selected and #selected > 0 then
            resolvedItemType = selected[1].fullType
        end
    end

    -- Resolve archetype
    local archetypeId = definition.archetypeId
    if not archetypeId or archetypeId == "" then
        -- Pick a random archetype that deals in this category
        local archetypes = { "baseline_trader", "scavenger_trader", "wholesaler",
                             "smuggler", "military_logistician", "speculator" }
        archetypeId = archetypes[ZombRand(#archetypes) + 1]
    end

    -- Resolve zone name
    local zoneName = zoneId or "unknown"

    -- Build briefing context
    local context = {
        zoneName       = zoneName,
        category       = categoryId,
        quantity       = quantity,
        rewardCash     = payout,
        deadlineDay    = day + deadlineDays,
        sponsorName    = archetypeId,
        difficulty     = definition.urgency or 2,
        operationCode  = tostring(ZombRand(1000, 9999)),
        targetName     = resolvedItemType and PhobosLib.getItemDisplayName(resolvedItemType) or categoryId,
    }

    -- Resolve briefing text via compositor
    local briefing = {}
    if POS_MissionBriefingResolver and POS_MissionBriefingResolver.resolveBriefing then
        -- Use contract-specific briefing sections
        local tempDef = {
            briefingPools = definition.briefingPools,
        }
        briefing = POS_MissionBriefingResolver.resolveBriefing(tempDef, context, archetypeId)
    end

    -- Build the contract instance
    return {
        id               = "CONTRACT_" .. tostring(getTimestampMs()) .. "_" .. tostring(ZombRand(10000)),
        definitionId     = definition.id,
        kind             = definition.kind,
        categoryId       = categoryId,
        zoneId           = zoneId,
        archetypeId      = archetypeId,
        urgency          = definition.urgency or 2,
        sigintRequired   = definition.sigintRequired or 0,
        reputationMin    = definition.reputationMin or 0,
        betrayalChance   = definition.betrayalChance or 0,
        resolvedItemType = resolvedItemType,
        resolvedQuantity = quantity,
        resolvedPayout   = payout,
        deadlineDay      = day + deadlineDays,
        briefing         = briefing,
    }
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Attempt to generate contracts from current world state.
--- Called from POS_EconomyTick after the daily simulation.
--- @return number Number of contracts generated
function POS_ContractGenerator.generateFromWorldState()
    POS_ContractGenerator.init()

    if not _contractRegistry then return 0 end

    -- Cooldown check
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    if day - _lastGenerationDay < POS_Constants.CONTRACT_GENERATION_COOLDOWN_DAYS then
        return 0
    end

    -- Check if Living Market is enabled
    if POS_Sandbox and POS_Sandbox.isLivingMarketEnabled
            and not POS_Sandbox.isLivingMarketEnabled() then
        return 0
    end

    local zones = POS_Constants.MARKET_ZONES or {}
    local allDefs = _contractRegistry:getAll()
    local generated = 0

    for _, zoneId in ipairs(zones) do
        local shortages = findShortages(zoneId)

        for _, shortage in ipairs(shortages) do
            -- Pick a contract definition that fits
            local candidates = {}
            for _, def in ipairs(allDefs) do
                if def.enabled ~= false then
                    candidates[#candidates + 1] = def
                end
            end

            if #candidates > 0 then
                local def = candidates[ZombRand(#candidates) + 1]
                local contract = buildContract(def, shortage.categoryId, zoneId)

                if contract then
                    local ok = POS_ContractService.post(contract)
                    if ok then
                        generated = generated + 1
                    end
                end
            end

            -- Only generate 1 contract per zone per tick to avoid flooding
            break
        end
    end

    if generated > 0 then
        _lastGenerationDay = day
        PhobosLib.debug("POS", _TAG,
            "Generated " .. tostring(generated) .. " contract(s) from world state")
    end

    return generated
end

--- Get the contract definition registry (for addon extensions).
--- @return table|nil
function POS_ContractGenerator.getRegistry()
    POS_ContractGenerator.init()
    return _contractRegistry
end
