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
-- POS_TutorialService.lua
-- Shared service for the progressive tutorial system.
-- Registers milestones, dispatches toasts and popup flags,
-- and handles legacy migration. All business logic lives here.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_TutorialService = {}

---------------------------------------------------------------
-- Milestone definitions
---------------------------------------------------------------

--- All tutorial milestones registered at init.
local MILESTONES = {
    { id = POS_Constants.TUTORIAL_FIRST_CONNECTION,        group = POS_Constants.TUTORIAL_GROUP_CORE,   labelKey = "UI_POS_Tutorial_Toast_FirstConnection" },
    { id = POS_Constants.TUTORIAL_FIRST_OP_RECEIVED,       group = POS_Constants.TUTORIAL_GROUP_CORE,   labelKey = "UI_POS_Tutorial_Toast_FirstOpReceived" },
    { id = POS_Constants.TUTORIAL_FIRST_OP_COMPLETED,      group = POS_Constants.TUTORIAL_GROUP_CORE,   labelKey = "UI_POS_Tutorial_Toast_FirstOpCompleted" },
    { id = POS_Constants.TUTORIAL_FIRST_MARKET_NOTE,       group = POS_Constants.TUTORIAL_GROUP_INTEL,  labelKey = "UI_POS_Tutorial_Toast_FirstMarketNote" },
    { id = POS_Constants.TUTORIAL_SIGINT_L3,               group = POS_Constants.TUTORIAL_GROUP_SIGINT, labelKey = "UI_POS_Tutorial_Toast_SigintL3" },
    { id = POS_Constants.TUTORIAL_SIGINT_L6,               group = POS_Constants.TUTORIAL_GROUP_SIGINT, labelKey = "UI_POS_Tutorial_Toast_SigintL6" },
    { id = POS_Constants.TUTORIAL_SIGINT_L9,               group = POS_Constants.TUTORIAL_GROUP_SIGINT, labelKey = "UI_POS_Tutorial_Toast_SigintL9" },
    { id = POS_Constants.TUTORIAL_FIRST_ANALYSIS,          group = POS_Constants.TUTORIAL_GROUP_INTEL,  labelKey = "UI_POS_Tutorial_Toast_FirstAnalysis" },
    { id = POS_Constants.TUTORIAL_FIRST_CAMERA,            group = POS_Constants.TUTORIAL_GROUP_INTEL,  labelKey = "UI_POS_Tutorial_Toast_FirstCamera" },
    { id = POS_Constants.TUTORIAL_FIRST_SATELLITE,         group = POS_Constants.TUTORIAL_GROUP_INTEL,  labelKey = "UI_POS_Tutorial_Toast_FirstSatellite" },
    { id = POS_Constants.TUTORIAL_FIRST_INVESTMENT,        group = POS_Constants.TUTORIAL_GROUP_CORE,   labelKey = "UI_POS_Tutorial_Toast_FirstInvestment" },
    { id = POS_Constants.TUTORIAL_FIRST_DELIVERY,          group = POS_Constants.TUTORIAL_GROUP_CORE,   labelKey = "UI_POS_Tutorial_Toast_FirstDelivery" },
    { id = POS_Constants.TUTORIAL_FIRST_DATA_RECORDER,     group = POS_Constants.TUTORIAL_GROUP_INTEL,  labelKey = "UI_POS_Tutorial_Toast_FirstDataRecorder" },
    { id = POS_Constants.TUTORIAL_FIRST_CROSS_CORRELATION, group = POS_Constants.TUTORIAL_GROUP_INTEL,  labelKey = "UI_POS_Tutorial_Toast_FirstCrossCorrelation" },
}

--- Milestones that trigger a Notice Popup (major progression gates).
local POPUP_MILESTONES = {
    [POS_Constants.TUTORIAL_FIRST_CONNECTION]  = true,
    [POS_Constants.TUTORIAL_FIRST_OP_COMPLETED] = true,
    [POS_Constants.TUTORIAL_SIGINT_L3]         = true,
    [POS_Constants.TUTORIAL_FIRST_CAMERA]      = true,
    [POS_Constants.TUTORIAL_FIRST_SATELLITE]   = true,
}

---------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------

local initialised = false

--- Register all milestones with PhobosLib_Milestone.
--- Called on OnGameStart. Safe to call multiple times (idempotent).
function POS_TutorialService.init()
    if initialised then return end
    initialised = true

    for _, ms in ipairs(MILESTONES) do
        PhobosLib.registerMilestone(
            POS_Constants.TUTORIAL_MOD_ID,
            ms.id,
            { labelKey = ms.labelKey, group = ms.group }
        )
    end

    -- Listen for awarded milestones
    pcall(function()
        LuaEventManager.AddEvent("PhobosLib_MilestoneAwarded")
    end)
    Events.PhobosLib_MilestoneAwarded.Add(POS_TutorialService.onMilestoneAwarded)

    -- Legacy migration: if old recorder tutorial flag exists, auto-award
    POS_TutorialService.migrateLegacy()

    PhobosLib.debug("POS", "[Tutorial]", "Initialised with "
        .. #MILESTONES .. " milestones")
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Check if the tutorial system is enabled.
---@return boolean
function POS_TutorialService.isEnabled()
    return POS_Sandbox and POS_Sandbox.getEnableTutorialHints
        and POS_Sandbox.getEnableTutorialHints()
end

--- Try to award a tutorial milestone. Safe to call from hot paths.
--- Returns immediately if tutorials are disabled or milestone already earned.
---@param player IsoPlayer
---@param milestoneId string One of POS_Constants.TUTORIAL_*
---@return boolean newlyAwarded
function POS_TutorialService.tryAward(player, milestoneId)
    if not POS_TutorialService.isEnabled() then return false end
    if not player or not milestoneId then return false end
    return PhobosLib.awardMilestone(player, POS_Constants.TUTORIAL_MOD_ID, milestoneId)
end

--- Get tutorial progress for a player.
---@param player IsoPlayer
---@return number completed, number total
function POS_TutorialService.getProgress(player)
    return PhobosLib.countMilestones(player, POS_Constants.TUTORIAL_MOD_ID)
end

---------------------------------------------------------------
-- Milestone Awarded Event Handler
---------------------------------------------------------------

--- Dispatch toast and/or queue popup flag when a POS milestone is awarded.
--- Listens to triggerEvent("PhobosLib_MilestoneAwarded").
---@param player IsoPlayer
---@param modId string
---@param milestoneId string
function POS_TutorialService.onMilestoneAwarded(player, modId, milestoneId)
    if modId ~= POS_Constants.TUTORIAL_MOD_ID then return end
    if not player then return end

    -- Find the milestone definition for the toast label
    local labelKey
    for _, ms in ipairs(MILESTONES) do
        if ms.id == milestoneId then
            labelKey = ms.labelKey
            break
        end
    end

    -- Always send a toast for immediate feedback
    if labelKey then
        PhobosLib.notifyOrSay(player, {
            channel = POS_Constants.PN_CHANNEL_ID,
            message = PhobosLib.safeGetText(labelKey),
            priority = "normal",
            colour = POS_Constants.TUTORIAL_TOAST_COLOUR,
            tag = POS_Constants.TUTORIAL_TOAST_TAG,
        })
    end

    -- For major milestones, set popup-ready flag for next game start
    if POPUP_MILESTONES[milestoneId] then
        local modData = player:getModData()
        if modData then
            modData[POS_Constants.TUTORIAL_POPUP_READY_PREFIX .. milestoneId] = true
            pcall(function()
                player:transmitModData()
            end)
        end
    end

    PhobosLib.debug("POS", "[Tutorial]",
        "Milestone awarded: " .. milestoneId)
end

---------------------------------------------------------------
-- SIGINT Level Change Detection
---------------------------------------------------------------

--- Check if a SIGINT level change crosses tutorial thresholds.
--- Call this from POS_SIGINTSkill.addXP() with before/after levels.
---@param player IsoPlayer
---@param levelBefore number
---@param levelAfter number
function POS_TutorialService.checkSIGINTLevelUp(player, levelBefore, levelAfter)
    if not player or not levelBefore or not levelAfter then return end
    if levelAfter <= levelBefore then return end

    if levelBefore < POS_Constants.TUTORIAL_SIGINT_THRESHOLD_L3
        and levelAfter >= POS_Constants.TUTORIAL_SIGINT_THRESHOLD_L3 then
        POS_TutorialService.tryAward(player, POS_Constants.TUTORIAL_SIGINT_L3)
    end
    if levelBefore < POS_Constants.TUTORIAL_SIGINT_THRESHOLD_L6
        and levelAfter >= POS_Constants.TUTORIAL_SIGINT_THRESHOLD_L6 then
        POS_TutorialService.tryAward(player, POS_Constants.TUTORIAL_SIGINT_L6)
    end
    if levelBefore < POS_Constants.TUTORIAL_SIGINT_THRESHOLD_L9
        and levelAfter >= POS_Constants.TUTORIAL_SIGINT_THRESHOLD_L9 then
        POS_TutorialService.tryAward(player, POS_Constants.TUTORIAL_SIGINT_L9)
    end
end

---------------------------------------------------------------
-- Legacy Migration
---------------------------------------------------------------

--- Migrate old one-shot tutorial flags to the milestone system.
function POS_TutorialService.migrateLegacy()
    local player = pcall(getSpecificPlayer, 0) and getSpecificPlayer(0) or nil
    if not player then return end

    local modData = player:getModData()
    if not modData then return end

    -- Migrate old recorder tutorial flag
    if modData[POS_Constants.MD_RECORDER_TUTORIAL_SHOWN_LEGACY] then
        PhobosLib.awardMilestone(player,
            POS_Constants.TUTORIAL_MOD_ID,
            POS_Constants.TUTORIAL_FIRST_DATA_RECORDER)
        -- Don't remove the old key — harmless and preserves backward compat
    end
end

---------------------------------------------------------------
-- Hook
---------------------------------------------------------------

Events.OnGameStart.Add(POS_TutorialService.init)
