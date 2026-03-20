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
require "POS_TerminalTheme"

POS_TerminalWidgets = {}

---------------------------------------------------------------
-- Colour palette (delegated to POS_TerminalTheme)
---------------------------------------------------------------
POS_TerminalWidgets.COLOURS = POS_TerminalTheme and POS_TerminalTheme.getColours() or {
    text   = { r = 0.33, g = 1.00, b = 0.33, a = 1.0 },
    dim    = { r = 0.20, g = 0.60, b = 0.20, a = 1.0 },
    header = { r = 0.50, g = 1.00, b = 0.50, a = 1.0 },
    border = { r = 0.15, g = 0.50, b = 0.15, a = 1.0 },
    bg     = { r = 0.00, g = 0.05, b = 0.00, a = 0.95 },
    warn   = { r = 1.00, g = 0.80, b = 0.20, a = 1.0 },
    error  = { r = 1.00, g = 0.30, b = 0.30, a = 1.0 },
    success = { r = 0.20, g = 0.90, b = 0.50, a = 1.0 },
}

function POS_TerminalWidgets.resetColours()
    POS_TerminalWidgets.COLOURS = POS_TerminalTheme and POS_TerminalTheme.getColours() or POS_TerminalWidgets.COLOURS
end

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
    -- Truncate text to fit button width
    if PhobosLib and PhobosLib.truncateText then
        local maxTextWidth = w - POS_Constants.UI_BUTTON_TEXT_PADDING
        text = PhobosLib.truncateText(text, UIFont.Code, maxTextWidth,
            POS_Constants.UI_BUTTON_TEXT_ELLIPSIS)
    end
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
    -- Truncate text to fit button width
    if PhobosLib and PhobosLib.truncateText then
        local maxTextWidth = w - POS_Constants.UI_BUTTON_TEXT_PADDING
        text = PhobosLib.truncateText(text, UIFont.Code, maxTextWidth,
            POS_Constants.UI_BUTTON_TEXT_ELLIPSIS)
    end
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
    -- Dynamic separator if charCount not explicitly provided
    if not charCount or charCount <= 0 then
        local charW = PhobosLib and PhobosLib.measureCharWidth
            and PhobosLib.measureCharWidth(UIFont.Code) or 8
        local panelW = parent and parent.getWidth and parent:getWidth() or 300
        charCount = math.max(POS_Constants.UI_MIN_SEPARATOR_CHARS,
            math.floor((panelW - 10) / charW))
    end
    local sep = string.rep(char or "=", charCount)
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

--- Create word-wrapped multi-line text as a series of ISLabels.
--- Splits text at word boundaries to fit within maxChars per line.
--- @param parent any ISPanel parent
--- @param x number X position
--- @param y number Starting Y position
--- @param maxChars number Maximum characters per line
--- @param text string Text to wrap
--- @param colour table|nil {r,g,b} colour (defaults to terminal green)
--- @return table Array of ISLabel widgets created
--- @return number Final Y position after last line
function POS_TerminalWidgets.createWrappedText(parent, x, y, maxChars, text, colour)
    local labels = {}
    local lineH = 18
    local currentY = y
    if not maxChars then
        local panelWidth = parent and parent.getWidth and parent:getWidth() or 300
        if PhobosLib and PhobosLib.maxCharsForWidth then
            maxChars = PhobosLib.maxCharsForWidth(UIFont.Code, panelWidth, 10)
        else
            maxChars = 38
        end
    end

    if not text or text == "" then
        return labels, currentY
    end

    local currentLine = ""
    for word in string.gmatch(text, "%S+") do
        if #currentLine == 0 then
            currentLine = word
        elseif #currentLine + 1 + #word <= maxChars then
            currentLine = currentLine .. " " .. word
        else
            local label = POS_TerminalWidgets.createLabel(parent, x, currentY,
                currentLine, colour)
            table.insert(labels, label)
            currentY = currentY + lineH
            currentLine = word
        end
    end

    -- Flush remaining text
    if #currentLine > 0 then
        local label = POS_TerminalWidgets.createLabel(parent, x, currentY,
            currentLine, colour)
        table.insert(labels, label)
        currentY = currentY + lineH
    end

    return labels, currentY
end

--- Create a CRT-themed text-based progress bar.
--- Renders as: [####--------] 65%
--- Uses monospace characters for consistent alignment.
--- @param parent any ISPanel parent
--- @param x number X position
--- @param y number Y position
--- @param w number Total width available for the bar
--- @param value number Current value (0-100, clamped)
--- @param colour table|nil Fill colour (defaults to terminal green)
--- @param bgColour table|nil Empty colour (defaults to dim)
--- @return any ISLabel
function POS_TerminalWidgets.createProgressBar(parent, x, y, w, value, colour, bgColour)
    value = math.max(0, math.min(100, value or 0))

    -- Determine bar width in characters
    local charW = PhobosLib and PhobosLib.measureCharWidth
        and PhobosLib.measureCharWidth(UIFont.Code) or 8
    -- Reserve space for brackets, space, and percentage text (e.g. " 100%")
    local reservedChars = 8  -- "[ ] 100%"
    local barChars = math.max(4, math.floor(w / charW) - reservedChars)

    local fillCount = math.floor(barChars * value / 100 + 0.5)
    local emptyCount = barChars - fillCount

    local fillChar = POS_Constants.UI_PROGRESS_FILL_CHAR or "#"
    local emptyChar = POS_Constants.UI_PROGRESS_EMPTY_CHAR or "-"

    local barText = "[" .. string.rep(fillChar, fillCount)
        .. string.rep(emptyChar, emptyCount) .. "] "
        .. string.format("%3d%%", value)

    local c = colour or C.text
    return POS_TerminalWidgets.createLabel(parent, x, y, barText, c)
end

--- Draw a labelled progress bar using the ctx cursor.
--- Renders: "Label: [####----] 45%"
--- Mutates ctx.y.
--- @param ctx table Layout context from initLayout
--- @param labelKey string Translation key for the label
--- @param value number 0-100
--- @param colour table|nil Fill colour (defaults based on value)
function POS_TerminalWidgets.drawProgressBar(ctx, labelKey, value, colour)
    local W = POS_TerminalWidgets
    value = math.max(0, math.min(100, value or 0))

    -- Auto-colour: green > 50, warn 20-50, error < 20
    if not colour then
        if value >= 50 then
            colour = C.text
        elseif value >= 20 then
            colour = C.warn
        else
            colour = C.error
        end
    end

    -- Label on one line
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText(labelKey) .. ":", colour)
    ctx.y = ctx.y + ctx.lineH

    -- Progress bar on next line, indented
    W.createProgressBar(ctx.panel, 8, ctx.y,
        ctx.pw - 16, value, colour)
    ctx.y = ctx.y + ctx.lineH
end

--- Remove all children from a panel (used by screen destroy).
--- Uses PZ's built-in ISUIElement:clearChildren() which resets
--- the Lua children table and calls javaObject:ClearChildren().
--- @param panel any ISPanel
function POS_TerminalWidgets.clearPanel(panel)
    if not panel then return end
    if panel.clearChildren then
        panel:clearChildren()
    end
end

---------------------------------------------------------------
-- Shared screen helpers
-- These eliminate boilerplate that was previously duplicated
-- across every screen file. See docs/design-guidelines.md §7.
---------------------------------------------------------------

--- Safe getText wrapper — delegates to PhobosLib.safeGetText.
--- @param key string Translation key
--- @return string
POS_TerminalWidgets.safeGetText = PhobosLib.safeGetText

--- Initialise standard layout variables from a content panel.
--- Returns a context table used by drawHeader, drawFooter, and
--- screen-specific layout code. Line height is derived from
--- actual font metrics rather than hardcoded.
--- @param contentPanel any ISPanel
--- @return table ctx Layout context
function POS_TerminalWidgets.initLayout(contentPanel)
    local lineH = getTextManager():getFontHeight(UIFont.Code) + 2
    local pw = contentPanel:getWidth()
    return {
        panel = contentPanel,
        pw    = pw,
        y     = 0,
        lineH = lineH,
        btnH  = lineH + 8,
        btnW  = pw - 10,
        btnX  = 5,
    }
end

--- Draw a standard screen header (bright title + separator).
--- Mutates ctx.y.
--- @param ctx table Layout context from initLayout
--- @param headerKey string Translation key for the header text
function POS_TerminalWidgets.drawHeader(ctx, headerKey)
    local W = POS_TerminalWidgets
    -- Render breadcrumb if navigated beyond root
    if POS_ScreenManager and POS_ScreenManager.getBreadcrumb then
        local crumb = POS_ScreenManager.getBreadcrumb()
        if crumb then
            W.createLabel(ctx.panel, 0, ctx.y, crumb, C.dim)
            ctx.y = ctx.y + ctx.lineH
        end
    end
    W.createLabel(ctx.panel, 0, ctx.y, W.safeGetText(headerKey), C.textBright)
    ctx.y = ctx.y + ctx.lineH
    W.createSeparator(ctx.panel, 0, ctx.y, nil)
    ctx.y = ctx.y + ctx.lineH + 4
end

--- Draw a standard screen footer (separator + [0] Back button).
--- Mutates ctx.y. Only for non-root screens.
--- @param ctx table Layout context from initLayout
function POS_TerminalWidgets.drawFooter(ctx)
    local W = POS_TerminalWidgets
    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, nil, "-")
    ctx.y = ctx.y + ctx.lineH + 4
    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        "[0] " .. W.safeGetText("UI_POS_BackPrompt"), nil,
        function() POS_ScreenManager.goBack() end)
    ctx.y = ctx.y + ctx.btnH + 4
end

--- Draw an exit footer for root screens (closes terminal).
--- Mutates ctx.y. Only for root screens where there is no back target.
--- @param ctx table Layout context from initLayout
function POS_TerminalWidgets.drawExitFooter(ctx)
    local W = POS_TerminalWidgets
    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, nil, "-")
    ctx.y = ctx.y + ctx.lineH + 4
    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
        "[0] " .. W.safeGetText("UI_POS_ExitTerminal"), nil,
        function()
            if POS_TerminalUI and POS_TerminalUI.instance then
                POS_TerminalUI.instance:close()
            end
        end)
    ctx.y = ctx.y + ctx.btnH + 4
end

--- Standard destroy function for screens.
--- Clears all children from the terminal content panel.
function POS_TerminalWidgets.defaultDestroy()
    if POS_TerminalUI and POS_TerminalUI.instance
       and POS_TerminalUI.instance.contentPanel then
        POS_TerminalWidgets.clearPanel(POS_TerminalUI.instance.contentPanel)
    end
end

--- Standard refresh for dynamic screens (destroy + recreate).
--- @param screen table Screen table with create/destroy methods
--- @param params table|nil Parameters to pass to create
function POS_TerminalWidgets.dynamicRefresh(screen, params)
    screen.destroy()
    if POS_TerminalUI and POS_TerminalUI.instance
       and POS_TerminalUI.instance.contentPanel then
        screen.create(POS_TerminalUI.instance.contentPanel, params,
            POS_TerminalUI.instance)
    end
end
