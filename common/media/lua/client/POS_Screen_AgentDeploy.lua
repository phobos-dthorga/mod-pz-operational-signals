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
-- POS_Screen_AgentDeploy.lua
-- Archetype picker and deployment confirmation screen.
-- Navigated to from Contract ContextPanel [Send Agent] button.
--
-- Flow:
--   1. Shows contract summary (kind, item, qty, payout)
--   2. Archetype buttons with commission/risk/ETA
--   3. Cost preview (items consumed + commission deducted)
--   4. [Confirm Deployment] → POS_FreeAgentService.deploy()
--
-- See design-guidelines.md §46.7.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_ContractService"
require "POS_FreeAgentService"
require "POS_API"

---------------------------------------------------------------

local _TAG = "[POS:AgentDeploy]"

local _selectedArchetype = nil

---------------------------------------------------------------
-- Archetype data (derived from POS_Constants)
---------------------------------------------------------------

local ARCHETYPE_ORDER = {
    POS_Constants.FREE_AGENT_ARCHETYPE_RUNNER,
    POS_Constants.FREE_AGENT_ARCHETYPE_COURIER,
    POS_Constants.FREE_AGENT_ARCHETYPE_BROKER,
    POS_Constants.FREE_AGENT_ARCHETYPE_SMUGGLER,
    POS_Constants.FREE_AGENT_ARCHETYPE_CONTACT,
}

local function getArchetypeInfo(archId)
    return {
        id         = archId,
        label      = PhobosLib.safeGetText("UI_POS_FreeAgent_Archetype_" .. archId),
        commission = POS_Constants.FREE_AGENT_COMMISSION_RATES[archId]
            or POS_Constants.FREE_AGENT_DEFAULT_COMMISSION,
        risk       = POS_Constants.FREE_AGENT_RISK_LEVELS[archId]
            or POS_Constants.FREE_AGENT_DEFAULT_RISK,
        eta        = POS_Constants.FREE_AGENT_ESTIMATED_DAYS[archId]
            or POS_Constants.FREE_AGENT_DEFAULT_ESTIMATED_DAYS,
    }
end

local function getRiskLabel(riskLevel)
    if riskLevel >= POS_Constants.RISK_THRESHOLD_HIGH then return "HIGH" end
    if riskLevel >= POS_Constants.RISK_THRESHOLD_MODERATE then return "MODERATE" end
    return "LOW"
end

local function getItemDisplayName(fullType)
    if PhobosLib.getItemDisplayName then
        return PhobosLib.getItemDisplayName(fullType)
    end
    return fullType
end

---------------------------------------------------------------
-- Screen definition
---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_AGENT_DEPLOY
screen.menuPath = nil  -- programmatic navigation only
screen.titleKey = "UI_POS_AgentDeploy_Title"
screen.requires = { connected = true }

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    _selectedArchetype = (params and params.selectedArchetype) or _selectedArchetype

    W.drawHeader(ctx, "UI_POS_AgentDeploy_Title")

    -- Load contract
    local contractId = params and params.contractId
    local contract = contractId and POS_ContractService.get(contractId)

    if not contract then
        W.createLabel(contentPanel, 8, ctx.y,
            "No contract specified.", C.error)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- Contract summary
    local itemName = contract.resolvedItemType
        and getItemDisplayName(contract.resolvedItemType)
        or (contract.categoryId or "?")
    local qty = contract.resolvedQuantity or 0
    local payout = contract.resolvedPayout or 0

    W.createLabel(contentPanel, 8, ctx.y,
        PhobosLib.safeGetText("UI_POS_Contract_Title") .. ": "
        .. (contract.briefing and contract.briefing.title or contract.kind or "?"),
        C.textBright)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(contentPanel, 8, ctx.y,
        PhobosLib.safeGetText("UI_POS_AgentDeploy_CargoCost") .. ": "
        .. tostring(qty) .. "x " .. itemName,
        C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(contentPanel, 8, ctx.y,
        "Payout: $" .. string.format("%.2f", payout),
        C.text)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(contentPanel, 0, ctx.y, 50, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Archetype selector
    W.createLabel(contentPanel, 8, ctx.y,
        PhobosLib.safeGetText("UI_POS_AgentDeploy_SelectArchetype"),
        C.textBright)
    ctx.y = ctx.y + ctx.lineH + 2

    for _, archId in ipairs(ARCHETYPE_ORDER) do
        local info = getArchetypeInfo(archId)
        local isSelected = (_selectedArchetype == archId)
        local riskLabel = getRiskLabel(info.risk)

        local label = info.label
            .. "  |  " .. PhobosLib.safeGetText("UI_POS_AgentDeploy_Commission")
            .. ": " .. tostring(math.floor(info.commission * 100)) .. "%"
            .. "  |  " .. PhobosLib.safeGetText("UI_POS_AgentDeploy_Risk")
            .. ": " .. riskLabel
            .. "  |  " .. PhobosLib.safeGetText("UI_POS_AgentDeploy_EstimatedTime")
            .. ": ~" .. tostring(info.eta) .. "d"

        if isSelected then
            W.createLabel(contentPanel, 8, ctx.y + 2,
                "> " .. label, C.textBright)
            ctx.y = ctx.y + ctx.lineH + 2
        else
            local aId = archId
            local cId = contractId
            W.createButton(contentPanel, 4, ctx.y,
                contentPanel:getWidth() - 8, ctx.btnH,
                label, nil, function()
                    _selectedArchetype = aId
                    POS_ScreenManager.replaceCurrent(
                        POS_Constants.SCREEN_AGENT_DEPLOY,
                        { contractId = cId, selectedArchetype = aId })
                end)
            ctx.y = ctx.y + ctx.btnH + 2
        end
    end

    ctx.y = ctx.y + 4
    W.createSeparator(contentPanel, 0, ctx.y, 50, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Cost preview (if archetype selected)
    if _selectedArchetype then
        local info = getArchetypeInfo(_selectedArchetype)
        local commission = payout * info.commission
        local netPayout = payout - commission

        W.createLabel(contentPanel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_AgentDeploy_CargoCost")
            .. ": " .. tostring(qty) .. "x " .. itemName
            .. " (consumed from inventory)",
            C.warning)
        ctx.y = ctx.y + ctx.lineH

        W.createLabel(contentPanel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_AgentDeploy_Commission")
            .. ": $" .. string.format("%.2f", commission)
            .. " (" .. tostring(math.floor(info.commission * 100)) .. "%)",
            C.dim)
        ctx.y = ctx.y + ctx.lineH

        W.createLabel(contentPanel, 8, ctx.y,
            "Net payout: $" .. string.format("%.2f", netPayout),
            C.success)
        ctx.y = ctx.y + ctx.lineH + 4

        -- Inventory check
        local player = getPlayer()
        local owned = 0
        if player and contract.resolvedItemType and PhobosLib.findAllItemsByFullType then
            local found = PhobosLib.findAllItemsByFullType(player, contract.resolvedItemType)
            owned = type(found) == "table" and #found or (type(found) == "number" and found or 0)
        end
        local hasEnough = owned >= qty
        local invColour = hasEnough and C.success or C.error
        W.createLabel(contentPanel, 8, ctx.y,
            "Inventory: " .. tostring(owned) .. "/" .. tostring(qty),
            invColour)
        ctx.y = ctx.y + ctx.lineH + 4

        -- Confirm button
        local cId = contractId
        local archId = _selectedArchetype
        local zoneId = contract.zoneId or ""
        local cargoType = contract.resolvedItemType or ""
        local cargoQty = qty
        local payAmt = payout

        if hasEnough then
            W.createButton(contentPanel, 4, ctx.y,
                contentPanel:getWidth() - 8, ctx.btnH + 4,
                PhobosLib.safeGetText("UI_POS_AgentDeploy_Confirm"), nil,
                function()
                    local agent, err = POS_FreeAgentService.deploy(
                        cId, archId, zoneId, cargoType, cargoQty, payAmt)
                    if agent then
                        _selectedArchetype = nil
                        POS_ScreenManager.navigateTo("pos.bbs.agents")
                    else
                        PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
                            title   = "POSnet",
                            message = err or PhobosLib.safeGetText("UI_POS_AgentDeploy_NoSlots"),
                            colour  = "error",
                            channel = POS_Constants.PN_CHANNEL_AGENTS,
                        })
                    end
                end)
            ctx.y = ctx.y + ctx.btnH + 6
        else
            W.createLabel(contentPanel, 8, ctx.y,
                PhobosLib.safeGetText("UI_POS_AgentDeploy_InsufficientCargo"),
                C.error)
            ctx.y = ctx.y + ctx.lineH
        end
    else
        W.createLabel(contentPanel, 8, ctx.y,
            "Select an agent type above to proceed.", C.dim)
        ctx.y = ctx.y + ctx.lineH
    end

    W.drawFooter(ctx)
end

function screen.destroy()
    _selectedArchetype = nil
    POS_TerminalWidgets.defaultDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

POS_API.registerScreen(screen)
