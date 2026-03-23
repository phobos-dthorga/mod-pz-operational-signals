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
-- POS_SignalPanel.lua
-- Left sidebar: passive intelligence feed ("The world speaks").
-- Read-only, constantly updating, no interaction required.
--
-- Sections:
--   1. Signal Status (strength bar, band, connection)
--   2. Network Devices (radio, satellite, terminal)
--   3. Intel Stream (rolling feed of recent events)
--   4. Background Processes (scan/decode/tick progress)
--
-- Subscribes to POS_Events for real-time updates.
-- See design-guidelines.md §9.2.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_SignalPanel = {}

---------------------------------------------------------------
-- Constants
---------------------------------------------------------------

local SIGNAL_BAR_LENGTH = 10
local THRESHOLD_HIGH = 80
local THRESHOLD_MED  = 50
local THRESHOLD_LOW  = 25

---------------------------------------------------------------
-- Internal state (rolling buffers via PhobosLib)
---------------------------------------------------------------

local _signalFeed   = PhobosLib.createRollingBuffer(POS_Constants.SIGNAL_FEED_MAX_ENTRIES)
local _processFeed  = PhobosLib.createRollingBuffer(POS_Constants.PROCESS_FEED_MAX_ENTRIES)
local _subscribed   = false

---------------------------------------------------------------
-- Signal bar builder (migrated from POS_NavPanel)
---------------------------------------------------------------

--- Build a text-based signal strength bar.
--- @param pct number Signal strength 0-100
--- @return string e.g. "########.."
function POS_SignalPanel.buildSignalBar(pct)
    local filled = math.floor((pct or 0) / SIGNAL_BAR_LENGTH)
    filled = math.max(0, math.min(SIGNAL_BAR_LENGTH, filled))
    local empty = SIGNAL_BAR_LENGTH - filled
    return string.rep("#", filled) .. string.rep(".", empty)
end

---------------------------------------------------------------
-- Event subscription
---------------------------------------------------------------

local function onAmbientIntelReceived(data)
    if not data then return end
    local count = data.count or 0
    local cats = data.categories or {}
    local catStr = #cats > 0 and cats[1] or "mixed"
    _signalFeed:push({
        text = PhobosLib.safeGetText("UI_POS_Signal_Feed_Ambient")
            .. ": " .. tostring(count) .. "x " .. catStr,
        colour = "dim",
    })
end

local function onMarketSnapshotUpdated(data)
    if not data then return end
    _signalFeed:push({
        text = PhobosLib.safeGetText("UI_POS_Signal_Feed_Intel")
            .. ": " .. tostring(data.categoryId or "?"),
        colour = "text",
    })
end

local function onItemDiscovered(data)
    if not data then return end
    local name = PhobosLib.getItemDisplayName(data.fullType) or data.fullType
    _signalFeed:push({
        text = PhobosLib.safeGetText("UI_POS_Signal_Feed_Discovery")
            .. ": " .. tostring(name),
        colour = "success",
    })
end

local function onStockTickClosed(data)
    _signalFeed:push({
        text = PhobosLib.safeGetText("UI_POS_Signal_Feed_EconTick")
            .. " (day " .. tostring(data and data.day or "?") .. ")",
        colour = "dim",
    })
end

local function onBackgroundProcessChanged(data)
    if not data then return end
    if data.complete then
        -- Remove completed process
        local items = _processFeed:getAll()
        for i = #items, 1, -1 do
            if items[i].processId == data.processId then
                table.remove(items, i)
            end
        end
    else
        -- Update or add process
        local found = false
        for _, item in ipairs(_processFeed:getAll()) do
            if item.processId == data.processId then
                item.label = data.label
                item.progress = data.progress
                found = true
                break
            end
        end
        if not found then
            _processFeed:push({
                processId = data.processId,
                label = data.label or "Processing...",
                progress = data.progress or 0,
            })
        end
    end
end

--- Subscribe to POS_Events (called once).
function POS_SignalPanel.subscribe()
    if _subscribed then return end
    _subscribed = true

    if not POS_Events then return end

    if POS_Events.OnAmbientIntelReceived then
        POS_Events.OnAmbientIntelReceived:addListener(onAmbientIntelReceived)
    end
    if POS_Events.OnMarketSnapshotUpdated then
        POS_Events.OnMarketSnapshotUpdated:addListener(onMarketSnapshotUpdated)
    end
    if POS_Events.OnItemDiscovered then
        POS_Events.OnItemDiscovered:addListener(onItemDiscovered)
    end
    if POS_Events.OnStockTickClosed then
        POS_Events.OnStockTickClosed:addListener(onStockTickClosed)
    end
    if POS_Events.OnBackgroundProcessChanged then
        POS_Events.OnBackgroundProcessChanged:addListener(onBackgroundProcessChanged)
    end
end

---------------------------------------------------------------
-- Render
---------------------------------------------------------------

--- Render the signal panel contents.
--- @param panel ISPanel The signal panel ISPanel instance
--- @param terminal table The POS_TerminalUI instance
function POS_SignalPanel.render(panel, terminal)
    POS_SignalPanel.subscribe()

    POS_TerminalWidgets.clearPanel(panel)

    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local lineH = getTextManager():getFontHeight(UIFont.Code) + 2
    local y = 0
    local pw = panel:getWidth()
    local charCount = math.floor(pw / (getTextManager():getFontHeight(UIFont.Code) * 0.55))

    -- ── Section 1: Signal Status ────────────────────────────
    W.createLabel(panel, 4, y,
        PhobosLib.safeGetText("UI_POS_Signal_Header"), C.textBright)
    y = y + lineH

    -- Signal strength
    local signalPct = math.floor((terminal.signalStrength or 0) * 100)
    local signalBar = POS_SignalPanel.buildSignalBar(signalPct)
    local signalColour = signalPct >= THRESHOLD_HIGH and C.success
        or signalPct >= THRESHOLD_MED and C.text
        or signalPct >= THRESHOLD_LOW and C.warn
        or C.error
    W.createLabel(panel, 4, y,
        PhobosLib.safeGetText("UI_POS_Signal_Strength")
            .. ": " .. signalBar .. " " .. signalPct .. "%", signalColour)
    y = y + lineH

    -- Band
    local bandLabel = terminal.band == "tactical"
        and PhobosLib.safeGetText("UI_POS_Band_Tactical")
        or PhobosLib.safeGetText("UI_POS_Band_Operations")
    W.createLabel(panel, 4, y,
        PhobosLib.safeGetText("UI_POS_Signal_Band") .. ": " .. bandLabel, C.dim)
    y = y + lineH

    -- Connection status
    local connected = terminal.connected ~= false
    local statusText = connected
        and PhobosLib.safeGetText("UI_POS_Signal_Status_Active")
        or PhobosLib.safeGetText("UI_POS_Signal_Status_Idle")
    local statusColour = connected and C.success or C.dim
    W.createLabel(panel, 4, y, statusText, statusColour)
    y = y + lineH

    W.createSeparator(panel, 4, y, charCount, "-")
    y = y + lineH

    -- ── Section 2: Intel Stream ─────────────────────────────
    W.createLabel(panel, 4, y,
        PhobosLib.safeGetText("UI_POS_Signal_Feed"), C.textBright)
    y = y + lineH

    local feedItems = _signalFeed:getAll()
    if #feedItems == 0 then
        W.createLabel(panel, 4, y,
            PhobosLib.safeGetText("UI_POS_Signal_Feed_Empty"), C.dim)
        y = y + lineH
    else
        -- Show newest first, max fitting in available space
        local maxFeedLines = math.max(3, math.floor((panel:getHeight() - y - lineH * 5) / lineH))
        for i = 1, math.min(#feedItems, maxFeedLines) do
            local item = feedItems[i]
            local colour = item.colour and C[item.colour] or C.dim
            W.createLabel(panel, 4, y, item.text or "", colour)
            y = y + lineH
        end
    end

    W.createSeparator(panel, 4, y, charCount, "-")
    y = y + lineH

    -- ── Section 3: Background Processes ─────────────────────
    W.createLabel(panel, 4, y,
        PhobosLib.safeGetText("UI_POS_Signal_Processes"), C.textBright)
    y = y + lineH

    local processItems = _processFeed:getAll()
    if #processItems == 0 then
        W.createLabel(panel, 4, y, "---", C.dim)
    else
        for _, proc in ipairs(processItems) do
            local pct = proc.progress or 0
            local bar = POS_SignalPanel.buildSignalBar(pct)
            W.createLabel(panel, 4, y,
                tostring(proc.label) .. " " .. bar .. " " .. pct .. "%", C.dim)
            y = y + lineH
        end
    end
end
