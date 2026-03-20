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
-- POS_MarketContextMenu.lua
-- Right-click context menu for "Gather Market Intel".
-- Appears when the player is inside a mapped building with
-- a writing tool and paper in inventory.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_RoomCategoryMap"
require "POS_MarketReconAction"

POS_MarketContextMenu = {}

local WRITING_TOOLS = {
    "Base.Pen", "Base.Pencil", "Base.RedPen", "Base.BluePen",
    "Base.GreenPen", "Base.PenMultiColor", "Base.PenFancy",
    "Base.PenSpiffo", "Base.PencilSpiffo",
}

local PAPER_TYPES = { "Base.SheetPaper2", "Base.Notebook" }

local function hasWritingTool(player)
    local inv = player:getInventory()
    for _, ft in ipairs(WRITING_TOOLS) do
        if inv:getFirstTypeRecurse(ft) then return true end
    end
    return false
end

local function hasPaper(player)
    local inv = player:getInventory()
    for _, ft in ipairs(PAPER_TYPES) do
        if inv:getFirstTypeRecurse(ft) then return true end
    end
    return false
end

local function getRoomCategory(player)
    local sq = player:getSquare()
    if not sq then return nil, nil end
    local building = sq:getBuilding()
    if not building then return nil, nil end

    -- Try to get room type from the player's current room
    local room = sq:getRoom()
    if room then
        local roomName = room:getName()
        if roomName then
            local category = POS_RoomCategoryMap.getCategory(roomName)
            if category then
                -- Get address for location name
                local location = roomName
                if PhobosLib_Address and PhobosLib_Address.resolveAddress then
                    local addr = PhobosLib_Address.resolveAddress(sq:getX(), sq:getY())
                    if addr and addr.street then
                        location = PhobosLib_Address.formatAddress(addr)
                    end
                end
                return category, location
            end
        end
    end
    return nil, nil
end

--- Delegate to POS_MarketReconAction.getVisitKey for room-zone-scoped cooldown.
local function getVisitKey(sq)
    return POS_MarketReconAction.getVisitKey(sq)
end

function POS_MarketContextMenu.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    -- Master toggle
    if POS_Sandbox and POS_Sandbox.getEnableMarkets and not POS_Sandbox.getEnableMarkets() then
        return
    end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- Determine state
    local category, location = getRoomCategory(player)
    local hasTools = hasWritingTool(player)
    local hasPaperItem = hasPaper(player)

    -- Build label
    local baseLabel = PhobosLib.safeGetText("UI_POS_Market_GatherIntel")
    local catLabel = ""
    if category then
        local catDef = POS_MarketRegistry and POS_MarketRegistry.getCategory(category)
        if catDef then
            catLabel = " (" .. PhobosLib.safeGetText(catDef.labelKey) .. ")"
        end
    end

    -- Determine state and tooltip (6-state priority system)
    local state = POS_Constants.INTEL_STATE_READY
    local tooltipText = ""
    local daysLeft = 0

    if not category then
        state = POS_Constants.INTEL_STATE_WRONG_LOCATION
        tooltipText = PhobosLib.safeGetText("UI_POS_Market_GatherIntel_WrongLocation")
    elseif PhobosLib and PhobosLib.isDangerNearby then
        local radius = POS_Sandbox and POS_Sandbox.getDangerCheckRadius
            and POS_Sandbox.getDangerCheckRadius()
            or POS_Constants.DANGER_CHECK_RADIUS
        if PhobosLib.isDangerNearby(player, radius) then
            state = POS_Constants.INTEL_STATE_DANGER_NEARBY
            tooltipText = PhobosLib.safeGetText("UI_POS_Market_GatherIntel_DangerNearby")
        end
    end

    if state == POS_Constants.INTEL_STATE_READY then
        if not hasTools or not hasPaperItem then
            state = POS_Constants.INTEL_STATE_MISSING_ITEMS
            tooltipText = PhobosLib.safeGetText("UI_POS_Market_GatherIntel_MissingItems")
        else
            -- Check cooldown (scoped to entire room zone, not individual tiles)
            local sq = player:getSquare()
            local visitKey = sq and getVisitKey(sq)
            if visitKey then
                local lastVisitDay = player:getModData()[visitKey] or -999
                local currentDay = getGameTime():getNightsSurvived()
                local cooldownDays = POS_Sandbox and POS_Sandbox.getIntelCooldownDays
                    and POS_Sandbox.getIntelCooldownDays() or POS_Constants.INTEL_COOLDOWN_DAYS_DEFAULT
                local daysSince = currentDay - lastVisitDay

                if daysSince < cooldownDays then
                    state = POS_Constants.INTEL_STATE_ON_COOLDOWN
                    daysLeft = cooldownDays - daysSince
                    tooltipText = PhobosLib.safeGetText("UI_POS_Market_GatherIntel_Cooldown")
                        .. " " .. tostring(math.ceil(daysLeft)) .. " day(s)."
                else
                    state = POS_Constants.INTEL_STATE_READY
                    tooltipText = PhobosLib.safeGetText("UI_POS_Market_GatherIntel_Ready")
                end
            end
        end
    end

    -- Add option (always visible)
    local option = context:addOption(
        baseLabel .. catLabel,
        worldobjects, function()
            if state == POS_Constants.INTEL_STATE_READY then
                ISTimedActionQueue.add(
                    POS_MarketReconAction:new(player, category, location)
                )
            end
        end
    )

    -- Set unavailable for non-ready states
    if state ~= POS_Constants.INTEL_STATE_READY then
        option.notAvailable = true
    end

    -- Tooltip
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description = tooltipText
    option.toolTip = tooltip
end

Events.OnFillWorldObjectContextMenu.Add(POS_MarketContextMenu.onFillWorldObjectContextMenu)
