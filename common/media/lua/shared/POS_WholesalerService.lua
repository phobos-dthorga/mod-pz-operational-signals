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
-- POS_WholesalerService.lua
-- Wholesaler lifecycle, supply pressure contribution, and
-- signal generation for the Living Market simulation.
-- Wholesaler definitions are loaded from data-only Lua files
-- via PhobosLib registry/schema infrastructure.
-- See docs/living-market-design.md §8 for the full schema.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_MarketDatabase"

POS_WholesalerService = POS_WholesalerService or {}

local _TAG = "[POS:WholesalerSvc]"

---------------------------------------------------------------
-- Wholesaler definition registry
---------------------------------------------------------------

local _wholesalerSchema = require "POS_WholesalerSchema"

local _wholesalerRegistry = PhobosLib.createRegistry({
    name    = "Wholesalers",
    schema  = _wholesalerSchema,
    idField = "id",
    allowOverwrite = false,
    tag     = "[POS:Wholesaler]",
})

--- Get the wholesaler definition registry for external registration.
---@return table PhobosLib registry instance
function POS_WholesalerService.getRegistry()
    return _wholesalerRegistry
end

--- Create a wholesaler from a registered definition.
---@param id string  Wholesaler definition ID
---@return table|nil Wholesaler instance, or nil if not found
function POS_WholesalerService.createFromRegistry(id)
    local def = _wholesalerRegistry:get(id)
    if not def then return nil end
    return POS_WholesalerService.createWholesaler(def)
end

--- Translation key suffix lookup: operational state → UI key fragment.
local STATE_UI_KEYS = {
    [POS_Constants.WHOLESALER_STATE_STABLE]      = "Stable",
    [POS_Constants.WHOLESALER_STATE_TIGHT]       = "Tight",
    [POS_Constants.WHOLESALER_STATE_STRAINED]    = "Strained",
    [POS_Constants.WHOLESALER_STATE_DUMPING]     = "Dumping",
    [POS_Constants.WHOLESALER_STATE_WITHHOLDING] = "Withholding",
    [POS_Constants.WHOLESALER_STATE_COLLAPSING]  = "Collapsing",
}

---------------------------------------------------------------
-- Event stock/disruption effect mapping (event ID → effect table)
---------------------------------------------------------------

local EVENT_EFFECTS = {
    [POS_Constants.MARKET_EVENT_BULK_ARRIVAL] = {
        stock      = POS_Constants.EVENT_STOCK_EFFECT_BULK_ARRIVAL,
        disruption = 0,
    },
    [POS_Constants.MARKET_EVENT_CONVOY_DELAY] = {
        stock      = 0,
        disruption = 0,
    },
    [POS_Constants.MARKET_EVENT_THEFT_RAID] = {
        stock      = POS_Constants.EVENT_STOCK_EFFECT_THEFT_RAID,
        disruption = POS_Constants.EVENT_DISRUPTION_THEFT_RAID,
    },
    [POS_Constants.MARKET_EVENT_CONTROLLED_RELEASE] = {
        stock      = POS_Constants.EVENT_STOCK_EFFECT_CONTROLLED_RELEASE,
        disruption = 0,
    },
    [POS_Constants.MARKET_EVENT_WITHHOLDING] = {
        stock      = 0,
        disruption = 0,
    },
    [POS_Constants.MARKET_EVENT_REQUISITION] = {
        stock      = POS_Constants.EVENT_STOCK_EFFECT_REQUISITION,
        disruption = POS_Constants.EVENT_DISRUPTION_REQUISITION,
    },
}


--- Create a new wholesaler from a definition table.
--- Missing fields are filled with sensible defaults.
---@param def table  Wholesaler definition (id, name, regionId, archetype required)
---@return table     Fully-initialised wholesaler table
function POS_WholesalerService.createWholesaler(def)
    local baseStock = def.stockLevel or 0.75
    return {
        id              = def.id,
        name            = def.name or def.id,
        regionId        = def.regionId,
        archetype       = def.archetype or POS_Constants.AGENT_ARCHETYPE_WHOLESALER,
        faction         = def.faction,
        active          = def.active ~= false,
        categoryWeights = def.categoryWeights or {},
        stockLevel      = baseStock,
        throughput      = def.throughput       or 0.60,
        resilience      = def.resilience       or 0.70,
        visibility      = def.visibility       or 0.35,
        reliability     = def.reliability      or 0.80,
        influence       = def.influence        or 0.85,
        secrecy         = def.secrecy          or 0.20,
        markupBias      = def.markupBias       or -0.08,
        panicThreshold  = def.panicThreshold   or 0.25,
        dumpThreshold   = def.dumpThreshold    or 0.90,
        convoyState     = def.convoyState or {
            inTransit     = false,
            etaDay        = nil,
            cargoStrength = 0.0,
        },
        pressure           = 0.0,
        disruption         = 0.0,
        lastUpdateDay      = 0,
        _baselineStock     = baseStock,
        _lastContributions = {},
        _operationalState  = POS_Constants.WHOLESALER_STATE_STABLE,
    }
end


---------------------------------------------------------------
-- 4A. Operational state machine (6 states, first-match wins)
---------------------------------------------------------------

--- Resolve the operational state of a wholesaler based on its
--- current pressure, disruption, and stock levels.
--- See design-guidelines.md §24.4 for the six-state model.
---@param wholesaler table  Wholesaler table
---@return string           One of POS_Constants.WHOLESALER_STATE_* values
function POS_WholesalerService.resolveOperationalState(wholesaler)
    local pressure   = wholesaler.pressure
    local disruption = wholesaler.disruption
    local stock      = wholesaler.stockLevel

    -- 1. COLLAPSING: high disruption + depleted stock
    if disruption >= POS_Constants.WHOLESALER_DISRUPTION_COLLAPSING_THRESHOLD
            and stock <= POS_Constants.WHOLESALER_STOCK_COLLAPSING_THRESHOLD then
        return POS_Constants.WHOLESALER_STATE_COLLAPSING
    end

    -- 2. DUMPING: very high stock (above dump threshold)
    if stock >= wholesaler.dumpThreshold then
        return POS_Constants.WHOLESALER_STATE_DUMPING
    end

    -- 3. WITHHOLDING: high pressure but holding stock
    if pressure >= POS_Constants.WHOLESALER_PRESSURE_STRAINED_THRESHOLD
            and stock >= POS_Constants.WHOLESALER_STOCK_WITHHOLDING_FLOOR then
        return POS_Constants.WHOLESALER_STATE_WITHHOLDING
    end

    -- 4. STRAINED: high pressure or moderate disruption
    if pressure >= POS_Constants.WHOLESALER_PRESSURE_STRAINED_THRESHOLD
            or disruption >= POS_Constants.WHOLESALER_DISRUPTION_STRAINED_THRESHOLD then
        return POS_Constants.WHOLESALER_STATE_STRAINED
    end

    -- 5. TIGHT: moderate pressure
    if pressure >= POS_Constants.WHOLESALER_PRESSURE_TIGHT_THRESHOLD then
        return POS_Constants.WHOLESALER_STATE_TIGHT
    end

    -- 6. STABLE: default
    return POS_Constants.WHOLESALER_STATE_STABLE
end


---------------------------------------------------------------
-- 4B. Supply pressure contribution
---------------------------------------------------------------

--- Compute a wholesaler's supply pressure contribution for a category.
--- Formula: influence × categoryWeight × (disruption + pressure − stockLevel − throughput × THROUGHPUT_FACTOR)
--- See living-market-design.md §9.
---@param wholesaler table   Wholesaler table
---@param categoryId string  Category key
---@return number            Pressure contribution (can be negative)
function POS_WholesalerService.computePressureContribution(wholesaler, categoryId)
    local catWeight = wholesaler.categoryWeights and wholesaler.categoryWeights[categoryId] or 0
    if catWeight <= 0 then return 0 end

    local raw = wholesaler.influence
        * catWeight
        * (wholesaler.disruption + wholesaler.pressure
           - wholesaler.stockLevel
           - wholesaler.throughput * POS_Constants.SIMULATION_THROUGHPUT_FACTOR)

    return PhobosLib.clamp(raw,
        POS_Constants.SIMULATION_PRESSURE_CLAMP_MIN,
        POS_Constants.SIMULATION_PRESSURE_CLAMP_MAX)
end


---------------------------------------------------------------
-- 4C. Wholesaler tick lifecycle (6 phases)
---------------------------------------------------------------

--- Run one simulation tick for a single wholesaler.
--- 6-phase lifecycle: natural drift, demand pull, convoy resolution,
--- event roll, market influence, signal emission.
--- See living-market-design.md §10 for the full specification.
---@param wholesaler table   Wholesaler table
---@param currentDay number  Current in-game day
function POS_WholesalerService.tickWholesaler(wholesaler, currentDay)
    if wholesaler.lastUpdateDay >= currentDay then return end

    -- Lazy require to avoid circular dependency at file load time
    local POS_MarketSimulation = POS_MarketSimulation

    -- Phase 1: Natural drift — pressure/disruption decay, stock replenishes
    wholesaler.pressure = PhobosLib.approach(
        wholesaler.pressure, 0,
        POS_Constants.SIMULATION_PRESSURE_DECAY_RATE)
    wholesaler.disruption = PhobosLib.approach(
        wholesaler.disruption, 0,
        POS_Constants.SIMULATION_DISRUPTION_DECAY_RATE)

    -- Convoy delay blocks stock replenishment (Phase 3 check ahead of drift)
    local convoyBlocking = false
    local convoy = wholesaler.convoyState
    if convoy and convoy.inTransit and convoy.etaDay then
        if currentDay > convoy.etaDay + POS_Constants.CONVOY_OVERDUE_TOLERANCE_DAYS then
            convoyBlocking = true
        end
    end

    if not convoyBlocking then
        wholesaler.stockLevel = PhobosLib.approach(
            wholesaler.stockLevel, wholesaler._baselineStock,
            POS_Constants.SIMULATION_STOCK_REPLENISH_RATE)
    end

    -- Phase 2: Demand pull — essential categories erode stock
    local zoneDef = POS_MarketSimulation
        and POS_MarketSimulation.getZoneRegistry()
        and POS_MarketSimulation.getZoneRegistry():get(wholesaler.regionId)
    local popTier = zoneDef and zoneDef.population or "medium"
    local demandMult = POS_Constants.SIMULATION_DEMAND_PULL[popTier]
        or POS_Constants.SIMULATION_DEMAND_PULL.medium

    for _, catId in ipairs(POS_Constants.SIMULATION_ESSENTIAL_CATEGORIES) do
        local catWeight = wholesaler.categoryWeights[catId] or 0
        if catWeight > 0 then
            wholesaler.stockLevel = wholesaler.stockLevel - (demandMult * catWeight)
        end
    end

    wholesaler.stockLevel = PhobosLib.clamp(
        wholesaler.stockLevel,
        POS_Constants.WHOLESALER_STOCK_MIN,
        POS_Constants.WHOLESALER_STOCK_MAX)

    -- Phase 3: Convoy resolution
    if convoy and convoy.inTransit and convoy.etaDay then
        if currentDay >= convoy.etaDay and not convoyBlocking then
            -- Convoy arrives: boost stock
            wholesaler.stockLevel = PhobosLib.clamp(
                wholesaler.stockLevel + convoy.cargoStrength,
                POS_Constants.WHOLESALER_STOCK_MIN,
                POS_Constants.WHOLESALER_STOCK_MAX)
            convoy.inTransit = false
            convoy.etaDay = nil
            convoy.cargoStrength = 0.0
            PhobosLib.debug("POS", _TAG, wholesaler.id .. ": convoy arrived, stock boosted")
        end
    end

    -- Phase 4: Event roll — iterate events, check probability
    if POS_MarketSimulation and POS_MarketSimulation.getEventRegistry then
        local allEvents = POS_MarketSimulation.getEventRegistry():getAll()
        for _, eventDef in ipairs(allEvents) do
            if eventDef.enabled ~= false then
                local roll = PhobosLib.randFloat(0, 1)
                local threshold = eventDef.probability
                    * POS_Constants.SIMULATION_EVENT_PROBABILITY_MULT
                if roll < threshold then
                    POS_WholesalerService._applyEvent(wholesaler, eventDef)
                end
            end
        end
    end

    -- Phase 5: Market influence — compute per-category contributions
    wholesaler._lastContributions = {}
    for _, catId in ipairs(POS_Constants.MARKET_CATEGORIES) do
        local contrib = POS_WholesalerService.computePressureContribution(wholesaler, catId)
        if contrib ~= 0 then
            wholesaler._lastContributions[catId] = contrib
        end
    end

    -- Phase 6: Signal emission — generate observations for POS_MarketDatabase
    POS_WholesalerService.emitSignals(wholesaler, currentDay)

    -- Finalise: update state and timestamp
    local prevState = wholesaler._operationalState
    wholesaler._operationalState = POS_WholesalerService.resolveOperationalState(wholesaler)
    wholesaler.lastUpdateDay = currentDay

    if wholesaler._operationalState ~= prevState then
        PhobosLib.debug("POS", _TAG, wholesaler.id .. ": state "
            .. tostring(prevState) .. " -> " .. tostring(wholesaler._operationalState))

        -- Phase 7C: Generate field note for significant state transitions
        local newState = wholesaler._operationalState
        local isSignificant = false
        for _, s in ipairs(POS_Constants.FIELD_NOTE_STATES) do
            if newState == s then isSignificant = true; break end
        end
        if isSignificant and wholesaler[POS_Constants.FIELD_NOTE_COOLDOWN_KEY] ~= currentDay then
            wholesaler[POS_Constants.FIELD_NOTE_COOLDOWN_KEY] = currentDay
            local ok, gen = PhobosLib.safecall(require, "POS_MarketNoteGenerator")
            if ok and gen and gen.generateNote then
                local noteData = {
                    type         = "state_transition",
                    wholesalerId = wholesaler.id,
                    regionId     = wholesaler.regionId,
                    state        = newState,
                    categories   = wholesaler.categoryWeights or {},
                    day          = currentDay,
                }
                PhobosLib.safecall(gen.generateNote, noteData)
                PhobosLib.debug("POS", _TAG,
                    wholesaler.id .. ": field note generated for " .. newState .. " transition")
            end
        end
    end
end


---------------------------------------------------------------
-- Signal Emission (Phase 3A)
---------------------------------------------------------------

--- Emit hard-signal observations into POS_MarketDatabase from a
--- wholesaler's current state. Visibility gates emission: high-secrecy
--- wholesalers emit fewer observations per tick. Each emitted category
--- produces one observation record with price, stock bucket, confidence,
--- and source/location display names resolved via registry.
---@param wholesaler table  Wholesaler table (after Phase 5 tick)
---@param currentDay number Current in-game day
function POS_WholesalerService.emitSignals(wholesaler, currentDay)
    -- Visibility gate: high-secrecy wholesalers may skip emission
    local visibility = wholesaler.visibility or 1.0
    if PhobosLib.randFloat(0, 1) > visibility then
        PhobosLib.trace("POS", _TAG,
            wholesaler.id .. " skipped emission (visibility gate)")
        return
    end

    local state = wholesaler._operationalState
        or POS_Constants.WHOLESALER_STATE_STABLE
    local priceMultiplier = POS_Constants.WHOLESALER_PRICE_MULTIPLIER[state]
        or 1.0
    local markupBias = wholesaler.markupBias or 0
    local reliability = wholesaler.reliability or 0.5
    local stockLevel = wholesaler.stockLevel or 0.5
    local catWeights = wholesaler.categoryWeights or {}

    -- Resolve display names via registry
    local sourceName = PhobosLib.getRegistryDisplayName(
        _wholesalerRegistry, wholesaler.id, wholesaler.id)
    local locationName = PhobosLib.getRegistryDisplayName(
        POS_WholesalerService._getZoneRegistry(),
        wholesaler.regionId, wholesaler.regionId)

    -- Determine stock bucket and confidence from tier tables
    local stockNorm = PhobosLib.clamp(
        math.floor(stockLevel * 100), 0, 100)
    local stockTier = PhobosLib.getQualityTier(
        stockNorm, POS_Constants.STOCK_LEVEL_TIERS)
    local stockBucket = stockTier and stockTier.name
        or POS_Constants.STOCK_LEVEL_TIERS[4].name

    local confNorm = PhobosLib.clamp(
        math.floor(reliability * 100), 0, 100)
    local confTier = PhobosLib.getQualityTier(
        confNorm, POS_Constants.CONFIDENCE_TIERS)
    local confidence = confTier and confTier.name
        or POS_Constants.CONFIDENCE_TIERS[3].name

    local quality = PhobosLib.clamp(
        PhobosLib.round(reliability * 100, 0), 0, 100)

    local count = 0
    for catId, weight in pairs(catWeights) do
        if weight > 0 then
            local basePrice = POS_Constants.CATEGORY_BASE_PRICE[catId]
            if basePrice then
                -- Price = base × (1 + markup) × state multiplier × noise
                local noise = 1 + PhobosLib.randFloat(
                    -POS_Constants.SIGNAL_PRICE_NOISE,
                    POS_Constants.SIGNAL_PRICE_NOISE)
                local price = PhobosLib.round(
                    basePrice * (1 + markupBias) * priceMultiplier * noise, 0)

                local recordId = POS_Constants.SIGNAL_RECORD_PREFIX
                    .. wholesaler.id .. "_" .. catId .. "_" .. currentDay

                PhobosLib.safecall(POS_MarketDatabase.addRecord, {
                    id          = recordId,
                    categoryId  = catId,
                    price       = price,
                    stock       = PhobosLib.safeGetText(stockBucket),
                    source      = sourceName,
                    location    = locationName,
                    confidence  = confidence,
                    sourceTier  = POS_Constants.SOURCE_TIER_BROADCAST,
                    quality     = quality,
                    recordedDay = currentDay,
                })
                count = count + 1
            end
        end
    end

    if count > 0 then
        PhobosLib.debug("POS", _TAG,
            wholesaler.id .. " emitted " .. count .. " observations"
            .. " (state=" .. tostring(state) .. ")")
    end
end

--- Internal accessor for zone registry (used by emitSignals for display names).
--- Must be set by POS_MarketSimulation during init.
---@return table|nil  Zone registry instance
function POS_WholesalerService._getZoneRegistry()
    return POS_WholesalerService._zoneRegistry
end

--- Set the zone registry reference (called by POS_MarketSimulation.init).
---@param registry table  Zone registry from MarketSimulation
function POS_WholesalerService._setZoneRegistry(registry)
    POS_WholesalerService._zoneRegistry = registry
end


--- Apply a market event's effects to a wholesaler.
--- Modifies pressure and stock based on the event definition and
--- whether the wholesaler carries affected categories.
---@param wholesaler table  Wholesaler table
---@param eventDef   table  Event definition from registry
function POS_WholesalerService._applyEvent(wholesaler, eventDef)
    -- Check if wholesaler carries any affected categories
    local affected = eventDef.affectedCategories or POS_Constants.MARKET_CATEGORIES
    local hasOverlap = false
    for _, catId in ipairs(affected) do
        if (wholesaler.categoryWeights[catId] or 0) > 0 then
            hasOverlap = true
            break
        end
    end
    if not hasOverlap then return end

    -- Apply pressure effect from definition
    wholesaler.pressure = PhobosLib.clamp(
        wholesaler.pressure + (eventDef.pressureEffect or 0),
        POS_Constants.WHOLESALER_PRESSURE_MIN,
        POS_Constants.WHOLESALER_PRESSURE_MAX)

    -- Apply stock and disruption effects from constant mapping
    local effects = EVENT_EFFECTS[eventDef.id]
    if effects then
        if effects.stock ~= 0 then
            wholesaler.stockLevel = PhobosLib.clamp(
                wholesaler.stockLevel + effects.stock,
                POS_Constants.WHOLESALER_STOCK_MIN,
                POS_Constants.WHOLESALER_STOCK_MAX)
        end
        if effects.disruption ~= 0 then
            wholesaler.disruption = PhobosLib.clamp(
                wholesaler.disruption + effects.disruption,
                POS_Constants.WHOLESALER_DISRUPTION_MIN,
                POS_Constants.WHOLESALER_DISRUPTION_MAX)
        end
    end

    PhobosLib.debug("POS", _TAG, wholesaler.id .. ": event "
        .. tostring(eventDef.id) .. " triggered (pressure="
        .. string.format("%.2f", wholesaler.pressure)
        .. ", stock=" .. string.format("%.2f", wholesaler.stockLevel) .. ")")

    -- Emit soft signal rumour for soft-class events
    if eventDef.signalClass == POS_Constants.SIGNAL_CLASS_SOFT then
        PhobosLib.safecall(function()
            local POS_RumourGenerator = require("POS_RumourGenerator")
            local currentDay = POS_WorldState and POS_WorldState.getWorldDay() or 0
            POS_RumourGenerator.generateRumour(eventDef, wholesaler, currentDay)
        end)
    end

    -- Award SIGINT XP for detecting market events (Phase 7B)
    local player = getSpecificPlayer(0)
    if player then
        local baseXP = POS_Constants.SIGINT_XP_MARKET_EVENT_BASE
        local mult = POS_Constants.SIGINT_XP_DEFAULT_MULT
        local opState = wholesaler._operationalState
            or POS_Constants.WHOLESALER_STATE_STABLE
        if opState == POS_Constants.WHOLESALER_STATE_COLLAPSING then
            mult = POS_Constants.SIGINT_XP_COLLAPSING_MULT
        elseif opState == POS_Constants.WHOLESALER_STATE_WITHHOLDING then
            mult = POS_Constants.SIGINT_XP_WITHHOLDING_MULT
        elseif opState == POS_Constants.WHOLESALER_STATE_STRAINED then
            mult = POS_Constants.SIGINT_XP_STRAINED_MULT
        end
        local xpAmount = PhobosLib.round(baseXP * mult, 0)
        local ok3, POS_SIGINTSkill = PhobosLib.safecall(require, "POS_SIGINTSkill")
        if ok3 and POS_SIGINTSkill and POS_SIGINTSkill.addXP then
            PhobosLib.safecall(POS_SIGINTSkill.addXP, player, xpAmount)
            PhobosLib.debug("POS", _TAG, "Awarded " .. xpAmount
                .. " SIGINT XP for " .. tostring(eventDef.id) .. " event")
        end
    end
end


---------------------------------------------------------------
-- 4D. Downstream influence modifiers
---------------------------------------------------------------

--- Downstream influence profiles: [state][archetype] → modifier table.
--- These describe how a wholesaler's operational state affects
--- downstream agents of various archetypes.
local DOWNSTREAM_PROFILES = {
    [POS_Constants.WHOLESALER_STATE_STABLE] = {
        [POS_Constants.AGENT_ARCHETYPE_SCAVENGER]     = { stockBias = 0.10, priceBias = 0.00, opportunity = 0.00 },
        [POS_Constants.AGENT_ARCHETYPE_QUARTERMASTER]  = { stockBias = 0.05, priceBias = -0.05, opportunity = 0.00 },
        [POS_Constants.AGENT_ARCHETYPE_SMUGGLER]       = { stockBias = 0.00, priceBias = 0.00, opportunity = 0.10 },
        [POS_Constants.AGENT_ARCHETYPE_SPECULATOR]     = { stockBias = 0.00, priceBias = 0.00, opportunity = 0.00 },
    },
    [POS_Constants.WHOLESALER_STATE_TIGHT] = {
        [POS_Constants.AGENT_ARCHETYPE_SCAVENGER]     = { stockBias = 0.00, priceBias = 0.05, opportunity = 0.10 },
        [POS_Constants.AGENT_ARCHETYPE_QUARTERMASTER]  = { stockBias = -0.05, priceBias = 0.05, opportunity = 0.00 },
        [POS_Constants.AGENT_ARCHETYPE_SMUGGLER]       = { stockBias = 0.00, priceBias = 0.05, opportunity = 0.20 },
        [POS_Constants.AGENT_ARCHETYPE_SPECULATOR]     = { stockBias = 0.00, priceBias = 0.10, opportunity = 0.15 },
    },
    [POS_Constants.WHOLESALER_STATE_STRAINED] = {
        [POS_Constants.AGENT_ARCHETYPE_SCAVENGER]     = { stockBias = -0.10, priceBias = 0.10, opportunity = 0.20 },
        [POS_Constants.AGENT_ARCHETYPE_QUARTERMASTER]  = { stockBias = -0.10, priceBias = 0.10, opportunity = 0.05 },
        [POS_Constants.AGENT_ARCHETYPE_SMUGGLER]       = { stockBias = -0.05, priceBias = 0.10, opportunity = 0.40 },
        [POS_Constants.AGENT_ARCHETYPE_SPECULATOR]     = { stockBias = -0.05, priceBias = 0.15, opportunity = 0.30 },
    },
    [POS_Constants.WHOLESALER_STATE_DUMPING] = {
        [POS_Constants.AGENT_ARCHETYPE_SCAVENGER]     = { stockBias = 0.15, priceBias = -0.10, opportunity = 0.05 },
        [POS_Constants.AGENT_ARCHETYPE_QUARTERMASTER]  = { stockBias = 0.10, priceBias = -0.10, opportunity = 0.00 },
        [POS_Constants.AGENT_ARCHETYPE_SMUGGLER]       = { stockBias = 0.10, priceBias = -0.05, opportunity = 0.15 },
        [POS_Constants.AGENT_ARCHETYPE_SPECULATOR]     = { stockBias = 0.10, priceBias = -0.15, opportunity = 0.10 },
    },
    [POS_Constants.WHOLESALER_STATE_WITHHOLDING] = {
        [POS_Constants.AGENT_ARCHETYPE_SCAVENGER]     = { stockBias = -0.10, priceBias = 0.10, opportunity = 0.20 },
        [POS_Constants.AGENT_ARCHETYPE_QUARTERMASTER]  = { stockBias = -0.10, priceBias = 0.10, opportunity = 0.05 },
        [POS_Constants.AGENT_ARCHETYPE_SMUGGLER]       = { stockBias = -0.05, priceBias = 0.10, opportunity = 0.70 },
        [POS_Constants.AGENT_ARCHETYPE_SPECULATOR]     = { stockBias = -0.05, priceBias = 0.15, opportunity = 0.40 },
    },
    [POS_Constants.WHOLESALER_STATE_COLLAPSING] = {
        [POS_Constants.AGENT_ARCHETYPE_SCAVENGER]     = { stockBias = -0.20, priceBias = 0.15, opportunity = 0.30 },
        [POS_Constants.AGENT_ARCHETYPE_QUARTERMASTER]  = { stockBias = -0.15, priceBias = 0.15, opportunity = 0.10 },
        [POS_Constants.AGENT_ARCHETYPE_SMUGGLER]       = { stockBias = -0.10, priceBias = 0.15, opportunity = 0.60 },
        [POS_Constants.AGENT_ARCHETYPE_SPECULATOR]     = { stockBias = -0.10, priceBias = 0.20, opportunity = 0.50 },
    },
}

--- Get modifier hints for downstream agent behaviour based on the
--- wholesaler's current operational state and the target archetype.
--- See living-market-design.md §8 (Downstream Influence).
---@param wholesaler      table   Wholesaler table
---@param targetArchetype string  Archetype of the downstream agent
---@return table                  { stockBias, priceBias, opportunity, strainDelay }
function POS_WholesalerService.getDownstreamInfluence(wholesaler, targetArchetype)
    local state = wholesaler._operationalState or POS_Constants.WHOLESALER_STATE_STABLE
    local stateProfiles = DOWNSTREAM_PROFILES[state]
    if not stateProfiles then
        return { stockBias = 0, priceBias = 0, opportunity = 0,
            strainDelay = POS_Constants.WHOLESALER_DOWNSTREAM_DELAY_DAYS }
    end

    local profile = stateProfiles[targetArchetype]
    if not profile then
        return { stockBias = 0, priceBias = 0, opportunity = 0,
            strainDelay = POS_Constants.WHOLESALER_DOWNSTREAM_DELAY_DAYS }
    end

    return {
        stockBias   = profile.stockBias or 0,
        priceBias   = profile.priceBias or 0,
        opportunity = profile.opportunity or 0,
        strainDelay = POS_Constants.WHOLESALER_DOWNSTREAM_DELAY_DAYS,
    }
end


--- Get the localised display name for a wholesaler operational state.
---@param state string  One of POS_Constants.WHOLESALER_STATE_* values
---@return string       Localised name, or the state ID as fallback
function POS_WholesalerService.getStateDisplayName(state)
    local suffix = STATE_UI_KEYS[state]
    if not suffix then return state end
    return PhobosLib.safeGetText("UI_POS_Wholesaler_State_" .. suffix)
end
