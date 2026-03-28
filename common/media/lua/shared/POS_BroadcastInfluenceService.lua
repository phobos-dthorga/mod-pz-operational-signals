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
-- POS_BroadcastInfluenceService.lua
-- Broadcast Influence System (Phase A) for POSnet.
--
-- Translates Tier IV satellite broadcasts into downstream
-- market effects: perceived pressure that adds to raw zone
-- pressure before entropy attenuation, and trust mutations
-- that affect how the network responds to future broadcasts.
--
-- Design reference: docs/architecture/broadcast-influence-design.md
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_BroadcastInfluence"

POS_BroadcastInfluenceService = {}

local _TAG = "[POS:BroadcastInfluence]"

--- Notification throttle cache: "key" -> last notify minute
local _notifyThrottle = {}

---------------------------------------------------------------
-- Internal: throttle check (mirrors POS_EntropyService pattern)
---------------------------------------------------------------

--- Check throttle for a notification key.
---@param key string Throttle key
---@return boolean True if notification is allowed
local function _canNotify(key)
    local now = 0
    if getGameTime then
        local gt = getGameTime()
        if gt and gt.getWorldAgeHours then
            now = gt:getWorldAgeHours() * 60
        end
    end
    local last = _notifyThrottle[key] or 0
    if now - last < (POS_Constants.ENTROPY_PN_THROTTLE_MIN or 60) then
        return false
    end
    _notifyThrottle[key] = now
    return true
end

---------------------------------------------------------------
-- Internal: get storage table from world ModData
---------------------------------------------------------------

--- Get the broadcast influence storage table.
---@return table { records = {} }
local function _getStorage()
    if not POS_WorldState or not POS_WorldState.getBroadcastInfluence then
        return nil
    end
    return POS_WorldState.getBroadcastInfluence()
end

---------------------------------------------------------------
-- Notifications
---------------------------------------------------------------

--- Notify: broadcast transmitted successfully.
---@param mode string Broadcast mode identifier
---@param zoneId string Target zone
function POS_BroadcastInfluenceService._notifyTransmitted(mode, zoneId)
    local key = "bi_tx:" .. tostring(mode) .. ":" .. tostring(zoneId)
    if not _canNotify(key) then return end

    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    PhobosLib.notifyOrSay(player, {
        title    = PhobosLib.safeGetText("UI_POS_Broadcast_PN_TransmittedTitle"),
        message  = PhobosLib.safeGetText("UI_POS_Broadcast_PN_Transmitted",
            tostring(mode), tostring(zoneId)),
        colour   = "success",
        priority = "normal",
        channel  = POS_Constants.PN_CHANNEL_INTEL,
    })
end

--- Notify: trust threshold crossed (rising or falling).
---@param zoneId string
---@param rising boolean True if trust is rising, false if falling
function POS_BroadcastInfluenceService._notifyTrustThreshold(zoneId, rising)
    local direction = rising and "rising" or "falling"
    local key = "bi_trust:" .. direction .. ":" .. tostring(zoneId)
    if not _canNotify(key) then return end

    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    if rising then
        PhobosLib.notifyOrSay(player, {
            title    = PhobosLib.safeGetText("UI_POS_Broadcast_PN_TrustRisingTitle"),
            message  = PhobosLib.safeGetText("UI_POS_Broadcast_PN_TrustRising",
                tostring(zoneId)),
            colour   = "success",
            priority = "high",
            channel  = POS_Constants.PN_CHANNEL_INTEL,
        })
    else
        PhobosLib.notifyOrSay(player, {
            title    = PhobosLib.safeGetText("UI_POS_Broadcast_PN_TrustFallingTitle"),
            message  = PhobosLib.safeGetText("UI_POS_Broadcast_PN_TrustFalling",
                tostring(zoneId)),
            colour   = "warning",
            priority = "high",
            channel  = POS_Constants.PN_CHANNEL_INTEL,
        })
    end
end

--- Notify: broadcast influence record resolved (freshness faded).
---@param mode string Broadcast mode
---@param zoneId string Target zone
function POS_BroadcastInfluenceService._notifyResolved(mode, zoneId)
    local key = "bi_res:" .. tostring(mode) .. ":" .. tostring(zoneId)
    if not _canNotify(key) then return end

    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    PhobosLib.notifyOrSay(player, {
        title    = PhobosLib.safeGetText("UI_POS_Broadcast_PN_ResolvedTitle"),
        message  = PhobosLib.safeGetText("UI_POS_Broadcast_PN_Resolved",
            tostring(mode), tostring(zoneId)),
        colour   = "info",
        priority = "low",
        channel  = POS_Constants.PN_CHANNEL_MARKET,
    })
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Record a satellite broadcast and generate downstream effects.
--- Persists record, mutates trust, records observation, fires events.
---@param broadcastResult table Results from POS_SatelliteService.broadcast()
---@param mode string Broadcast mode (e.g. "scarcity_alert")
---@param zoneId string Target market zone
---@param categories table Array of category IDs affected
---@param currentDay number Current game day
function POS_BroadcastInfluenceService.onBroadcast(broadcastResult, mode, zoneId, categories, currentDay)
    if not broadcastResult or not mode or not zoneId then return end

    local storage = _getStorage()
    if not storage then return end
    storage.records = storage.records or {}

    local strength = broadcastResult.strength or 0
    if strength <= 0 then return end

    -- Direction from mode
    local direction = POS_Constants.BROADCAST_MODE_PRESSURE_DIRECTION[mode] or 0

    -- Create influence record
    local record = {
        mode       = mode,
        zoneId     = zoneId,
        categories = categories or {},
        strength   = strength,
        freshness  = 1.0,
        direction  = direction,
        day        = currentDay or 0,
    }

    -- Persist via rolling buffer
    PhobosLib.pushRolling(storage.records, record,
        POS_Constants.BROADCAST_RECORD_MAX)

    -- Mutate trust in entropy intelState for each affected category
    local trustImpact = (POS_Constants.SAT_TRUST_IMPACT or {})[mode] or 0
    local scaledTrust = trustImpact * POS_Constants.BROADCAST_TRUST_MUTATION_RATE

    for _, catId in ipairs(categories or {}) do
        -- Record observation in entropy system (boosts certainty/freshness)
        if POS_EntropyService and POS_EntropyService.recordObservation then
            PhobosLib.safecall(POS_EntropyService.recordObservation,
                zoneId, catId, "high")
        end

        -- Mutate trust via entropy intel state
        if scaledTrust ~= 0 and POS_EntropyService and POS_EntropyService.getIntelState then
            local ok, state = PhobosLib.safecall(
                POS_EntropyService.getIntelState, zoneId, catId)
            if ok and state then
                local prevTrust = state.trust or POS_Constants.ENTROPY_TRUST_DEFAULT
                state.trust = PhobosLib.clamp(
                    prevTrust + scaledTrust,
                    POS_Constants.ENTROPY_TRUST_MIN,
                    POS_Constants.ENTROPY_TRUST_MAX)

                -- Check trust threshold notification
                local delta = math.abs(state.trust - prevTrust)
                if delta >= POS_Constants.BROADCAST_TRUST_NOTIFY_THRESHOLD then
                    POS_BroadcastInfluenceService._notifyTrustThreshold(
                        zoneId, state.trust > prevTrust)
                end
            end
        end
    end

    -- Fire Starlit event
    if POS_Events and POS_Events.OnBroadcastTransmitted then
        POS_Events.OnBroadcastTransmitted:trigger({
            mode       = mode,
            zoneId     = zoneId,
            strength   = strength,
            categories = categories,
            day        = currentDay,
        })
    end

    -- PN notification
    POS_BroadcastInfluenceService._notifyTransmitted(mode, zoneId)

    PhobosLib.debug("POS", _TAG,
        "onBroadcast: mode=" .. tostring(mode)
        .. " zone=" .. tostring(zoneId)
        .. " strength=" .. string.format("%.2f", strength)
        .. " direction=" .. string.format("%.2f", direction)
        .. " trustDelta=" .. string.format("%.3f", scaledTrust))
end

--- Decay freshness of all active broadcast influence records.
--- Resolves records that fall below the freshness floor.
---@param currentDay number Current game day
function POS_BroadcastInfluenceService.tickDecay(currentDay)
    local storage = _getStorage()
    if not storage or not storage.records then return end

    local resolved = {}
    local surviving = {}

    for _, record in ipairs(storage.records) do
        -- Apply multiplicative decay
        record.freshness = PhobosLib.decayMultiplicative(
            record.freshness,
            POS_Constants.BROADCAST_FRESHNESS_DECAY,
            0)

        if record.freshness < POS_Constants.BROADCAST_RESOLVED_FRESHNESS_FLOOR then
            -- Record has faded — mark for resolution
            resolved[#resolved + 1] = record
        else
            surviving[#surviving + 1] = record
        end
    end

    -- Replace records with surviving only
    storage.records = surviving

    -- Fire events + notifications for resolved records
    for _, record in ipairs(resolved) do
        if POS_Events and POS_Events.OnBroadcastResolved then
            POS_Events.OnBroadcastResolved:trigger({
                mode   = record.mode,
                zoneId = record.zoneId,
                day    = currentDay,
            })
        end
        POS_BroadcastInfluenceService._notifyResolved(
            record.mode, record.zoneId)

        PhobosLib.debug("POS", _TAG,
            "tickDecay: resolved record mode=" .. tostring(record.mode)
            .. " zone=" .. tostring(record.zoneId))
    end

    if #storage.records > 0 or #resolved > 0 then
        PhobosLib.debug("POS", _TAG,
            "tickDecay: " .. tostring(#storage.records) .. " active, "
            .. tostring(#resolved) .. " resolved")
    end
end

--- Calculate perceived pressure from active broadcast records for a zone/category.
--- Returns a signed value clamped to [-WEIGHT, +WEIGHT].
---@param zoneId string Zone identifier
---@param categoryId string Category identifier
---@return number Perceived pressure contribution
function POS_BroadcastInfluenceService.getPerceivedPressure(zoneId, categoryId)
    if not zoneId or not categoryId then return 0 end

    local storage = _getStorage()
    if not storage or not storage.records then return 0 end

    local total = 0
    local mult = POS_Constants.BROADCAST_STRENGTH_TO_PRESSURE_MULT
    local weight = POS_Constants.BROADCAST_PERCEIVED_PRESSURE_WEIGHT

    for _, record in ipairs(storage.records) do
        if record.zoneId == zoneId and record.freshness > 0 then
            -- Check if this record's categories include the target
            local matches = false
            if record.categories then
                for _, cat in ipairs(record.categories) do
                    if cat == categoryId then
                        matches = true
                        break
                    end
                end
            end
            if matches then
                total = total
                    + (record.direction or 0)
                    * (record.strength or 0)
                    * record.freshness
                    * mult
            end
        end
    end

    return PhobosLib.clamp(total, -weight, weight)
end

--- Get all active broadcast influence records for a zone.
--- Query API for UI and future phases.
---@param zoneId string Zone identifier
---@return table Array of active broadcast records for the zone
function POS_BroadcastInfluenceService.getActiveRecords(zoneId)
    local storage = _getStorage()
    if not storage or not storage.records then return {} end

    if not zoneId then return storage.records end

    local result = {}
    for _, record in ipairs(storage.records) do
        if record.zoneId == zoneId then
            result[#result + 1] = record
        end
    end
    return result
end
