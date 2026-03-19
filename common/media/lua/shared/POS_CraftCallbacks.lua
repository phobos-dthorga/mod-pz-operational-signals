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
-- POS_CraftCallbacks.lua
-- OnCreate callbacks for POSnet crafting recipes.
--
-- CraftFieldReport: transfers operation ID from photograph to
-- field report, and applies small damage to writing implement.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_CraftCallbacks = POS_CraftCallbacks or {}

--- Writing implement full type names for damage targeting.
local WRITING_IMPLEMENTS = {
    ["Base.Pen"] = true,
    ["Base.Pencil"] = true,
    ["Base.RedPen"] = true,
    ["Base.BluePen"] = true,
    ["Base.GreenPen"] = true,
    ["Base.PenMultiColor"] = true,
    ["Base.PenFancy"] = true,
    ["Base.PenSpiffo"] = true,
    ["Base.PencilSpiffo"] = true,
}

--- OnCreate callback for the CraftFieldReport recipe.
--- Transfers the operation ID from the consumed ReconPhotograph
--- to the created FieldReport, and damages the writing implement.
---@param items table Input items (B42: may be table or ArrayList)
---@param result any The created FieldReport item
---@param player any IsoPlayer
function POS_CraftCallbacks.onCreateFieldReport(items, result, player)
    if not result or not player then return end

    -- Transfer operation ID from photograph modData to report
    local operationId = nil
    PhobosLib.iterateItems(items, function(item)
        if item and item:getFullType() == POS_Constants.ITEM_RECON_PHOTOGRAPH then
            local md = item:getModData()
            if md and md[POS_Constants.MD_OPERATION_ID] then
                operationId = md[POS_Constants.MD_OPERATION_ID]
            end
        end
    end)

    if operationId then
        local md = result:getModData()
        if md then
            md[POS_Constants.MD_OPERATION_ID] = operationId
        end
        PhobosLib.debug("POS", "[CraftCallback] Field report created for operation: " .. operationId)
    end

    -- Damage writing implement
    local chancePct = POS_Sandbox and POS_Sandbox.getWritingDamageChance
        and POS_Sandbox.getWritingDamageChance() or 20
    local damageAmt = POS_Sandbox and POS_Sandbox.getWritingDamageAmount
        and POS_Sandbox.getWritingDamageAmount() or 7

    local inv = player:getInventory()
    if inv then
        PhobosLib.iterateItems(items, function(item)
            if item then
                local fullType = item:getFullType()
                if WRITING_IMPLEMENTS[fullType] then
                    local damaged = PhobosLib.damageItemCondition(
                        item, math.max(1, damageAmt - 2), damageAmt + 2, chancePct)
                    if damaged then
                        PhobosLib.debug("POS", "[CraftCallback] Writing implement damaged: " .. fullType)
                    end
                end
            end
        end)
    end

    -- Mark operation objective as having notes written
    if operationId and POS_OperationLog then
        local op = POS_OperationLog.get(operationId)
        if op and op.objectives and op.objectives[1] then
            op.objectives[1].notesWritten = true
        end
    end
end

--- Callback for Refurbished VHS-C Tape crafting.
function POS_CraftCallbacks.onCreateRefurbishedTape(items, result, player)
    if not result then return end
    local md = PhobosLib.getModData(result)
    if md then
        md[POS_Constants.MD_TAPE_CAPACITY] = POS_Constants.VHS_REFURBISHED_CAPACITY
        md[POS_Constants.MD_TAPE_QUALITY] = "medium"
        md[POS_Constants.MD_TAPE_ENTRY_COUNT] = 0
        md[POS_Constants.MD_TAPE_ENTRIES] = ""
        md[POS_Constants.MD_TAPE_WEAR] = 0
    end
end

--- Callback for Spliced Recon Tape crafting.
function POS_CraftCallbacks.onCreateSplicedTape(items, result, player)
    if not result then return end
    local md = PhobosLib.getModData(result)
    if md then
        md[POS_Constants.MD_TAPE_CAPACITY] = POS_Constants.VHS_SPLICED_CAPACITY
        md[POS_Constants.MD_TAPE_QUALITY] = "low"
        md[POS_Constants.MD_TAPE_ENTRY_COUNT] = 0
        md[POS_Constants.MD_TAPE_ENTRIES] = ""
        md[POS_Constants.MD_TAPE_WEAR] = 0
    end
end

--- Callback for Improvised Recon Tape crafting.
function POS_CraftCallbacks.onCreateImprovisedTape(items, result, player)
    if not result then return end
    local md = PhobosLib.getModData(result)
    if md then
        md[POS_Constants.MD_TAPE_CAPACITY] = POS_Constants.VHS_IMPROVISED_CAPACITY
        md[POS_Constants.MD_TAPE_QUALITY] = "very_low"
        md[POS_Constants.MD_TAPE_ENTRY_COUNT] = 0
        md[POS_Constants.MD_TAPE_ENTRIES] = ""
        md[POS_Constants.MD_TAPE_WEAR] = 0
    end
end

--- Callback for VHS tape review -- converts one tape entry to a market note.
---@param items table Input items (B42: may be table or ArrayList)
---@param result any The created RawMarketNote item
---@param player any IsoPlayer
function POS_CraftCallbacks.onCreateVHSReviewNote(items, result, player)
    if not result or not player then return end

    -- Find the tape that was used
    local tape = nil
    if items and PhobosLib.iterateItems then
        PhobosLib.iterateItems(items, function(item)
            if POS_TapeManager and POS_TapeManager.isUsableTape and POS_TapeManager.isUsableTape(item) then
                tape = item
                return true  -- stop iteration
            end
        end)
    end

    -- Get tape modData for entry info
    local tapeId = nil
    local tapeMd = tape and PhobosLib.getModData(tape)
    if tapeMd then
        tapeId = tapeMd[POS_Constants.MD_TAPE_ID]
    end

    -- Build note modData from tape context
    local md = result:getModData()
    if not md then return end

    md[POS_Constants.MD_NOTE_TYPE] = "market"
    md[POS_Constants.MD_NOTE_SOURCE] = POS_Constants.VHS_REVIEW_SOURCE_LABEL
    md[POS_Constants.MD_NOTE_RECORDED] = getGameTime():getNightsSurvived()

    -- Get tape region for location context
    local region = tapeMd and tapeMd[POS_Constants.MD_TAPE_REGION] or "Unknown"
    md[POS_Constants.MD_NOTE_LOCATION] = region

    -- Determine category from tape region or use a default
    local categoryId = "tools"  -- fallback
    if POS_RoomCategoryMap and tapeMd then
        local inferredCat = POS_RoomCategoryMap.getCategory(region)
        if inferredCat then categoryId = inferredCat end
    end
    md[POS_Constants.MD_NOTE_CATEGORY] = categoryId

    -- Generate items and prices for the category
    local poolSize = POS_Sandbox and POS_Sandbox.getItemSelectionPoolSize
        and POS_Sandbox.getItemSelectionPoolSize() or 3
    local ctx = { sourceTier = POS_Constants.SOURCE_TIER_FIELD }
    local selectedItems = POS_ItemPool and POS_ItemPool.selectItems(categoryId, poolSize, ctx)
    if selectedItems and #selectedItems > 0
            and POS_PriceEngine and POS_PriceEngine.generatePrices then
        local prices = POS_PriceEngine.generatePrices(selectedItems, categoryId, ctx)
        if prices and #prices > 0 then
            local itemData = {}
            for i, p in ipairs(prices) do
                itemData[i] = p.fullType .. ":" .. tostring(p.price)
            end
            md[POS_Constants.MD_NOTE_ITEMS] = table.concat(itemData, "|")
        end
    end

    -- Apply tape quality to confidence
    local confidence = "medium"
    if tape and POS_TapeManager and POS_TapeManager.getConfidenceMod then
        local confMod = POS_TapeManager.getConfidenceMod(tape)
        if confMod <= POS_Constants.VHS_CONFIDENCE_MOD_IMPROVISED then
            confidence = "low"
        elseif confMod <= POS_Constants.VHS_CONFIDENCE_MOD_SPLICED then
            confidence = "low"
        elseif confMod <= POS_Constants.VHS_CONFIDENCE_MOD_REFURBISHED then
            confidence = "medium"
        else
            confidence = "high"
        end
    end
    md[POS_Constants.MD_NOTE_CONFIDENCE] = confidence

    -- Generate a price estimate
    if POS_PriceEngine and POS_PriceEngine.generatePrice then
        local priceItems = POS_ItemPool and POS_ItemPool.getItemsForCategory(categoryId)
        if priceItems and #priceItems > 0 then
            local item = priceItems[ZombRand(#priceItems) + 1]
            md[POS_Constants.MD_NOTE_PRICE] = POS_PriceEngine.generatePrice(item.fullType, categoryId, ctx)
        end
    end

    -- Stock level from tape data
    md[POS_Constants.MD_NOTE_STOCK] = "medium"

    -- Decrement tape entry count
    if tapeMd then
        local count = tonumber(tapeMd[POS_Constants.MD_TAPE_ENTRY_COUNT]) or 0
        tapeMd[POS_Constants.MD_TAPE_ENTRY_COUNT] = math.max(0, count - 1)
    end

    -- Apply dynamic tooltip
    if POS_NoteTooltip and POS_NoteTooltip.applyToNote then
        POS_NoteTooltip.applyToNote(result)
    end

    -- Damage writing implement (same pattern as field note creation)
    local chancePct = POS_Sandbox and POS_Sandbox.getWritingDamageChance
        and POS_Sandbox.getWritingDamageChance() or 20
    local damageAmt = POS_Sandbox and POS_Sandbox.getWritingDamageAmount
        and POS_Sandbox.getWritingDamageAmount() or 7

    if items and PhobosLib.iterateItems then
        PhobosLib.iterateItems(items, function(item)
            if item then
                local fullType = item:getFullType()
                if WRITING_IMPLEMENTS[fullType] then
                    local damaged = PhobosLib.damageItemCondition(
                        item, math.max(1, damageAmt - 2), damageAmt + 2, chancePct)
                    if damaged then
                        PhobosLib.debug("POS", "[CraftCallback] Writing implement damaged: " .. fullType)
                    end
                end
            end
        end)
    end

    PhobosLib.debug("POS", "[CraftCallback] VHS review note created: " .. categoryId)
end
