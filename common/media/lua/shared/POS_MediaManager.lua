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
-- POS_MediaManager.lua
-- Unified media abstraction for all 3 families (VHS, Microcassette, Floppy).
-- Replaces POS_TapeManager with a registry-driven approach.
---------------------------------------------------------------

require "POS_Constants"

POS_MediaManager = {}

local _TAG = "[POS:MediaMgr]"

-- Media definitions: keyed by item fullType
local MEDIA_DEFS = {
    -- VHS-C family
    [POS_Constants.ITEM_BLANK_VHS_TAPE]    = {
        family   = POS_Constants.MEDIA_FAMILY_VHS,
        capacity = POS_Constants.VHS_FACTORY_CAPACITY,
        fidelity = POS_Constants.MEDIA_FIDELITY_STANDARD,
        confMod  = POS_Constants.VHS_CONFIDENCE_MOD_FACTORY,
        quality  = "high",
    },
    [POS_Constants.ITEM_REFURBISHED_TAPE]  = {
        family   = POS_Constants.MEDIA_FAMILY_VHS,
        capacity = POS_Constants.VHS_REFURBISHED_CAPACITY,
        fidelity = POS_Constants.MEDIA_FIDELITY_STANDARD,
        confMod  = POS_Constants.VHS_CONFIDENCE_MOD_REFURBISHED,
        quality  = "medium",
    },
    [POS_Constants.ITEM_SPLICED_TAPE]      = {
        family   = POS_Constants.MEDIA_FAMILY_VHS,
        capacity = POS_Constants.VHS_SPLICED_CAPACITY,
        fidelity = POS_Constants.MEDIA_FIDELITY_STANDARD,
        confMod  = POS_Constants.VHS_CONFIDENCE_MOD_SPLICED,
        quality  = "low",
    },
    [POS_Constants.ITEM_IMPROVISED_TAPE]   = {
        family   = POS_Constants.MEDIA_FAMILY_VHS,
        capacity = POS_Constants.VHS_IMPROVISED_CAPACITY,
        fidelity = POS_Constants.MEDIA_FIDELITY_STANDARD,
        confMod  = POS_Constants.VHS_CONFIDENCE_MOD_IMPROVISED,
        quality  = "very_low",
    },
    [POS_Constants.ITEM_RECORDED_RECON_TAPE] = {
        family   = POS_Constants.MEDIA_FAMILY_VHS,
        capacity = POS_Constants.VHS_FACTORY_CAPACITY,
        fidelity = POS_Constants.MEDIA_FIDELITY_STANDARD,
        confMod  = POS_Constants.VHS_CONFIDENCE_MOD_FACTORY,
        quality  = "high",
    },

    -- Microcassette family
    [POS_Constants.ITEM_MICROCASSETTE] = {
        family   = POS_Constants.MEDIA_FAMILY_MICROCASSETTE,
        capacity = POS_Constants.MICROCASSETTE_CAPACITY,
        fidelity = POS_Constants.MEDIA_FIDELITY_HIGH,
        confMod  = POS_Constants.MICROCASSETTE_CONFIDENCE_MOD,
        quality  = "high",
    },
    [POS_Constants.ITEM_RECORDED_MICROCASSETTE] = {
        family   = POS_Constants.MEDIA_FAMILY_MICROCASSETTE,
        capacity = POS_Constants.MICROCASSETTE_CAPACITY,
        fidelity = POS_Constants.MEDIA_FIDELITY_HIGH,
        confMod  = POS_Constants.MICROCASSETTE_CONFIDENCE_MOD,
        quality  = "high",
    },
    [POS_Constants.ITEM_REWOUND_MICROCASSETTE] = {
        family   = POS_Constants.MEDIA_FAMILY_MICROCASSETTE,
        capacity = POS_Constants.MICROCASSETTE_REWIND_CAP,
        fidelity = POS_Constants.MEDIA_FIDELITY_HIGH,
        confMod  = POS_Constants.MICROCASSETTE_REWOUND_CONFIDENCE_MOD,
        quality  = "medium",
    },

    -- Floppy disk family
    [POS_Constants.ITEM_BLANK_FLOPPY_DISK] = {
        family   = POS_Constants.MEDIA_FAMILY_FLOPPY,
        capacity = POS_Constants.FLOPPY_CAPACITY,
        fidelity = POS_Constants.MEDIA_FIDELITY_DIGITAL,
        confMod  = POS_Constants.FLOPPY_CONFIDENCE_MOD,
        quality  = "digital",
    },
    [POS_Constants.ITEM_RECORDED_FLOPPY_DISK] = {
        family   = POS_Constants.MEDIA_FAMILY_FLOPPY,
        capacity = POS_Constants.FLOPPY_CAPACITY,
        fidelity = POS_Constants.MEDIA_FIDELITY_DIGITAL,
        confMod  = POS_Constants.FLOPPY_CONFIDENCE_MOD,
        quality  = "digital",
    },
    [POS_Constants.ITEM_WORN_FLOPPY_DISK] = {
        family   = POS_Constants.MEDIA_FAMILY_FLOPPY,
        capacity = POS_Constants.FLOPPY_CAPACITY,
        fidelity = POS_Constants.MEDIA_FIDELITY_DIGITAL,
        confMod  = POS_Constants.FLOPPY_WORN_CONFIDENCE_MOD,
        quality  = "worn",
    },
}

--- Get the media definition for an item.
function POS_MediaManager.getMediaDef(item)
    if not item then return nil end
    return MEDIA_DEFS[item:getFullType()]
end

--- Check if an item is any kind of usable recording media (not spent/corrupt/scrap).
function POS_MediaManager.isUsableMedia(item)
    if not item then return false end
    local ft = item:getFullType()
    if not MEDIA_DEFS[ft] then return false end
    -- Exclude non-recordable states
    if ft == POS_Constants.ITEM_WORN_VHS_TAPE
        or ft == POS_Constants.ITEM_DAMAGED_VHS_TAPE
        or ft == POS_Constants.ITEM_MAGNETIC_TAPE_SCRAP
        or ft == POS_Constants.ITEM_SPENT_MICROCASSETTE
        or ft == POS_Constants.ITEM_CORRUPT_FLOPPY_DISK then
        return false
    end
    return true
end

--- Get the media family for an item.
function POS_MediaManager.getFamily(item)
    local def = POS_MediaManager.getMediaDef(item)
    return def and def.family or nil
end

--- Get current entry count on media.
function POS_MediaManager.getEntryCount(item)
    if not item then return 0 end
    local md = PhobosLib.getModData(item)
    if not md then return 0 end
    return tonumber(md[POS_Constants.MD_MEDIA_ENTRY_COUNT]) or 0
end

--- Get total capacity for media.
function POS_MediaManager.getCapacity(item)
    if not item then return 0 end
    local md = PhobosLib.getModData(item)
    local def = POS_MediaManager.getMediaDef(item)
    if not def then return 0 end
    return (md and tonumber(md[POS_Constants.MD_MEDIA_CAPACITY])) or def.capacity
end

--- Get remaining capacity on media.
function POS_MediaManager.getRemainingCapacity(item)
    if not item then return 0 end
    local capacity = POS_MediaManager.getCapacity(item)
    local used = POS_MediaManager.getEntryCount(item)
    return math.max(0, capacity - used)
end

--- Check if media is full.
function POS_MediaManager.isFull(item)
    return POS_MediaManager.getRemainingCapacity(item) <= 0
end

--- Get the confidence modifier for media (BPS).
function POS_MediaManager.getConfidenceMod(item)
    if not item then return 0 end
    local def = POS_MediaManager.getMediaDef(item)
    if not def then return 0 end

    local baseMod = def.confMod
    local md = PhobosLib.getModData(item)
    local wear = md and tonumber(md[POS_Constants.MD_MEDIA_WEAR]) or 0

    -- Wear reduces confidence: each wear point = -100 BPS
    return baseMod - (wear * 100)
end

--- Get the fidelity level string for media.
function POS_MediaManager.getFidelity(item)
    local def = POS_MediaManager.getMediaDef(item)
    return def and def.fidelity or POS_Constants.MEDIA_FIDELITY_STANDARD
end

--- Ensure media has a unique ID. Creates one if missing.
function POS_MediaManager.ensureMediaId(item)
    if not item then return nil end
    local md = PhobosLib.getModData(item)
    if not md then return nil end
    if not md[POS_Constants.MD_MEDIA_ID] then
        md[POS_Constants.MD_MEDIA_ID] = PhobosLib.generateId()
    end
    return md[POS_Constants.MD_MEDIA_ID]
end

--- Initialise media modData from its definition (idempotent).
function POS_MediaManager.ensureInitialized(item)
    if not item then return false end
    local def = POS_MediaManager.getMediaDef(item)
    if not def then return false end

    local md = PhobosLib.getModData(item)
    if not md then return false end

    POS_MediaManager.ensureMediaId(item)

    if not md[POS_Constants.MD_MEDIA_FAMILY] then
        md[POS_Constants.MD_MEDIA_FAMILY] = def.family
    end
    if not md[POS_Constants.MD_MEDIA_CAPACITY] then
        md[POS_Constants.MD_MEDIA_CAPACITY] = def.capacity
    end
    if not md[POS_Constants.MD_MEDIA_FIDELITY] then
        md[POS_Constants.MD_MEDIA_FIDELITY] = def.fidelity
    end
    if not md[POS_Constants.MD_MEDIA_CONF_MOD] then
        md[POS_Constants.MD_MEDIA_CONF_MOD] = def.confMod
    end
    if not md[POS_Constants.MD_MEDIA_ENTRY_COUNT] then
        md[POS_Constants.MD_MEDIA_ENTRY_COUNT] = 0
    end
    if not md[POS_Constants.MD_MEDIA_WEAR] then
        md[POS_Constants.MD_MEDIA_WEAR] = 0
    end
    if not md[POS_Constants.MD_MEDIA_CYCLE_COUNT] then
        md[POS_Constants.MD_MEDIA_CYCLE_COUNT] = 0
    end
    return true
end

--- Record a data chunk onto media. Returns true if successful.
function POS_MediaManager.recordEntry(item, chunk)
    if not item or not chunk then return false end
    if POS_MediaManager.isFull(item) then return false end

    POS_MediaManager.ensureInitialized(item)
    local md = PhobosLib.getModData(item)
    if not md then return false end

    -- Increment entry count
    md[POS_Constants.MD_MEDIA_ENTRY_COUNT] = (tonumber(md[POS_Constants.MD_MEDIA_ENTRY_COUNT]) or 0) + 1

    -- Store full chunk data in event log (not in item modData)
    if POS_EventLog and POS_EventLog.append then
        POS_EventLog.append(
            POS_Constants.EVENT_SYSTEM_RECON,
            chunk.type or "unknown",
            chunk.entityId or "unknown",
            chunk.region or "",
            md[POS_Constants.MD_MEDIA_ID],
            0,
            chunk.confidence or 50,
            tostring(chunk.x or 0) .. "," .. tostring(chunk.y or 0)
        )
    end

    -- Update region tracking
    if chunk.region and not md[POS_Constants.MD_MEDIA_REGION] then
        md[POS_Constants.MD_MEDIA_REGION] = chunk.region
    end

    return true
end

--- Apply degradation to media after a review/upload cycle.
--- Returns true if media has degraded beyond usability.
function POS_MediaManager.degradeMedia(item)
    if not item then return false end
    local md = PhobosLib.getModData(item)
    if not md then return false end

    local def = POS_MediaManager.getMediaDef(item)
    if not def then return false end

    local degradeRate = POS_Sandbox and POS_Sandbox.getTapeDegradationRate
        and POS_Sandbox.getTapeDegradationRate() or POS_Constants.VHS_DEGRADATION_RATE_PCT
    local currentWear = tonumber(md[POS_Constants.MD_MEDIA_WEAR]) or 0
    md[POS_Constants.MD_MEDIA_WEAR] = currentWear + degradeRate

    -- Increment cycle count
    md[POS_Constants.MD_MEDIA_CYCLE_COUNT] = (tonumber(md[POS_Constants.MD_MEDIA_CYCLE_COUNT]) or 0) + 1

    -- If wear exceeds threshold, media is spent
    if md[POS_Constants.MD_MEDIA_WEAR] >= 100 then
        return true  -- signal: media is worn out, caller should transform item
    end
    return false
end

--- Find the first usable media in player inventory, preferring highest fidelity.
--- Search order: Floppy > Microcassette > VHS (best quality first).
function POS_MediaManager.findUsableMedia(player)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    for _, ft in ipairs(POS_Constants.USABLE_MEDIA_SEARCH_ORDER) do
        if POS_MediaManager.isUsableMedia({ getFullType = function() return ft end }) then
            local items = inv:getItemsFromFullType(ft)
            if items then
                for i = 0, items:size() - 1 do
                    local media = items:get(i)
                    if not POS_MediaManager.isFull(media) then
                        return media
                    end
                end
            end
        end
    end

    return nil
end

--- Migrate legacy VHS tape modData keys to unified media keys.
--- For backward compatibility during the transition.
function POS_MediaManager.migrateVHSKeys(item)
    if not item then return false end
    local md = PhobosLib.getModData(item)
    if not md then return false end

    -- Already migrated?
    if md[POS_Constants.MD_MEDIA_MIGRATED] then return true end

    -- Migrate tape ID → media ID
    if md[POS_Constants.MD_TAPE_ID] and not md[POS_Constants.MD_MEDIA_ID] then
        md[POS_Constants.MD_MEDIA_ID] = md[POS_Constants.MD_TAPE_ID]
    end

    -- Migrate entry count
    if md[POS_Constants.MD_TAPE_ENTRY_COUNT] and not md[POS_Constants.MD_MEDIA_ENTRY_COUNT] then
        md[POS_Constants.MD_MEDIA_ENTRY_COUNT] = md[POS_Constants.MD_TAPE_ENTRY_COUNT]
    end

    -- Migrate capacity
    if md[POS_Constants.MD_TAPE_CAPACITY] and not md[POS_Constants.MD_MEDIA_CAPACITY] then
        md[POS_Constants.MD_MEDIA_CAPACITY] = md[POS_Constants.MD_TAPE_CAPACITY]
    end

    -- Migrate wear
    if md[POS_Constants.MD_TAPE_WEAR] and not md[POS_Constants.MD_MEDIA_WEAR] then
        md[POS_Constants.MD_MEDIA_WEAR] = md[POS_Constants.MD_TAPE_WEAR]
    end

    -- Migrate region
    if md[POS_Constants.MD_TAPE_REGION] and not md[POS_Constants.MD_MEDIA_REGION] then
        md[POS_Constants.MD_MEDIA_REGION] = md[POS_Constants.MD_TAPE_REGION]
    end

    -- Set family
    if not md[POS_Constants.MD_MEDIA_FAMILY] then
        md[POS_Constants.MD_MEDIA_FAMILY] = POS_Constants.MEDIA_FAMILY_VHS
    end

    -- Mark as migrated
    md[POS_Constants.MD_MEDIA_MIGRATED] = true

    PhobosLib.debug("POS", _TAG, "migrated VHS keys for " .. tostring(md[POS_Constants.MD_MEDIA_ID]))
    return true
end
