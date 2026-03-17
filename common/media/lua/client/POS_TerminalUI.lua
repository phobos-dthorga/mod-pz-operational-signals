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
-- POS_TerminalUI.lua
-- Retro early-90s computer terminal UI for POSnet.
--
-- Hosts the CRT-style window with scanline effect. Content
-- rendering is delegated to POS_ScreenManager which drives
-- a multi-screen BBS state machine. On first open per
-- world-load, plays a DOS-style boot sequence.
---------------------------------------------------------------

require "PhobosLib"

POS_TerminalUI = ISCollapsableWindow:derive("POS_TerminalUI")

--- Singleton instance reference.
POS_TerminalUI.instance = nil

--- Session boot flag — boot plays once per world-load.
local hasBootedThisSession = false

--- Terminal colour scheme.
local TERM = {
    bg      = { r = 0.05, g = 0.08, b = 0.05, a = 0.95 },
    text    = { r = 0.20, g = 0.90, b = 0.20 },
    dim     = { r = 0.12, g = 0.50, b = 0.12 },
    header  = { r = 0.30, g = 1.00, b = 0.30 },
    warn    = { r = 0.90, g = 0.80, b = 0.10 },
    err     = { r = 0.90, g = 0.25, b = 0.20 },
    border  = { r = 0.15, g = 0.40, b = 0.15, a = 1.0 },
    scan    = { r = 0.10, g = 0.20, b = 0.10, a = 0.15 },
}

--- Safe getText wrapper.
local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

--- Font for terminal text.
local FONT = UIFont.Code

--- Line height for the terminal font.
local function lineHeight()
    return getTextManager():getFontHeight(FONT) + 2
end

---------------------------------------------------------------
-- Boot sequence
---------------------------------------------------------------

local BOOT_TEXT = [[Phoenix BIOS Version 4.03
Copyright (C) 1985-1992 Phoenix Technologies Ltd.
All Rights Reserved

CPU: 80486DX @ 33 MHz
Base Memory: 640K
Extended Memory: 15360K

Detecting IDE Drives...
Primary Master: CONNER CP-30174
Primary Slave: None

Initializing Floppy Drive A: 1.44MB 3.5"

Memory Test: 16384K OK

Starting MS-DOS...

MS-DOS Version 6.00
(C)Copyright Microsoft Corp 1981-1993.

HIMEM is testing extended memory...done.
Loading HIMEM.SYS
Loading EMM386.EXE
Expanded Memory Manager installed.

BUFFERS=30
FILES=40
LASTDRIVE=Z

Loading device drivers...

ANSI.SYS installed
MOUSE.COM installed

Initializing network services...

Loading packet driver...
COM1: Radio Interface Detected
Establishing link...

C:\>]]

--- Split boot text into lines at load time.
local BOOT_LINES = {}
for line in BOOT_TEXT:gmatch("[^\n]+") do
    table.insert(BOOT_LINES, line)
end

--- Total character count (including newline as 1 char between lines).
local BOOT_TOTAL_CHARS = 0
for i, line in ipairs(BOOT_LINES) do
    BOOT_TOTAL_CHARS = BOOT_TOTAL_CHARS + #line
    if i < #BOOT_LINES then
        BOOT_TOTAL_CHARS = BOOT_TOTAL_CHARS + 1  -- newline
    end
end

--- Base reveal rate: chars per frame at 1x game speed.
--- ~720 chars over 30 seconds at 60fps = 0.4 chars/frame.
local BASE_CHARS_PER_FRAME = BOOT_TOTAL_CHARS / (30 * 60)

--- Pause frames after boot text finishes (1 second).
local BOOT_PAUSE_FRAMES = 60

---------------------------------------------------------------
-- Constructor
---------------------------------------------------------------

function POS_TerminalUI:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.title = "POSnet Terminal"
    o.resizable = false
    o.radioName = "Radio"
    o.frequency = 91500
    o.scrollOffset = 0
    o.maxScroll = 0
    o.updateTick = 0
    o.cachedLines = {}
    o._lineHeight = lineHeight()

    -- Boot sequence state
    if hasBootedThisSession then
        o.terminalState = "ready"
    else
        o.terminalState = "booting"
        o.bootCharIndex = 0
        o.bootAccumulator = 0.0
        o.bootPauseCountdown = -1
        o.bootCursorBlink = 0
    end

    return o
end

---------------------------------------------------------------
-- ISCollapsableWindow overrides
---------------------------------------------------------------

function POS_TerminalUI:initialise()
    ISCollapsableWindow.initialise(self)
end

function POS_TerminalUI:createChildren()
    PhobosLib.makeWindowResizable(self, 400, 400)
    ISCollapsableWindow.createChildren(self)
end

function POS_TerminalUI:prerender()
    ISCollapsableWindow.prerender(self)

    -- Terminal background
    local th = self:titleBarHeight()
    self:drawRect(0, th, self.width, self.height - th,
        TERM.bg.a, TERM.bg.r, TERM.bg.g, TERM.bg.b)

    -- Scanline effect
    for y = th, self.height - 1, 3 do
        self:drawRect(0, y, self.width, 1,
            TERM.scan.a, TERM.scan.r, TERM.scan.g, TERM.scan.b)
    end

    -- Inner border
    local pad = 8
    local bx, by = pad, th + pad
    local bw, bh = self.width - pad * 2, self.height - th - pad * 2
    self:drawRectBorder(bx, by, bw, bh,
        TERM.border.a, TERM.border.r, TERM.border.g, TERM.border.b)
end

function POS_TerminalUI:render()
    ISCollapsableWindow.render(self)

    if self.terminalState == "booting" then
        self:renderBoot()
    else
        self:renderScreen()
    end
end

function POS_TerminalUI:onMouseWheel(del)
    local lh = lineHeight()
    self.scrollOffset = self.scrollOffset + del * lh * 3
    self.scrollOffset = math.max(0, math.min(self.scrollOffset, self.maxScroll))
    return true
end

function POS_TerminalUI:onMouseDown(x, y)
    -- Click to skip boot sequence
    if self.terminalState == "booting" then
        self:finishBoot()
        return true
    end

    -- Delegate to screen manager for hit-zone detection
    if POS_ScreenManager and POS_ScreenManager.handleClick(self, x, y) then
        return true
    end

    return ISCollapsableWindow.onMouseDown(self, x, y)
end

function POS_TerminalUI:close()
    ISCollapsableWindow.close(self)
    POS_TerminalUI.instance = nil
end

---------------------------------------------------------------
-- Boot sequence rendering
---------------------------------------------------------------

--- Advance boot character reveal and render the boot text.
function POS_TerminalUI:renderBoot()
    -- Advance character reveal
    if self.bootPauseCountdown < 0 then
        -- Still revealing characters
        local speed = 1.0
        local gt = getGameTime()
        if gt and gt.getMultiplier then
            speed = gt:getMultiplier()
        end
        self.bootAccumulator = self.bootAccumulator + (BASE_CHARS_PER_FRAME * speed)
        local chars = math.floor(self.bootAccumulator)
        self.bootAccumulator = self.bootAccumulator - chars
        self.bootCharIndex = math.min(self.bootCharIndex + chars, BOOT_TOTAL_CHARS)

        if self.bootCharIndex >= BOOT_TOTAL_CHARS then
            self.bootPauseCountdown = BOOT_PAUSE_FRAMES
        end
    else
        -- Post-reveal pause with blinking cursor
        self.bootPauseCountdown = self.bootPauseCountdown - 1
        self.bootCursorBlink = (self.bootCursorBlink or 0) + 1
        if self.bootPauseCountdown <= 0 then
            self:finishBoot()
            return
        end
    end

    -- Render visible boot text
    local th = self:titleBarHeight()
    local pad = 16
    local x = pad
    local lh = lineHeight()
    local viewHeight = self.height - th - pad * 2

    -- Determine which characters are visible
    local charsSoFar = 0
    local renderedLines = {}

    for i, line in ipairs(BOOT_LINES) do
        local lineStart = charsSoFar
        local lineEnd = charsSoFar + #line

        if self.bootCharIndex <= lineStart then
            break  -- haven't reached this line yet
        elseif self.bootCharIndex >= lineEnd then
            -- Full line visible
            table.insert(renderedLines, line)
        else
            -- Partial line (currently being typed)
            local partial = self.bootCharIndex - lineStart
            table.insert(renderedLines, string.sub(line, 1, partial))
        end

        charsSoFar = lineEnd + 1  -- +1 for newline
    end

    -- Add blinking cursor on last line during pause
    if self.bootPauseCountdown >= 0 and #renderedLines > 0 then
        local blink = math.floor((self.bootCursorBlink or 0) / 30) % 2 == 0
        if blink then
            renderedLines[#renderedLines] = renderedLines[#renderedLines] .. "_"
        end
    end

    -- Auto-scroll to keep bottom visible
    local contentHeight = #renderedLines * lh
    if contentHeight > viewHeight then
        self.scrollOffset = contentHeight - viewHeight
    else
        self.scrollOffset = 0
    end

    -- Draw lines
    local y = th + pad - self.scrollOffset
    for _, text in ipairs(renderedLines) do
        if y + lh > th and y < self.height then
            self:drawText(text, x, y,
                TERM.text.r, TERM.text.g, TERM.text.b, 1.0, FONT)
        end
        y = y + lh
    end
end

--- Complete the boot sequence and transition to main menu.
function POS_TerminalUI:finishBoot()
    self.terminalState = "ready"
    hasBootedThisSession = true
    self.scrollOffset = 0
    POS_ScreenManager.resetTo("MAIN_MENU")
end

---------------------------------------------------------------
-- Screen rendering (delegated to POS_ScreenManager)
---------------------------------------------------------------

--- Render the current screen with throttled content rebuild.
function POS_TerminalUI:renderScreen()
    -- Throttle content rebuild (every 30 frames ~ 2/sec)
    self.updateTick = self.updateTick + 1
    if self.updateTick >= 30 or POS_ScreenManager.dirty then
        self.updateTick = 0
        POS_ScreenManager.rebuildIfNeeded(self)
    end

    -- Render cached terminal lines
    local th = self:titleBarHeight()
    local pad = 16
    local x = pad
    local y = th + pad - self.scrollOffset
    local lh = lineHeight()

    for _, line in ipairs(self.cachedLines) do
        if y + lh > th and y < self.height then
            local c = line.colour or TERM.text
            self:drawText(line.text, x, y, c.r, c.g, c.b, 1.0, FONT)
        end
        y = y + lh
    end

    -- Track max scroll
    local contentHeight = #self.cachedLines * lh
    local viewHeight = self.height - th - pad * 2
    self.maxScroll = math.max(0, contentHeight - viewHeight)
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Open the POSnet terminal window.
--- @param radioName string Display name of the connected radio
--- @param frequency number POSnet frequency in Hz
function POS_TerminalUI.open(radioName, frequency)
    if POS_TerminalUI.instance then
        POS_TerminalUI.instance:setVisible(true)
        POS_TerminalUI.instance:addToUIManager()
        return
    end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local w = 520
    local h = 560
    local x = (sw - w) / 2
    local y = (sh - h) / 2

    local ui = POS_TerminalUI:new(x, y, w, h)
    ui.radioName = radioName or "Radio"
    ui.frequency = frequency or POS_Sandbox.getPOSnetFrequency()
    ui:initialise()
    ui:addToUIManager()
    ui:setVisible(true)

    -- If skipping boot, go straight to main menu
    if ui.terminalState == "ready" then
        POS_ScreenManager.resetTo("MAIN_MENU")
    end

    POS_TerminalUI.instance = ui
end

--- Close the POSnet terminal window.
function POS_TerminalUI.closeTerminal()
    if POS_TerminalUI.instance then
        POS_TerminalUI.instance:close()
        POS_TerminalUI.instance = nil
    end
end
