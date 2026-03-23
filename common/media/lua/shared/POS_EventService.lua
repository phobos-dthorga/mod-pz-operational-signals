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
-- POS_EventService.lua
-- Market event firing service. Rolls against event probability
-- each economy tick, applies pressure effects, creates rumours,
-- and emits Starlit events for cross-system notification.
--
-- Called from POS_MarketSimulation during the daily tick phase.
-- Uses deferred Starlit event emission to avoid blocking the
-- game loop when multiple events fire simultaneously.
--
-- See design-guidelines.md §24.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_EventService = {}

local _TAG = "[POS:EventService]"

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

local _activeEvents = {}  -- zoneId -> { eventId -> { expiryDay, pressureEffect, categories } }

---------------------------------------------------------------
-- Event store (world ModData)
---------------------------------------------------------------

local function getEventStore()
    return PhobosLib.getWorldModDataTable("POSNET", "ActiveEvents") or {}
end

local function saveEventStore(store)
    PhobosLib.setWorldModDataTable("POSNET", "ActiveEvents", store)
end

local function getRecentEvents()
    return PhobosLib.getWorldModDataTable("POSNET", "RecentEvents") or {}
end

local function saveRecentEvents(events)
    PhobosLib.setWorldModDataTable("POSNET", "RecentEvents", events)
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Fire a market event in a specific zone.
--- Applies pressure effect, creates rumour, emits Starlit event.
---@param eventDef table  Event definition from registry
---@param zoneId string   Target zone
---@param currentDay number  Current game day
function POS_EventService.fireEvent(eventDef, zoneId, currentDay)
    if not eventDef or not zoneId then return end

    -- Record the event
    local eventRecord = {
        eventId    = eventDef.id,
        zoneId     = zoneId,
        firedDay   = currentDay,
        expiryDay  = currentDay + (eventDef.durationDays or POS_Constants.EVENT_DEFAULT_DURATION_DAYS),
        pressure   = eventDef.pressureEffect or 0,
        categories = eventDef.affectedCategories or {},
        signalClass = eventDef.signalClass or POS_Constants.EVENT_DEFAULT_SIGNAL_CLASS,
        displayNameKey = eventDef.displayNameKey or ("UI_POS_Event_" .. (eventDef.id or "Unknown")),
    }

    -- Store in active events
    local store = getEventStore()
    if not store[zoneId] then store[zoneId] = {} end
    store[zoneId][eventDef.id] = eventRecord
    saveEventStore(store)

    -- Add to recent events log (for Market Signals screen)
    local recent = getRecentEvents()
    recent[#recent + 1] = eventRecord
    -- Cap recent events
    while #recent > POS_Constants.EVENT_MAX_RECENT do
        table.remove(recent, 1)
    end
    saveRecentEvents(recent)

    -- Generate rumour
    if POS_RumourGenerator and POS_RumourGenerator.addRumour then
        local impactHint = eventRecord.pressure > 0
            and POS_Constants.EVENT_IMPACT_SHORTAGE
            or POS_Constants.EVENT_IMPACT_SURPLUS
        if eventDef.id == POS_Constants.MARKET_EVENT_THEFT_RAID
                or eventDef.id == POS_Constants.MARKET_EVENT_REQUISITION then
            impactHint = POS_Constants.EVENT_IMPACT_DISRUPTION
        end
        POS_RumourGenerator.addRumour({
            eventId        = eventDef.id,
            day            = currentDay,
            expiryDay      = eventRecord.expiryDay,
            source         = zoneId,
            impactHint     = impactHint,
            displayNameKey = eventRecord.displayNameKey,
        }, currentDay)
    end

    -- Toast notification via PhobosNotifications
    local eventName = PhobosLib.safeGetText(eventRecord.displayNameKey) or eventDef.id
    PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
        title   = "POSnet",
        message = eventName .. " in " .. zoneId,
        colour  = "warning",
        channel = POS_Constants.PN_CHANNEL_MARKET,
    })

    -- Emit Starlit event (deferred processing)
    if POS_Events and POS_Events.OnMarketEvent then
        POS_Events.OnMarketEvent:trigger({
            eventId     = eventDef.id,
            zoneId      = zoneId,
            signalClass = eventRecord.signalClass,
            pressure    = eventRecord.pressure,
            categories  = eventRecord.categories,
        })
    end

    PhobosLib.debug("POS", _TAG, "Fired event: " .. tostring(eventDef.id)
        .. " in " .. zoneId .. " (pressure: " .. tostring(eventRecord.pressure)
        .. ", duration: " .. tostring(eventDef.durationDays) .. "d)")
end

--- Roll event probabilities for a zone and fire any that hit.
--- Called once per zone per economy tick.
---@param eventRegistry table  PhobosLib registry of event definitions
---@param zoneId string        Target zone
---@param currentDay number    Current game day
---@return number              Number of events fired
function POS_EventService.rollEventsForZone(eventRegistry, zoneId, currentDay)
    if not eventRegistry then return 0 end

    -- Check zone cooldown
    local store = getEventStore()
    local zoneEvents = store[zoneId] or {}
    local activeCount = 0
    for _, ev in pairs(zoneEvents) do
        if ev.expiryDay and ev.expiryDay > currentDay then
            activeCount = activeCount + 1
        end
    end

    -- Respect max active events per zone
    if activeCount >= POS_Constants.EVENT_MAX_ACTIVE_PER_ZONE then
        return 0
    end

    -- Check cooldown (most recent event in this zone)
    local mostRecentDay = 0
    for _, ev in pairs(zoneEvents) do
        if ev.firedDay and ev.firedDay > mostRecentDay then
            mostRecentDay = ev.firedDay
        end
    end
    if (currentDay - mostRecentDay) < POS_Constants.EVENT_COOLDOWN_DAYS then
        return 0
    end

    -- Roll against each event definition
    local fired = 0
    local allDefs = eventRegistry:getAll()
    local probMult = POS_Constants.EVENT_PROBABILITY_MULTIPLIER

    for _, def in ipairs(allDefs) do
        if def.enabled ~= false then
            local roll = PhobosLib.randFloat(0, 1)
            local threshold = (def.probability or 0) * probMult
            if roll < threshold then
                -- Check we haven't exceeded max per zone
                if (activeCount + fired) < POS_Constants.EVENT_MAX_ACTIVE_PER_ZONE then
                    POS_EventService.fireEvent(def, zoneId, currentDay)
                    fired = fired + 1
                end
            end
        end
    end

    return fired
end

--- Purge expired events from the active store.
---@param currentDay number
function POS_EventService.purgeExpired(currentDay)
    local store = getEventStore()
    local purged = 0
    for zoneId, events in pairs(store) do
        for eventId, ev in pairs(events) do
            if ev.expiryDay and ev.expiryDay <= currentDay then
                events[eventId] = nil
                purged = purged + 1
            end
        end
    end
    if purged > 0 then
        saveEventStore(store)
        PhobosLib.debug("POS", _TAG, "Purged " .. purged .. " expired events")
    end
end

--- Get active events affecting a specific zone.
---@param zoneId string
---@param currentDay number
---@return table Array of active event records
function POS_EventService.getActiveEventsForZone(zoneId, currentDay)
    local store = getEventStore()
    local zoneEvents = store[zoneId] or {}
    local result = {}
    for _, ev in pairs(zoneEvents) do
        if ev.expiryDay and ev.expiryDay > currentDay then
            result[#result + 1] = ev
        end
    end
    return result
end

--- Get the aggregate pressure contribution from active events
--- for a specific category in a zone.
---@param zoneId string
---@param categoryId string
---@param currentDay number
---@return number  Aggregate pressure from events
function POS_EventService.getEventPressure(zoneId, categoryId, currentDay)
    local active = POS_EventService.getActiveEventsForZone(zoneId, currentDay)
    local total = 0
    for _, ev in ipairs(active) do
        if ev.categories then
            for _, cat in ipairs(ev.categories) do
                if cat == categoryId then
                    total = total + (ev.pressure or 0)
                    break
                end
            end
        end
    end
    return PhobosLib.clamp(total,
        POS_Constants.EVENT_PRESSURE_CLAMP_MIN,
        POS_Constants.EVENT_PRESSURE_CLAMP_MAX)
end
