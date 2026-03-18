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

---------------------------------------------------------------
-- Reputation & reward sandbox accessors
---------------------------------------------------------------

function POS_Sandbox.isReconEnabled()
    return PhobosLib.getSandboxVar("POS", "EnableReconMissions", true)
end

function POS_Sandbox.getReputationCap()
    return PhobosLib.getSandboxVar("POS", "ReputationCap", 2500)
end

function POS_Sandbox.getReputationMultiplier()
    return PhobosLib.getSandboxVar("POS", "ReputationMultiplier", 100)
end

function POS_Sandbox.getRewardMultiplier()
    return PhobosLib.getSandboxVar("POS", "RewardMultiplier", 100)
end

function POS_Sandbox.getTierIIReputationReq()
    return PhobosLib.getSandboxVar("POS", "TierIIReputationReq", 250)
end

function POS_Sandbox.getTierIIIReputationReq()
    return PhobosLib.getSandboxVar("POS", "TierIIIReputationReq", 750)
end

function POS_Sandbox.getTierIVReputationReq()
    return PhobosLib.getSandboxVar("POS", "TierIVReputationReq", 1500)
end

function POS_Sandbox.getExpiryReputationPenalty()
    return PhobosLib.getSandboxVar("POS", "ExpiryReputationPenalty", 25)
end

function POS_Sandbox.getInvestmentRepPerHundred()
    return PhobosLib.getSandboxVar("POS", "InvestmentRepPerHundred", 10)
end

function POS_Sandbox.getWritingDamageChance()
    return PhobosLib.getSandboxVar("POS", "WritingDamageChance", 20)
end

function POS_Sandbox.getWritingDamageAmount()
    return PhobosLib.getSandboxVar("POS", "WritingDamageAmount", 7)
end

---------------------------------------------------------------
-- Negotiation sandbox accessors
---------------------------------------------------------------

function POS_Sandbox.isNegotiationEnabled()
    return PhobosLib.getSandboxVar("POS", "EnableNegotiation", true)
end

function POS_Sandbox.getNegotiationSuccessBonus()
    return PhobosLib.getSandboxVar("POS", "NegotiationSuccessBonus", 0)
end

---------------------------------------------------------------
-- Cancellation sandbox accessors
---------------------------------------------------------------

function POS_Sandbox.isCancellationPenaltyEnabled()
    return PhobosLib.getSandboxVar("POS", "EnableCancellationPenalty", true)
end

function POS_Sandbox.getBaseCancelPenalty()
    return PhobosLib.getSandboxVar("POS", "BaseCancelPenalty", 30)
end

function POS_Sandbox.getBaseCancelPenaltyDelivery()
    return PhobosLib.getSandboxVar("POS", "BaseCancelPenaltyDelivery", 15)
end

---------------------------------------------------------------
-- Terminal theme sandbox accessors
---------------------------------------------------------------

--- Font size: 1=Small, 2=Medium, 3=Code, 4=Large.
function POS_Sandbox.getTerminalFontSize()
    return PhobosLib.getSandboxVar("POS", "TerminalFontSize", 3)
end

--- Colour theme: 1=Classic Green, 2=Amber, 3=Cool White, 4=IBM Blue.
function POS_Sandbox.getTerminalColourTheme()
    return PhobosLib.getSandboxVar("POS", "TerminalColourTheme", 1)
end

--- Whether to scale font size with window width.
function POS_Sandbox.isFontScaleWithWindow()
    return PhobosLib.getSandboxVar("POS", "FontScaleWithWindow", false)
end
