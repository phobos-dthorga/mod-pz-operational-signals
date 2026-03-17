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
-- Displays active operations, objectives, and status in a
-- green-on-dark monospace terminal style. Designed to have
-- a gpt-image-1 CRT background texture added later.
---------------------------------------------------------------

require "PhobosLib"

POS_TerminalUI = ISCollapsableWindow:derive("POS_TerminalUI")

--- Singleton instance reference.
POS_TerminalUI.instance = nil

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
    return o
end

---------------------------------------------------------------
-- ISCollapsableWindow overrides
---------------------------------------------------------------

function POS_TerminalUI:initialise()
    ISCollapsableWindow.initialise(self)
end

function POS_TerminalUI:createChildren()
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

    -- Throttle content rebuild (every 30 frames ~ 2/sec)
    self.updateTick = self.updateTick + 1
    if self.updateTick >= 30 then
        self.updateTick = 0
        self:rebuildLines()
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

function POS_TerminalUI:onMouseWheel(del)
    local lh = lineHeight()
    self.scrollOffset = self.scrollOffset + del * lh * 3
    self.scrollOffset = math.max(0, math.min(self.scrollOffset, self.maxScroll))
    return true
end

function POS_TerminalUI:close()
    ISCollapsableWindow.close(self)
    POS_TerminalUI.instance = nil
end

---------------------------------------------------------------
-- Terminal content
---------------------------------------------------------------

--- Rebuild the cached terminal line buffer.
function POS_TerminalUI:rebuildLines()
    local lines = {}

    -- Header block
    table.insert(lines, { text = safeGetText("UI_POS_TerminalHeader"), colour = TERM.header })
    table.insert(lines, { text = string.rep("=", 40), colour = TERM.dim })
    table.insert(lines, {
        text = "> " .. safeGetText("UI_POS_TerminalConnected", self.radioName),
        colour = TERM.text
    })

    local freqMHz = string.format("%.1f", self.frequency / 1000)
    table.insert(lines, {
        text = "> " .. safeGetText("UI_POS_TerminalFrequency", freqMHz),
        colour = TERM.text
    })
    table.insert(lines, { text = "", colour = TERM.text })

    -- Active operations
    local ops = {}
    if POS_OperationLog then
        ops = POS_OperationLog.getByStatus("active")
    end

    table.insert(lines, { text = safeGetText("UI_POS_TerminalActiveOps"), colour = TERM.header })
    table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })

    if #ops == 0 then
        table.insert(lines, { text = "  " .. safeGetText("UI_POS_TerminalNoOps"), colour = TERM.dim })
    else
        for idx, op in ipairs(ops) do
            -- Category and difficulty
            local catKey = "UI_POS_Category_" .. (op.category or "IndustrialRecovery")
            local diffKey = "UI_POS_Difficulty_" .. (op.difficulty or "easy")
            local catName = safeGetText(catKey)
            local diffName = safeGetText(diffKey)

            table.insert(lines, {
                text = "  [" .. idx .. "] " .. catName .. " - " .. diffName,
                colour = TERM.text
            })

            -- Objective progress
            if op.objectives then
                local done = 0
                local total = #op.objectives
                for _, obj in ipairs(op.objectives) do
                    if obj.completed then done = done + 1 end
                end
                table.insert(lines, {
                    text = "      " .. safeGetText("UI_POS_TerminalObjStatus", tostring(done), tostring(total)),
                    colour = done == total and TERM.header or TERM.dim
                })

                -- List individual objectives
                for _, obj in ipairs(op.objectives) do
                    local marker = obj.completed and "[x]" or "[ ]"
                    local desc = obj.description or "?"
                    local c = obj.completed and TERM.dim or TERM.text
                    table.insert(lines, { text = "      " .. marker .. " " .. desc, colour = c })
                end
            end

            -- Expiry info
            if op.expiryDay then
                local gameTime = getGameTime()
                local currentDay = gameTime and gameTime:getNightsSurvived() or 0
                local remaining = op.expiryDay - currentDay
                if remaining <= 1 then
                    table.insert(lines, {
                        text = "      ! Expires soon",
                        colour = TERM.warn
                    })
                end
            end

            table.insert(lines, { text = "", colour = TERM.text })
        end
    end

    -- Summary counts
    table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })
    local counts = POS_OperationLog and POS_OperationLog.getCounts() or {}
    local completed = counts.completed or 0
    local expired = counts.expired or 0
    table.insert(lines, {
        text = safeGetText("UI_POS_TerminalCompleted", tostring(completed))
            .. "  " .. safeGetText("UI_POS_TerminalExpired", tostring(expired)),
        colour = TERM.dim
    })

    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, { text = "> " .. safeGetText("UI_POS_TerminalAwaiting"), colour = TERM.dim })

    self.cachedLines = lines
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
    ui:rebuildLines()

    POS_TerminalUI.instance = ui
end

--- Close the POSnet terminal window.
function POS_TerminalUI.closeTerminal()
    if POS_TerminalUI.instance then
        POS_TerminalUI.instance:close()
        POS_TerminalUI.instance = nil
    end
end
