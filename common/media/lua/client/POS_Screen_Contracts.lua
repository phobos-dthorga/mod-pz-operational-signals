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
-- "Incoming Requests" — sell-side contract browser under BBS.
--
-- Single unified list with status badges: [OPEN], [ACCEPTED],
-- [DONE], [EXPIRED], [FAILED], [BETRAYED]. Filter buttons at
-- top: All / Mine / Settled.
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
local _activeFilter = "all"  -- "all" | "mine" | "settled"

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

local function getKindLabel(kind)
    return PhobosLib.safeGetText("UI_POS_Contract_Kind_" .. (kind or "procurement"))
end

local function getUrgencyLabel(urgency)
    return PhobosLib.safeGetText("UI_POS_Contract_Urgency_" .. tostring(urgency or 2))
end

local STATUS_BADGES = {
    posted   = { text = "OPEN",     colour = "textBright" },
    accepted = { text = "ACCEPTED", colour = "warning" },
    settled  = { text = "DONE",     colour = "success" },
    expired  = { text = "EXPIRED",  colour = "dim" },
    failed   = { text = "FAILED",   colour = "error" },
    betrayed = { text = "BETRAYED", colour = "error" },
}

local function getStatusBadge(status)
    return STATUS_BADGES[status] or STATUS_BADGES.posted
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
screen.menuPath = {"pos.bbs"}
screen.titleKey = "UI_POS_Contract_Title"
screen.sortOrder = 15

---------------------------------------------------------------
-- Contract row rendering
---------------------------------------------------------------

local function renderContractRow(ctx, contract, parent, rx, ry, rw, _idx)
    local W = POS_TerminalWidgets
    local C = W.COLOURS

    local badge = getStatusBadge(contract.status)
    local badgeColour = C[badge.colour] or C.text
    local urgColour = getUrgencyColour(contract.urgency, C)

    -- Row 1: [STATUS] Kind badge + briefing title
    local title = contract.briefing and contract.briefing.title
        or getKindLabel(contract.kind)
    W.createLabel(parent, rx, ry,
        "[" .. badge.text .. "] " .. title, badgeColour)
    ry = ry + ctx.lineH

    -- Row 2: Item + quantity + payout
    local itemName = contract.resolvedItemType
        and getItemDisplayName(contract.resolvedItemType)
        or (contract.categoryId or "?")
    local qty = contract.resolvedQuantity or 0
    local payout = contract.resolvedPayout or 0
    W.createLabel(parent, rx + 8, ry,
        tostring(qty) .. "x " .. itemName
        .. "  --  $" .. string.format("%.2f", payout),
        urgColour)
    ry = ry + ctx.lineH

    -- Row 3: Deadline + urgency
    local daysLeft = getDaysLeft(contract)
    local deadlineStr
    if contract.status == "settled" or contract.status == "failed"
            or contract.status == "betrayed" or contract.status == "expired" then
        deadlineStr = badge.text
    elseif daysLeft > 0 then
        deadlineStr = tostring(daysLeft) .. " days left"
    elseif daysLeft == 0 then
        deadlineStr = "DUE TODAY"
    else
        deadlineStr = "OVERDUE"
    end
    local urgStr = getUrgencyLabel(contract.urgency)
    W.createLabel(parent, rx + 8, ry,
        urgStr .. "  |  " .. deadlineStr, C.dim)
    ry = ry + ctx.lineH

    -- Select button
    local isTerminal = (contract.status ~= "expired")
    if isTerminal then
        local contractId = contract.id
        local isSelected = (_selectedContractId == contractId)
        local label = isSelected and "> SELECTED" or "View Details"
        local labelColour = isSelected and C.textBright or nil
        W.createButton(parent, rx, ry, rw, ctx.btnH,
            label, labelColour,
            function()
                _selectedContractId = contractId
                POS_ScreenManager.refreshCurrentScreen()
            end)
        ry = ry + ctx.btnH + 4
    else
        ry = ry + 4
    end

    return ry - (ctx.lineH * 3 + (isTerminal and (ctx.btnH + 4) or 4))
end

---------------------------------------------------------------
-- Main create
---------------------------------------------------------------

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Resolve filter from params
    _activeFilter = (params and params.filter) or _activeFilter or "all"

    W.drawHeader(ctx, "UI_POS_Contract_Title")

    -- Filter buttons: All | Mine | Settled
    local filters = {
        { id = "all",     label = "All" },
        { id = "mine",    label = "Mine" },
        { id = "settled", label = "Settled" },
    }

    local filterX = ctx.btnX
    local filterW = math.floor(ctx.btnW / #filters) - 2
    for _, f in ipairs(filters) do
        if _activeFilter == f.id then
            W.createLabel(contentPanel, filterX + 4, ctx.y + 2,
                "> " .. f.label, C.textBright)
        else
            local fId = f.id
            W.createButton(contentPanel, filterX, ctx.y, filterW, ctx.btnH,
                f.label, nil,
                function()
                    _activeFilter = fId
                    _selectedContractId = nil
                    POS_ScreenManager.replaceCurrent(
                        POS_Constants.SCREEN_CONTRACTS, { filter = fId })
                end)
        end
        filterX = filterX + filterW + 4
    end
    ctx.y = ctx.y + ctx.btnH + 6

    W.createSeparator(contentPanel, 0, ctx.y, 50, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Gather contracts based on filter
    local contracts = {}
    if _activeFilter == "all" then
        -- All non-settled: open + accepted
        local avail = POS_ContractService.getAvailable()
        local active = POS_ContractService.getActive()
        for _, c in ipairs(avail) do contracts[#contracts + 1] = c end
        for _, c in ipairs(active) do contracts[#contracts + 1] = c end
    elseif _activeFilter == "mine" then
        contracts = POS_ContractService.getActive()
    elseif _activeFilter == "settled" then
        contracts = POS_ContractService.getHistory()
    end

    if #contracts == 0 then
        local emptyMsg = _activeFilter == "mine"
            and "No accepted contracts. Browse [All] to find open requests."
            or (_activeFilter == "settled"
                and "No settled contracts yet."
                or "No contracts available. Check back after the next economy tick.")
        W.createLabel(contentPanel, 8, ctx.y, emptyMsg, C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (params and params.contractPage) or 1
        local filterCopy = _activeFilter

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
            renderItem = function(parent, rx, ry, rw, item, idx)
                local startY = ry
                ry = renderContractRow(ctx, item, parent, rx, ry, rw, idx)
                return ry - startY
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(
                    POS_Constants.SCREEN_CONTRACTS,
                    { filter = filterCopy, contractPage = newPage })
            end,
        })
    end

    -- Player balance
    local balance = POS_TradeService and POS_TradeService.getPlayerBalance
        and POS_TradeService.getPlayerBalance(getPlayer()) or 0
    ctx.y = ctx.y + 4
    W.createLabel(contentPanel, 8, ctx.y,
        "Balance: $" .. string.format("%.2f", balance), C.dim)
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

    -- Header: status badge + kind
    local badge = getStatusBadge(contract.status)
    table.insert(data, { type = "header",
        text = "[" .. badge.text .. "] " .. getKindLabel(contract.kind) })
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
        local riskLabel = contract.betrayalChance >= POS_Constants.BETRAYAL_THRESHOLD_HIGH and "HIGH"
            or (contract.betrayalChance >= POS_Constants.BETRAYAL_THRESHOLD_MODERATE and "MODERATE" or "LOW")
        table.insert(data, { type = "kv", key = "UI_POS_Contract_Risk",
            value = riskLabel,
            colour = contract.betrayalChance >= POS_Constants.BETRAYAL_COLOUR_THRESHOLD and "error" or "warning" })
    end

    -- NOTE: No SIGINT gate display. Per §21, SIGINT affects data quality
    -- (confidence, noise), not screen/contract access.

    -- Briefing situation text (if available)
    if contract.briefing and contract.briefing.situation
            and contract.briefing.situation ~= "" then
        table.insert(data, { type = "separator" })
        table.insert(data, { type = "header", text = "BRIEFING" })
        local sit = contract.briefing.situation
        if #sit > 80 then sit = string.sub(sit, 1, 77) .. "..." end
        table.insert(data, { type = "kv", key = "", value = sit })
    end

    -- Inventory check for accepted contracts
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
                    POS_ScreenManager.refreshCurrentScreen()
                else
                    PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
                        title   = "POSnet",
                        message = err or PhobosLib.safeGetText("UI_POS_Contract_Err_Accept"),
                        colour  = "error",
                        channel = POS_Constants.PN_CHANNEL_CONTRACTS,
                    })
                end
            end,
        })
    elseif contract.status == POS_Constants.CONTRACT_STATUS_ACCEPTED then
        local cId = contract.id
        table.insert(data, {
            type = "action",
            text = "UI_POS_Contract_Fulfil",
            callback = function()
                local ok, err = POS_ContractService.fulfil(cId)
                if ok then
                    _selectedContractId = nil
                    POS_ScreenManager.refreshCurrentScreen()
                else
                    PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
                        title   = "POSnet",
                        message = err or PhobosLib.safeGetText("UI_POS_Contract_Err_Fulfil"),
                        colour  = "error",
                        channel = POS_Constants.PN_CHANNEL_CONTRACTS,
                    })
                end
            end,
        })
        table.insert(data, {
            type = "action",
            text = "UI_POS_Contract_Abandon",
            callback = function()
                POS_ContractService.abandon(cId)
                _selectedContractId = nil
                POS_ScreenManager.refreshCurrentScreen()
            end,
        })
        -- Send Agent button — delegates contract fulfilment to a free agent
        table.insert(data, { type = "separator" })
        local activeAgents = POS_FreeAgentService and POS_FreeAgentService.getActive
            and POS_FreeAgentService.getActive() or {}
        local canDeploy = #activeAgents < POS_Constants.FREE_AGENT_MAX_ACTIVE
        table.insert(data, {
            type = "action",
            text = "UI_POS_FreeAgent_Deploy",
            enabled = canDeploy,
            tooltip = not canDeploy
                and PhobosLib.safeGetText("UI_POS_AgentDeploy_NoSlots") or nil,
            callback = function()
                POS_ScreenManager.navigateTo(POS_Constants.SCREEN_AGENT_DEPLOY,
                    { contractId = cId })
            end,
        })
    end

    return data
end

---------------------------------------------------------------

screen.destroy = function()
    _selectedContractId = nil
    _activeFilter = "all"
    POS_TerminalWidgets.defaultDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
