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
-- POS_ChunkProcessor.lua
-- Decodes raw data chunks into intelligence artifacts at
-- terminal processing time. Delegates note generation to
-- POS_MarketNoteGenerator for market-related chunks.
---------------------------------------------------------------

require "POS_Constants"
require "POS_DataRecorderService"
require "POS_MediaManager"

POS_ChunkProcessor = {}

local _TAG = "[POS:ChunkProc]"

--- Calculate the full confidence chain for a chunk.
--- finalConfidence = baseDeviceConfidence + mediaFidelityMod + recorderConditionMod
---                   + carryBonusMod + signalQualityMod
--- All values in BPS (basis points).
function POS_ChunkProcessor.calculateConfidence(chunk, recorder)
    local base = chunk and chunk.confidence or POS_Constants.CONFIDENCE_BASE_EFFECTIVE * POS_Constants.CONFIDENCE_BPS_DIVISOR

    -- Recorder condition modifier
    local recorderMod = 0
    if recorder then
        recorderMod = POS_DataRecorderService.getConditionMod(recorder)
    end

    -- Media fidelity modifier (stored in chunk at record time)
    local mediaMod = chunk and chunk.mediaMod or 0

    -- Carry bonus (from calculator or other devices in inventory, stored in chunk)
    local carryMod = chunk and chunk.carryMod or 0

    -- Signal quality (for radio intercepts, stored in chunk)
    local signalMod = chunk and chunk.signalMod or 0

    local total = base + recorderMod + mediaMod + carryMod + signalMod
    local minEffective = POS_Constants.CONFIDENCE_MIN_EFFECTIVE * POS_Constants.CONFIDENCE_BPS_DIVISOR
    return math.max(minEffective, total)
end

--- Process all chunks from a recorder at a terminal.
--- Produces intelligence artifacts (market notes, building cache updates).
--- @param player IsoPlayer
--- @param recorder InventoryItem
--- @return number Number of chunks processed
function POS_ChunkProcessor.processAll(player, recorder)
    if not player or not recorder then return 0 end
    if not POS_DataRecorderService.isPowered(recorder) then return 0 end

    POS_DataRecorderService.ensureInitialized(recorder)
    local md = PhobosLib.getModData(recorder)
    if not md then return 0 end

    local processed = 0

    -- Process buffer entries
    local bufCount = POS_DataRecorderService.getBufferCount(recorder)
    if bufCount > 0 then
        processed = processed + POS_ChunkProcessor._processEntries(player, recorder, bufCount, "buffer")
        md[POS_Constants.MD_RECORDER_BUFFER_COUNT] = 0
    end

    -- Process media entries
    local mediaUsed = tonumber(md[POS_Constants.MD_RECORDER_MEDIA_USED]) or 0
    if mediaUsed > 0 then
        processed = processed + POS_ChunkProcessor._processEntries(player, recorder, mediaUsed, "media")
        md[POS_Constants.MD_RECORDER_MEDIA_USED] = 0
    end

    -- Log processing event
    if POS_EventLog and POS_EventLog.append and processed > 0 then
        POS_EventLog.append(
            POS_Constants.EVENT_SYSTEM_RECON,
            POS_Constants.EVENT_RECORDER_PROCESS,
            "process_all",
            "",
            md[POS_Constants.MD_RECORDER_ID] or "",
            processed,
            0, ""
        )
    end

    PhobosLib.debug("POS", _TAG, "processed " .. processed .. " chunks")
    return processed
end

--- Internal: process N entries from a source (buffer or media).
--- Each entry generates one intelligence artifact.
function POS_ChunkProcessor._processEntries(player, recorder, count, source)
    if count <= 0 then return 0 end

    local processed = 0
    for _ = 1, count do
        -- Each chunk at processing time is a generic "recorded entry"
        -- The actual chunk type was logged in POS_EventLog at record time
        -- At terminal, we generate artifacts based on recorder context
        local chunk = {
            type = POS_Constants.CHUNK_TYPE_BUILDING_SCAN,
            confidence = POS_Constants.CONFIDENCE_BASE_EFFECTIVE * POS_Constants.CONFIDENCE_BPS_DIVISOR,
            mediaMod = 0,
            carryMod = 0,
            signalMod = 0,
        }

        local confidence = POS_ChunkProcessor.calculateConfidence(chunk, recorder)
        local success = POS_ChunkProcessor._generateArtifact(player, confidence, source)
        if success then
            processed = processed + 1
        end
    end

    return processed
end

--- Internal: generate a single intelligence artifact.
--- Checks for paper + pen consumption.
function POS_ChunkProcessor._generateArtifact(player, confidence, source)
    if not player then return false end

    local inv = player:getInventory()
    if not inv then return false end

    -- Check for paper
    local paper = PhobosLib.findItemByFullType(inv, "Base.SheetPaper2")
        or PhobosLib.findItemByFullType(inv, "Base.Notebook")
    if not paper then
        PhobosLib.debug("POS", _TAG, "no paper available — artifact skipped")
        return false
    end

    -- Check for writing implement
    local pen = PhobosLib.findItemByFullType(inv, "Base.Pen")
        or PhobosLib.findItemByFullType(inv, "Base.Pencil")
        or PhobosLib.findItemByFullType(inv, "Base.BluePen")
        or PhobosLib.findItemByFullType(inv, "Base.RedPen")
    if not pen then
        PhobosLib.debug("POS", _TAG, "no writing implement — artifact skipped")
        return false
    end

    -- Consume paper
    inv:Remove(paper)

    -- Create market note
    local noteItem = inv:AddItem(POS_Constants.ITEM_RAW_MARKET_NOTE)
    if noteItem and POS_MarketNoteGenerator and POS_MarketNoteGenerator.populateNoteModData then
        POS_MarketNoteGenerator.populateNoteModData(noteItem, {
            confidence = confidence,
            source = source,
        })
    end

    -- Optionally damage writing implement
    local damageChance = POS_Constants.WRITING_DAMAGE_CHANCE_DEFAULT
    if ZombRand(100) < damageChance then
        local damageAmt = POS_Constants.WRITING_DAMAGE_AMOUNT_DEFAULT
        if PhobosLib.damageItemCondition then
            PhobosLib.damageItemCondition(pen, damageAmt)
        end
    end

    return true
end

--- Process only chunks of a specific type.
--- @param player IsoPlayer
--- @param recorder InventoryItem
--- @param chunkType string One of POS_Constants.CHUNK_TYPE_*
--- @return number Number of chunks processed
function POS_ChunkProcessor.processType(player, recorder, chunkType)
    -- For now, processAll handles all chunk types uniformly.
    -- Type-specific processing will be implemented when the event log
    -- stores chunk type metadata that can be queried at processing time.
    PhobosLib.debug("POS", _TAG, "processType not yet type-selective — delegating to processAll")
    return POS_ChunkProcessor.processAll(player, recorder)
end
