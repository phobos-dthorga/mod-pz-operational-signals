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
-- POS_Screen_MarketReports.lua
-- Lists CompiledMarketReport items from player inventory.
-- Each entry shows category, region, price range, compiled date.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketRegistry"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local function getCompiledReports()
    local player = getSpecificPlayer(0)
    if not player then return {} end
    local inv = player:getInventory()
    if not inv then return {} end

    local items = inv:getItemsFromFullType(POS_Constants.ITEM_COMPILED_REPORT)
    if not items then return {} end

    local reports = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local md = item:getModData()
        if md and md[POS_Constants.MD_REPORT_TYPE] == "market" then
            table.insert(reports, {
                item = item,
                categoryId = md[POS_Constants.MD_NOTE_CATEGORY],
                region = md[POS_Constants.MD_REPORT_REGION],
                low = md[POS_Constants.MD_REPORT_LOW],
                high = md[POS_Constants.MD_REPORT_HIGH],
                avg = md[POS_Constants.MD_REPORT_AVG],
                sources = md[POS_Constants.MD_REPORT_SOURCES],
                compiledDay = md[POS_Constants.MD_REPORT_COMPILED],
            })
        end
    end

    -- Sort by compiled day (most recent first)
    table.sort(reports, function(a, b)
        return (a.compiledDay or 0) > (b.compiledDay or 0)
    end)

    return reports
end

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_REPORTS
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_Market_Reports"
screen.sortOrder = 30

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Market_Reports")

    local reports = getCompiledReports()

    if #reports == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoData"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (params and params.reportPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = reports,
            pageSize = POS_Constants.PAGE_SIZE_MARKET_REPORTS,
            currentPage = currentPage,
            x = ctx.btnX,
            y = ctx.y,
            width = ctx.btnW,
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, _rw, report, _idx)
                -- Category name
                local catDef = POS_MarketRegistry.getCategory(report.categoryId)
                local catLabel = catDef and W.safeGetText(catDef.labelKey) or (report.categoryId or "?")
                W.createLabel(parent, rx, ry,
                    catLabel .. " — " .. (report.region or W.safeGetText("UI_POS_Market_Unknown")),
                    C.textBright)
                ry = ry + ctx.lineH

                -- Price range
                local lowStr = report.low and string.format("$%.2f", report.low) or "?"
                local highStr = report.high and string.format("$%.2f", report.high) or "?"
                local avgStr = report.avg and string.format("$%.2f", report.avg) or "?"
                W.createLabel(parent, rx + 8, ry,
                    lowStr .. " — " .. avgStr .. " — " .. highStr
                    .. " (" .. (report.sources or 0) .. " "
                    .. W.safeGetText("UI_POS_Market_Sources") .. ")",
                    C.text)
                ry = ry + ctx.lineH

                -- Compiled date
                W.createLabel(parent, rx + 8, ry,
                    W.safeGetText("UI_POS_Market_CompiledDay")
                    .. ": " .. (report.compiledDay or "?"), C.dim)
                ry = ry + ctx.lineH + 4

                return (ctx.lineH * 3) + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_REPORTS,
                    { reportPage = newPage })
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
    local data = {}
    local reports = getCompiledReports()
    table.insert(data, { type = "kv", key = "UI_POS_Market_ReportCount",
        value = tostring(#reports) })
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
