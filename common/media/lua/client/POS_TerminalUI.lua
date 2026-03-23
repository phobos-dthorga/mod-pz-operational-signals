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
-- Telnet-style terminal UI for POSnet.
--
-- Hosts a clean terminal window with header bar, content area,
-- status bar, and subtle scanline/glow effects. Content
-- rendering is delegated to POS_ScreenManager which drives a
-- multi-screen BBS state machine. On first open per world-load,
-- plays a DOS-style boot sequence.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "ISUI/ISPanel"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_TerminalTheme"
require "POS_BootSequence"

POS_TerminalUI = ISCollapsableWindow:derive("POS_TerminalUI")

local _TAG = "[POS:TerminalUI]"

--- Singleton instance reference.
POS_TerminalUI.instance = nil

--- Session boot flag -- boot plays once per world-load.
local hasBootedThisSession = false

--- Terminal colour scheme (resolved from theme in createChildren).
local TERM = nil

--- Header and status bar geometry.
local HEADER_HEIGHT = 24
local STATUS_BAR_HEIGHT = 24
local HEADER_FONT = UIFont.Code

--- Font for terminal text.
local FONT = UIFont.Code

--- Line height for the terminal font.
local function lineHeight()
    return getTextManager():getFontHeight(FONT) + 2
end

--- Content padding inside the screen area.
local SCREEN_PAD = POS_Constants.UI_SCREEN_PADDING

--- Context detail panel width (right panel, fixed).
local CONTEXT_PANEL_WIDTH = POS_Constants.UI_CONTEXT_PANEL_WIDTH

--- Minimum window width before context panel auto-collapses.
local CONTEXT_COLLAPSE_THRESHOLD = POS_Constants.UI_CONTEXT_COLLAPSE_THRESHOLD

--- Gap between adjacent panels.
local PANEL_GAP = POS_Constants.UI_PANEL_GAP

---------------------------------------------------------------
-- Boot sequence (loaded from Definitions/BootSequence/)
---------------------------------------------------------------

--- Boot data resolved per-open from POS_BootSequence.getBootData().
--- Fields: lines (string[]), totalChars (int), charsPerFrame (float),
--- pauseFrames (int). Populated in initBootData().
local bootData = nil

--- Compute boot timing from resolved boot data.
---@param terminal table POS_TerminalUI instance
local function initBootData(terminal)
    local bd = POS_BootSequence.getBootData(terminal)
    local lines = bd.lines or { "System ready." }
    local totalChars = 0
    for i, line in ipairs(lines) do
        totalChars = totalChars + #line
        if i < #lines then totalChars = totalChars + 1 end  -- newline
    end
    local duration = bd.durationSeconds or 15
    local fps = POS_Constants.BOOT_TARGET_FPS or 60
    bootData = {
        lines         = lines,
        totalChars    = totalChars,
        charsPerFrame = totalChars / (duration * fps),
        pauseFrames   = math.floor((bd.postBootPauseSec or 1.0) * fps),
        systemName    = bd.systemName or "POSNET BBS",
    }
end

---------------------------------------------------------------
-- Screen rect helper
---------------------------------------------------------------

--- Compute the content area rectangle (between header and status bar).
--- Returns absolute pixel coordinates relative to the window.
---@return number sx, number sy, number sw, number sh
function POS_TerminalUI:getScreenRect()
    return 0, HEADER_HEIGHT, self.width, self.height - HEADER_HEIGHT - STATUS_BAR_HEIGHT
end

---------------------------------------------------------------
-- Panel layout
---------------------------------------------------------------

--- Reposition nav, content, and context panels within the content area.
--- Called every prerender() to handle window resize.
function POS_TerminalUI:repositionPanels()
    local sx, sy, sw, sh = self:getScreenRect()
    local pad = SCREEN_PAD
    local innerX = sx + pad
    local innerY = sy + pad
    local innerW = sw - pad * 2
    local innerH = sh - pad * 2

    local showContext = (self.width >= CONTEXT_COLLAPSE_THRESHOLD)

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

    -- ContentPanel (flex width, no nav panel offset)
    if self.contentPanel then
        local contentX = innerX
        local contentW = innerW
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

    -- Resolve theme colours (cached for this window lifetime)
    TERM = POS_TerminalTheme.getTERM()

    -- Hide standard window chrome -- we draw our own header bar
    self.drawFrame = false
    self.background = false
    if self.closeButton then self.closeButton:setVisible(false) end
    if self.collapseButton then self.collapseButton:setVisible(false) end
    if self.pinButton then self.pinButton:setVisible(false) end

    -- Create content panels (no stencil clipping needed)
    local sx, sy, sw, sh = self:getScreenRect()
    local pad = SCREEN_PAD

    local function createPanel(parent, x, y, w, h)
        local panel = ISPanel:new(x, y, w, h)
        panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
        panel:initialise()
        panel:instantiate()
        parent:addChild(panel)
        return panel
    end

    self.contentPanel = createPanel(self, sx + pad, sy + pad, sw - pad * 2, sh - pad * 2)

    -- NavPanel removed — breadcrumb navigation provides context

    -- ContextPanel (right sidebar)
    self.contextPanel = createPanel(self, 0, 0, CONTEXT_PANEL_WIDTH, 100)
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
                    "Desktop power lost -- closing terminal")
                POS_TerminalUI.closeTerminal()
                return
            end
        end
    end

    -- Draw content area background
    local sx, sy, sw, sh = self:getScreenRect()
    self:drawRect(sx, sy, sw, sh,
        TERM.bg.a, TERM.bg.r, TERM.bg.g, TERM.bg.b)

    -- Draw header bar background
    local hdr = TERM.headerBg or TERM.bg
    self:drawRect(0, 0, self.width, HEADER_HEIGHT, hdr.a or TERM.bg.a, hdr.r, hdr.g, hdr.b)

    -- Header bottom border
    self:drawRect(0, HEADER_HEIGHT - 1, self.width, 1,
        TERM.border.a, TERM.border.r, TERM.border.g, TERM.border.b)

    -- Header left text: band label
    local bandLabel = self.band == "tactical" and "POSNET_TAC" or "POSNET_OPS"
    local headerTextY = (HEADER_HEIGHT - getTextManager():getFontHeight(HEADER_FONT)) / 2
    self:drawText(bandLabel, 8, headerTextY,
        TERM.header.r, TERM.header.g, TERM.header.b, 1.0, HEADER_FONT)

    -- Header center text: current screen title
    local screenTitle = ""
    local currentScreen = POS_ScreenManager.currentScreen
    if currentScreen then
        local screenDef = POS_Registry and POS_Registry.getScreen and POS_Registry.getScreen(currentScreen)
        if screenDef and screenDef.titleKey then
            screenTitle = PhobosLib.safeGetText(screenDef.titleKey)
        end
    end
    if screenTitle ~= "" then
        local titleW = getTextManager():MeasureStringX(HEADER_FONT, screenTitle)
        local titleX = (self.width - titleW) / 2
        self:drawText(screenTitle, titleX, headerTextY,
            TERM.text.r, TERM.text.g, TERM.text.b, 1.0, HEADER_FONT)
    end

    -- Header right text: status + close button
    local statusText = "SYS READY"
    local closeText = "[X]"
    local closeW = getTextManager():MeasureStringX(HEADER_FONT, closeText)
    local statusW = getTextManager():MeasureStringX(HEADER_FONT, statusText)
    local closeX = self.width - closeW - 8
    local statusX = closeX - statusW - 12
    self:drawText(statusText, statusX, headerTextY,
        TERM.dim.r, TERM.dim.g, TERM.dim.b, 1.0, HEADER_FONT)
    self:drawText(closeText, closeX, headerTextY,
        TERM.header.r, TERM.header.g, TERM.header.b, 1.0, HEADER_FONT)

    -- Store close button hit area for onMouseDown
    self._closeHitX = closeX
    self._closeHitW = closeW

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

    if self.terminalState == "booting" then
        self:renderBoot()
    else
        self:renderScreen()
    end

    -- Draw status bar background
    local statusY = self.height - STATUS_BAR_HEIGHT
    local sbar = TERM.statusBg or TERM.bg
    self:drawRect(0, statusY, self.width, STATUS_BAR_HEIGHT, sbar.a or TERM.bg.a, sbar.r, sbar.g, sbar.b)

    -- Status bar top border
    self:drawRect(0, statusY, self.width, 1,
        TERM.border.a, TERM.border.r, TERM.border.g, TERM.border.b)

    -- Status bar left text: user info
    local player = getPlayer()
    local playerName = player and player:getDisplayName() or "UNKNOWN"
    local playerId = player and tostring(player:getOnlineID()) or "0"
    local statusLeft = string.format("> USER: %s | HID: %s | LINK: ACTIVE", playerName, playerId)
    local statusTextY = statusY + (STATUS_BAR_HEIGHT - getTextManager():getFontHeight(HEADER_FONT)) / 2
    self:drawText(statusLeft, 8, statusTextY,
        TERM.dim.r, TERM.dim.g, TERM.dim.b, 1.0, HEADER_FONT)

    -- Status bar right text: game time + date
    local gt = getGameTime()
    local timeStr = ""
    if gt then
        local hour = gt:getHour()
        local min = gt:getMinutes()
        local day = gt:getDay()
        local month = gt:getMonth() + 1  -- 0-indexed
        local year = gt:getYear()
        timeStr = string.format("%02d:%02d  %02d/%02d/%d", hour, min, day, month, year)
    end
    if timeStr ~= "" then
        local timeW = getTextManager():MeasureStringX(HEADER_FONT, timeStr)
        self:drawText(timeStr, self.width - timeW - 8, statusTextY,
            TERM.dim.r, TERM.dim.g, TERM.dim.b, 1.0, HEADER_FONT)
    end

    -- Scanline effect (subtle, over content area only)
    local scanAlpha = 0.04
    for y = sy, sy + sh - 1, 3 do
        self:drawRect(sx, y, sw, 1,
            scanAlpha, TERM.scan.r, TERM.scan.g, TERM.scan.b)
    end

    -- Phosphor glow effect over content area (subtle)
    local glowAlpha = 0.03
    self:drawRect(sx, sy, sw, sh,
        glowAlpha, TERM.glow.r, TERM.glow.g, TERM.glow.b)
end

function POS_TerminalUI:onMouseDown(x, y)
    -- Close if click is outside window bounds (replaces onMouseDownOutside
    -- which was unreliable when ISButtons are destroyed mid-click)
    if x < 0 or y < 0 or x > self.width or y > self.height then
        self:close()
        return true
    end

    -- Header [X] close button hit test
    if y >= 0 and y <= HEADER_HEIGHT and self._closeHitX then
        if x >= self._closeHitX and x <= self._closeHitX + self._closeHitW then
            self:close()
            return true
        end
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
        PhobosLib.safecall(screen.destroy)
    end
    ISCollapsableWindow.close(self)
    POS_TerminalUI.instance = nil
end

---------------------------------------------------------------
-- Boot sequence rendering
---------------------------------------------------------------

--- Advance boot character reveal and render the boot text.
function POS_TerminalUI:renderBoot()
    if not bootData then initBootData(self) end

    -- Advance character reveal
    if self.bootPauseCountdown < 0 then
        local speed = 1.0
        local gt = getGameTime()
        if gt and gt.getMultiplier then
            speed = gt:getMultiplier()
        end
        self.bootAccumulator = self.bootAccumulator + (bootData.charsPerFrame * speed)
        local chars = math.floor(self.bootAccumulator)
        self.bootAccumulator = self.bootAccumulator - chars
        self.bootCharIndex = math.min(self.bootCharIndex + chars, bootData.totalChars)

        if self.bootCharIndex >= bootData.totalChars then
            self.bootPauseCountdown = bootData.pauseFrames
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

    for i, line in ipairs(bootData.lines) do
        local lineStart = charsSoFar
        local lineEnd = charsSoFar + #line

        if self.bootCharIndex <= lineStart then
            break  -- haven't reached this line yet
        elseif self.bootCharIndex >= lineEnd then
            table.insert(renderedLines, line)
        else
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

    -- Reset boot data so tokens are resolved with fresh connection info
    bootData = nil

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
                            .. "%%/min -- skipping POSnet drain")
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
