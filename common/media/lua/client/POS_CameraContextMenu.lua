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
-- POS_CameraContextMenu.lua
-- Right-click context menu for Camera Workstation.
-- Appears when player right-clicks on a camera furniture object.
-- Sub-menu with 3 actions per design-guidelines.md §10.1.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_CameraService"
require "POS_CameraCompileAction"

POS_CameraContextMenu = {}

---------------------------------------------------------------
-- Helpers
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

local function hasBlankVHS(player)
    local inv = player:getInventory()
    local vhs = inv:getFirstTypeRecurse("Base.VideoTape")
    if vhs then
        local md = PhobosLib.getModData(vhs)
        -- Blank if no recorded entries
        if not md or not md.POS_EntryCount then return true end
    end
    return false
end

--- Build state and tooltip for a camera action.
local function resolveActionState(player, actionType, inputCount, requiresPaper, requiresPen, requiresVHS)
    local state = "ready"
    local tooltipText = ""

    -- Check cooldown
    local onCooldown, hoursLeft = POS_CameraService.isOnCooldown(player, actionType)
    if onCooldown then
        state = "cooldown"
        tooltipText = PhobosLib.safeGetText("UI_POS_Camera_OnCooldown", tostring(hoursLeft))
        return state, tooltipText
    end

    -- Check power
    if PhobosLib.hasPower then
        local sq = player:getSquare()
        if sq and not PhobosLib.hasPower(sq) then
            state = "no_power"
            tooltipText = PhobosLib.safeGetText("UI_POS_Camera_NoPower")
            return state, tooltipText
        end
    end

    -- Check inputs
    if inputCount == 0 then
        state = "no_inputs"
        tooltipText = PhobosLib.safeGetText("UI_POS_Camera_NoInputs")
        return state, tooltipText
    end

    -- Check materials
    if requiresPaper and not hasPaper(player) then
        state = "missing_items"
        tooltipText = PhobosLib.safeGetText("UI_POS_Camera_MissingPaper")
        return state, tooltipText
    end
    if requiresPen and not hasWritingTool(player) then
        state = "missing_items"
        tooltipText = PhobosLib.safeGetText("UI_POS_Camera_MissingPen")
        return state, tooltipText
    end
    if requiresVHS and not hasBlankVHS(player) then
        state = "missing_items"
        tooltipText = PhobosLib.safeGetText("UI_POS_Camera_MissingVHS")
        return state, tooltipText
    end

    -- Check danger
    if PhobosLib and PhobosLib.isDangerNearby then
        local radius = POS_Sandbox and POS_Sandbox.getDangerCheckRadius
            and POS_Sandbox.getDangerCheckRadius()
            or POS_Constants.DANGER_CHECK_RADIUS
        if PhobosLib.isDangerNearby(player, radius) then
            state = "danger"
            tooltipText = PhobosLib.safeGetText("UI_POS_Camera_DangerNearby")
            return state, tooltipText
        end
    end

    tooltipText = PhobosLib.safeGetText("UI_POS_Camera_Ready")
    return state, tooltipText
end

---------------------------------------------------------------
-- Context Menu Hook
---------------------------------------------------------------

function POS_CameraContextMenu.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    -- Master toggle
    if POS_Sandbox and POS_Sandbox.getEnableMarkets and not POS_Sandbox.getEnableMarkets() then
        return
    end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- Check if any world object is a camera workstation
    local foundCamera = false
    for _, obj in ipairs(worldobjects) do
        if POS_CameraService.isCameraWorkstation(obj) then
            foundCamera = true
            break
        end
    end
    if not foundCamera then return end

    -- Build sub-menu per §10.1
    local parentLabel = PhobosLib.safeGetText("UI_POS_Camera_SubMenu")
    local parentOption = context:addOption(parentLabel, worldobjects)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(parentOption, subMenu)

    -- Gather available inputs
    local compileInputs = POS_CameraService.findCompileInputs(player)
    local tapeInputs = POS_CameraService.findTapeInputs(player)
    local bulletinInputs = POS_CameraService.findBulletinInputs(player)

    -- 1. Compile Site Survey
    local compileState, compileTip = resolveActionState(
        player, POS_Constants.CAMERA_COMPILE_ACTION,
        #compileInputs, true, false, false)
    local compileOption = subMenu:addOption(
        PhobosLib.safeGetText("UI_POS_Camera_CompileSurvey"),
        worldobjects, function()
            if compileState == "ready" then
                -- Use up to 3 inputs
                local selected = {}
                for i = 1, math.min(3, #compileInputs) do
                    selected[#selected + 1] = compileInputs[i]
                end
                ISTimedActionQueue.add(
                    POS_CameraCompileAction:new(player,
                        POS_Constants.CAMERA_COMPILE_ACTION, selected))
            end
        end)
    if compileState ~= "ready" then compileOption.notAvailable = true end
    local compileTT = ISWorldObjectContextMenu.addToolTip()
    compileTT.description = compileTip
    compileOption.toolTip = compileTT

    -- 2. Review Recorded Tape
    local tapeState, tapeTip = resolveActionState(
        player, POS_Constants.CAMERA_TAPE_REVIEW_ACTION,
        #tapeInputs, true, true, false)
    local tapeOption = subMenu:addOption(
        PhobosLib.safeGetText("UI_POS_Camera_ReviewTape"),
        worldobjects, function()
            if tapeState == "ready" and tapeInputs[1] then
                ISTimedActionQueue.add(
                    POS_CameraCompileAction:new(player,
                        POS_Constants.CAMERA_TAPE_REVIEW_ACTION, { tapeInputs[1] }))
            end
        end)
    if tapeState ~= "ready" then tapeOption.notAvailable = true end
    local tapeTT = ISWorldObjectContextMenu.addToolTip()
    tapeTT.description = tapeTip
    tapeOption.toolTip = tapeTT

    -- 3. Produce Market Bulletin
    local bulletinState, bulletinTip = resolveActionState(
        player, POS_Constants.CAMERA_BULLETIN_ACTION,
        #bulletinInputs >= 2 and #bulletinInputs or 0, true, false, true)
    local bulletinOption = subMenu:addOption(
        PhobosLib.safeGetText("UI_POS_Camera_ProduceBulletin"),
        worldobjects, function()
            if bulletinState == "ready" then
                local selected = {}
                for i = 1, math.min(5, #bulletinInputs) do
                    selected[#selected + 1] = bulletinInputs[i]
                end
                ISTimedActionQueue.add(
                    POS_CameraCompileAction:new(player,
                        POS_Constants.CAMERA_BULLETIN_ACTION, selected))
            end
        end)
    if bulletinState ~= "ready" then bulletinOption.notAvailable = true end
    local bulletinTT = ISWorldObjectContextMenu.addToolTip()
    bulletinTT.description = bulletinTip
    bulletinOption.toolTip = bulletinTT
end

Events.OnFillWorldObjectContextMenu.Add(POS_CameraContextMenu.onFillWorldObjectContextMenu)
