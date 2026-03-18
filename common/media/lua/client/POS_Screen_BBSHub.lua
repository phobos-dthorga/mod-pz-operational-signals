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
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_OperationLog"
require "POS_InvestmentLog"

local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

---------------------------------------------------------------

local screen = {}
screen.id = "BBS_HUB"

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = POS_TerminalWidgets.COLOURS
    local pw = contentPanel:getWidth()
    local y = 0
    local lineH = 20
    local btnH = 28
    local btnW = pw - 10
    local btnX = 5

    -- Header
    W.createLabel(contentPanel, 0, y,
        safeGetText("UI_POS_BBSHub_Header"), C.textBright)
    y = y + lineH

    W.createSeparator(contentPanel, 0, y, 40)
    y = y + lineH + 4

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

    -- Sub-menu options
    local options = {
        {
            key = "UI_POS_BBSHub_Investments",
            screen = "BBS_LIST",
            count = investCount,
        },
        {
            key = "UI_POS_BBSHub_Operations",
            screen = "OPERATIONS",
            count = reconCount,
        },
        {
            key = "UI_POS_BBSHub_Courier",
            screen = "DELIVERIES",
            count = deliveryCount,
        },
    }

    for i, opt in ipairs(options) do
        local countStr = ""
        if opt.count > 0 then
            countStr = "  " .. safeGetText("UI_POS_BBSHub_ActiveCount", tostring(opt.count))
        end
        local label = "[" .. i .. "] " .. safeGetText(opt.key) .. countStr
        local targetScreen = opt.screen
        W.createButton(contentPanel, btnX, y, btnW, btnH, label, nil,
            function() POS_ScreenManager.navigateTo(targetScreen) end)
        y = y + btnH + 4
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
    if POS_TerminalUI and POS_TerminalUI.instance
       and POS_TerminalUI.instance.contentPanel then
        POS_TerminalWidgets.clearPanel(POS_TerminalUI.instance.contentPanel)
    end
end

function screen.refresh(_params)
    -- Static screen — no dynamic refresh needed
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
