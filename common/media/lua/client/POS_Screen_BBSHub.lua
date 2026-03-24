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
-- POS_Screen_BBSHub.lua
-- BBS hub sub-menu — routes to Investments, Operations,
-- Courier Service, and Assignments screens. Shows active-count summaries.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_OperationLog"
require "POS_InvestmentLog"
require "POS_API"
require "POS_MenuBuilder"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_BBS_HUB
screen.menuPath = {"pos.main"}
screen.titleKey = "UI_POS_BBSHub_Header"
screen.sortOrder = 10

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_BBSHub_Header")

    -- Active counts by type
    local investCount = 0
    if POS_InvestmentLog and POS_InvestmentLog.countActiveInvestments then
        investCount = POS_InvestmentLog.countActiveInvestments()
    end

    local reconCount = 0
    local deliveryCount = 0
    local allOps = POS_OperationLog.getByStatus(POS_Constants.STATUS_ACTIVE)
    for i = 1, #allOps do
        if allOps[i].type == POS_Constants.OBJECTIVE_TYPE_DELIVERY then
            deliveryCount = deliveryCount + 1
        else
            reconCount = reconCount + 1
        end
    end

    -- Band-based content gating
    local terminal = POS_TerminalUI and POS_TerminalUI.instance
    local band = terminal and terminal.band or "operations"

    -- Active count lookup for sub-screen badges
    local countByScreen = {
        [POS_Constants.SCREEN_BBS_LIST] = investCount,
        [POS_Constants.SCREEN_OPERATIONS] = reconCount,
        [POS_Constants.SCREEN_DELIVERIES] = deliveryCount,
    }

    -- Sub-menu options (built dynamically from registry)
    local menuCtx = { connected = true, band = band, terminal = terminal }
    local player = getSpecificPlayer(0)
    local entries = POS_MenuBuilder.buildMenu({"pos.bbs"}, player, menuCtx)

    for i, entry in ipairs(entries) do
        local screenId = entry.def.id
        local count = countByScreen[screenId] or 0
        local countStr = ""
        if count > 0 then
            countStr = "  " .. W.safeGetText("UI_POS_BBSHub_ActiveCount", tostring(count))
        end
        local label = "[" .. i .. "] " .. W.safeGetText(entry.def.titleKey) .. countStr

        if entry.enabled then
            local targetScreen = screenId
            W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH, label, nil,
                function() POS_ScreenManager.navigateTo(targetScreen) end)
        else
            local disabledLabel = "    " .. W.safeGetText(entry.def.titleKey)
            if entry.reason then
                disabledLabel = disabledLabel .. "  (" .. W.safeGetText(entry.reason) .. ")"
            end
            W.createDisabledButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH, disabledLabel)
        end

        ctx.y = ctx.y + ctx.btnH + 4
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(_params)
    -- Static screen — no dynamic refresh needed
end

screen.getContextData = function(_params)
    local data = {}
    table.insert(data, { type = "header", text = "UI_POS_BBSHub_Header" })
    table.insert(data, { type = "separator" })

    -- Active operations
    if POS_OperationLog and POS_OperationLog.getByStatus then
        local ok, active = PhobosLib.safecall(POS_OperationLog.getByStatus, POS_Constants.STATUS_ACTIVE)
        if ok and active then
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_MainMenu_ActiveOps"),
                value = tostring(#active) })
        end
    end

    -- Open contracts
    if POS_ContractService and POS_ContractService.getAvailable then
        local ok, avail = PhobosLib.safecall(POS_ContractService.getAvailable)
        if ok and avail then
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_BBSHub_OpenContracts"),
                value = tostring(#avail) })
        end
    end

    -- Active free agents
    if POS_FreeAgentService and POS_FreeAgentService.getActive then
        local ok, agents = PhobosLib.safecall(POS_FreeAgentService.getActive)
        if ok and agents then
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_BBSHub_ActiveAgents"),
                value = tostring(#agents) })
        end
    end

    return data
end

---------------------------------------------------------------

POS_API.registerCategory({
    id = "pos.bbs",
    parent = "pos.main",
    titleKey = "UI_POS_BBSHub_Header",
    sortOrder = 10,
})

POS_API.registerScreen(screen)
