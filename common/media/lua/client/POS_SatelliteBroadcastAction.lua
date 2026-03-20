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
-- POS_SatelliteBroadcastAction.lua
-- Timed action for Satellite Uplink operations.
-- Handles calibration and broadcast actions.
-- Delegates all business logic to POS_SatelliteService.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_SatelliteService"
require "POS_SIGINTService"
require "POS_SIGINTSkill"
require "TimedActions/ISBaseTimedAction"

POS_SatelliteBroadcastAction = ISBaseTimedAction:derive("POS_SatelliteBroadcastAction")

--- Action types
POS_SatelliteBroadcastAction.TYPE_CALIBRATE = "calibrate"
POS_SatelliteBroadcastAction.TYPE_BROADCAST = "broadcast"

function POS_SatelliteBroadcastAction:new(player, actionType, sq, artifact)
    local o = ISBaseTimedAction.new(self, player)
    o.actionType = actionType
    o.sq = sq
    o.artifact = artifact  -- nil for calibration

    -- Action time by type, with SIGINT reduction
    local baseTime
    if actionType == POS_SatelliteBroadcastAction.TYPE_CALIBRATE then
        baseTime = POS_Sandbox and POS_Sandbox.getSatelliteCalibrationTime
            and POS_Sandbox.getSatelliteCalibrationTime()
            or POS_Constants.SATELLITE_CALIBRATION_TIME_DEFAULT
    else
        baseTime = POS_Constants.SATELLITE_BROADCAST_TIME_DEFAULT
    end

    o.maxTime = POS_SIGINTService.calculateEffectiveTime(player, baseTime)
    return o
end

function POS_SatelliteBroadcastAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.sq then return false end

    -- Power required for both actions
    if not POS_SatelliteService.hasPower(self.sq) then return false end

    -- Broadcast requires artifact still in inventory
    if self.actionType == POS_SatelliteBroadcastAction.TYPE_BROADCAST then
        if not self.artifact then return false end
        local inv = self.character:getInventory()
        if not inv or not inv:contains(self.artifact) then return false end
    end

    return true
end

function POS_SatelliteBroadcastAction:start()
    self:setActionAnim("Loot")
    self:setOverrideHandModels(nil, nil)
end

function POS_SatelliteBroadcastAction:update()
    if self.character and ZombRand(POS_Constants.CHARACTER_MUMBLE_CHANCE) == 0 then
        self.character:Say(PhobosLib.safeGetText("UI_POS_Satellite_Mumble"))
    end
end

function POS_SatelliteBroadcastAction:stop()
    ISBaseTimedAction.stop(self)
end

function POS_SatelliteBroadcastAction:perform()
    local player = self.character
    if not player then return end

    if self.actionType == POS_SatelliteBroadcastAction.TYPE_CALIBRATE then
        -- Delegate calibration to service
        local success = POS_SatelliteService.calibrate(player, self.sq)

        if success then
            PhobosLib.notifyOrSay(player, {
                channel = POS_Constants.PN_CHANNEL_ID,
                message = PhobosLib.safeGetText("UI_POS_Satellite_CalibrationComplete"),
                priority = "normal",
                colour = "success",
            })
        end

    elseif self.actionType == POS_SatelliteBroadcastAction.TYPE_BROADCAST then
        -- Delegate broadcast to service
        local results = POS_SatelliteService.broadcast(player, self.artifact, self.sq)

        if results and results.consumed then
            -- Format market impact description
            local impactKey
            if results.strength >= 0.8 then
                impactKey = "UI_POS_Satellite_ImpactStrong"
            elseif results.strength >= 0.5 then
                impactKey = "UI_POS_Satellite_ImpactModerate"
            else
                impactKey = "UI_POS_Satellite_ImpactWeak"
            end
            local impactText = PhobosLib.safeGetText(impactKey)

            PhobosLib.notifyOrSay(player, {
                channel = POS_Constants.PN_CHANNEL_ID,
                message = PhobosLib.safeGetText(
                    "UI_POS_Satellite_BroadcastComplete_Summary",
                    impactText),
                priority = "normal",
                colour = "success",
            })
        end
    end

    ISBaseTimedAction.perform(self)
end
