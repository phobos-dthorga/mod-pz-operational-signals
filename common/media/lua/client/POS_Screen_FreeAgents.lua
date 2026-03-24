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
-- POS_Screen_FreeAgents.lua
-- "Field Agents" — monitor runners, brokers, and couriers
-- sent into the wasteland. Dual tab bars: archetype × status.
-- The player watches named contacts progress through states
-- on a flickering terminal, waiting for radio confirmation
-- that the cargo arrived — or that the agent is lost.
--
-- See design-guidelines.md §46.
---------------------------------------------------------------

require "PhobosLib"
require "PhobosLib_DualTab"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_FreeAgentService"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local _activeArchetype = "all"
local _activeStatus = "active"
local _selectedAgentId = nil

local ARCHETYPE_TABS = {
    { id = "all",      labelKey = "UI_POS_Assignments_FilterAll" },
    { id = "runner",   labelKey = "UI_POS_FreeAgent_Archetype_runner" },
    { id = "broker",   labelKey = "UI_POS_FreeAgent_Archetype_broker" },
    { id = "courier",  labelKey = "UI_POS_FreeAgent_Archetype_courier" },
    { id = "smuggler", labelKey = "UI_POS_FreeAgent_Archetype_smuggler" },
}

local STATUS_TABS = {
    { id = "active",    labelKey = "UI_POS_Assignments_FilterActive" },
    { id = "completed", labelKey = "UI_POS_Assignments_FilterCompleted" },
    { id = "failed",    labelKey = "UI_POS_Assignments_FilterFailed" },
}

local STATE_COLOURS = {
    drafted      = "textBright",
    assembling   = "text",
    transit      = "warning",
    negotiation  = "textBright",
    settlement   = "success",
    completed    = "success",
    failed       = "error",
    delayed      = "warning",
    compromised  = "error",
}

---------------------------------------------------------------

local screen = {}
screen.id = "pos.bbs.agents"
screen.menuPath = {"pos.bbs"}
screen.titleKey = "UI_POS_FreeAgent_Title"
screen.sortOrder = 25
screen.requires = { connected = true }

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    _activeArchetype = (params and params.archetype) or _activeArchetype or "all"
    _activeStatus = (params and params.status) or _activeStatus or "active"

    W.drawHeader(ctx, "UI_POS_FreeAgent_Title")

    -- Dual tab bar: archetype × status (via PhobosLib_DualTab)
    ctx.y = PhobosLib_DualTab.create({
        panel   = ctx.panel,
        y       = ctx.y,
        tabs1   = ARCHETYPE_TABS,
        tabs2   = STATUS_TABS,
        active1 = _activeArchetype,
        active2 = _activeStatus,
        colours = C,
        btnH    = ctx.btnH,
        _W      = W,
        onTabChange = function(tab1, tab2)
            _activeArchetype = tab1
            _activeStatus = tab2
            _selectedAgentId = nil
            POS_ScreenManager.replaceCurrent(screen.id,
                { archetype = tab1, status = tab2 })
        end,
    })

    W.createSeparator(ctx.panel, 0, ctx.y, 50, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Get filtered agents
    local agents = {}
    local allAgents = (_activeStatus == "active")
        and POS_FreeAgentService.getActive()
        or ((_activeStatus == "completed")
            and POS_FreeAgentService.getHistory()
            or POS_FreeAgentService.getAll())

    for _, a in ipairs(allAgents) do
        local archMatch = _activeArchetype == "all" or a.agentArchetype == _activeArchetype
        local statusMatch = true
        if _activeStatus == POS_Constants.AGENT_STATE_FAILED then
            statusMatch = (a.state == POS_Constants.AGENT_STATE_FAILED)
        elseif _activeStatus == POS_Constants.AGENT_STATE_COMPLETED then
            statusMatch = (a.state == POS_Constants.AGENT_STATE_COMPLETED)
        end
        if archMatch and statusMatch then
            agents[#agents + 1] = a
        end
    end

    -- Deploy New Agent button (always visible, breaks chicken-and-egg)
    W.createButton(ctx.panel, 4, ctx.y,
        ctx.panel:getWidth() - 8, ctx.btnH,
        PhobosLib.safeGetText("UI_POS_FreeAgent_Deploy"), nil,
        function()
            POS_ScreenManager.navigateTo(POS_Constants.SCREEN_AGENT_DEPLOY, {})
        end)
    ctx.y = ctx.y + ctx.btnH + 6

    if #agents == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_FreeAgent_None"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (params and params.page) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = agents,
            pageSize = POS_Constants.FREE_AGENT_PAGE_SIZE,
            currentPage = currentPage,
            x = 0, y = ctx.y,
            width = ctx.panel:getWidth(),
            colours = { text = C.text, dim = C.dim, bgDark = C.bgDark,
                        bgHover = C.bgHover, border = C.border },
            renderItem = function(parent, rx, ry, rw, agent, _idx)
                local stateLabel = PhobosLib.safeGetText("UI_POS_FreeAgent_State_" .. agent.state)
                local stateColour = C[STATE_COLOURS[agent.state] or "text"]
                local archLabel = PhobosLib.safeGetText("UI_POS_FreeAgent_Archetype_" .. agent.agentArchetype)

                -- Row 1: [STATE] Agent Name (Archetype)
                W.createLabel(parent, rx, ry,
                    "[" .. stateLabel .. "] " .. agent.agentName .. " (" .. archLabel .. ")",
                    stateColour)
                ry = ry + ctx.lineH

                -- Row 2: Zone + cargo + payout
                local cargoName = agent.cargoFullType ~= ""
                    and (PhobosLib.getItemDisplayName and PhobosLib.getItemDisplayName(agent.cargoFullType) or agent.cargoFullType)
                    or "General cargo"
                W.createLabel(parent, rx + 8, ry,
                    agent.zoneId .. " | " .. tostring(agent.cargoQuantity) .. "x " .. cargoName
                    .. " | $" .. string.format("%.0f", agent.settlementPayout or 0),
                    C.dim)
                ry = ry + ctx.lineH

                -- Row 3: ETA + risk
                local day = getGameTime() and getGameTime():getNightsSurvived() or 0
                local elapsed = day - agent.startDay
                local eta = math.max(0, agent.estimatedDays - elapsed)
                local riskLabel = agent.riskLevel >= POS_Constants.RISK_THRESHOLD_HIGH and "HIGH"
                    or (agent.riskLevel >= POS_Constants.RISK_THRESHOLD_MODERATE and "MODERATE" or "LOW")
                W.createLabel(parent, rx + 8, ry,
                    "ETA: ~" .. tostring(eta) .. "d | Risk: " .. riskLabel
                    .. " | Commission: " .. tostring(math.floor(agent.commissionRate * 100)) .. "%",
                    C.dim)
                ry = ry + ctx.lineH

                -- Select button (populates ContextPanel detail)
                local agentId = agent.id
                local isSelected = (_selectedAgentId == agentId)
                local selectLabel = isSelected
                    and "> " .. PhobosLib.safeGetText("UI_POS_Screen_ViewDetails")
                    or PhobosLib.safeGetText("UI_POS_Screen_ViewDetails")
                W.createButton(parent, rx, ry, rw, ctx.btnH,
                    selectLabel, nil,
                    function()
                        _selectedAgentId = agentId
                        POS_ScreenManager.refreshCurrentScreen()
                    end)
                ry = ry + ctx.btnH + 4

                return ry - (ctx.lineH * 3 + ctx.btnH + 4)
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(screen.id, {
                    archetype = _activeArchetype, status = _activeStatus, page = newPage,
                })
            end,
        })
    end

    W.drawFooter(ctx)
end

function screen.destroy()
    _selectedAgentId = nil
    POS_TerminalWidgets.defaultDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function()
    local data = {}
    local active = POS_FreeAgentService.getActive()

    -- Summary header
    table.insert(data, { type = "header", text = "UI_POS_FreeAgent_Title" })
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_FreeAgent_Active"),
        value = tostring(#active) .. "/" .. tostring(POS_Constants.FREE_AGENT_MAX_ACTIVE) })
    table.insert(data, { type = "separator" })

    -- Selected agent detail
    local agent = _selectedAgentId
        and POS_FreeAgentService.get(_selectedAgentId)

    if not agent then
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Screen_Hint"),
            value = PhobosLib.safeGetText("UI_POS_FreeAgent_SelectHint") })
        return data
    end

    -- Archetype + state badge
    local archLabel = PhobosLib.safeGetText(
        "UI_POS_FreeAgent_Archetype_" .. agent.agentArchetype)
    local stateLabel = PhobosLib.safeGetText(
        "UI_POS_FreeAgent_State_" .. agent.state)
    local stateColour = STATE_COLOURS[agent.state]
    table.insert(data, { type = "header",
        text = "[" .. stateLabel .. "] " .. agent.agentName })
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_FreeAgent_ArchetypeLabel"),
        value = archLabel })

    -- Zone
    local zoneName = agent.zoneId or "?"
    if POS_MarketSimulation and POS_MarketSimulation.getZoneLuxuryDemand then
        -- Zone is accessible — try display name
        zoneName = agent.zoneId
    end
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_FreeAgent_Zone"),
        value = zoneName })

    -- ETA countdown
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    local elapsed = day - (agent.startDay or 0)
    local eta = math.max(0, (agent.estimatedDays or 0) - elapsed)
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_AgentDeploy_EstimatedTime"),
        value = "~" .. tostring(eta) .. "d",
        colour = eta <= 1 and "warning" or nil })

    -- Risk (zone-adjusted display)
    local riskLevel = agent.riskLevel or 0
    local riskLabel = riskLevel >= POS_Constants.RISK_THRESHOLD_HIGH and "HIGH"
        or (riskLevel >= POS_Constants.RISK_THRESHOLD_MODERATE and "MODERATE" or "LOW")
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_AgentDeploy_Risk"),
        value = riskLabel,
        colour = riskLevel >= POS_Constants.RISK_THRESHOLD_HIGH and "error"
            or (riskLevel >= POS_Constants.RISK_THRESHOLD_MODERATE and "warning" or nil) })

    -- Cargo
    local cargoName = agent.cargoFullType and agent.cargoFullType ~= ""
        and (PhobosLib.getItemDisplayName
            and PhobosLib.getItemDisplayName(agent.cargoFullType)
            or agent.cargoFullType)
        or PhobosLib.safeGetText("UI_POS_FreeAgent_GeneralCargo")
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_AgentDeploy_CargoCost"),
        value = tostring(agent.cargoQuantity or 0) .. "x " .. cargoName })

    table.insert(data, { type = "separator" })

    -- Commission breakdown
    local payout = agent.settlementPayout or 0
    local commission = payout * (agent.commissionRate or 0)
    local netPayout = payout - commission
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_AgentDeploy_Commission"),
        value = tostring(math.floor((agent.commissionRate or 0) * 100))
            .. "% ($" .. string.format("%.2f", commission) .. ")" })
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_FreeAgent_NetPayout"),
        value = "$" .. string.format("%.2f", netPayout), colour = "success" })

    -- SIGINT bonus (if captured)
    if agent.sigintLevel and agent.sigintLevel > 0 then
        local sigintBonus = agent.sigintLevel
            * POS_Constants.FREE_AGENT_SIGINT_RISK_REDUCTION_PER_LEVEL
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_FreeAgent_SigintBonus"),
            value = "-" .. tostring(math.floor(sigintBonus * 100)) .. "% risk" })
    end

    -- Recall button (if active)
    if agent.state ~= POS_Constants.AGENT_STATE_COMPLETED
            and agent.state ~= POS_Constants.AGENT_STATE_FAILED then
        table.insert(data, { type = "separator" })
        local agentId = agent.id
        table.insert(data, {
            type = "action",
            text = "UI_POS_FreeAgent_Recall",
            callback = function()
                POS_FreeAgentService.recall(agentId)
                _selectedAgentId = nil
                POS_ScreenManager.refreshCurrentScreen()
            end,
        })
    end

    return data
end

POS_API.registerScreen(screen)
