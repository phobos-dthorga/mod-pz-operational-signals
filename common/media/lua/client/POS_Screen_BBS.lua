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
---------------------------------------------------------------

require "PhobosLib"
require "POS_ScreenManager"

local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

local TERM = {
    text   = { r = 0.20, g = 0.90, b = 0.20 },
    dim    = { r = 0.12, g = 0.50, b = 0.12 },
    header = { r = 0.30, g = 1.00, b = 0.30 },
    warn   = { r = 0.90, g = 0.80, b = 0.10 },
    err    = { r = 0.90, g = 0.25, b = 0.20 },
    good   = { r = 0.20, g = 0.90, b = 0.50 },
}

---------------------------------------------------------------

local screen = {}
screen.id = "BBS_LIST"

function screen.rebuildLines(_terminal, _params)
    local lines = {}
    local hitZones = {}

    -- Header
    table.insert(lines, { text = safeGetText("UI_POS_BBS_Header"), colour = TERM.header })
    table.insert(lines, { text = string.rep("=", 40), colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })

    -- Investment opportunities section
    table.insert(lines, { text = safeGetText("UI_POS_BBS_OpenInvestments"), colour = TERM.header })
    table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })

    local opportunities = {}
    if POS_InvestmentLog then
        opportunities = POS_InvestmentLog.getOpenOpportunities()
    end

    if #opportunities == 0 then
        table.insert(lines, { text = "", colour = TERM.text })
        table.insert(lines, { text = "  " .. safeGetText("UI_POS_BBS_NoOpportunities"), colour = TERM.dim })
        table.insert(lines, { text = "", colour = TERM.text })
    else
        table.insert(lines, { text = "", colour = TERM.text })
        for i, opp in ipairs(opportunities) do
            local riskPct = string.format("%.0f%%", (opp.displayedRisk or 0) * 100)
            local returnX = string.format("%.1fx", opp.returnMultiplier or 1)
            local label = "[" .. i .. "] " .. (opp.posterName or "???")
                .. " — $" .. (opp.principalMin or 0) .. "-$" .. (opp.principalMax or 0)
                .. " (" .. returnX .. ", ~" .. riskPct .. " risk)"

            local lineIdx = #lines + 1
            table.insert(lines, { text = label, colour = TERM.text })
            table.insert(hitZones, {
                lineIndex = lineIdx,
                actionId = "viewPost",
                data = { opportunityId = opp.id },
            })
        end
        table.insert(lines, { text = "", colour = TERM.text })
    end

    -- Active investments section
    table.insert(lines, { text = safeGetText("UI_POS_BBS_YourInvestments"), colour = TERM.header })
    table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })

    local investments = {}
    if POS_InvestmentLog then
        investments = POS_InvestmentLog.getInvestmentsByStatus("active")
    end

    if #investments == 0 then
        table.insert(lines, { text = "", colour = TERM.text })
        table.insert(lines, { text = "  " .. safeGetText("UI_POS_BBS_NoInvestments"), colour = TERM.dim })
    else
        table.insert(lines, { text = "", colour = TERM.text })
        local gameTime = getGameTime()
        local currentDay = gameTime and gameTime:getNightsSurvived() or 0

        for _, inv in ipairs(investments) do
            local daysLeft = (inv.maturityDay or 0) - currentDay
            if daysLeft < 0 then daysLeft = 0 end
            local line = "  " .. (inv.posterName or "???")
                .. " — $" .. (inv.principalAmount or 0)
                .. " -> $" .. (inv.returnAmount or 0)
                .. " (" .. daysLeft .. "d left)"
            table.insert(lines, { text = line, colour = TERM.warn })
        end
    end

    -- Recent results section
    local matured = {}
    local defaulted = {}
    if POS_InvestmentLog then
        matured = POS_InvestmentLog.getInvestmentsByStatus("matured")
        defaulted = POS_InvestmentLog.getInvestmentsByStatus("defaulted")
    end

    if #matured > 0 or #defaulted > 0 then
        table.insert(lines, { text = "", colour = TERM.text })
        table.insert(lines, { text = safeGetText("UI_POS_BBS_RecentResults"), colour = TERM.header })
        table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })
        table.insert(lines, { text = "", colour = TERM.text })

        -- Show last 5 results (most recent first)
        local results = {}
        for _, inv in ipairs(matured) do
            table.insert(results, { inv = inv, status = "matured" })
        end
        for _, inv in ipairs(defaulted) do
            table.insert(results, { inv = inv, status = "defaulted" })
        end

        -- Show up to 5
        local shown = 0
        for i = #results, 1, -1 do
            if shown >= 5 then break end
            local r = results[i]
            local prefix, colour
            if r.status == "matured" then
                prefix = "  [OK] "
                colour = TERM.good
            else
                prefix = "  [!!] "
                colour = TERM.err
            end
            local line = prefix .. (r.inv.posterName or "???")
                .. " — $" .. (r.inv.principalAmount or 0)
            if r.status == "matured" then
                line = line .. " -> $" .. (r.inv.returnAmount or 0) .. " PAID"
            else
                line = line .. " DEFAULTED"
            end
            table.insert(lines, { text = line, colour = colour })
            shown = shown + 1
        end
    end

    -- Footer
    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })

    local backIdx = #lines + 1
    table.insert(lines, { text = "[0] " .. safeGetText("UI_POS_BackPrompt"), colour = TERM.text })
    table.insert(hitZones, { lineIndex = backIdx, actionId = "back" })

    return lines, hitZones
end

function screen.onAction(_terminal, actionId, data)
    if actionId == "back" then
        POS_ScreenManager.goBack()
    elseif actionId == "viewPost" and data and data.opportunityId then
        POS_ScreenManager.navigateTo("BBS_POST_VIEW", { opportunityId = data.opportunityId })
    end
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
