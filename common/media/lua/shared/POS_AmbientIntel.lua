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
-- POS_AmbientIntel.lua
-- Passive data trickle that generates low-confidence market
-- observations automatically when the player is connected to
-- the POSnet network.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_MarketRegistry"
require "POS_MarketDatabase"
require "POS_ItemPool"
require "POS_SandboxIntegration"

POS_AmbientIntel = {}
local _TAG = "Ambient"
local _lastTickMinute = 0
local _recentCategories = {}  -- anti-repetition history
local _initialised = false

-- Ambient source name pool (translation keys)
local SOURCE_POOL = {
    "UI_POS_Ambient_RadioChatter",
    "UI_POS_Ambient_NetworkBulletin",
    "UI_POS_Ambient_TraderGossip",
    "UI_POS_Ambient_OverheardBroadcast",
    "UI_POS_Ambient_SignalFragment",
    "UI_POS_Ambient_StaticIntercept",
    "UI_POS_Ambient_FrequencyScan",
    "UI_POS_Ambient_BandMonitor",
}

-- Stock bucket pool
local STOCK_BUCKETS = { "low", "medium", "high" }

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

--- Check whether the player is connected to POSnet.
--- Uses safecall since POS_ConnectionManager is client-only.
--- Returns true if connected, or if ConnectionManager is unavailable
--- (server context — allow generation).
local function isPlayerConnected()
    local ok, connMgr = PhobosLib.safecall(require, "POS_ConnectionManager")
    if not ok or not connMgr then
        -- ConnectionManager unavailable (server context) — allow generation
        return true
    end
    if type(connMgr.isConnected) == "function" then
        local ok2, connected = PhobosLib.safecall(connMgr.isConnected)
        if ok2 then return connected end
    end
    return false
end

--- Pick a random element from an array.
local function pickRandom(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[ZombRand(#tbl) + 1]
end

--- Get current game day.
local function getCurrentDay()
    local gt = getGameTime()
    if not gt then return 1 end
    return gt:getNightsSurvived() + 1
end

--- Get current world age in minutes.
local function getWorldAgeMinutes()
    local gt = getGameTime()
    if not gt then return 0 end
    return gt:getWorldAgeHours() * 60
end

--- Get market zones if Living Market is enabled, nil otherwise.
local function getMarketZones()
    local ok, enabled = PhobosLib.safecall(function()
        return POS_Sandbox.isLivingMarketEnabled()
    end)
    if ok and enabled and POS_Constants.MARKET_ZONES then
        return POS_Constants.MARKET_ZONES
    end
    return nil
end

--- Remove oldest ambient records if we exceed the cap.
--- Walks all categories and removes the oldest observations
--- that were sourced from the ambient system.
local function pruneAmbientRecords()
    local maxRecords = POS_Constants.AMBIENT_INTEL_MAX_RECORDS
    local allRecords = {}

    local categories = POS_MarketRegistry.getVisibleCategories({})
    for _, cat in ipairs(categories) do
        local ok, catData = PhobosLib.safecall(
            POS_MarketDatabase.getCategoryData, cat.id
        )
        if ok and catData and catData.observations then
            for _, obs in ipairs(catData.observations) do
                if obs.sourcePrefix == POS_Constants.AMBIENT_INTEL_SOURCE_PREFIX then
                    allRecords[#allRecords + 1] = {
                        categoryId = cat.id,
                        day = obs.day or 0,
                        id = obs.id,
                    }
                end
            end
        end
    end

    if #allRecords <= maxRecords then return end

    -- Sort oldest first
    table.sort(allRecords, function(a, b) return a.day < b.day end)

    local toRemove = #allRecords - maxRecords
    for i = 1, toRemove do
        PhobosLib.safecall(
            POS_MarketDatabase.removeRecord,
            allRecords[i].categoryId, allRecords[i].id
        )
    end
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Initialise the ambient intel system.
--- Called from OnGameStart. Uses PhobosLib.lazyInit() guard.
function POS_AmbientIntel.init()
    if _initialised then return end
    _initialised = true
    Events.EveryOneMinute.Add(POS_AmbientIntel.onEveryOneMinute)
    PhobosLib.debug("POS", _TAG, "Ambient intel system initialised")
end

--- EveryOneMinute tick handler.
--- Generates low-confidence market observations at the configured interval.
function POS_AmbientIntel.onEveryOneMinute()
    -- Gate: must be connected to POSnet
    if not isPlayerConnected() then return end

    -- Gate: check interval
    local nowMinutes = getWorldAgeMinutes()
    local interval = POS_Sandbox.getAmbientIntelInterval()
    if (nowMinutes - _lastTickMinute) < interval then return end

    -- Determine observation count
    local minObs = POS_Constants.AMBIENT_INTEL_MIN_OBS
    local maxObs = POS_Constants.AMBIENT_INTEL_MAX_OBS
    local count = minObs + ZombRand(maxObs - minObs + 1)

    -- Get visible categories
    local categories = POS_MarketRegistry.getVisibleCategories({})
    if not categories or #categories == 0 then
        _lastTickMinute = nowMinutes
        return
    end

    local currentDay = getCurrentDay()
    local zones = getMarketZones()
    local generated = 0
    local usedCategories = {}

    for _ = 1, count do
        -- Pick random category with anti-repetition
        local catId = nil
        local attempts = 0
        local maxAttempts = #categories * 2
        while not catId and attempts < maxAttempts do
            local candidate = pickRandom(categories)
            if candidate and PhobosLib.avoidRecent(
                candidate.id, _recentCategories,
                POS_Constants.AMBIENT_INTEL_HISTORY_SIZE
            ) then
                catId = candidate.id
            end
            attempts = attempts + 1
        end

        -- Fallback: if anti-repetition exhausted, just pick any
        if not catId then
            local fallback = pickRandom(categories)
            if fallback then catId = fallback.id end
        end

        if catId then
            -- Get base price
            local basePrice = POS_Constants.MARKET_NOTE_BASE_PRICES[catId]
                or POS_Constants.MARKET_NOTE_BASE_PRICE_DEFAULT

            -- Apply noise
            local noise = POS_Constants.AMBIENT_INTEL_PRICE_NOISE
            local price = basePrice * (1 + PhobosLib.randFloat(-noise, noise))

            -- Pick random stock bucket
            local stock = pickRandom(STOCK_BUCKETS)

            -- Pick random source (resolve via safeGetText)
            local sourceKey = pickRandom(SOURCE_POOL)
            local source = PhobosLib.safeGetText(sourceKey)

            -- Pick random zone (only if Living Market enabled)
            local zoneId = nil
            if zones and #zones > 0 then
                zoneId = pickRandom(zones)
            end

            -- Build record
            local record = {
                id = POS_Constants.AMBIENT_INTEL_SOURCE_PREFIX
                    .. tostring(currentDay) .. "_" .. tostring(ZombRand(100000)),
                categoryId    = catId,
                price         = price,
                stock         = stock,
                confidence    = POS_Constants.CONFIDENCE_LOW,
                source        = source,
                sourceTier    = POS_Constants.SOURCE_TIER_BROADCAST,
                day           = currentDay,
                zoneId        = zoneId,
                sourcePrefix  = POS_Constants.AMBIENT_INTEL_SOURCE_PREFIX,
            }

            -- Select random items for discovery
            local selectedItems = POS_ItemPool.selectRandomItems(catId,
                ZombRand(POS_Constants.AMBIENT_INTEL_MIN_ITEMS,
                    POS_Constants.AMBIENT_INTEL_MAX_ITEMS + 1))
            record.discoveredItems = {}
            record.items = {}
            for _, item in ipairs(selectedItems) do
                local ft = item.fullType or item
                record.discoveredItems[#record.discoveredItems + 1] = ft
                record.items[#record.items + 1] = {
                    fullType = ft,
                    price = price,
                }
            end

            -- Add to database
            PhobosLib.safecall(POS_MarketDatabase.addRecord, record)
            generated = generated + 1
            usedCategories[#usedCategories + 1] = catId
        end
    end

    -- Prune excess ambient records
    PhobosLib.safecall(pruneAmbientRecords)

    PhobosLib.debug("POS", _TAG,
        "Generated " .. tostring(generated) .. " ambient observations")

    -- Emit event for SignalPanel and other subscribers
    if generated > 0 and POS_Events and POS_Events.OnAmbientIntelReceived then
        POS_Events.OnAmbientIntelReceived:trigger({
            count = generated,
            categories = usedCategories or {},
        })
    end

    _lastTickMinute = nowMinutes
end

--- Returns the ambient source name pool (for testing/extension).
function POS_AmbientIntel.getSourcePool()
    return SOURCE_POOL
end

---------------------------------------------------------------
-- Registration
---------------------------------------------------------------

Events.OnGameStart.Add(POS_AmbientIntel.init)
