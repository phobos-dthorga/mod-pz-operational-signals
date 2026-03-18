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
-- POS_Screen_Stockmarket.lua
-- Placeholder "COMING SOON" screen for the Stockmarket feature.
-- Widget-based: uses ISButton/ISLabel children in contentPanel.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_STOCKMARKET
screen.menuPath = {"pos.main"}
screen.titleKey = "UI_POS_Stock_Header"
screen.sortOrder = 90
screen.canOpen = function(_player, _ctx)
    return false, "UI_POS_Stockmarket_Placeholder"
end

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Stock_Header")

    ctx.y = ctx.y + ctx.lineH

    -- Coming soon message
    W.createLabel(ctx.panel, 20, ctx.y,
        W.safeGetText("UI_POS_Stock_ComingSoon"), C.warn)
    ctx.y = ctx.y + ctx.lineH * 2

    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Stock_Message"), C.dim)
    ctx.y = ctx.y + ctx.lineH * 3

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(_params)
    -- Static screen — no dynamic data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
