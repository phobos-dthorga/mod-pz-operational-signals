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
-- POS_MarketReconAction.lua
-- Timed action for field market note-taking.
-- Uses ISBaseTimedAction pattern — consumes paper, damages
-- writing tool, generates a Raw Market Note with procedural data.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_RoomCategoryMap"
require "POS_Reputation"
require "TimedActions/ISBaseTimedAction"

POS_MarketReconAction = ISBaseTimedAction:derive("POS_MarketReconAction")

local WRITING_TOOLS = {
    "Base.Pen", "Base.Pencil", "Base.RedPen", "Base.BluePen",
    "Base.GreenPen", "Base.PenMultiColor", "Base.PenFancy",
    "Base.PenSpiffo", "Base.PencilSpiffo",
}

local PAPER_TYPES = { "Base.SheetPaper2", "Base.Notebook" }

--- Find a writing tool in inventory.
local function findWritingTool(player)
    local inv = player:getInventory()
    for _, fullType in ipairs(WRITING_TOOLS) do
        local item = inv:getFirstTypeRecurse(fullType)
        if item then return item end
    end
    return nil
end

--- Find paper in inventory.
local function findPaper(player)
    local inv = player:getInventory()
    for _, fullType in ipairs(PAPER_TYPES) do
        local item = inv:getFirstTypeRecurse(fullType)
        if item then return item end
    end
    return nil
end

--- Generate a procedural source name from location.
local function generateSourceName(location)
    local prefixes = { "Contact", "Trader", "Supplier", "Broker", "Merchant" }
    local idx = (ZombRand(#prefixes) or 0) + 1
    return prefixes[idx] .. " at " .. (location or PhobosLib.safeGetText("UI_POS_Market_Unknown"))
end

--- Generate a randomised price for a category.
--- Uses POS_PriceEngine when available, falls back to hardcoded base prices.
local function generatePrice(categoryId, ctx)
    if POS_PriceEngine and POS_PriceEngine.generatePrice then
        -- Pick a representative item for category-level price
        local items = POS_ItemPool and POS_ItemPool.getItemsForCategory(categoryId)
        if items and #items > 0 then
            local item = items[ZombRand(#items) + 1]
            return POS_PriceEngine.generatePrice(item.fullType, categoryId, ctx)
        end
    end
    -- Fallback to existing logic if pool not ready
    local basePrices = {
        fuel = 8.0, medicine = 12.0, food = 5.0,
        ammunition = 15.0, tools = 10.0, radio = 20.0,
        chemicals = 18.0, agriculture = 6.0, biofuel = 9.0,
        specimens = 25.0, biohazard = 30.0,
    }
    local base = basePrices[categoryId] or 10.0
    local variancePct = POS_Constants.PRICE_BASE_VARIANCE_PCT / 100
    local variance = base * variancePct
    local price = base + (ZombRand(math.floor(variance * 200)) - variance * 100) / 100
    return math.floor(price * 100 + 0.5) / 100
end

--- Generate stock estimate.
local function generateStock()
    local r = ZombRand(100)
    if r < 10 then return "none" end
    if r < 40 then return "low" end
    if r < 75 then return "medium" end
    return "high"
end

function POS_MarketReconAction:new(player, categoryId, location)
    local o = ISBaseTimedAction.new(self, player)
    o.categoryId = categoryId
    o.location = location or PhobosLib.safeGetText("UI_POS_Market_Unknown")
    o.paper = nil
    o.writingTool = nil

    -- Check for repeat visit discount
    local actionTime = POS_Sandbox and POS_Sandbox.getMarketNoteActionTime
        and POS_Sandbox.getMarketNoteActionTime()
        or POS_Constants.MARKET_NOTE_ACTION_TIME
    -- TODO: check modData for repeat visit and apply discount
    o.maxTime = actionTime

    return o
end

function POS_MarketReconAction:isValid()
    return self.character and not self.character:isDead()
        and findWritingTool(self.character) ~= nil
        and findPaper(self.character) ~= nil
end

function POS_MarketReconAction:start()
    -- Lock items
    self.paper = findPaper(self.character)
    self.writingTool = findWritingTool(self.character)

    -- Play writing animation
    self:setActionAnim("Write")
    self:setOverrideHandModels(nil, nil)
end

function POS_MarketReconAction:update()
    -- Character mumbles periodically
    if self.character and ZombRand(300) == 0 then
        self.character:Say(PhobosLib.safeGetText("UI_POS_Market_Mumble"))
    end
end

function POS_MarketReconAction:stop()
    ISBaseTimedAction.stop(self)
end

function POS_MarketReconAction:perform()
    local player = self.character
    if not player then return end
    local inv = player:getInventory()
    if not inv then return end

    -- Consume paper
    if self.paper and inv:contains(self.paper) then
        inv:Remove(self.paper)
    end

    -- Damage writing tool (reuses existing sandbox options)
    if self.writingTool then
        local dmgChance = POS_Sandbox and POS_Sandbox.getWritingDamageChance
            and POS_Sandbox.getWritingDamageChance() or 20
        if ZombRand(100) < dmgChance then
            local dmgAmount = POS_Sandbox and POS_Sandbox.getWritingDamageAmount
                and POS_Sandbox.getWritingDamageAmount() or 7
            local variance = ZombRand(5) - 2  -- +/-2
            local cond = self.writingTool:getCondition()
            if cond then
                self.writingTool:setCondition(math.max(0, cond - dmgAmount - variance))
            end
        end
    end

    -- Determine confidence from reputation
    local confidence = "low"
    if POS_Reputation and POS_Reputation.getTier then
        local tier = POS_Reputation.getTier(player)
        if tier >= 4 then confidence = "high"
        elseif tier >= 2 then confidence = "medium"
        end
    end

    -- Create Raw Market Note
    local note = inv:AddItem(POS_Constants.ITEM_RAW_MARKET_NOTE)
    if note then
        local ctx = { sourceTier = "field" }
        local md = note:getModData()
        md[POS_Constants.MD_NOTE_TYPE] = "market"
        md[POS_Constants.MD_NOTE_CATEGORY] = self.categoryId
        md[POS_Constants.MD_NOTE_SOURCE] = generateSourceName(self.location)
        md[POS_Constants.MD_NOTE_LOCATION] = self.location
        md[POS_Constants.MD_NOTE_PRICE] = generatePrice(self.categoryId, ctx)
        md[POS_Constants.MD_NOTE_STOCK] = generateStock()
        md[POS_Constants.MD_NOTE_RECORDED] = getGameTime():getNightsSurvived()
        md[POS_Constants.MD_NOTE_CONFIDENCE] = confidence

        -- Store item-level data from POS_ItemPool + POS_PriceEngine
        local poolSize = POS_Sandbox and POS_Sandbox.getItemSelectionPoolSize
            and POS_Sandbox.getItemSelectionPoolSize() or 3
        local selectedItems = POS_ItemPool and POS_ItemPool.selectItems(self.categoryId, poolSize, ctx)
        if selectedItems and #selectedItems > 0
                and POS_PriceEngine and POS_PriceEngine.generatePrices then
            local prices = POS_PriceEngine.generatePrices(selectedItems, self.categoryId, ctx)
            if prices and #prices > 0 then
                local itemData = {}
                for i, p in ipairs(prices) do
                    itemData[i] = p.fullType .. ":" .. tostring(p.price)
                end
                md[POS_Constants.MD_NOTE_ITEMS] = table.concat(itemData, "|")
            end
        end
    end

    PhobosLib.debug("POS", "[POS:ReconAction]",
        "Market note created for category: " .. self.categoryId)

    ISBaseTimedAction.perform(self)
end
