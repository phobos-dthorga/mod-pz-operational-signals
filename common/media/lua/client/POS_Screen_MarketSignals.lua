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
-- POS_Screen_MarketSignals.lua
-- Consolidated chronological feed combining hard market events
-- and soft rumours with filter tabs + ContextPanel detail view.
-- Absorbs the Event Log functionality (§33.4 consolidation).
-- Replaces: POS_Screen_EventLog + POS_Screen_BBSRumours
--
-- Filter tabs: All | Hard Events | Rumours | Structural
-- ContextPanel: full detail when a signal entry is selected
---------------------------------------------------------------

require "PhobosLib"
require "PhobosLib_DualTab"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_WorldState"
require "POS_RumourGenerator"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local _TAG = "[POS:MarketSignals]"

--- Filter state
local _activeFilter = "all"  -- "all" | "hard" | "soft" | "structural"
local _selectedSignalIdx = nil
local _lastMerged = {}  -- cached for ContextPanel access

--- Filter tab definitions
local FILTER_TABS = {
    { id = "all",        labelKey = "UI_POS_Signals_FilterAll" },
    { id = "hard",       labelKey = "UI_POS_Signals_FilterHard" },
    { id = "soft",       labelKey = "UI_POS_Signals_FilterSoft" },
    { id = "structural", labelKey = "UI_POS_Signals_FilterStructural" },
}

--- Signal class badge map (using POS_Constants)
local CLASS_DISPLAY = {
    [POS_Constants.SIGNAL_CLASS_HARD]       = { badge = "HARD",       colourKey = "textBright" },
    [POS_Constants.SIGNAL_CLASS_SOFT]       = { badge = "SOFT",       colourKey = "teal" },
    [POS_Constants.SIGNAL_CLASS_STRUCTURAL] = { badge = "STRUCTURAL", colourKey = "error" },
}

--- Teal colour (custom, not in standard COLOURS)
local COLOUR_TEAL = { r = 0.4, g = 0.8, b = 0.8, a = 1 }

local function _getSignalColour(signalClass, C)
    local info = CLASS_DISPLAY[signalClass]
    if not info then return C.dim end
    if info.colourKey == "teal" then return COLOUR_TEAL end
    return C[info.colourKey] or C.text
end

local function _getSignalBadge(signalClass)
    local info = CLASS_DISPLAY[signalClass]
    return info and info.badge or "?"
end

---------------------------------------------------------------
-- Data collection
---------------------------------------------------------------

local function _collectHardEvents()
    local world = POS_WorldState.getWorld()
    local events = (world and world.recentEvents) or {}
    local result = {}

    if type(events) == "table" then
        for _, v in pairs(events) do
            if type(v) == "table" then
                result[#result + 1] = {
                    day          = v.day or 0,
                    signalClass  = v.signalClass or POS_Constants.SIGNAL_CLASS_HARD,
                    typeKey      = v.typeKey or v.type or "???",
                    zone         = v.zoneId or v.zone or "???",
                    categories   = v.categories,
                    pressure     = v.pressure,
                    expiryDay    = v.expiryDay,
                    source       = "event",
                }
            end
        end
    end
    return result
end

local function _collectRumours(currentDay)
    local result = {}
    if not POS_RumourGenerator or not POS_RumourGenerator.getActiveRumours then
        return result
    end

    local rumours = POS_RumourGenerator.getActiveRumours(currentDay) or {}
    for _, r in pairs(rumours) do
        if type(r) == "table" then
            local expiryDay = r.expiryDay or currentDay
            local daysLeft = math.max(0, expiryDay - currentDay)

            result[#result + 1] = {
                day          = r.recordedDay or r.day or currentDay,
                signalClass  = POS_Constants.SIGNAL_CLASS_SOFT,
                typeKey      = r.messageKey or "UI_POS_BBS_UnknownRumour",
                zone         = r.regionId or r.region or "???",
                categories   = r.categoryIds or r.categories or "???",
                impactHint   = r.impactHint,
                daysLeft     = daysLeft,
                reliability  = r.confidence or r.reliability or "medium",
                source       = "rumour",
            }
        end
    end
    return result
end

local function _mergeAndFilter(currentDay, filter)
    local merged = {}

    local hardEvents = _collectHardEvents()
    for _, entry in ipairs(hardEvents) do
        merged[#merged + 1] = entry
    end

    local rumours = _collectRumours(currentDay)
    for _, entry in ipairs(rumours) do
        merged[#merged + 1] = entry
    end

    -- Sort newest first
    table.sort(merged, function(a, b) return (a.day or 0) > (b.day or 0) end)

    -- Apply filter
    if filter and filter ~= "all" then
        local filtered = {}
        for _, entry in ipairs(merged) do
            if entry.signalClass == filter then
                filtered[#filtered + 1] = entry
            end
        end
        return filtered
    end

    return merged
end

---------------------------------------------------------------
-- Screen definition
---------------------------------------------------------------

local screen = {}
screen.id        = "pos.markets.signals"
screen.menuPath  = {"pos.markets"}
screen.titleKey  = "UI_POS_MarketSignals_Title"
screen.sortOrder = 20

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    _activeFilter = (params and params.filter) or _activeFilter or "all"

    W.drawHeader(ctx, "UI_POS_MarketSignals_Title")

    -- Filter tab bar (PhobosLib_DualTab)
    ctx.y = PhobosLib_DualTab.createSingle({
        panel   = ctx.panel,
        y       = ctx.y,
        tabs1   = FILTER_TABS,
        active1 = _activeFilter,
        colours = C,
        btnH    = ctx.btnH,
        _W      = W,
        onTabChange = function(tab1)
            _activeFilter = tab1
            _selectedSignalIdx = nil
            POS_ScreenManager.replaceCurrent(screen.id, { filter = tab1 })
        end,
    })

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Merge + filter signals
    local currentDay = getGameTime():getNightsSurvived()
    local merged = _mergeAndFilter(currentDay, _activeFilter)
    _lastMerged = merged  -- cache for ContextPanel

    if #merged == 0 then
        -- Check if Living Market is disabled — explain why no signals
        local livingMarketEnabled = POS_Sandbox
            and POS_Sandbox.isLivingMarketEnabled
            and POS_Sandbox.isLivingMarketEnabled()
        if not livingMarketEnabled then
            W.createLabel(ctx.panel, 8, ctx.y,
                PhobosLib.safeGetText("UI_POS_LivingMarket_Disabled"), C.warning)
            ctx.y = ctx.y + ctx.lineH * 2
        else
            local emptyKey = _activeFilter == "all"
                and "UI_POS_Signals_WaitForTick"
                or "UI_POS_Signals_NoMatch"
            W.createLabel(ctx.panel, 8, ctx.y, PhobosLib.safeGetText(emptyKey), C.dim)
            ctx.y = ctx.y + ctx.lineH
        end
    else
        local currentPage = (params and params.signalPage) or 1
        local filterCopy = _activeFilter

        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = merged,
            pageSize = POS_Constants.SIGNALS_PAGE_SIZE,
            currentPage = currentPage,
            x = ctx.btnX, y = ctx.y, width = ctx.btnW,
            colours = { text = C.text, dim = C.dim, bgDark = C.bgDark,
                        bgHover = C.bgHover, border = C.border },
            renderItem = function(parent, rx, ry, rw, entry, idx)
                local itemY = 0
                local signalClass = entry.signalClass or POS_Constants.SIGNAL_CLASS_SOFT
                local signalColour = _getSignalColour(signalClass, C)

                -- Line 1: Day + [BADGE] + event type
                local dayStr = PhobosLib.safeGetText("UI_POS_MarketSignals_Day")
                    .. " " .. tostring(entry.day or 0)
                W.createLabel(parent, rx, ry + itemY, dayStr, C.text)

                local badgeX = rx + POS_Constants.SIGNALS_BADGE_OFFSET
                local badge = _getSignalBadge(signalClass)
                PhobosLib.createStatusBadge(parent, badgeX, ry + itemY,
                    "[" .. badge .. "]", signalColour)

                local typeX = badgeX + POS_Constants.SIGNALS_TYPE_OFFSET
                W.createLabel(parent, typeX, ry + itemY,
                    PhobosLib.safeGetText(entry.typeKey), C.text)
                itemY = itemY + ctx.lineH

                -- Line 2: zone + categories + meta
                local cats = entry.categories
                if type(cats) == "table" then cats = table.concat(cats, ", ") end
                cats = cats or "???"

                local detailLine = (entry.zone or "???") .. " -- " .. cats
                W.createLabel(parent, rx + 12, ry + itemY, detailLine, C.dim)

                if entry.source == "rumour" and entry.impactHint then
                    local meta = "  |  "
                        .. PhobosLib.safeGetText("UI_POS_Signals_Impact")
                        .. ": " .. entry.impactHint
                    if entry.daysLeft then
                        meta = meta .. "  |  " .. tostring(entry.daysLeft) .. "d "
                            .. PhobosLib.safeGetText("UI_POS_Signals_Remaining")
                    end
                    W.createLabel(parent, rx + 12 +
                        getTextManager():MeasureStringX(UIFont.Small, detailLine),
                        ry + itemY, meta, C.dim)
                end
                itemY = itemY + ctx.lineH

                -- Select button
                local entryIdx = idx
                local isSelected = (_selectedSignalIdx == entryIdx)
                W.createButton(parent, rx, ry + itemY, rw, ctx.btnH,
                    isSelected and "> SELECTED"
                        or PhobosLib.safeGetText("UI_POS_Screen_ViewDetails"),
                    isSelected and C.textBright or nil,
                    function()
                        _selectedSignalIdx = entryIdx
                        POS_ScreenManager.refreshCurrentScreen()
                    end)
                itemY = itemY + ctx.btnH + 4

                return itemY
            end,
            onPageChange = function(newPage)
                _selectedSignalIdx = nil
                POS_ScreenManager.replaceCurrent(screen.id,
                    { filter = filterCopy, signalPage = newPage })
            end,
        })
    end

    W.drawFooter(ctx)
end

---------------------------------------------------------------
-- ContextPanel: signal detail view
---------------------------------------------------------------

screen.getContextData = function(_params)
    local data = {}

    local entry = _selectedSignalIdx and _lastMerged[_selectedSignalIdx]

    if not entry then
        table.insert(data, { type = "header", text = "UI_POS_MarketSignals_Title" })
        table.insert(data, { type = "kv",
            key = "", value = PhobosLib.safeGetText("UI_POS_Signals_NoDetail") })

        -- Summary counts
        local currentDay = getGameTime():getNightsSurvived()
        local world = POS_WorldState.getWorld()
        local events = (world and world.recentEvents) or {}
        local eventCount = 0
        for _ in pairs(events) do eventCount = eventCount + 1 end

        local rumourCount = 0
        if POS_RumourGenerator and POS_RumourGenerator.getRumourCount then
            local ok, ct = PhobosLib.safecall(POS_RumourGenerator.getRumourCount, currentDay)
            if ok and type(ct) == "number" then rumourCount = ct end
        end

        table.insert(data, { type = "separator" })
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Signals_FilterHard"),
            value = tostring(eventCount) })
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Signals_FilterSoft"),
            value = tostring(rumourCount) })
        return data
    end

    -- Signal detail
    local badge = _getSignalBadge(entry.signalClass)
    table.insert(data, { type = "header",
        text = "[" .. badge .. "] " .. PhobosLib.safeGetText(entry.typeKey) })
    table.insert(data, { type = "separator" })

    -- Zone
    local zoneName = entry.zone or "???"
    if POS_MarketSimulation and POS_MarketSimulation.getZoneRegistry then
        zoneName = PhobosLib.getRegistryDisplayName(
            POS_MarketSimulation.getZoneRegistry(), entry.zone, zoneName)
    end
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Zone"),
        value = zoneName })

    -- Categories
    local cats = entry.categories
    if type(cats) == "table" then cats = table.concat(cats, ", ") end
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Categories"),
        value = cats or "???" })

    -- Day
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_MarketSignals_Day"),
        value = tostring(entry.day or 0) })

    if entry.source == "event" then
        -- Hard event detail
        if entry.pressure then
            local arrow = entry.pressure > 0 and "+" or ""
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_Signals_Pressure"),
                value = arrow .. string.format("%.0f%%", entry.pressure * 100),
                colour = entry.pressure > 0 and "error" or "success" })
        end

        if entry.expiryDay then
            local currentDay = getGameTime():getNightsSurvived()
            local remaining = entry.expiryDay - currentDay
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_Signals_Duration"),
                value = tostring(remaining) .. "d "
                    .. PhobosLib.safeGetText("UI_POS_Signals_Remaining"),
                colour = remaining <= 1 and "warning" or nil })
        end

    elseif entry.source == "rumour" then
        -- Rumour detail
        if entry.impactHint then
            local impactColour = entry.impactHint == "shortage" and "error"
                or (entry.impactHint == "surplus" and "success" or "warning")
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_Signals_Impact"),
                value = entry.impactHint, colour = impactColour })
        end

        if entry.reliability then
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_Signals_Reliability"),
                value = entry.reliability })
        end

        if entry.daysLeft then
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_Signals_Remaining"),
                value = tostring(entry.daysLeft) .. "d",
                colour = entry.daysLeft <= 1 and "warning" or nil })
        end
    end

    return data
end

---------------------------------------------------------------

screen.destroy = function()
    _selectedSignalIdx = nil
    _lastMerged = {}
    POS_TerminalWidgets.defaultDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------
-- Starlit reactive refresh
---------------------------------------------------------------

if POS_Events and POS_Events.OnMarketEvent then
    POS_Events.OnMarketEvent:addListener(function()
        if POS_ScreenManager.currentScreen == screen.id then
            POS_ScreenManager.refreshCurrentScreen()
        end
    end)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
