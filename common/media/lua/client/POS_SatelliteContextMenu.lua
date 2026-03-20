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
-- POS_SatelliteContextMenu.lua
-- Right-click context menu for Satellite Uplink.
-- Appears when player right-clicks on a satellite dish object.
-- Sub-menu with 3 actions per design-guidelines.md §10.1.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_SatelliteService"
require "POS_SatelliteBroadcastAction"

POS_SatelliteContextMenu = {}

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Find a compiled intelligence artifact in the player's inventory.
---@param player IsoPlayer
---@return InventoryItem|nil
local function findBroadcastArtifact(player)
    local inv = player:getInventory()
    if not inv then return nil end

    -- Look for items tagged POS_Intelligence (Tier III compiled artifacts)
    local items = PhobosLib.findItemsByTag(inv, POS_Constants.TAG_INTELLIGENCE)
    if items and #items > 0 then
        return items[1]
    end
    return nil
end

--- Get the satellite dish square from world objects.
---@param worldobjects table
---@return IsoGridSquare|nil
local function getDishSquare(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if POS_SatelliteService.isSatelliteDish(obj) then
            local ok, sq = pcall(function() return obj:getSquare() end)
            if ok and sq then return sq end
        end
    end
    return nil
end

---------------------------------------------------------------
-- Context Menu Hook
---------------------------------------------------------------

function POS_SatelliteContextMenu.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    -- Master toggle
    if POS_Sandbox and POS_Sandbox.getEnableSatelliteUplink
        and not POS_Sandbox.getEnableSatelliteUplink() then
        return
    end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- Check if any world object is a satellite dish
    local foundDish = false
    for _, obj in ipairs(worldobjects) do
        if POS_SatelliteService.isSatelliteDish(obj) then
            foundDish = true
            break
        end
    end
    if not foundDish then return end

    local sq = getDishSquare(worldobjects)
    if not sq then return end

    -- Build sub-menu per §10.1
    local parentLabel = PhobosLib.safeGetText("UI_POS_Satellite_SubMenu")
    local parentOption = context:addOption(parentLabel, worldobjects)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(parentOption, subMenu)

    -- Get status
    local status = POS_SatelliteService.getStatus(player, sq)
    local artifact = findBroadcastArtifact(player)

    -- 1. Broadcast Compiled Report
    local broadcastState = "ready"
    local broadcastTip = ""
    local onCooldown, hoursLeft = POS_SatelliteService.isOnCooldown(player)

    if onCooldown then
        broadcastState = "cooldown"
        broadcastTip = PhobosLib.safeGetText("UI_POS_Satellite_OnCooldown", tostring(hoursLeft))
    elseif not status.hasPower then
        broadcastState = "no_power"
        broadcastTip = PhobosLib.safeGetText("UI_POS_Satellite_NoPower")
    elseif not status.calibrated then
        broadcastState = "not_calibrated"
        broadcastTip = PhobosLib.safeGetText("UI_POS_Satellite_NotCalibrated")
    elseif not artifact then
        broadcastState = "missing_report"
        broadcastTip = PhobosLib.safeGetText("UI_POS_Satellite_MissingReport")
    else
        -- Check danger
        if PhobosLib and PhobosLib.isDangerNearby then
            local radius = POS_Sandbox and POS_Sandbox.getDangerCheckRadius
                and POS_Sandbox.getDangerCheckRadius()
                or POS_Constants.DANGER_CHECK_RADIUS
            if PhobosLib.isDangerNearby(player, radius) then
                broadcastState = "danger"
                broadcastTip = PhobosLib.safeGetText("UI_POS_Satellite_DangerNearby")
            end
        end
        if broadcastState == "ready" then
            broadcastTip = PhobosLib.safeGetText("UI_POS_Satellite_Ready")
        end
    end

    local broadcastOption = subMenu:addOption(
        PhobosLib.safeGetText("UI_POS_Satellite_Broadcast"),
        worldobjects, function()
            if broadcastState == "ready" and artifact then
                ISTimedActionQueue.add(
                    POS_SatelliteBroadcastAction:new(player,
                        POS_SatelliteBroadcastAction.TYPE_BROADCAST, sq, artifact))
            end
        end)
    if broadcastState ~= "ready" then broadcastOption.notAvailable = true end
    local broadcastTT = ISWorldObjectContextMenu.addToolTip()
    broadcastTT.description = broadcastTip
    broadcastOption.toolTip = broadcastTT

    -- 2. Calibrate Dish
    local calibrateState = "ready"
    local calibrateTip = ""

    if status.calibrated then
        calibrateState = "already_calibrated"
        calibrateTip = PhobosLib.safeGetText("UI_POS_Satellite_StatusCalibrated")
    elseif not status.hasPower then
        calibrateState = "no_power"
        calibrateTip = PhobosLib.safeGetText("UI_POS_Satellite_NoPower")
    else
        -- Check danger
        if PhobosLib and PhobosLib.isDangerNearby then
            local radius = POS_Sandbox and POS_Sandbox.getDangerCheckRadius
                and POS_Sandbox.getDangerCheckRadius()
                or POS_Constants.DANGER_CHECK_RADIUS
            if PhobosLib.isDangerNearby(player, radius) then
                calibrateState = "danger"
                calibrateTip = PhobosLib.safeGetText("UI_POS_Satellite_DangerNearby")
            end
        end
        if calibrateState == "ready" then
            calibrateTip = PhobosLib.safeGetText("UI_POS_Satellite_CalibrateReady")
        end
    end

    local calibrateOption = subMenu:addOption(
        PhobosLib.safeGetText("UI_POS_Satellite_Calibrate"),
        worldobjects, function()
            if calibrateState == "ready" then
                ISTimedActionQueue.add(
                    POS_SatelliteBroadcastAction:new(player,
                        POS_SatelliteBroadcastAction.TYPE_CALIBRATE, sq, nil))
            end
        end)
    if calibrateState ~= "ready" then calibrateOption.notAvailable = true end
    local calibrateTT = ISWorldObjectContextMenu.addToolTip()
    calibrateTT.description = calibrateTip
    calibrateOption.toolTip = calibrateTT

    -- 3. Check Signal Status (free, instant)
    local statusOption = subMenu:addOption(
        PhobosLib.safeGetText("UI_POS_Satellite_CheckStatus"),
        worldobjects, function()
            POS_SatelliteContextMenu.showStatus(player, sq)
        end)
    local statusTT = ISWorldObjectContextMenu.addToolTip()
    statusTT.description = PhobosLib.safeGetText("UI_POS_Satellite_CheckStatusTip")
    statusOption.toolTip = statusTT
end

---------------------------------------------------------------
-- Status Display
---------------------------------------------------------------

--- Display satellite dish status via character speech bubbles.
---@param player IsoPlayer
---@param sq IsoGridSquare
function POS_SatelliteContextMenu.showStatus(player, sq)
    if not player or not sq then return end

    local status = POS_SatelliteService.getStatus(player, sq)

    -- Calibration status
    if status.calibrated then
        player:Say(PhobosLib.safeGetText("UI_POS_Satellite_StatusCalibrated"))
    else
        player:Say(PhobosLib.safeGetText("UI_POS_Satellite_StatusUncalibrated"))
    end

    -- Terminal link
    if status.hasLink then
        player:Say(PhobosLib.safeGetText("UI_POS_Satellite_StatusLinked",
            tostring(POS_Constants.SATELLITE_LINK_RANGE)))
    else
        player:Say(PhobosLib.safeGetText("UI_POS_Satellite_StatusUnlinked"))
    end

    -- Fuel warning
    if status.fuelLow then
        player:Say(PhobosLib.safeGetText("UI_POS_Satellite_LowFuel"))
    end
end

Events.OnFillWorldObjectContextMenu.Add(POS_SatelliteContextMenu.onFillWorldObjectContextMenu)
