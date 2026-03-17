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
require "POS_ScreenManager"
require "POS_TerminalWidgets"

local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

local C = POS_TerminalWidgets.COLOURS

--- Additional colours used by BBS screen.
local BBS = {
    good = { r = 0.20, g = 0.90, b = 0.50, a = 1.0 },
}

---------------------------------------------------------------

local screen = {}
screen.id = "BBS_LIST"

local widgets = {}

function screen.create(contentPanel, _params, _terminal)
    widgets = {}
    local W = POS_TerminalWidgets
    local pw = contentPanel:getWidth()
    local y = 0
    local lineH = 20
    local btnH = 28
    local btnW = pw - 10
    local btnX = 5

    -- Header
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_BBS_Header"), C.textBright)
    y = y + lineH

    W.createSeparator(contentPanel, 0, y, 40)
    y = y + lineH

    -- ── Open investment opportunities ──
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_BBS_OpenInvestments"), C.textBright)
    y = y + lineH

    W.createSeparator(contentPanel, 0, y, 40, "-")
    y = y + lineH

    local opportunities = {}
    if POS_InvestmentLog then
        opportunities = POS_InvestmentLog.getOpenOpportunities()
    end

    if #opportunities == 0 then
        W.createLabel(contentPanel, 8, y,
            safeGetText("UI_POS_BBS_NoOpportunities"), C.dim)
        y = y + lineH
    else
        for i, opp in ipairs(opportunities) do
            local riskPct = string.format("%.0f%%", (opp.displayedRisk or 0) * 100)
            local returnX = string.format("%.1fx", opp.returnMultiplier or 1)
            local label = "[" .. i .. "] " .. (opp.posterName or "???")
                .. " -- $" .. (opp.principalMin or 0) .. "-$" .. (opp.principalMax or 0)
                .. " (" .. returnX .. ", ~" .. riskPct .. " risk)"

            local oppId = opp.id
            W.createButton(contentPanel, btnX, y, btnW, btnH, label, nil,
                function()
                    POS_ScreenManager.navigateTo("BBS_POST_VIEW",
                        { opportunityId = oppId })
                end)
            y = y + btnH + 4
        end
    end

    y = y + 4

    -- ── Active investments ──
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_BBS_YourInvestments"), C.textBright)
    y = y + lineH

    W.createSeparator(contentPanel, 0, y, 40, "-")
    y = y + lineH

    local investments = {}
    if POS_InvestmentLog then
        investments = POS_InvestmentLog.getInvestmentsByStatus("active")
    end

    if #investments == 0 then
        W.createLabel(contentPanel, 8, y,
            safeGetText("UI_POS_BBS_NoInvestments"), C.dim)
        y = y + lineH
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
            W.createLabel(contentPanel, 0, y, line, C.warn)
            y = y + lineH
        end
    end

    -- ── Recent results ──
    local matured = {}
    local defaulted = {}
    if POS_InvestmentLog then
        matured = POS_InvestmentLog.getInvestmentsByStatus("matured")
        defaulted = POS_InvestmentLog.getInvestmentsByStatus("defaulted")
    end

    if #matured > 0 or #defaulted > 0 then
        y = y + 4

        W.createLabel(contentPanel, 0, y,
            safeGetText("UI_POS_BBS_RecentResults"), C.textBright)
        y = y + lineH

        W.createSeparator(contentPanel, 0, y, 40, "-")
        y = y + lineH

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
                colour = BBS.good
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
            W.createLabel(contentPanel, 0, y, line, colour)
            y = y + lineH
            shown = shown + 1
        end
    end

    -- Footer
    y = y + 4
    W.createSeparator(contentPanel, 0, y, 40, "-")
    y = y + lineH + 4

    W.createButton(contentPanel, btnX, y, btnW, btnH,
        "[0] " .. safeGetText("UI_POS_BackPrompt"), nil,
        function() POS_ScreenManager.goBack() end)
end

function screen.destroy()
    if POS_TerminalUI.instance and POS_TerminalUI.instance.contentPanel then
        POS_TerminalWidgets.clearPanel(POS_TerminalUI.instance.contentPanel)
    end
    widgets = {}
end

function screen.refresh(_params)
    -- Dynamic data — full rebuild via destroy + create
    local terminal = POS_TerminalUI.instance
    if terminal and terminal.contentPanel then
        screen.destroy()
        screen.create(terminal.contentPanel, _params, terminal)
    end
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
