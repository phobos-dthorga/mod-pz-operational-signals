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
-- Hosts the CRT-style window with a generated bezel texture,
-- scanline effect, and phosphor glow. Content rendering is
-- delegated to POS_ScreenManager which drives a multi-screen
-- BBS state machine. On first open per world-load, plays a
-- DOS-style boot sequence.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "ISUI/ISPanel"
require "POS_ScreenManager"
require "POS_TerminalWidgets"

POS_TerminalUI = ISCollapsableWindow:derive("POS_TerminalUI")

local _TAG = "[POS:TerminalUI]"

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
    glow    = { r = 0.05, g = 0.15, b = 0.05, a = 0.08 },
}

--- CRT bezel texture (lazy-loaded, cached by PZ engine).
local CRT_BEZEL = nil
local function getCRTBezel()
    if not CRT_BEZEL then
        CRT_BEZEL = getTexture("media/textures/POSnet_CRT_Bezel.png")
    end
    return CRT_BEZEL
end

--- Bezel screen area inset percentages.
--- These define where the monitor's "screen" sits within the bezel texture.
--- Values measured from the generated CRT bezel image.
local BEZEL = {
    left   = POS_Constants.BEZEL_INSET_LEFT,
    right  = POS_Constants.BEZEL_INSET_RIGHT,
    top    = POS_Constants.BEZEL_INSET_TOP,
    bottom = POS_Constants.BEZEL_INSET_BOTTOM,
}

--- Font for terminal text.
local FONT = UIFont.Code

--- Line height for the terminal font.
local function lineHeight()
    return getTextManager():getFontHeight(FONT) + 2
end

--- Content padding inside the screen area.
local SCREEN_PAD = POS_Constants.UI_SCREEN_PADDING

--- Navigation sidebar width (left panel, fixed).
local NAV_PANEL_WIDTH = POS_Constants.UI_NAV_PANEL_WIDTH

--- Context detail panel width (right panel, fixed).
local CONTEXT_PANEL_WIDTH = POS_Constants.UI_CONTEXT_PANEL_WIDTH

--- Minimum window width before context panel auto-collapses.
local CONTEXT_COLLAPSE_THRESHOLD = POS_Constants.UI_CONTEXT_COLLAPSE_THRESHOLD

--- Gap between adjacent panels.
local PANEL_GAP = POS_Constants.UI_PANEL_GAP

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
local BASE_CHARS_PER_FRAME = BOOT_TOTAL_CHARS / (POS_Constants.BOOT_DURATION_SECONDS * POS_Constants.BOOT_TARGET_FPS)

--- Pause frames after boot text finishes (1 second).
local BOOT_PAUSE_FRAMES = POS_Constants.BOOT_PAUSE_FRAMES

---------------------------------------------------------------
-- Screen rect helper
---------------------------------------------------------------

--- Compute the content screen rectangle within the bezel.
--- Returns absolute pixel coordinates relative to the window.
---@return number sx, number sy, number sw, number sh
function POS_TerminalUI:getScreenRect()
    local tex = getCRTBezel()
    if tex then
        local bx = math.floor(self.width * BEZEL.left)
        local by = math.floor(self.height * BEZEL.top)
        local bw = self.width - bx - math.floor(self.width * BEZEL.right)
        local bh = self.height - by - math.floor(self.height * BEZEL.bottom)
        return bx, by, bw, bh
    else
        -- Fallback: use title bar + padding (original behaviour)
        local th = self:titleBarHeight()
        local pad = 16
        return pad, th + pad, self.width - pad * 2, self.height - th - pad * 2
    end
end

---------------------------------------------------------------
-- Panel layout
---------------------------------------------------------------

--- Reposition nav, content, and context panels within the bezel.
--- Called every prerender() to handle window resize.
function POS_TerminalUI:repositionPanels()
    local sx, sy, sw, sh = self:getScreenRect()
    local pad = SCREEN_PAD
    local innerX = sx + pad
    local innerY = sy + pad
    local innerW = sw - pad * 2
    local innerH = sh - pad * 2

    local showNav = POS_Sandbox and POS_Sandbox.getEnableNavPanel
        and POS_Sandbox.getEnableNavPanel() or true
    local showContext = (self.width >= CONTEXT_COLLAPSE_THRESHOLD)
        and (POS_Sandbox and POS_Sandbox.getEnableContextPanel
             and POS_Sandbox.getEnableContextPanel() or true)

    -- NavPanel (left, fixed width)
    if self.navPanel then
        if showNav then
            self.navPanel:setX(innerX)
            self.navPanel:setY(innerY)
            self.navPanel:setWidth(NAV_PANEL_WIDTH)
            self.navPanel:setHeight(innerH)
        end
        self.navPanel:setVisible(showNav and self.terminalState == "ready")
    end

    -- ContextPanel (right, fixed width, collapsible)
    local ctxW = showContext and CONTEXT_PANEL_WIDTH or 0
    if self.contextPanel then
        if showContext then
            self.contextPanel:setX(innerX + innerW - ctxW)
            self.contextPanel:setY(innerY)
            self.contextPanel:setWidth(ctxW)
            self.contextPanel:setHeight(innerH)
        end
        self.contextPanel:setVisible(showContext and self.terminalState == "ready")
    end

    -- ContentPanel (center, flex width)
    if self.contentPanel then
        local contentX = innerX
        local contentW = innerW
        if showNav then
            contentX = contentX + NAV_PANEL_WIDTH + PANEL_GAP
            contentW = contentW - NAV_PANEL_WIDTH - PANEL_GAP
        end
        if showContext then
            contentW = contentW - ctxW - PANEL_GAP
        end
        self.contentPanel:setX(contentX)
        self.contentPanel:setY(innerY)
        self.contentPanel:setWidth(math.max(contentW, 200))
        self.contentPanel:setHeight(innerH)
    end
end

---------------------------------------------------------------
-- Constructor
---------------------------------------------------------------

function POS_TerminalUI:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.title = "POSnet Terminal"
    o.resizable = false
    o.pin = true
    o.radioName = "Radio"
    o.frequency = 91500
    o.updateTick = 0

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
    PhobosLib.makeWindowResizable(self, 720, 780)
    ISCollapsableWindow.createChildren(self)

    -- Hide standard window chrome — CRT bezel replaces it visually
    local tex = getCRTBezel()
    if tex then
        if self.closeButton then self.closeButton:setVisible(false) end
        if self.collapseButton then self.collapseButton:setVisible(false) end
        if self.pinButton then self.pinButton:setVisible(false) end
        self.drawFrame = false
        self.background = false
    end

    -- Create content panel for widget-based screens
    local sx, sy, sw, sh = self:getScreenRect()
    local pad = SCREEN_PAD
    -- Helper: create a stencil-clipped ISPanel (prevents content bleed-over)
    local function createClippedPanel(parent, x, y, w, h)
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
        panel:initialise()
        panel:instantiate()
        parent:addChild(panel)
        return panel
    end

    self.contentPanel = createClippedPanel(self, sx + pad, sy + pad, sw - pad * 2, sh - pad * 2)

    -- NavPanel (left sidebar)
    self.navPanel = createClippedPanel(self, 0, 0, NAV_PANEL_WIDTH, 100)
    self.navPanel:setVisible(false)

    -- ContextPanel (right sidebar)
    self.contextPanel = createClippedPanel(self, 0, 0, CONTEXT_PANEL_WIDTH, 100)
    self.contextPanel:setVisible(false)

    -- Register ESC key listener (closure captures self)
    local ui = self
    self._keyHandler = function(key)
        if key == Keyboard.KEY_ESCAPE and ui:isVisible() then
            ui:close()
        end
    end
    Events.OnKeyPressed.Add(self._keyHandler)
end

function POS_TerminalUI:prerender()
    -- Drain portable computer condition while terminal is open
    if self.portableComputer then
        local gt = getGameTime()
        if gt then
            local mult = gt:getMultiplier() or 1
            local drainDivisor = POS_Sandbox and POS_Sandbox.getPortableDrainDivisor
                and POS_Sandbox.getPortableDrainDivisor() or POS_Constants.PORTABLE_DRAIN_DIVISOR_DEFAULT
            self.portableDrainAccum = (self.portableDrainAccum or 0) + (mult / drainDivisor)
            if self.portableDrainAccum >= 1.0 then
                self.portableDrainAccum = self.portableDrainAccum - 1.0
                local cond = self.portableComputer:getCondition()
                if cond and cond > 0 then
                    self.portableComputer:setCondition(cond - 1)
                else
                    PhobosLib.debug("POS", _TAG, "Portable computer battery depleted")
                    POS_TerminalUI.closeTerminal()
                    return
                end
            end
        end
    end

    -- Desktop terminal: check for power failure (throttled)
    if not self.portableComputer and self.powerSquare then
        self.powerCheckAccum = (self.powerCheckAccum or 0) + 1
        if self.powerCheckAccum >= POS_Constants.POWER_CHECK_INTERVAL then
            self.powerCheckAccum = 0
            if not PhobosLib.hasPower(self.powerSquare) then
                local player = getPlayer()
                if player then
                    PhobosLib.say(player,
                        PhobosLib.safeGetText(POS_Constants.MSG_POWER_LOST))
                end
                PhobosLib.debug("POS", _TAG,
                    "Desktop power lost — closing terminal")
                POS_TerminalUI.closeTerminal()
                return
            end
        end
    end

    local tex = getCRTBezel()
    if tex then
        -- Draw CRT bezel texture covering entire window (behind child widgets)
        self:drawTextureScaled(tex, 0, 0, self.width, self.height, 1.0, 1, 1, 1)
        -- Scanlines are drawn in render() so they overlay child widgets
    else
        -- Fallback: original programmatic rendering
        ISCollapsableWindow.prerender(self)
        local th = self:titleBarHeight()
        self:drawRect(0, th, self.width, self.height - th,
            TERM.bg.a, TERM.bg.r, TERM.bg.g, TERM.bg.b)

        -- Inner border (fallback only)
        local pad = 8
        local bx, by = pad, th + pad
        local bw, bh = self.width - pad * 2, self.height - th - pad * 2
        self:drawRectBorder(bx, by, bw, bh,
            TERM.border.a, TERM.border.r, TERM.border.g, TERM.border.b)
    end

    -- Reposition all panels (nav, content, context) on resize
    self:repositionPanels()
end

function POS_TerminalUI:render()
    ISCollapsableWindow.render(self)

    local sx, sy, sw, sh = self:getScreenRect()

    -- Hide all panels during boot (boot uses drawText directly)
    local isReady = (self.terminalState == "ready")
    if self.contentPanel then
        self.contentPanel:setVisible(isReady)
    end
    if self.navPanel then
        self.navPanel:setVisible(isReady and self.navPanel:isVisible())
    end
    if self.contextPanel then
        self.contextPanel:setVisible(isReady and self.contextPanel:isVisible())
    end

    -- Stencil clip drawText content to the screen area
    self:setStencilRect(sx, sy, sw, sh)

    if self.terminalState == "booting" then
        self:renderBoot()
    else
        self:renderScreen()
    end

    self:clearStencilRect()

    -- Scanline effect OVER widget children (CRT glass look)
    for y = sy, sy + sh - 1, 3 do
        self:drawRect(sx, y, sw, 1,
            TERM.scan.a, TERM.scan.r, TERM.scan.g, TERM.scan.b)
    end

    -- Phosphor glow effect over screen area
    self:drawRect(sx, sy, sw, sh,
        TERM.glow.a, TERM.glow.r, TERM.glow.g, TERM.glow.b)
end

function POS_TerminalUI:onMouseDown(x, y)
    -- Close if click is outside window bounds (replaces onMouseDownOutside
    -- which was unreliable when ISButtons are destroyed mid-click)
    if x < 0 or y < 0 or x > self.width or y > self.height then
        self:close()
        return true
    end

    -- Click to skip boot sequence
    if self.terminalState == "booting" then
        self:finishBoot()
        return true
    end

    return ISCollapsableWindow.onMouseDown(self, x, y)
end

function POS_TerminalUI:close()
    -- Stop power drain session
    if self.powerDrainSession then
        PhobosLib.stopPowerDrain(self.powerDrainSession)
        -- Clean up square modData
        if self.powerSquare then
            local md = self.powerSquare:getModData()
            md[POS_Constants.MD_POWER_DRAIN_RATE] = nil
            md[POS_Constants.MD_POWER_DRAIN_SESSION] = nil
        end
        self.powerDrainSession = nil
        self.powerSquare = nil
    end
    -- Remove keyboard listener
    if self._keyHandler then
        Events.OnKeyPressed.Remove(self._keyHandler)
        self._keyHandler = nil
    end
    -- Destroy current screen widgets before closing
    local screen = POS_ScreenManager.screens[POS_ScreenManager.currentScreen]
    if screen and screen.destroy then
        pcall(screen.destroy)
    end
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
    local sx, sy, sw, sh = self:getScreenRect()
    local pad = SCREEN_PAD
    local x = sx + pad
    local lh = lineHeight()
    local viewHeight = sh - pad * 2

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

    -- Draw lines (clipped to screen area)
    local drawY = sy + pad - self.scrollOffset
    for _, text in ipairs(renderedLines) do
        if drawY + lh > sy and drawY < sy + sh then
            self:drawText(text, x, drawY,
                TERM.text.r, TERM.text.g, TERM.text.b, 1.0, FONT)
        end
        drawY = drawY + lh
    end
end

--- Complete the boot sequence and transition to main menu.
function POS_TerminalUI:finishBoot()
    self.terminalState = "ready"
    hasBootedThisSession = true
    POS_ScreenManager.resetTo(POS_Constants.SCREEN_MAIN_MENU)
end

---------------------------------------------------------------
-- Screen refresh (widget content handled by child ISPanels)
---------------------------------------------------------------

--- Handle throttled screen refresh. Widget screens manage their
--- own rendering via ISButton/ISLabel children in contentPanel.
function POS_TerminalUI:renderScreen()
    -- Defensive: if no screen is active, navigate to main menu
    if not POS_ScreenManager.currentScreen then
        POS_ScreenManager.resetTo(POS_Constants.SCREEN_MAIN_MENU)
    end

    -- Throttle refresh check (every 30 frames ~ 2/sec)
    self.updateTick = self.updateTick + 1
    if self.updateTick >= 30 or POS_ScreenManager.dirty then
        self.updateTick = 0
        POS_ScreenManager.refreshIfNeeded(self)
    end
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Open the POSnet terminal window.
--- @param radioName string Display name of the connected radio
--- @param frequency number POSnet frequency in Hz
function POS_TerminalUI.open(radioName, frequency, portablePC, signalStrength, band)
    if POS_TerminalUI.instance then
        POS_TerminalUI.instance:setVisible(true)
        POS_TerminalUI.instance:addToUIManager()
        return
    end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local w = 1080
    local h = 1170
    local x = (sw - w) / 2
    local y = (sh - h) / 2

    local ui = POS_TerminalUI:new(x, y, w, h)
    ui.radioName = radioName or "Radio"
    ui.frequency = frequency or POS_Sandbox.getPOSnetFrequency()
    ui.signalStrength = signalStrength or 1.0
    ui.band = band or "operations"
    ui.connected = true

    -- Track portable computer for battery drain
    ui.portableComputer = portablePC
    ui.portableDrainAccum = 0

    -- Desktop terminal: start generator power drain
    if not portablePC then
        local player = getPlayer()
        if player then
            local sq = player:getSquare()
            if sq and PhobosLib.hasPower(sq) then
                local drainRate = POS_Sandbox.getTerminalPowerDrainRate()
                if drainRate > 0 then
                    -- Cross-mod: check if another drain already exists on this square
                    local md = sq:getModData()
                    local existingRate = md[POS_Constants.MD_POWER_DRAIN_RATE] or 0
                    if existingRate > 0 and existingRate >= drainRate then
                        PhobosLib.debug("POS", _TAG,
                            "Existing power drain at " .. existingRate
                            .. "%%/min — skipping POSnet drain")
                    else
                        -- Stop existing lower-rate drain if present
                        local existingSession = md[POS_Constants.MD_POWER_DRAIN_SESSION]
                        if existingSession then
                            PhobosLib.stopPowerDrain(existingSession)
                        end
                        ui.powerDrainSession = PhobosLib.startPowerDrain(sq, drainRate)
                        md[POS_Constants.MD_POWER_DRAIN_RATE] = drainRate
                        md[POS_Constants.MD_POWER_DRAIN_SESSION] = ui.powerDrainSession
                    end
                end
                ui.powerSquare = sq
            end
        end
    end
    ui.powerCheckAccum = 0

    ui:initialise()
    ui:addToUIManager()
    ui:setVisible(true)

    -- Set instance BEFORE resetTo so createWidgetScreen can find
    -- the contentPanel via POS_TerminalUI.instance
    POS_TerminalUI.instance = ui

    -- If skipping boot, go straight to main menu
    if ui.terminalState == "ready" then
        POS_ScreenManager.resetTo(POS_Constants.SCREEN_MAIN_MENU)
    end
end

--- Close the POSnet terminal window.
function POS_TerminalUI.closeTerminal()
    if POS_TerminalUI.instance then
        POS_TerminalUI.instance:close()
        POS_TerminalUI.instance = nil
    end
end
