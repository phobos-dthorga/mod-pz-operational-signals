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
-- POS_TerminalAnalysisAction.lua
-- Timed action for Terminal Analysis (Process Intelligence).
-- Uses ISBaseTimedAction pattern — delegates all business logic
-- to POS_TerminalAnalysisService. Presentation only.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_TerminalAnalysisService"
require "POS_SIGINTSkill"
require "TimedActions/ISBaseTimedAction"

POS_TerminalAnalysisAction = ISBaseTimedAction:derive("POS_TerminalAnalysisAction")

function POS_TerminalAnalysisAction:new(player, selectedInputs)
    local o = ISBaseTimedAction.new(self, player)
    o.selectedInputs = selectedInputs or {}

    -- Calculate action time based on SIGINT level
    local inputCount = math.min(#o.selectedInputs, POS_Constants.ANALYSIS_MAX_INPUTS)
    o.maxTime = POS_TerminalAnalysisService.calculateActionTime(player, inputCount)

    return o
end

function POS_TerminalAnalysisAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.selectedInputs or #self.selectedInputs == 0 then return false end

    -- Verify inputs still exist in inventory
    local inv = self.character:getInventory()
    if not inv then return false end
    for _, item in ipairs(self.selectedInputs) do
        if not inv:contains(item) then return false end
    end

    return true
end

function POS_TerminalAnalysisAction:start()
    -- Play typing/analysis animation
    self:setActionAnim("Write")
    self:setOverrideHandModels(nil, nil)
end

function POS_TerminalAnalysisAction:update()
    -- Character mumbles periodically
    if self.character and ZombRand(POS_Constants.CHARACTER_MUMBLE_CHANCE) == 0 then
        self.character:Say(PhobosLib.safeGetText("UI_POS_Analysis_Mumble"))
    end
end

function POS_TerminalAnalysisAction:stop()
    ISBaseTimedAction.stop(self)
end

function POS_TerminalAnalysisAction:perform()
    local player = self.character
    if not player then return end

    -- Delegate to service — one-liner per design guidelines
    local results = POS_TerminalAnalysisService.processIntelligence(
        player, self.selectedInputs)

    -- Notify player of results
    local fragmentCount = #results.fragments
    if fragmentCount > 0 then
        PhobosLib.notifyOrSay(player, {
            channel = POS_Constants.PN_CHANNEL_ID,
            message = PhobosLib.safeGetText(
                "UI_POS_Analysis_Complete_Summary",
                tostring(fragmentCount)),
            priority = "normal",
            colour = "success",
        })
    end

    -- Notify cross-correlation discovery
    if results.crossCorrelation then
        PhobosLib.notifyOrSay(player, {
            channel = POS_Constants.PN_CHANNEL_ID,
            message = PhobosLib.safeGetText("UI_POS_Analysis_CrossCorrelation_Found"),
            priority = "normal",
            colour = "info",
        })
    end

    -- Notify false data detection
    if results.falseDataFiltered then
        PhobosLib.notifyOrSay(player, {
            channel = POS_Constants.PN_CHANNEL_ID,
            message = PhobosLib.safeGetText("UI_POS_Analysis_FalseData_Detected"),
            priority = "normal",
            colour = "info",
        })
    end

    ISBaseTimedAction.perform(self)
end
