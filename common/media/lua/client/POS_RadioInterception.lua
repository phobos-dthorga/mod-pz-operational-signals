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
-- POS_RadioInterception.lua
-- POSnet radio channel registration and broadcast reception.
--
-- Registers the POSnet frequency as a custom radio channel
-- via PZ's OnLoadRadioScripts callback. Listens for incoming
-- server commands and routes operation data to the Operation Log.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_MarketDatabase"
require "POS_WorldState"
require "POS_WatchlistService"
require "POS_PlayerFileStore"

POS_RadioInterception = {}

local _TAG = "[POS:RadioInt]"

--- Whether the POSnet channel has been registered.
local channelRegistered = false

--- Register POSnet radio channels with PZ's radio system.
--- Called from init() on OnGameStart (after AZAS assigns frequencies).
function POS_RadioInterception.registerChannels()
    if channelRegistered then return end

    local mgr = getRadioScriptManager and getRadioScriptManager()
    if not mgr then
        PhobosLib.debug("POS", _TAG, "RadioScriptManager not available — skipping channel registration")
        return
    end

    -- Register operations channel (amateur band)
    local opsFreq = POS_AZASIntegration and POS_AZASIntegration.getOperationsFrequency
        and POS_AZASIntegration.getOperationsFrequency() or 130000
    local opsCh = mgr:AddChannel("POSnet Operations", opsFreq)
    if opsCh then
        opsCh:SetCategory("Military")
        PhobosLib.debug("POS", _TAG, "POSnet Operations channel at " .. tostring(opsFreq) .. " Hz")
    end

    -- Register tactical channel (military band)
    local tacFreq = POS_AZASIntegration and POS_AZASIntegration.getTacticalFrequency
        and POS_AZASIntegration.getTacticalFrequency() or 155000
    local tacCh = mgr:AddChannel("POSnet Tactical", tacFreq)
    if tacCh then
        tacCh:SetCategory("Military")
        PhobosLib.debug("POS", _TAG, "POSnet Tactical channel at " .. tostring(tacFreq) .. " Hz")
    end

    channelRegistered = true
end

--- Handle an incoming POSnet transmission from the server.
--- Routes operation data to the Operation Log.
--- @param transmission table Transmission data with operationData field
function POS_RadioInterception.onTransmissionReceived(transmission)
    if not transmission then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    PhobosLib.debug("POS", _TAG, "Transmission received")

    if transmission.operationData and POS_OperationLog then
        local added = POS_OperationLog.addOperation(transmission.operationData)
        if added then
            PhobosLib.debug("POS", _TAG, "Operation added: " .. (transmission.operationData.id or "?"))
        end
    end
end

--- Handle server commands sent to the POS module.
--- @param module string Command module name
--- @param command string Command name
--- @param args table Command arguments
local function onServerCommand(module, command, args)
    if module ~= POS_Constants.CMD_MODULE then return end

    if command == POS_Constants.CMD_NEW_OPERATION and args and args.operationData then
        POS_RadioInterception.onTransmissionReceived(args)
    elseif command == POS_Constants.CMD_NEW_INVESTMENT and args and args.investmentData then
        if POS_InvestmentLog then
            local added = POS_InvestmentLog.addOpportunity(args.investmentData)
            if added then
                PhobosLib.debug("POS", _TAG, "Investment opportunity received: "
                    .. (args.investmentData.id or "?"))
            end
        end
    elseif command == POS_Constants.CMD_INVESTMENT_RESOLVED and args then
        if POS_InvestmentLog then
            local record = POS_InvestmentLog.resolveInvestment(
                args.investmentId, args.status)
            if record and args.status == POS_Constants.INV_STATUS_MATURED and args.returnAmount then
                -- Pay out the return to the player
                local player = getSpecificPlayer(0)
                if player then
                    PhobosLib.addMoney(player, args.returnAmount)
                    PhobosLib.debug("POS", _TAG, "Investment matured — $"
                        .. args.returnAmount .. " added to inventory")
                end
            elseif record and args.status == POS_Constants.INV_STATUS_DEFAULTED then
                PhobosLib.debug("POS", _TAG, "Investment defaulted — $"
                    .. (record.principalAmount or 0) .. " lost")
            end
        end
    elseif command == POS_Constants.CMD_INVESTMENT_ACK and args then
        PhobosLib.debug("POS", _TAG, "Server acknowledged investment: "
            .. (args.investmentId or "?"))
    elseif command == POS_Constants.CMD_MARKET_BROADCAST and args and args.marketData then
        -- Auto-ingest broadcast market data into the database
        if POS_MarketDatabase then
            local added = POS_MarketDatabase.addRecord(args.marketData)
            if added then
                PhobosLib.debug("POS", _TAG, "Market broadcast ingested: "
                    .. (args.marketData.categoryId or "?")
                    .. " @ $" .. (args.marketData.price or "?"))
            end
        end

    elseif command == POS_Constants.CMD_MARKET_SNAPSHOT then
        -- SP/authority: data is already in POS_MarketFileStore — skip
        -- the client cache entirely. Only MP clients need snapshot data.
        if POS_WorldState and POS_WorldState.isAuthority() then
            PhobosLib.debug("POS", _TAG, "[RadioInterception] Market snapshot ignored (SP authority)")
        elseif args and args.data and POS_MarketDatabase then
            -- MP client: store aggregates only. Observations are too large
            -- to process during a server command handler without risking
            -- a JVM crash from bulk table allocation. MP clients access
            -- observations on-demand via per-screen requests (future).
            for catId, catData in pairs(args.data) do
                POS_MarketDatabase.updateClientCache(catId, {
                    observations  = {},
                    rollingCloses = catData.rollingCloses or {},
                    aggregate     = catData.aggregate or {},
                })
            end
            PhobosLib.debug("POS", _TAG, "[RadioInterception] Market snapshot received (aggregates + closes)")
        end

        -- Refresh watchlist snapshots now that fresh price data is available.
        if getGameTime and getGameTime():getWorldAgeHours() > 0 then
            local snapshotPlayer = getSpecificPlayer(0)
            if snapshotPlayer and POS_WatchlistService then
                PhobosLib.safecall(POS_WatchlistService.refresh, snapshotPlayer)
            end
        end

    elseif command == POS_Constants.CMD_ECONOMY_TICK_COMPLETE then
        -- Economy day tick completed — request fresh snapshot
        if POS_MarketDatabase then
            POS_MarketDatabase.clearClientCache()
        end
        -- Auto-request fresh data
        local player = getSpecificPlayer(0)
        if player then
            sendClientCommand(player, POS_Constants.CMD_MODULE,
                POS_Constants.CMD_REQUEST_MARKET_SNAPSHOT, {})
        end

        -- SP shortcut: server and client share the same data, so refresh
        -- the watchlist immediately without waiting for a snapshot response.
        if POS_WorldState and POS_WorldState.isAuthority() then
            if player and POS_WatchlistService then
                PhobosLib.safecall(POS_WatchlistService.refresh, player)
            end
        end

        PhobosLib.debug("POS", _TAG, "[RadioInterception] Economy tick day="
            .. tostring(args and args.day or "?"))

    elseif command == POS_Constants.CMD_BUILDING_CACHE_SYNC then
        -- Server sent building cache sync
        if args and args.entries and POS_WorldState then
            local buildings = POS_WorldState.getBuildings()
            buildings.entries = args.entries
        end

    elseif command == POS_Constants.CMD_MAILBOX_CACHE_SYNC then
        -- Server sent mailbox cache sync
        if args and args.entries and POS_WorldState then
            local mailboxes = POS_WorldState.getMailboxes()
            mailboxes.entries = args.entries
        end
    end
end

--- Public entry point for server-side code to invoke client command
--- handlers directly in SP (bypassing sendServerCommand).
--- @param command string Command name (without module prefix)
--- @param args table|nil Command arguments
function POS_RadioInterception.handleCommand(command, args)
    onServerCommand(POS_Constants.CMD_MODULE, command, args)
end

--- Request a new operation from the server (future use).
function POS_RadioInterception.requestOperation()
    local player = getSpecificPlayer(0)
    if player then
        sendClientCommand(player, POS_Constants.CMD_MODULE, POS_Constants.CMD_REQUEST_OPERATION, {})
    end
end

--- Check whether the POSnet channel is registered.
--- @return boolean
function POS_RadioInterception.isChannelRegistered()
    return channelRegistered
end

--- Flush player file store on game save so snapshot data survives exits.
local function onSaveGame()
    local player = getSpecificPlayer(0)
    if player and POS_PlayerFileStore then
        POS_PlayerFileStore.save(player)
        PhobosLib.debug("POS", _TAG, "Player file store flushed on save")
    end
end

--- Initialise radio interception hooks.
function POS_RadioInterception.init()
    POS_RadioInterception.registerChannels()
    Events.OnServerCommand.Add(onServerCommand)
    Events.OnPostSave.Add(onSaveGame)

    -- Initial market snapshot request deferred to first EveryOneMinute tick.
    -- Requesting at frame 0 triggers synchronous data exchange during init
    -- when the engine is already under heavy load from ~200 mods booting.

    PhobosLib.debug("POS", _TAG, "Radio interception initialised")
end

--- Deferred initial market snapshot request (MP clients only).
--- Runs once on the first EveryOneMinute tick after game start.
local snapshotRequested = false
local function onDeferredSnapshotRequest()
    if snapshotRequested then return end
    snapshotRequested = true
    local player = getSpecificPlayer(0)
    if player and POS_WorldState and not POS_WorldState.isAuthority() then
        sendClientCommand(player, POS_Constants.CMD_MODULE,
            POS_Constants.CMD_REQUEST_MARKET_SNAPSHOT, {})
        PhobosLib.debug("POS", _TAG, "Deferred market snapshot requested")
    end
end

Events.OnGameStart.Add(function()
    POS_RadioInterception.init()
    Events.EveryOneMinute.Add(onDeferredSnapshotRequest)

    -- Pre-warm the player file store cache so that watchlist/alerts
    -- screens never trigger getFileReader during a UI render frame.
    -- File I/O during OnGameStart is safe (DRJ confirms this pattern).
    -- File I/O during screen.create() crashes the JVM silently.
    local player = getSpecificPlayer(0)
    if player then
        POS_PlayerFileStore.load(player)
        PhobosLib.debug("POS", _TAG, "Player file store cache warmed")
    end
end)
