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
-- Regional economic dashboard — pressure gauges, population
-- tiers, active events, and agent counts per zone. The kind
-- of display a signals officer would stare at all night,
-- watching the economy of a dead world pulse and flicker.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketSimulation"
require "POS_EventService"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_ZONE_OVERVIEW
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_ZoneOverview_Title"
screen.sortOrder = 30
screen.requires = { connected = true }

--- Build a text-based pressure bar: [########----] 65%
local function buildPressureBar(pressure, maxWidth)
    local pct = PhobosLib.clamp((pressure + 2) / 4, 0, 1)  -- normalise -2..+2 to 0..1
    local filled = math.floor(pct * maxWidth)
    local empty = maxWidth - filled
    return "[" .. string.rep("#", filled) .. string.rep("-", empty) .. "] "
        .. tostring(math.floor(pct * 100)) .. "%"
end

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    W.drawHeader(ctx, "UI_POS_ZoneOverview_Title")

    local zones = POS_Constants.MARKET_ZONES or {}
    local currentDay = getGameTime() and getGameTime():getNightsSurvived() or 0

    for _, zoneId in ipairs(zones) do
        -- Zone header
        local zoneName = zoneId
        local zoneDef = nil
        if POS_MarketSimulation and POS_MarketSimulation.getZoneRegistry then
            zoneDef = POS_MarketSimulation.getZoneRegistry():get(zoneId)
            if zoneDef and zoneDef.name then zoneName = zoneDef.name end
        end

        W.createLabel(ctx.panel, 0, ctx.y, zoneName, C.textBright)
        ctx.y = ctx.y + ctx.lineH

        -- Population tier
        local pop = zoneDef and zoneDef.population or "unknown"
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_ZoneOverview_Population") .. ": " .. pop, C.dim)
        ctx.y = ctx.y + ctx.lineH

        -- Zone pressure (from simulation)
        local zoneState = POS_MarketSimulation.getZoneState
            and POS_MarketSimulation.getZoneState(zoneId)
        local pressure = zoneState and zoneState.pressure or 0
        local pressureBar = buildPressureBar(pressure, 20)
        local pressureColour = pressure > 0.5 and C.error
            or (pressure > 0 and C.warning or C.text)
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_ZoneOverview_Pressure") .. ": " .. pressureBar,
            pressureColour)
        ctx.y = ctx.y + ctx.lineH

        -- Active agents in zone
        local agents = POS_MarketSimulation.getAgentsForZone
            and POS_MarketSimulation.getAgentsForZone(zoneId) or {}
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_ZoneOverview_Agents") .. ": " .. tostring(#agents),
            C.dim)
        ctx.y = ctx.y + ctx.lineH

        -- Active events in zone
        local events = POS_EventService and POS_EventService.getActiveEventsForZone
            and POS_EventService.getActiveEventsForZone(zoneId, currentDay) or {}
        if #events > 0 then
            for _, ev in ipairs(events) do
                local evName = PhobosLib.safeGetText(ev.displayNameKey or "?")
                local daysLeft = (ev.expiryDay or 0) - currentDay
                W.createLabel(ctx.panel, 16, ctx.y,
                    "[" .. (ev.signalClass or "?"):upper() .. "] "
                    .. evName .. " (" .. tostring(daysLeft) .. "d)",
                    ev.signalClass == "hard" and C.textBright or C.dim)
                ctx.y = ctx.y + ctx.lineH
            end
        end

        -- Luxury demand
        if zoneDef and zoneDef.luxuryDemand then
            W.createLabel(ctx.panel, 8, ctx.y,
                PhobosLib.safeGetText("UI_POS_ZoneOverview_LuxuryDemand")
                .. ": " .. string.format("%.1fx", zoneDef.luxuryDemand), C.dim)
            ctx.y = ctx.y + ctx.lineH
        end

        -- Zone separator
        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH
    end

    W.drawFooter(ctx)
end

function screen.destroy()
    POS_TerminalWidgets.defaultDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function() return {} end

POS_API.registerScreen(screen)
