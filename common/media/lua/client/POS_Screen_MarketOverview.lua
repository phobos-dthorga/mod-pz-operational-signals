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
-- POS_Screen_MarketOverview.lua
-- Consolidated 3-tab market dashboard:
--   Tab 1: Summary — categories, top pressures, health
--   Tab 2: Zones — full zone pressure bars, events, agents
--   Tab 3: Exchange — commodity indices, sentiment, trends
--
-- Absorbs: ZoneOverview + Stockmarket (both deleted)
-- Uses PhobosLib_DualTab for consistent tab rendering.
-- Subscribes to Starlit events for reactive refresh.
--
-- See design-guidelines.md §33, §48.
---------------------------------------------------------------

require "PhobosLib"
require "PhobosLib_DualTab"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketRegistry"
require "POS_MarketDatabase"
require "POS_MarketService"
require "POS_MarketSimulation"
require "POS_EventService"
require "POS_ExchangeEngine"
require "POS_WorldState"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local _TAG = "[POS:MarketOverview]"
local _activeTab = "summary"

local TAB_DEFS = {
    { id = "summary",  labelKey = "UI_POS_MarketOverview_TabSummary" },
    { id = "zones",    labelKey = "UI_POS_MarketOverview_TabZones" },
    { id = "exchange", labelKey = "UI_POS_MarketOverview_TabExchange" },
}

local screen = {}
screen.id = POS_Constants.SCREEN_MARKET_OVERVIEW
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_MarketOverview_Title"
screen.sortOrder = 5

---------------------------------------------------------------
-- Shared helpers
---------------------------------------------------------------

local function _trendArrow(trendKey)
    if trendKey == "UI_POS_Market_Trend_Rising" then return "\226\134\145" end
    if trendKey == "UI_POS_Market_Trend_Falling" then return "\226\134\147" end
    return "\226\134\146"
end

local function _trendColour(trendKey, C)
    if trendKey == "UI_POS_Market_Trend_Rising" then return C.success or C.text end
    if trendKey == "UI_POS_Market_Trend_Falling" then return C.warn or C.text end
    return C.dim or C.text
end

local function _getPressureColour(pressure, C)
    if pressure < -POS_Constants.PRESSURE_COLOUR_THRESHOLD then return C.success or C.text end
    if pressure > POS_Constants.PRESSURE_COLOUR_THRESHOLD then return C.warn or C.text end
    return C.text
end

local function _getPressureLabelKey(pressure)
    if pressure < -POS_Constants.PRESSURE_COLOUR_THRESHOLD then return "UI_POS_Zone_PressureSurplus" end
    if pressure > POS_Constants.PRESSURE_COLOUR_THRESHOLD then return "UI_POS_Zone_PressureShortage" end
    return "UI_POS_Zone_PressureNeutral"
end

local function _getTopPressures(zoneState)
    local entries = {}
    if not zoneState or not zoneState.pressure then return entries end
    for catId, val in pairs(zoneState.pressure) do
        entries[#entries + 1] = { catId = catId, pressure = val }
    end
    table.sort(entries, function(a, b)
        return math.abs(a.pressure) > math.abs(b.pressure)
    end)
    local top = {}
    for i = 1, math.min(POS_Constants.ZONE_TOP_PRESSURES, #entries) do
        top[i] = entries[i]
    end
    return top
end

local function buildPressureBar(pressure, maxWidth)
    local pct = PhobosLib.clamp(
        (pressure + POS_Constants.PRESSURE_NORM_OFFSET)
        / POS_Constants.PRESSURE_NORM_DIVISOR, 0, 1)
    local filled = math.floor(pct * maxWidth)
    local empty = maxWidth - filled
    return "[" .. string.rep("#", filled) .. string.rep("-", empty) .. "] "
        .. tostring(math.floor(pct * 100)) .. "%"
end

---------------------------------------------------------------
-- Tab A: Summary
---------------------------------------------------------------

local function renderSummary(ctx, params)
    local W = POS_TerminalWidgets
    local C = W.COLOURS

    -- Categories (paginated)
    W.createLabel(ctx.panel, 0, ctx.y,
        "=== " .. W.safeGetText("UI_POS_MarketOverview_Categories") .. " ===",
        C.textBright)
    ctx.y = ctx.y + ctx.lineH

    local categories = POS_MarketRegistry.getVisibleCategories({})

    if #categories == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (params and params.catPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = categories,
            pageSize = POS_Constants.PAGE_SIZE_MARKET_OVERVIEW,
            currentPage = currentPage,
            x = ctx.btnX, y = ctx.y, width = ctx.btnW,
            colours = { text = C.text, dim = C.dim, bgDark = C.bgDark,
                        bgHover = C.bgHover, border = C.border },
            renderItem = function(parent, rx, ry, rw, cat, _idx)
                local summary = POS_MarketService.getCommoditySummary(cat.id)
                local catLabel = W.safeGetText(cat.labelKey)
                local priceStr = "\226\128\148"
                local arrow = ""
                local freshnessStr = ""
                local sourceStr = ""

                if summary then
                    if summary.avgPrice and summary.avgPrice > 0 then
                        priceStr = "$" .. tostring(math.floor(summary.avgPrice + 0.5))
                    end
                    arrow = _trendArrow(summary.trendKey)
                    if summary.freshnessKey then
                        freshnessStr = " [" .. W.safeGetText(summary.freshnessKey) .. "]"
                    end
                    sourceStr = tostring(summary.sourceCount or 0) .. " "
                        .. W.safeGetText("UI_POS_Market_Sources")
                end

                local label = catLabel .. " \226\128\148 " .. priceStr
                    .. " " .. arrow .. freshnessStr .. "  " .. sourceStr
                local catId = cat.id
                W.createButton(parent, rx, ry, rw, ctx.btnH, label, nil,
                    function()
                        POS_ScreenManager.navigateTo(
                            POS_Constants.SCREEN_COMMODITY_DETAIL,
                            { categoryId = catId })
                    end)
                return ctx.btnH + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(screen.id,
                    { tab = "summary", catPage = newPage })
            end,
        })
    end

    ctx.y = ctx.y + 4

    -- Zone pressure
    W.createLabel(ctx.panel, 0, ctx.y,
        "=== " .. W.safeGetText("UI_POS_MarketOverview_ZonePressure") .. " ===",
        C.textBright)
    ctx.y = ctx.y + ctx.lineH

    local zoneRegistry = POS_MarketSimulation.getZoneRegistry()
    local zones = {}
    if zoneRegistry and zoneRegistry.getAll then
        for _, def in pairs(zoneRegistry:getAll() or {}) do
            zones[#zones + 1] = def
        end
    end
    table.sort(zones, function(a, b) return (a.id or "") < (b.id or "") end)

    for _, zoneDef in ipairs(zones) do
        local zoneName = PhobosLib.getRegistryDisplayName(
            zoneRegistry, zoneDef.id, zoneDef.id)
        local zoneState = POS_MarketSimulation.getZoneState
            and POS_MarketSimulation.getZoneState(zoneDef.id)

        W.createLabel(ctx.panel, 8, ctx.y, zoneName, C.text)
        ctx.y = ctx.y + ctx.lineH

        local topPressures = _getTopPressures(zoneState)
        if #topPressures > 0 then
            local parts = {}
            for _, entry in ipairs(topPressures) do
                parts[#parts + 1] = entry.catId .. "=" .. W.safeGetText(_getPressureLabelKey(entry.pressure))
            end
            W.createLabel(ctx.panel, 8, ctx.y,
                "  " .. table.concat(parts, ", "),
                _getPressureColour(topPressures[1].pressure, C))
        else
            W.createLabel(ctx.panel, 8, ctx.y,
                "  " .. W.safeGetText("UI_POS_Zone_NoData"), C.dim)
        end
        ctx.y = ctx.y + ctx.lineH
    end
    ctx.y = ctx.y + 4

    -- Health summary
    W.createLabel(ctx.panel, 0, ctx.y,
        "=== " .. W.safeGetText("UI_POS_MarketOverview_Health") .. " ===",
        C.textBright)
    ctx.y = ctx.y + ctx.lineH

    local totalObs = 0
    local totalConf, confCount = 0, 0
    for _, cat in ipairs(categories) do
        local s = POS_MarketService.getCommoditySummary(cat.id)
        if s then
            totalObs = totalObs + (s.sourceCount or 0)
            if s.confidenceKey then
                confCount = confCount + 1
                if s.confidenceKey == "UI_POS_Market_Confidence_High" then totalConf = totalConf + 3
                elseif s.confidenceKey == "UI_POS_Market_Confidence_Medium" then totalConf = totalConf + 2
                elseif s.confidenceKey == "UI_POS_Market_Confidence_Low" then totalConf = totalConf + 1 end
            end
        end
    end

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_MarketOverview_TotalObservations") .. ": " .. tostring(totalObs), C.text)
    ctx.y = ctx.y + ctx.lineH

    local avgConfLabel = "\226\128\148"
    if confCount > 0 then
        local avgScore = totalConf / confCount
        if avgScore >= POS_Constants.CONFIDENCE_HIGH_THRESHOLD then
            avgConfLabel = W.safeGetText("UI_POS_Market_Confidence_High")
        elseif avgScore >= POS_Constants.CONFIDENCE_MEDIUM_THRESHOLD then
            avgConfLabel = W.safeGetText("UI_POS_Market_Confidence_Medium")
        else
            avgConfLabel = W.safeGetText("UI_POS_Market_Confidence_Low")
        end
    end

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_MarketOverview_AvgConfidence") .. ": " .. avgConfLabel, C.text)
    ctx.y = ctx.y + ctx.lineH
end

---------------------------------------------------------------
-- Tab B: Zone Detail (absorbed from ZoneOverview)
---------------------------------------------------------------

local function renderZones(ctx, _params)
    local W = POS_TerminalWidgets
    local C = W.COLOURS

    local zones = POS_Constants.MARKET_ZONES or {}
    local currentDay = getGameTime() and getGameTime():getNightsSurvived() or 0

    for _, zoneId in ipairs(zones) do
        local zoneName = zoneId
        local zoneDef = nil
        if POS_MarketSimulation and POS_MarketSimulation.getZoneRegistry then
            zoneDef = POS_MarketSimulation.getZoneRegistry():get(zoneId)
            if zoneDef and zoneDef.name then zoneName = zoneDef.name end
        end

        W.createLabel(ctx.panel, 0, ctx.y, zoneName, C.textBright)
        ctx.y = ctx.y + ctx.lineH

        local pop = zoneDef and zoneDef.population or "unknown"
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_ZoneOverview_Population") .. ": " .. pop, C.dim)
        ctx.y = ctx.y + ctx.lineH

        local zoneState = POS_MarketSimulation.getZoneState
            and POS_MarketSimulation.getZoneState(zoneId)
        local pressure = zoneState and zoneState.pressure or 0
        local pressureBar = buildPressureBar(pressure, POS_Constants.ZONE_PRESSURE_BAR_WIDTH)
        local pressureColour = pressure > POS_Constants.PRESSURE_HIGH_THRESHOLD and C.error
            or (pressure > 0 and C.warning or C.text)
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_ZoneOverview_Pressure") .. ": " .. pressureBar,
            pressureColour)
        ctx.y = ctx.y + ctx.lineH

        local agents = POS_MarketSimulation.getAgentsForZone
            and POS_MarketSimulation.getAgentsForZone(zoneId) or {}
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_ZoneOverview_Agents") .. ": " .. tostring(#agents), C.dim)
        ctx.y = ctx.y + ctx.lineH

        local events = POS_EventService and POS_EventService.getActiveEventsForZone
            and POS_EventService.getActiveEventsForZone(zoneId, currentDay) or {}
        for _, ev in ipairs(events) do
            local evName = PhobosLib.safeGetText(ev.displayNameKey or "?")
            local daysLeft = (ev.expiryDay or 0) - currentDay
            W.createLabel(ctx.panel, 16, ctx.y,
                "[" .. (ev.signalClass or "?"):upper() .. "] "
                .. evName .. " (" .. tostring(daysLeft) .. "d)",
                ev.signalClass == POS_Constants.SIGNAL_CLASS_HARD and C.textBright or C.dim)
            ctx.y = ctx.y + ctx.lineH
        end

        if zoneDef and zoneDef.luxuryDemand then
            W.createLabel(ctx.panel, 8, ctx.y,
                PhobosLib.safeGetText("UI_POS_ZoneOverview_LuxuryDemand")
                .. ": " .. string.format("%.1fx", zoneDef.luxuryDemand), C.dim)
            ctx.y = ctx.y + ctx.lineH
        end

        W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.ZONE_SEPARATOR_WIDTH, "-")
        ctx.y = ctx.y + ctx.lineH
    end
end

---------------------------------------------------------------
-- Tab C: Exchange (absorbed from Stockmarket)
---------------------------------------------------------------

local function renderExchange(ctx, params)
    local W = POS_TerminalWidgets
    local C = W.COLOURS

    local exchangeEnabled = POS_Sandbox
        and POS_Sandbox.getEnableExchange
        and POS_Sandbox.getEnableExchange()

    if not exchangeEnabled then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Exchange_Disabled"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        return
    end

    local overview = POS_MarketService.getExchangeOverview()

    -- Sentiment
    W.createLabel(ctx.panel, 0, ctx.y,
        W.safeGetText("UI_POS_Exchange_MarketOverview"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    local sentimentLabel = W.safeGetText(overview.sentimentKey)
    local sentimentColour = C.text
    if overview.sentimentKey == "UI_POS_Market_Sentiment_Bullish" then
        sentimentColour = C.success
    elseif overview.sentimentKey == "UI_POS_Market_Sentiment_Bearish" then
        sentimentColour = C.error
    end
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Exchange_Sentiment") .. ": " .. sentimentLabel,
        sentimentColour)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Commodity indices
    if #overview.indices == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Exchange_CommodityIndex"), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        local function renderIndexEntry(parent, rx, ry, rw, entry, _idx)
            local arrow = "="
            local colour = C.text
            if entry.trendKey == "UI_POS_Market_Trend_Rising" then
                arrow = "^"
                colour = C.success
            elseif entry.trendKey == "UI_POS_Market_Trend_Falling" then
                arrow = "v"
                colour = C.error
            end

            local changeStr = ""
            if entry.changePct and entry.changePct ~= 0 then
                changeStr = " (" .. string.format("%+.1f%%", entry.changePct) .. ")"
            end

            local line = "  " .. W.safeGetText(entry.labelKey)
                .. ": " .. string.format("%.1f", entry.index or 100)
                .. " " .. arrow .. changeStr

            local catId = entry.categoryId
            W.createButton(parent, rx, ry, rw, ctx.btnH, line, nil,
                function()
                    POS_ScreenManager.navigateTo(
                        POS_Constants.SCREEN_COMMODITY_DETAIL,
                        { categoryId = catId })
                end)
            return ctx.btnH + 4
        end

        local pageSize = POS_Constants.UI_EXCHANGE_PAGE_SIZE
        if #overview.indices > pageSize then
            local currentPage = (params and params.indexPage) or 1
            ctx.y = PhobosLib_Pagination.create(ctx.panel, {
                items = overview.indices,
                pageSize = pageSize,
                currentPage = currentPage,
                x = ctx.btnX, y = ctx.y, width = ctx.btnW,
                colours = { text = C.text, dim = C.dim, bgDark = C.bgDark,
                            bgHover = C.bgHover, border = C.border },
                renderItem = renderIndexEntry,
                onPageChange = function(newPage)
                    POS_ScreenManager.replaceCurrent(screen.id,
                        { tab = "exchange", indexPage = newPage })
                end,
            })
        else
            for _, entry in ipairs(overview.indices) do
                ctx.y = ctx.y + renderIndexEntry(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, entry, nil)
            end
        end
    end
end

---------------------------------------------------------------
-- Main create
---------------------------------------------------------------

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    _activeTab = (params and params.tab) or _activeTab or "summary"

    W.drawHeader(ctx, "UI_POS_MarketOverview_Title")

    -- Tab bar (PhobosLib_DualTab single-row)
    ctx.y = PhobosLib_DualTab.createSingle({
        panel   = ctx.panel,
        y       = ctx.y,
        tabs1   = TAB_DEFS,
        active1 = _activeTab,
        colours = C,
        btnH    = ctx.btnH,
        _W      = W,
        onTabChange = function(tab1)
            _activeTab = tab1
            POS_ScreenManager.replaceCurrent(screen.id, { tab = tab1 })
        end,
    })

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Scrollable content area
    local origPanel = contentPanel
    local scrollH = contentPanel:getHeight() - ctx.y - ctx.btnH - 16
    local scrollPanel = PhobosLib.createScrollPanel(
        contentPanel, 0, ctx.y, contentPanel:getWidth(), scrollH)
    ctx.panel = scrollPanel
    ctx.y = 0

    -- Render active tab
    if _activeTab == "summary" then
        renderSummary(ctx, params)
    elseif _activeTab == "zones" then
        renderZones(ctx, params)
    elseif _activeTab == "exchange" then
        renderExchange(ctx, params)
    end

    -- Footer
    ctx.panel = origPanel
    W.drawFooter(ctx)
end

---------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------
-- ContextPanel
---------------------------------------------------------------

screen.getContextData = function(_params)
    local data = {}
    if _activeTab == "exchange" then
        local overview = POS_MarketService.getExchangeOverview()
        table.insert(data, { type = "header", text = "UI_POS_Exchange_MarketOverview" })
        table.insert(data, { type = "kv", key = "UI_POS_Exchange_Sentiment",
            value = PhobosLib.safeGetText(overview.sentimentKey) })
        for _, entry in ipairs(overview.indices) do
            table.insert(data, { type = "kv",
                key = entry.labelKey,
                value = string.format("%.1f", entry.index or 100) })
        end
    else
        local categories = POS_MarketRegistry.getVisibleCategories({})
        table.insert(data, { type = "kv",
            key = POS_TerminalWidgets.safeGetText("UI_POS_MarketOverview_Categories"),
            value = tostring(#categories) })
    end
    return data
end

---------------------------------------------------------------
-- Starlit event listeners (reactive refresh)
---------------------------------------------------------------

local function _refreshIfActive()
    if POS_ScreenManager.currentScreen == screen.id then
        POS_ScreenManager.refreshCurrentScreen()
    end
end

if POS_Events then
    if POS_Events.OnMarketEvent then
        POS_Events.OnMarketEvent:addListener(_refreshIfActive)
    end
    if POS_Events.OnMarketSnapshotUpdated then
        POS_Events.OnMarketSnapshotUpdated:addListener(_refreshIfActive)
    end
    if POS_Events.OnStockTickClosed then
        POS_Events.OnStockTickClosed:addListener(_refreshIfActive)
    end
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
