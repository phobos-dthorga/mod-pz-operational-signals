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
-- POS_NoteTooltip.lua
-- Dynamic tooltip provider for RawMarketNote and VHS tape items.
--
-- Uses PhobosLib.registerTooltipProvider() to hook into the
-- ISToolTipInv render system and display category-specific
-- intelligence data below the vanilla item tooltip.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_NoteTooltip = {}

-- Colours for tooltip lines
local COL_HEADER  = { r = 0.4, g = 1.0, b = 0.4 }  -- green
local COL_LABEL   = { r = 0.8, g = 0.8, b = 0.8 }  -- light grey
local COL_VALUE   = { r = 1.0, g = 1.0, b = 1.0 }  -- white
local COL_ITEM    = { r = 0.7, g = 0.9, b = 1.0 }  -- light blue
local COL_DIM     = { r = 0.5, g = 0.5, b = 0.5 }  -- dim grey

--- Build tooltip lines from a market note's modData.
--- @param item any InventoryItem
--- @return table|nil Array of {text, r, g, b} or nil
local function buildNoteTooltipLines(item)
    if not item then return nil end
    local md = item:getModData()
    if not md then return nil end

    -- Only process market notes
    if md[POS_Constants.MD_NOTE_TYPE] ~= "market" then return nil end

    local lines = {}

    -- Category header
    local category = md[POS_Constants.MD_NOTE_CATEGORY] or "unknown"
    local catLabel = category
    if POS_MarketRegistry and POS_MarketRegistry.getCategory then
        local catDef = POS_MarketRegistry.getCategory(category)
        if catDef and catDef.labelKey then
            catLabel = PhobosLib.safeGetText(catDef.labelKey)
        end
    end
    lines[#lines + 1] = { text = "--- Market Intel: " .. catLabel .. " ---",
        r = COL_HEADER.r, g = COL_HEADER.g, b = COL_HEADER.b }

    -- Location
    local location = md[POS_Constants.MD_NOTE_LOCATION]
    if location and location ~= "" then
        lines[#lines + 1] = { text = "Location: " .. PhobosLib.titleCase(tostring(location)),
            r = COL_LABEL.r, g = COL_LABEL.g, b = COL_LABEL.b }
    end

    -- Confidence
    local confidence = md[POS_Constants.MD_NOTE_CONFIDENCE] or "unknown"
    lines[#lines + 1] = { text = "Confidence: " .. tostring(confidence),
        r = COL_LABEL.r, g = COL_LABEL.g, b = COL_LABEL.b }

    -- Price estimate
    local price = md[POS_Constants.MD_NOTE_PRICE]
    if price then
        lines[#lines + 1] = { text = "Price Estimate: " .. PhobosLib.formatPrice(price),
            r = COL_VALUE.r, g = COL_VALUE.g, b = COL_VALUE.b }
    end

    -- Stock level
    local stock = md[POS_Constants.MD_NOTE_STOCK]
    if stock then
        lines[#lines + 1] = { text = "Stock Level: " .. tostring(stock),
            r = COL_LABEL.r, g = COL_LABEL.g, b = COL_LABEL.b }
    end

    -- Items observed
    local itemsStr = md[POS_Constants.MD_NOTE_ITEMS]
    if itemsStr and itemsStr ~= "" then
        lines[#lines + 1] = { text = "", r = 0, g = 0, b = 0 }  -- spacer
        lines[#lines + 1] = { text = "Items Observed:",
            r = COL_HEADER.r, g = COL_HEADER.g, b = COL_HEADER.b }

        for entry in itemsStr:gmatch("[^|]+") do
            local fullType, priceStr = entry:match("([^:]+):(.+)")
            if fullType and priceStr then
                local displayName = PhobosLib.getItemDisplayName(fullType)
                lines[#lines + 1] = { text = "  " .. displayName .. " - " .. PhobosLib.formatPrice(tonumber(priceStr)),
                    r = COL_ITEM.r, g = COL_ITEM.g, b = COL_ITEM.b }
            end
        end
    end

    -- Recorded day
    local recordedDay = md[POS_Constants.MD_NOTE_RECORDED]
    if recordedDay then
        lines[#lines + 1] = { text = "", r = 0, g = 0, b = 0 }  -- spacer
        lines[#lines + 1] = { text = "Recorded: Day " .. tostring(recordedDay),
            r = COL_DIM.r, g = COL_DIM.g, b = COL_DIM.b }
    end

    return #lines > 0 and lines or nil
end

--- Build tooltip lines for VHS tape items (summary only).
--- @param item any InventoryItem
--- @return table|nil
local function buildTapeTooltipLines(item)
    if not item then return nil end
    local md = item:getModData()
    if not md then return nil end

    -- Only process items with tape entry data
    local entryCount = tonumber(md[POS_Constants.MD_TAPE_ENTRY_COUNT])
    if not entryCount then return nil end

    local lines = {}

    lines[#lines + 1] = { text = "--- Tape Data ---",
        r = COL_HEADER.r, g = COL_HEADER.g, b = COL_HEADER.b }

    local capacity = tonumber(md[POS_Constants.MD_TAPE_CAPACITY]) or "?"
    lines[#lines + 1] = { text = "Entries: " .. tostring(entryCount) .. " / " .. tostring(capacity),
        r = COL_VALUE.r, g = COL_VALUE.g, b = COL_VALUE.b }

    local region = md[POS_Constants.MD_TAPE_REGION]
    if region and region ~= "" then
        lines[#lines + 1] = { text = "Region: " .. tostring(region),
            r = COL_LABEL.r, g = COL_LABEL.g, b = COL_LABEL.b }
    end

    local quality = md[POS_Constants.MD_TAPE_QUALITY]
    if quality then
        lines[#lines + 1] = { text = "Quality: " .. tostring(quality),
            r = COL_LABEL.r, g = COL_LABEL.g, b = COL_LABEL.b }
    end

    local wear = tonumber(md[POS_Constants.MD_TAPE_WEAR]) or 0
    if wear > 0 then
        lines[#lines + 1] = { text = "Wear: " .. tostring(wear) .. "%",
            r = COL_DIM.r, g = COL_DIM.g, b = COL_DIM.b }
    end

    return #lines > 0 and lines or nil
end

---------------------------------------------------------------
-- Registration
---------------------------------------------------------------

--- Combined provider for all POSnet items with dynamic tooltip data.
local function posnetTooltipProvider(item)
    -- Try market note first
    local noteLines = buildNoteTooltipLines(item)
    if noteLines then return noteLines end

    -- Try VHS tape
    local tapeLines = buildTapeTooltipLines(item)
    if tapeLines then return tapeLines end

    return nil
end

-- Register with PhobosLib's tooltip system
if PhobosLib and PhobosLib.registerTooltipProvider then
    PhobosLib.registerTooltipProvider("PhobosOperationalSignals.", posnetTooltipProvider)
end

--- Legacy compatibility: applyToNote is no longer needed since PhobosLib
--- handles tooltip rendering automatically. Keep as no-op for any callers.
function POS_NoteTooltip.applyToNote(item)
    -- No-op: PhobosLib tooltip provider handles rendering dynamically
end

--- Legacy compatibility: buildTooltip returns formatted string for non-tooltip uses.
function POS_NoteTooltip.buildTooltip(item)
    local lines = buildNoteTooltipLines(item)
    if not lines then return nil end
    local parts = {}
    for _, line in ipairs(lines) do
        if line.text and line.text ~= "" then
            parts[#parts + 1] = line.text
        end
    end
    return table.concat(parts, " <BR> ")
end
