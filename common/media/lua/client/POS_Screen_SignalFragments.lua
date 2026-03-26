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
-- POS_Screen_SignalFragments.lua
-- Terminal screen for browsing Signal Fragments (Tier 0.5
-- radio intelligence). Displays fragments captured by
-- POS_WBN_ClientListener from WBN broadcasts, with filter
-- tabs by fragment type and ContextPanel detail view.
---------------------------------------------------------------

require "PhobosLib"
require "PhobosLib_DualTab"
require "PhobosLib_Pagination"
require "POS_Constants"
require "POS_Constants_WBN"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_API"
require "POS_WBN_ClientListener"

---------------------------------------------------------------

local _TAG = "Screen:Fragments"

--- Filter state
local _activeFilter = "all"  -- "all" | "market_fragment" | "weather_fragment" | "infrastructure_fragment"
local _selectedIdx = nil
local _lastFragments = {}    -- cached for ContextPanel access

--- Filter tab definitions
local FILTER_TABS = {
    { id = "all",                      labelKey = "UI_POS_Fragments_FilterAll" },
    { id = "market_fragment",          labelKey = "UI_POS_Fragments_FilterMarket" },
    { id = "weather_fragment",         labelKey = "UI_POS_Fragments_FilterWeather" },
    { id = "infrastructure_fragment",  labelKey = "UI_POS_Fragments_FilterInfra" },
}

--- Type badge display map
local TYPE_BADGES = {
    market_fragment         = { badge = "MKT",   colour = "success" },
    weather_fragment        = { badge = "WX",    colour = "warning" },
    infrastructure_fragment = { badge = "INFRA", colour = "error" },
}

---------------------------------------------------------------
-- Data collection
---------------------------------------------------------------

--- Collect all signal fragments from player ModData.
--- Reads from POSNET.SignalFragments using pairs() for Java
--- table safety. Returns array sorted newest-first.
--- @return table Array of fragment tables
local function _getAllFragments()
    local player = getPlayer()
    if not player then return {} end
    local md = player:getModData()
    if not md or not md.POSNET then return {} end
    local store = md.POSNET[POS_Constants.WBN_FRAGMENT_MODDATA_KEY]
    if not store then return {} end

    local result = {}
    for k, v in pairs(store) do
        if type(v) == "table" then
            v._sortIdx = tonumber(k) or 0
            result[#result + 1] = v
        end
    end
    table.sort(result, function(a, b) return (a._sortIdx or 0) > (b._sortIdx or 0) end)
    return result
end

--- Collect fragments with optional type filter applied.
--- @param filter string  "all" or a fragment type id
--- @return table  Filtered array of fragments
local function _collectFragments(filter)
    local all = _getAllFragments()
    if filter == "all" then return all end
    local filtered = {}
    for _, f in ipairs(all) do
        if f.type == filter then
            filtered[#filtered + 1] = f
        end
    end
    return filtered
end

--- Get the badge colour from POS_TerminalWidgets.COLOURS.
--- @param fragmentType string  Fragment type key
--- @param C            table   COLOURS table
--- @return table  Colour table
local function _getBadgeColour(fragmentType, C)
    local info = TYPE_BADGES[fragmentType]
    if not info then return C.dim end
    return C[info.colour] or C.dim
end

--- Get the badge text for a fragment type.
--- @param fragmentType string  Fragment type key
--- @return string  Badge text
local function _getBadgeText(fragmentType)
    local info = TYPE_BADGES[fragmentType]
    return info and info.badge or "???"
end

--- Format a direction string for display.
--- @param direction string|nil  Direction from fragment
--- @return string  Arrow or dash
local function _formatDirection(direction)
    if direction == POS_Constants.WBN_DIR_UP then return "^"
    elseif direction == POS_Constants.WBN_DIR_DOWN then return "v"
    elseif direction == POS_Constants.WBN_DIR_MIXED then return "~"
    elseif direction == POS_Constants.WBN_DIR_STABLE then return "-"
    end
    return "-"
end

---------------------------------------------------------------
-- Screen definition
---------------------------------------------------------------

local screen = {}
screen.id        = "pos.bbs.fragments"
screen.menuPath  = {"pos.bbs"}
screen.titleKey  = "UI_POS_Fragments_Title"
screen.sortOrder = 40

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Restore filter from params
    _activeFilter = (params and params.filter) or _activeFilter or "all"
    if params and params.selectedIdx then
        _selectedIdx = params.selectedIdx
    end

    -- Header
    W.drawHeader(ctx, screen.titleKey)

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
            _selectedIdx = nil
            POS_ScreenManager.replaceCurrent(screen.id, { filter = tab1 })
        end,
    })

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Collect and cache fragments
    local fragments = _collectFragments(_activeFilter)
    _lastFragments = fragments

    if #fragments == 0 then
        -- Empty state
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_Fragments_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_Fragments_NoData_Hint"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        -- Paginated fragment list
        local currentPage = (params and params.page) or 1
        local filterCopy = _activeFilter

        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = fragments,
            pageSize = POS_Constants.FRAGMENTS_PAGE_SIZE,
            currentPage = currentPage,
            x = ctx.btnX, y = ctx.y, width = ctx.btnW,
            colours = { text = C.text, dim = C.dim, bgDark = C.bgDark,
                        bgHover = C.bgHover, border = C.border },
            renderItem = function(parent, rx, ry, rw, entry, idx)
                local itemY = 0
                local fragType = entry.type or "market_fragment"
                local badgeColour = _getBadgeColour(fragType, C)
                local badgeText = _getBadgeText(fragType)

                -- Line 1: [MKT] Day 5  Conf:42%  Fresh:100%
                local dayStr = PhobosLib.safeGetText("UI_POS_Fragments_Day")
                    .. " " .. tostring(entry.receivedDay or 0)
                local confStr = PhobosLib.safeGetText("UI_POS_Fragments_Conf")
                    .. ":" .. string.format("%.0f%%", (entry.confidence or 0) * 100)
                local freshStr = PhobosLib.safeGetText("UI_POS_Fragments_Fresh")
                    .. ":" .. string.format("%.0f%%", (entry.freshness or 0) * 100)
                local line1 = "[" .. badgeText .. "] " .. dayStr .. "  " .. confStr .. "  " .. freshStr
                W.createLabel(parent, rx, ry + itemY, line1, badgeColour)
                itemY = itemY + ctx.lineH

                -- Line 2: zone | category | direction (dim)
                local zoneName = entry.zoneId
                    and PhobosLib.safeGetText("UI_WBN_Zone_" .. tostring(entry.zoneId))
                    or "???"
                -- Fall back to raw zoneId if translation key returned itself
                if zoneName == ("UI_WBN_Zone_" .. tostring(entry.zoneId)) then
                    zoneName = tostring(entry.zoneId)
                end
                local catName = entry.categoryId
                    and PhobosLib.safeGetText("UI_POS_Category_" .. tostring(entry.categoryId))
                    or "---"
                if catName == ("UI_POS_Category_" .. tostring(entry.categoryId)) then
                    catName = tostring(entry.categoryId)
                end
                local dirStr = _formatDirection(entry.direction)
                local line2 = "  " .. zoneName .. " | " .. catName .. " | " .. dirStr
                W.createLabel(parent, rx, ry + itemY, line2, C.dim)
                itemY = itemY + ctx.lineH

                -- Line 3: View Details / > SELECTED button
                local globalIdx = ((currentPage - 1) * POS_Constants.FRAGMENTS_PAGE_SIZE) + idx
                local isSelected = (_selectedIdx == globalIdx)
                W.createButton(parent, rx, ry + itemY, rw, ctx.btnH,
                    isSelected and "> SELECTED"
                        or PhobosLib.safeGetText("UI_POS_Screen_ViewDetails"),
                    nil,
                    function()
                        _selectedIdx = globalIdx
                        POS_ScreenManager.replaceCurrent(screen.id,
                            { filter = _activeFilter, selectedIdx = globalIdx, page = currentPage })
                    end)
                itemY = itemY + ctx.btnH + 4

                return itemY
            end,
            onPageChange = function(newPage)
                _selectedIdx = nil
                POS_ScreenManager.replaceCurrent(screen.id,
                    { filter = filterCopy, page = newPage })
            end,
        })
    end

    W.drawFooter(ctx)
end

---------------------------------------------------------------
-- ContextPanel: fragment detail view
---------------------------------------------------------------

screen.getContextData = function(_params)
    local data = {}

    local entry = _selectedIdx and _lastFragments[_selectedIdx]

    if not entry then
        -- Summary view: counts per type
        table.insert(data, { type = "header", text = "UI_POS_Fragments_Title" })
        table.insert(data, { type = "kv",
            key = "", value = PhobosLib.safeGetText("UI_POS_Fragments_NoSelection") })
        table.insert(data, { type = "separator" })

        local allFragments = _getAllFragments()
        local countByType = { market_fragment = 0, weather_fragment = 0, infrastructure_fragment = 0 }
        for _, f in ipairs(allFragments) do
            if f.type and countByType[f.type] then
                countByType[f.type] = countByType[f.type] + 1
            end
        end

        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Fragments_FilterMarket"),
            value = tostring(countByType.market_fragment) })
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Fragments_FilterWeather"),
            value = tostring(countByType.weather_fragment) })
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Fragments_FilterInfra"),
            value = tostring(countByType.infrastructure_fragment) })
        return data
    end

    -- Detail view for selected fragment
    local fragType = entry.type or "market_fragment"
    local badgeText = _getBadgeText(fragType)
    local badgeInfo = TYPE_BADGES[fragType]
    table.insert(data, { type = "header",
        text = "[" .. badgeText .. "] " .. PhobosLib.safeGetText("UI_POS_Fragments_Detail") })
    table.insert(data, { type = "separator" })

    -- Zone
    local zoneName = entry.zoneId
        and PhobosLib.safeGetText("UI_WBN_Zone_" .. tostring(entry.zoneId))
        or "???"
    if zoneName == ("UI_WBN_Zone_" .. tostring(entry.zoneId)) then
        zoneName = tostring(entry.zoneId)
    end
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Zone"),
        value = zoneName })

    -- Category (if present)
    if entry.categoryId then
        local catName = PhobosLib.safeGetText("UI_POS_Category_" .. tostring(entry.categoryId))
        if catName == ("UI_POS_Category_" .. tostring(entry.categoryId)) then
            catName = tostring(entry.categoryId)
        end
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Categories"),
            value = catName })
    end

    -- Direction (if present)
    if entry.direction then
        local dirDisplay = PhobosLib.safeGetText("UI_POS_Fragments_Dir_" .. tostring(entry.direction))
        if dirDisplay == ("UI_POS_Fragments_Dir_" .. tostring(entry.direction)) then
            dirDisplay = tostring(entry.direction)
        end
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Fragments_Direction"),
            value = dirDisplay })
    end

    -- Estimated change (if present)
    if entry.estimatedChange then
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Fragments_EstimatedChange"),
            value = "~" .. string.format("%.0f%%", entry.estimatedChange) })
    end

    -- Confidence
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Fragments_Confidence"),
        value = string.format("%.0f%%", (entry.confidence or 0) * 100) })

    -- Freshness
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Fragments_Freshness"),
        value = string.format("%.0f%%", (entry.freshness or 0) * 100) })

    -- Received day
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Fragments_ReceivedDay"),
        value = tostring(entry.receivedDay or 0) })

    -- Station
    if entry.stationClassId then
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Fragments_Station"),
            value = tostring(entry.stationClassId) })
    end

    -- Verified status
    local verifiedText
    local verifiedColour
    if entry.verified then
        verifiedText = PhobosLib.safeGetText("UI_POS_Fragments_Verified")
        verifiedColour = "success"
    else
        verifiedText = PhobosLib.safeGetText("UI_POS_Fragments_Unverified")
        verifiedColour = "warning"
    end
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Fragments_VerifiedStatus"),
        value = verifiedText,
        colour = verifiedColour })

    return data
end

---------------------------------------------------------------

screen.destroy = function()
    _selectedIdx = nil
    _lastFragments = {}
    POS_TerminalWidgets.defaultDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
