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
-- POS_ContextPanel.lua
-- Context-sensitive detail inspector for the POSnet terminal.
-- Renders screen-specific data (mission info, negotiation
-- stats, investment details) from getContextData() callbacks.
---------------------------------------------------------------

require "PhobosLib"
require "POS_TerminalWidgets"
require "POS_ScreenManager"

POS_ContextPanel = {}

--- Render the context panel with data from the current screen.
---@param contextPanel any ISPanel
---@param terminal any POS_TerminalUI instance
function POS_ContextPanel.render(contextPanel, terminal)
    POS_TerminalWidgets.clearPanel(contextPanel)

    local screen = POS_ScreenManager.screens[POS_ScreenManager.currentScreen]
    if not screen or not screen.getContextData then return end

    local data = nil
    local ok, result = pcall(screen.getContextData, POS_ScreenManager.currentParams)
    if ok then data = result end
    if not data or #data == 0 then return end

    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local lineH = getTextManager():getFontHeight(UIFont.Code) + 2
    local y = 0
    local pw = contextPanel:getWidth()

    for _, item in ipairs(data) do
        if item.type == "header" then
            W.createLabel(contextPanel, 4, y,
                PhobosLib.safeGetText(item.text), C.textBright)
            y = y + lineH
        elseif item.type == "kv" then
            local colour = item.colour and C[item.colour] or C.text
            local keyText = PhobosLib.safeGetText(item.key)
            W.createLabel(contextPanel, 4, y,
                keyText .. ": " .. tostring(item.value), colour)
            y = y + lineH
        elseif item.type == "separator" then
            local charCount = math.floor((pw - 8) / 8)
            W.createSeparator(contextPanel, 4, y, charCount, "-")
            y = y + lineH
        elseif item.type == "bar" then
            local barPct = tonumber(item.value) or 0
            local bar = POS_NavPanel.buildSignalBar(barPct)
            local colour = item.colour and C[item.colour] or C.text
            W.createLabel(contextPanel, 4, y,
                PhobosLib.safeGetText(item.key) .. ": " .. bar .. " " .. barPct .. "%",
                colour)
            y = y + lineH
        end
    end
end
