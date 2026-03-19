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
-- POS_Screen_BBS.lua
-- BBS listing screen for the POSnet terminal.
-- Shows open investment opportunities and active player investments.
-- Widget-based: uses ISButton/ISLabel children in contentPanel.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_BBS_LIST
screen.menuPath = {"pos.bbs"}
screen.titleKey = "UI_POS_BBS_Header"
screen.sortOrder = 10

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_BBS_Header")

    -- ── Open investment opportunities ──
    W.createLabel(ctx.panel, 0, ctx.y,
        W.safeGetText("UI_POS_BBS_OpenInvestments"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH

    local opportunities = {}
    if POS_InvestmentLog then
        opportunities = POS_InvestmentLog.getOpenOpportunities()
    end

    -- On-demand generation if none available
    if #opportunities == 0 and POS_Sandbox and POS_Sandbox.isInvestmentEnabled
       and POS_Sandbox.isInvestmentEnabled()
       and POS_InvestmentGenerator and POS_InvestmentGenerator.generate then
        local opp = POS_InvestmentGenerator.generate()
        if opp and POS_InvestmentLog then
            POS_InvestmentLog.addOpportunity(opp)
            table.insert(opportunities, opp)
            PhobosLib.debug("POS", "[BBS] On-demand investment generated: " .. (opp.id or "?"))
        end
    end

    if #opportunities == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_BBS_NoOpportunities"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (_params and _params.bbsPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = opportunities,
            pageSize = 5,
            currentPage = currentPage,
            x = ctx.btnX,
            y = ctx.y,
            width = ctx.btnW,
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, rw, opp, _idx)
                local riskPct = string.format("%.0f%%", (opp.displayedRisk or 0) * 100)
                local returnX = string.format("%.1fx", opp.returnMultiplier or 1)
                local label = (opp.posterName or "???")
                    .. " -- $" .. (opp.principalMin or 0) .. "-$" .. (opp.principalMax or 0)
                    .. " (" .. returnX .. ", ~" .. riskPct .. " risk)"
                local oppId = opp.id
                W.createButton(parent, rx, ry, rw, ctx.btnH, label, nil,
                    function()
                        POS_ScreenManager.navigateTo(POS_Constants.SCREEN_BBS_POST,
                            { opportunityId = oppId })
                    end)
                return ctx.btnH + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_BBS_LIST,
                    { bbsPage = newPage })
            end,
        })
    end

    ctx.y = ctx.y + 4

    -- ── Active investments ──
    W.createLabel(ctx.panel, 0, ctx.y,
        W.safeGetText("UI_POS_BBS_YourInvestments"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH

    local investments = {}
    if POS_InvestmentLog then
        investments = POS_InvestmentLog.getInvestmentsByStatus(POS_Constants.INV_STATUS_ACTIVE)
    end

    if #investments == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_BBS_NoInvestments"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local gameTime = getGameTime()
        local currentDay = gameTime and gameTime:getNightsSurvived() or 0

        for _, inv in ipairs(investments) do
            local daysLeft = (inv.maturityDay or 0) - currentDay
            if daysLeft < 0 then daysLeft = 0 end
            local line = "  " .. (inv.posterName or "???")
                .. " -- $" .. (inv.principalAmount or 0)
                .. " -> $" .. (inv.returnAmount or 0)
                .. " (" .. daysLeft .. "d left)"
            W.createLabel(ctx.panel, 0, ctx.y, line, C.warn)
            ctx.y = ctx.y + ctx.lineH
        end
    end

    -- ── Recent results ──
    local matured = {}
    local defaulted = {}
    if POS_InvestmentLog then
        matured = POS_InvestmentLog.getInvestmentsByStatus(POS_Constants.INV_STATUS_MATURED)
        defaulted = POS_InvestmentLog.getInvestmentsByStatus(POS_Constants.INV_STATUS_DEFAULTED)
    end

    if #matured > 0 or #defaulted > 0 then
        ctx.y = ctx.y + 4

        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_BBS_RecentResults"), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH

        -- Collect and show last 5 results (most recent first)
        local results = {}
        for _, inv in ipairs(matured) do
            table.insert(results, { inv = inv, status = "matured" })
        end
        for _, inv in ipairs(defaulted) do
            table.insert(results, { inv = inv, status = "defaulted" })
        end

        local shown = 0
        for i = #results, 1, -1 do
            if shown >= 5 then break end
            local r = results[i]
            local prefix, colour
            if r.status == "matured" then
                prefix = "  [OK] "
                colour = C.success
            else
                prefix = "  [!!] "
                colour = C.error
            end
            local line = prefix .. (r.inv.posterName or "???")
                .. " -- $" .. (r.inv.principalAmount or 0)
            if r.status == "matured" then
                line = line .. " -> $" .. (r.inv.returnAmount or 0) .. " PAID"
            else
                line = line .. " DEFAULTED"
            end
            W.createLabel(ctx.panel, 0, ctx.y, line, colour)
            ctx.y = ctx.y + ctx.lineH
            shown = shown + 1
        end
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(_params)
    POS_TerminalWidgets.dynamicRefresh(screen, _params)
end

screen.getContextData = function(_params)
    local data = {}
    if POS_InvestmentLog and POS_InvestmentLog.countActiveInvestments then
        local count = POS_InvestmentLog.countActiveInvestments()
        table.insert(data, { type = "header", text = "UI_POS_Context_MissionInfo" })
        table.insert(data, { type = "kv", key = "UI_POS_Context_ActiveCount", value = tostring(count) })
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
