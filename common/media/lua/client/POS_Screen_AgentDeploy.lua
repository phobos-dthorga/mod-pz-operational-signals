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

    -- Load contract (optional — nil for standalone trade runs)
    local contractId = params and params.contractId
    local contract = contractId and POS_ContractService.get(contractId)
    local isStandalone = (contract == nil)

    -- Resolve cargo/payout context
    local itemName = nil
    local qty = 0
    local payout = 0

    if contract then
        -- Contract-linked mode: cargo + payout from contract
        itemName = contract.resolvedItemType
            and getItemDisplayName(contract.resolvedItemType)
            or (contract.categoryId or "?")
        qty = contract.resolvedQuantity or 0
        payout = contract.resolvedPayout or 0

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
    else
        -- Standalone trade run: no contract, agent does a speculative run
        itemName = PhobosLib.safeGetText("UI_POS_AgentDeploy_GeneralCargo")
        qty = 0
        payout = 0

        W.createLabel(contentPanel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_AgentDeploy_StandaloneTitle"),
            C.textBright)
        ctx.y = ctx.y + ctx.lineH

        W.createLabel(contentPanel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_AgentDeploy_StandaloneDesc"),
            C.dim)
        ctx.y = ctx.y + ctx.lineH + 4
    end

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

    -- Cost preview + confirm (if archetype selected)
    if _selectedArchetype then
        local info = getArchetypeInfo(_selectedArchetype)

        if not isStandalone then
            -- Contract mode: show cargo cost + commission + inventory
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
                PhobosLib.safeGetText("UI_POS_FreeAgent_NetPayout")
                .. ": $" .. string.format("%.2f", netPayout),
                C.success)
            ctx.y = ctx.y + ctx.lineH
        else
            -- Standalone mode: no cargo cost, agent works on commission
            W.createLabel(contentPanel, 8, ctx.y,
                PhobosLib.safeGetText("UI_POS_AgentDeploy_StandaloneCost"),
                C.dim)
            ctx.y = ctx.y + ctx.lineH
        end

        -- SIGINT bonus display
        local player = getPlayer()
        local sigintLvl = PhobosLib.getPlayerPerkLevel
            and PhobosLib.getPlayerPerkLevel(player, POS_Constants.PERK_SIGINT) or 0
        if sigintLvl > 0 then
            local sigintPct = math.floor(sigintLvl
                * POS_Constants.FREE_AGENT_SIGINT_RISK_REDUCTION_PER_LEVEL * 100)
            W.createLabel(contentPanel, 8, ctx.y,
                PhobosLib.safeGetText("UI_POS_FreeAgent_SigintBonus")
                .. ": -" .. tostring(sigintPct) .. "% risk",
                C.textBright)
            ctx.y = ctx.y + ctx.lineH
        end
        ctx.y = ctx.y + 4

        -- Inventory check (contract mode only)
        local hasEnough = true
        if not isStandalone then
            local player2 = getPlayer()
            local owned = 0
            if player2 and contract.resolvedItemType and PhobosLib.findAllItemsByFullType then
                local found = PhobosLib.findAllItemsByFullType(player2, contract.resolvedItemType)
                owned = type(found) == "table" and #found or (type(found) == "number" and found or 0)
            end
            hasEnough = owned >= qty
            local invColour = hasEnough and C.success or C.error
            W.createLabel(contentPanel, 8, ctx.y,
                PhobosLib.safeGetText("UI_POS_Inventory") .. ": " .. tostring(owned) .. "/" .. tostring(qty),
                invColour)
            ctx.y = ctx.y + ctx.lineH + 4
        end

        -- Confirm deploy button
        local cId = contractId or ""
        local archId = _selectedArchetype
        local zoneId = (contract and contract.zoneId) or ""
        local cargoType = (contract and contract.resolvedItemType) or ""
        local cargoQty = qty
        local payAmt = payout

        -- For standalone: pick a random zone for the trade run
        if isStandalone and zoneId == "" then
            local zones = POS_Constants.MARKET_ZONES or {}
            if #zones > 0 then
                zoneId = zones[ZombRand(#zones) + 1]
            end
        end

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
            PhobosLib.safeGetText("UI_POS_AgentDeploy_SelectPrompt"), C.dim)
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

screen.getContextData = function(_params)
    local data = {}

    if not _selectedArchetype then
        table.insert(data, { type = "header", text = "UI_POS_AgentDeploy_Title" })
        table.insert(data, { type = "kv",
            key = "", value = PhobosLib.safeGetText("UI_POS_AgentDeploy_SelectArchetype") })
        return data
    end

    local info = getArchetypeInfo(_selectedArchetype)
    table.insert(data, { type = "header", text = info.label })
    table.insert(data, { type = "separator" })

    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_AgentDeploy_Commission"),
        value = tostring(math.floor(info.commission * 100)) .. "%" })

    local riskLabel = getRiskLabel(info.risk)
    local riskColour = info.risk >= POS_Constants.RISK_THRESHOLD_HIGH and "error"
        or (info.risk >= POS_Constants.RISK_THRESHOLD_MODERATE and "warning" or nil)
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_AgentDeploy_Risk"),
        value = riskLabel, colour = riskColour })

    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_AgentDeploy_EstimatedTime"),
        value = "~" .. tostring(info.eta) .. "d" })

    -- Active agent count
    if POS_FreeAgentService and POS_FreeAgentService.getActive then
        local ok, agents = PhobosLib.safecall(POS_FreeAgentService.getActive)
        if ok and agents then
            table.insert(data, { type = "separator" })
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_BBSHub_ActiveAgents"),
                value = tostring(#agents) .. "/" .. tostring(POS_Constants.FREE_AGENT_MAX_ACTIVE) })
        end
    end

    return data
end

POS_API.registerScreen(screen)
