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

--- POS_WBN_SchedulerService — Manages per-station-class bulletin queues
--- and emits bulletins on cadence via the harvest -> editorial -> composition
--- pipeline.
---
--- Each station class maintains its own priority queue (sorted by editorial
--- score descending) and an independent emission cadence timer. On each
--- game-minute tick the scheduler harvests new candidates, filters them
--- through the editorial layer, composes radio lines, enqueues them, and
--- emits the top-priority bulletin when the cadence window has elapsed.
---
--- @module POS_WBN_SchedulerService

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_WBN"
require "POS_WBN_HarvestService"
require "POS_WBN_EditorialService"
require "POS_WBN_CompositionService"

local _TAG = "WBN:Scheduler"
POS_WBN_SchedulerService = {}

--- Select a random archetype from a weighted table.
--- @param weights table  Archetype weight table (sum = 100)
--- @return string        Selected archetype ID
local function selectWeightedArchetype(weights)
    local total = 0
    for _, w in pairs(weights) do total = total + w end
    local roll = ZombRand(total)
    local running = 0
    for archId, w in pairs(weights) do
        running = running + w
        if roll < running then return archId end
    end
    -- Fallback (shouldn't reach here)
    for archId, _ in pairs(weights) do return archId end
end

-- Station class configuration (Phase 1 + world-state domains)
local STATIONS = {
    [POS_Constants.WBN_STATION_CIVILIAN_MARKET] = {
        domains    = {
            POS_Constants.WBN_DOMAIN_ECONOMY,
            POS_Constants.WBN_DOMAIN_WEATHER,
            POS_Constants.WBN_DOMAIN_COLOUR,
        },
        cadenceMin = POS_Constants.WBN_CADENCE_CIVILIAN_MIN,
        maxQueue   = POS_Constants.WBN_QUEUE_MAX_CIVILIAN,
    },
    [POS_Constants.WBN_STATION_EMERGENCY] = {
        domains    = {
            POS_Constants.WBN_DOMAIN_INFRASTRUCTURE,
            POS_Constants.WBN_DOMAIN_POWER,
            POS_Constants.WBN_DOMAIN_COLOUR,
        },
        cadenceMin = POS_Constants.WBN_CADENCE_EMERGENCY_MIN,
        maxQueue   = POS_Constants.WBN_QUEUE_MAX_EMERGENCY,
    },
}

-- Per-station priority queues (keyed by station class id)
local _queues = {}
-- Last emission timestamps per station (game-time minutes)
local _lastEmitTime = {}

-- Bulletin metadata cache: maps first-line text to candidate data.
-- Populated on emit, consumed by ClientListener for fragment generation.
-- Rolling cap to prevent unbounded growth.
local _bulletinMetaCache = {}
local _BULLETIN_META_MAX = 50

--- Get the current game-time expressed as total elapsed minutes.
--- @return number  Total game minutes since world start
local function getGameMinutes()
    local gt = getGameTime()
    if not gt then return 0 end
    return math.floor(gt:getWorldAgeHours() * 60)
end

--- Enqueue a bulletin into the priority queue for a station class.
--- Bulletins are inserted sorted by score descending; the queue is
--- trimmed to the station's maximum queue size (lowest scores dropped).
--- @param stationId string  Station class id (POS_Constants.WBN_STATION_*)
--- @param bulletin  table   Candidate table with .score and ._composedLines
local function enqueue(stationId, bulletin)
    _queues[stationId] = _queues[stationId] or {}
    local q = _queues[stationId]
    local maxQ = STATIONS[stationId] and STATIONS[stationId].maxQueue
        or POS_Constants.WBN_QUEUE_MAX_CIVILIAN

    -- Insert sorted by score descending
    local inserted = false
    for i = 1, #q do
        if (bulletin.score or 0) > (q[i].score or 0) then
            table.insert(q, i, bulletin)
            inserted = true
            break
        end
    end
    if not inserted then
        q[#q + 1] = bulletin
    end

    -- Trim to max queue size (remove lowest priority from tail)
    while #q > maxQ do
        table.remove(q)
    end
end

--- Main scheduler tick — processes the full harvest -> editorial ->
--- composition -> enqueue -> emit pipeline.
--- Called automatically from Events.EveryOneMinute on the server.
function POS_WBN_SchedulerService.tick()
    local gt = getGameTime()
    local currentDay = gt and gt:getNightsSurvived() or 0
    local worldHours = gt and gt:getWorldAgeHours() or 0

    -- 1. Harvest: consume pending candidates from the harvest layer
    local candidates = {}
    if POS_WBN_HarvestService and POS_WBN_HarvestService.consumeCandidates then
        candidates = POS_WBN_HarvestService.consumeCandidates()
    end

    -- 1b. If no candidates from economy tick, try world-state Tier 3 directly.
    -- This ensures the radio has content even if economy ticks are infrequent.
    if #candidates == 0 and POS_WBN_HarvestService
            and POS_WBN_HarvestService.generateWorldStateCandidates then
        POS_WBN_HarvestService.generateWorldStateCandidates(currentDay, worldHours)
        if POS_WBN_HarvestService.consumeCandidates then
            candidates = POS_WBN_HarvestService.consumeCandidates()
        end
    end

    -- 2. Editorial: filter, deduplicate, and score candidates
    local approved = {}
    if #candidates > 0 and POS_WBN_EditorialService and POS_WBN_EditorialService.filter then
        approved = POS_WBN_EditorialService.filter(candidates)
    end

    -- Pipeline debug logging
    if #candidates > 0 or #approved > 0 then
        PhobosLib.debug("POS", _TAG,
            "tick: " .. tostring(#candidates) .. " candidates consumed, "
            .. tostring(#approved) .. " passed editorial")
    end

    -- 3. Compose radio lines and enqueue approved bulletins
    local enqueuedCount = 0
    if #approved > 0 and POS_WBN_CompositionService and POS_WBN_CompositionService.compose then
        for _, c in ipairs(approved) do
            local stationId = c.stationClass or POS_Constants.WBN_STATION_CIVILIAN_MARKET
            local station = STATIONS[stationId]
            if station then
                -- Select archetype via weighted random per station class
                local archetypeId
                if stationId == POS_Constants.WBN_STATION_CIVILIAN_MARKET then
                    archetypeId = selectWeightedArchetype(POS_Constants.WBN_ARCHETYPE_WEIGHTS_MARKET)
                elseif stationId == POS_Constants.WBN_STATION_EMERGENCY then
                    archetypeId = selectWeightedArchetype(POS_Constants.WBN_ARCHETYPE_WEIGHTS_EMERGENCY)
                end
                local ok, lines = PhobosLib.safecall(
                    POS_WBN_CompositionService.compose, c, archetypeId)
                if ok and lines and #lines > 0 then
                    c._composedLines = lines
                    enqueue(stationId, c)
                    enqueuedCount = enqueuedCount + 1
                end
            end
        end
    end

    -- 4. Emit: check cadence per station and pop the top-priority bulletin
    local now = getGameMinutes()
    for stationId, station in pairs(STATIONS) do
        local lastEmit = _lastEmitTime[stationId] or 0
        local elapsed = now - lastEmit

        if elapsed >= station.cadenceMin then
            local q = _queues[stationId]
            if q and #q > 0 then
                local bulletin = table.remove(q, 1)  -- pop highest priority

                -- Apply signal degradation to bulletin text
                local skipEmit = false
                if POS_SignalEcologyService and POS_SignalEcologyService.getQualitativeState then
                    local state = POS_SignalEcologyService.getQualitativeState()
                    if POS_WBN_CompositionService.degradeBulletin then
                        bulletin._composedLines = POS_WBN_CompositionService.degradeBulletin(
                            bulletin._composedLines, state)
                    end
                    -- Skip emit entirely if signal is "lost"
                    if state == "lost" then
                        PhobosLib.debug("POS", _TAG,
                            "emit skipped on " .. stationId .. ": signal lost")
                        skipEmit = true
                    end
                end

                if not skipEmit and bulletin._composedLines and #bulletin._composedLines > 0
                        and POS_WBN_ChannelService
                        and POS_WBN_ChannelService.emit then
                    local emitted = POS_WBN_ChannelService.emit(stationId, bulletin._composedLines)
                    if emitted then
                        _lastEmitTime[stationId] = now
                        -- Record emission for editorial deduplication
                        if POS_WBN_EditorialService and POS_WBN_EditorialService.recordEmitted then
                            POS_WBN_EditorialService.recordEmitted(bulletin)
                        end
                        -- Cache candidate metadata for client-side fragment generation.
                        -- Key on body text (second line) since that's what the client sees.
                        if bulletin._composedLines[2] then
                            local cacheKey = bulletin._composedLines[2].text or ""
                            if cacheKey ~= "" then
                                _bulletinMetaCache[cacheKey] = {
                                    domain         = bulletin.domain,
                                    zoneId         = bulletin.zoneId,
                                    categoryId     = bulletin.categoryId,
                                    direction      = bulletin.direction,
                                    percentChange  = bulletin.percentChange,
                                    confidence     = bulletin.confidence,
                                    severity       = bulletin.severity,
                                    weatherKey     = bulletin.weatherKey,
                                    powerTransition = bulletin.powerTransition,
                                    stationClass   = stationId,
                                }
                                -- Trim cache if over cap (remove arbitrary oldest)
                                local count = 0
                                local firstKey = nil
                                for k, _ in pairs(_bulletinMetaCache) do
                                    count = count + 1
                                    if not firstKey then firstKey = k end
                                end
                                if count > _BULLETIN_META_MAX and firstKey then
                                    _bulletinMetaCache[firstKey] = nil
                                end
                            end
                        end
                        PhobosLib.debug("POS", _TAG,
                            "emitted bulletin on " .. stationId
                            .. " (queue remaining: " .. tostring(#q) .. ")")
                    end
                end
            end
        end
    end
end

--- Look up cached candidate metadata for a received broadcast line.
--- Used by ClientListener to retrieve structured data for fragment generation.
--- Consumes the entry (one-shot) to prevent stale reuse.
--- @param lineText string  The broadcast body text received by the client
--- @return table|nil       Candidate metadata table, or nil if not found
function POS_WBN_SchedulerService.consumeBulletinMeta(lineText)
    if not lineText or lineText == "" then return nil end
    local meta = _bulletinMetaCache[lineText]
    if meta then
        _bulletinMetaCache[lineText] = nil
    end
    return meta
end

--- Initialise the scheduler and its dependent services.
--- Called automatically on Events.OnGameStart.
function POS_WBN_SchedulerService.init()
    -- Initialise harvest layer event subscriptions
    if POS_WBN_HarvestService and POS_WBN_HarvestService.init then
        POS_WBN_HarvestService.init()
    end
    PhobosLib.debug("POS", _TAG, "init: scheduler ready")
end

-- Hook into PZ's EveryOneMinute event (server-side tick)
if Events and Events.EveryOneMinute then
    Events.EveryOneMinute.Add(POS_WBN_SchedulerService.tick)
end

-- Initialise on game start
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(POS_WBN_SchedulerService.init)
end
