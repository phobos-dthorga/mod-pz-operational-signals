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
-- POS_Screen_MainMenu.lua
-- Main menu screen for the POSnet terminal BBS.
-- Widget-based: uses ISButton/ISLabel children in contentPanel.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_Reputation"
require "POS_RadioPower"

local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

local C = POS_TerminalWidgets.COLOURS

--- Menu options with target screen IDs.
local MENU_OPTIONS = {
    { key = "UI_POS_MainMenuOption_BBS",        screen = POS_Constants.SCREEN_BBS_HUB,    enabled = true },
    { key = "UI_POS_MainMenuOption_IRC",        screen = "IRC_LIST",                     enabled = false },
    { key = "UI_POS_MainMenuOption_Journal",    screen = "JOURNAL",                      enabled = false },
    { key = "UI_POS_MainMenuOption_Profile",    screen = "PROFILE",                      enabled = false },
    { key = "UI_POS_MainMenuOption_Stock",      screen = POS_Constants.SCREEN_STOCKMARKET, enabled = true },
    { key = "UI_POS_MainMenuOption_Shutdown",   screen = nil,                       enabled = true, action = "shutdown" },
}

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_MAIN_MENU

function screen.create(contentPanel, _params, terminal)
    local W = POS_TerminalWidgets
    local pw = contentPanel:getWidth()
    local y = 0
    local lineH = 20
    local btnH = 28
    local btnW = pw - 10
    local btnX = 5

    -- Header
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_MainMenuHeader"), C.textBright)
    y = y + lineH

    W.createSeparator(contentPanel, 0, y, 40)
    y = y + lineH

    -- Connection info
    local radioName = terminal and terminal.radioName or "Radio"
    local freq = terminal and terminal.frequency or 91500
    local freqMHz = string.format("%.1f", freq / 1000)

    W.createLabel(contentPanel, 0, y,
        "> " .. safeGetText("UI_POS_TerminalConnected", radioName), C.text)
    y = y + lineH

    W.createLabel(contentPanel, 0, y,
        "> " .. safeGetText("UI_POS_TerminalFrequency", freqMHz), C.text)
    y = y + lineH

    -- Band display
    local band = terminal and terminal.band or "operations"
    local bandKey = band == "tactical" and "UI_POS_Band_Tactical" or "UI_POS_Band_Operations"
    W.createLabel(contentPanel, 0, y,
        "> " .. safeGetText("UI_POS_TerminalBand", safeGetText(bandKey)), C.text)
    y = y + lineH

    -- Signal strength display
    local signal = terminal and terminal.signalStrength or 1.0
    if POS_Sandbox.isSignalStrengthEnabled() then
        local signalPct = string.format("%.0f%%", signal * 100)
        local qualityKey = POS_RadioPower.getQualityKey(signal)
        local signalColour = signal >= 0.8 and C.textBright
            or signal >= 0.5 and C.text
            or signal >= 0.25 and C.warn
            or C.error
        W.createLabel(contentPanel, 0, y,
            "> " .. safeGetText("UI_POS_TerminalSignal", signalPct, safeGetText(qualityKey)),
            signalColour)
        y = y + lineH
    end

    -- Reputation display
    local player = getSpecificPlayer(0)
    local rep = POS_Reputation.get(player)
    local tierDef = POS_Reputation.getPlayerTierDef(player)
    W.createLabel(contentPanel, 0, y,
        "> " .. safeGetText("UI_POS_Ops_Reputation") .. ": " .. rep
        .. " [" .. safeGetText(tierDef and tierDef.key or "UI_POS_Rep_Tier_Untrusted") .. "]",
        C.dim)
    y = y + lineH + 4

    W.createSeparator(contentPanel, 0, y, 40, "-")
    y = y + lineH + 4

    -- Menu option buttons
    for i, opt in ipairs(MENU_OPTIONS) do
        local label = "[" .. i .. "] " .. safeGetText(opt.key)

        if opt.enabled then
            if opt.action == "shutdown" then
                W.createButton(contentPanel, btnX, y, btnW, btnH, label, nil,
                    function() POS_TerminalUI.closeTerminal() end)
            else
                local targetScreen = opt.screen
                W.createButton(contentPanel, btnX, y, btnW, btnH, label, nil,
                    function() POS_ScreenManager.navigateTo(targetScreen) end)
            end
        else
            local disabledLabel = "    " .. safeGetText(opt.key) .. "  (coming soon)"
            W.createDisabledButton(contentPanel, btnX, y, btnW, btnH, disabledLabel)
        end

        y = y + btnH + 4
    end

    -- Footer
    y = y + 4
    W.createSeparator(contentPanel, 0, y, 40, "-")
    y = y + lineH

    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_MainMenuPrompt"), C.dim)
end

function screen.destroy()
    if POS_TerminalUI.instance and POS_TerminalUI.instance.contentPanel then
        POS_TerminalWidgets.clearPanel(POS_TerminalUI.instance.contentPanel)
    end
end

function screen.refresh(_params)
    -- Static screen — no dynamic data to refresh
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
