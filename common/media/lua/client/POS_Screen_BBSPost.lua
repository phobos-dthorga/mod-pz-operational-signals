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
-- POS_Screen_BBSPost.lua
-- BBS post detail view with preset investment tier selection.
--
-- Shows full investment terms, risk display, and 3-4 clickable
-- investment tiers dynamically generated based on principal range
-- and the player's available cash.
---------------------------------------------------------------

require "PhobosLib"

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
}

---------------------------------------------------------------
-- Tier generation
---------------------------------------------------------------

--- Generate investment tier amounts for an opportunity.
--- Returns 3-4 tiers within principalMin/Max, capped by player's cash.
---@param opp table Investment opportunity
---@param playerCash number Player's available cash
---@return table Array of tier amounts (sorted ascending)
local function generateTiers(opp, playerCash)
    local pMin = opp.principalMin or 50
    local pMax = opp.principalMax or 500
    local effectiveMax = math.min(pMax, playerCash)

    if effectiveMax < pMin then
        return {}  -- Can't afford any tier
    end

    local tiers = {}
    local range = effectiveMax - pMin

    if range <= 0 then
        -- Only one possible amount
        table.insert(tiers, pMin)
    elseif range <= 100 then
        -- Small range: 2 tiers (min and max)
        table.insert(tiers, pMin)
        if effectiveMax > pMin then
            table.insert(tiers, effectiveMax)
        end
    else
        -- Normal range: 3-4 tiers spread across the range
        table.insert(tiers, pMin)

        local mid1 = math.floor(pMin + range * 0.33)
        -- Round to nearest 10 for clean display
        mid1 = math.floor(mid1 / 10) * 10
        if mid1 > pMin and mid1 < effectiveMax then
            table.insert(tiers, mid1)
        end

        local mid2 = math.floor(pMin + range * 0.66)
        mid2 = math.floor(mid2 / 10) * 10
        if mid2 > (tiers[#tiers] or 0) and mid2 < effectiveMax then
            table.insert(tiers, mid2)
        end

        if effectiveMax > (tiers[#tiers] or 0) then
            table.insert(tiers, effectiveMax)
        end
    end

    return tiers
end

---------------------------------------------------------------

local screen = {}
screen.id = "BBS_POST_VIEW"

function screen.rebuildLines(terminal, params)
    local lines = {}
    local hitZones = {}

    if not params or not params.opportunityId then
        table.insert(lines, { text = "ERROR: No opportunity specified.", colour = TERM.err })
        local backIdx = #lines + 1
        table.insert(lines, { text = "[0] " .. safeGetText("UI_POS_BackPrompt"), colour = TERM.text })
        table.insert(hitZones, { lineIndex = backIdx, actionId = "back" })
        return lines, hitZones
    end

    local opp = POS_InvestmentLog and POS_InvestmentLog.getOpportunity(params.opportunityId)
    if not opp then
        table.insert(lines, { text = "ERROR: Opportunity not found.", colour = TERM.err })
        local backIdx = #lines + 1
        table.insert(lines, { text = "[0] " .. safeGetText("UI_POS_BackPrompt"), colour = TERM.text })
        table.insert(hitZones, { lineIndex = backIdx, actionId = "back" })
        return lines, hitZones
    end

    -- Header
    table.insert(lines, { text = safeGetText("UI_POS_BBS_PostHeader"), colour = TERM.header })
    table.insert(lines, { text = string.rep("=", 40), colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })

    -- Poster info
    table.insert(lines, {
        text = safeGetText("UI_POS_BBS_PostedBy") .. " " .. (opp.posterName or "???")
            .. " <" .. (opp.posterHandle or "???") .. ">",
        colour = TERM.text
    })
    table.insert(lines, { text = "", colour = TERM.text })

    -- Description
    local desc = safeGetText(opp.descriptionKey or "UI_POS_BBS_InvDesc_TradeRoute")
    -- Wrap long description (split by words, max ~38 chars per line)
    local words = {}
    for word in desc:gmatch("%S+") do
        table.insert(words, word)
    end
    local currentLine = "  \""
    for _, word in ipairs(words) do
        if #currentLine + #word + 1 > 38 then
            table.insert(lines, { text = currentLine, colour = TERM.dim })
            currentLine = "   " .. word
        else
            currentLine = currentLine .. " " .. word
        end
    end
    currentLine = currentLine .. "\""
    table.insert(lines, { text = currentLine, colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })

    -- Investment terms
    table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })

    local riskPct = string.format("~%.0f%%", (opp.displayedRisk or 0) * 100)
    local returnX = string.format("%.1fx", opp.returnMultiplier or 1)

    local gameTime = getGameTime()
    local currentDay = gameTime and gameTime:getNightsSurvived() or 0
    local daysToExpiry = (opp.expiryDay or 0) - currentDay
    if daysToExpiry < 0 then daysToExpiry = 0 end

    table.insert(lines, {
        text = "  " .. safeGetText("UI_POS_BBS_Payback") .. ":   " .. (opp.paybackDays or "?") .. " " .. safeGetText("UI_POS_BBS_Days"),
        colour = TERM.text
    })
    table.insert(lines, {
        text = "  " .. safeGetText("UI_POS_BBS_EstRisk") .. ":  " .. riskPct,
        colour = TERM.warn
    })
    table.insert(lines, {
        text = "  " .. safeGetText("UI_POS_BBS_Return") .. ":    " .. returnX .. " " .. safeGetText("UI_POS_BBS_YourInvestment"),
        colour = TERM.text
    })
    table.insert(lines, {
        text = "  " .. safeGetText("UI_POS_BBS_MinMax") .. ":   $" .. (opp.principalMin or 0) .. " - $" .. (opp.principalMax or 0),
        colour = TERM.text
    })
    table.insert(lines, {
        text = "  " .. safeGetText("UI_POS_BBS_Expires") .. ":  " .. daysToExpiry .. " " .. safeGetText("UI_POS_BBS_Days"),
        colour = TERM.text
    })

    table.insert(lines, { text = "", colour = TERM.text })

    -- Player's cash
    local player = getSpecificPlayer(0)
    local playerCash = 0
    if player then
        playerCash = PhobosLib.countPlayerMoney(player)
    end

    table.insert(lines, {
        text = "  " .. safeGetText("UI_POS_BBS_YourCash") .. ": $" .. playerCash,
        colour = TERM.text
    })

    -- Max active investments check
    local maxActive = POS_Sandbox.getMaxActiveInvestments()
    local activeCount = POS_InvestmentLog and POS_InvestmentLog.countActiveInvestments() or 0

    if activeCount >= maxActive then
        table.insert(lines, { text = "", colour = TERM.text })
        table.insert(lines, {
            text = "  " .. safeGetText("UI_POS_BBS_MaxInvestments"),
            colour = TERM.err
        })
    elseif playerCash < (opp.principalMin or 50) then
        table.insert(lines, { text = "", colour = TERM.text })
        table.insert(lines, {
            text = "  " .. safeGetText("UI_POS_BBS_CantAfford"),
            colour = TERM.err
        })
    else
        -- Investment tiers
        table.insert(lines, { text = "", colour = TERM.text })
        table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })
        table.insert(lines, { text = "", colour = TERM.text })

        local tiers = generateTiers(opp, playerCash)
        for i, amount in ipairs(tiers) do
            local returnAmt = math.floor(amount * (opp.returnMultiplier or 1))
            local label = "[" .. i .. "] " .. safeGetText("UI_POS_BBS_Invest")
                .. " $" .. amount .. " (return: $" .. returnAmt .. ")"

            local lineIdx = #lines + 1
            table.insert(lines, { text = label, colour = TERM.text })
            table.insert(hitZones, {
                lineIndex = lineIdx,
                actionId = "invest",
                data = {
                    opportunityId = opp.id,
                    amount = amount,
                    returnAmount = returnAmt,
                },
            })
        end
    end

    -- Back option
    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })
    local backIdx = #lines + 1
    table.insert(lines, { text = "[0] " .. safeGetText("UI_POS_BackPrompt"), colour = TERM.text })
    table.insert(hitZones, { lineIndex = backIdx, actionId = "back" })

    return lines, hitZones
end

function screen.onAction(terminal, actionId, data)
    if actionId == "back" then
        POS_ScreenManager.goBack()
    elseif actionId == "invest" and data then
        -- Perform the investment
        local opp = POS_InvestmentLog and POS_InvestmentLog.getOpportunity(data.opportunityId)
        if not opp then return end

        local player = getSpecificPlayer(0)
        if not player then return end

        local amount = data.amount
        local returnAmount = data.returnAmount

        -- Verify player can still afford it
        if not PhobosLib.canAfford(player, amount) then
            PhobosLib.debug("POS", "[BBSPost] Player can no longer afford $" .. amount)
            POS_ScreenManager.markDirty()
            return
        end

        -- Check max active investments
        local maxActive = POS_Sandbox.getMaxActiveInvestments()
        local activeCount = POS_InvestmentLog.countActiveInvestments()
        if activeCount >= maxActive then
            PhobosLib.debug("POS", "[BBSPost] Max active investments reached")
            POS_ScreenManager.markDirty()
            return
        end

        -- Remove money from player
        local removed = PhobosLib.removeMoney(player, amount)
        if not removed then
            PhobosLib.debug("POS", "[BBSPost] Failed to remove $" .. amount)
            POS_ScreenManager.markDirty()
            return
        end

        -- Calculate maturity day
        local gameTime = getGameTime()
        local currentDay = gameTime and gameTime:getNightsSurvived() or 0
        local maturityDay = currentDay + (opp.paybackDays or 30)

        -- Record investment locally
        POS_InvestmentLog.recordInvestment(
            opp.id, amount, returnAmount, maturityDay,
            opp.actualRisk, opp.posterName
        )

        -- Mark opportunity as funded
        POS_InvestmentLog.markOpportunityFunded(opp.id)

        -- Notify server for resolution tracking
        sendClientCommand(player, "POS", "PlayerInvested", {
            investmentId = opp.id,
            principalAmount = amount,
            returnAmount = returnAmount,
            maturityDay = maturityDay,
            actualRisk = opp.actualRisk,
        })

        PhobosLib.debug("POS", "[BBSPost] Invested $" .. amount
            .. " in " .. opp.id .. " (return $" .. returnAmount
            .. " in " .. (opp.paybackDays or "?") .. " days)")

        -- Navigate back to BBS list
        POS_ScreenManager.goBack()
    end
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
