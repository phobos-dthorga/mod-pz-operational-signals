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

POS_RadioInterception = {}

--- Whether the POSnet channel has been registered.
local channelRegistered = false

--- Register the POSnet radio channel with PZ's radio system.
--- Called via OnLoadRadioScripts event.
--- @param scriptManager any PZ RadioScriptManager
--- @param isNewGame boolean True if this is a new game
function POS_RadioInterception.onLoadRadioScripts(scriptManager, isNewGame)
    if channelRegistered then return end
    if not scriptManager then return end

    local freq = POS_Sandbox.getPOSnetFrequency()

    local channel = scriptManager:AddChannel("POSnet", freq)
    if channel then
        channel:SetCategory("Military")
        PhobosLib.debug("POS", "POSnet channel registered at " .. tostring(freq) .. " Hz")
        channelRegistered = true
    else
        PhobosLib.debug("POS", "Failed to register POSnet channel at " .. tostring(freq) .. " Hz")
    end
end

--- Handle an incoming POSnet transmission from the server.
--- Routes operation data to the Operation Log.
--- @param transmission table Transmission data with operationData field
function POS_RadioInterception.onTransmissionReceived(transmission)
    if not transmission then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    PhobosLib.debug("POS", "Transmission received")

    if transmission.operationData and POS_OperationLog then
        local added = POS_OperationLog.addOperation(transmission.operationData)
        if added then
            PhobosLib.debug("POS", "Operation added: " .. (transmission.operationData.id or "?"))
        end
    end
end

--- Handle server commands sent to the POS module.
--- @param module string Command module name
--- @param command string Command name
--- @param args table Command arguments
local function onServerCommand(module, command, args)
    if module ~= "POS" then return end

    if command == "NewOperation" and args and args.operationData then
        POS_RadioInterception.onTransmissionReceived(args)
    end
end

--- Request a new operation from the server (future use).
function POS_RadioInterception.requestOperation()
    local player = getSpecificPlayer(0)
    if player then
        sendClientCommand(player, "POS", "RequestOperation", {})
    end
end

--- Check whether the POSnet channel is registered.
--- @return boolean
function POS_RadioInterception.isChannelRegistered()
    return channelRegistered
end

--- Initialise radio interception hooks.
function POS_RadioInterception.init()
    Events.OnLoadRadioScripts.Add(POS_RadioInterception.onLoadRadioScripts)
    Events.OnServerCommand.Add(onServerCommand)
    PhobosLib.debug("POS", "Radio interception initialised")
end

Events.OnGameStart.Add(POS_RadioInterception.init)
