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
-- POS_CameraCompileAction.lua
-- Timed action for Camera Workstation compilation.
-- Handles all 3 action types (compile/review/bulletin).
-- Delegates all business logic to POS_CameraService.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_CameraService"
require "POS_SIGINTService"
require "TimedActions/ISBaseTimedAction"

POS_CameraCompileAction = ISBaseTimedAction:derive("POS_CameraCompileAction")

function POS_CameraCompileAction:new(player, actionType, inputs)
    local o = ISBaseTimedAction.new(self, player)
    o.actionType = actionType
    o.inputs = inputs or {}

    -- Action time by type, with SIGINT reduction
    local baseTime
    if actionType == POS_Constants.CAMERA_COMPILE_ACTION then
        baseTime = POS_Sandbox and POS_Sandbox.getCameraCompileTime
            and POS_Sandbox.getCameraCompileTime()
            or POS_Constants.CAMERA_COMPILE_TIME_DEFAULT
    elseif actionType == POS_Constants.CAMERA_TAPE_REVIEW_ACTION then
        baseTime = POS_Sandbox and POS_Sandbox.getCameraTapeReviewTime
            and POS_Sandbox.getCameraTapeReviewTime()
            or POS_Constants.CAMERA_TAPE_REVIEW_TIME_DEFAULT
    else
        baseTime = POS_Sandbox and POS_Sandbox.getCameraBulletinTime
            and POS_Sandbox.getCameraBulletinTime()
            or POS_Constants.CAMERA_BULLETIN_TIME_DEFAULT
    end

    o.maxTime = POS_SIGINTService.calculateEffectiveTime(player, baseTime)
    return o
end

function POS_CameraCompileAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.inputs or #self.inputs == 0 then return false end

    local inv = self.character:getInventory()
    if not inv then return false end
    for _, item in ipairs(self.inputs) do
        if not inv:contains(item) then return false end
    end
    return true
end

function POS_CameraCompileAction:start()
    self:setActionAnim("Write")
    self:setOverrideHandModels(nil, nil)
end

function POS_CameraCompileAction:update()
    if self.character and ZombRand(POS_Constants.CHARACTER_MUMBLE_CHANCE) == 0 then
        local mumbleKey
        if self.actionType == POS_Constants.CAMERA_COMPILE_ACTION then
            mumbleKey = "UI_POS_Camera_Mumble"
        elseif self.actionType == POS_Constants.CAMERA_TAPE_REVIEW_ACTION then
            mumbleKey = "UI_POS_Camera_Mumble"
        else
            mumbleKey = "UI_POS_Camera_Mumble"
        end
        self.character:Say(PhobosLib.safeGetText(mumbleKey))
    end
end

function POS_CameraCompileAction:stop()
    ISBaseTimedAction.stop(self)
end

function POS_CameraCompileAction:perform()
    local player = self.character
    if not player then return end

    -- Delegate to service — one-liner per design guidelines
    local artifact
    if self.actionType == POS_Constants.CAMERA_COMPILE_ACTION then
        artifact = POS_CameraService.compileSiteSurvey(player, self.inputs)
    elseif self.actionType == POS_Constants.CAMERA_TAPE_REVIEW_ACTION then
        artifact = POS_CameraService.reviewRecordedTape(player, self.inputs[1])
    elseif self.actionType == POS_Constants.CAMERA_BULLETIN_ACTION then
        artifact = POS_CameraService.produceMarketBulletin(player, self.inputs)
    end

    -- Notify completion
    if artifact then
        local md = PhobosLib.getModData(artifact)
        local confStr = md and tostring(md.POS_Confidence) or "?"
        local artifactName = artifact:getDisplayName() or "artifact"

        PhobosLib.notifyOrSay(player, {
            channel = POS_Constants.PN_CHANNEL_ID,
            message = PhobosLib.safeGetText(
                "UI_POS_Camera_Complete_Summary",
                artifactName, confStr),
            priority = "normal",
            colour = "success",
        })
    end

    ISBaseTimedAction.perform(self)
end
