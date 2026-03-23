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
-- POS_Popups.lua
-- Welcome guide popup for POSnet.
---------------------------------------------------------------

require "PhobosLib"
require "POS_TerminalWidgets"

--- Default guide popup window width.
local GUIDE_POPUP_WIDTH = 620

--- Default guide popup window height.
local GUIDE_POPUP_HEIGHT = 500

-- Defer registration to OnGameStart so PhobosLib_Popup.lua is loaded
local function _registerPopups()
    if not PhobosLib.registerGuidePopup then return end
    PhobosLib.registerGuidePopup("POS", {
    title = POS_TerminalWidgets.safeGetText("UI_POS_GuideTitle"),
    width = GUIDE_POPUP_WIDTH,
    height = GUIDE_POPUP_HEIGHT,
    buildContent = function()
        local lines = {}
        table.insert(lines, " <RGB:0.3,1.0,0.3> " .. POS_TerminalWidgets.safeGetText("UI_POS_GuideTitle"))
        table.insert(lines, " ")
        table.insert(lines, " <RGB:0.9,0.9,0.9> " .. POS_TerminalWidgets.safeGetText("UI_POS_GuideIntro"))
        table.insert(lines, " ")
        table.insert(lines, " <RGB:0.6,1.0,0.6> " .. POS_TerminalWidgets.safeGetText("UI_POS_GuideStep1"))
        table.insert(lines, " <RGB:0.6,1.0,0.6> " .. POS_TerminalWidgets.safeGetText("UI_POS_GuideStep2"))
        table.insert(lines, " <RGB:0.6,1.0,0.6> " .. POS_TerminalWidgets.safeGetText("UI_POS_GuideStep3"))
        table.insert(lines, " <RGB:0.6,1.0,0.6> " .. POS_TerminalWidgets.safeGetText("UI_POS_GuideStep4"))
        table.insert(lines, " ")
        table.insert(lines, " <RGB:0.7,0.7,0.7> " .. POS_TerminalWidgets.safeGetText("UI_POS_GuideNote"))
        return table.concat(lines, " <LINE> ")
    end,
    backgroundColor = { r = 0.05, g = 0.08, b = 0.05, a = 0.95 },
    borderColor = { r = 0.15, g = 0.40, b = 0.15, a = 1.0 },
    })
end

Events.OnGameStart.Add(_registerPopups)
