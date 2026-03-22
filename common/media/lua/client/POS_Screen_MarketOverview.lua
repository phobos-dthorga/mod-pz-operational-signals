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
-- Consolidated market dashboard combining category listings,
-- zone pressure indicators, and health summary into a single
-- scrollable screen.
-- Replaces: IntelSummary + Commodities + ZoneOverview
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketRegistry"
require "POS_MarketDatabase"
require "POS_MarketService"
require "POS_MarketSimulation"
require "POS_WorldState"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_MARKET_OVERVIEW
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_MarketOverview_Title"
screen.sortOrder = 5

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Map trend key to arrow glyph.
---@param trendKey string|nil  Translation key for trend direction
---@return string              Arrow glyph
local function _trendArrow(trendKey)
    if trendKey == "UI_POS_Market_Trend_Rising" then
        return "\226\134\145"   -- ↑ (UTF-8)
    elseif trendKey == "UI_POS_Market_Trend_Falling" then
        return "\226\134\147"   -- ↓ (UTF-8)
    end
    return "\226\134\146"       -- → (UTF-8)
end

--- Map trend key to colour.
---@param trendKey string|nil  Translation key for trend direction
---@param C        table       Colour palette
---@return table               RGBA colour
local function _trendColour(trendKey, C)
    if trendKey == "UI_POS_Market_Trend_Rising" then
        return C.success or C.text
    elseif trendKey == "UI_POS_Market_Trend_Falling" then
        return C.warn or C.text
    end
    return C.dim or C.text
end

--- Get the pressure colour for a given pressure value.
---@param pressure number  Pressure value (-1 to +1 range)
---@param C        table   Colour palette
---@return table           RGBA colour
local function _getPressureColour(pressure, C)
    if pressure < -0.3 then
        return C.success or C.text   -- surplus = green
    elseif pressure > 0.3 then
        return C.warn or C.text      -- shortage = red/amber
    end
    return C.text                    -- neutral = amber
end

--- Get the pressure label key for a given pressure value.
---@param pressure number  Pressure value
---@return string          Translation key
local function _getPressureLabelKey(pressure)
    if pressure < -0.3 then
        return "UI_POS_Zone_PressureSurplus"
    elseif pressure > 0.3 then
        return "UI_POS_Zone_PressureShortage"
    end
    return "UI_POS_Zone_PressureNeutral"
end

--- Build sorted pressure entries for a zone (top 3 by absolute value).
---@param zoneState table|nil  Zone state from POS_MarketSimulation
---@return table               Array of {catId, pressure}
local function _getTopPressures(zoneState)
    local entries = {}
    if not zoneState or not zoneState.pressure then return entries end
    for catId, val in pairs(zoneState.pressure) do
        table.insert(entries, { catId = catId, pressure = val })
    end
    table.sort(entries, function(a, b)
        return math.abs(a.pressure) > math.abs(b.pressure)
    end)
    local top = {}
    for i = 1, math.min(3, #entries) do
        top[i] = entries[i]
    end
    return top
end

---------------------------------------------------------------
-- Screen
---------------------------------------------------------------

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_MarketOverview_Title")

    -- Scrollable content area (between header and footer)
    local origPanel = contentPanel
    local scrollH = contentPanel:getHeight() - ctx.y - ctx.btnH - 16
    local scrollPanel = PhobosLib.createScrollPanel(
        contentPanel, 0, ctx.y, contentPanel:getWidth(), scrollH)
    ctx.panel = scrollPanel
    ctx.y = 0

    -------------------------------------------------------
    -- Section A — Categories (paginated)
    -------------------------------------------------------
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
        local currentPage = (_params and _params.catPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = categories,
            pageSize = POS_Constants.PAGE_SIZE_MARKET_OVERVIEW,
            currentPage = currentPage,
            x = ctx.btnX,
            y = ctx.y,
            width = ctx.btnW,
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, rw, cat, _idx)
                local summary = POS_MarketService.getCommoditySummary(cat.id)
                local catLabel = W.safeGetText(cat.labelKey)
                local priceStr = "\226\128\148"  -- em-dash fallback
                local arrow = ""
                local arrowColour = C.dim
                local freshnessStr = ""
                local sourceStr = ""

                if summary then
                    -- Avg price
                    if summary.avgPrice and summary.avgPrice > 0 then
                        priceStr = "$" .. tostring(math.floor(summary.avgPrice + 0.5))
                    end
                    -- Trend arrow
                    arrow = _trendArrow(summary.trendKey)
                    arrowColour = _trendColour(summary.trendKey, C)
                    -- Freshness badge
                    if summary.freshnessKey then
                        freshnessStr = " [" .. W.safeGetText(summary.freshnessKey) .. "]"
                    end
                    -- Source count
                    local sources = summary.sourceCount or 0
                    sourceStr = tostring(sources) .. " "
                        .. W.safeGetText("UI_POS_Market_Sources")
                end

                -- Build row label: "Category — $price ↑ [Fresh] 3 sources"
                local label = catLabel .. " \226\128\148 " .. priceStr
                    .. " " .. arrow .. freshnessStr
                    .. "  " .. sourceStr

                local catId = cat.id
                W.createButton(parent, rx, ry, rw, ctx.btnH, label, nil,
                    function()
                        POS_ScreenManager.navigateTo(
                            POS_Constants.SCREEN_COMMODITY_DETAIL,
                            { categoryId = catId })
                    end)

                -- Trend arrow overlay (coloured separately)
                -- Already embedded in label text; colour comes from button default

                return ctx.btnH + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(
                    POS_Constants.SCREEN_MARKET_OVERVIEW,
                    { catPage = newPage })
            end,
        })
    end

    ctx.y = ctx.y + 4

    -------------------------------------------------------
    -- Section B — Zone Pressure (Living Market only)
    -------------------------------------------------------
    local livingMarketEnabled = POS_Sandbox
        and POS_Sandbox.isLivingMarketEnabled
        and POS_Sandbox.isLivingMarketEnabled()

    if livingMarketEnabled then
        W.createLabel(ctx.panel, 0, ctx.y,
            "=== " .. W.safeGetText("UI_POS_MarketOverview_ZonePressure") .. " ===",
            C.textBright)
        ctx.y = ctx.y + ctx.lineH

        local zoneRegistry = POS_MarketSimulation.getZoneRegistry()
        local zones = {}
        if zoneRegistry and zoneRegistry.getAll then
            local allDefs = zoneRegistry:getAll()
            if allDefs then
                for _, def in pairs(allDefs) do
                    table.insert(zones, def)
                end
            end
        end

        if #zones == 0 then
            W.createLabel(ctx.panel, 8, ctx.y,
                W.safeGetText("UI_POS_Zone_NoData"), C.dim)
            ctx.y = ctx.y + ctx.lineH
        else
            table.sort(zones, function(a, b)
                return (a.id or "") < (b.id or "")
            end)

            for _, zoneDef in ipairs(zones) do
                local zoneName = PhobosLib.getRegistryDisplayName(
                    zoneRegistry, zoneDef.id, zoneDef.id)

                local zoneState = nil
                if POS_MarketSimulation and POS_MarketSimulation.getZoneState then
                    zoneState = POS_MarketSimulation.getZoneState(zoneDef.id)
                end

                -- Zone name label
                W.createLabel(ctx.panel, 8, ctx.y, zoneName, C.text)
                ctx.y = ctx.y + ctx.lineH

                -- Top 3 pressure indicators
                local topPressures = _getTopPressures(zoneState)
                if #topPressures > 0 then
                    local parts = {}
                    for _, entry in ipairs(topPressures) do
                        local pressKey = _getPressureLabelKey(entry.pressure)
                        table.insert(parts,
                            entry.catId .. "=" .. W.safeGetText(pressKey))
                    end
                    local pressureLine = "  " .. table.concat(parts, ", ")
                    local topColour = _getPressureColour(
                        topPressures[1].pressure, C)
                    W.createLabel(ctx.panel, 8, ctx.y, pressureLine, topColour)
                else
                    W.createLabel(ctx.panel, 8, ctx.y,
                        "  " .. W.safeGetText("UI_POS_Zone_NoData"), C.dim)
                end
                ctx.y = ctx.y + ctx.lineH
            end
        end

        ctx.y = ctx.y + 4
    end

    -------------------------------------------------------
    -- Section C — Health Summary
    -------------------------------------------------------
    W.createLabel(ctx.panel, 0, ctx.y,
        "=== " .. W.safeGetText("UI_POS_MarketOverview_Health") .. " ===",
        C.textBright)
    ctx.y = ctx.y + ctx.lineH

    local metaOk, meta = PhobosLib.safecall(POS_WorldState.getMeta)
    meta = (metaOk and meta) or {}

    -- Total observations (sum across all category summaries)
    local totalObs = 0
    local totalConf = 0
    local confCount = 0
    for _, cat in ipairs(categories) do
        local s = POS_MarketService.getCommoditySummary(cat.id)
        if s then
            totalObs = totalObs + (s.sourceCount or 0)
            if s.confidenceKey then
                confCount = confCount + 1
                if s.confidenceKey == "UI_POS_Market_Confidence_High" then
                    totalConf = totalConf + 3
                elseif s.confidenceKey == "UI_POS_Market_Confidence_Medium" then
                    totalConf = totalConf + 2
                elseif s.confidenceKey == "UI_POS_Market_Confidence_Low" then
                    totalConf = totalConf + 1
                end
            end
        end
    end

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_MarketOverview_TotalObservations") .. ": "
        .. tostring(totalObs), C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Average confidence (textual)
    local avgConfLabel
    if confCount > 0 then
        local avgScore = totalConf / confCount
        if avgScore >= 2.5 then
            avgConfLabel = W.safeGetText("UI_POS_Market_Confidence_High")
        elseif avgScore >= 1.5 then
            avgConfLabel = W.safeGetText("UI_POS_Market_Confidence_Medium")
        else
            avgConfLabel = W.safeGetText("UI_POS_Market_Confidence_Low")
        end
    else
        avgConfLabel = "\226\128\148"  -- em-dash
    end

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_MarketOverview_AvgConfidence") .. ": "
        .. avgConfLabel, C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Days since last economy tick
    local lastDay = meta.lastProcessedDay
    local daysSinceTick = "\226\128\148"  -- em-dash
    if lastDay and lastDay >= 0 then
        local gameTime = GameTime and GameTime.getInstance
            and GameTime.getInstance()
        if gameTime and gameTime.getNightsSurvived then
            local currentDay = gameTime:getNightsSurvived()
            daysSinceTick = tostring(currentDay - lastDay)
        end
    end

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_MarketOverview_DaysSinceTick") .. ": "
        .. daysSinceTick, C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Footer (drawn on original content panel, outside scroll area)
    ctx.panel = origPanel
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function(_params)
    local ok, data = PhobosLib.safecall(function()
        local result = {}
        local categories = POS_MarketRegistry.getVisibleCategories({})
        table.insert(result, { type = "kv",
            key = POS_TerminalWidgets.safeGetText("UI_POS_MarketOverview_Categories"),
            value = tostring(#categories) })
        return result
    end)
    return (ok and data) or {}
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
