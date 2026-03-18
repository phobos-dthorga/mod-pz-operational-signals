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

---------------------------------------------------------------
-- Investment sandbox accessors
---------------------------------------------------------------

function POS_Sandbox.isInvestmentEnabled()
    return PhobosLib.getSandboxVar("POS", "EnableInvestments", true)
end

function POS_Sandbox.getInvestmentMinPaybackDays()
    return PhobosLib.getSandboxVar("POS", "InvestmentMinPaybackDays", 14)
end

function POS_Sandbox.getInvestmentMaxPaybackDays()
    return PhobosLib.getSandboxVar("POS", "InvestmentMaxPaybackDays", 90)
end

function POS_Sandbox.getInvestmentMinBaseRisk()
    return PhobosLib.getSandboxVar("POS", "InvestmentMinBaseRisk", 20)
end

function POS_Sandbox.getInvestmentMaxBaseRisk()
    return PhobosLib.getSandboxVar("POS", "InvestmentMaxBaseRisk", 35)
end

function POS_Sandbox.getInvestmentRandomRiskPct()
    return PhobosLib.getSandboxVar("POS", "InvestmentRandomRiskPct", 15)
end

function POS_Sandbox.getInvestmentObfuscationPct()
    return PhobosLib.getSandboxVar("POS", "InvestmentObfuscationPct", 33)
end

function POS_Sandbox.getInvestmentMinReturn()
    return PhobosLib.getSandboxVar("POS", "InvestmentMinReturn", 130)
end

function POS_Sandbox.getInvestmentMaxReturn()
    return PhobosLib.getSandboxVar("POS", "InvestmentMaxReturn", 250)
end

function POS_Sandbox.getMaxActiveInvestments()
    return PhobosLib.getSandboxVar("POS", "MaxActiveInvestments", 5)
end

function POS_Sandbox.getInvestmentBroadcastMins()
    return PhobosLib.getSandboxVar("POS", "InvestmentBroadcastMins", 60)
end

---------------------------------------------------------------
-- Delivery mission sandbox accessors
---------------------------------------------------------------

function POS_Sandbox.isDeliveryEnabled()
    return PhobosLib.getSandboxVar("POS", "EnableDeliveryMissions", true)
end

function POS_Sandbox.getMinDeliveryDistance()
    return PhobosLib.getSandboxVar("POS", "MinDeliveryDistance", 4400)
end

function POS_Sandbox.getMaxDeliveryDistance()
    return PhobosLib.getSandboxVar("POS", "MaxDeliveryDistance", 11000)
end

--- Returns road factor as a float (sandbox stores as integer percentage).
function POS_Sandbox.getDeliveryRoadFactor()
    local pct = PhobosLib.getSandboxVar("POS", "DeliveryRoadFactor", 130)
    return pct / 100
end
