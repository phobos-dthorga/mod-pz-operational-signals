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
-- POS_Screen_DataReset.lua
-- Terminal screen: developer tool to wipe all POSnet data.
-- Gated behind PZ -debug flag OR POS.EnableDebugLogging.
-- Two-step confirmation to prevent accidental use.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_DataResetService"
require "POS_SandboxIntegration"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_DATA_RESET
screen.menuPath = {"pos.main"}
screen.sortOrder = 99
screen.titleKey = "UI_POS_DataReset_Title"

--- Only show when debug mode is enabled (PZ -debug OR sandbox option).
screen.shouldShow = function()
    if isDebugEnabled() then return true end
    if POS_Sandbox and POS_Sandbox.isDebugLoggingEnabled then
        return POS_Sandbox.isDebugLoggingEnabled()
    end
    return false
end

---------------------------------------------------------------
-- Confirmation dialog
---------------------------------------------------------------

local function showConfirmationDialog(terminal)
    local player = getSpecificPlayer(0)
    if not player then return end

    local w = 420
    local h = 220
    local x = (getCore():getScreenWidth() - w) / 2
    local y = (getCore():getScreenHeight() - h) / 2

    local modal = ISPanel:new(x, y, w, h)
    modal:initialise()
    modal:instantiate()
    modal:setVisible(true)
    modal:setAlwaysOnTop(true)
    modal.backgroundColor = {r = 0.05, g = 0.05, b = 0.05, a = 0.95}
    modal.borderColor = {r = 1.0, g = 0.2, b = 0.2, a = 0.8}
    modal:setAnchorRight(false)
    modal:setAnchorBottom(false)

    -- Title
    local titleText = PhobosLib.safeGetText("UI_POS_DataReset_ConfirmTitle")
    local titleLabel = ISLabel:new(w / 2, 15, 24, titleText, 1.0, 0.2, 0.2, 1.0, UIFont.Medium, true)
    modal:addChild(titleLabel)

    -- Warning body
    local bodyText = PhobosLib.safeGetText("UI_POS_DataReset_ConfirmBody")
    local bodyLabel = ISLabel:new(20, 50, 18, bodyText, 1.0, 0.8, 0.2, 1.0, UIFont.Small, false)
    modal:addChild(bodyLabel)

    local line2Text = PhobosLib.safeGetText("UI_POS_DataReset_ConfirmBody2")
    local line2Label = ISLabel:new(20, 80, 18, line2Text, 1.0, 0.6, 0.6, 1.0, UIFont.Small, false)
    modal:addChild(line2Label)

    local line3Text = PhobosLib.safeGetText("UI_POS_DataReset_ConfirmBody3")
    local line3Label = ISLabel:new(20, 110, 18, line3Text, 0.7, 0.7, 0.7, 1.0, UIFont.Small, false)
    modal:addChild(line3Label)

    -- Cancel button
    local btnW = 120
    local btnH = 30
    local cancelBtn = ISButton:new(w / 2 - btnW - 15, h - btnH - 20, btnW, btnH,
        PhobosLib.safeGetText("UI_POS_DataReset_Cancel"), modal,
        function(self)
            self.parent:setVisible(false)
            self.parent:removeFromUIManager()
        end)
    cancelBtn:initialise()
    cancelBtn:instantiate()
    cancelBtn.backgroundColor = {r = 0.2, g = 0.2, b = 0.2, a = 0.9}
    cancelBtn.borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 1.0}
    modal:addChild(cancelBtn)

    -- Confirm button
    local confirmBtn = ISButton:new(w / 2 + 15, h - btnH - 20, btnW, btnH,
        PhobosLib.safeGetText("UI_POS_DataReset_Confirm"), modal,
        function(self)
            local p = getSpecificPlayer(0)
            local wc, pc = POS_DataResetService.resetAll(p)
            PhobosLib.debug("POS", "DataReset", "Reset complete: " .. tostring(wc) .. " world, " .. tostring(pc) .. " player keys")

            self.parent:setVisible(false)
            self.parent:removeFromUIManager()

            -- Navigate back to main menu after reset
            if terminal and terminal.navigateTo then
                terminal:navigateTo(POS_Constants.SCREEN_MAIN_MENU)
            end
        end)
    confirmBtn:initialise()
    confirmBtn:instantiate()
    confirmBtn.backgroundColor = {r = 0.5, g = 0.1, b = 0.1, a = 0.9}
    confirmBtn.borderColor = {r = 1.0, g = 0.2, b = 0.2, a = 1.0}
    modal:addChild(confirmBtn)

    modal:addToUIManager()
end

---------------------------------------------------------------
-- Screen render
---------------------------------------------------------------

screen.render = function(terminal, parentPanel)
    local COLOURS = POS_TerminalWidgets.COLOURS
    local y = 10
    local padX = 15

    -- Header
    local headerText = PhobosLib.safeGetText("UI_POS_DataReset_Title")
    POS_TerminalWidgets.addSectionHeader(parentPanel, headerText, padX, y, COLOURS.red)
    y = y + 30

    -- Warning text
    local warningText = PhobosLib.safeGetText("UI_POS_DataReset_Warning")
    local warningLabel = ISLabel:new(padX, y, 18, warningText, 1.0, 0.4, 0.4, 1.0, UIFont.Small, false)
    parentPanel:addChild(warningLabel)
    y = y + 25

    local descText = PhobosLib.safeGetText("UI_POS_DataReset_Desc")
    local descLabel = ISLabel:new(padX, y, 18, descText, 0.7, 0.7, 0.7, 1.0, UIFont.Small, false)
    parentPanel:addChild(descLabel)
    y = y + 25

    local desc2Text = PhobosLib.safeGetText("UI_POS_DataReset_Desc2")
    local desc2Label = ISLabel:new(padX, y, 18, desc2Text, 0.7, 0.7, 0.7, 1.0, UIFont.Small, false)
    parentPanel:addChild(desc2Label)
    y = y + 40

    -- Reset button
    local btnW = 250
    local btnH = 30
    local btnX = (parentPanel:getWidth() - btnW) / 2
    local resetBtn = ISButton:new(btnX, y, btnW, btnH,
        PhobosLib.safeGetText("UI_POS_DataReset_Button"), parentPanel,
        function()
            showConfirmationDialog(terminal)
        end)
    resetBtn:initialise()
    resetBtn:instantiate()
    resetBtn.backgroundColor = {r = 0.4, g = 0.1, b = 0.1, a = 0.9}
    resetBtn.borderColor = {r = 1.0, g = 0.2, b = 0.2, a = 1.0}
    parentPanel:addChild(resetBtn)

    y = y + btnH + 20

    -- Developer note
    local noteText = PhobosLib.safeGetText("UI_POS_DataReset_Note")
    local noteLabel = ISLabel:new(padX, y, 18, noteText, 0.5, 0.5, 0.5, 1.0, UIFont.Small, false)
    parentPanel:addChild(noteLabel)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
