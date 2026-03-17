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
-- POS_SandboxIntegration.lua
-- Sandbox option accessors for POSnet.
-- All getters wrap PhobosLib.getSandboxVar() with defaults.
---------------------------------------------------------------

require "PhobosLib"

POS_Sandbox = {}

function POS_Sandbox.isDebugLoggingEnabled()
    return PhobosLib.getSandboxVar("POS", "EnableDebugLogging", false)
end

function POS_Sandbox.isBroadcastEnabled()
    return PhobosLib.getSandboxVar("POS", "EnableBroadcasts", true)
end

function POS_Sandbox.getBroadcastIntervalMinutes()
    return PhobosLib.getSandboxVar("POS", "BroadcastIntervalMinutes", 30)
end

function POS_Sandbox.getMaxActiveOperations()
    return PhobosLib.getSandboxVar("POS", "MaxActiveOperations", 3)
end

function POS_Sandbox.getOperationExpiryDays()
    return PhobosLib.getSandboxVar("POS", "OperationExpiryDays", 7)
end

function POS_Sandbox.getPOSnetFrequency()
    return PhobosLib.getSandboxVar("POS", "POSnetFrequency", 91500)
end
