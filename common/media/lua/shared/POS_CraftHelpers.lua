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
-- POS_CraftHelpers.lua
-- Shared helper functions for POSnet crafting recipe callbacks.
-- Eliminates duplication across media review and field report
-- callbacks by centralising writing damage, confidence
-- resolution, and note generation logic.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_CraftHelpers = POS_CraftHelpers or {}

local _TAG = "[POS:CraftHelpers]"

---------------------------------------------------------------
-- (a) damageWritingImplement
---------------------------------------------------------------

--- Find a writing implement in the recipe items and apply
--- condition damage using sandbox-configurable parameters.
---@param items table       Input items from the recipe callback
---@param player any        IsoPlayer performing the craft
---@return any|nil          The writing implement item, or nil if none found
function POS_CraftHelpers.damageWritingImplement(items, player)
    if not items or not player then return nil end

    local chancePct = PhobosLib.getConfigurable(
        POS_Sandbox, "getWritingDamageChance",
        POS_Constants.WRITING_DAMAGE_CHANCE_DEFAULT)
    local damageAmt = PhobosLib.getConfigurable(
        POS_Sandbox, "getWritingDamageAmount",
        POS_Constants.WRITING_DAMAGE_AMOUNT_DEFAULT)

    local foundImpl = nil

    PhobosLib.iterateItems(items, function(item)
        if not item then return end
        local ok, fullType = PhobosLib.safecall(function() return item:getFullType() end)
        if ok and fullType and POS_Constants.WRITING_IMPLEMENTS[fullType] then
            local damaged = PhobosLib.damageItemCondition(
                item,
                math.max(1, damageAmt - POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET),
                damageAmt + POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET,
                chancePct)
            if damaged then
                PhobosLib.debug("POS", _TAG, "writing implement damaged: " .. fullType)
            end
            foundImpl = item
        end
    end)

    return foundImpl
end

---------------------------------------------------------------
-- (b) resolveMediaConfidence
---------------------------------------------------------------

--- Resolve a media confidence modifier to a confidence tier string
--- using the VHS confidence thresholds from POS_Constants.
---@param confMod number    Confidence modifier (basis points)
---@return string           Confidence tier: "low", "medium", or "high"
function POS_CraftHelpers.resolveMediaConfidence(confMod)
    return PhobosLib.resolveThresholdTier(
        confMod,
        POS_Constants.VHS_CONFIDENCE_THRESHOLDS,
        POS_Constants.CONFIDENCE_HIGH)
end

---------------------------------------------------------------
-- (c) initializeMedia
---------------------------------------------------------------

--- Set default modData fields on a newly created media item.
---@param item any          The media item to initialise
---@param mediaType string  Media type identifier (e.g. "vhs", "microcassette", "floppy")
---@return any              The item (for chaining)
function POS_CraftHelpers.initializeMedia(item, mediaType)
    if not item then return item end
    local md = PhobosLib.getModData(item)
    if not md then return item end

    md[POS_Constants.MD_MEDIA_ENTRY_COUNT]  = 0
    md[POS_Constants.MD_MEDIA_CONF_MOD]     = 0
    md[POS_Constants.MD_MEDIA_CYCLE_COUNT]  = 0
    md[POS_Constants.MD_MEDIA_REGION]       = ""
    md["POS_MediaType"]                     = mediaType or ""
    md["POS_MediaState"]                    = "blank"

    return item
end

---------------------------------------------------------------
-- (d) generateNoteFromMedia
---------------------------------------------------------------

--- Consolidated logic for all media review callbacks (VHS, microcassette, floppy).
--- Finds the media item in inputs, reads its modData, resolves confidence,
--- populates the note, decrements entry count, applies tooltip, and damages
--- the writing implement.
---@param items table           Input items from the recipe callback
---@param result any            The created RawMarketNote item
---@param player any            IsoPlayer performing the craft
---@param mediaTypes table      Array of fullType strings to match media items
---@param opts table|nil        Optional overrides:
---   confidenceThresholds  - tier table for resolveThresholdTier (default: VHS)
---   confidenceDefault     - fallback confidence (default: CONFIDENCE_HIGH)
---   sourceLabel           - override for MD_NOTE_SOURCE (default: nil = no override)
---   legacyRegionKey       - fallback modData key for region (default: nil)
---   legacyEntryCountKey   - fallback modData key for entry count (default: nil)
---@return boolean              true if note was successfully generated
function POS_CraftHelpers.generateNoteFromMedia(items, result, player, mediaTypes, opts)
    if not result or not player or not mediaTypes then return false end

    opts = opts or {}
    local confThresholds   = opts.confidenceThresholds or POS_Constants.VHS_CONFIDENCE_THRESHOLDS
    local confDefault      = opts.confidenceDefault    or POS_Constants.CONFIDENCE_HIGH
    local sourceLabel      = opts.sourceLabel
    local legacyRegionKey  = opts.legacyRegionKey
    local legacyEntryKey   = opts.legacyEntryCountKey

    -- Build lookup set from mediaTypes array
    local mediaLookup = {}
    for i = 1, #mediaTypes do
        mediaLookup[mediaTypes[i]] = true
    end

    -- Find the media item from inputs
    local media = nil
    PhobosLib.iterateItems(items, function(item)
        if not item then return end
        local ok, ft = PhobosLib.safecall(function() return item:getFullType() end)
        if ok and ft and mediaLookup[ft] then
            media = item
            return true  -- stop iteration
        end
    end)

    -- Read media modData
    local mediaMd = media and PhobosLib.getModData(media)

    -- Resolve region (unified key first, then legacy fallback)
    local region = nil
    if mediaMd then
        region = mediaMd[POS_Constants.MD_MEDIA_REGION]
        if not region and legacyRegionKey then
            region = mediaMd[legacyRegionKey]
        end
    end
    region = region or PhobosLib.safeGetText("UI_POS_Market_Unknown")

    -- Infer category from region
    local categoryId = "tools"
    if POS_RoomCategoryMap and mediaMd then
        local inferredCat = POS_RoomCategoryMap.getCategory(region)
        if inferredCat then categoryId = inferredCat end
    end

    -- Resolve confidence from media quality
    local confidence = confDefault
    if media then
        local confMod = POS_MediaManager.getConfidenceMod(media)
        confidence = PhobosLib.resolveThresholdTier(confMod, confThresholds, confDefault)
    end

    -- Populate note modData via shared generator
    local ctx = { sourceTier = POS_Constants.SOURCE_TIER_FIELD }
    POS_MarketNoteGenerator.populateNoteModData(result, categoryId, region, confidence, ctx)

    -- Optionally override source label
    if sourceLabel then
        local md = PhobosLib.getModData(result)
        if md then
            md[POS_Constants.MD_NOTE_SOURCE] = sourceLabel
        end
    end

    -- Decrement media entry count (unified key first, then legacy fallback)
    if mediaMd then
        local countKey = POS_Constants.MD_MEDIA_ENTRY_COUNT
        if mediaMd[countKey] == nil and legacyEntryKey then
            countKey = legacyEntryKey
        end
        local count = tonumber(mediaMd[countKey]) or 0
        mediaMd[countKey] = math.max(0, count - 1)
    end

    -- Apply dynamic tooltip
    if POS_NoteTooltip and POS_NoteTooltip.applyToNote then
        POS_NoteTooltip.applyToNote(result)
    end

    -- Damage writing implement
    POS_CraftHelpers.damageWritingImplement(items, player)

    PhobosLib.debug("POS", _TAG, "media review note created: " .. categoryId)

    return true
end
