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
-- POS_Screen_Markets.lua
-- Markets hub sub-menu — routes to Commodities, Traders,
-- Reports, and Ledger screens. Upload Field Notes action.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketIngestion"
require "POS_WatchlistService"
require "POS_PlayerState"
require "POS_API"
require "POS_MenuBuilder"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_MARKETS
screen.menuPath = {"pos.main"}
screen.titleKey = "UI_POS_Markets_Title"
screen.sortOrder = 40
screen.shouldShow = function(_player, _ctx)
    return POS_Sandbox and POS_Sandbox.getEnableMarkets and POS_Sandbox.getEnableMarkets()
end

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Markets_Title")

    -- Sub-menu options (built dynamically from registry)
    local terminal = POS_TerminalUI and POS_TerminalUI.instance
    local band = terminal and terminal.band or "operations"
    local menuCtx = { band = band, terminal = terminal }
    local player = getSpecificPlayer(0)
    local entries = POS_MenuBuilder.buildMenu({"pos.markets"}, player, menuCtx)

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

    -- Upload Field Notes action button
    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
    ctx.y = ctx.y + ctx.lineH + 4

    local noteCount = POS_MarketIngestion.countNotes(player)
    if noteCount > 0 then
        local uploadLabel = W.safeGetText("UI_POS_Market_UploadNotes")
            .. " (" .. noteCount .. ")"
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH, uploadLabel, nil,
            function()
                local p = getSpecificPlayer(0)
                if not p then return end
                local notes = POS_MarketIngestion.getNotes(p)
                local ingested = 0
                local inv = p:getInventory()
                for _, noteItem in ipairs(notes) do
                    if POS_MarketIngestion.ingestNote(noteItem) then
                        ingested = ingested + 1
                        if inv then inv:Remove(noteItem) end
                    end
                end
                PhobosLib.debug("POS", "[POS:Markets]",
                    "Uploaded " .. ingested .. " field notes")
                POS_ScreenManager.markDirty()
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    else
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Market_NoNotes"), C.dim)
        ctx.y = ctx.y + ctx.lineH
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
    local player = getSpecificPlayer(0)
    local noteCount = POS_MarketIngestion.countNotes(player)
    if noteCount > 0 then
        table.insert(data, { type = "header", text = "UI_POS_Market_FieldNotes" })
        table.insert(data, { type = "kv", key = "UI_POS_Market_NotesCount",
            value = tostring(noteCount) })
    end
    if player and POS_Sandbox and POS_Sandbox.getEnableWatchlist
        and POS_Sandbox.getEnableWatchlist() then
        local alertCount = POS_WatchlistService.countPendingAlerts(player)
        if alertCount > 0 then
            table.insert(data, { type = "kv", key = "UI_POS_Market_AlertCount",
                value = tostring(alertCount) })
        end
    end
    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
