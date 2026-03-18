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
-- BBS hub sub-menu — routes to Investments, Operations, and
-- Courier Service screens. Shows active-count summaries.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_OperationLog"
require "POS_InvestmentLog"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_BBS_HUB

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
    local allOps = POS_OperationLog.getByStatus("active")
    for i = 1, #allOps do
        if allOps[i].type == "delivery" then
            deliveryCount = deliveryCount + 1
        else
            reconCount = reconCount + 1
        end
    end

    -- Band-based content gating
    local terminal = POS_TerminalUI and POS_TerminalUI.instance
    local band = terminal and terminal.band or "operations"

    -- Sub-menu options (filtered by band)
    local options = {}

    if band == "operations" then
        -- Civilian band: investments, deliveries, Tier I-II operations
        table.insert(options, {
            key = "UI_POS_BBSHub_Investments",
            screen = POS_Constants.SCREEN_BBS_LIST,
            count = investCount,
        })
        table.insert(options, {
            key = "UI_POS_BBSHub_Operations",
            screen = POS_Constants.SCREEN_OPERATIONS,
            count = reconCount,
        })
        table.insert(options, {
            key = "UI_POS_BBSHub_Courier",
            screen = POS_Constants.SCREEN_DELIVERIES,
            count = deliveryCount,
        })
    elseif band == "tactical" then
        -- Military band: Tier III-IV operations + investments
        table.insert(options, {
            key = "UI_POS_BBSHub_Investments",
            screen = POS_Constants.SCREEN_BBS_LIST,
            count = investCount,
        })
        table.insert(options, {
            key = "UI_POS_BBSHub_Operations",
            screen = POS_Constants.SCREEN_OPERATIONS,
            count = reconCount,
        })
    end

    for i, opt in ipairs(options) do
        local countStr = ""
        if opt.count > 0 then
            countStr = "  " .. W.safeGetText("UI_POS_BBSHub_ActiveCount", tostring(opt.count))
        end
        local label = "[" .. i .. "] " .. W.safeGetText(opt.key) .. countStr
        local targetScreen = opt.screen
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH, label, nil,
            function() POS_ScreenManager.navigateTo(targetScreen) end)
        ctx.y = ctx.y + ctx.btnH + 4
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(_params)
    -- Static screen — no dynamic refresh needed
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
