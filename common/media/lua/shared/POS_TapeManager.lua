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
-- POS_TapeManager.lua
-- VHS tape lifecycle management -- insert, record, erase, degrade.
---------------------------------------------------------------

require "POS_Constants"

POS_TapeManager = {}

-- Tape type definitions (capacity, quality tier, confidence modifier)
local TAPE_TYPES = {
    [POS_Constants.ITEM_BLANK_VHS_TAPE]    = { capacity = POS_Constants.VHS_FACTORY_CAPACITY,     quality = "high",     confMod = POS_Constants.VHS_CONFIDENCE_MOD_FACTORY },
    [POS_Constants.ITEM_REFURBISHED_TAPE]  = { capacity = POS_Constants.VHS_REFURBISHED_CAPACITY,  quality = "medium",   confMod = POS_Constants.VHS_CONFIDENCE_MOD_REFURBISHED },
    [POS_Constants.ITEM_SPLICED_TAPE]      = { capacity = POS_Constants.VHS_SPLICED_CAPACITY,      quality = "low",      confMod = POS_Constants.VHS_CONFIDENCE_MOD_SPLICED },
    [POS_Constants.ITEM_IMPROVISED_TAPE]   = { capacity = POS_Constants.VHS_IMPROVISED_CAPACITY,   quality = "very_low", confMod = POS_Constants.VHS_CONFIDENCE_MOD_IMPROVISED },
    [POS_Constants.ITEM_RECORDED_RECON_TAPE] = { capacity = POS_Constants.VHS_FACTORY_CAPACITY,    quality = "high",     confMod = POS_Constants.VHS_CONFIDENCE_MOD_FACTORY },
}

--- Get tape type info for an item.
function POS_TapeManager.getTapeType(item)
    if not item then return nil end
    local fullType = item:getFullType()
    return TAPE_TYPES[fullType]
end

--- Check if an item is any kind of usable tape (blank or partially recorded).
function POS_TapeManager.isUsableTape(item)
    if not item then return false end
    local ft = item:getFullType()
    return TAPE_TYPES[ft] ~= nil and ft ~= POS_Constants.ITEM_WORN_VHS_TAPE
        and ft ~= POS_Constants.ITEM_DAMAGED_VHS_TAPE
        and ft ~= POS_Constants.ITEM_MAGNETIC_TAPE_SCRAP
end

--- Get current entry count on a tape.
function POS_TapeManager.getEntryCount(item)
    if not item then return 0 end
    local md = PhobosLib.getModData(item)
    if not md then return 0 end
    return tonumber(md[POS_Constants.MD_TAPE_ENTRY_COUNT]) or 0
end

--- Get remaining capacity on a tape.
function POS_TapeManager.getRemainingCapacity(item)
    if not item then return 0 end
    local tapeType = POS_TapeManager.getTapeType(item)
    if not tapeType then return 0 end
    local md = PhobosLib.getModData(item)
    local capacity = (md and tonumber(md[POS_Constants.MD_TAPE_CAPACITY])) or tapeType.capacity
    local used = POS_TapeManager.getEntryCount(item)
    return math.max(0, capacity - used)
end

--- Check if tape is full.
function POS_TapeManager.isFull(item)
    return POS_TapeManager.getRemainingCapacity(item) <= 0
end

--- Record a recon entry onto a tape. Returns true if successful.
function POS_TapeManager.recordEntry(item, entry)
    if not item or not entry then return false end
    if POS_TapeManager.isFull(item) then return false end

    local md = PhobosLib.getModData(item)
    if not md then return false end

    -- Ensure tape has a unique ID
    if not md[POS_Constants.MD_TAPE_ID] then
        md[POS_Constants.MD_TAPE_ID] = "tape_" .. tostring(ZombRand(1000000000))
    end

    -- Increment entry count
    md[POS_Constants.MD_TAPE_ENTRY_COUNT] = (tonumber(md[POS_Constants.MD_TAPE_ENTRY_COUNT]) or 0) + 1

    -- Store full entry data in event log (not in item modData)
    if POS_EventLog and POS_EventLog.append then
        POS_EventLog.append(
            "recon",                          -- system
            "tape_entry",                     -- eventType
            entry.roomType or "unknown",      -- entityId
            entry.region or "",               -- regionId
            md[POS_Constants.MD_TAPE_ID],     -- actorId (tape ID for linking)
            0,                                -- qty
            entry.confidence or 50,           -- priceBps (repurposed for confidence)
            tostring(entry.x or 0) .. "," .. tostring(entry.y or 0)  -- cause (coordinates)
        )
    end

    -- Update region tracking (summary in modData)
    if entry.region and not md[POS_Constants.MD_TAPE_REGION] then
        md[POS_Constants.MD_TAPE_REGION] = entry.region
    end

    -- Update duration
    md[POS_Constants.MD_TAPE_DURATION] = (tonumber(md[POS_Constants.MD_TAPE_DURATION]) or 0) + 1

    return true
end

--- Get the confidence modifier for a tape (BPS).
function POS_TapeManager.getConfidenceMod(item)
    if not item then return 0 end
    local tapeType = POS_TapeManager.getTapeType(item)
    if not tapeType then return 0 end

    local baseMod = tapeType.confMod
    local md = PhobosLib.getModData(item)
    local wear = md and tonumber(md[POS_Constants.MD_TAPE_WEAR]) or 0

    -- Wear reduces confidence further
    return baseMod - (wear * 100)  -- each wear point = -1% = -100 BPS
end

--- Apply degradation to a tape after upload.
function POS_TapeManager.degradeTape(item)
    if not item then return end
    local md = PhobosLib.getModData(item)
    if not md then return end

    local degradeRate = POS_Sandbox and POS_Sandbox.getTapeDegradationRate
        and POS_Sandbox.getTapeDegradationRate() or POS_Constants.VHS_DEGRADATION_RATE_PCT
    local currentWear = tonumber(md[POS_Constants.MD_TAPE_WEAR]) or 0
    md[POS_Constants.MD_TAPE_WEAR] = currentWear + degradeRate

    -- If wear exceeds threshold, tape becomes worn
    if md[POS_Constants.MD_TAPE_WEAR] >= 100 then
        -- Caller should replace item with WornVHSTape
        return true  -- signal: tape is now worn out
    end
    return false
end

--- Find the first usable tape in player inventory.
function POS_TapeManager.findUsableTape(player)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    -- Check blank tapes first (prefer highest quality)
    local tapeTypes = {
        POS_Constants.ITEM_BLANK_VHS_TAPE,
        POS_Constants.ITEM_REFURBISHED_TAPE,
        POS_Constants.ITEM_SPLICED_TAPE,
        POS_Constants.ITEM_IMPROVISED_TAPE,
    }

    for _, ft in ipairs(tapeTypes) do
        local items = inv:getItemsFromFullType(ft)
        if items then
            for i = 0, items:size() - 1 do
                local tape = items:get(i)
                if not POS_TapeManager.isFull(tape) then
                    return tape
                end
            end
        end
    end

    return nil
end
