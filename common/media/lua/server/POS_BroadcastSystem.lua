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
require "POS_WorldState"
require "POS_MarketDatabase"
require "POS_MarketFileStore"
require "POS_MarketRegistry"
require "POS_MarketBroadcaster"

POS_BroadcastSystem = {}

local _TAG = "[POS:Broadcast]"

--- Broadcast a server command to all connected players.
--- In SP, invokes the client handler directly (sendServerCommand crashes
--- the JVM during early frames in SP). In MP, iterates getOnlinePlayers().
--- @param module string Command module
--- @param command string Command name
--- @param args table Command arguments
function POS_BroadcastSystem.broadcastToAll(module, command, args)
    if isServer and isServer() then
        -- Dedicated/listen server: iterate online players
        local players = getOnlinePlayers and getOnlinePlayers()
        if players then
            for i = 0, players:size() - 1 do
                local p = players:get(i)
                if p then
                    sendServerCommand(p, module, command, args)
                end
            end
        end
    else
        -- Single-player: invoke client handler directly to avoid
        -- sendServerCommand which can crash the JVM during init.
        if POS_RadioInterception and POS_RadioInterception.handleCommand then
            POS_RadioInterception.handleCommand(command, args)
        end
    end
end

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
        PhobosLib.debug("POS", _TAG, "Broadcasts disabled in sandbox — system not started")
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
    PhobosLib.debug("POS", _TAG, "Broadcast system started (interval: "
        .. POS_Sandbox.getBroadcastIntervalMinutes() .. " min)")
end

--- Stop the broadcast system.
function POS_BroadcastSystem.stop()
    systemActive = false
    PhobosLib.debug("POS", _TAG, "Broadcast system stopped")
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
        PhobosLib.debug("POS", _TAG, "Mission generation failed — no broadcast sent")
        return false
    end

    -- Broadcast to all clients via server command
    POS_BroadcastSystem.broadcastToAll(POS_Constants.CMD_MODULE, POS_Constants.CMD_NEW_OPERATION, {
        operationData = operation,
    })

    PhobosLib.debug("POS", _TAG, "Broadcast sent: " .. operation.id
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
        PhobosLib.debug("POS", _TAG, "Investment generation failed — no broadcast sent")
        return false
    end

    -- Broadcast to all clients via server command
    POS_BroadcastSystem.broadcastToAll(POS_Constants.CMD_MODULE, POS_Constants.CMD_NEW_INVESTMENT, {
        investmentData = opportunity,
    })

    PhobosLib.debug("POS", _TAG, "Investment broadcast sent: " .. opportunity.id
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

    -- Market broadcasts (separate timer, managed by POS_MarketBroadcaster)
    if POS_MarketBroadcaster then
        POS_MarketBroadcaster.tick()
    end
end

--- Handle client command responses (reserved for future use).
--- @param module string Command module name
--- @param command string Command name
--- @param player IsoPlayer Sending player
--- @param args table Command arguments
function POS_BroadcastSystem.onClientCommand(module, command, player, args)
    if module ~= POS_Constants.CMD_MODULE then return end

    if command == POS_Constants.CMD_SUBMIT_OBSERVATION then
        if not args or not args.record then return end
        local record = args.record

        -- Validate required fields
        if type(record.categoryId) ~= "string" or record.categoryId == "" then
            PhobosLib.debug("POS", _TAG, "[Validation] Rejected observation: invalid categoryId from "
                .. (player:getUsername() or "?"))
            return
        end

        -- Validate category exists in registry
        if POS_MarketRegistry and POS_MarketRegistry.getCategory then
            if not POS_MarketRegistry.getCategory(record.categoryId) then
                PhobosLib.debug("POS", _TAG, "[Validation] Rejected observation: unknown category '"
                    .. tostring(record.categoryId) .. "' from " .. (player:getUsername() or "?"))
                return
            end
        end

        -- Validate price range (reject obviously invalid)
        if record.price and (type(record.price) ~= "number" or record.price < 0 or record.price > 10000) then
            PhobosLib.debug("POS", _TAG, "[Validation] Rejected observation: invalid price "
                .. tostring(record.price) .. " from " .. (player:getUsername() or "?"))
            return
        end

        -- Set server-authoritative fields
        record.recordedDay = POS_WorldState and POS_WorldState.getWorldDay() or 0
        record.id = record.id or ("obs_" .. tostring(ZombRand(1000000000)))

        POS_MarketDatabase.addRecord(record)

    elseif command == POS_Constants.CMD_REQUEST_MARKET_SNAPSHOT then
        -- Client requesting market overview for their local cache.
        -- Send aggregates + rolling closes only — observations are too
        -- large to pass through sendServerCommand safely (bulk table
        -- allocation can crash the JVM). MP clients that need per-item
        -- observations will request them on-demand per screen (future).
        if player then
            local snapshot = {}
            local world = POS_WorldState and POS_WorldState.getWorld()
            for catId, catData in pairs(POS_MarketFileStore.getAllCategories()) do
                local agg = (world and world.categories
                    and world.categories[catId]
                    and world.categories[catId].aggregate) or {}
                snapshot[catId] = {
                    rollingCloses = catData.rollingCloses or {},
                    aggregate = agg,
                }
            end
            sendServerCommand(player, POS_Constants.CMD_MODULE,
                POS_Constants.CMD_MARKET_SNAPSHOT, { data = snapshot })
        end

    elseif command == POS_Constants.CMD_REQUEST_OPERATION then
        -- Future: allow players to request a new operation on demand
        PhobosLib.debug("POS", _TAG, "Operation request from " .. (player:getUsername() or "?"))
    elseif command == POS_Constants.CMD_PLAYER_INVESTED and args then
        if POS_InvestmentResolver then
            POS_InvestmentResolver.onPlayerInvested(player, args)
        end
    elseif command == POS_Constants.CMD_REQUEST_PAYOUTS then
        if POS_InvestmentResolver then
            POS_InvestmentResolver.onRequestPendingPayouts(player)
        end

    elseif command == POS_Constants.CMD_ADMIN_FORCE_TICK then
        -- Admin only: force economy tick
        if PhobosLib.isPlayerAdmin and PhobosLib.isPlayerAdmin(player) then
            if POS_EconomyTick and POS_EconomyTick.processDayTick then
                local meta = POS_WorldState.getMeta()
                meta.lastProcessedDay = -1  -- Force reprocessing
                POS_EconomyTick.processDayTick()
                PhobosLib.debug("POS", _TAG, "[Admin] Force tick executed by " .. (player:getUsername() or "?"))
            end
        end

    elseif command == POS_Constants.CMD_ADMIN_DUMP_STATE then
        -- Admin only: dump compact world state summary
        if PhobosLib.isPlayerAdmin and PhobosLib.isPlayerAdmin(player) then
            local meta = POS_WorldState.getMeta()
            local summary = {
                schemaVersion = meta.schemaVersion,
                lastProcessedDay = meta.lastProcessedDay,
                categoryCount = 0,
                totalObservations = 0,
            }
            for _, catData in pairs(POS_MarketFileStore.getAllCategories()) do
                summary.categoryCount = summary.categoryCount + 1
                summary.totalObservations = summary.totalObservations
                    + (catData.observations and #catData.observations or 0)
            end
            sendServerCommand(player, POS_Constants.CMD_MODULE,
                POS_Constants.CMD_ADMIN_DUMP_STATE, { summary = summary })
            PhobosLib.debug("POS", _TAG, "[Admin] State dump sent to " .. (player:getUsername() or "?"))
        end
    end
end

--- Initialise the broadcast system on server start.
function POS_BroadcastSystem.init()
    POS_BroadcastSystem.start()

    -- Start market broadcaster alongside operation/investment timers
    if POS_MarketBroadcaster then
        POS_MarketBroadcaster.start()
    end

    Events.EveryOneMinute.Add(POS_BroadcastSystem.onEveryOneMinute)
    Events.OnClientCommand.Add(POS_BroadcastSystem.onClientCommand)
    PhobosLib.debug("POS", _TAG, "Broadcast system initialised")
end

Events.OnGameStart.Add(POS_BroadcastSystem.init)
