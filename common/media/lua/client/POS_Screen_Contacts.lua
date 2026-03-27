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
-- 2-tab contacts/directory screen:
--   Tab 1 "Contacts" — flat wholesaler list with trade buttons
--   Tab 2 "Directory" — zone × state dual-tab filtered view
--     (absorbed from POS_Screen_WholesalerDir.lua)
--
-- Uses PhobosLib_DualTab for all tab rendering.
-- Subscribes to POS_Events.OnStockTickClosed for reactive refresh.
---------------------------------------------------------------

require "PhobosLib"
require "PhobosLib_DualTab"
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

local _activeTab = "contacts"  -- "contacts" | "directory"
local _dirZone = nil           -- nil = all zones (directory tab)
local _dirState = "all"        -- "all" | "active" | "suspended" | "collapsed"

local TOP_TABS = {
    { id = "contacts",  labelKey = "UI_POS_Contacts_TabContacts" },
    { id = "directory", labelKey = "UI_POS_Contacts_TabDirectory" },
}

local STATE_COLOUR_MAP = {
    [POS_Constants.WHOLESALER_STATE_STABLE]      = "success",
    [POS_Constants.WHOLESALER_STATE_TIGHT]        = "warn",
    [POS_Constants.WHOLESALER_STATE_STRAINED]     = "warn",
    [POS_Constants.WHOLESALER_STATE_DUMPING]       = "error",
    [POS_Constants.WHOLESALER_STATE_WITHHOLDING]   = "error",
    [POS_Constants.WHOLESALER_STATE_COLLAPSING]    = "error",
}

local DIR_STATE_BADGES = {
    active     = { key = "UI_POS_Wholesaler_Active",    colour = "success" },
    suspended  = { key = "UI_POS_Wholesaler_Suspended", colour = "warning" },
    blocked    = { key = "UI_POS_Wholesaler_Blocked",   colour = "error" },
    collapsed  = { key = "UI_POS_Wholesaler_Collapsed", colour = "dim" },
    starting   = { key = "UI_POS_Wholesaler_Starting",  colour = "textBright" },
    recovering = { key = "UI_POS_Wholesaler_Recovering", colour = "warning" },
}

local DIR_STATE_FILTERS = { "all", "active", "suspended", "collapsed" }

local function _isTradeFullyBlocked(state)
    if not state then return true end
    local buyBlocked = POS_Constants.TRADE_BLOCKED_BUY_STATES
        and POS_Constants.TRADE_BLOCKED_BUY_STATES[state]
    local sellBlocked = POS_Constants.TRADE_BLOCKED_SELL_STATES
        and POS_Constants.TRADE_BLOCKED_SELL_STATES[state]
    return (buyBlocked and sellBlocked) or false
end

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_CONTACTS
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_Contacts_Title"
screen.sortOrder = 15

---------------------------------------------------------------
-- Tab 1: Contacts (flat list with trade buttons)
---------------------------------------------------------------

local function renderContacts(ctx, params)
    local W = POS_TerminalWidgets
    local C = W.COLOURS

    local player = getSpecificPlayer(0)
    local sigintLevel = player and POS_SIGINTSkill.getLevel(player) or 0

    local wholesalers = POS_WorldState.getWholesalers()
    local visThreshold = POS_Constants.WHOLESALER_VISIBLE_THRESHOLD

    local zoneRegistry = POS_MarketSimulation
        and POS_MarketSimulation.getZoneRegistry
        and POS_MarketSimulation.getZoneRegistry()

    local entries = {}
    local hiddenCount = 0
    if wholesalers then
        for wId, w in pairs(wholesalers) do
            if type(w) == "table" then
                local visible = (w.visibility or 0) > visThreshold
                local highSigint = sigintLevel >= POS_Constants.SIGINT_HIGH_VISIBILITY_LEVEL
                if visible or highSigint then
                    entries[#entries + 1] = {
                        id = wId, wholesaler = w,
                        isRevealed = true,
                    }
                else
                    hiddenCount = hiddenCount + 1
                end
            end
        end
    end

    -- Filter by category if navigated from "Known Sellers" on Commodity Detail
    local filterCat = params and params.filterCategory
    if filterCat then
        local filtered = {}
        for _, e in ipairs(entries) do
            local w = e.wholesaler
            if w and w.categoryWeights and w.categoryWeights[filterCat]
                    and w.categoryWeights[filterCat] > 0 then
                filtered[#filtered + 1] = e
            end
        end
        entries = filtered

        -- Show filter header
        local catLabel = filterCat
        if POS_MarketRegistry and POS_MarketRegistry.getCategory then
            local catDef = POS_MarketRegistry.getCategory(filterCat)
            if catDef and catDef.labelKey then
                catLabel = W.safeGetText(catDef.labelKey)
            end
        end
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Contacts_SellersOf") .. " " .. catLabel, C.textBright)
        ctx.y = ctx.y + ctx.lineH
    end

    table.sort(entries, function(a, b)
        if a.isRevealed ~= b.isRevealed then return a.isRevealed end
        return (a.id or "") < (b.id or "")
    end)

    if #entries == 0 then
        local emptyKey = filterCat and "UI_POS_Contacts_NoSellersForCategory"
            or "UI_POS_Contacts_NoContacts"
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText(emptyKey), C.dim)
        ctx.y = ctx.y + ctx.lineH
        return
    end

    local currentPage = (params and params.contactPage) or 1
    ctx.y = PhobosLib_Pagination.create(ctx.panel, {
        items = entries,
        pageSize = POS_Constants.PAGE_SIZE_CONTACTS,
        currentPage = currentPage,
        x = ctx.btnX, y = ctx.y, width = ctx.btnW,
        colours = { text = C.text, dim = C.dim, bgDark = C.bgDark,
                    bgHover = C.bgHover, border = C.border },
        renderItem = function(parent, rx, ry, rw, entry, _idx)
            local itemY = 0
            local w = entry.wholesaler

            local name = entry.isRevealed
                and (W.safeGetText(w.nameKey or w.displayNameKey or "") or w.name or entry.id)
                or W.safeGetText("UI_POS_Contacts_UnknownContact")

            local zoneId = w.regionId or w.zone or "???"
            local zoneName = zoneRegistry
                and PhobosLib.getRegistryDisplayName(zoneRegistry, zoneId, zoneId)
                or zoneId

            local stateBadge = W.safeGetText("UI_POS_Contacts_StateUnknown")
            local stateColourKey = "dim"
            if w.state then
                if POS_WholesalerService and POS_WholesalerService.getStateDisplayName then
                    stateBadge = POS_WholesalerService.getStateDisplayName(w.state)
                end
                stateColourKey = STATE_COLOUR_MAP[w.state] or "dim"
            end

            W.createLabel(parent, rx, ry + itemY, name, C.text)
            W.createLabel(parent, rx + rw * POS_Constants.CONTACTS_ZONE_OFFSET, ry + itemY, zoneName, C.dim)
            itemY = itemY + ctx.lineH

            PhobosLib.createStatusBadge(parent, rx + 8, ry + itemY, stateBadge, C[stateColourKey] or C.dim)
            itemY = itemY + ctx.lineH

            local wsId = entry.id
            if _isTradeFullyBlocked(w.state) then
                local btn = W.createButton(parent, rx, ry + itemY, rw, ctx.btnH,
                    W.safeGetText("UI_POS_Contacts_Blocked"), nil, nil)
                if btn and btn.setEnable then btn:setEnable(false) end
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
            POS_ScreenManager.replaceCurrent(screen.id,
                { tab = "contacts", contactPage = newPage })
        end,
    })

    -- §49 No Silent Gates: show hidden contacts hint
    if hiddenCount > 0 then
        ctx.y = ctx.y + 4
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_Gate_HiddenContacts")
                :gsub("%%1", tostring(hiddenCount)),
            C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_Gate_SigintReveal")
                :gsub("%%1", tostring(sigintLevel)),
            C.dim)
        ctx.y = ctx.y + ctx.lineH
    end
end

---------------------------------------------------------------
-- Tab 2: Directory (zone × state dual-tab, absorbed from WholesalerDir)
---------------------------------------------------------------

local function renderDirectory(ctx, params)
    local W = POS_TerminalWidgets
    local C = W.COLOURS

    -- Build zone tabs dynamically with fallback chain:
    -- 1. Zone registry → zDef.name
    -- 2. Translation key → UI_POS_Zone_<zoneId>
    -- 3. Raw zoneId (title-cased)
    local zones = POS_Constants.MARKET_ZONES or {}
    local zoneTabs = { { id = "all", labelKey = "UI_POS_Assignments_FilterAll" } }
    for _, zoneId in ipairs(zones) do
        local zLabel = nil
        -- Try zone registry first
        if POS_MarketSimulation and POS_MarketSimulation.getZoneRegistry then
            local ok, zReg = PhobosLib.safecall(POS_MarketSimulation.getZoneRegistry)
            if ok and zReg then
                local zDef = zReg:get(zoneId)
                if zDef and zDef.name then zLabel = zDef.name end
            end
        end
        -- Fallback: translation key
        if not zLabel then
            local key = "UI_POS_Zone_" .. zoneId
            local translated = PhobosLib.safeGetText(key)
            if translated and translated ~= key then zLabel = translated end
        end
        -- Fallback: raw ID
        if not zLabel then zLabel = zoneId end
        -- Truncate
        if #zLabel > POS_Constants.WHOLESALER_LABEL_MAX_LENGTH + 2 then
            zLabel = string.sub(zLabel, 1, POS_Constants.WHOLESALER_LABEL_MAX_LENGTH) .. ".."
        end
        zoneTabs[#zoneTabs + 1] = { id = zoneId, label = zLabel }
    end

    local stateTabs = {}
    for _, sId in ipairs(DIR_STATE_FILTERS) do
        stateTabs[#stateTabs + 1] = {
            id = sId,
            labelKey = "UI_POS_Assignments_Filter" .. sId:sub(1,1):upper() .. sId:sub(2),
        }
    end

    _dirZone = (params and params.dirZone) or _dirZone
    _dirState = (params and params.dirState) or _dirState or "all"

    -- Dual-tab bar (PhobosLib_DualTab)
    ctx.y = PhobosLib_DualTab.create({
        panel   = ctx.panel,
        y       = ctx.y,
        tabs1   = zoneTabs,
        tabs2   = stateTabs,
        active1 = _dirZone or "all",
        active2 = _dirState,
        colours = C,
        btnH    = ctx.btnH,
        _W      = W,
        onTabChange = function(tab1, tab2)
            _dirZone = (tab1 == "all") and nil or tab1
            _dirState = tab2
            POS_ScreenManager.replaceCurrent(screen.id,
                { tab = "directory", dirZone = _dirZone, dirState = tab2 })
        end,
    })

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Get filtered wholesalers
    local wholesalers = {}
    if POS_WholesalerService and POS_WholesalerService.getAllVisible then
        local ok, all = PhobosLib.safecall(POS_WholesalerService.getAllVisible)
        if ok and all then
            for _, w in ipairs(all) do
                local zoneMatch = not _dirZone or w.regionId == _dirZone
                local stateMatch = _dirState == "all" or w.state == _dirState
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
        local currentPage = (params and params.dirPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = wholesalers,
            pageSize = POS_Constants.PAGE_SIZE_WHOLESALER_DIR,
            currentPage = currentPage,
            x = 0, y = ctx.y, width = ctx.panel:getWidth(),
            colours = { text = C.text, dim = C.dim, bgDark = C.bgDark,
                        bgHover = C.bgHover, border = C.border },
            renderItem = function(parent, rx, ry, rw, w, _idx)
                local badge = DIR_STATE_BADGES[w.state] or DIR_STATE_BADGES.active
                local badgeText = PhobosLib.safeGetText(badge.key)
                local badgeColour = C[badge.colour] or C.text

                W.createLabel(parent, rx, ry,
                    "[" .. badgeText .. "] " .. (w.displayName or w.id)
                    .. " -- " .. (w.regionId or "?"), badgeColour)
                ry = ry + ctx.lineH

                local catStr = w.primaryCategories
                    and table.concat(w.primaryCategories, ", ") or ""
                W.createLabel(parent, rx + 8, ry,
                    catStr ~= "" and catStr
                    or PhobosLib.safeGetText("UI_POS_WholesalerDir_GeneralSupply"), C.dim)
                ry = ry + ctx.lineH + 4

                return ctx.lineH * 2 + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(screen.id,
                    { tab = "directory", dirZone = _dirZone, dirState = _dirState, dirPage = newPage })
            end,
        })
    end
end

---------------------------------------------------------------
-- Main create
---------------------------------------------------------------

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    _activeTab = (params and params.tab) or _activeTab or "contacts"

    W.drawHeader(ctx, "UI_POS_Contacts_Title")

    -- Top-level tab bar
    ctx.y = PhobosLib_DualTab.createSingle({
        panel   = ctx.panel,
        y       = ctx.y,
        tabs1   = TOP_TABS,
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

    -- Render active tab
    if _activeTab == "contacts" then
        renderContacts(ctx, params)
    elseif _activeTab == "directory" then
        renderDirectory(ctx, params)
    end

    W.drawFooter(ctx)
end

---------------------------------------------------------------

screen.destroy = function()
    _dirZone = nil
    _dirState = "all"
    POS_TerminalWidgets.defaultDestroy()
end

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
                if type(w) == "table" then count = count + 1 end
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
-- Starlit reactive refresh
---------------------------------------------------------------

if POS_Events and POS_Events.OnStockTickClosed then
    POS_Events.OnStockTickClosed:addListener(function()
        if POS_ScreenManager.currentScreen == screen.id then
            POS_ScreenManager.markDirty()
        end
    end)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
