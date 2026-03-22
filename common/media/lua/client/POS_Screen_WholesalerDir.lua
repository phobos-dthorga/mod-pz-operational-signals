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
-- POS_Screen_WholesalerDir.lua
-- Wholesaler Directory screen. Paginated list of known
-- wholesaler contacts, gated behind SIGINT level 3.
-- High-secrecy wholesalers appear as "Unknown Contact"
-- unless the player has SIGINT >= 7.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_WorldState"
require "POS_WholesalerService"
require "POS_SIGINTSkill"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_WHOLESALER_DIR
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_WholesalerDir_Title"
screen.sortOrder = 35

screen.canOpen = function()
    local player = getSpecificPlayer(0)
    if not player then return false, "UI_POS_WholesalerDir_RequiresSIGINT" end
    local sigintLevel = POS_SIGINTSkill.getLevel(player)
    if sigintLevel < POS_Constants.WHOLESALER_DIR_SIGINT_REQ then
        return false, PhobosLib.safeGetText("UI_POS_WholesalerDir_RequiresSIGINT")
    end
    return true
end

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_WholesalerDir_Title")

    -- Current player SIGINT level
    local player = getSpecificPlayer(0)
    local sigintLevel = 0
    if player then
        sigintLevel = POS_SIGINTSkill.getLevel(player)
    end

    -- Fetch wholesalers (nil-safe)
    local wholesalers = POS_WorldState.getWholesalers()
    local visThreshold = POS_Constants.WHOLESALER_VISIBLE_THRESHOLD

    -- Build list of wholesalers to display
    local entries = {}
    if wholesalers then
        for wId, w in pairs(wholesalers) do
            if type(w) == "table" then
                local visible = (w.visibility or 0) > visThreshold
                local highSigint = sigintLevel >= 7
                -- Show if visible OR high SIGINT (show as unknown if neither)
                local entry = {
                    id = wId,
                    wholesaler = w,
                    isRevealed = visible or highSigint,
                }
                table.insert(entries, entry)
            end
        end
    end

    -- Sort by revealed first, then by ID for stable ordering
    table.sort(entries, function(a, b)
        if a.isRevealed ~= b.isRevealed then
            return a.isRevealed
        end
        return (a.id or "") < (b.id or "")
    end)

    if #entries == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_WholesalerDir_NoAccess"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (_params and _params.dirPage) or 1
        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = entries,
            pageSize = POS_Constants.PAGE_SIZE_WHOLESALER_DIR,
            currentPage = currentPage,
            x = ctx.btnX,
            y = ctx.y,
            width = ctx.btnW,
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, rw, entry, _idx)
                local itemY = 0
                local w = entry.wholesaler

                -- Line 1: name (or "Unknown Contact") + operational state badge
                local name
                if entry.isRevealed then
                    local nameKey = w.nameKey or w.displayNameKey
                    name = nameKey and W.safeGetText(nameKey) or (w.name or entry.id)
                else
                    name = W.safeGetText("UI_POS_WholesalerDir_UnknownContact")
                end

                local stateBadge = "Unknown"
                if POS_WholesalerService and POS_WholesalerService.getStateDisplayName
                    and w.state then
                    stateBadge = POS_WholesalerService.getStateDisplayName(w.state)
                end

                W.createLabel(parent, rx, ry + itemY,
                    name .. "  [" .. stateBadge .. "]", C.text)
                itemY = itemY + ctx.lineH

                -- Line 2: "  Zone: <zone> | <top categories>"
                local zone = w.regionId or w.zone or "???"
                local cats = w.categories
                if type(cats) == "table" then
                    cats = table.concat(cats, ", ")
                end
                local detailLine = "  Zone: " .. zone
                if entry.isRevealed and cats then
                    detailLine = detailLine .. " | "
                        .. W.safeGetText("UI_POS_WholesalerDir_Categories", cats)
                end
                W.createLabel(parent, rx, ry + itemY, detailLine, C.dim)
                itemY = itemY + ctx.lineH

                return itemY + 4
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_WHOLESALER_DIR,
                    { dirPage = newPage })
            end,
        })
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.getContextData = function(_params)
    local data = {}
    local wholesalers = POS_WorldState.getWholesalers()
    local player = getSpecificPlayer(0)
    local sigintLevel = player and POS_SIGINTSkill.getLevel(player) or 0
    local visThreshold = POS_Constants.WHOLESALER_VISIBLE_THRESHOLD
    local count = 0
    if wholesalers then
        for _, w in pairs(wholesalers) do
            if type(w) == "table" then
                if (w.visibility or 0) > visThreshold or sigintLevel >= 7 then
                    count = count + 1
                end
            end
        end
    end
    if count > 0 then
        table.insert(data, { type = "kv", key = "UI_POS_WholesalerDir_Title",
            value = tostring(count) })
    end
    return data
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
