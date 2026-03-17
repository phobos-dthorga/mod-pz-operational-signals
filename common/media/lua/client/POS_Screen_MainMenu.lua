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
-- Displays 5 options: BBS, IRC, Journal, Profile, Stockmarket.
---------------------------------------------------------------

require "PhobosLib"
require "POS_ScreenManager"

local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

--- Terminal colour references (must match POS_TerminalUI).
local TERM = {
    text   = { r = 0.20, g = 0.90, b = 0.20 },
    dim    = { r = 0.12, g = 0.50, b = 0.12 },
    header = { r = 0.30, g = 1.00, b = 0.30 },
    warn   = { r = 0.90, g = 0.80, b = 0.10 },
}

--- Menu options with target screen IDs.
local MENU_OPTIONS = {
    { key = "UI_POS_MainMenuOption_BBS",     screen = "BBS_LIST",                 enabled = true },
    { key = "UI_POS_MainMenuOption_IRC",     screen = "IRC_LIST",                 enabled = false },
    { key = "UI_POS_MainMenuOption_Journal", screen = "JOURNAL",                  enabled = false },
    { key = "UI_POS_MainMenuOption_Profile", screen = "PROFILE",                  enabled = false },
    { key = "UI_POS_MainMenuOption_Stock",   screen = "STOCKMARKET_PLACEHOLDER",  enabled = true },
    { key = "UI_POS_MainMenuOption_Shutdown", screen = nil,                       enabled = true, action = "shutdown" },
}

---------------------------------------------------------------

local screen = {}
screen.id = "MAIN_MENU"

function screen.rebuildLines(terminal, _params)
    local lines = {}
    local hitZones = {}

    -- Header
    table.insert(lines, { text = safeGetText("UI_POS_MainMenuHeader"), colour = TERM.header })
    table.insert(lines, { text = string.rep("=", 40), colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })

    -- Connection info
    table.insert(lines, {
        text = "> " .. safeGetText("UI_POS_TerminalConnected", terminal.radioName or "Radio"),
        colour = TERM.text
    })
    local freqMHz = string.format("%.1f", (terminal.frequency or 91500) / 1000)
    table.insert(lines, {
        text = "> " .. safeGetText("UI_POS_TerminalFrequency", freqMHz),
        colour = TERM.text
    })
    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })

    -- Menu options
    for i, opt in ipairs(MENU_OPTIONS) do
        local label = safeGetText(opt.key)
        local colour = opt.enabled and TERM.text or TERM.dim
        local prefix = opt.enabled and ("[" .. i .. "] ") or ("    ")
        local suffix = opt.enabled and "" or "  (coming soon)"

        local lineIdx = #lines + 1
        table.insert(lines, { text = prefix .. label .. suffix, colour = colour })

        if opt.enabled then
            local actionId = opt.action or "navigate"
            table.insert(hitZones, {
                lineIndex = lineIdx,
                actionId  = actionId,
                data      = { screen = opt.screen },
            })
        end
    end

    -- Footer
    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, {
        text = safeGetText("UI_POS_MainMenuPrompt"),
        colour = TERM.dim
    })

    return lines, hitZones
end

function screen.onAction(terminal, actionId, data)
    if actionId == "navigate" and data and data.screen then
        POS_ScreenManager.navigateTo(data.screen)
    elseif actionId == "shutdown" then
        POS_TerminalUI.closeTerminal()
    end
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
