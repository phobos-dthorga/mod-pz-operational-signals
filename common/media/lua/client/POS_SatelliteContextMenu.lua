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
require "POS_SatelliteWiringAction"

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
            local ok, sq = PhobosLib.safecall(function() return obj:getSquare() end)
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
    elseif not status.hasLink then
        broadcastState = "no_link"
        broadcastTip = PhobosLib.safeGetText("UI_POS_Satellite_NoTerminalLink")
    elseif status.fuelLow then
        broadcastState = "low_fuel"
        broadcastTip = PhobosLib.safeGetText("UI_POS_Satellite_InsufficientFuel")
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
    elseif not status.hasLink then
        calibrateState = "no_link"
        calibrateTip = PhobosLib.safeGetText("UI_POS_Satellite_NoTerminalLink")
    elseif status.fuelLow then
        calibrateState = "low_fuel"
        calibrateTip = PhobosLib.safeGetText("UI_POS_Satellite_InsufficientFuel")
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

    -- 4. Wire to Terminal (only when NOT wired)
    if not POS_SatelliteService.isWired(sq) then
        local maxRange = POS_Sandbox and POS_Sandbox.getSatelliteWiringMaxRange
            and POS_Sandbox.getSatelliteWiringMaxRange()
            or POS_Constants.SATELLITE_WIRING_MAX_RANGE_DEFAULT
        local targets = POS_SatelliteService.findDesktopTargets(sq, maxRange)

        if #targets == 0 then
            -- Grey out with "no desktop in range"
            local wireOpt = subMenu:addOption(
                PhobosLib.safeGetText("UI_POS_Satellite_WireToTerminal"))
            wireOpt.notAvailable = true
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_WireNoDesktop", tostring(maxRange))
            wireOpt.toolTip = tooltip
        elseif #targets == 1 then
            -- Single target — direct option
            local t = targets[1]
            local reqs = POS_SatelliteService.checkWiringRequirements(player, t.wireCount)
            local wireOpt = subMenu:addOption(
                PhobosLib.safeGetText("UI_POS_Satellite_WireToTerminal"))

            if not reqs.ok then
                wireOpt.notAvailable = true
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                if reqs.skillTooLow then
                    tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_WireLowSkill",
                        tostring(reqs.skillNeed), tostring(reqs.skillHave))
                elseif #reqs.missingTools > 0 then
                    tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_WireNoTools")
                elseif reqs.missingItems and reqs.missingItems.type then
                    tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_WireNotEnough",
                        tostring(reqs.missingItems.need), tostring(reqs.missingItems.have))
                end
                wireOpt.toolTip = tooltip
            else
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_WireReady",
                    tostring(t.wireCount), tostring(t.wireCount))
                wireOpt.toolTip = tooltip
                wireOpt.onSelect = function()
                    ISTimedActionQueue.add(POS_SatelliteWiringAction:new(
                        player, POS_SatelliteWiringAction.TYPE_WIRE,
                        sq, t.x, t.y, t.z, t.wireCount))
                end
            end
        else
            -- Multiple targets — nested sub-menu
            local wireOpt = subMenu:addOption(
                PhobosLib.safeGetText("UI_POS_Satellite_WireToTerminal"))
            local chooseMenu = ISContextMenu:getNew(subMenu)
            subMenu:addSubMenu(wireOpt, chooseMenu)

            for _, t in ipairs(targets) do
                local reqs = POS_SatelliteService.checkWiringRequirements(player, t.wireCount)
                local label = PhobosLib.safeGetText("UI_POS_Satellite_TerminalAt",
                    tostring(t.x), tostring(t.y), tostring(t.wireCount), tostring(t.wireCount))
                local opt = chooseMenu:addOption(label)

                if not reqs.ok then
                    opt.notAvailable = true
                    local tooltip = ISWorldObjectContextMenu.addToolTip()
                    if reqs.skillTooLow then
                        tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_WireLowSkill",
                            tostring(reqs.skillNeed), tostring(reqs.skillHave))
                    elseif #reqs.missingTools > 0 then
                        tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_WireNoTools")
                    elseif reqs.missingItems and reqs.missingItems.type then
                        tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_WireNotEnough",
                            tostring(reqs.missingItems.need), tostring(reqs.missingItems.have))
                    end
                    opt.toolTip = tooltip
                else
                    local tx, ty, tz, wc = t.x, t.y, t.z, t.wireCount
                    opt.onSelect = function()
                        ISTimedActionQueue.add(POS_SatelliteWiringAction:new(
                            player, POS_SatelliteWiringAction.TYPE_WIRE,
                            sq, tx, ty, tz, wc))
                    end
                end
            end
        end
    end

    -- 5. Disconnect Wiring (only when IS wired)
    if POS_SatelliteService.isWired(sq) then
        local data = POS_SatelliteService.getWiringData(sq)
        local returnCount = math.floor((data.wireCount or 0) * POS_Constants.SATELLITE_WIRING_RETURN_PCT / 100)
        local disconnectOpt = subMenu:addOption(
            PhobosLib.safeGetText("UI_POS_Satellite_DisconnectWiring"))
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_DisconnectReady",
            tostring(returnCount))
        disconnectOpt.toolTip = tooltip
        disconnectOpt.onSelect = function()
            ISTimedActionQueue.add(POS_SatelliteWiringAction:new(
                player, POS_SatelliteWiringAction.TYPE_DISCONNECT, sq))
        end
    end
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

    -- Wired/wireless link state
    local wiringData = POS_SatelliteService.getWiringData(sq)
    if wiringData then
        player:Say(PhobosLib.safeGetText("UI_POS_Satellite_StatusWired", tostring(wiringData.wireCount)))
    else
        player:Say(PhobosLib.safeGetText("UI_POS_Satellite_StatusWireless"))
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
