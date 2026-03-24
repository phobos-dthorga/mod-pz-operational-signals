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
-- (from POS_WorldState) and soft rumours (from POS_RumourGenerator)
-- into a single paginated signal log.
-- Replaces: POS_Screen_EventLog + POS_Screen_BBSRumours
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_WorldState"
require "POS_RumourGenerator"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local _TAG = "[POS:MarketSignals]"

--- Signal class constants for entry tagging.
local SIGNAL_CLASS_HARD       = "Hard"
local SIGNAL_CLASS_SOFT       = "Soft"
local SIGNAL_CLASS_STRUCTURAL = "Structural"

--- Page size for the merged signal feed.
local PAGE_SIZE = 8

--- Teal colour for soft signals.
local COLOUR_TEAL = { r = 0.4, g = 0.8, b = 0.8, a = 1 }

--- Get the colour for a signal class.
---@param signalClass string  "Hard", "Soft", or "Structural"
---@param C table             COLOURS table from TerminalWidgets
---@return table              RGBA colour
local function _getSignalColour(signalClass, C)
    if signalClass == SIGNAL_CLASS_HARD then
        return C.textBright
    elseif signalClass == SIGNAL_CLASS_SOFT then
        return COLOUR_TEAL
    elseif signalClass == SIGNAL_CLASS_STRUCTURAL then
        return C.error
    end
    return C.dim
end

--- Get the translation key for a signal class badge.
---@param signalClass string  "Hard", "Soft", or "Structural"
---@return string             Translation key
local function _getSignalBadgeKey(signalClass)
    if signalClass == SIGNAL_CLASS_HARD then
        return "UI_POS_MarketSignals_Hard"
    elseif signalClass == SIGNAL_CLASS_SOFT then
        return "UI_POS_MarketSignals_Soft"
    elseif signalClass == SIGNAL_CLASS_STRUCTURAL then
        return "UI_POS_MarketSignals_Structural"
    end
    return "UI_POS_MarketSignals_Soft"
end

---------------------------------------------------------------
-- Data merging
---------------------------------------------------------------

--- Collect hard events from world state into a normalised array.
---@param currentDay number  Current game day
---@return table[]           Array of signal entries
local function _collectHardEvents(currentDay)
    local world = POS_WorldState.getWorld()
    local events = (world and world.recentEvents) or {}
    local result = {}

    if type(events) == "table" then
        for _, v in pairs(events) do
            if type(v) == "table" then
                local signalClass = v.signalClass or SIGNAL_CLASS_HARD
                table.insert(result, {
                    day         = v.day or 0,
                    signalClass = signalClass,
                    typeKey     = v.typeKey or v.type or "???",
                    zone        = v.zoneId or v.zone or "???",
                    categories  = v.categories,
                    source      = "event",
                })
            end
        end
    end

    return result
end

--- Collect soft rumours into a normalised array.
---@param currentDay number  Current game day
---@return table[]           Array of signal entries
local function _collectRumours(currentDay)
    local result = {}

    if not POS_RumourGenerator or not POS_RumourGenerator.getActiveRumours then
        return result
    end

    local rumours = POS_RumourGenerator.getActiveRumours(currentDay) or {}
    for _, r in ipairs(rumours) do
        local expiryDay = r.expiryDay or currentDay
        local daysLeft  = expiryDay - currentDay
        if daysLeft < 0 then daysLeft = 0 end

        table.insert(result, {
            day         = r.day or currentDay,
            signalClass = SIGNAL_CLASS_SOFT,
            typeKey     = r.messageKey or "UI_POS_BBS_UnknownRumour",
            zone        = r.region or "???",
            categories  = r.categories or "???",
            impactHint  = r.impactHint,
            daysLeft    = daysLeft,
            source      = "rumour",
        })
    end

    return result
end

---------------------------------------------------------------
-- Screen definition
---------------------------------------------------------------

local screen = {}
screen.id        = "pos.markets.signals"
screen.menuPath  = {"pos.markets"}
screen.titleKey  = "UI_POS_MarketSignals_Title"
screen.sortOrder = 20

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_MarketSignals_Title")

    -- Merge events + rumours
    local currentDay = getGameTime():getNightsSurvived()
    local merged = {}

    local hardEvents = _collectHardEvents(currentDay)
    for _, entry in ipairs(hardEvents) do
        table.insert(merged, entry)
    end

    local rumours = _collectRumours(currentDay)
    for _, entry in ipairs(rumours) do
        table.insert(merged, entry)
    end

    -- Sort by day descending (newest first)
    table.sort(merged, function(a, b)
        return (a.day or 0) > (b.day or 0)
    end)

    if #merged == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_MarketSignals_NoSignals"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (_params and _params.signalPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = merged,
            pageSize = PAGE_SIZE,
            currentPage = currentPage,
            x = ctx.btnX,
            y = ctx.y,
            width = ctx.btnW,
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, rw, entry, _idx)
                local itemY = 0
                local signalClass = entry.signalClass or SIGNAL_CLASS_SOFT
                local signalColour = _getSignalColour(signalClass, C)

                -- Line 1: Day number + signal class badge + event type
                local dayStr = W.safeGetText("UI_POS_MarketSignals_Day",
                    tostring(entry.day or 0))
                local badgeText = W.safeGetText(_getSignalBadgeKey(signalClass))
                local eventType = W.safeGetText(entry.typeKey)

                -- Render day label
                W.createLabel(parent, rx, ry + itemY, dayStr, C.text)

                -- Signal class badge (coloured)
                local badgeX = rx + 60
                PhobosLib.createStatusBadge(parent, badgeX, ry + itemY,
                    "[" .. badgeText .. "]", signalColour)

                -- Event type (after badge)
                local typeX = badgeX + 100
                W.createLabel(parent, typeX, ry + itemY, eventType, C.text)
                itemY = itemY + ctx.lineH

                -- Line 2 (dim, indented): zone + affected categories
                local cats = entry.categories
                if type(cats) == "table" then
                    cats = table.concat(cats, ", ")
                end
                cats = cats or "???"

                local detailLine = entry.zone .. " — " .. cats
                W.createLabel(parent, rx + 12, ry + itemY, detailLine, C.dim)

                -- For rumours: append impact hint and days remaining
                if entry.source == "rumour" then
                    local metaParts = {}
                    if entry.impactHint then
                        table.insert(metaParts,
                            W.safeGetText("UI_POS_MarketSignals_Impact")
                            .. ": " .. entry.impactHint)
                    end
                    if entry.daysLeft then
                        table.insert(metaParts,
                            W.safeGetText("UI_POS_MarketSignals_DaysLeft",
                                tostring(entry.daysLeft)))
                    end
                    if #metaParts > 0 then
                        local metaStr = "  |  " .. table.concat(metaParts, "  |  ")
                        W.createLabel(parent, rx + 12 +
                            getTextManager():MeasureStringX(UIFont.Small, detailLine),
                            ry + itemY, metaStr, C.dim)
                    end
                end
                itemY = itemY + ctx.lineH

                return itemY + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent("pos.markets.signals",
                    { signalPage = newPage })
            end,
        })
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.getContextData = function(_params)
    local data = {}
    local currentDay = getGameTime():getNightsSurvived()

    -- Count events
    local world = POS_WorldState.getWorld()
    local events = (world and world.recentEvents) or {}
    local eventCount = 0
    for _ in pairs(events) do
        eventCount = eventCount + 1
    end

    -- Count rumours
    local rumourCount = 0
    if POS_RumourGenerator and POS_RumourGenerator.getRumourCount then
        rumourCount = PhobosLib.safecall(POS_RumourGenerator.getRumourCount, currentDay) or 0
    end

    local totalCount = eventCount + rumourCount
    if totalCount > 0 then
        table.insert(data, { type = "kv", key = "UI_POS_MarketSignals_Title",
            value = tostring(totalCount) })
    end
    return data
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

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
