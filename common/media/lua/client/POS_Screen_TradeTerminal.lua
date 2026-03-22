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
-- POS_Screen_TradeTerminal.lua
-- Main trade terminal screen. Paginated list of wholesalers
-- available for direct trading. Gated behind Living Market
-- sandbox option and SIGINT level requirement.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_WorldState"
require "POS_WholesalerService"
require "POS_SIGINTSkill"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_TRADE_TERMINAL
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_Trade_Title"
screen.sortOrder = 40

screen.canOpen = function()
    -- Gate 1: Living Market must be enabled
    if not POS_Sandbox or not POS_Sandbox.isLivingMarketEnabled
            or not POS_Sandbox.isLivingMarketEnabled() then
        return false, PhobosLib.safeGetText("UI_POS_Trade_RequiresLivingMarket")
    end
    -- Gate 2: SIGINT level requirement
    local player = getSpecificPlayer(0)
    if not player then return false, PhobosLib.safeGetText("UI_POS_Trade_RequiresSIGINT") end
    local sigintLevel = POS_SIGINTSkill.getLevel(player)
    if sigintLevel < POS_Constants.TRADE_TERMINAL_SIGINT_REQ then
        return false, PhobosLib.safeGetText("UI_POS_Trade_RequiresSIGINT")
    end
    return true
end

---------------------------------------------------------------
-- State colour map for wholesaler operational state badges
---------------------------------------------------------------

local STATE_COLOURS = {
    [POS_Constants.WHOLESALER_STATE_STABLE]      = "success",
    [POS_Constants.WHOLESALER_STATE_TIGHT]        = "warn",
    [POS_Constants.WHOLESALER_STATE_STRAINED]     = "warn",
    [POS_Constants.WHOLESALER_STATE_DUMPING]       = "error",
    [POS_Constants.WHOLESALER_STATE_WITHHOLDING]   = "error",
    [POS_Constants.WHOLESALER_STATE_COLLAPSING]    = "error",
}

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Trade_Title")

    -- Fetch tradeable wholesalers
    local player = getSpecificPlayer(0)
    local wholesalers = POS_WorldState.getWholesalers()

    -- Build filtered list of tradeable wholesalers
    local entries = {}
    if wholesalers then
        for wId, w in pairs(wholesalers) do
            if type(w) == "table" then
                table.insert(entries, { id = wId, wholesaler = w })
            end
        end
    end

    -- Sort by ID for stable ordering
    table.sort(entries, function(a, b)
        return (a.id or "") < (b.id or "")
    end)

    if #entries == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Trade_NoContacts"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (_params and _params.tradePage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = entries,
            pageSize = POS_Constants.PAGE_SIZE_TRADE_TERMINAL,
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
                local w = entry.wholesaler

                -- Line 1: displayName + state badge
                local nameKey = w.nameKey or w.displayNameKey
                local name = nameKey and W.safeGetText(nameKey) or (w.name or entry.id)

                local stateBadge = "?"
                local stateColourKey = "dim"
                if w.state then
                    if POS_WholesalerService and POS_WholesalerService.getStateDisplayName then
                        stateBadge = POS_WholesalerService.getStateDisplayName(w.state)
                    end
                    stateColourKey = STATE_COLOURS[w.state] or "dim"
                end

                local stateColour = C[stateColourKey] or C.dim

                W.createLabel(parent, rx, ry + itemY, name, C.text)
                W.createLabel(parent, rx + rw * 0.6, ry + itemY,
                    "[" .. stateBadge .. "]", stateColour)
                itemY = itemY + ctx.lineH

                -- Line 2: zone (dim) + stock indicator
                local zone = w.regionId or w.zone or "???"
                local stockLevel = w.stockLevel or w.stock
                local stockStr = ""
                if stockLevel then
                    stockStr = " | " .. W.safeGetText("UI_POS_Trade_Stock")
                        .. ": " .. tostring(stockLevel)
                end
                W.createLabel(parent, rx, ry + itemY,
                    "  " .. W.safeGetText("UI_POS_Trade_Zone") .. ": "
                    .. zone .. stockStr, C.dim)
                itemY = itemY + ctx.lineH

                -- Clickable: navigate to catalog
                local wsId = entry.id
                W.createButton(parent, rx, ry + itemY, rw, ctx.btnH,
                    W.safeGetText("UI_POS_Trade_OpenCatalog"), nil,
                    function()
                        POS_ScreenManager.navigateTo(
                            POS_Constants.SCREEN_TRADE_CATALOG,
                            { wholesalerId = wsId })
                    end)
                itemY = itemY + ctx.btnH + 4

                return itemY + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_TRADE_TERMINAL,
                    { tradePage = newPage })
            end,
        })
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.getContextData = function(_params)
    local data = {}
    local wholesalers = POS_WorldState.getWholesalers()
    local count = 0
    if wholesalers then
        for _, w in pairs(wholesalers) do
            if type(w) == "table" then
                count = count + 1
            end
        end
    end
    if count > 0 then
        table.insert(data, { type = "kv", key = "UI_POS_Trade_Title",
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
