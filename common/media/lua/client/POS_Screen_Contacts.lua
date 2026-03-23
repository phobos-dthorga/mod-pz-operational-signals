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
-- POS_Screen_Contacts.lua
-- Consolidated contacts screen showing all known wholesaler
-- contacts with state badges and trade entry points.
-- Replaces: Traders + WholesalerDir + TradeTerminal (entry)
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_WorldState"
require "POS_WholesalerService"
require "POS_MarketSimulation"
require "POS_SIGINTSkill"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_CONTACTS
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_Contacts_Title"
screen.sortOrder = 15

-- NOTE: No SIGINT screen gate. Per §21, SIGINT affects data quality
-- (confidence, noise), never screen access. All screens navigable
-- from SIGINT 0. Low-SIGINT players see noisier contact data.

---------------------------------------------------------------
-- State colour map for wholesaler operational state badges
---------------------------------------------------------------

local STATE_COLOUR_MAP = {
    [POS_Constants.WHOLESALER_STATE_STABLE]      = "success",
    [POS_Constants.WHOLESALER_STATE_TIGHT]        = "warn",
    [POS_Constants.WHOLESALER_STATE_STRAINED]     = "warn",
    [POS_Constants.WHOLESALER_STATE_DUMPING]       = "error",
    [POS_Constants.WHOLESALER_STATE_WITHHOLDING]   = "error",
    [POS_Constants.WHOLESALER_STATE_COLLAPSING]    = "error",
}

--- Check whether a wholesaler state blocks ALL trade (both buy and sell).
---@param state string|nil  Wholesaler operational state
---@return boolean          True if trade is fully blocked
local function _isTradeFullyBlocked(state)
    if not state then return true end
    local buyBlocked = POS_Constants.TRADE_BLOCKED_BUY_STATES
        and POS_Constants.TRADE_BLOCKED_BUY_STATES[state]
    local sellBlocked = POS_Constants.TRADE_BLOCKED_SELL_STATES
        and POS_Constants.TRADE_BLOCKED_SELL_STATES[state]
    return (buyBlocked and sellBlocked) or false
end

---------------------------------------------------------------
-- Screen
---------------------------------------------------------------

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Contacts_Title")

    -- Current player SIGINT level
    local player = getSpecificPlayer(0)
    local sigintLevel = 0
    if player then
        sigintLevel = POS_SIGINTSkill.getLevel(player)
    end

    -- Fetch wholesalers (nil-safe)
    local wholesalers = POS_WorldState.getWholesalers()
    local visThreshold = POS_Constants.WHOLESALER_VISIBLE_THRESHOLD

    -- Zone registry for display names
    local zoneRegistry = nil
    if POS_MarketSimulation and POS_MarketSimulation.getZoneRegistry then
        zoneRegistry = POS_MarketSimulation.getZoneRegistry()
    end

    -- Build list of contacts
    local entries = {}
    if wholesalers then
        for wId, w in pairs(wholesalers) do
            if type(w) == "table" then
                local visible = (w.visibility or 0) > visThreshold
                local highSigint = sigintLevel >= 7
                table.insert(entries, {
                    id = wId,
                    wholesaler = w,
                    isRevealed = visible or highSigint,
                })
            end
        end
    end

    -- Sort: revealed first, then by ID for stable ordering
    table.sort(entries, function(a, b)
        if a.isRevealed ~= b.isRevealed then
            return a.isRevealed
        end
        return (a.id or "") < (b.id or "")
    end)

    if #entries == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Contacts_NoContacts"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (_params and _params.contactPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = entries,
            pageSize = POS_Constants.PAGE_SIZE_CONTACTS,
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

                -- Resolve display name
                local name
                if entry.isRevealed then
                    local nameKey = w.nameKey or w.displayNameKey
                    name = nameKey and W.safeGetText(nameKey)
                        or (w.name or entry.id)
                else
                    name = W.safeGetText("UI_POS_Contacts_UnknownContact")
                end

                -- Resolve zone name
                local zoneId = w.regionId or w.zone or "???"
                local zoneName = zoneId
                if zoneRegistry then
                    zoneName = PhobosLib.getRegistryDisplayName(
                        zoneRegistry, zoneId, zoneId)
                end

                -- Resolve state badge
                local stateBadge = W.safeGetText("UI_POS_Contacts_StateUnknown")
                local stateColourKey = "dim"
                if w.state then
                    if POS_WholesalerService
                            and POS_WholesalerService.getStateDisplayName then
                        stateBadge = POS_WholesalerService
                            .getStateDisplayName(w.state)
                    end
                    stateColourKey = STATE_COLOUR_MAP[w.state] or "dim"
                end
                local stateColour = C[stateColourKey] or C.dim

                -- Line 1: name + zone
                W.createLabel(parent, rx, ry + itemY, name, C.text)
                -- Zone on same line, right-aligned area
                W.createLabel(parent, rx + rw * 0.55, ry + itemY,
                    zoneName, C.dim)
                itemY = itemY + ctx.lineH

                -- Line 2: state badge (coloured)
                PhobosLib.createStatusBadge(parent,
                    rx + 8, ry + itemY, stateBadge, stateColour)
                itemY = itemY + ctx.lineH

                -- Trade button
                local wsId = entry.id
                local tradeBlocked = _isTradeFullyBlocked(w.state)
                if tradeBlocked then
                    -- Disabled trade button
                    local btn = W.createButton(parent, rx, ry + itemY,
                        rw, ctx.btnH,
                        W.safeGetText("UI_POS_Contacts_Blocked"),
                        nil, nil)
                    if btn and btn.setEnable then
                        btn:setEnable(false)
                    end
                else
                    W.createButton(parent, rx, ry + itemY, rw, ctx.btnH,
                        W.safeGetText("UI_POS_Contacts_Trade"), nil,
                        function()
                            POS_ScreenManager.navigateTo(
                                POS_Constants.SCREEN_TRADE_CATALOG,
                                { wholesalerId = wsId })
                        end)
                end
                itemY = itemY + ctx.btnH + 4

                return itemY + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(
                    POS_Constants.SCREEN_CONTACTS,
                    { contactPage = newPage })
            end,
        })
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function(_params)
    local ok, data = PhobosLib.safecall(function()
        local result = {}
        local wholesalers = POS_WorldState.getWholesalers()
        local count = 0
        if wholesalers then
            for _, w in pairs(wholesalers) do
                if type(w) == "table" then
                    count = count + 1
                end
            end
        end
        table.insert(result, { type = "kv",
            key = POS_TerminalWidgets.safeGetText("UI_POS_Contacts_Title"),
            value = tostring(count) })
        return result
    end)
    return (ok and data) or {}
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
