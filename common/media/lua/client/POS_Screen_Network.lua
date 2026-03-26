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
-- POS_Screen_Network.lua
-- Network hub sub-menu — routes to Satellite Broadcast,
-- Signal Dashboard, and Strategic Relay screens.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_API"
require "POS_MenuBuilder"

---------------------------------------------------------------

local _TAG = "[POS:Network]"

local screen = {}
screen.id = POS_Constants.SCREEN_NETWORK
screen.menuPath = {"pos.main"}
screen.titleKey = "UI_POS_Network_Title"
screen.sortOrder = 45
screen.shouldShow = function(_player, _ctx)
    return true
end

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Network_Title")

    -- Sub-menu options (built dynamically from registry)
    local terminal = POS_TerminalUI and POS_TerminalUI.instance
    local band = terminal and terminal.band or "operations"
    local menuCtx = { connected = true, band = band, terminal = terminal }
    local player = getSpecificPlayer(0)
    local entries = POS_MenuBuilder.buildMenu({"pos.network"}, player, menuCtx)

    for i, entry in ipairs(entries) do
        local label = "[" .. i .. "] " .. W.safeGetText(entry.def.titleKey)

        if entry.enabled then
            local targetScreen = entry.def.id
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

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function(_params)
    local data = {}
    table.insert(data, { type = "header", text = "UI_POS_Network_Title" })
    table.insert(data, { type = "separator" })
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Network_SatelliteBroadcast"),
        value = PhobosLib.safeGetText("UI_POS_Satellite_Title") })
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
