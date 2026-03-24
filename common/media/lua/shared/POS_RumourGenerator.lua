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
-- POS_RumourGenerator.lua
-- Generates, stores, and queries soft-signal rumour records
-- from market events. Rumours are world-scoped and expire
-- after a configurable number of in-game days.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_WorldState"

POS_RumourGenerator = {}
local _TAG = "Rumour"

---------------------------------------------------------------
-- Internal: world ModData accessor
---------------------------------------------------------------

--- Returns the rumour entries array from world ModData, never nil.
---@return table Array of rumour records
function POS_RumourGenerator.getRumours()
    local data = POS_WorldState.getRumours()
    data.entries = data.entries or {}
    return data.entries
end

---------------------------------------------------------------
-- Mutation: add and prune
---------------------------------------------------------------

--- Append a rumour record via PhobosLib.pushRolling, then prune expired.
---@param rumour table  Rumour record to append
---@param currentDay number  Current in-game day for expiry pruning
function POS_RumourGenerator.addRumour(rumour, currentDay)
    local entries = POS_RumourGenerator.getRumours()
    PhobosLib.pushRolling(entries, rumour, POS_Constants.RUMOUR_MAX_ACTIVE)
    POS_RumourGenerator.pruneExpired(currentDay)
end

--- Remove expired rumour entries in-place.
--- An entry is expired when its expiryDay <= currentDay.
---@param currentDay number  Current in-game day
---@return number  Count of entries removed
function POS_RumourGenerator.pruneExpired(currentDay)
    local entries = POS_RumourGenerator.getRumours()
    -- Rebuild without expired entries (# and table.remove crash on Java ModData)
    local surviving = {}
    local survivingIdx = 1
    local totalCount = 0

    for _, entry in pairs(entries) do
        if type(entry) == "table" then
            totalCount = totalCount + 1
            if entry.expiryDay and entry.expiryDay > currentDay then
                surviving[survivingIdx] = entry
                survivingIdx = survivingIdx + 1
            end
        end
    end

    local removed = totalCount - (survivingIdx - 1)
    if removed > 0 then
        -- Clear and rewrite (ModData-safe)
        local keysToRemove = {}
        for k, _ in pairs(entries) do keysToRemove[#keysToRemove + 1] = k end
        for _, k in ipairs(keysToRemove) do entries[k] = nil end
        for k, v in pairs(surviving) do entries[k] = v end
        PhobosLib.debug("POS", _TAG, "Pruned " .. tostring(removed) .. " expired rumours")
    end
    return removed
end

---------------------------------------------------------------
-- Generation
---------------------------------------------------------------

--- Resolve the impact hint for an event definition.
--- "shortage" if pressureEffect > 0, "surplus" if < 0,
--- "disruption" if the event has a disruption effect in EVENT_EFFECTS.
---@param eventDef table  Event definition from registry
---@return string         One of POS_Constants.RUMOUR_IMPACT_* values
local function _resolveImpactHint(eventDef)
    -- Check for disruption effect via the constant mapping
    local effects = POS_Constants["EVENT_DISRUPTION_" .. string.upper(string.gsub(eventDef.id, "%s", "_"))]
    -- Simpler: check if there's a known disruption constant for this event
    if eventDef.id == "theft_raid" or eventDef.id == "requisition_diversion" then
        return POS_Constants.RUMOUR_IMPACT_DISRUPTION
    end
    local pressure = eventDef.pressureEffect or 0
    if pressure > 0 then
        return POS_Constants.RUMOUR_IMPACT_SHORTAGE
    elseif pressure < 0 then
        return POS_Constants.RUMOUR_IMPACT_SURPLUS
    end
    return POS_Constants.RUMOUR_IMPACT_DISRUPTION
end

--- Resolve the source display name for a rumour.
---@param wholesaler table  Wholesaler table with regionId
---@return string           Localised source string
local function _resolveSourceName(wholesaler)
    local zoneName = wholesaler.regionId or "unknown"
    -- Try POS_MarketSimulation.getZoneDisplayName if available
    local ok, resolved = PhobosLib.safecall(function()
        local POS_MarketSimulation = require("POS_MarketSimulation")
        if POS_MarketSimulation and POS_MarketSimulation.getZoneDisplayName then
            return POS_MarketSimulation.getZoneDisplayName(wholesaler.regionId)
        end
        return nil
    end)
    if ok and resolved then
        zoneName = resolved
    end
    return PhobosLib.safeGetText("UI_POS_Rumour_Source", zoneName)
end

--- Create and store a rumour record from a market event.
---@param eventDef table    Event definition from registry
---@param wholesaler table  Wholesaler table (source of the event)
---@param currentDay number Current in-game day
---@return table|nil        The created rumour record, or nil on failure
function POS_RumourGenerator.generateRumour(eventDef, wholesaler, currentDay)
    if not eventDef or not wholesaler or not currentDay then
        PhobosLib.debug("POS", _TAG, "generateRumour: missing arguments")
        return nil
    end

    local id = POS_Constants.RUMOUR_KEY_PREFIX
        .. tostring(eventDef.id) .. "_"
        .. tostring(wholesaler.id) .. "_"
        .. tostring(currentDay)

    local categoryIds = eventDef.affectedCategories or POS_Constants.MARKET_CATEGORIES or {}

    local impactHint = _resolveImpactHint(eventDef)

    local ok, sourceName = PhobosLib.safecall(_resolveSourceName, wholesaler)
    if not ok or not sourceName then
        sourceName = wholesaler.name or wholesaler.id or "unknown"
    end

    local messageKey = POS_Constants.RUMOUR_EVENT_KEYS[eventDef.id] or eventDef.id

    local rumour = {
        id          = id,
        eventId     = eventDef.id,
        categoryIds = categoryIds,
        regionId    = wholesaler.regionId,
        sourceName  = sourceName,
        confidence  = POS_Constants.RUMOUR_CONFIDENCE,
        recordedDay = currentDay,
        expiryDay   = currentDay + POS_Constants.RUMOUR_EXPIRY_DAYS,
        impactHint  = impactHint,
        durationHint = eventDef.durationDays or POS_Constants.RUMOUR_EXPIRY_DAYS,
        messageKey  = messageKey,
    }

    POS_RumourGenerator.addRumour(rumour, currentDay)

    PhobosLib.debug("POS", _TAG, "Generated rumour: " .. id
        .. " (event=" .. tostring(eventDef.id)
        .. ", impact=" .. impactHint
        .. ", expires day " .. tostring(rumour.expiryDay) .. ")")

    return rumour
end

---------------------------------------------------------------
-- Query helpers
---------------------------------------------------------------

--- Return all non-expired rumours.
---@param currentDay number  Current in-game day
---@return table             Array of active rumour records
function POS_RumourGenerator.getActiveRumours(currentDay)
    POS_RumourGenerator.pruneExpired(currentDay)
    return POS_RumourGenerator.getRumours()
end

--- Return active rumours filtered by region.
---@param regionId string    Region ID to filter by
---@param currentDay number  Current in-game day
---@return table             Array of matching rumour records
function POS_RumourGenerator.getRumoursForRegion(regionId, currentDay)
    local active = POS_RumourGenerator.getActiveRumours(currentDay)
    local result = {}
    for _, rumour in ipairs(active) do
        if rumour.regionId == regionId then
            result[#result + 1] = rumour
        end
    end
    return result
end

--- Return active rumours filtered by affected category.
---@param categoryId string  Category ID to filter by
---@param currentDay number  Current in-game day
---@return table             Array of matching rumour records
function POS_RumourGenerator.getRumoursForCategory(categoryId, currentDay)
    local active = POS_RumourGenerator.getActiveRumours(currentDay)
    local result = {}
    for _, rumour in ipairs(active) do
        if rumour.categoryIds then
            for _, catId in ipairs(rumour.categoryIds) do
                if catId == categoryId then
                    result[#result + 1] = rumour
                    break
                end
            end
        end
    end
    return result
end

--- Return the count of active (non-expired) rumours.
---@param currentDay number  Current in-game day
---@return number            Count of active rumours
function POS_RumourGenerator.getRumourCount(currentDay)
    return #POS_RumourGenerator.getActiveRumours(currentDay)
end

return POS_RumourGenerator
