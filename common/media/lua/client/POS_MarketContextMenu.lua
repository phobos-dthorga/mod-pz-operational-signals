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

function POS_MarketContextMenu.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    -- Check if market system is enabled
    if POS_Sandbox and POS_Sandbox.getEnableMarkets and not POS_Sandbox.getEnableMarkets() then
        return
    end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- Check if player has required materials
    if not hasWritingTool(player) or not hasPaper(player) then return end

    -- Check if player is in a mapped building
    local category, location = getRoomCategory(player)
    if not category then return end

    -- Add context menu option
    local catLabel = ""
    local catDef = POS_MarketRegistry and POS_MarketRegistry.getCategory(category)
    if catDef then
        catLabel = " (" .. PhobosLib.safeGetText(catDef.labelKey) .. ")"
    end

    local option = context:addOption(
        PhobosLib.safeGetText("UI_POS_Market_GatherIntel") .. catLabel,
        worldobjects, function()
            ISTimedActionQueue.add(
                POS_MarketReconAction:new(player, category, location)
            )
        end
    )

    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description = PhobosLib.safeGetText("UI_POS_Market_GatherIntel_Tooltip")
    option.toolTip = tooltip
end

Events.OnFillWorldObjectContextMenu.Add(POS_MarketContextMenu.onFillWorldObjectContextMenu)
