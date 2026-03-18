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
-- Dynamic tooltip builder for RawMarketNote items.
-- Reads modData fields stamped by POS_MarketReconAction and
-- produces a formatted tooltip string for inventory display.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_NoteTooltip = {}

--- Build a rich tooltip string from a market note's modData.
function POS_NoteTooltip.buildTooltip(item)
    if not item then return nil end
    local md = item:getModData()
    if not md or md[POS_Constants.MD_NOTE_TYPE] ~= "market" then return nil end

    local lines = {}

    -- Category
    local category = md[POS_Constants.MD_NOTE_CATEGORY] or "unknown"
    local catLabel = category
    if POS_MarketRegistry and POS_MarketRegistry.getCategory then
        local catDef = POS_MarketRegistry.getCategory(category)
        if catDef and catDef.labelKey then
            catLabel = PhobosLib.safeGetText(catDef.labelKey)
        end
    end
    lines[#lines + 1] = PhobosLib.safeGetText("UI_POS_NoteTooltip_Category") .. ": " .. catLabel

    -- Location
    local location = md[POS_Constants.MD_NOTE_LOCATION]
    if location and location ~= "" then
        lines[#lines + 1] = PhobosLib.safeGetText("UI_POS_NoteTooltip_Location") .. ": " .. tostring(location)
    end

    -- Confidence
    local confidence = md[POS_Constants.MD_NOTE_CONFIDENCE] or "unknown"
    lines[#lines + 1] = PhobosLib.safeGetText("UI_POS_NoteTooltip_Confidence") .. ": " .. tostring(confidence)

    -- Price estimate
    local price = md[POS_Constants.MD_NOTE_PRICE]
    if price then
        lines[#lines + 1] = PhobosLib.safeGetText("UI_POS_NoteTooltip_Price") .. ": $" .. tostring(price)
    end

    -- Stock level
    local stock = md[POS_Constants.MD_NOTE_STOCK]
    if stock then
        lines[#lines + 1] = PhobosLib.safeGetText("UI_POS_NoteTooltip_Stock") .. ": " .. tostring(stock)
    end

    -- Items observed
    local itemsStr = md[POS_Constants.MD_NOTE_ITEMS]
    if itemsStr and itemsStr ~= "" then
        lines[#lines + 1] = ""
        lines[#lines + 1] = PhobosLib.safeGetText("UI_POS_NoteTooltip_Items") .. ":"
        for entry in itemsStr:gmatch("[^|]+") do
            local fullType, priceStr = entry:match("([^:]+):(.+)")
            if fullType and priceStr then
                -- Try to get display name
                local displayName = fullType
                local script = ScriptManager.instance and ScriptManager.instance:getItem(fullType)
                if script then
                    local dn = script:getDisplayName()
                    if dn then displayName = dn end
                end
                lines[#lines + 1] = "  " .. displayName .. " — $" .. priceStr
            end
        end
    end

    -- Recorded day
    local recordedDay = md[POS_Constants.MD_NOTE_RECORDED]
    if recordedDay then
        lines[#lines + 1] = ""
        lines[#lines + 1] = PhobosLib.safeGetText("UI_POS_NoteTooltip_Recorded") .. ": Day " .. tostring(recordedDay)
    end

    return table.concat(lines, " <BR> ")
end

--- Apply a formatted tooltip to a market note item.
--- Stores the tooltip text in modData and calls setExtraTooltip if available.
function POS_NoteTooltip.applyToNote(item)
    if not item then return end
    local tooltipText = POS_NoteTooltip.buildTooltip(item)
    if tooltipText then
        local md = item:getModData()
        if md then
            md["POS_FormattedTooltip"] = tooltipText
        end
        -- Try to set the extra tooltip if PZ supports it
        if item.setExtraTooltip then
            item:setExtraTooltip(tooltipText)
        end
    end
end
