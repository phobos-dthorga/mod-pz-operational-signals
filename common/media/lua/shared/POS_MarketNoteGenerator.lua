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
-- POS_MarketNoteGenerator.lua
-- Shared service for generating market note data.
-- Used by POS_MarketReconAction (timed action) and
-- POS_CraftCallbacks (VHS tape review).
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MarketNoteGenerator = {}

---------------------------------------------------------------
-- Data generation helpers
---------------------------------------------------------------

--- Generate a procedural source name from location.
---@param location string|nil
---@return string
function POS_MarketNoteGenerator.generateSourceName(location)
    local prefixes = { "Contact", "Trader", "Supplier", "Broker", "Merchant" }
    local idx = (ZombRand(#prefixes) or 0) + 1
    return prefixes[idx] .. " at " .. (location or PhobosLib.safeGetText("UI_POS_Market_Unknown"))
end

--- Generate a randomised price for a category.
--- Uses POS_PriceEngine when available, falls back to base prices.
---@param categoryId string
---@param ctx table|nil  Context table (sourceTier, etc.)
---@return number
function POS_MarketNoteGenerator.generatePrice(categoryId, ctx)
    if POS_PriceEngine and POS_PriceEngine.generatePrice then
        local items = POS_ItemPool and POS_ItemPool.getItemsForCategory(categoryId)
        if items and #items > 0 then
            local item = items[ZombRand(#items) + 1]
            return POS_PriceEngine.generatePrice(item.fullType, categoryId, ctx)
        end
    end
    local base = POS_Constants.MARKET_NOTE_BASE_PRICES[categoryId]
        or POS_Constants.MARKET_NOTE_BASE_PRICE_DEFAULT
    local variancePct = POS_Constants.PRICE_BASE_VARIANCE_PCT / 100
    local variance = base * variancePct
    local price = base + (ZombRand(math.floor(variance * 200)) - variance * 100) / 100
    return math.floor(price * 100 + 0.5) / 100
end

--- Generate a randomised stock estimate.
---@return string One of STOCK_NONE, STOCK_LOW, STOCK_MEDIUM, STOCK_HIGH values
function POS_MarketNoteGenerator.generateStock()
    local r = ZombRand(100)
    if r < POS_Constants.STOCK_THRESHOLD_NONE then return POS_Constants.STOCK_NONE end
    if r < POS_Constants.STOCK_THRESHOLD_LOW then return POS_Constants.STOCK_LOW end
    if r < POS_Constants.STOCK_THRESHOLD_MEDIUM then return POS_Constants.STOCK_MEDIUM end
    return POS_Constants.STOCK_HIGH
end

---------------------------------------------------------------
-- Item-level data generation
---------------------------------------------------------------

--- Select items and generate prices for a category.
--- Returns a pipe-delimited string of "fullType:price" entries.
---@param categoryId string
---@param ctx table|nil  Context table
---@return string|nil  Pipe-delimited item data, or nil if unavailable
function POS_MarketNoteGenerator.generateItemData(categoryId, ctx)
    local poolSize = POS_Sandbox and POS_Sandbox.getItemSelectionPoolSize
        and POS_Sandbox.getItemSelectionPoolSize()
        or POS_Constants.ITEM_SELECTION_POOL_SIZE_DEFAULT
    local selectedItems = POS_ItemPool and POS_ItemPool.selectItems(categoryId, poolSize, ctx)
    if not selectedItems or #selectedItems == 0 then return nil end
    if not POS_PriceEngine or not POS_PriceEngine.generatePrices then return nil end

    local prices = POS_PriceEngine.generatePrices(selectedItems, categoryId, ctx)
    if not prices or #prices == 0 then return nil end

    local itemData = {}
    for i, p in ipairs(prices) do
        itemData[i] = p.fullType .. ":" .. tostring(p.price)
    end
    return table.concat(itemData, "|")
end

---------------------------------------------------------------
-- ModData population
---------------------------------------------------------------

--- Populate a market note item's modData with generated market data.
---@param note any       InventoryItem (the market note)
---@param categoryId string
---@param location string
---@param confidence string  "low"/"medium"/"high"
---@param ctx table|nil      Context table (sourceTier, etc.)
function POS_MarketNoteGenerator.populateNoteModData(note, categoryId, location, confidence, ctx)
    if not note then return end
    local md = note:getModData()
    if not md then return end

    md[POS_Constants.MD_NOTE_TYPE] = "market"
    md[POS_Constants.MD_NOTE_CATEGORY] = categoryId
    md[POS_Constants.MD_NOTE_SOURCE] = POS_MarketNoteGenerator.generateSourceName(location)
    md[POS_Constants.MD_NOTE_LOCATION] = location
    md[POS_Constants.MD_NOTE_PRICE] = POS_MarketNoteGenerator.generatePrice(categoryId, ctx)
    md[POS_Constants.MD_NOTE_STOCK] = POS_MarketNoteGenerator.generateStock()
    md[POS_Constants.MD_NOTE_RECORDED] = getGameTime():getNightsSurvived()
    md[POS_Constants.MD_NOTE_CONFIDENCE] = confidence

    -- Item-level drill-down data
    local itemData = POS_MarketNoteGenerator.generateItemData(categoryId, ctx)
    if itemData then
        md[POS_Constants.MD_NOTE_ITEMS] = itemData
    end
end

---------------------------------------------------------------
-- Readable document creation
---------------------------------------------------------------

--- Create a readable document (PZ Literature API) for a market note.
---@param note any       InventoryItem
---@param categoryId string
---@param location string
---@param confidence string
function POS_MarketNoteGenerator.createReadableDocument(note, categoryId, location, confidence)
    if not PhobosLib or not PhobosLib.createReadableDocument then return end
    if not note then return end

    local catLabel = categoryId
    if POS_MarketRegistry and POS_MarketRegistry.getCategory then
        local catDef = POS_MarketRegistry.getCategory(categoryId)
        if catDef and catDef.labelKey then
            catLabel = PhobosLib.safeGetText(catDef.labelKey)
        end
    end

    local md = note:getModData()
    if not md then return end

    local pageLines = {}
    pageLines[#pageLines + 1] = "=== MARKET INTELLIGENCE REPORT ==="
    pageLines[#pageLines + 1] = ""
    pageLines[#pageLines + 1] = PhobosLib.safeGetText("UI_POS_Note_Category") .. ": " .. catLabel
    pageLines[#pageLines + 1] = PhobosLib.safeGetText("UI_POS_Note_Location") .. ": "
        .. PhobosLib.titleCase(location or PhobosLib.safeGetText("UI_POS_Market_Unknown"))
    pageLines[#pageLines + 1] = PhobosLib.safeGetText("UI_POS_Note_Date") .. ": Day "
        .. tostring(getGameTime():getNightsSurvived())
    pageLines[#pageLines + 1] = PhobosLib.safeGetText("UI_POS_Note_Confidence") .. ": " .. confidence
    pageLines[#pageLines + 1] = ""
    pageLines[#pageLines + 1] = "--- " .. PhobosLib.safeGetText("UI_POS_Note_PriceObservations") .. " ---"
    pageLines[#pageLines + 1] = ""

    local noteItems = md[POS_Constants.MD_NOTE_ITEMS]
    if noteItems and noteItems ~= "" then
        for entry in noteItems:gmatch("[^|]+") do
            local fullType, priceStr = entry:match("([^:]+):(.+)")
            if fullType and priceStr then
                local displayName = PhobosLib.getItemDisplayName(fullType)
                pageLines[#pageLines + 1] = displayName .. "  "
                    .. PhobosLib.formatPrice(tonumber(priceStr))
            end
        end
    else
        pageLines[#pageLines + 1] = PhobosLib.safeGetText("UI_POS_Note_PriceEstimate") .. ": "
            .. PhobosLib.formatPrice(md[POS_Constants.MD_NOTE_PRICE])
    end

    pageLines[#pageLines + 1] = ""
    pageLines[#pageLines + 1] = "--- " .. PhobosLib.safeGetText("UI_POS_Note_StockAssessment") .. " ---"
    pageLines[#pageLines + 1] = ""
    pageLines[#pageLines + 1] = PhobosLib.safeGetText("UI_POS_Note_SupplyLevel") .. ": "
        .. tostring(md[POS_Constants.MD_NOTE_STOCK] or PhobosLib.safeGetText("UI_POS_Market_Unknown"))
    pageLines[#pageLines + 1] = ""
    pageLines[#pageLines + 1] = "--- " .. PhobosLib.safeGetText("UI_POS_Note_Notes") .. " ---"
    pageLines[#pageLines + 1] = ""
    pageLines[#pageLines + 1] = PhobosLib.safeGetText("UI_POS_Note_FieldObservations")
    pageLines[#pageLines + 1] = PhobosLib.safeGetText("UI_POS_Note_UploadInstructions")

    local pageText = table.concat(pageLines, "\n")
    PhobosLib.createReadableDocument(note, PhobosLib.safeGetText("UI_POS_Note_Title") .. ": " .. catLabel, { pageText })
end
