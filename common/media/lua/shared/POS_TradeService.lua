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
-- POS_TradeService.lua
-- Core business logic for POSnet's standalone trading system.
-- Provides query, validation, and transaction execution for
-- buying/selling items through wholesalers.
-- All external calls wrapped in PhobosLib.safecall.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_WorldState"
require "POS_PlayerState"
require "POS_SandboxIntegration"

POS_TradeService = POS_TradeService or {}

local _TAG = "[POS:TradeService]"

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

--- Build a set from an array of state strings for O(1) lookup.
---@param states string[]
---@return table
local function stateSet(states)
    local set = {}
    for _, s in ipairs(states) do set[s] = true end
    return set
end

--- Lazily resolved blocked-state sets (built once on first access).
local _blockedBuySet
local _blockedSellSet

local function getBlockedBuySet()
    if not _blockedBuySet then
        _blockedBuySet = stateSet(POS_Constants.TRADE_BLOCKED_BUY_STATES)
    end
    return _blockedBuySet
end

local function getBlockedSellSet()
    if not _blockedSellSet then
        _blockedSellSet = stateSet(POS_Constants.TRADE_BLOCKED_SELL_STATES)
    end
    return _blockedSellSet
end

--- Combined blocked set (buy + sell).
local function isTotallyBlocked(state)
    return getBlockedBuySet()[state] and getBlockedSellSet()[state]
end

--- Get wholesaler table by ID from world state.
---@param wholesalerId string
---@return table|nil
local function getWholesaler(wholesalerId)
    local ok, wholesalers = PhobosLib.safecall(POS_WorldState.getWholesalers)
    if not ok or not wholesalers or not wholesalers.entries then return nil end
    for _, w in ipairs(wholesalers.entries) do
        if w.id == wholesalerId then return w end
    end
    return nil
end

--- Count items of a given fullType in a player's inventory.
---@param player   IsoPlayer
---@param fullType string
---@return number
local function countPlayerItems(player, fullType)
    local ok, items = PhobosLib.safecall(
        PhobosLib.findAllItemsByFullType, player, fullType)
    if not ok or not items then return 0 end
    return #items
end

--- Award SIGINT XP for a trade transaction.
---@param player   IsoPlayer
---@param quantity number
local function awardTradeXP(player, quantity)
    local baseXP = POS_Constants.SIGINT_XP_TRADE_BASE
    local xp = baseXP
    if quantity >= POS_Constants.TRADE_BULK_DISCOUNT_THRESHOLD then
        xp = xp + POS_Constants.SIGINT_XP_TRADE_BULK_BONUS
    end
    local ok, POS_SIGINTSkill = PhobosLib.safecall(require, "POS_SIGINTSkill")
    if ok and POS_SIGINTSkill and POS_SIGINTSkill.addXP then
        PhobosLib.safecall(POS_SIGINTSkill.addXP, player, xp)
        PhobosLib.debug("POS", _TAG, "Awarded " .. tostring(xp)
            .. " SIGINT XP for trade (qty=" .. tostring(quantity) .. ")")
    end
end

--- Send trade notification to player via PhobosLib.notifyOrSay.
---@param player  IsoPlayer
---@param textKey string   Translation key
---@param args    table    Format args for the message
local function notifyTrade(player, textKey, args)
    PhobosLib.safecall(PhobosLib.notifyOrSay, player, {
        textKey  = textKey,
        type     = "success",
        channel  = "POS",
        args     = args,
    })
end


---------------------------------------------------------------
-- Query Functions
---------------------------------------------------------------

--- Get tradeable wholesalers sorted by regionId.
--- Filters out wholesalers whose state is in both blocked-buy
--- and blocked-sell sets (completely untradeable).
---@param player IsoPlayer|nil
---@return table[]  Array of wholesaler summaries
function POS_TradeService.getTradeableWholesalers(player)
    local result = {}
    local ok, wholesalers = PhobosLib.safecall(POS_WorldState.getWholesalers)
    if not ok or not wholesalers or not wholesalers.entries then return result end

    local blockedBuy  = getBlockedBuySet()
    local blockedSell = getBlockedSellSet()

    local ok2, wsRegistry = PhobosLib.safecall(function()
        return POS_WholesalerService and POS_WholesalerService.getRegistry()
    end)

    for _, w in ipairs(wholesalers.entries) do
        local state = w._operationalState or POS_Constants.WHOLESALER_STATE_STABLE
        -- Include if at least one trade direction is open
        if not (blockedBuy[state] and blockedSell[state]) then
            local displayName = w.name or w.id
            if ok2 and wsRegistry then
                local ok3, dn = PhobosLib.safecall(
                    PhobosLib.getRegistryDisplayName, wsRegistry, w.id, w.name)
                if ok3 and dn then displayName = dn end
            end

            local ok4, stateName = PhobosLib.safecall(
                POS_WholesalerService.getStateDisplayName, state)
            if not ok4 then stateName = state end

            -- Collect category IDs from categoryWeights
            local categories = {}
            if w.categoryWeights then
                for catId, weight in pairs(w.categoryWeights) do
                    if weight > 0 then
                        categories[#categories + 1] = catId
                    end
                end
                table.sort(categories)
            end

            result[#result + 1] = {
                id               = w.id,
                name             = w.name or w.id,
                displayName      = displayName,
                regionId         = w.regionId,
                state            = state,
                stateDisplayName = stateName,
                categories       = categories,
                stockLevel       = w.stockLevel or 0,
            }
        end
    end

    -- Sort by regionId
    table.sort(result, function(a, b)
        return (a.regionId or "") < (b.regionId or "")
    end)

    return result
end


--- Get items available for purchase from a wholesaler in a category.
--- Items are filtered by player discovery state — only discovered items
--- are returned. totalCount is stored on the result for UI display.
---@param wholesalerId string
---@param categoryId   string
---@param player       IsoPlayer|nil
---@return table[]  Array of { fullType, displayName, buyPrice, sellPrice, stockIndicator }
function POS_TradeService.getBuyableItems(wholesalerId, categoryId, player)
    local result = {}
    local wholesaler = getWholesaler(wholesalerId)
    if not wholesaler then return result end

    local ok, items = PhobosLib.safecall(POS_ItemPool.getItemsForCategory, categoryId)
    if not ok or not items then return result end

    -- Filter by player discoveries
    local totalCount = #items
    if player then
        local discovered = POS_PlayerState.getDiscoveredItems(player)
        local filtered = {}
        for _, item in ipairs(items) do
            if discovered[item.fullType] then
                filtered[#filtered + 1] = item
            end
        end
        items = filtered
    end

    for _, item in ipairs(items) do
        local fullType = item.fullType
        local ok2, displayName = PhobosLib.safecall(
            PhobosLib.getItemDisplayName, fullType)
        if not ok2 then displayName = fullType end

        local buyPrice  = POS_TradeService.computeBuyPrice(
            fullType, categoryId, wholesaler, player)
        local sellPrice = POS_TradeService.computeSellPrice(
            fullType, categoryId, wholesaler, player)
        local stockKey  = POS_TradeService.getStockIndicatorKey(
            wholesaler, categoryId)

        result[#result + 1] = {
            fullType       = fullType,
            displayName    = displayName,
            buyPrice       = buyPrice,
            sellPrice      = sellPrice,
            stockIndicator = stockKey,
        }
    end

    result.totalCount = totalCount
    return result
end


--- Get items in player inventory matching a wholesaler's category.
---@param wholesalerId string
---@param categoryId   string
---@param player       IsoPlayer
---@return table[]  Array of { fullType, displayName, sellPrice, playerCount }
function POS_TradeService.getSellableItems(wholesalerId, categoryId, player)
    local result = {}
    if not player then return result end

    local wholesaler = getWholesaler(wholesalerId)
    if not wholesaler then return result end

    local ok, poolItems = PhobosLib.safecall(POS_ItemPool.getItemsForCategory, categoryId)
    if not ok or not poolItems then return result end

    -- Build lookup set of fullTypes in this category
    local validTypes = {}
    for _, item in ipairs(poolItems) do
        validTypes[item.fullType] = true
    end

    -- Aggregate player inventory by fullType
    local counts = {}
    local inventory = player:getInventory()
    if not inventory then return result end

    local ok2, allItems = PhobosLib.safecall(function()
        return inventory:getItems()
    end)
    if not ok2 or not allItems then return result end

    for i = 0, allItems:size() - 1 do
        local ok3, item = PhobosLib.safecall(allItems.get, allItems, i)
        if ok3 and item then
            local ok4, ft = PhobosLib.safecall(item.getFullType, item)
            if ok4 and ft and validTypes[ft] then
                counts[ft] = (counts[ft] or 0) + 1
            end
        end
    end

    -- Build result entries
    for fullType, count in pairs(counts) do
        local ok5, displayName = PhobosLib.safecall(
            PhobosLib.getItemDisplayName, fullType)
        if not ok5 then displayName = fullType end

        local sellPrice = POS_TradeService.computeSellPrice(
            fullType, categoryId, wholesaler, player)

        result[#result + 1] = {
            fullType    = fullType,
            displayName = displayName,
            sellPrice   = sellPrice,
            playerCount = count,
        }
    end

    return result
end


---------------------------------------------------------------
-- Price Computation
---------------------------------------------------------------

--- Compute buy price for an item at a wholesaler.
--- Formula: basePrice * stateMultiplier * (1 + markupBias)
--- Applies TRADE_DUMPING_EXTRA_DISCOUNT if state is dumping.
---@param fullType   string
---@param categoryId string
---@param wholesaler table
---@param player     IsoPlayer|nil
---@return number
function POS_TradeService.computeBuyPrice(fullType, categoryId, wholesaler, player)
    -- Try POS_PriceEngine first, fall back to POS_ItemPool base price
    local basePrice
    if POS_PriceEngine and POS_PriceEngine.generatePrice then
        local ok, price = PhobosLib.safecall(
            POS_PriceEngine.generatePrice, fullType, categoryId, {
                player = player,
                zoneId = wholesaler.regionId,
            })
        if ok and price then
            basePrice = price
        end
    end
    if not basePrice then
        local ok, price = PhobosLib.safecall(POS_ItemPool.getBasePrice, fullType)
        if ok and price then
            basePrice = price
        else
            basePrice = POS_Constants.PRICE_MIN_OUTPUT
        end
    end

    -- State-based multiplier
    local state = wholesaler._operationalState
        or POS_Constants.WHOLESALER_STATE_STABLE
    local stateMultiplier = POS_Constants.WHOLESALER_PRICE_MULTIPLIER[state] or 1.0

    -- Markup bias from wholesaler profile
    local markupBias = wholesaler.markupBias or 0

    local price = basePrice * stateMultiplier * (1 + markupBias)

    -- Extra discount for dumping state
    if state == POS_Constants.WHOLESALER_STATE_DUMPING then
        price = price * (1 - POS_Constants.TRADE_DUMPING_EXTRA_DISCOUNT)
    end

    return math.floor(price)
end


--- Compute sell price for an item.
--- Formula: buyPrice * sellPriceRatio.
---@param fullType   string
---@param categoryId string
---@param wholesaler table
---@param player     IsoPlayer|nil
---@return number
function POS_TradeService.computeSellPrice(fullType, categoryId, wholesaler, player)
    local buyPrice = POS_TradeService.computeBuyPrice(
        fullType, categoryId, wholesaler, player)
    local ratio = POS_Sandbox.getSellPriceRatio
        and POS_Sandbox.getSellPriceRatio()
        or POS_Constants.TRADE_DEFAULT_SELL_RATIO
    return math.floor(buyPrice * ratio)
end


--- Compute bulk discount multiplier.
--- Returns < 1.0 if quantity meets bulk threshold, otherwise 1.0.
---@param quantity number
---@return number  Discount multiplier (e.g. 0.95 for 5% off)
function POS_TradeService.computeBulkDiscount(quantity)
    local threshold = POS_Constants.TRADE_BULK_DISCOUNT_THRESHOLD
    if quantity >= threshold then
        local pct = POS_Constants.TRADE_BULK_DISCOUNT_PERCENT
        return 1.0 - (pct / 100)
    end
    return 1.0
end

--- Get the player's current money balance.
---@param player IsoPlayer|nil  Defaults to getPlayer()
---@return number  Balance in dollars
function POS_TradeService.getPlayerBalance(player)
    player = player or getPlayer()
    if not player then return 0 end
    return PhobosLib.countPlayerMoney(player) or 0
end


--- Map wholesaler stockLevel to a translation key for UI display.
---@param wholesaler table
---@param categoryId string
---@return string  Translation key (e.g. "UI_POS_Trade_StockAbundant")
function POS_TradeService.getStockIndicatorKey(wholesaler, categoryId)
    local stockLevel = wholesaler.stockLevel or 0
    local stockNorm = PhobosLib.clamp(math.floor(stockLevel * 100), 0, 100)

    local ok, tier = PhobosLib.safecall(
        PhobosLib.resolveThresholdTier,
        stockNorm,
        POS_Constants.TRADE_STOCK_THRESHOLDS,
        POS_Constants.TRADE_STOCK_THRESHOLDS[#POS_Constants.TRADE_STOCK_THRESHOLDS])
    if ok and tier and tier.key then
        return tier.key
    end

    -- Fallback: use STOCK_LEVEL_TIERS via getQualityTier
    local ok2, qTier = PhobosLib.safecall(
        PhobosLib.getQualityTier, stockNorm, POS_Constants.STOCK_LEVEL_TIERS)
    if ok2 and qTier and qTier.name then
        return qTier.name
    end

    return "UI_POS_Trade_StockUnknown"
end


---------------------------------------------------------------
-- Validation Functions
---------------------------------------------------------------

--- Validate a buy transaction.
---@param player       IsoPlayer
---@param wholesalerId string
---@param fullType     string
---@param quantity     number
---@return boolean ok
---@return string|nil errorKey
function POS_TradeService.validateBuy(player, wholesalerId, fullType, quantity)
    -- Wholesaler must exist
    local wholesaler = getWholesaler(wholesalerId)
    if not wholesaler then
        return false, "UI_POS_Trade_Err_WholesalerNotFound"
    end

    -- State must not be buy-blocked
    local state = wholesaler._operationalState
        or POS_Constants.WHOLESALER_STATE_STABLE
    if getBlockedBuySet()[state] then
        if state == POS_Constants.WHOLESALER_STATE_WITHHOLDING then
            return false, "UI_POS_Trade_Err_Withholding"
        end
        return false, "UI_POS_Trade_Err_Collapsing"
    end

    -- Quantity cap
    if quantity > POS_Constants.TRADE_MAX_QUANTITY_PER_TX then
        return false, "UI_POS_Trade_Err_MaxQuantity"
    end

    -- Compute total cost and check affordability
    local unitPrice = POS_TradeService.computeBuyPrice(
        fullType, nil, wholesaler, player)
    local discount = POS_TradeService.computeBulkDiscount(quantity)
    local totalCost = math.floor(unitPrice * quantity * discount)

    local ok, balance = PhobosLib.safecall(PhobosLib.countPlayerMoney, player)
    if not ok then balance = 0 end
    if balance < totalCost then
        return false, "UI_POS_Trade_Err_NoMoney"
    end

    -- Stock check
    if wholesaler.stockLevel <= POS_Constants.TRADE_STOCK_LOW then
        return false, "UI_POS_Trade_Err_NoStock"
    end

    return true, nil
end


--- Validate a sell transaction.
---@param player       IsoPlayer
---@param wholesalerId string
---@param fullType     string
---@param quantity     number
---@return boolean ok
---@return string|nil errorKey
function POS_TradeService.validateSell(player, wholesalerId, fullType, quantity)
    -- Wholesaler must exist
    local wholesaler = getWholesaler(wholesalerId)
    if not wholesaler then
        return false, "UI_POS_Trade_Err_WholesalerNotFound"
    end

    -- State must not be sell-blocked
    local state = wholesaler._operationalState
        or POS_Constants.WHOLESALER_STATE_STABLE
    if getBlockedSellSet()[state] then
        return false, "UI_POS_Trade_Err_Collapsing"
    end

    -- Quantity cap
    if quantity > POS_Constants.TRADE_MAX_QUANTITY_PER_TX then
        return false, "UI_POS_Trade_Err_MaxQuantity"
    end

    -- Player must have enough items
    local playerCount = countPlayerItems(player, fullType)
    if playerCount < quantity then
        return false, "UI_POS_Trade_Err_NoItems"
    end

    return true, nil
end


---------------------------------------------------------------
-- Transaction Execution
---------------------------------------------------------------

--- Execute an atomic buy transaction.
---@param player       IsoPlayer
---@param wholesalerId string
---@param fullType     string
---@param quantity     number
---@return boolean success
---@return table|string|nil receipt or errorKey
function POS_TradeService.executeBuy(player, wholesalerId, fullType, quantity)
    -- Validate first
    local valid, errKey = POS_TradeService.validateBuy(
        player, wholesalerId, fullType, quantity)
    if not valid then
        PhobosLib.debug("POS", _TAG, "Buy validation failed: " .. tostring(errKey))
        return false, errKey
    end

    local wholesaler = getWholesaler(wholesalerId)

    -- Compute pricing
    local unitPrice = POS_TradeService.computeBuyPrice(
        fullType, nil, wholesaler, player)
    local discount  = POS_TradeService.computeBulkDiscount(quantity)
    local totalCost = math.floor(unitPrice * quantity * discount)

    -- Deduct money
    local ok1, removed = PhobosLib.safecall(PhobosLib.removeMoney, player, totalCost)
    if not ok1 or not removed then
        PhobosLib.debug("POS", _TAG, "Failed to remove money for buy tx")
        return false, "UI_POS_Trade_Err_NoMoney"
    end

    -- Grant items
    local ok2 = PhobosLib.safecall(PhobosLib.grantItems, player, fullType, quantity)
    if not ok2 then
        -- Rollback: refund money
        PhobosLib.safecall(PhobosLib.addMoney, player, totalCost)
        PhobosLib.debug("POS", _TAG, "Failed to grant items, money refunded")
        return false, "UI_POS_Trade_Err_GrantFailed"
    end

    -- Adjust wholesaler stock
    local depletion = POS_Constants.TRADE_STOCK_DEPLETION_PER_UNIT * quantity
    wholesaler.stockLevel = PhobosLib.clamp(
        wholesaler.stockLevel - depletion,
        POS_Constants.WHOLESALER_STOCK_MIN,
        POS_Constants.WHOLESALER_STOCK_MAX)

    -- Re-evaluate operational state
    PhobosLib.safecall(POS_WholesalerService.resolveOperationalState, wholesaler)
    wholesaler._operationalState = POS_WholesalerService.resolveOperationalState(wholesaler)

    -- Award SIGINT XP
    awardTradeXP(player, quantity)

    -- Get display name for receipt/notification
    local ok3, displayName = PhobosLib.safecall(
        PhobosLib.getItemDisplayName, fullType)
    if not ok3 then displayName = fullType end

    -- Get new balance
    local ok4, newBalance = PhobosLib.safecall(PhobosLib.countPlayerMoney, player)
    if not ok4 then newBalance = 0 end

    -- Notify player
    notifyTrade(player, "UI_POS_Trade_BuySuccess", {
        displayName, tostring(quantity), tostring(totalCost),
    })

    PhobosLib.debug("POS", _TAG, "Buy executed: " .. tostring(quantity)
        .. "x " .. fullType .. " for $" .. tostring(totalCost)
        .. " from " .. wholesalerId)

    -- Build receipt
    return true, {
        fullType     = fullType,
        displayName  = displayName,
        quantity     = quantity,
        unitPrice    = unitPrice,
        totalCost    = totalCost,
        discount     = discount,
        newBalance   = newBalance,
        wholesalerId = wholesalerId,
    }
end


--- Execute an atomic sell transaction.
---@param player       IsoPlayer
---@param wholesalerId string
---@param fullType     string
---@param quantity     number
---@return boolean success
---@return table|string|nil receipt or errorKey
function POS_TradeService.executeSell(player, wholesalerId, fullType, quantity)
    -- Validate first
    local valid, errKey = POS_TradeService.validateSell(
        player, wholesalerId, fullType, quantity)
    if not valid then
        PhobosLib.debug("POS", _TAG, "Sell validation failed: " .. tostring(errKey))
        return false, errKey
    end

    local wholesaler = getWholesaler(wholesalerId)

    -- Compute pricing
    local unitSellPrice = POS_TradeService.computeSellPrice(
        fullType, nil, wholesaler, player)
    local totalRevenue = math.floor(unitSellPrice * quantity)

    -- Consume items from inventory
    local ok1, consumed = PhobosLib.safecall(
        PhobosLib.consumeItems, player, fullType, quantity)
    if not ok1 or not consumed then
        PhobosLib.debug("POS", _TAG, "Failed to consume items for sell tx")
        return false, "UI_POS_Trade_Err_NoItems"
    end

    -- Add money
    local ok2 = PhobosLib.safecall(PhobosLib.addMoney, player, totalRevenue)
    if not ok2 then
        -- Rollback: return items
        PhobosLib.safecall(PhobosLib.grantItems, player, fullType, quantity)
        PhobosLib.debug("POS", _TAG, "Failed to add money, items returned")
        return false, "UI_POS_Trade_Err_PaymentFailed"
    end

    -- Adjust wholesaler stock (replenish)
    local replenish = POS_Constants.TRADE_STOCK_REPLENISH_PER_UNIT * quantity
    wholesaler.stockLevel = PhobosLib.clamp(
        wholesaler.stockLevel + replenish,
        POS_Constants.WHOLESALER_STOCK_MIN,
        POS_Constants.WHOLESALER_STOCK_MAX)

    -- Re-evaluate operational state
    wholesaler._operationalState = POS_WholesalerService.resolveOperationalState(wholesaler)

    -- Award SIGINT XP
    awardTradeXP(player, quantity)

    -- Get display name for receipt/notification
    local ok3, displayName = PhobosLib.safecall(
        PhobosLib.getItemDisplayName, fullType)
    if not ok3 then displayName = fullType end

    -- Get new balance
    local ok4, newBalance = PhobosLib.safecall(PhobosLib.countPlayerMoney, player)
    if not ok4 then newBalance = 0 end

    -- Notify player
    notifyTrade(player, "UI_POS_Trade_SellSuccess", {
        displayName, tostring(quantity), tostring(totalRevenue),
    })

    PhobosLib.debug("POS", _TAG, "Sell executed: " .. tostring(quantity)
        .. "x " .. fullType .. " for $" .. tostring(totalRevenue)
        .. " to " .. wholesalerId)

    -- Build receipt
    return true, {
        fullType     = fullType,
        displayName  = displayName,
        quantity     = quantity,
        unitPrice    = unitSellPrice,
        totalRevenue = totalRevenue,
        newBalance   = newBalance,
        wholesalerId = wholesalerId,
    }
end
