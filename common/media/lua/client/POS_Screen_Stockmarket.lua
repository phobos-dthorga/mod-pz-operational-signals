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
-- POS_Screen_Stockmarket.lua
-- Placeholder "COMING SOON" screen for the Stockmarket feature.
-- Widget-based: uses ISButton/ISLabel children in contentPanel.
---------------------------------------------------------------

require "PhobosLib"
require "POS_ScreenManager"
require "POS_TerminalWidgets"

local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

local C = POS_TerminalWidgets.COLOURS

---------------------------------------------------------------

local screen = {}
screen.id = "STOCKMARKET_PLACEHOLDER"

local widgets = {}

function screen.create(contentPanel, _params, _terminal)
    widgets = {}
    local W = POS_TerminalWidgets
    local pw = contentPanel:getWidth()
    local y = 0
    local lineH = 20
    local btnH = 28
    local btnW = pw - 10
    local btnX = 5

    -- Header
    widgets.header = W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_Stock_Header"), C.textBright)
    y = y + lineH

    widgets.sep1 = W.createSeparator(contentPanel, 0, y, 40)
    y = y + lineH * 2

    -- Coming soon message
    widgets.comingSoon = W.createLabel(contentPanel, 20, y,
        safeGetText("UI_POS_Stock_ComingSoon"), C.warn)
    y = y + lineH * 2

    widgets.message = W.createLabel(contentPanel, 8, y,
        safeGetText("UI_POS_Stock_Message"), C.dim)
    y = y + lineH * 3

    -- Footer
    widgets.sep2 = W.createSeparator(contentPanel, 0, y, 40, "-")
    y = y + lineH + 4

    widgets.backBtn = W.createButton(contentPanel, btnX, y, btnW, btnH,
        "[0] " .. safeGetText("UI_POS_BackPrompt"), nil,
        function() POS_ScreenManager.goBack() end)
end

function screen.destroy()
    if POS_TerminalUI.instance and POS_TerminalUI.instance.contentPanel then
        POS_TerminalWidgets.clearPanel(POS_TerminalUI.instance.contentPanel)
    end
    widgets = {}
end

function screen.refresh(_params)
    -- Static screen — no dynamic data
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
