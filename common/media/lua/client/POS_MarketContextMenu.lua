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

---------------------------------------------------------------
-- Helpers (item lists from POS_Constants)
---------------------------------------------------------------

local function hasWritingTool(player)
    local inv = player:getInventory()
    for _, ft in ipairs(POS_Constants.WRITING_TOOLS) do
        if inv:getFirstTypeRecurse(ft) then return true end
    end
    return false
end

local function hasPaper(player)
    local inv = player:getInventory()
    for _, ft in ipairs(POS_Constants.PAPER_TYPES) do
        if inv:getFirstTypeRecurse(ft) then return true end
    end
    return false
end

--- Get all commodity categories and a display location for the
--- player's current room. Uses PhobosLib.getPlayerRoomName() for
--- correct IRoomDef resolution (not IsoRoom:getName()).
---@return string[] categories, string location
local function getRoomCategoriesAndLocation(player)
    local roomName = PhobosLib.getPlayerRoomName(player)
    if not roomName then return {}, nil end

    local categories = POS_RoomCategoryMap.getCategories(roomName)
    if #categories == 0 then return {}, nil end

    -- Resolve a human-readable address if PhobosLib_Address is available
    local location = roomName
    local sq = player:getSquare()
    if sq and PhobosLib_Address and PhobosLib_Address.resolveAddress then
        local addr = PhobosLib_Address.resolveAddress(sq:getX(), sq:getY())
        if addr and addr.street then
            location = PhobosLib_Address.formatAddress(addr)
        end
    end
    return categories, location
end

--- Delegate to POS_MarketReconAction.getVisitKey for room-zone-scoped cooldown.
local function getVisitKey(sq)
    return POS_MarketReconAction.getVisitKey(sq)
end

--- Resolve the category display label via POS_MarketRegistry.
local function getCategoryLabel(categoryId)
    local catDef = POS_MarketRegistry and POS_MarketRegistry.getCategory(categoryId)
    if catDef then
        return PhobosLib.safeGetText(catDef.labelKey)
    end
    return categoryId
end

--- Determine the current intel-gathering state and tooltip text.
--- Shared between single-option and sub-menu paths.
local function resolveIntelState(player, hasCategories)
    local state = POS_Constants.INTEL_STATE_READY
    local tooltipText = ""

    if not hasCategories then
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
        if not hasWritingTool(player) or not hasPaper(player) then
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
                    local daysLeft = cooldownDays - daysSince
                    tooltipText = PhobosLib.safeGetText("UI_POS_Market_GatherIntel_Cooldown")
                        .. " " .. tostring(math.ceil(daysLeft)) .. " day(s)."
                else
                    tooltipText = PhobosLib.safeGetText("UI_POS_Market_GatherIntel_Ready")
                end
            end
        end
    end

    return state, tooltipText
end

---------------------------------------------------------------
-- Context menu hook
---------------------------------------------------------------

function POS_MarketContextMenu.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    -- Master toggle
    if POS_Sandbox and POS_Sandbox.getEnableMarkets and not POS_Sandbox.getEnableMarkets() then
        return
    end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- Resolve categories via PhobosLib room detection
    local categories, location = getRoomCategoriesAndLocation(player)
    local hasCategories = #categories > 0

    -- Compute shared state (danger, items, cooldown)
    local state, tooltipText = resolveIntelState(player, hasCategories)
    local baseLabel = PhobosLib.safeGetText("UI_POS_Market_GatherIntel")

    if #categories <= 1 then
        -------------------------------------------------------
        -- Single category (or no match): one flat option
        -------------------------------------------------------
        local catLabel = ""
        if categories[1] then
            catLabel = " (" .. getCategoryLabel(categories[1]) .. ")"
        end

        local selectedCategory = categories[1]
        local option = context:addOption(
            baseLabel .. catLabel,
            worldobjects, function()
                if state == POS_Constants.INTEL_STATE_READY then
                    ISTimedActionQueue.add(
                        POS_MarketReconAction:new(player, selectedCategory, location)
                    )
                end
            end
        )

        if state ~= POS_Constants.INTEL_STATE_READY then
            option.notAvailable = true
        end

        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = tooltipText
        option.toolTip = tooltip
    else
        -------------------------------------------------------
        -- Multiple categories: sub-menu per §10.1
        -------------------------------------------------------
        local parentOption = context:addOption(baseLabel, worldobjects)
        local subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(parentOption, subMenu)

        -- Parent tooltip for multi-category locations
        local parentTooltip = ISWorldObjectContextMenu.addToolTip()
        parentTooltip.description = PhobosLib.safeGetText("UI_POS_Market_GatherIntel_MultiLocation")
        parentOption.toolTip = parentTooltip

        if state ~= POS_Constants.INTEL_STATE_READY then
            parentOption.notAvailable = true
        end

        for _, categoryId in ipairs(categories) do
            local catLabel = getCategoryLabel(categoryId)
            local subOption = subMenu:addOption(catLabel, worldobjects, function()
                if state == POS_Constants.INTEL_STATE_READY then
                    ISTimedActionQueue.add(
                        POS_MarketReconAction:new(player, categoryId, location)
                    )
                end
            end)

            if state ~= POS_Constants.INTEL_STATE_READY then
                subOption.notAvailable = true
            end

            local subTooltip = ISWorldObjectContextMenu.addToolTip()
            subTooltip.description = tooltipText
            subOption.toolTip = subTooltip
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(POS_MarketContextMenu.onFillWorldObjectContextMenu)
