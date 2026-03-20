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
-- POS_EconomyTick.lua
-- Server-side daily economy tick processor.
-- Purges expired observations, rebuilds category aggregates,
-- trims rolling windows, writes event log snapshots, and
-- notifies clients on completion.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_WorldState"
require "POS_MarketDatabase"
require "POS_MarketFileStore"
require "POS_BasisPoints"
require "POS_EventLog"

POS_EconomyTick = {}

---------------------------------------------------------------
-- Day tick processor
---------------------------------------------------------------

function POS_EconomyTick.processDayTick()
    if not POS_WorldState.isAuthority() then return end

    local meta = POS_WorldState.getMeta()
    local currentDay = POS_WorldState.getWorldDay()

    -- Already processed today?
    if meta.lastProcessedDay and meta.lastProcessedDay >= currentDay then return end

    -- Check sandbox toggle
    if POS_Sandbox and POS_Sandbox.getEconomyTickEnabled
            and not POS_Sandbox.getEconomyTickEnabled() then
        return
    end

    PhobosLib.debug("POS", "[EconomyTick] Processing day " .. tostring(currentDay))

    -- Phase 1: Purge expired observations
    local purged = POS_MarketDatabase.purgeExpired()
    if purged > 0 then
        PhobosLib.debug("POS", "[EconomyTick] Purged " .. tostring(purged) .. " expired observations")
    end

    -- Phase 2: Aggregate category summaries (from file store)
    -- Mirror aggregates back to ModData for MP client snapshots.
    local world = POS_WorldState.getWorld()
    world.categories = world.categories or {}
    for catId, catData in pairs(POS_MarketFileStore.getAllCategories()) do
        POS_EconomyTick.rebuildCategoryAggregate(catId, catData, currentDay)
        -- Mirror aggregate to ModData (used by BroadcastSystem snapshot)
        if not world.categories[catId] then
            world.categories[catId] = {}
        end
        world.categories[catId].aggregate = catData.aggregate
    end

    -- Phase 3: Trim rolling closes and events (from file store)
    local maxCloses = POS_Sandbox and POS_Sandbox.getMaxRollingCloses
        and POS_Sandbox.getMaxRollingCloses() or POS_Constants.MAX_ROLLING_CLOSES
    local maxEvents = POS_Sandbox and POS_Sandbox.getMaxGlobalEvents
        and POS_Sandbox.getMaxGlobalEvents() or POS_Constants.MAX_GLOBAL_EVENTS

    for _, catData in pairs(POS_MarketFileStore.getAllCategories()) do
        if catData.rollingCloses then
            PhobosLib.trimArray(catData.rollingCloses, maxCloses)
        end
    end
    if world.recentEvents then
        PhobosLib.trimArray(world.recentEvents, maxEvents)
    end

    -- Phase 4: Log economy snapshot
    if POS_EventLog and POS_EventLog.writeSnapshot then
        POS_EconomyTick.writeEconomySnapshot(world, currentDay)
    end

    -- Phase 5: Purge old event logs
    if POS_EventLog and POS_EventLog.purgeOldLogs then
        local retention = POS_Sandbox and POS_Sandbox.getEventLogRetentionDays
            and POS_Sandbox.getEventLogRetentionDays() or 30
        POS_EventLog.purgeOldLogs(retention)
    end

    -- Phase 5.5: Satellite decalibration check
    if POS_SatelliteService and POS_SatelliteService.checkDecalibration then
        POS_SatelliteService.checkDecalibration()
    end

    -- Phase 6: Mark day processed
    meta.lastProcessedDay = currentDay

    -- Phase 6.5: Persist market data to external file
    if POS_MarketFileStore and POS_MarketFileStore.save then
        POS_MarketFileStore.save()
    end

    -- Phase 7: Notify clients
    if POS_BroadcastSystem and POS_BroadcastSystem.broadcastToAll then
        POS_BroadcastSystem.broadcastToAll(
            POS_Constants.CMD_MODULE,
            POS_Constants.CMD_ECONOMY_TICK_COMPLETE,
            { day = currentDay })
    else
        -- Fallback: send to local player (SP)
        local player = getSpecificPlayer(0)
        if player then
            sendServerCommand(player, POS_Constants.CMD_MODULE,
                POS_Constants.CMD_ECONOMY_TICK_COMPLETE, { day = currentDay })
        end
    end

    PhobosLib.debug("POS", "[EconomyTick] Day " .. tostring(currentDay) .. " complete")
end

---------------------------------------------------------------
-- Category aggregate builder
---------------------------------------------------------------

function POS_EconomyTick.rebuildCategoryAggregate(catId, catData, currentDay)
    if not catData.observations or #catData.observations == 0 then return end

    local totalWeight = 0
    local weightedSum = 0
    local lowPrice = nil
    local highPrice = nil
    local sourceCount = 0
    local freshestDay = -1

    for _, obs in ipairs(catData.observations) do
        local age = currentDay - (obs.day or 0)
        -- Staleness multiplier extends effective lifespan (satellite broadcasts persist longer)
        local effectiveStaleLimit = POS_Constants.MARKET_STALE_DAYS * (obs.staleness or 1.0)
        if age <= effectiveStaleLimit then
            -- Freshness multiplier: newer = more weight
            local freshMult = math.max(0.25, 1.0 - (age * 0.1))

            -- Source tier weight
            local tierWeight = POS_Constants.SOURCE_TIER_WEIGHT_DEFAULT
            if obs.sourceTier == POS_Constants.SOURCE_TIER_FIELD then
                tierWeight = POS_Constants.SOURCE_TIER_WEIGHT_FIELD
            elseif obs.sourceTier == POS_Constants.SOURCE_TIER_BROADCAST then
                tierWeight = POS_Constants.SOURCE_TIER_WEIGHT_BROADCAST
            elseif obs.sourceTier == POS_Constants.SOURCE_TIER_STUDIO then
                tierWeight = POS_Constants.SOURCE_TIER_WEIGHT_STUDIO
            end

            local w = math.max(1, math.floor(50 * freshMult * tierWeight))
            local price = obs.price or 0

            weightedSum = weightedSum + (price * w)
            totalWeight = totalWeight + w
            sourceCount = sourceCount + 1

            if not lowPrice or price < lowPrice then lowPrice = price end
            if not highPrice or price > highPrice then highPrice = price end
            if obs.day and obs.day > freshestDay then freshestDay = obs.day end
        end
    end

    local avg = totalWeight > 0 and (weightedSum / totalWeight) or 0

    -- Compute confidence tier
    local confidence = POS_Constants.CONFIDENCE_LOW
    if sourceCount >= 5 and (currentDay - freshestDay) <= POS_Constants.MARKET_FRESH_DAYS then
        confidence = POS_Constants.CONFIDENCE_HIGH
    elseif sourceCount >= 3 then
        confidence = POS_Constants.CONFIDENCE_MEDIUM
    end

    -- Compute freshness
    local freshness = POS_Constants.FRESHNESS_EXPIRED
    if freshestDay >= 0 then
        local age = currentDay - freshestDay
        if age <= POS_Constants.MARKET_FRESH_DAYS then freshness = POS_Constants.FRESHNESS_FRESH
        elseif age <= POS_Constants.MARKET_STALE_DAYS then freshness = POS_Constants.FRESHNESS_STALE
        end
    end

    -- Update aggregate
    catData.aggregate = {
        lowPrice = lowPrice or avg,
        highPrice = highPrice or avg,
        avgPrice = avg,
        sourceCount = sourceCount,
        freshestDay = freshestDay,
        confidence = confidence,
        freshness = freshness,
    }

    -- Push closing price
    if avg > 0 then
        local maxCloses = POS_Sandbox and POS_Sandbox.getMaxRollingCloses
            and POS_Sandbox.getMaxRollingCloses() or POS_Constants.MAX_ROLLING_CLOSES
        catData.rollingCloses = catData.rollingCloses or {}
        PhobosLib.pushRolling(catData.rollingCloses, avg, maxCloses)
    end
end

---------------------------------------------------------------
-- Economy snapshot writer
---------------------------------------------------------------

function POS_EconomyTick.writeEconomySnapshot(world, currentDay)
    local meta = POS_WorldState.getMeta()
    local header = table.concat({
        tostring(meta.schemaVersion or POS_Constants.SCHEMA_VERSION),
        tostring(meta.worldSeed or 0),
        tostring(currentDay),
        "0",  -- lastEventId placeholder
    }, POS_Constants.EVENT_LOG_SEPARATOR)

    local dataLines = {}
    if world.categories then
        for catId, catData in pairs(world.categories) do
            local agg = catData.aggregate or {}
            dataLines[#dataLines + 1] = table.concat({
                catId,
                tostring(POS_BasisPoints.toBps(agg.avgPrice or 0)),
                tostring(POS_BasisPoints.toBps(agg.avgPrice or 0)),
                tostring(POS_BasisPoints.toBps(agg.lowPrice or 0)),
                tostring(POS_BasisPoints.toBps(agg.highPrice or 0)),
                tostring(agg.sourceCount or 0),
                tostring(agg.confidence or "low"),
                tostring(agg.freshness or "expired"),
                "0",  -- driftBps placeholder
            }, POS_Constants.EVENT_LOG_SEPARATOR)
        end
    end

    POS_EventLog.writeSnapshot(POS_Constants.EVENT_SYSTEM_ECONOMY, header, dataLines)
end

---------------------------------------------------------------
-- Hook: check every game minute if day changed
---------------------------------------------------------------

function POS_EconomyTick.onEveryOneMinute()
    POS_EconomyTick.processDayTick()
end

Events.EveryOneMinute.Add(POS_EconomyTick.onEveryOneMinute)
