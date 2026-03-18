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
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_API"

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
    sendClientCommand(player, POS_Constants.CMD_MODULE, POS_Constants.CMD_PLAYER_INVESTED, {
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
screen.id = POS_Constants.SCREEN_BBS_POST
screen.menuPath = {}  -- navigated programmatically, not in any menu
screen.titleKey = "UI_POS_BBSPost_Header"

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Error: no opportunity specified
    if not params or not params.opportunityId then
        W.createLabel(ctx.panel, 0, ctx.y, "ERROR: No opportunity specified.", C.error)
        ctx.y = ctx.y + ctx.lineH + 4
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[0] " .. W.safeGetText("UI_POS_BackPrompt"), nil,
            function() POS_ScreenManager.goBack() end)
        return
    end

    local opp = POS_InvestmentLog and POS_InvestmentLog.getOpportunity(params.opportunityId)
    if not opp then
        W.createLabel(ctx.panel, 0, ctx.y, "ERROR: Opportunity not found.", C.error)
        ctx.y = ctx.y + ctx.lineH + 4
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[0] " .. W.safeGetText("UI_POS_BackPrompt"), nil,
            function() POS_ScreenManager.goBack() end)
        return
    end

    -- Header
    W.drawHeader(ctx, "UI_POS_BBS_PostHeader")

    -- Poster info
    W.createLabel(ctx.panel, 0, ctx.y,
        W.safeGetText("UI_POS_BBS_PostedBy") .. " " .. (opp.posterName or "???")
        .. " <" .. (opp.posterHandle or "???") .. ">", C.text)
    ctx.y = ctx.y + ctx.lineH * 2

    -- Description (word-wrapped, quoted)
    local desc = W.safeGetText(opp.descriptionKey or "UI_POS_BBS_InvDesc_TradeRoute")
    local quotedDesc = "\"" .. desc .. "\""
    local _, endY = W.createWrappedText(ctx.panel, 8, ctx.y, 38, quotedDesc, C.dim)
    ctx.y = endY + ctx.lineH

    -- Investment terms
    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH

    local riskPct = string.format("~%.0f%%", (opp.displayedRisk or 0) * 100)
    local returnX = string.format("%.1fx", opp.returnMultiplier or 1)

    local gameTime = getGameTime()
    local currentDay = gameTime and gameTime:getNightsSurvived() or 0
    local daysToExpiry = (opp.expiryDay or 0) - currentDay
    if daysToExpiry < 0 then daysToExpiry = 0 end

    W.createLabel(ctx.panel, 0, ctx.y,
        "  " .. W.safeGetText("UI_POS_BBS_Payback") .. ":   "
        .. (opp.paybackDays or "?") .. " " .. W.safeGetText("UI_POS_BBS_Days"), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 0, ctx.y,
        "  " .. W.safeGetText("UI_POS_BBS_EstRisk") .. ":  " .. riskPct, C.warn)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 0, ctx.y,
        "  " .. W.safeGetText("UI_POS_BBS_Return") .. ":    " .. returnX
        .. " " .. W.safeGetText("UI_POS_BBS_YourInvestment"), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 0, ctx.y,
        "  " .. W.safeGetText("UI_POS_BBS_MinMax") .. ":   $"
        .. (opp.principalMin or 0) .. " - $" .. (opp.principalMax or 0), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 0, ctx.y,
        "  " .. W.safeGetText("UI_POS_BBS_Expires") .. ":  "
        .. daysToExpiry .. " " .. W.safeGetText("UI_POS_BBS_Days"), C.text)
    ctx.y = ctx.y + ctx.lineH * 2

    -- Player's cash
    local player = getSpecificPlayer(0)
    local playerCash = 0
    if player then
        playerCash = PhobosLib.countPlayerMoney(player)
    end

    W.createLabel(ctx.panel, 0, ctx.y,
        "  " .. W.safeGetText("UI_POS_BBS_YourCash") .. ": $" .. playerCash, C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Max active investments check
    local maxActive = POS_Sandbox.getMaxActiveInvestments()
    local activeCount = POS_InvestmentLog and POS_InvestmentLog.countActiveInvestments() or 0

    if activeCount >= maxActive then
        ctx.y = ctx.y + 4
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_BBS_MaxInvestments"), C.error)
        ctx.y = ctx.y + ctx.lineH
    elseif playerCash < (opp.principalMin or 50) then
        ctx.y = ctx.y + 4
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_BBS_CantAfford"), C.error)
        ctx.y = ctx.y + ctx.lineH
    else
        -- Investment tier buttons
        ctx.y = ctx.y + 4
        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH + 4

        local tiers = generateTiers(opp, playerCash)
        for i, amount in ipairs(tiers) do
            local returnAmt = math.floor(amount * (opp.returnMultiplier or 1))
            local label = "[" .. i .. "] " .. W.safeGetText("UI_POS_BBS_Invest")
                .. " $" .. amount .. " (return: $" .. returnAmt .. ")"

            local investOppId = opp.id
            local investAmt = amount
            local investReturn = returnAmt
            W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH, label, nil,
                function()
                    performInvestment(investOppId, investAmt, investReturn)
                end)
            ctx.y = ctx.y + ctx.btnH + 4
        end
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function(params)
    local data = {}
    if not params or not params.opportunityId then return data end
    local opp = POS_InvestmentLog and POS_InvestmentLog.getOpportunity
        and POS_InvestmentLog.getOpportunity(params.opportunityId)
    if opp then
        table.insert(data, { type = "header", text = "UI_POS_Context_MissionInfo" })
        if opp.displayedRisk then
            local riskPct = math.floor(opp.displayedRisk * 100)
            table.insert(data, { type = "kv", key = "UI_POS_Context_Risk", value = riskPct .. "%" })
        end
        if opp.returnMultiplier then
            local retPct = math.floor((opp.returnMultiplier - 1) * 100)
            table.insert(data, { type = "kv", key = "UI_POS_Context_ExpectedReturn", value = retPct .. "%" })
        end
        if opp.paybackDays then
            table.insert(data, { type = "kv", key = "UI_POS_Context_Duration", value = tostring(opp.paybackDays) .. "d" })
        end
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
