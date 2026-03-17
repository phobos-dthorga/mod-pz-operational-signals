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

--- Execute an investment action.
---@param oppId string Opportunity ID
---@param amount number Investment amount
---@param returnAmount number Expected return amount
local function performInvestment(oppId, amount, returnAmount)
    local opp = POS_InvestmentLog and POS_InvestmentLog.getOpportunity(oppId)
    if not opp then return end

    local player = getSpecificPlayer(0)
    if not player then return end

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

---------------------------------------------------------------

local screen = {}
screen.id = "BBS_POST_VIEW"

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local pw = contentPanel:getWidth()
    local y = 0
    local lineH = 20
    local btnH = 28
    local btnW = pw - 10
    local btnX = 5

    -- Error: no opportunity specified
    if not params or not params.opportunityId then
        W.createLabel(contentPanel, 0, y, "ERROR: No opportunity specified.", C.error)
        y = y + lineH + 4
        W.createButton(contentPanel, btnX, y, btnW, btnH,
            "[0] " .. safeGetText("UI_POS_BackPrompt"), nil,
            function() POS_ScreenManager.goBack() end)
        return
    end

    local opp = POS_InvestmentLog and POS_InvestmentLog.getOpportunity(params.opportunityId)
    if not opp then
        W.createLabel(contentPanel, 0, y, "ERROR: Opportunity not found.", C.error)
        y = y + lineH + 4
        W.createButton(contentPanel, btnX, y, btnW, btnH,
            "[0] " .. safeGetText("UI_POS_BackPrompt"), nil,
            function() POS_ScreenManager.goBack() end)
        return
    end

    -- Header
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_BBS_PostHeader"), C.textBright)
    y = y + lineH

    W.createSeparator(contentPanel, 0, y, 40)
    y = y + lineH

    -- Poster info
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_BBS_PostedBy") .. " " .. (opp.posterName or "???")
        .. " <" .. (opp.posterHandle or "???") .. ">", C.text)
    y = y + lineH * 2

    -- Description (word-wrapped, quoted)
    local desc = safeGetText(opp.descriptionKey or "UI_POS_BBS_InvDesc_TradeRoute")
    local quotedDesc = "\"" .. desc .. "\""
    local _, endY = W.createWrappedText(contentPanel, 8, y, 38, quotedDesc, C.dim)
    y = endY + lineH

    -- Investment terms
    W.createSeparator(contentPanel, 0, y, 40, "-")
    y = y + lineH

    local riskPct = string.format("~%.0f%%", (opp.displayedRisk or 0) * 100)
    local returnX = string.format("%.1fx", opp.returnMultiplier or 1)

    local gameTime = getGameTime()
    local currentDay = gameTime and gameTime:getNightsSurvived() or 0
    local daysToExpiry = (opp.expiryDay or 0) - currentDay
    if daysToExpiry < 0 then daysToExpiry = 0 end

    W.createLabel(contentPanel, 0, y,
        "  " .. safeGetText("UI_POS_BBS_Payback") .. ":   "
        .. (opp.paybackDays or "?") .. " " .. safeGetText("UI_POS_BBS_Days"), C.text)
    y = y + lineH

    W.createLabel(contentPanel, 0, y,
        "  " .. safeGetText("UI_POS_BBS_EstRisk") .. ":  " .. riskPct, C.warn)
    y = y + lineH

    W.createLabel(contentPanel, 0, y,
        "  " .. safeGetText("UI_POS_BBS_Return") .. ":    " .. returnX
        .. " " .. safeGetText("UI_POS_BBS_YourInvestment"), C.text)
    y = y + lineH

    W.createLabel(contentPanel, 0, y,
        "  " .. safeGetText("UI_POS_BBS_MinMax") .. ":   $"
        .. (opp.principalMin or 0) .. " - $" .. (opp.principalMax or 0), C.text)
    y = y + lineH

    W.createLabel(contentPanel, 0, y,
        "  " .. safeGetText("UI_POS_BBS_Expires") .. ":  "
        .. daysToExpiry .. " " .. safeGetText("UI_POS_BBS_Days"), C.text)
    y = y + lineH * 2

    -- Player's cash
    local player = getSpecificPlayer(0)
    local playerCash = 0
    if player then
        playerCash = PhobosLib.countPlayerMoney(player)
    end

    W.createLabel(contentPanel, 0, y,
        "  " .. safeGetText("UI_POS_BBS_YourCash") .. ": $" .. playerCash, C.text)
    y = y + lineH

    -- Max active investments check
    local maxActive = POS_Sandbox.getMaxActiveInvestments()
    local activeCount = POS_InvestmentLog and POS_InvestmentLog.countActiveInvestments() or 0

    if activeCount >= maxActive then
        y = y + 4
        W.createLabel(contentPanel, 8, y,
            safeGetText("UI_POS_BBS_MaxInvestments"), C.error)
        y = y + lineH
    elseif playerCash < (opp.principalMin or 50) then
        y = y + 4
        W.createLabel(contentPanel, 8, y,
            safeGetText("UI_POS_BBS_CantAfford"), C.error)
        y = y + lineH
    else
        -- Investment tier buttons
        y = y + 4
        W.createSeparator(contentPanel, 0, y, 40, "-")
        y = y + lineH + 4

        local tiers = generateTiers(opp, playerCash)
        for i, amount in ipairs(tiers) do
            local returnAmt = math.floor(amount * (opp.returnMultiplier or 1))
            local label = "[" .. i .. "] " .. safeGetText("UI_POS_BBS_Invest")
                .. " $" .. amount .. " (return: $" .. returnAmt .. ")"

            local investOppId = opp.id
            local investAmt = amount
            local investReturn = returnAmt
            W.createButton(contentPanel, btnX, y, btnW, btnH, label, nil,
                function()
                    performInvestment(investOppId, investAmt, investReturn)
                end)
            y = y + btnH + 4
        end
    end

    -- Back button
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
end

function screen.refresh(params)
    -- Dynamic data — full rebuild via destroy + create
    local terminal = POS_TerminalUI.instance
    if terminal and terminal.contentPanel then
        screen.destroy()
        screen.create(terminal.contentPanel, params, terminal)
    end
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
