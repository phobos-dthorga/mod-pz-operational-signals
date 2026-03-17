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
-- transmissions and routes them to the Operation Log.
--
-- The POSnet channel appears in the player's radio UI when
-- tuned to the configured frequency (default 91.5 MHz).
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

--- Handle an incoming POSnet transmission.
--- Called when the broadcast system delivers a message to this client.
--- @param transmission table Transmission data with message, category, etc.
function POS_RadioInterception.onTransmissionReceived(transmission)
    if not transmission then return end

    -- Check if player is listening on the POSnet frequency
    local player = getSpecificPlayer(0)
    if not player then return end

    local freq = POS_Sandbox.getPOSnetFrequency()
    local radio = ZomboidRadio.getInstance()
    if not radio then return end

    if not radio:PlayerListensChannel(freq) then
        PhobosLib.debug("POS", "Player not tuned to POSnet — ignoring transmission")
        return
    end

    PhobosLib.debug("POS", "Transmission received: " .. (transmission.message or "?"))

    -- Route to operation log if it contains operation data
    if transmission.operationData and POS_OperationLog then
        POS_OperationLog.addOperation(transmission.operationData)
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
    PhobosLib.debug("POS", "Radio interception initialised")
end

Events.OnGameStart.Add(POS_RadioInterception.init)
