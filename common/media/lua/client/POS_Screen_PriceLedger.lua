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
-- POS_Screen_PriceLedger.lua
-- Category selector + daily price history from the market
-- database. Text-based trend display.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_MarketRegistry"
require "POS_MarketDatabase"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_LEDGER
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_Market_Ledger"
screen.sortOrder = 40

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Market_Ledger")

    local categoryId = params and params.categoryId

    -- Category selector buttons (if no category selected)
    if not categoryId then
        local categories = POS_MarketRegistry.getVisibleCategories({})
        if #categories == 0 then
            W.createLabel(ctx.panel, 8, ctx.y,
                W.safeGetText("UI_POS_Market_NoData"), C.dim)
            ctx.y = ctx.y + ctx.lineH
        else
            W.createLabel(ctx.panel, 0, ctx.y,
                W.safeGetText("UI_POS_Market_SelectCategory"), C.textBright)
            ctx.y = ctx.y + ctx.lineH + 4

            for i, cat in ipairs(categories) do
                local catId = cat.id
                W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
                    "[" .. i .. "] " .. W.safeGetText(cat.labelKey), nil,
                    function()
                        POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_LEDGER,
                            { categoryId = catId })
                    end)
                ctx.y = ctx.y + ctx.btnH + 4
            end
        end
    else
        -- Show price history for selected category
        local catDef = POS_MarketRegistry.getCategory(categoryId)
        local catLabel = catDef and W.safeGetText(catDef.labelKey) or categoryId

        W.createLabel(ctx.panel, 0, ctx.y,
            W.safeGetText("UI_POS_Market_PriceHistory") .. ": " .. catLabel, C.textBright)
        ctx.y = ctx.y + ctx.lineH

        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH

        local history = POS_MarketDatabase.getPriceHistory(categoryId, 14)

        if #history == 0 then
            W.createLabel(ctx.panel, 8, ctx.y,
                W.safeGetText("UI_POS_Market_InsufficientData"), C.dim)
            ctx.y = ctx.y + ctx.lineH
        else
            for i, entry in ipairs(history) do
                local trend = ""
                if i > 1 then
                    local prev = history[i - 1].avg
                    if entry.avg > prev * (1 + POS_Constants.TREND_RISING_PCT) then
                        trend = " ^"
                    elseif entry.avg < prev * (1 - POS_Constants.TREND_FALLING_PCT) then
                        trend = " v"
                    else
                        trend = " ="
                    end
                end

                local colour = C.text
                if trend == " ^" then colour = C.success
                elseif trend == " v" then colour = C.error
                end

                local line = "  Day " .. entry.day .. ": $"
                    .. string.format("%.2f", entry.avg)
                    .. " (" .. entry.count .. " records)" .. trend
                W.createLabel(ctx.panel, 0, ctx.y, line, colour)
                ctx.y = ctx.y + ctx.lineH
            end
        end

        -- Back to category selector
        ctx.y = ctx.y + 4
        W.createSeparator(ctx.panel, 0, ctx.y, 40, "-")
        ctx.y = ctx.y + ctx.lineH + 4

        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[1] " .. W.safeGetText("UI_POS_Market_SelectCategory"), nil,
            function()
                POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_LEDGER, {})
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
