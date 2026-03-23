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
-- POS_FreeAgentService.lua
-- Lifecycle service for free agents — runners, brokers,
-- couriers, and smugglers sent into zombie territory to
-- execute trade operations on the player's behalf.
--
-- State machine:
--   drafted → assembling → transit → negotiation → settlement → completed
--                              ↓           ↓
--                           delayed    compromised
--
-- Each economy tick advances agents probabilistically. The
-- player monitors progress through the signal feed and can
-- intervene at key decision points.
--
-- See design-guidelines.md §46.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_FreeAgentService = {}

local _TAG = "[POS:FreeAgent]"

---------------------------------------------------------------
-- State constants (no magic strings)
---------------------------------------------------------------

-- Use constants from POS_Constants — no magic strings
local STATE = {
    DRAFTED      = POS_Constants.AGENT_STATE_DRAFTED,
    ASSEMBLING   = POS_Constants.AGENT_STATE_ASSEMBLING,
    TRANSIT      = POS_Constants.AGENT_STATE_TRANSIT,
    NEGOTIATION  = POS_Constants.AGENT_STATE_NEGOTIATION,
    SETTLEMENT   = POS_Constants.AGENT_STATE_SETTLEMENT,
    COMPLETED    = POS_Constants.AGENT_STATE_COMPLETED,
    FAILED       = POS_Constants.AGENT_STATE_FAILED,
    DELAYED      = POS_Constants.AGENT_STATE_DELAYED,
    COMPROMISED  = POS_Constants.AGENT_STATE_COMPROMISED,
}

---------------------------------------------------------------
-- Persistence (world ModData)
---------------------------------------------------------------

local function getAgentStore()
    return PhobosLib.getWorldModDataTable("POSNET", "FreeAgents") or {}
end

local function saveAgentStore(store)
    PhobosLib.setWorldModDataTable("POSNET", "FreeAgents", store)
end

---------------------------------------------------------------
-- Agent name generation (apocalypse-flavoured)
---------------------------------------------------------------

local AGENT_FIRST_NAMES = {
    "Ghost", "Ash", "Crow", "Ember", "Flint", "Rust", "Shadow",
    "Thorn", "Vex", "Wire", "Bones", "Siren", "Copper", "Haze",
    "Patch", "Rook", "Slate", "Storm", "Volt", "Wraith",
}

local AGENT_CALL_SIGNS = {
    "the Runner", "Backpack", "No-Name", "Quick Hands",
    "the Broker", "Two-Face", "the Ghost", "Graveyard Shift",
    "the Mule", "Dead Drop", "Last Mile", "Nightcrawler",
}

local function generateAgentName()
    local first = AGENT_FIRST_NAMES[ZombRand(#AGENT_FIRST_NAMES) + 1]
    local call = AGENT_CALL_SIGNS[ZombRand(#AGENT_CALL_SIGNS) + 1]
    return first .. " '" .. call .. "'"
end

---------------------------------------------------------------
-- State transition logic
---------------------------------------------------------------

--- Determine the next state for an agent based on current state,
--- elapsed days, and risk. Probabilistic — not guaranteed to
--- advance every tick. Feels like waiting by the radio for news.
---@param agent table Agent record
---@param currentDay number
---@return string|nil New state, or nil if no transition
local function resolveNextState(agent, currentDay)
    local elapsed = currentDay - agent.lastStateDay
    if elapsed < 1 then return nil end  -- min 1 day per state

    local advanceChance = POS_Constants.FREE_AGENT_ADVANCE_CHANCE
    local riskChance = agent.riskLevel or POS_Constants.FREE_AGENT_DEFAULT_RISK

    if agent.state == STATE.DRAFTED then
        return STATE.ASSEMBLING

    elseif agent.state == STATE.ASSEMBLING then
        if PhobosLib.randFloat(0, 1) < advanceChance then
            return STATE.TRANSIT
        end

    elseif agent.state == STATE.TRANSIT then
        -- Risk: delay or compromise
        if PhobosLib.randFloat(0, 1) < riskChance then
            return (PhobosLib.randFloat(0, 1) < POS_Constants.FREE_AGENT_DELAY_VS_COMPROMISE)
                and STATE.DELAYED or STATE.COMPROMISED
        end
        if PhobosLib.randFloat(0, 1) < advanceChance then
            return STATE.NEGOTIATION
        end

    elseif agent.state == STATE.DELAYED then
        -- Delays resolve after 1-2 days
        if elapsed >= 2 or PhobosLib.randFloat(0, 1) < POS_Constants.FREE_AGENT_DELAY_RESOLVE_CHANCE then
            return STATE.TRANSIT  -- resume transit
        end

    elseif agent.state == STATE.COMPROMISED then
        -- Compromised agents have a chance to recover or fail
        if PhobosLib.randFloat(0, 1) < POS_Constants.FREE_AGENT_COMPROMISE_FAIL_CHANCE then
            return STATE.FAILED  -- lost the cargo, lost the agent
        end
        if PhobosLib.randFloat(0, 1) < POS_Constants.FREE_AGENT_COMPROMISE_RECOVER_CHANCE then
            return STATE.TRANSIT  -- recovered, continues
        end

    elseif agent.state == STATE.NEGOTIATION then
        if PhobosLib.randFloat(0, 1) < advanceChance then
            return STATE.SETTLEMENT
        end

    elseif agent.state == STATE.SETTLEMENT then
        return STATE.COMPLETED
    end

    return nil
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Deploy a free agent to execute a contract or sale.
---@param contractId string Contract to fulfil
---@param archetype string "runner"|"broker"|"courier"|"smuggler"|"wholesaler_contact"
---@param zoneId string Target zone
---@param cargoFullType string Item fullType
---@param cargoQuantity number Item count
---@param payout number Expected settlement payout
---@return table|nil Agent record, or nil on failure
function POS_FreeAgentService.deploy(contractId, archetype, zoneId,
        cargoFullType, cargoQuantity, payout)
    local store = getAgentStore()
    if not store.agents then store.agents = {} end

    -- Cap active agents
    local activeCount = 0
    for _, a in ipairs(store.agents) do
        if a.state ~= STATE.COMPLETED and a.state ~= STATE.FAILED then
            activeCount = activeCount + 1
        end
    end
    if activeCount >= POS_Constants.FREE_AGENT_MAX_ACTIVE then
        return nil
    end

    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    local commRate = POS_Constants.FREE_AGENT_COMMISSION_RATES[archetype]
        or POS_Constants.FREE_AGENT_DEFAULT_COMMISSION

    local agent = {
        schemaVersion  = 1,
        id             = "FA_" .. tostring(getTimestampMs()) .. "_" .. tostring(ZombRand(10000)),
        agentName      = generateAgentName(),
        agentArchetype = archetype,
        contractId     = contractId or "",
        state          = STATE.DRAFTED,
        zoneId         = zoneId or "",
        cargoFullType  = cargoFullType or "",
        cargoQuantity  = cargoQuantity or 0,
        commissionRate = commRate,
        estimatedDays  = POS_Constants.FREE_AGENT_ESTIMATED_DAYS[archetype]
            or POS_Constants.FREE_AGENT_DEFAULT_ESTIMATED_DAYS,
        startDay       = day,
        lastStateDay   = day,
        settlementPayout = payout or 0,
        riskLevel      = POS_Constants.FREE_AGENT_RISK_LEVELS[archetype]
            or POS_Constants.FREE_AGENT_DEFAULT_RISK,
    }

    store.agents[#store.agents + 1] = agent
    saveAgentStore(store)

    PhobosLib.debug("POS", _TAG, "Deployed agent: " .. agent.agentName
        .. " (" .. archetype .. ") to " .. zoneId)

    -- Emit event
    if POS_Events and POS_Events.OnFreeAgentDeployed then
        POS_Events.OnFreeAgentDeployed:trigger({
            agentId = agent.id, archetype = archetype, zoneId = zoneId,
        })
    end

    -- Signal feed notification
    PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
        title   = "POSnet",
        message = agent.agentName .. " deployed to " .. zoneId,
        colour  = "info",
        channel = POS_Constants.PN_CHANNEL_AGENTS,
    })

    return agent
end

--- Advance all active agents by one tick.
--- Called from economy tick. Probabilistic state transitions.
---@param currentDay number
function POS_FreeAgentService.tick(currentDay)
    local store = getAgentStore()
    if not store.agents then return end

    local changed = false
    for _, agent in ipairs(store.agents) do
        if agent.state ~= STATE.COMPLETED and agent.state ~= STATE.FAILED then
            local nextState = resolveNextState(agent, currentDay)
            if nextState then
                local prevState = agent.state
                agent.state = nextState
                agent.lastStateDay = currentDay
                changed = true

                PhobosLib.debug("POS", _TAG,
                    agent.agentName .. ": " .. prevState .. " -> " .. nextState)

                -- Handle settlement — credit money minus commission
                if nextState == STATE.COMPLETED and agent.settlementPayout > 0 then
                    local commission = agent.settlementPayout * agent.commissionRate
                    local netPayout = agent.settlementPayout - commission
                    local player = getPlayer()
                    if player and PhobosLib.addMoney then
                        PhobosLib.safecall(PhobosLib.addMoney, player, netPayout)
                    end
                    PhobosLib.debug("POS", _TAG,
                        "Settlement: $" .. string.format("%.2f", netPayout)
                        .. " (commission: $" .. string.format("%.2f", commission) .. ")")
                end

                -- Handle failure — cargo lost
                if nextState == STATE.FAILED then
                    PhobosLib.debug("POS", _TAG,
                        agent.agentName .. " lost in the field. Cargo presumed gone.")
                end

                -- Emit state change event
                if POS_Events and POS_Events.OnFreeAgentStateChanged then
                    POS_Events.OnFreeAgentStateChanged:trigger({
                        agentId = agent.id,
                        prevState = prevState,
                        newState = nextState,
                        agentName = agent.agentName,
                    })
                end

                -- Signal feed update
                local stateLabel = PhobosLib.safeGetText("UI_POS_FreeAgent_State_" .. nextState)
                local stateColour = (nextState == STATE.FAILED or nextState == STATE.COMPROMISED)
                    and "error"
                    or ((nextState == STATE.DELAYED) and "warning"
                    or ((nextState == STATE.COMPLETED) and "success" or "info"))
                local statePriority = (nextState == STATE.FAILED) and "critical"
                    or ((nextState == STATE.COMPROMISED) and "high"
                    or ((nextState == STATE.COMPLETED or nextState == STATE.DELAYED) and "normal" or "low"))
                PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
                    title    = "POSnet",
                    message  = agent.agentName .. ": " .. stateLabel,
                    colour   = stateColour,
                    priority = statePriority,
                    channel  = POS_Constants.PN_CHANNEL_AGENTS,
                })
            end
        end
    end

    if changed then saveAgentStore(store) end
end

--- Get all agents (active + completed + failed).
---@return table[]
function POS_FreeAgentService.getAll()
    local store = getAgentStore()
    return store.agents or {}
end

--- Get active agents (not completed/failed).
---@return table[]
function POS_FreeAgentService.getActive()
    local result = {}
    local store = getAgentStore()
    for _, a in ipairs(store.agents or {}) do
        if a.state ~= STATE.COMPLETED and a.state ~= STATE.FAILED then
            result[#result + 1] = a
        end
    end
    return result
end

--- Get completed/failed agents (history).
---@return table[]
function POS_FreeAgentService.getHistory()
    local result = {}
    local store = getAgentStore()
    for _, a in ipairs(store.agents or {}) do
        if a.state == STATE.COMPLETED or a.state == STATE.FAILED then
            result[#result + 1] = a
        end
    end
    return result
end

--- Get a specific agent by ID.
---@param agentId string
---@return table|nil
function POS_FreeAgentService.get(agentId)
    local store = getAgentStore()
    for _, a in ipairs(store.agents or {}) do
        if a.id == agentId then return a end
    end
    return nil
end

--- Recall an active agent (abort mission). Agent returns with
--- partial cargo but no payout. Better than losing everything.
---@param agentId string
---@return boolean
function POS_FreeAgentService.recall(agentId)
    local store = getAgentStore()
    for _, a in ipairs(store.agents or {}) do
        if a.id == agentId and a.state ~= STATE.COMPLETED
                and a.state ~= STATE.FAILED then
            a.state = STATE.FAILED
            a.lastStateDay = getGameTime() and getGameTime():getNightsSurvived() or 0
            saveAgentStore(store)

            PhobosLib.safecall(PhobosLib.notifyOrSay, getPlayer(), {
                title   = "POSnet",
                message = a.agentName .. " recalled. Mission aborted.",
                colour  = "warning",
                channel = POS_Constants.PN_CHANNEL_AGENTS,
            })
            return true
        end
    end
    return false
end
