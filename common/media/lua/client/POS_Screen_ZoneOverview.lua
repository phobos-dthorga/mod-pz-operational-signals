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
-- POS_Screen_ZoneOverview.lua
-- Paginated list of market zones from the zone registry.
-- Each entry shows zone name, pressure summary (top 3
-- categories with colour coding), volatility badge, and
-- wholesaler count.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketSimulation"
require "POS_WholesalerService"
require "POS_WorldState"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_ZONE_OVERVIEW
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_Zone_Overview"
screen.sortOrder = 15

--- Get the pressure colour for a given pressure value.
---@param pressure number  Pressure value (-1 to +1 range)
---@return table           RGBA colour table
local function _getPressureColour(pressure, C)
    if pressure < -0.3 then
        return C.success or {0.4, 0.8, 0.4, 1}
    elseif pressure > 0.3 then
        return C.error or {0.8, 0.3, 0.3, 1}
    else
        return C.warning or {0.9, 0.7, 0.2, 1}
    end
end

--- Get the pressure label key for a given pressure value.
---@param pressure number  Pressure value
---@return string          Translation key
local function _getPressureLabelKey(pressure)
    if pressure < -0.3 then
        return "UI_POS_Zone_PressureSurplus"
    elseif pressure > 0.3 then
        return "UI_POS_Zone_PressureShortage"
    else
        return "UI_POS_Zone_PressureNeutral"
    end
end

--- Get the volatility label key for a given volatility value.
---@param volatility number  Volatility value (0 to 1 range)
---@return string            Translation key
local function _getVolatilityKey(volatility)
    if volatility < 0.3 then
        return "UI_POS_Zone_VolatilityLow"
    elseif volatility > 0.6 then
        return "UI_POS_Zone_VolatilityHigh"
    else
        return "UI_POS_Zone_VolatilityMed"
    end
end

--- Count wholesalers in a given zone.
---@param zoneId string  The zone ID
---@return number        Count of wholesalers in the zone
local function _countWholesalersInZone(zoneId)
    local wholesalers = POS_WorldState.getWholesalers()
    if not wholesalers then return 0 end
    local count = 0
    for _, w in pairs(wholesalers) do
        if w and w.regionId == zoneId then
            count = count + 1
        end
    end
    return count
end

--- Build sorted pressure entries for a zone (top 3 by absolute value).
---@param zoneState table  Zone state from POS_MarketSimulation
---@return table           Array of {catId, pressure} sorted by |pressure| desc
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

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Zone_Overview")

    -- Fetch zone list from registry
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
        -- Sort zones by ID for stable ordering
        table.sort(zones, function(a, b) return (a.id or "") < (b.id or "") end)

        local currentPage = (_params and _params.zonePage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = zones,
            pageSize = POS_Constants.PAGE_SIZE_ZONE_OVERVIEW,
            currentPage = currentPage,
            x = ctx.btnX,
            y = ctx.y,
            width = ctx.btnW,
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, rw, zoneDef, _idx)
                local itemY = 0

                -- Resolve zone name
                local zoneName = PhobosLib.getRegistryDisplayName(
                    zoneRegistry, zoneDef.id, zoneDef.id)

                -- Get zone state (nil-safe)
                local zoneState = nil
                if POS_MarketSimulation and POS_MarketSimulation.getZoneState then
                    zoneState = POS_MarketSimulation.getZoneState(zoneDef.id)
                end

                if not zoneState then
                    -- Line 1: zone name + no data
                    W.createLabel(parent, rx, ry + itemY,
                        zoneName .. " — " .. W.safeGetText("UI_POS_Zone_NoData"), C.text)
                    itemY = itemY + ctx.lineH
                else
                    -- Line 1: zone name + volatility badge
                    local volKey = _getVolatilityKey(zoneState.volatility or 0)
                    local volLabel = W.safeGetText("UI_POS_Zone_Volatility")
                        .. ": " .. W.safeGetText(volKey)
                    local wholesalerCount = _countWholesalersInZone(zoneDef.id)
                    local countLabel = W.safeGetText("UI_POS_Zone_WholesalerCount",
                        tostring(wholesalerCount))

                    W.createLabel(parent, rx, ry + itemY,
                        zoneName .. "  [" .. volLabel .. "]  " .. countLabel, C.text)
                    itemY = itemY + ctx.lineH

                    -- Line 2: top 3 pressure categories
                    local topPressures = _getTopPressures(zoneState)
                    if #topPressures > 0 then
                        local parts = {}
                        for _, entry in ipairs(topPressures) do
                            local pressKey = _getPressureLabelKey(entry.pressure)
                            table.insert(parts, entry.catId .. "=" .. W.safeGetText(pressKey))
                        end
                        local pressureLine = "  " .. W.safeGetText("UI_POS_Zone_Pressure")
                            .. ": " .. table.concat(parts, ", ")
                        -- Use colour of the highest-magnitude pressure
                        local topColour = _getPressureColour(topPressures[1].pressure, C)
                        W.createLabel(parent, rx, ry + itemY, pressureLine, topColour)
                    else
                        W.createLabel(parent, rx, ry + itemY,
                            "  " .. W.safeGetText("UI_POS_Zone_NoData"), C.dim)
                    end
                    itemY = itemY + ctx.lineH
                end

                return itemY + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_ZONE_OVERVIEW,
                    { zonePage = newPage })
            end,
        })
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.getContextData = function(_params)
    local data = {}
    local zoneRegistry = POS_MarketSimulation.getZoneRegistry()
    local count = zoneRegistry and zoneRegistry.count and zoneRegistry:count() or 0
    if count > 0 then
        table.insert(data, { type = "kv", key = "UI_POS_Zone_Overview",
            value = tostring(count) })
    end
    return data
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
