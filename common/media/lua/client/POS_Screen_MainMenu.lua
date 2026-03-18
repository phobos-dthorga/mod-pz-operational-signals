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
require "POS_API"
require "POS_MenuBuilder"

local C = POS_TerminalWidgets.COLOURS

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_MAIN_MENU
screen.menuPath = {}  -- root screen, no parent menu
screen.titleKey = "UI_POS_MainMenuHeader"
screen.sortOrder = 0
screen.isRoot = true

function screen.create(contentPanel, _params, terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_MainMenuHeader")

    -- Connection info
    local radioName = terminal and terminal.radioName or "Radio"
    local freq = terminal and terminal.frequency or 91500
    local freqMHz = string.format("%.1f", freq / 1000)

    W.createLabel(ctx.panel, 0, ctx.y,
        "> " .. W.safeGetText("UI_POS_TerminalConnected", radioName), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 0, ctx.y,
        "> " .. W.safeGetText("UI_POS_TerminalFrequency", freqMHz), C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Band display
    local band = terminal and terminal.band or "operations"
    local bandKey = band == "tactical" and "UI_POS_Band_Tactical" or "UI_POS_Band_Operations"
    W.createLabel(ctx.panel, 0, ctx.y,
        "> " .. W.safeGetText("UI_POS_TerminalBand", W.safeGetText(bandKey)), C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Signal strength display
    local signal = terminal and terminal.signalStrength or 1.0
    if POS_Sandbox.isSignalStrengthEnabled() then
        local signalPct = string.format("%.0f%%", signal * 100)
        local qualityKey = POS_RadioPower.getQualityKey(signal)
        local signalColour = signal >= 0.8 and C.textBright
            or signal >= 0.5 and C.text
            or signal >= 0.25 and C.warn
            or C.error
        W.createLabel(ctx.panel, 0, ctx.y,
            "> " .. W.safeGetText("UI_POS_TerminalSignal", signalPct, W.safeGetText(qualityKey)),
            signalColour)
        ctx.y = ctx.y + ctx.lineH
    end

    -- Reputation display
    local player = getSpecificPlayer(0)
    local rep = POS_Reputation.get(player)
    local tierDef = POS_Reputation.getPlayerTierDef(player)
    W.createLabel(ctx.panel, 0, ctx.y,
        "> " .. W.safeGetText("UI_POS_Ops_Reputation") .. ": " .. rep
        .. " [" .. W.safeGetText(tierDef and tierDef.key or "UI_POS_Rep_Tier_Untrusted") .. "]",
        C.dim)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH + 4

    -- Menu option buttons (built dynamically from registry)
    local menuCtx = {
        band = band,
        signal = signal,
        terminal = terminal,
    }
    local entries = POS_MenuBuilder.buildMenu({"pos.main"}, player, menuCtx)
    for i, entry in ipairs(entries) do
        local label = "[" .. i .. "] " .. W.safeGetText(entry.def.titleKey)

        if entry.enabled then
            local targetScreen = entry.def.id
            W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH, label, nil,
                function() POS_ScreenManager.navigateTo(targetScreen) end)
        else
            local disabledLabel = "    " .. W.safeGetText(entry.def.titleKey)
            if entry.reason then
                disabledLabel = disabledLabel .. "  (" .. W.safeGetText(entry.reason) .. ")"
            else
                disabledLabel = disabledLabel .. "  (coming soon)"
            end
            W.createDisabledButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH, disabledLabel)
        end

        ctx.y = ctx.y + ctx.btnH + 4
    end

    -- Shutdown button (always present, not registry-driven)
    local shutIdx = #entries + 1
    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        "[" .. shutIdx .. "] " .. W.safeGetText("UI_POS_MainMenuOption_Shutdown"), nil,
        function() POS_TerminalUI.closeTerminal() end)
    ctx.y = ctx.y + ctx.btnH + 4

    -- Footer
    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 0, ctx.y,
        W.safeGetText("UI_POS_MainMenuPrompt"), C.dim)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(_params)
    -- Static screen — no dynamic data to refresh
end

---------------------------------------------------------------

POS_API.registerCategory({
    id = "pos.main",
    parent = nil,
    titleKey = "UI_POS_MainMenuHeader",
    sortOrder = 0,
})

POS_API.registerScreen(screen)
