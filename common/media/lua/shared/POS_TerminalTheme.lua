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
-- POS_TerminalTheme.lua
-- Central theme system for the POSnet terminal.
--
-- Manages font size, font-to-window scaling, and colour themes.
-- Reads from sandbox options and provides accessors used by
-- POS_TerminalUI and POS_TerminalWidgets.
--
-- Theme changes take effect on next terminal open.
---------------------------------------------------------------

POS_TerminalTheme = POS_TerminalTheme or {}

---------------------------------------------------------------
-- Font size mapping
---------------------------------------------------------------

--- Map sandbox integer to UIFont enum.
local FONT_MAP = {
    [1] = UIFont.Small,
    [2] = UIFont.Medium,
    [3] = UIFont.Code,
    [4] = UIFont.Large,
}

--- Get the configured terminal font.
---@param windowWidth number|nil Current window width for scaling (optional)
---@return any UIFont enum value
function POS_TerminalTheme.getFont(windowWidth)
    local sizeIdx = POS_Sandbox and POS_Sandbox.getTerminalFontSize
        and POS_Sandbox.getTerminalFontSize() or 3

    -- Font-to-window scaling (if enabled)
    if windowWidth and POS_Sandbox and POS_Sandbox.isFontScaleWithWindow
       and POS_Sandbox.isFontScaleWithWindow() then
        if windowWidth < 600 then
            sizeIdx = math.max(1, sizeIdx - 1)
        elseif windowWidth > 900 then
            sizeIdx = math.min(4, sizeIdx + 1)
        end
    end

    return FONT_MAP[sizeIdx] or UIFont.Code
end

---------------------------------------------------------------
-- Colour themes
---------------------------------------------------------------

--- Theme definitions. Each provides colours for TERM (TerminalUI)
--- and COLOURS (TerminalWidgets).
POS_TerminalTheme.THEMES = {
    -- 1: Classic Green (default)
    {
        name = "Classic Green",
        term = {
            bg     = { r = 0.05, g = 0.08, b = 0.05, a = 0.95 },
            text   = { r = 0.20, g = 0.90, b = 0.20 },
            dim    = { r = 0.12, g = 0.50, b = 0.12 },
            header = { r = 0.30, g = 1.00, b = 0.30 },
            warn   = { r = 0.90, g = 0.80, b = 0.10 },
            err    = { r = 0.90, g = 0.25, b = 0.20 },
            border = { r = 0.15, g = 0.40, b = 0.15 },
            scan   = { r = 0.10, g = 0.20, b = 0.10, a = 0.15 },
            glow   = { r = 0.05, g = 0.15, b = 0.05, a = 0.08 },
        },
        widgets = {
            text       = { r = 0.20, g = 0.90, b = 0.20, a = 1.0 },
            textBright = { r = 0.30, g = 1.00, b = 0.30, a = 1.0 },
            dim        = { r = 0.12, g = 0.50, b = 0.12, a = 1.0 },
            disabled   = { r = 0.10, g = 0.35, b = 0.10, a = 0.7 },
            warn       = { r = 0.90, g = 0.80, b = 0.10, a = 1.0 },
            error      = { r = 0.90, g = 0.25, b = 0.20, a = 1.0 },
            bgDark     = { r = 0.02, g = 0.05, b = 0.02, a = 0.8 },
            bgHover    = { r = 0.05, g = 0.15, b = 0.05, a = 0.8 },
            border     = { r = 0.15, g = 0.50, b = 0.15, a = 0.8 },
            borderDim  = { r = 0.08, g = 0.25, b = 0.08, a = 0.5 },
            transparent = { r = 0, g = 0, b = 0, a = 0 },
        },
    },
    -- 2: Amber
    {
        name = "Amber",
        term = {
            bg     = { r = 0.08, g = 0.05, b = 0.02, a = 0.95 },
            text   = { r = 1.00, g = 0.75, b = 0.00 },
            dim    = { r = 0.60, g = 0.45, b = 0.00 },
            header = { r = 1.00, g = 0.85, b = 0.20 },
            warn   = { r = 1.00, g = 0.50, b = 0.10 },
            err    = { r = 0.90, g = 0.25, b = 0.20 },
            border = { r = 0.40, g = 0.30, b = 0.05 },
            scan   = { r = 0.20, g = 0.15, b = 0.02, a = 0.15 },
            glow   = { r = 0.15, g = 0.10, b = 0.02, a = 0.08 },
        },
        widgets = {
            text       = { r = 1.00, g = 0.75, b = 0.00, a = 1.0 },
            textBright = { r = 1.00, g = 0.85, b = 0.20, a = 1.0 },
            dim        = { r = 0.60, g = 0.45, b = 0.00, a = 1.0 },
            disabled   = { r = 0.35, g = 0.25, b = 0.00, a = 0.7 },
            warn       = { r = 1.00, g = 0.50, b = 0.10, a = 1.0 },
            error      = { r = 0.90, g = 0.25, b = 0.20, a = 1.0 },
            bgDark     = { r = 0.05, g = 0.03, b = 0.01, a = 0.8 },
            bgHover    = { r = 0.15, g = 0.10, b = 0.02, a = 0.8 },
            border     = { r = 0.50, g = 0.35, b = 0.05, a = 0.8 },
            borderDim  = { r = 0.25, g = 0.18, b = 0.03, a = 0.5 },
            transparent = { r = 0, g = 0, b = 0, a = 0 },
        },
    },
    -- 3: Cool White
    {
        name = "Cool White",
        term = {
            bg     = { r = 0.06, g = 0.06, b = 0.06, a = 0.95 },
            text   = { r = 0.85, g = 0.90, b = 0.85 },
            dim    = { r = 0.50, g = 0.55, b = 0.50 },
            header = { r = 1.00, g = 1.00, b = 1.00 },
            warn   = { r = 0.90, g = 0.80, b = 0.10 },
            err    = { r = 0.90, g = 0.25, b = 0.20 },
            border = { r = 0.35, g = 0.35, b = 0.35 },
            scan   = { r = 0.15, g = 0.15, b = 0.15, a = 0.12 },
            glow   = { r = 0.10, g = 0.10, b = 0.10, a = 0.06 },
        },
        widgets = {
            text       = { r = 0.85, g = 0.90, b = 0.85, a = 1.0 },
            textBright = { r = 1.00, g = 1.00, b = 1.00, a = 1.0 },
            dim        = { r = 0.50, g = 0.55, b = 0.50, a = 1.0 },
            disabled   = { r = 0.30, g = 0.30, b = 0.30, a = 0.7 },
            warn       = { r = 0.90, g = 0.80, b = 0.10, a = 1.0 },
            error      = { r = 0.90, g = 0.25, b = 0.20, a = 1.0 },
            bgDark     = { r = 0.04, g = 0.04, b = 0.04, a = 0.8 },
            bgHover    = { r = 0.12, g = 0.12, b = 0.12, a = 0.8 },
            border     = { r = 0.40, g = 0.40, b = 0.40, a = 0.8 },
            borderDim  = { r = 0.20, g = 0.20, b = 0.20, a = 0.5 },
            transparent = { r = 0, g = 0, b = 0, a = 0 },
        },
    },
    -- 4: IBM Blue
    {
        name = "IBM Blue",
        term = {
            bg     = { r = 0.02, g = 0.03, b = 0.08, a = 0.95 },
            text   = { r = 0.40, g = 0.60, b = 1.00 },
            dim    = { r = 0.20, g = 0.35, b = 0.60 },
            header = { r = 0.50, g = 0.70, b = 1.00 },
            warn   = { r = 0.90, g = 0.80, b = 0.10 },
            err    = { r = 0.90, g = 0.25, b = 0.20 },
            border = { r = 0.15, g = 0.25, b = 0.50 },
            scan   = { r = 0.05, g = 0.08, b = 0.20, a = 0.15 },
            glow   = { r = 0.03, g = 0.05, b = 0.15, a = 0.08 },
        },
        widgets = {
            text       = { r = 0.40, g = 0.60, b = 1.00, a = 1.0 },
            textBright = { r = 0.50, g = 0.70, b = 1.00, a = 1.0 },
            dim        = { r = 0.20, g = 0.35, b = 0.60, a = 1.0 },
            disabled   = { r = 0.15, g = 0.20, b = 0.40, a = 0.7 },
            warn       = { r = 0.90, g = 0.80, b = 0.10, a = 1.0 },
            error      = { r = 0.90, g = 0.25, b = 0.20, a = 1.0 },
            bgDark     = { r = 0.01, g = 0.02, b = 0.05, a = 0.8 },
            bgHover    = { r = 0.05, g = 0.08, b = 0.18, a = 0.8 },
            border     = { r = 0.20, g = 0.35, b = 0.65, a = 0.8 },
            borderDim  = { r = 0.10, g = 0.18, b = 0.35, a = 0.5 },
            transparent = { r = 0, g = 0, b = 0, a = 0 },
        },
    },
}

--- Get the active theme definition.
---@return table Theme table with .term and .widgets sub-tables
function POS_TerminalTheme.getActiveTheme()
    local themeIdx = POS_Sandbox and POS_Sandbox.getTerminalColourTheme
        and POS_Sandbox.getTerminalColourTheme() or 1
    return POS_TerminalTheme.THEMES[themeIdx] or POS_TerminalTheme.THEMES[1]
end

--- Get the TERM colour table (for POS_TerminalUI).
---@return table TERM-compatible colour table
function POS_TerminalTheme.getTERM()
    return POS_TerminalTheme.getActiveTheme().term
end

--- Get the COLOURS table (for POS_TerminalWidgets).
---@return table Widget colour palette
function POS_TerminalTheme.getColours()
    return POS_TerminalTheme.getActiveTheme().widgets
end
