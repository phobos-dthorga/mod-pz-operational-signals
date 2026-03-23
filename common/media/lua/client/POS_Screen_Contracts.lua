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
-- POS_Screen_Contracts.lua
-- "Incoming Requests" — sell-side contract browser.
--
-- Three tabs: Available (posted contracts from the world),
-- Active (accepted, in-progress), History (settled/failed).
--
-- The ContextPanel shows full contract detail when a contract
-- is selected: buyer info, briefing text, risk, deadline,
-- payout, and action buttons (Accept/Fulfil/Abandon).
--
-- See design-guidelines.md §43.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_ContractService"
require "POS_MarketRegistry"
require "POS_ItemPool"
require "PhobosLib_Pagination"
require "POS_API"

---------------------------------------------------------------

local _TAG = "[POS:ContractsScreen]"

-- Currently selected contract ID (for ContextPanel detail)
local _selectedContractId = nil
local _activeTab = "available"  -- "available" | "active" | "history"

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

local function getKindLabel(kind)
    return PhobosLib.safeGetText("UI_POS_Contract_Kind_" .. (kind or "procurement"))
end

local function getUrgencyLabel(urgency)
    return PhobosLib.safeGetText("UI_POS_Contract_Urgency_" .. tostring(urgency or 2))
end

local function getStatusLabel(status)
    local key = "UI_POS_Contract_Status_"
        .. string.sub(status or "posted", 1, 1):upper()
        .. string.sub(status or "posted", 2)
    return PhobosLib.safeGetText(key)
end

local function getUrgencyColour(urgency, C)
    if urgency >= 4 then return C.error end
    if urgency >= 3 then return C.warning end
    return C.text
end

local function getDaysLeft(contract)
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    return (contract.deadlineDay or 0) - day
end

local function getItemDisplayName(fullType)
    if PhobosLib.getItemDisplayName then
        return PhobosLib.getItemDisplayName(fullType)
    end
    return fullType
end

---------------------------------------------------------------
-- Screen definition
---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_CONTRACTS
screen.menuPath = {"pos.markets"}
screen.titleKey = "UI_POS_Contract_Title"
screen.sortOrder = 15

---------------------------------------------------------------
-- Tab rendering
---------------------------------------------------------------

local function renderContractRow(ctx, contract, parent, rx, ry, rw, isSelectable)
    local W = POS_TerminalWidgets
    local C = W.COLOURS

    local kind = getKindLabel(contract.kind)
    local urgColour = getUrgencyColour(contract.urgency, C)

    -- Row 1: Kind badge + briefing title
    local title = contract.briefing and contract.briefing.title or kind
    W.createLabel(parent, rx, ry,
        "[" .. kind .. "] " .. title, urgColour)
    ry = ry + ctx.lineH

    -- Row 2: Item + quantity + payout
    local itemName = contract.resolvedItemType
        and getItemDisplayName(contract.resolvedItemType)
        or (contract.categoryId or "?")
    local qty = contract.resolvedQuantity or 0
    local payout = contract.resolvedPayout or 0
    W.createLabel(parent, rx + 8, ry,
        tostring(qty) .. "x " .. itemName
        .. "  —  $" .. string.format("%.2f", payout),
        C.textBright)
    ry = ry + ctx.lineH

    -- Row 3: Deadline + urgency
    local daysLeft = getDaysLeft(contract)
    local deadlineStr
    if daysLeft > 0 then
        deadlineStr = tostring(daysLeft) .. " days remaining"
    elseif daysLeft == 0 then
        deadlineStr = "DUE TODAY"
    else
        deadlineStr = "OVERDUE"
    end
    local urgStr = getUrgencyLabel(contract.urgency)
    W.createLabel(parent, rx + 8, ry,
        "Urgency: " .. urgStr .. "  |  " .. deadlineStr, C.dim)
    ry = ry + ctx.lineH

    -- Select button (highlights in ContextPanel)
    if isSelectable then
        local contractId = contract.id
        W.createButton(parent, rx, ry, rw, ctx.btnH,
            PhobosLib.safeGetText("UI_POS_Screen_ViewDetails") or "View Details", nil,
            function()
                _selectedContractId = contractId
                POS_ScreenManager.refreshCurrentScreen()
            end)
        ry = ry + ctx.btnH + 4
    else
        ry = ry + 4
    end

    return ry
end

---------------------------------------------------------------
-- Main create
---------------------------------------------------------------

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Resolve tab from params
    _activeTab = (params and params.tab) or _activeTab or "available"

    W.drawHeader(ctx, "UI_POS_Contract_Title")

    -- Tab bar
    local tabs = {
        { id = "available", key = "UI_POS_Contract_Available" },
        { id = "active",    key = "UI_POS_Contract_Active" },
        { id = "history",   key = "UI_POS_Contract_History" },
    }

    local tabX = ctx.btnX
    local tabW = math.floor(ctx.btnW / #tabs)
    for _, tab in ipairs(tabs) do
        if _activeTab == tab.id then
            W.createLabel(contentPanel, tabX + 4, ctx.y + 2,
                "> " .. W.safeGetText(tab.key), C.textBright)
        else
            local tabId = tab.id
            W.createButton(contentPanel, tabX, ctx.y, tabW, ctx.btnH,
                W.safeGetText(tab.key), nil,
                function()
                    _activeTab = tabId
                    _selectedContractId = nil
                    POS_ScreenManager.replaceCurrent(
                        POS_Constants.SCREEN_CONTRACTS, { tab = tabId })
                end)
        end
        tabX = tabX + tabW + 2
    end
    ctx.y = ctx.y + ctx.btnH + 6

    W.createSeparator(contentPanel, 0, ctx.y, 50, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Tab content
    local contracts = {}
    if _activeTab == "available" then
        contracts = POS_ContractService.getAvailable()
    elseif _activeTab == "active" then
        contracts = POS_ContractService.getActive()
    elseif _activeTab == "history" then
        contracts = POS_ContractService.getHistory()
    end

    if #contracts == 0 then
        local emptyKey = _activeTab == "available"
            and "UI_POS_Contract_None"
            or "UI_POS_Contract_NoneActive"
        W.createLabel(contentPanel, 8, ctx.y,
            W.safeGetText(emptyKey), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (params and params.contractPage) or 1
        local tabCopy = _activeTab
        local isSelectable = (_activeTab ~= "history")

        ctx.y = PhobosLib_Pagination.create(contentPanel, {
            items = contracts,
            pageSize = 4,
            currentPage = currentPage,
            x = ctx.btnX,
            y = ctx.y,
            width = ctx.btnW,
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, rw, item, _idx)
                local startY = ry
                ry = renderContractRow(ctx, item, parent, rx, ry, rw, isSelectable)
                return ry - startY
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(
                    POS_Constants.SCREEN_CONTRACTS,
                    { tab = tabCopy, contractPage = newPage })
            end,
        })
    end

    -- Player balance
    local balance = POS_TradeService and POS_TradeService.getPlayerBalance
        and POS_TradeService.getPlayerBalance(getPlayer()) or 0
    ctx.y = ctx.y + 4
    W.createLabel(contentPanel, 8, ctx.y,
        W.safeGetText("UI_POS_Trade_Balance") .. ": $"
        .. string.format("%.2f", balance), C.dim)
    ctx.y = ctx.y + ctx.lineH

    W.drawFooter(ctx)
end

---------------------------------------------------------------
-- ContextPanel: contract detail view
---------------------------------------------------------------

screen.getContextData = function(_params)
    local data = {}
    local contract = _selectedContractId
        and POS_ContractService.get(_selectedContractId)

    if not contract then
        table.insert(data, { type = "header", text = "UI_POS_Contract_Title" })
        table.insert(data, { type = "kv", key = "UI_POS_Screen_Hint",
            value = "Select a contract for details" })
        return data
    end

    -- Header: kind badge
    table.insert(data, { type = "header",
        text = getKindLabel(contract.kind) })
    table.insert(data, { type = "separator" })

    -- Buyer archetype
    if contract.archetypeId and contract.archetypeId ~= "" then
        local archName = contract.archetypeId
        if POS_MarketAgent and POS_MarketAgent.getDisplayName then
            archName = POS_MarketAgent.getDisplayName(contract.archetypeId) or archName
        end
        table.insert(data, { type = "kv", key = "UI_POS_Contract_Buyer",
            value = archName })
    end

    -- Item + quantity
    local itemName = contract.resolvedItemType
        and getItemDisplayName(contract.resolvedItemType)
        or (contract.categoryId or "?")
    table.insert(data, { type = "kv", key = "UI_POS_Contract_Needs",
        value = tostring(contract.resolvedQuantity or 0) .. "x " .. itemName })

    -- Payout
    table.insert(data, { type = "kv", key = "UI_POS_Contract_Pays",
        value = "$" .. string.format("%.2f", contract.resolvedPayout or 0) })

    -- Deadline
    local daysLeft = getDaysLeft(contract)
    local deadlineColour = daysLeft <= 1 and "error" or (daysLeft <= 3 and "warning" or nil)
    table.insert(data, { type = "kv", key = "UI_POS_Contract_Deadline",
        value = tostring(daysLeft) .. " days", colour = deadlineColour })

    -- Urgency
    table.insert(data, { type = "kv", key = "UI_POS_Contract_Urgency",
        value = getUrgencyLabel(contract.urgency) })

    -- Risk indicator (betrayal chance)
    if contract.betrayalChance and contract.betrayalChance > 0 then
        local riskLabel = contract.betrayalChance >= 0.15 and "HIGH"
            or (contract.betrayalChance >= 0.05 and "MODERATE" or "LOW")
        table.insert(data, { type = "kv", key = "UI_POS_Contract_Risk",
            value = riskLabel, colour = contract.betrayalChance >= 0.10 and "error" or "warning" })
    end

    -- SIGINT requirement
    if contract.sigintRequired and contract.sigintRequired > 0 then
        table.insert(data, { type = "kv",
            key = "SIGINT Required",
            value = "Level " .. tostring(contract.sigintRequired) })
    end

    -- Briefing situation text (if available)
    if contract.briefing and contract.briefing.situation
            and contract.briefing.situation ~= "" then
        table.insert(data, { type = "separator" })
        table.insert(data, { type = "header", text = "BRIEFING" })
        -- Show first 80 chars of situation as preview
        local sit = contract.briefing.situation
        if #sit > 80 then sit = string.sub(sit, 1, 77) .. "..." end
        table.insert(data, { type = "kv", key = "", value = sit })
    end

    -- Inventory check for active contracts
    if contract.status == POS_Constants.CONTRACT_STATUS_ACCEPTED
            and contract.resolvedItemType then
        table.insert(data, { type = "separator" })
        local player = getPlayer()
        local owned = 0
        if player and PhobosLib.findAllItemsByFullType then
            local found = PhobosLib.findAllItemsByFullType(player, contract.resolvedItemType)
            owned = type(found) == "table" and #found or (type(found) == "number" and found or 0)
        end
        local needed = contract.resolvedQuantity or 0
        local readyColour = owned >= needed and "success" or "warning"
        table.insert(data, { type = "kv", key = "In Inventory",
            value = tostring(owned) .. "/" .. tostring(needed), colour = readyColour })
    end

    table.insert(data, { type = "separator" })

    -- Action buttons based on status
    if contract.status == POS_Constants.CONTRACT_STATUS_POSTED then
        local cId = contract.id
        table.insert(data, {
            type = "action",
            text = "UI_POS_Contract_Accept",
            callback = function()
                local ok, err = POS_ContractService.accept(cId)
                if ok then
                    _activeTab = "active"
                    POS_ScreenManager.replaceCurrent(
                        POS_Constants.SCREEN_CONTRACTS, { tab = "active" })
                else
                    if PhobosLib.notifyOrSay then
                        PhobosLib.notifyOrSay("POSnet", err or "Cannot accept", "error")
                    end
                end
            end,
        })
    elseif contract.status == POS_Constants.CONTRACT_STATUS_ACCEPTED then
        local cId = contract.id
        -- Fulfil button
        table.insert(data, {
            type = "action",
            text = "UI_POS_Contract_Fulfil",
            callback = function()
                local ok, err = POS_ContractService.fulfil(cId)
                if ok then
                    _selectedContractId = nil
                    POS_ScreenManager.refreshCurrentScreen()
                else
                    if PhobosLib.notifyOrSay then
                        PhobosLib.notifyOrSay("POSnet", err or "Cannot fulfil", "error")
                    end
                end
            end,
        })
        -- Abandon button
        table.insert(data, {
            type = "action",
            text = "UI_POS_Contract_Abandon",
            callback = function()
                POS_ContractService.abandon(cId)
                _selectedContractId = nil
                POS_ScreenManager.refreshCurrentScreen()
            end,
        })
    end

    return data
end

---------------------------------------------------------------

screen.destroy = function()
    _selectedContractId = nil
    _activeTab = "available"
    POS_TerminalWidgets.defaultDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
