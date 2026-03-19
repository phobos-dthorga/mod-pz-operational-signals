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
require "POS_MarketNoteGenerator"
require "POS_MediaManager"

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
        and POS_Sandbox.getWritingDamageChance()
        or POS_Constants.WRITING_DAMAGE_CHANCE_DEFAULT
    local damageAmt = POS_Sandbox and POS_Sandbox.getWritingDamageAmount
        and POS_Sandbox.getWritingDamageAmount()
        or POS_Constants.WRITING_DAMAGE_AMOUNT_DEFAULT

    local inv = player:getInventory()
    if inv then
        PhobosLib.iterateItems(items, function(item)
            if item then
                local fullType = item:getFullType()
                if WRITING_IMPLEMENTS[fullType] then
                    local damaged = PhobosLib.damageItemCondition(
                        item,
                        math.max(1, damageAmt - POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET),
                        damageAmt + POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET,
                        chancePct)
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
    POS_MediaManager.ensureInitialized(result)
end

--- Callback for Spliced Recon Tape crafting.
function POS_CraftCallbacks.onCreateSplicedTape(items, result, player)
    if not result then return end
    POS_MediaManager.ensureInitialized(result)
end

--- Callback for Improvised Recon Tape crafting.
function POS_CraftCallbacks.onCreateImprovisedTape(items, result, player)
    if not result then return end
    POS_MediaManager.ensureInitialized(result)
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
            if POS_MediaManager.isUsableMedia(item) then
                tape = item
                return true  -- stop iteration
            end
        end)
    end

    -- Get tape modData for entry info
    local tapeMd = tape and PhobosLib.getModData(tape)

    -- Determine category from tape region
    local region = tapeMd and (tapeMd[POS_Constants.MD_MEDIA_REGION] or tapeMd[POS_Constants.MD_TAPE_REGION])
        or PhobosLib.safeGetText("UI_POS_Market_Unknown")
    local categoryId = "tools"
    if POS_RoomCategoryMap and tapeMd then
        local inferredCat = POS_RoomCategoryMap.getCategory(region)
        if inferredCat then categoryId = inferredCat end
    end

    -- Apply media quality to confidence
    local confidence = POS_Constants.CONFIDENCE_MEDIUM
    if tape then
        local confMod = POS_MediaManager.getConfidenceMod(tape)
        if confMod <= POS_Constants.VHS_CONFIDENCE_MOD_SPLICED then
            confidence = POS_Constants.CONFIDENCE_LOW
        elseif confMod <= POS_Constants.VHS_CONFIDENCE_MOD_REFURBISHED then
            confidence = POS_Constants.CONFIDENCE_MEDIUM
        else
            confidence = POS_Constants.CONFIDENCE_HIGH
        end
    end

    -- Populate note modData via shared generator
    local ctx = { sourceTier = POS_Constants.SOURCE_TIER_FIELD }
    POS_MarketNoteGenerator.populateNoteModData(result, categoryId, region, confidence, ctx)

    -- Override source to VHS review label (generator sets a procedural name)
    local md = result:getModData()
    if md then
        md[POS_Constants.MD_NOTE_SOURCE] = POS_Constants.VHS_REVIEW_SOURCE_LABEL
    end

    -- Decrement media entry count (check unified key first, fall back to legacy)
    if tapeMd then
        local countKey = tapeMd[POS_Constants.MD_MEDIA_ENTRY_COUNT] ~= nil
            and POS_Constants.MD_MEDIA_ENTRY_COUNT or POS_Constants.MD_TAPE_ENTRY_COUNT
        local count = tonumber(tapeMd[countKey]) or 0
        tapeMd[countKey] = math.max(0, count - 1)
    end

    -- Apply dynamic tooltip
    if POS_NoteTooltip and POS_NoteTooltip.applyToNote then
        POS_NoteTooltip.applyToNote(result)
    end

    -- Damage writing implement
    local chancePct = POS_Sandbox and POS_Sandbox.getWritingDamageChance
        and POS_Sandbox.getWritingDamageChance()
        or POS_Constants.WRITING_DAMAGE_CHANCE_DEFAULT
    local damageAmt = POS_Sandbox and POS_Sandbox.getWritingDamageAmount
        and POS_Sandbox.getWritingDamageAmount()
        or POS_Constants.WRITING_DAMAGE_AMOUNT_DEFAULT

    if items and PhobosLib.iterateItems then
        PhobosLib.iterateItems(items, function(item)
            if item then
                local fullType = item:getFullType()
                if WRITING_IMPLEMENTS[fullType] then
                    local damaged = PhobosLib.damageItemCondition(
                        item,
                        math.max(1, damageAmt - POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET),
                        damageAmt + POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET,
                        chancePct)
                    if damaged then
                        PhobosLib.debug("POS", "[CraftCallback] Writing implement damaged: " .. fullType)
                    end
                end
            end
        end)
    end

    PhobosLib.debug("POS", "CraftCallback", "VHS review note created: " .. categoryId)
end

--- Callback for Rewind Microcassette recipe (at microscope).
function POS_CraftCallbacks.onCreateRewindMicrocassette(items, result, player)
    if not result then return end
    POS_MediaManager.ensureInitialized(result)
    local md = PhobosLib.getModData(result)
    if md then
        -- Reset entry count, increment cycle count
        md[POS_Constants.MD_MEDIA_ENTRY_COUNT] = 0
        md[POS_Constants.MD_MEDIA_CYCLE_COUNT] = (tonumber(md[POS_Constants.MD_MEDIA_CYCLE_COUNT]) or 0) + 1
        -- Rewound tapes have reduced confidence
        md[POS_Constants.MD_MEDIA_CONF_MOD] = POS_Constants.MICROCASSETTE_REWOUND_CONFIDENCE_MOD
    end
    PhobosLib.debug("POS", "CraftCallback", "microcassette rewound")
end

--- Callback for Recycle Microcassette recipe (at microscope).
function POS_CraftCallbacks.onCreateRecycleMicrocassette(items, result, player)
    -- Result is MagneticTapeScrap — no special modData needed
    PhobosLib.debug("POS", "CraftCallback", "microcassette recycled to scrap")
end

--- Callback for Review Microcassette recipe (portable — no station required).
function POS_CraftCallbacks.onCreateReviewMicrocassette(items, result, player)
    if not result or not player then return end

    -- Find the microcassette from inputs
    local cassette = nil
    if items and PhobosLib.iterateItems then
        PhobosLib.iterateItems(items, function(item)
            if item then
                local ft = item:getFullType()
                if ft == POS_Constants.ITEM_RECORDED_MICROCASSETTE
                    or ft == POS_Constants.ITEM_REWOUND_MICROCASSETTE then
                    cassette = item
                    return true
                end
            end
        end)
    end

    local cassetteMd = cassette and PhobosLib.getModData(cassette)
    local region = cassetteMd and cassetteMd[POS_Constants.MD_MEDIA_REGION]
        or PhobosLib.safeGetText("UI_POS_Market_Unknown")
    local categoryId = "tools"
    if POS_RoomCategoryMap and cassetteMd then
        local inferredCat = POS_RoomCategoryMap.getCategory(region)
        if inferredCat then categoryId = inferredCat end
    end

    -- Microcassette confidence
    local confidence = POS_Constants.CONFIDENCE_HIGH
    if cassette then
        local confMod = POS_MediaManager.getConfidenceMod(cassette)
        if confMod >= POS_Constants.MICROCASSETTE_CONFIDENCE_MOD then
            confidence = POS_Constants.CONFIDENCE_HIGH
        else
            confidence = POS_Constants.CONFIDENCE_MEDIUM
        end
    end

    local ctx = { sourceTier = POS_Constants.SOURCE_TIER_FIELD }
    POS_MarketNoteGenerator.populateNoteModData(result, categoryId, region, confidence, ctx)

    -- Decrement media entry count
    if cassetteMd then
        local count = tonumber(cassetteMd[POS_Constants.MD_MEDIA_ENTRY_COUNT]) or 0
        cassetteMd[POS_Constants.MD_MEDIA_ENTRY_COUNT] = math.max(0, count - 1)
    end

    if POS_NoteTooltip and POS_NoteTooltip.applyToNote then
        POS_NoteTooltip.applyToNote(result)
    end

    -- Damage writing implement
    local chancePct = POS_Sandbox and POS_Sandbox.getWritingDamageChance
        and POS_Sandbox.getWritingDamageChance()
        or POS_Constants.WRITING_DAMAGE_CHANCE_DEFAULT
    local damageAmt = POS_Sandbox and POS_Sandbox.getWritingDamageAmount
        and POS_Sandbox.getWritingDamageAmount()
        or POS_Constants.WRITING_DAMAGE_AMOUNT_DEFAULT

    if items and PhobosLib.iterateItems then
        PhobosLib.iterateItems(items, function(item)
            if item then
                local fullType = item:getFullType()
                if WRITING_IMPLEMENTS[fullType] then
                    PhobosLib.damageItemCondition(
                        item,
                        math.max(1, damageAmt - POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET),
                        damageAmt + POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET,
                        chancePct)
                end
            end
        end)
    end

    PhobosLib.debug("POS", "CraftCallback", "microcassette review note created: " .. categoryId)
end

--- Callback for Review Floppy Disk recipe (at terminal station).
function POS_CraftCallbacks.onCreateReviewFloppyDisk(items, result, player)
    if not result or not player then return end

    -- Find the floppy from inputs
    local floppy = nil
    if items and PhobosLib.iterateItems then
        PhobosLib.iterateItems(items, function(item)
            if item then
                local ft = item:getFullType()
                if ft == POS_Constants.ITEM_RECORDED_FLOPPY_DISK
                    or ft == POS_Constants.ITEM_WORN_FLOPPY_DISK then
                    floppy = item
                    return true
                end
            end
        end)
    end

    local floppyMd = floppy and PhobosLib.getModData(floppy)
    local region = floppyMd and floppyMd[POS_Constants.MD_MEDIA_REGION]
        or PhobosLib.safeGetText("UI_POS_Market_Unknown")
    local categoryId = "tools"
    if POS_RoomCategoryMap and floppyMd then
        local inferredCat = POS_RoomCategoryMap.getCategory(region)
        if inferredCat then categoryId = inferredCat end
    end

    -- Floppy disk confidence (digital precision)
    local confidence = POS_Constants.CONFIDENCE_HIGH
    if floppy then
        local confMod = POS_MediaManager.getConfidenceMod(floppy)
        if confMod >= POS_Constants.FLOPPY_CONFIDENCE_MOD then
            confidence = POS_Constants.CONFIDENCE_HIGH
        elseif confMod >= POS_Constants.FLOPPY_WORN_CONFIDENCE_MOD then
            confidence = POS_Constants.CONFIDENCE_MEDIUM
        else
            confidence = POS_Constants.CONFIDENCE_LOW
        end
    end

    local ctx = { sourceTier = POS_Constants.SOURCE_TIER_FIELD }
    POS_MarketNoteGenerator.populateNoteModData(result, categoryId, region, confidence, ctx)

    -- Decrement media entry count
    if floppyMd then
        local count = tonumber(floppyMd[POS_Constants.MD_MEDIA_ENTRY_COUNT]) or 0
        floppyMd[POS_Constants.MD_MEDIA_ENTRY_COUNT] = math.max(0, count - 1)
    end

    if POS_NoteTooltip and POS_NoteTooltip.applyToNote then
        POS_NoteTooltip.applyToNote(result)
    end

    -- Damage writing implement
    local chancePct = POS_Sandbox and POS_Sandbox.getWritingDamageChance
        and POS_Sandbox.getWritingDamageChance()
        or POS_Constants.WRITING_DAMAGE_CHANCE_DEFAULT
    local damageAmt = POS_Sandbox and POS_Sandbox.getWritingDamageAmount
        and POS_Sandbox.getWritingDamageAmount()
        or POS_Constants.WRITING_DAMAGE_AMOUNT_DEFAULT

    if items and PhobosLib.iterateItems then
        PhobosLib.iterateItems(items, function(item)
            if item then
                local fullType = item:getFullType()
                if WRITING_IMPLEMENTS[fullType] then
                    PhobosLib.damageItemCondition(
                        item,
                        math.max(1, damageAmt - POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET),
                        damageAmt + POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET,
                        chancePct)
                end
            end
        end)
    end

    PhobosLib.debug("POS", "CraftCallback", "floppy disk review note created: " .. categoryId)
end

--- Callback for Salvage Corrupt Floppy Disk recipe (at terminal station).
function POS_CraftCallbacks.onCreateSalvageCorruptFloppy(items, result, player)
    -- Result is ElectronicsScrap — no special modData needed
    PhobosLib.debug("POS", "CraftCallback", "corrupt floppy salvaged for electronics scrap")
end

--- Callback for Repair Data-Recorder recipe.
function POS_CraftCallbacks.onCreateRepairDataRecorder(items, result, player)
    if not result then return end
    -- Restore condition to full
    result:setCondition(result:getConditionMax())
    POS_DataRecorderService.ensureInitialized(result)
    PhobosLib.debug("POS", "CraftCallback", "data recorder repaired to full condition")
end
