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
-- POS_RelayContextMenu.lua
-- Right-click context menu entries for Tier V relay dish
-- discovery and wiring. Grouped under "POSnet" sub-menu
-- per design-guidelines.md §49.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_Relay"
require "POS_RelayDetection"
require "POS_StrategicRelayService"

local _TAG = "POS:RelayMenu"

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Find the first relay dish object among world objects.
---@param worldobjects table
---@return IsoObject|nil dishObj
---@return IsoGridSquare|nil sq
local function findRelayDish(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if POS_RelayDetection.isRelayDish(obj) then
            local ok, sq = PhobosLib.safecall(function() return obj:getSquare() end)
            if ok and sq then
                return obj, sq
            end
        end
    end
    return nil, nil
end

--- Generate site ID from square coordinates (matches POS_StrategicRelayService).
---@param sq IsoGridSquare
---@return string|nil
local function generateSiteId(sq)
    local ok, siteId = PhobosLib.safecall(function()
        return "relay_" .. tostring(sq:getX()) .. "_" .. tostring(sq:getY()) .. "_" .. tostring(sq:getZ())
    end)
    if ok then return siteId end
    return nil
end

---------------------------------------------------------------
-- Context Menu Hook
---------------------------------------------------------------

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- Find a relay dish among the clicked objects
    local dishObj, sq = findRelayDish(worldobjects)
    if not dishObj or not sq then return end

    -- Only process dishes that qualify as relay sites (rooftop heuristic)
    if not POS_RelayDetection.isRelaySite(sq) then return end

    -- Build "POSnet" sub-menu per §49
    local parentLabel = PhobosLib.safeGetText("UI_POS_SubMenu")
    local parentOption = context:addOption(parentLabel, worldobjects)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(parentOption, subMenu)

    local siteId = generateSiteId(sq)
    local isDiscovered = siteId and POS_StrategicRelayService.getRelay(siteId) ~= nil

    ---------------------------------------------------------------
    -- 1. Discover Relay Site (only when NOT discovered)
    ---------------------------------------------------------------
    if not isDiscovered then
        local canDiscover, reason = POS_RelayDetection.canDiscover(player, sq)

        local discoverOpt = subMenu:addOption(
            PhobosLib.safeGetText("UI_POS_Relay_ContextMenu_Discover"),
            worldobjects, function()
                if not canDiscover then return end
                local ok, relay = PhobosLib.safecall(
                    POS_StrategicRelayService.discoverRelay, player, sq)
                if ok and relay then
                    PhobosLib.safecall(function()
                        PhobosLib.notifyOrSay(player,
                            PhobosLib.safeGetText("UI_POS_Relay_Discovered"))
                    end)
                end
            end)

        if not canDiscover then
            discoverOpt.notAvailable = true
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = reason and PhobosLib.safeGetText(reason) or ""
            discoverOpt.toolTip = tooltip
        else
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = PhobosLib.safeGetText("UI_POS_Relay_ContextMenu_DiscoverTip")
            discoverOpt.toolTip = tooltip
        end
    end

    ---------------------------------------------------------------
    -- 2. Wire to Terminal (discovered + not wired)
    ---------------------------------------------------------------
    if isDiscovered then
        local okW, isWired = PhobosLib.safecall(POS_SatelliteService.isWired, sq)
        isWired = okW and isWired

        if not isWired then
            -- Reuse Tier IV wiring logic via POS_SatelliteService
            local ok, POS_SatelliteService = PhobosLib.safecall(require, "POS_SatelliteService")
            local ok2, POS_SatelliteWiringAction = PhobosLib.safecall(require, "POS_SatelliteWiringAction")

            local maxRange = POS_Constants.RELAY_WIRING_RANGE_MAX
            local targets = {}
            if ok and POS_SatelliteService and POS_SatelliteService.findDesktopTargets then
                local ok3, t = PhobosLib.safecall(POS_SatelliteService.findDesktopTargets, sq, maxRange)
                if ok3 and t then targets = t end
            end

            if #targets == 0 then
                local wireOpt = subMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_Relay_ContextMenu_Wire"))
                wireOpt.notAvailable = true
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_WireNoDesktop",
                    tostring(maxRange))
                wireOpt.toolTip = tooltip
            elseif #targets == 1 then
                local t = targets[1]
                local reqs = {}
                if ok and POS_SatelliteService.checkWiringRequirements then
                    local ok4, r = PhobosLib.safecall(
                        POS_SatelliteService.checkWiringRequirements, player, t.wireCount)
                    if ok4 and r then reqs = r end
                end

                local wireOpt = subMenu:addOption(
                    PhobosLib.safeGetText("UI_POS_Relay_ContextMenu_Wire"))

                if reqs.ok == false then
                    wireOpt.notAvailable = true
                    local tooltip = ISWorldObjectContextMenu.addToolTip()
                    if reqs.skillTooLow then
                        tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_WireLowSkill",
                            tostring(reqs.skillNeed), tostring(reqs.skillHave))
                    elseif reqs.missingTools and #reqs.missingTools > 0 then
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
                        if ok2 and POS_SatelliteWiringAction then
                            ISTimedActionQueue.add(POS_SatelliteWiringAction:new(
                                player, POS_SatelliteWiringAction.TYPE_WIRE,
                                sq, t.x, t.y, t.z, t.wireCount))
                        end
                    end
                end
            end

    ---------------------------------------------------------------
    -- 3. Disconnect Wiring (discovered + wired)
    ---------------------------------------------------------------
        else
            local ok5, POS_SatelliteService = PhobosLib.safecall(require, "POS_SatelliteService")
            local ok6, POS_SatelliteWiringAction = PhobosLib.safecall(require, "POS_SatelliteWiringAction")

            local data = nil
            if ok5 and POS_SatelliteService and POS_SatelliteService.getWiringData then
                local ok7, d = PhobosLib.safecall(POS_SatelliteService.getWiringData, sq)
                if ok7 then data = d end
            end

            local returnCount = 0
            if data and data.wireCount then
                returnCount = math.floor(data.wireCount * POS_Constants.SATELLITE_WIRING_RETURN_PCT / 100)
            end

            local disconnectOpt = subMenu:addOption(
                PhobosLib.safeGetText("UI_POS_Relay_ContextMenu_Disconnect"))
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = PhobosLib.safeGetText("UI_POS_Satellite_DisconnectReady",
                tostring(returnCount))
            disconnectOpt.toolTip = tooltip
            disconnectOpt.onSelect = function()
                if ok6 and POS_SatelliteWiringAction then
                    ISTimedActionQueue.add(POS_SatelliteWiringAction:new(
                        player, POS_SatelliteWiringAction.TYPE_DISCONNECT, sq))
                end
            end
        end
    end
end

---------------------------------------------------------------
-- Event Registration
---------------------------------------------------------------

if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
end
