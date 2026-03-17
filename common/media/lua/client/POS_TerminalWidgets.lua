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
-- POS_TerminalWidgets.lua
-- Factory functions for CRT-themed PZ UI widgets.
--
-- All widgets use UIFont.Code and a green-on-dark phosphor
-- colour palette to match the POSnet terminal aesthetic.
---------------------------------------------------------------

require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"

POS_TerminalWidgets = {}

---------------------------------------------------------------
-- Colour palette (CRT phosphor green theme)
---------------------------------------------------------------
POS_TerminalWidgets.COLOURS = {
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
}

local C = POS_TerminalWidgets.COLOURS

---------------------------------------------------------------
-- Widget factories
---------------------------------------------------------------

--- Create a CRT-green ISButton.
--- @param parent any ISPanel parent
--- @param x number X position within parent
--- @param y number Y position within parent
--- @param w number Width
--- @param h number Height
--- @param text string Button label text
--- @param target any Callback target object
--- @param callback function Callback function
--- @return any ISButton
function POS_TerminalWidgets.createButton(parent, x, y, w, h, text, target, callback)
    local btn = ISButton:new(x, y, w, h, text, target, callback)
    btn.backgroundColor = { r = C.bgDark.r, g = C.bgDark.g, b = C.bgDark.b, a = C.bgDark.a }
    btn.backgroundColorMouseOver = { r = C.bgHover.r, g = C.bgHover.g, b = C.bgHover.b, a = C.bgHover.a }
    btn.borderColor = { r = C.border.r, g = C.border.g, b = C.border.b, a = C.border.a }
    btn.textColor = { r = C.text.r, g = C.text.g, b = C.text.b, a = C.text.a }
    btn.font = UIFont.Code
    btn:initialise()
    btn:instantiate()
    parent:addChild(btn)
    return btn
end

--- Create a disabled (greyed-out) CRT-green ISButton.
--- @param parent any ISPanel parent
--- @param x number X position within parent
--- @param y number Y position within parent
--- @param w number Width
--- @param h number Height
--- @param text string Button label text
--- @return any ISButton
function POS_TerminalWidgets.createDisabledButton(parent, x, y, w, h, text)
    local btn = ISButton:new(x, y, w, h, text, nil, nil)
    btn.backgroundColor = { r = C.bgDark.r, g = C.bgDark.g, b = C.bgDark.b, a = 0.4 }
    btn.backgroundColorMouseOver = btn.backgroundColor
    btn.borderColor = { r = C.borderDim.r, g = C.borderDim.g, b = C.borderDim.b, a = C.borderDim.a }
    btn.textColor = { r = C.disabled.r, g = C.disabled.g, b = C.disabled.b, a = C.disabled.a }
    btn.font = UIFont.Code
    btn.enable = false
    btn:initialise()
    btn:instantiate()
    parent:addChild(btn)
    return btn
end

--- Create a CRT-green ISLabel.
--- @param parent any ISPanel parent
--- @param x number X position
--- @param y number Y position
--- @param text string Label text
--- @param colour table|nil {r,g,b} — defaults to terminal green
--- @return any ISLabel
function POS_TerminalWidgets.createLabel(parent, x, y, text, colour)
    local c = colour or C.text
    local label = ISLabel:new(x, y, 18, text, c.r, c.g, c.b, c.a or 1.0, UIFont.Code, true)
    label:initialise()
    label:instantiate()
    parent:addChild(label)
    return label
end

--- Create a dim separator line (e.g. "════════════════════").
--- @param parent any ISPanel parent
--- @param x number X position
--- @param y number Y position
--- @param charCount number Number of separator characters
--- @param char string|nil Separator character (default "=")
--- @return any ISLabel
function POS_TerminalWidgets.createSeparator(parent, x, y, charCount, char)
    local sep = string.rep(char or "=", charCount or 40)
    return POS_TerminalWidgets.createLabel(parent, x, y, sep, C.dim)
end

--- Create a CRT-green ISTextEntryBox for keyboard input.
--- @param parent any ISPanel parent
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @param onSubmit function|nil Called when Enter is pressed
--- @return any ISTextEntryBox
function POS_TerminalWidgets.createTextEntry(parent, x, y, w, h, onSubmit)
    local entry = ISTextEntryBox:new("", x, y, w, h)
    entry.backgroundColor = { r = C.bgDark.r, g = C.bgDark.g, b = C.bgDark.b, a = 0.9 }
    entry.borderColor = { r = C.border.r, g = C.border.g, b = C.border.b, a = C.border.a }
    entry.font = UIFont.Code
    if onSubmit then
        entry.onCommandEntered = onSubmit
    end
    entry:initialise()
    entry:instantiate()
    parent:addChild(entry)
    return entry
end

--- Create a CRT-themed ISScrollingListBox.
--- @param parent any ISPanel parent
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @return any ISScrollingListBox
function POS_TerminalWidgets.createScrollList(parent, x, y, w, h)
    local list = ISScrollingListBox:new(x, y, w, h)
    list.backgroundColor = { r = C.bgDark.r, g = C.bgDark.g, b = C.bgDark.b, a = 0.6 }
    list.borderColor = { r = C.borderDim.r, g = C.borderDim.g, b = C.borderDim.b, a = C.borderDim.a }
    list.font = { UIFont.Code }
    list:initialise()
    list:instantiate()
    parent:addChild(list)
    return list
end

--- Create a stencil-clipped scrolling ISPanel.
--- Content taller than the panel height scrolls with mouse wheel.
--- @param parent any ISPanel parent
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @return any ISPanel
function POS_TerminalWidgets.createScrollPanel(parent, x, y, w, h)
    local panel = ISPanel:new(x, y, w, h)
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    function panel:prerender()
        ISPanel.prerender(self)
        self:setStencilRect(0, 0, self.width, self.height)
    end
    function panel:postrender()
        self:clearStencilRect()
    end
    panel:setScrollChildren(true)
    panel:initialise()
    panel:instantiate()
    parent:addChild(panel)
    return panel
end

--- Remove all children from a panel (used by screen destroy).
--- @param panel any ISPanel
function POS_TerminalWidgets.clearPanel(panel)
    if not panel then return end
    -- ISUIElement stores children in self.javaObject child list
    -- Safest approach: collect then remove
    local children = {}
    if panel.getChildren then
        local jChildren = panel:getChildren()
        if jChildren then
            for i = 0, jChildren:size() - 1 do
                table.insert(children, jChildren:get(i))
            end
        end
    end
    for _, child in ipairs(children) do
        panel:removeChild(child)
    end
end
