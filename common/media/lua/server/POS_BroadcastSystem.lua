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
-- POS_BroadcastSystem.lua
-- Server-side timed broadcast scheduling and transmission.
--
-- Generates new operations at configurable intervals and
-- broadcasts them over the POSnet radio frequency.
-- Clients receive the transmission via POS_RadioInterception.
--
-- Broadcast flow:
--   Timer tick → MissionGenerator.generate() → serialize →
--   sendServerCommand("POS", "NewOperation", data) →
--   client OnServerCommand → RadioInterception.onTransmissionReceived()
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_BroadcastSystem = {}

--- Last broadcast timestamp (real-time milliseconds).
local lastBroadcastTime = 0

--- Last investment broadcast timestamp (real-time milliseconds).
local lastInvestmentBroadcastTime = 0

--- Whether the broadcast system is active.
local systemActive = false

--- Delay in game-minutes before the first investment broadcast fires.
local FIRST_INVESTMENT_DELAY_MINS = 5

--- Start the broadcast system.
function POS_BroadcastSystem.start()
    if not POS_Sandbox.isBroadcastEnabled() then
        PhobosLib.debug("POS", "Broadcasts disabled in sandbox — system not started")
        return
    end

    systemActive = true
    local now = getTimestampMs()
    lastBroadcastTime = now
    -- Offset investment timer so the first broadcast fires after ~5 game-minutes
    -- instead of the full interval (default 60 min), improving first-time experience.
    local invIntervalMs = POS_Sandbox.getInvestmentBroadcastMins() * 60 * 1000
    local firstInvDelayMs = FIRST_INVESTMENT_DELAY_MINS * 60 * 1000
    lastInvestmentBroadcastTime = now - invIntervalMs + firstInvDelayMs
    PhobosLib.debug("POS", "Broadcast system started (interval: "
        .. POS_Sandbox.getBroadcastIntervalMinutes() .. " min)")
end

--- Stop the broadcast system.
function POS_BroadcastSystem.stop()
    systemActive = false
    PhobosLib.debug("POS", "Broadcast system stopped")
end

--- Generate and broadcast a new operation to all connected clients.
--- @return boolean True if a broadcast was sent
function POS_BroadcastSystem.broadcast()
    if not systemActive then return false end

    -- Pick a random online player as the generation context
    local players = getOnlinePlayers()
    if not players or players:size() == 0 then return false end
    local player = players:get(ZombRand(players:size()))
    if not player then return false end

    local operation = POS_MissionGenerator.generate(player)
    if not operation then
        PhobosLib.debug("POS", "Mission generation failed — no broadcast sent")
        return false
    end

    -- Broadcast to all clients via server command
    sendServerCommand(POS_Constants.CMD_MODULE, POS_Constants.CMD_NEW_OPERATION, {
        operationData = operation,
    })

    PhobosLib.debug("POS", "Broadcast sent: " .. operation.id
        .. " [" .. (operation.category or "?") .. "]")

    return true
end

--- Generate and broadcast a new investment opportunity to all connected clients.
--- @return boolean True if a broadcast was sent
function POS_BroadcastSystem.broadcastInvestment()
    if not systemActive then return false end
    if not POS_Sandbox.isInvestmentEnabled() then return false end

    local opportunity = POS_InvestmentGenerator.generate()
    if not opportunity then
        PhobosLib.debug("POS", "Investment generation failed — no broadcast sent")
        return false
    end

    -- Broadcast to all clients via server command
    sendServerCommand(POS_Constants.CMD_MODULE, POS_Constants.CMD_NEW_INVESTMENT, {
        investmentData = opportunity,
    })

    PhobosLib.debug("POS", "Investment broadcast sent: " .. opportunity.id
        .. " (poster=" .. (opportunity.posterName or "?") .. ")")

    return true
end

--- Tick handler — checks if it's time to broadcast.
--- Runs every in-game minute; uses real-time interval.
function POS_BroadcastSystem.onEveryOneMinute()
    if not systemActive then return end

    local now = getTimestampMs()

    -- Operation broadcasts
    local intervalMs = POS_Sandbox.getBroadcastIntervalMinutes() * 60 * 1000
    if (now - lastBroadcastTime) >= intervalMs then
        POS_BroadcastSystem.broadcast()
        lastBroadcastTime = now
    end

    -- Investment broadcasts (separate timer)
    local invIntervalMs = POS_Sandbox.getInvestmentBroadcastMins() * 60 * 1000
    if (now - lastInvestmentBroadcastTime) >= invIntervalMs then
        POS_BroadcastSystem.broadcastInvestment()
        lastInvestmentBroadcastTime = now
    end

    -- Investment maturity resolution
    if POS_InvestmentResolver then
        POS_InvestmentResolver.resolveMatured()
    end
end

--- Handle client command responses (reserved for future use).
--- @param module string Command module name
--- @param command string Command name
--- @param player IsoPlayer Sending player
--- @param args table Command arguments
function POS_BroadcastSystem.onClientCommand(module, command, player, args)
    if module ~= POS_Constants.CMD_MODULE then return end

    if command == POS_Constants.CMD_REQUEST_OPERATION then
        -- Future: allow players to request a new operation on demand
        PhobosLib.debug("POS", "Operation request from " .. (player:getUsername() or "?"))
    elseif command == POS_Constants.CMD_PLAYER_INVESTED and args then
        if POS_InvestmentResolver then
            POS_InvestmentResolver.onPlayerInvested(player, args)
        end
    elseif command == POS_Constants.CMD_REQUEST_PAYOUTS then
        if POS_InvestmentResolver then
            POS_InvestmentResolver.onRequestPendingPayouts(player)
        end
    end
end

--- Initialise the broadcast system on server start.
function POS_BroadcastSystem.init()
    POS_BroadcastSystem.start()
    Events.EveryOneMinute.Add(POS_BroadcastSystem.onEveryOneMinute)
    Events.OnClientCommand.Add(POS_BroadcastSystem.onClientCommand)
    PhobosLib.debug("POS", "Broadcast system initialised")
end

Events.OnGameStart.Add(POS_BroadcastSystem.init)
