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
-- Right sidebar: context-sensitive actions & insight
-- ("I act upon it"). Renders screen-specific data from
-- getContextData() callbacks.
--
-- Item types:
--   header    — section title (bright)
--   kv        — key: value pair
--   separator — dim horizontal line
--   bar       — text progress bar with percentage
--   action    — clickable themed button (context action)
--   progress  — labelled progress bar (background task)
--
-- See design-guidelines.md §9.3, §9.4.
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
    if not screen or not screen.getContextData then
        PhobosLib.debug("POS", "CtxPanel", "no getContextData for screen")
        return
    end

    local data = nil
    local ok, result = PhobosLib.safecall(screen.getContextData, POS_ScreenManager.currentParams)
    if ok then data = result end
    if not data or #data == 0 then
        PhobosLib.debug("POS", "CtxPanel",
            "empty data (ok=" .. tostring(ok) .. " #data=" .. tostring(data and #data or "nil") .. ")")
        return
    end
    PhobosLib.debug("POS", "CtxPanel",
        "rendering " .. tostring(#data) .. " items, panel visible=" .. tostring(contextPanel:isVisible())
        .. " w=" .. tostring(contextPanel:getWidth()))

    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local lineH = getTextManager():getFontHeight(UIFont.Code) + 2
    local y = 0
    local pw = contextPanel:getWidth()
    local charCount = math.floor((pw - 8) / 8)

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
            W.createSeparator(contextPanel, 4, y, charCount, "-")
            y = y + lineH

        elseif item.type == "bar" then
            local barPct = tonumber(item.value) or 0
            local bar = POS_SignalPanel and POS_SignalPanel.buildSignalBar
                and POS_SignalPanel.buildSignalBar(barPct) or tostring(barPct)
            local colour = item.colour and C[item.colour] or C.text
            W.createLabel(contextPanel, 4, y,
                PhobosLib.safeGetText(item.key) .. ": " .. bar .. " " .. barPct .. "%",
                colour)
            y = y + lineH

        elseif item.type == "action" then
            -- Clickable context action button
            local btnW = pw - 8
            local btnH = lineH + 4
            local enabled = item.enabled ~= false
            local label = PhobosLib.safeGetText(item.text)
            if enabled and item.callback then
                local btn = W.createButton(contextPanel, 4, y, btnW, btnH,
                    label, item.callback)
                if btn then
                    btn.tooltip = item.tooltip
                end
            else
                W.createDisabledButton(contextPanel, 4, y, btnW, btnH,
                    label, item.tooltip)
            end
            y = y + btnH + 2

        elseif item.type == "progress" then
            -- Labelled progress bar for background tasks
            local pct = tonumber(item.value) or 0
            local bar = POS_SignalPanel and POS_SignalPanel.buildSignalBar
                and POS_SignalPanel.buildSignalBar(pct) or tostring(pct)
            local colour = item.colour and C[item.colour] or C.dim
            W.createLabel(contextPanel, 4, y,
                PhobosLib.safeGetText(item.text) .. " " .. bar .. " " .. pct .. "%",
                colour)
            y = y + lineH
        end
    end
end
