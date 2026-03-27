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
-- POS_MarketBroadcaster.lua
-- Server-side market data broadcaster.
-- Generates randomised market intel packets and broadcasts
-- them to all connected clients via sendServerCommand.
-- Broadcast data is lower quality than field-gathered notes.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_MarketRegistry"
require "POS_MarketDatabase"

POS_MarketBroadcaster = {}

local _TAG = "[POS:MarketBcast]"

--- Delegate to the central SP-safe broadcast helper.
local function broadcastToAll(module, command, args)
    if POS_BroadcastSystem and POS_BroadcastSystem.broadcastToAll then
        POS_BroadcastSystem.broadcastToAll(module, command, args)
    end
end

--- Last market broadcast timestamp (real-time milliseconds).
local lastMarketBroadcastTime = 0

--- Whether the market broadcaster is active.
local broadcasterActive = false

--- Base prices per category (same as field notes for consistency).
local BASE_PRICES = {
    fuel = 8.0, medicine = 12.0, food = 5.0,
    ammunition = 15.0, tools = 10.0, radio = 20.0,
    chemicals = 18.0, agriculture = 6.0, biofuel = 9.0,
    specimens = 25.0, biohazard = 30.0,
}

--- Source name prefixes for broadcast intel.
local BROADCAST_SOURCES = {
    "Signal intercept", "Radio chatter", "Relay report",
    "Encrypted broadcast", "Overheard transmission",
}

--- Generate a randomised price for a category.
--- Broadcast prices have wider variance than field notes.
--- @param categoryId string
--- @return number
local function generateBroadcastPrice(categoryId)
    local base = BASE_PRICES[categoryId] or 10.0
    local variance = base * 0.5  -- +/-50% (wider than field notes)
    local price = base + (ZombRand(math.floor(variance * 200)) - variance * 100) / 100
    return math.floor(price * 100 + 0.5) / 100
end

--- Generate a broadcast stock estimate.
--- @return string
local function generateBroadcastStock()
    local r = ZombRand(100)
    if r < 15 then return POS_Constants.STOCK_NONE end
    if r < 45 then return POS_Constants.STOCK_LOW end
    if r < 80 then return POS_Constants.STOCK_MEDIUM end
    return POS_Constants.STOCK_HIGH
end

--- Generate a single market intel broadcast packet.
--- @return table|nil Broadcast data or nil on failure
function POS_MarketBroadcaster.generatePacket()
    -- Weighted category selection
    local allCats = POS_MarketRegistry.getVisibleCategories()
    local categoryId

    if PhobosLib and PhobosLib.weightedRandom then
        local selected = PhobosLib.weightedRandom(allCats, function(cat)
            local w = cat.weight or 1.0
            local bfm = cat.broadcastFrequencyMult or 1.0
            if cat.isEssential then
                w = w * 1.5
            end
            return w * bfm
        end)
        categoryId = selected and selected.id
    end

    -- Fallback to uniform random if weighted selection unavailable
    if not categoryId then
        local allIds = POS_MarketRegistry.getAllCategoryIds()
        if #allIds == 0 then return nil end
        categoryId = allIds[ZombRand(#allIds) + 1]
    end

    -- Generate broadcast source name
    local srcIdx = ZombRand(#BROADCAST_SOURCES) + 1
    local source = BROADCAST_SOURCES[srcIdx]

    -- Broadcast quality (hardcoded default)
    local quality = 50

    -- Broadcast confidence is always lower than field notes
    local confidence = "low"
    if quality >= 80 then
        confidence = "medium"
    end

    local currentDay = 0
    local gt = getGameTime and getGameTime()
    if gt then currentDay = gt:getNightsSurvived() end

    local packet = {
        id = "POS_BCAST_" .. tostring(getTimestampMs()),
        categoryId = categoryId,
        source = source,
        location = PhobosLib.safeGetText("UI_POS_Market_Unknown"),
        price = generateBroadcastPrice(categoryId),
        stock = generateBroadcastStock(),
        recordedDay = currentDay,
        confidence = confidence,
    }

    -- Generate item-level data for the packet
    local itemsPerPacket = POS_Sandbox and POS_Sandbox.getBroadcastItemsPerPacket
        and POS_Sandbox.getBroadcastItemsPerPacket() or 2
    local selectedItems = POS_ItemPool and POS_ItemPool.selectItems(
        categoryId, itemsPerPacket, { sourceTier = POS_Constants.SOURCE_TIER_BROADCAST })
    if selectedItems and #selectedItems > 0 then
        local prices = POS_PriceEngine and POS_PriceEngine.generatePrices(
            selectedItems, categoryId, { sourceTier = POS_Constants.SOURCE_TIER_BROADCAST })
        if prices then
            packet.items = prices
        end
    end

    return packet
end

--- Broadcast market data to all connected clients.
--- @return boolean True if broadcast was sent
function POS_MarketBroadcaster.broadcast()
    if not broadcasterActive then return false end

    local packet = POS_MarketBroadcaster.generatePacket()
    if not packet then
        PhobosLib.debug("POS", _TAG, "Failed to generate market packet")
        return false
    end

    -- Write broadcast observation directly to world state (server-side)
    if POS_MarketDatabase and POS_MarketDatabase.addRecord then
        POS_MarketDatabase.addRecord({
            id = packet.id,
            categoryId = packet.categoryId,
            price = packet.price,
            stock = packet.stock or "medium",
            source = packet.source or "Radio Broadcast",
            location = packet.location or "",
            recordedDay = POS_WorldState and POS_WorldState.getWorldDay() or 0,
            confidence = packet.confidence or "low",
            sourceTier = POS_Constants.SOURCE_TIER_BROADCAST,
            quality = 50,
            items = packet.items,
        })
    end

    -- Notify all clients that new market data is available
    broadcastToAll(POS_Constants.CMD_MODULE, POS_Constants.CMD_MARKET_BROADCAST, {
        marketData = packet,
    })

    PhobosLib.debug("POS", _TAG,
        "Market broadcast sent: " .. packet.categoryId
        .. " @ $" .. packet.price)

    return true
end

--- Tick handler — checks if it's time to broadcast market data.
--- Called by POS_BroadcastSystem.onEveryOneMinute.
function POS_MarketBroadcaster.tick()
    if not broadcasterActive then return end

    local now = getTimestampMs()
    local intervalMins = POS_Sandbox and POS_Sandbox.getMarketBroadcastInterval
        and POS_Sandbox.getMarketBroadcastInterval() or 120
    local intervalMs = intervalMins * 60 * 1000

    if (now - lastMarketBroadcastTime) >= intervalMs then
        POS_MarketBroadcaster.broadcast()
        lastMarketBroadcastTime = now
    end
end

--- Start the market broadcaster.
function POS_MarketBroadcaster.start()
    broadcasterActive = true
    lastMarketBroadcastTime = getTimestampMs()
    PhobosLib.debug("POS", _TAG, "Market broadcaster started")
end

--- Stop the market broadcaster.
function POS_MarketBroadcaster.stop()
    broadcasterActive = false
    PhobosLib.debug("POS", _TAG, "Market broadcaster stopped")
end

--- Whether the broadcaster is currently active.
--- @return boolean
function POS_MarketBroadcaster.isActive()
    return broadcasterActive
end
