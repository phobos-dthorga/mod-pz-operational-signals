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
-- POS_Screen_WholesalerDir.lua
-- Supply network directory — who's moving goods, where, and
-- in what state. Dual tab bars: zone × operational state.
-- Flickering green text on a CRT, listing the survivors who
-- keep the supply lines alive in a world that's falling apart.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_WholesalerService"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local _TAG = "[POS:WholesalerDir]"

local _activeZone = nil    -- nil = all zones
local _activeState = "all" -- "all" | "active" | "suspended" | "collapsed"
local _selectedId = nil

local STATE_BADGES = {
    active     = { key = "UI_POS_Wholesaler_Active",    colour = "success" },
    suspended  = { key = "UI_POS_Wholesaler_Suspended", colour = "warning" },
    blocked    = { key = "UI_POS_Wholesaler_Blocked",   colour = "error" },
    collapsed  = { key = "UI_POS_Wholesaler_Collapsed", colour = "dim" },
    starting   = { key = "UI_POS_Wholesaler_Starting",  colour = "textBright" },
    recovering = { key = "UI_POS_Wholesaler_Recovering", colour = "warning" },
}

local STATE_FILTERS = { "all", "active", "suspended", "collapsed" }

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_WHOLESALER_DIR
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_WholesalerDir_Title"
screen.sortOrder = 25
screen.requires = { connected = true }

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    _activeZone = (params and params.zone) or _activeZone
    _activeState = (params and params.state) or _activeState or "all"

    W.drawHeader(ctx, "UI_POS_WholesalerDir_Title")

    -- Tab Row 1: Zones
    local zones = POS_Constants.MARKET_ZONES or {}
    local zoneTabW = math.floor(ctx.panel:getWidth() / (#zones + 1)) - 2
    local zoneTabX = 0

    -- "All" zone tab
    if not _activeZone then
        W.createLabel(ctx.panel, zoneTabX + 4, ctx.y + 2,
            "> " .. PhobosLib.safeGetText("UI_POS_Assignments_FilterAll"), C.textBright)
    else
        W.createButton(ctx.panel, zoneTabX, ctx.y, zoneTabW, ctx.btnH,
            PhobosLib.safeGetText("UI_POS_Assignments_FilterAll"), nil,
            function()
                _activeZone = nil
                _selectedId = nil
                POS_ScreenManager.replaceCurrent(screen.id, { zone = nil, state = _activeState })
            end)
    end
    zoneTabX = zoneTabX + zoneTabW + 2

    for _, zoneId in ipairs(zones) do
        local zLabel = zoneId
        if POS_MarketSimulation and POS_MarketSimulation.getZoneRegistry then
            local zDef = POS_MarketSimulation.getZoneRegistry():get(zoneId)
            if zDef and zDef.name then zLabel = zDef.name end
        end
        -- Truncate long zone names
        if #zLabel > 12 then zLabel = string.sub(zLabel, 1, 10) .. ".." end

        if _activeZone == zoneId then
            W.createLabel(ctx.panel, zoneTabX + 4, ctx.y + 2, "> " .. zLabel, C.textBright)
        else
            local zId = zoneId
            W.createButton(ctx.panel, zoneTabX, ctx.y, zoneTabW, ctx.btnH,
                zLabel, nil,
                function()
                    _activeZone = zId
                    _selectedId = nil
                    POS_ScreenManager.replaceCurrent(screen.id, { zone = zId, state = _activeState })
                end)
        end
        zoneTabX = zoneTabX + zoneTabW + 2
    end
    ctx.y = ctx.y + ctx.btnH + 4

    -- Tab Row 2: Operational State
    local stateTabW = math.floor(ctx.panel:getWidth() / #STATE_FILTERS) - 2
    local stateTabX = 0
    for _, stateId in ipairs(STATE_FILTERS) do
        local sLabel = PhobosLib.safeGetText("UI_POS_Assignments_Filter"
            .. stateId:sub(1,1):upper() .. stateId:sub(2))
        if _activeState == stateId then
            W.createLabel(ctx.panel, stateTabX + 4, ctx.y + 2, "> " .. sLabel, C.textBright)
        else
            local sId = stateId
            W.createButton(ctx.panel, stateTabX, ctx.y, stateTabW, ctx.btnH,
                sLabel, nil,
                function()
                    _activeState = sId
                    _selectedId = nil
                    POS_ScreenManager.replaceCurrent(screen.id, { zone = _activeZone, state = sId })
                end)
        end
        stateTabX = stateTabX + stateTabW + 2
    end
    ctx.y = ctx.y + ctx.btnH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, 50, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Get wholesalers
    local wholesalers = {}
    if POS_WholesalerService and POS_WholesalerService.getAllVisible then
        local ok, all = PhobosLib.safecall(POS_WholesalerService.getAllVisible)
        if ok and all then
            for _, w in ipairs(all) do
                local zoneMatch = not _activeZone or w.regionId == _activeZone
                local stateMatch = _activeState == "all" or w.state == _activeState
                if zoneMatch and stateMatch then
                    wholesalers[#wholesalers + 1] = w
                end
            end
        end
    end

    if #wholesalers == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_WholesalerDir_None"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (params and params.page) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = wholesalers,
            pageSize = 5,
            currentPage = currentPage,
            x = 0, y = ctx.y,
            width = ctx.panel:getWidth(),
            colours = { text = C.text, dim = C.dim, bgDark = C.bgDark,
                        bgHover = C.bgHover, border = C.border },
            renderItem = function(parent, rx, ry, rw, w, _idx)
                local badge = STATE_BADGES[w.state] or STATE_BADGES.active
                local badgeText = PhobosLib.safeGetText(badge.key)
                local badgeColour = C[badge.colour] or C.text

                -- Row 1: [STATE] Name — Zone
                local zoneName = w.regionId or "?"
                W.createLabel(parent, rx, ry,
                    "[" .. badgeText .. "] " .. (w.displayName or w.id)
                    .. " -- " .. zoneName, badgeColour)
                ry = ry + ctx.lineH

                -- Row 2: Categories + stock bias
                local catStr = ""
                if w.primaryCategories then
                    catStr = table.concat(w.primaryCategories, ", ")
                end
                W.createLabel(parent, rx + 8, ry,
                    catStr ~= "" and catStr or "General supply", C.dim)
                ry = ry + ctx.lineH + 4

                return ry - rx
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(screen.id,
                    { zone = _activeZone, state = _activeState, page = newPage })
            end,
        })
    end

    W.drawFooter(ctx)
end

function screen.destroy()
    _selectedId = nil
    POS_TerminalWidgets.defaultDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function(_params)
    return {}
end

POS_API.registerScreen(screen)
