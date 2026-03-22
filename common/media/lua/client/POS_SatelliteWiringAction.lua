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
-- POS_SatelliteWiringAction.lua
-- Timed action for wiring/disconnecting a satellite dish
-- to/from a desktop terminal.
---------------------------------------------------------------

require "TimedActions/ISBaseTimedAction"
require "PhobosLib"
require "POS_Constants"
require "POS_SatelliteService"

local _TAG = "POS:SatWireAction"

POS_SatelliteWiringAction = ISBaseTimedAction:derive("POS_SatelliteWiringAction")

POS_SatelliteWiringAction.TYPE_WIRE       = "wire"
POS_SatelliteWiringAction.TYPE_DISCONNECT = "disconnect"

function POS_SatelliteWiringAction:new(player, actionType, sq, targetX, targetY, targetZ, wireCount)
    local o = ISBaseTimedAction.new(self)
    o.character = player
    o.actionType = actionType
    o.sq = sq
    o.targetX = targetX
    o.targetY = targetY
    o.targetZ = targetZ
    o.wireCount = wireCount or 0

    if actionType == POS_SatelliteWiringAction.TYPE_WIRE then
        local baseTime = PhobosLib.clamp(
            o.wireCount * POS_Constants.SATELLITE_WIRING_TIME_PER_TILE,
            POS_Constants.SATELLITE_WIRING_TIME_MIN,
            POS_Constants.SATELLITE_WIRING_TIME_MAX)
        o.maxTime = baseTime
    else
        o.maxTime = POS_Constants.SATELLITE_DISCONNECT_TIME
    end

    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function POS_SatelliteWiringAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.sq then return false end
    if self.actionType == POS_SatelliteWiringAction.TYPE_WIRE then
        local inv = self.character:getInventory()
        if not inv then return false end
        local have = inv:getCountType(POS_Constants.SATELLITE_WIRING_ITEM) or 0
        if have < self.wireCount then return false end
        if not inv:containsType(POS_Constants.SATELLITE_WIRING_TOOL_SCREWDRIVER) then return false end
        if not inv:containsType(POS_Constants.SATELLITE_WIRING_TOOL_PLIERS) then return false end
    end
    return true
end

function POS_SatelliteWiringAction:start()
    self:setActionAnim("Loot")
    if self.actionType == POS_SatelliteWiringAction.TYPE_WIRE then
        self.character:Say(PhobosLib.safeGetText("UI_POS_Satellite_WiringInProgress"))
    else
        self.character:Say(PhobosLib.safeGetText("UI_POS_Satellite_DisconnectInProgress"))
    end
end

function POS_SatelliteWiringAction:update()
    -- No per-tick logic needed
end

function POS_SatelliteWiringAction:stop()
    ISBaseTimedAction.stop(self)
end

function POS_SatelliteWiringAction:perform()
    if self.actionType == POS_SatelliteWiringAction.TYPE_WIRE then
        local success = POS_SatelliteService.wireToTerminal(
            self.character, self.sq,
            self.targetX, self.targetY, self.targetZ,
            self.wireCount)
        if success then
            PhobosLib.notifyOrSay(self.character,
                PhobosLib.safeGetText("UI_POS_Satellite_WiringComplete",
                    tostring(self.wireCount), tostring(self.wireCount)),
                "POSnet")
        else
            PhobosLib.notifyOrSay(self.character,
                PhobosLib.safeGetText("UI_POS_Satellite_WiringFailed"),
                "POSnet")
        end
    else
        local result = POS_SatelliteService.disconnectWiring(self.character, self.sq)
        if result then
            PhobosLib.notifyOrSay(self.character,
                PhobosLib.safeGetText("UI_POS_Satellite_DisconnectComplete",
                    tostring(result.returned)),
                "POSnet")
        end
    end
    ISBaseTimedAction.perform(self)
end

function POS_SatelliteWiringAction:getDuration()
    return self.maxTime
end
