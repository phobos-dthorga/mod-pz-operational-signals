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
-- Each callback is a thin delegator to POS_CraftHelpers.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_CraftHelpers"
require "POS_MarketNoteGenerator"
require "POS_MediaManager"

POS_CraftCallbacks = POS_CraftCallbacks or {}

local _TAG = "[POS:CraftCB]"

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
        if not item then return end
        local ok, ft = PhobosLib.safecall(function() return item:getFullType() end)
        if ok and ft == POS_Constants.ITEM_RECON_PHOTOGRAPH then
            local md = PhobosLib.getModData(item)
            if md and md[POS_Constants.MD_OPERATION_ID] then
                operationId = md[POS_Constants.MD_OPERATION_ID]
            end
        end
    end)

    if operationId then
        local md = PhobosLib.getModData(result)
        if md then
            md[POS_Constants.MD_OPERATION_ID] = operationId
        end
        PhobosLib.debug("POS", _TAG, "field report created for operation: " .. operationId)
    end

    -- Damage writing implement
    POS_CraftHelpers.damageWritingImplement(items, player)

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

--- Callback for converting vanilla VHS tapes to POSnet blank tapes.
function POS_CraftCallbacks.onCreateConvertedVHSTape(items, result, player)
    if not result then return end
    POS_MediaManager.ensureInitialized(result)
end

--- Callback for VHS tape review -- converts one tape entry to a market note.
---@param items table Input items (B42: may be table or ArrayList)
---@param result any The created RawMarketNote item
---@param player any IsoPlayer
function POS_CraftCallbacks.onCreateVHSReviewNote(items, result, player)
    POS_CraftHelpers.generateNoteFromMedia(items, result, player,
        { POS_Constants.ITEM_RECORDED_RECON_TAPE },
        {
            confidenceThresholds = POS_Constants.VHS_CONFIDENCE_THRESHOLDS,
            confidenceDefault    = POS_Constants.CONFIDENCE_HIGH,
            sourceLabel          = POS_Constants.VHS_REVIEW_SOURCE_LABEL,
            legacyRegionKey      = POS_Constants.MD_TAPE_REGION,
            legacyEntryCountKey  = POS_Constants.MD_TAPE_ENTRY_COUNT,
        })
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
    PhobosLib.debug("POS", _TAG, "microcassette rewound")
end

--- Callback for Recycle Microcassette recipe (at microscope).
function POS_CraftCallbacks.onCreateRecycleMicrocassette(items, result, player)
    -- Result is MagneticTapeScrap — no special modData needed
    PhobosLib.debug("POS", _TAG, "microcassette recycled to scrap")
end

--- Callback for Review Microcassette recipe (portable -- no station required).
function POS_CraftCallbacks.onCreateReviewMicrocassette(items, result, player)
    POS_CraftHelpers.generateNoteFromMedia(items, result, player,
        {
            POS_Constants.ITEM_RECORDED_MICROCASSETTE,
            POS_Constants.ITEM_REWOUND_MICROCASSETTE,
        },
        {
            confidenceThresholds = POS_Constants.MICROCASSETTE_CONFIDENCE_THRESHOLDS,
            confidenceDefault    = POS_Constants.CONFIDENCE_HIGH,
        })
end

--- Callback for Review Floppy Disk recipe (at terminal station).
function POS_CraftCallbacks.onCreateReviewFloppyDisk(items, result, player)
    POS_CraftHelpers.generateNoteFromMedia(items, result, player,
        {
            POS_Constants.ITEM_RECORDED_FLOPPY_DISK,
            POS_Constants.ITEM_WORN_FLOPPY_DISK,
        },
        {
            confidenceThresholds = POS_Constants.FLOPPY_CONFIDENCE_THRESHOLDS,
            confidenceDefault    = POS_Constants.CONFIDENCE_HIGH,
        })
end

--- Callback for Salvage Corrupt Floppy Disk recipe (at terminal station).
function POS_CraftCallbacks.onCreateSalvageCorruptFloppy(items, result, player)
    -- Result is ElectronicsScrap — no special modData needed
    PhobosLib.debug("POS", _TAG, "corrupt floppy salvaged for electronics scrap")
end

--- Callback for Repair Data-Recorder recipe.
function POS_CraftCallbacks.onCreateRepairDataRecorder(items, result, player)
    if not result then return end
    -- Restore condition to full
    local ok, condMax = PhobosLib.safecall(function() return result:getConditionMax() end)
    if ok and condMax then
        PhobosLib.safecall(function() result:setCondition(condMax) end)
    end
    POS_DataRecorderService.ensureInitialized(result)
    PhobosLib.debug("POS", _TAG, "data recorder repaired to full condition")
end
