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
-- POS_ContractService.lua
-- Sell-side contract lifecycle management.
--
-- Contracts are world-originated demand orders: someone needs
-- something and is willing to pay.  The player fulfils them
-- by delivering items through the terminal.
--
-- Lifecycle: posted → accepted → fulfilled → settled
--            posted → expired
--            accepted → failed (deadline)
--            accepted → betrayed (grey market)
--
-- See design-guidelines.md §43.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_ContractService = {}

local _TAG = "[POS:Contracts]"

---------------------------------------------------------------
-- Internal state (persisted in world ModData)
---------------------------------------------------------------

local function getContractStore()
    return PhobosLib.getWorldModDataTable("POSNET", "Contracts") or {}
end

local function saveContractStore(store)
    PhobosLib.setWorldModDataTable("POSNET", "Contracts", store)
end

---------------------------------------------------------------
-- Query API
---------------------------------------------------------------

--- Get all contracts matching a status.
--- @param status string One of POS_Constants.CONTRACT_STATUS_*
--- @return table[] Array of contract data tables
function POS_ContractService.getByStatus(status)
    local store = getContractStore()
    local result = {}
    for _, c in pairs(store) do
        if c.status == status then
            result[#result + 1] = c
        end
    end
    -- Sort by urgency descending, then deadline ascending
    table.sort(result, function(a, b)
        if a.urgency ~= b.urgency then return a.urgency > b.urgency end
        return (a.deadlineDay or 9999) < (b.deadlineDay or 9999)
    end)
    return result
end

--- Get all posted (available) contracts.
--- @return table[]
function POS_ContractService.getAvailable()
    return POS_ContractService.getByStatus(POS_Constants.CONTRACT_STATUS_POSTED)
end

--- Get all accepted (in-progress) contracts for this player.
--- @return table[]
function POS_ContractService.getActive()
    return POS_ContractService.getByStatus(POS_Constants.CONTRACT_STATUS_ACCEPTED)
end

--- Get settled/expired/failed/betrayed contracts for history.
--- @return table[]
function POS_ContractService.getHistory()
    local store = getContractStore()
    local result = {}
    for _, c in pairs(store) do
        local s = c.status
        if s == POS_Constants.CONTRACT_STATUS_SETTLED
            or s == POS_Constants.CONTRACT_STATUS_EXPIRED
            or s == POS_Constants.CONTRACT_STATUS_FAILED
            or s == POS_Constants.CONTRACT_STATUS_BETRAYED then
            result[#result + 1] = c
        end
    end
    table.sort(result, function(a, b)
        return (a.settledDay or a.deadlineDay or 0) > (b.settledDay or b.deadlineDay or 0)
    end)
    -- Trim to max history
    while #result > POS_Constants.CONTRACT_HISTORY_MAX_SIZE do
        table.remove(result)
    end
    return result
end

--- Get a single contract by ID.
--- @param contractId string
--- @return table|nil
function POS_ContractService.get(contractId)
    local store = getContractStore()
    return store[contractId]
end

--- Count active contracts.
--- @return number
function POS_ContractService.countActive()
    local count = 0
    local store = getContractStore()
    for _, c in pairs(store) do
        if c.status == POS_Constants.CONTRACT_STATUS_ACCEPTED then
            count = count + 1
        end
    end
    return count
end

---------------------------------------------------------------
-- Lifecycle: Post
---------------------------------------------------------------

--- Post a new contract into the available pool.
--- Called by POS_ContractGenerator when the world produces demand.
--- @param contract table  Generated contract data
--- @return boolean success
function POS_ContractService.post(contract)
    if not contract or not contract.id then return false end

    -- Enforce max available
    local available = POS_ContractService.getAvailable()
    if #available >= POS_Constants.CONTRACT_MAX_AVAILABLE then
        PhobosLib.debug("POS", _TAG, "Max available contracts reached, skipping")
        return false
    end

    contract.status = POS_Constants.CONTRACT_STATUS_POSTED
    contract.postedDay = getGameTime() and getGameTime():getNightsSurvived() or 0

    local store = getContractStore()
    store[contract.id] = contract
    saveContractStore(store)

    PhobosLib.debug("POS", _TAG,
        "Posted contract: " .. contract.id .. " [" .. (contract.kind or "?") .. "]")

    -- Emit event
    if POS_Events and POS_Events.OnContractPosted then
        POS_Events.OnContractPosted:trigger({ contractId = contract.id, kind = contract.kind })
    end

    return true
end

---------------------------------------------------------------
-- Lifecycle: Accept
---------------------------------------------------------------

--- Player accepts a posted contract.
--- @param contractId string
--- @return boolean success
--- @return string|nil error message
function POS_ContractService.accept(contractId)
    local store = getContractStore()
    local c = store[contractId]
    if not c then return false, "Contract not found" end
    if c.status ~= POS_Constants.CONTRACT_STATUS_POSTED then
        return false, "Contract not available"
    end

    -- Check active limit
    if POS_ContractService.countActive() >= POS_Constants.CONTRACT_MAX_ACTIVE then
        return false, "Maximum active contracts reached"
    end

    -- NOTE: No SIGINT gate on acceptance. Per §21, SIGINT affects data
    -- quality (what contracts you discover), not access (what you can accept).
    -- If a contract is visible, it's actionable.

    c.status = POS_Constants.CONTRACT_STATUS_ACCEPTED
    c.acceptedDay = getGameTime() and getGameTime():getNightsSurvived() or 0
    saveContractStore(store)

    PhobosLib.debug("POS", _TAG, "Accepted contract: " .. contractId)

    if POS_Events and POS_Events.OnContractAccepted then
        POS_Events.OnContractAccepted:trigger({ contractId = contractId })
    end

    -- Notification
    PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
        title   = "POSnet",
        message = PhobosLib.safeGetText("UI_POS_Contract_Accepted")
            .. ": " .. (c.briefing and c.briefing.title or c.kind),
        colour  = "info",
        channel = POS_Constants.PN_CHANNEL_CONTRACTS,
    })

    return true
end

---------------------------------------------------------------
-- Lifecycle: Fulfil
---------------------------------------------------------------

--- Player delivers items to fulfil an accepted contract.
--- Consumes items from inventory, credits payment, updates world state.
--- @param contractId string
--- @return boolean success
--- @return string|nil error message
function POS_ContractService.fulfil(contractId)
    local store = getContractStore()
    local c = store[contractId]
    if not c then return false, "Contract not found" end
    if c.status ~= POS_Constants.CONTRACT_STATUS_ACCEPTED then
        return false, "Contract not in progress"
    end

    local player = getPlayer()
    if not player then return false, "No player" end

    -- Check player has the required items
    local fullType = c.resolvedItemType
    local qty = c.resolvedQuantity or 0
    if not fullType or qty <= 0 then
        return false, "Contract has no resolved items"
    end

    local owned = PhobosLib.findAllItemsByFullType
        and PhobosLib.findAllItemsByFullType(player, fullType) or 0
    if type(owned) == "table" then owned = #owned end
    if owned < qty then
        return false, "Not enough items (" .. tostring(owned) .. "/" .. tostring(qty) .. ")"
    end

    -- Check for betrayal (grey market)
    if c.betrayalChance and c.betrayalChance > 0 then
        local roll = ZombRand(1000) / 1000
        if roll < c.betrayalChance then
            -- Betrayal! Items consumed but no payment.
            PhobosLib.safecall(PhobosLib.consumeItems, player, fullType, qty)
            c.status = POS_Constants.CONTRACT_STATUS_BETRAYED
            c.settledDay = getGameTime() and getGameTime():getNightsSurvived() or 0
            saveContractStore(store)

            PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
                title    = "POSnet",
                message  = PhobosLib.safeGetText("UI_POS_Contract_Betrayed_Msg"),
                colour   = "error",
                priority = "critical",
                channel  = POS_Constants.PN_CHANNEL_CONTRACTS,
            })

            if POS_Events and POS_Events.OnContractBetrayted then
                POS_Events.OnContractBetrayted:trigger({ contractId = contractId })
            end

            return false, "Buyer betrayed the deal"
        end
    end

    -- Consume items
    local okConsume = PhobosLib.safecall(PhobosLib.consumeItems, player, fullType, qty)
    if not okConsume then
        return false, "Failed to consume items"
    end

    -- Credit payment
    local payout = c.resolvedPayout or 0
    local okPay = PhobosLib.safecall(PhobosLib.addMoney, player, payout)
    if not okPay then
        -- Rollback: return items
        PhobosLib.safecall(PhobosLib.grantItems, player, fullType, qty)
        return false, "Failed to credit payment"
    end

    -- Update contract state
    c.status = POS_Constants.CONTRACT_STATUS_SETTLED
    c.settledDay = getGameTime() and getGameTime():getNightsSurvived() or 0
    saveContractStore(store)

    PhobosLib.debug("POS", _TAG,
        "Fulfilled contract: " .. contractId .. " — $" .. tostring(payout))

    -- Notification
    local displayName = PhobosLib.getItemDisplayName(fullType) or fullType
    PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
        title   = "POSnet",
        message = PhobosLib.safeGetText("UI_POS_Contract_Fulfilled_Msg")
            .. ": " .. tostring(qty) .. "x " .. displayName
            .. " — $" .. string.format("%.2f", payout),
        colour  = "success",
        channel = POS_Constants.PN_CHANNEL_CONTRACTS,
    })

    -- Emit events
    if POS_Events and POS_Events.OnContractFulfilled then
        POS_Events.OnContractFulfilled:trigger({
            contractId = contractId,
            fullType = fullType,
            quantity = qty,
            payout = payout,
            zoneId = c.zoneId,
            categoryId = c.categoryId,
        })
    end

    if POS_Events and POS_Events.OnTradeCompleted then
        POS_Events.OnTradeCompleted:trigger({
            type = "contract_sell",
            fullType = fullType,
            quantity = qty,
            totalCost = payout,
            categoryId = c.categoryId,
        })
    end

    return true
end

---------------------------------------------------------------
-- Lifecycle: Abandon
---------------------------------------------------------------

--- Player abandons an accepted contract.
--- @param contractId string
--- @return boolean success
function POS_ContractService.abandon(contractId)
    local store = getContractStore()
    local c = store[contractId]
    if not c then return false end
    if c.status ~= POS_Constants.CONTRACT_STATUS_ACCEPTED then return false end

    c.status = POS_Constants.CONTRACT_STATUS_FAILED
    c.settledDay = getGameTime() and getGameTime():getNightsSurvived() or 0
    c.failReason = "abandoned"
    saveContractStore(store)

    PhobosLib.debug("POS", _TAG, "Abandoned contract: " .. contractId)

    PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
        title   = "POSnet",
        message = PhobosLib.safeGetText("UI_POS_Contract_Abandoned_Msg"),
        colour  = "warning",
        channel = POS_Constants.PN_CHANNEL_CONTRACTS,
    })

    return true
end

---------------------------------------------------------------
-- Lifecycle: Agent-delegated settlement (§4.2 hard invariant)
---------------------------------------------------------------

--- Settle a contract that was fulfilled by a free agent.
--- Skips cargo consumption (agent consumed cargo on deploy).
--- Awards reputation and logs history.
---@param contractId string
---@param agentId string
---@return boolean
function POS_ContractService.settleViaAgent(contractId, agentId)
    local store = getContractStore()
    local c = store[contractId]
    if not c then return false end
    if c.status ~= POS_Constants.CONTRACT_STATUS_ACCEPTED then return false end

    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    c.status = POS_Constants.CONTRACT_STATUS_SETTLED
    c.settledDay = day
    c.settledByAgent = agentId
    saveContractStore(store)

    PhobosLib.debug("POS", _TAG,
        "Contract settled via agent: " .. contractId .. " (agent: " .. agentId .. ")")

    -- Emit Starlit event
    if POS_Events and POS_Events.OnContractFulfilled then
        POS_Events.OnContractFulfilled:trigger({
            contractId = contractId,
            settledByAgent = agentId,
        })
    end

    return true
end

---------------------------------------------------------------
-- Lifecycle: Expiry check (called from economy tick)
---------------------------------------------------------------

--- Check all posted and accepted contracts for deadline expiry.
function POS_ContractService.checkExpiry()
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    local store = getContractStore()
    local changed = false

    for id, c in pairs(store) do
        if c.deadlineDay and day > c.deadlineDay then
            if c.status == POS_Constants.CONTRACT_STATUS_POSTED then
                c.status = POS_Constants.CONTRACT_STATUS_EXPIRED
                c.settledDay = day
                changed = true
                PhobosLib.debug("POS", _TAG, "Contract expired (unaccepted): " .. id)
            elseif c.status == POS_Constants.CONTRACT_STATUS_ACCEPTED then
                c.status = POS_Constants.CONTRACT_STATUS_FAILED
                c.settledDay = day
                c.failReason = "deadline"
                changed = true
                PhobosLib.debug("POS", _TAG, "Contract failed (deadline): " .. id)

                PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
                    title   = "POSnet",
                    message = PhobosLib.safeGetText("UI_POS_Contract_Expired_Msg"),
                    colour  = "error",
                    channel = POS_Constants.PN_CHANNEL_CONTRACTS,
                })
            end
        end
    end

    if changed then saveContractStore(store) end
end

---------------------------------------------------------------
-- Cleanup: remove very old history entries
---------------------------------------------------------------

function POS_ContractService.cleanupHistory()
    local store = getContractStore()
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    local changed = false

    for id, c in pairs(store) do
        local s = c.status
        if (s == POS_Constants.CONTRACT_STATUS_SETTLED
            or s == POS_Constants.CONTRACT_STATUS_EXPIRED
            or s == POS_Constants.CONTRACT_STATUS_FAILED
            or s == POS_Constants.CONTRACT_STATUS_BETRAYED) then
            -- Remove entries older than 30 days
            if c.settledDay and (day - c.settledDay) > 30 then
                store[id] = nil
                changed = true
            end
        end
    end

    if changed then saveContractStore(store) end
end
