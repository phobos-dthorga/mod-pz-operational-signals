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
-- POS_NavPanel.lua
-- Persistent navigation sidebar for the POSnet terminal.
-- Displays signal strength indicator, band info, and menu
-- items built from the screen registry.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_TerminalWidgets"
require "POS_ScreenManager"
require "POS_MenuBuilder"

POS_NavPanel = {}

--- Number of segments in the signal strength bar.
local SIGNAL_BAR_LENGTH = 10

--- Build a text-based signal strength bar.
---@param pct number Signal percentage (0-100)
---@return string bar Visual bar representation
function POS_NavPanel.buildSignalBar(pct)
    local filled = math.floor(pct / SIGNAL_BAR_LENGTH)
    local empty = SIGNAL_BAR_LENGTH - filled
    return string.rep("#", filled) .. string.rep(".", empty)
end

--- Render the navigation sidebar contents.
---@param navPanel any ISPanel
---@param terminal any POS_TerminalUI instance
function POS_NavPanel.render(navPanel, terminal)
    POS_TerminalWidgets.clearPanel(navPanel)

    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local lineH = getTextManager():getFontHeight(UIFont.Code) + 2
    local y = 0
    local pw = navPanel:getWidth()

    -- Signal indicator
    W.createLabel(navPanel, 4, y, PhobosLib.safeGetText("UI_POS_Nav_Signal"), C.dim)
    y = y + lineH
    local signalPct = math.floor((terminal.signalStrength or 0) * 100)
    local signalBar = POS_NavPanel.buildSignalBar(signalPct)
    local signalColour = signalPct >= 80 and C.success
        or signalPct >= 50 and C.text
        or signalPct >= 25 and C.warn
        or C.error
    W.createLabel(navPanel, 4, y, signalBar .. " " .. signalPct .. "%", signalColour)
    y = y + lineH

    -- Band indicator
    local band = terminal.band or ""
    if band ~= "" then
        W.createLabel(navPanel, 4, y, PhobosLib.safeGetText("UI_POS_Nav_Band") .. ": " .. band, C.dim)
        y = y + lineH
    end
    y = y + lineH

    -- Separator
    W.createSeparator(navPanel, 4, y, math.floor((pw - 8) / 8), "-")
    y = y + lineH

    -- Menu items from registry
    local player = getPlayer()
    local ctx = {
        connected = terminal.connected or false,
        band = band,
        signal = terminal.signalStrength or 0,
    }
    local entries = POS_MenuBuilder.buildMenu({"pos.main"}, player, ctx)
    local currentScreen = POS_ScreenManager.currentScreen or ""
    local btnW = pw - 8
    local btnH = lineH + 4

    for _, entry in ipairs(entries) do
        local isCurrent = (currentScreen == entry.def.id)
            or (currentScreen:find("^" .. entry.def.id:gsub("%.", "%%.")) ~= nil)
        local label = PhobosLib.safeGetText(entry.def.titleKey)

        if isCurrent then
            label = "> " .. label
        else
            label = "  " .. label
        end

        if entry.enabled then
            local targetId = entry.def.id
            local colour = isCurrent and C.textBright or C.text
            local btn = W.createButton(navPanel, 4, y, btnW, btnH, label, nil,
                function() POS_ScreenManager.navigateTo(targetId) end)
            if isCurrent then
                btn.textColor = { r = colour.r, g = colour.g, b = colour.b, a = colour.a }
            end
        else
            W.createDisabledButton(navPanel, 4, y, btnW, btnH, label)
        end
        y = y + btnH + 2
    end
end
