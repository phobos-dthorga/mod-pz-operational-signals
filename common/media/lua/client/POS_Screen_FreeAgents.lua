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

local ARCHETYPE_FILTERS = { "all", "runner", "broker", "courier", "smuggler" }
local STATUS_FILTERS = { "active", "completed", "failed" }

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

    -- Tab Row 1: Archetype
    local archTabW = math.floor(ctx.panel:getWidth() / #ARCHETYPE_FILTERS) - 2
    local archTabX = 0
    for _, archId in ipairs(ARCHETYPE_FILTERS) do
        local label = archId == "all"
            and PhobosLib.safeGetText("UI_POS_Assignments_FilterAll")
            or PhobosLib.safeGetText("UI_POS_FreeAgent_Archetype_" .. archId)
        if _activeArchetype == archId then
            W.createLabel(ctx.panel, archTabX + 4, ctx.y + 2, "> " .. label, C.textBright)
        else
            local aId = archId
            W.createButton(ctx.panel, archTabX, ctx.y, archTabW, ctx.btnH,
                label, nil, function()
                    _activeArchetype = aId
                    _selectedAgentId = nil
                    POS_ScreenManager.replaceCurrent(screen.id,
                        { archetype = aId, status = _activeStatus })
                end)
        end
        archTabX = archTabX + archTabW + 2
    end
    ctx.y = ctx.y + ctx.btnH + 4

    -- Tab Row 2: Status
    local statusTabW = math.floor(ctx.panel:getWidth() / #STATUS_FILTERS) - 2
    local statusTabX = 0
    for _, statusId in ipairs(STATUS_FILTERS) do
        local label = PhobosLib.safeGetText("UI_POS_Assignments_Filter"
            .. statusId:sub(1,1):upper() .. statusId:sub(2))
        if _activeStatus == statusId then
            W.createLabel(ctx.panel, statusTabX + 4, ctx.y + 2, "> " .. label, C.textBright)
        else
            local sId = statusId
            W.createButton(ctx.panel, statusTabX, ctx.y, statusTabW, ctx.btnH,
                label, nil, function()
                    _activeStatus = sId
                    _selectedAgentId = nil
                    POS_ScreenManager.replaceCurrent(screen.id,
                        { archetype = _activeArchetype, status = sId })
                end)
        end
        statusTabX = statusTabX + statusTabW + 2
    end
    ctx.y = ctx.y + ctx.btnH + 4

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

                -- Recall button for active agents
                if agent.state ~= POS_Constants.AGENT_STATE_COMPLETED
                        and agent.state ~= POS_Constants.AGENT_STATE_FAILED then
                    local agentId = agent.id
                    W.createButton(parent, rx, ry, rw, ctx.btnH,
                        PhobosLib.safeGetText("UI_POS_FreeAgent_Recall"), nil,
                        function()
                            POS_FreeAgentService.recall(agentId)
                            POS_ScreenManager.refreshCurrentScreen()
                        end)
                    ry = ry + ctx.btnH + 4
                else
                    ry = ry + 4
                end

                local hasRecall = agent.state ~= POS_Constants.AGENT_STATE_COMPLETED
                    and agent.state ~= POS_Constants.AGENT_STATE_FAILED
                return ry - (ctx.lineH * 3 + (hasRecall and (ctx.btnH + 4) or 4))
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
    if #active > 0 then
        table.insert(data, { type = "header", text = "UI_POS_FreeAgent_Title" })
        table.insert(data, { type = "kv", key = "Active",
            value = tostring(#active) .. "/" .. tostring(POS_Constants.FREE_AGENT_MAX_ACTIVE) })
    end
    return data
end

POS_API.registerScreen(screen)
