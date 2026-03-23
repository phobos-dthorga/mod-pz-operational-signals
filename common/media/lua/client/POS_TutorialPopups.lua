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
-- POS_TutorialPopups.lua
-- Registers Notice Popups for major tutorial milestones.
-- Each popup fires once per character at the milestone gate.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_TutorialService"
require "POS_TerminalWidgets"

---------------------------------------------------------------
-- Shared popup dimensions and theme
---------------------------------------------------------------

local POPUP_WIDTH  = 620
local POPUP_HEIGHT = 500

local BG_COLOUR     = { r = 0.05, g = 0.08, b = 0.05, a = 0.95 }
local BORDER_COLOUR = { r = 0.15, g = 0.40, b = 0.15, a = 1.0 }

---------------------------------------------------------------
-- Helper: build shouldShow gate for a milestone-driven popup
---------------------------------------------------------------

local function makeShouldShow(milestoneId)
    return function(player)
        if not POS_TutorialService.isEnabled() then return false end
        if not player then return false end

        local modData = player:getModData()
        if not modData then return false end

        -- Popup ready flag must be set (awarded during play or previous session)
        local readyKey = POS_Constants.TUTORIAL_POPUP_READY_PREFIX .. milestoneId
        if not modData[readyKey] then
            -- Also check if milestone was awarded (covers award on previous session)
            if not PhobosLib.hasMilestone(player, POS_Constants.TUTORIAL_MOD_ID, milestoneId) then
                return false
            end
        end

        -- Popup not yet shown
        local shownKey = POS_Constants.TUTORIAL_POPUP_SHOWN_PREFIX .. milestoneId
        if modData[shownKey] then return false end

        return true
    end
end

---------------------------------------------------------------
-- Helper: build content from translation key lines
---------------------------------------------------------------

local function buildPopupContent(lineKeys)
    return function()
        local lines = {}
        for _, entry in ipairs(lineKeys) do
            local rgb = entry.rgb or "0.9,0.9,0.9"
            local text = POS_TerminalWidgets.safeGetText(entry.key)
            table.insert(lines, " <RGB:" .. rgb .. "> " .. text)
        end
        return table.concat(lines, " <LINE> ")
    end
end

---------------------------------------------------------------
-- Deferred registration — PhobosLib_Popup.lua (client) may not
-- be loaded yet when this file runs at load time.
---------------------------------------------------------------

local function _registerTutorialPopups()
    if not PhobosLib.registerNoticePopup then return end

---------------------------------------------------------------
-- Popup 1: First Connection
---------------------------------------------------------------

PhobosLib.registerNoticePopup("POS", "tutorial_first_connection", {
    title = POS_TerminalWidgets.safeGetText("UI_POS_Tutorial_Popup_FirstConnection_Title"),
    width = POPUP_WIDTH,
    height = POPUP_HEIGHT,
    shouldShow = makeShouldShow(POS_Constants.TUTORIAL_FIRST_CONNECTION),
    buildContent = buildPopupContent({
        { key = "UI_POS_Tutorial_Popup_FirstConnection_Title", rgb = "0.3,1.0,0.3" },
        { key = "UI_POS_Tutorial_Popup_FirstConnection_Line1" },
        { key = "UI_POS_Tutorial_Popup_FirstConnection_Line2", rgb = "0.6,1.0,0.6" },
        { key = "UI_POS_Tutorial_Popup_FirstConnection_Line3", rgb = "0.6,1.0,0.6" },
        { key = "UI_POS_Tutorial_Popup_FirstConnection_Line4", rgb = "0.7,0.7,0.7" },
    }),
    backgroundColor = BG_COLOUR,
    borderColor = BORDER_COLOUR,
    onDismiss = function(player)
        if not player then return end
        local modData = player:getModData()
        if modData then
            modData[POS_Constants.TUTORIAL_POPUP_SHOWN_PREFIX
                .. POS_Constants.TUTORIAL_FIRST_CONNECTION] = true
            PhobosLib.safecall(function() player:transmitModData() end)
        end
    end,
})

---------------------------------------------------------------
-- Popup 2: First Operation Completed
---------------------------------------------------------------

PhobosLib.registerNoticePopup("POS", "tutorial_first_op_completed", {
    title = POS_TerminalWidgets.safeGetText("UI_POS_Tutorial_Popup_FirstOpCompleted_Title"),
    width = POPUP_WIDTH,
    height = POPUP_HEIGHT,
    shouldShow = makeShouldShow(POS_Constants.TUTORIAL_FIRST_OP_COMPLETED),
    buildContent = buildPopupContent({
        { key = "UI_POS_Tutorial_Popup_FirstOpCompleted_Title", rgb = "0.3,1.0,0.3" },
        { key = "UI_POS_Tutorial_Popup_FirstOpCompleted_Line1" },
        { key = "UI_POS_Tutorial_Popup_FirstOpCompleted_Line2", rgb = "0.6,1.0,0.6" },
        { key = "UI_POS_Tutorial_Popup_FirstOpCompleted_Line3", rgb = "0.6,1.0,0.6" },
        { key = "UI_POS_Tutorial_Popup_FirstOpCompleted_Line4", rgb = "0.7,0.7,0.7" },
    }),
    backgroundColor = BG_COLOUR,
    borderColor = BORDER_COLOUR,
    onDismiss = function(player)
        if not player then return end
        local modData = player:getModData()
        if modData then
            modData[POS_Constants.TUTORIAL_POPUP_SHOWN_PREFIX
                .. POS_Constants.TUTORIAL_FIRST_OP_COMPLETED] = true
            PhobosLib.safecall(function() player:transmitModData() end)
        end
    end,
})

---------------------------------------------------------------
-- Popup 3: SIGINT Level 3 — Pattern Seeker
---------------------------------------------------------------

PhobosLib.registerNoticePopup("POS", "tutorial_sigint_l3", {
    title = POS_TerminalWidgets.safeGetText("UI_POS_Tutorial_Popup_SigintL3_Title"),
    width = POPUP_WIDTH,
    height = POPUP_HEIGHT,
    shouldShow = makeShouldShow(POS_Constants.TUTORIAL_SIGINT_L3),
    buildContent = buildPopupContent({
        { key = "UI_POS_Tutorial_Popup_SigintL3_Title", rgb = "0.3,1.0,0.3" },
        { key = "UI_POS_Tutorial_Popup_SigintL3_Line1" },
        { key = "UI_POS_Tutorial_Popup_SigintL3_Line2", rgb = "0.6,1.0,0.6" },
        { key = "UI_POS_Tutorial_Popup_SigintL3_Line3", rgb = "0.6,1.0,0.6" },
        { key = "UI_POS_Tutorial_Popup_SigintL3_Line4", rgb = "0.7,0.7,0.7" },
    }),
    backgroundColor = BG_COLOUR,
    borderColor = BORDER_COLOUR,
    onDismiss = function(player)
        if not player then return end
        local modData = player:getModData()
        if modData then
            modData[POS_Constants.TUTORIAL_POPUP_SHOWN_PREFIX
                .. POS_Constants.TUTORIAL_SIGINT_L3] = true
            PhobosLib.safecall(function() player:transmitModData() end)
        end
    end,
})

---------------------------------------------------------------
-- Popup 4: First Camera Compile
---------------------------------------------------------------

PhobosLib.registerNoticePopup("POS", "tutorial_first_camera", {
    title = POS_TerminalWidgets.safeGetText("UI_POS_Tutorial_Popup_FirstCamera_Title"),
    width = POPUP_WIDTH,
    height = POPUP_HEIGHT,
    shouldShow = makeShouldShow(POS_Constants.TUTORIAL_FIRST_CAMERA),
    buildContent = buildPopupContent({
        { key = "UI_POS_Tutorial_Popup_FirstCamera_Title", rgb = "0.3,1.0,0.3" },
        { key = "UI_POS_Tutorial_Popup_FirstCamera_Line1" },
        { key = "UI_POS_Tutorial_Popup_FirstCamera_Line2", rgb = "0.6,1.0,0.6" },
        { key = "UI_POS_Tutorial_Popup_FirstCamera_Line3", rgb = "0.6,1.0,0.6" },
        { key = "UI_POS_Tutorial_Popup_FirstCamera_Line4", rgb = "0.7,0.7,0.7" },
    }),
    backgroundColor = BG_COLOUR,
    borderColor = BORDER_COLOUR,
    onDismiss = function(player)
        if not player then return end
        local modData = player:getModData()
        if modData then
            modData[POS_Constants.TUTORIAL_POPUP_SHOWN_PREFIX
                .. POS_Constants.TUTORIAL_FIRST_CAMERA] = true
            PhobosLib.safecall(function() player:transmitModData() end)
        end
    end,
})

---------------------------------------------------------------
-- Popup 5: First Satellite Broadcast
---------------------------------------------------------------

PhobosLib.registerNoticePopup("POS", "tutorial_first_satellite", {
    title = POS_TerminalWidgets.safeGetText("UI_POS_Tutorial_Popup_FirstSatellite_Title"),
    width = POPUP_WIDTH,
    height = POPUP_HEIGHT,
    shouldShow = makeShouldShow(POS_Constants.TUTORIAL_FIRST_SATELLITE),
    buildContent = buildPopupContent({
        { key = "UI_POS_Tutorial_Popup_FirstSatellite_Title", rgb = "0.3,1.0,0.3" },
        { key = "UI_POS_Tutorial_Popup_FirstSatellite_Line1" },
        { key = "UI_POS_Tutorial_Popup_FirstSatellite_Line2", rgb = "0.6,1.0,0.6" },
        { key = "UI_POS_Tutorial_Popup_FirstSatellite_Line3", rgb = "0.6,1.0,0.6" },
        { key = "UI_POS_Tutorial_Popup_FirstSatellite_Line4", rgb = "0.7,0.7,0.7" },
    }),
    backgroundColor = BG_COLOUR,
    borderColor = BORDER_COLOUR,
    onDismiss = function(player)
        if not player then return end
        local modData = player:getModData()
        if modData then
            modData[POS_Constants.TUTORIAL_POPUP_SHOWN_PREFIX
                .. POS_Constants.TUTORIAL_FIRST_SATELLITE] = true
            PhobosLib.safecall(function() player:transmitModData() end)
        end
    end,
})

end -- _registerTutorialPopups

Events.OnGameStart.Add(_registerTutorialPopups)
