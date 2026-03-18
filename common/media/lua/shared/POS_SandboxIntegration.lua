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

function POS_Sandbox.getDeliveryExpiryDays()
    return PhobosLib.getSandboxVar("POS", "DeliveryExpiryDays", 3)
end

function POS_Sandbox.getInitialScanRadius()
    return PhobosLib.getSandboxVar("POS", "InitialScanRadius", 250)
end

function POS_Sandbox.getPassiveScanRadius()
    return PhobosLib.getSandboxVar("POS", "PassiveScanRadius", 50)
end

--- Returns variance as float (sandbox stores as integer 0-30 %).
function POS_Sandbox.getInvestmentReturnVariance()
    local pct = PhobosLib.getSandboxVar("POS", "InvestmentReturnVariance", 10)
    return pct / 100
end

--- Returns min return as float (sandbox stores as integer 100-150 %).
function POS_Sandbox.getInvestmentMinReturnPct()
    local pct = PhobosLib.getSandboxVar("POS", "InvestmentMinReturnPct", 110)
    return pct / 100
end

--- POSnet frequency — now delegated to AZAS integration.
--- Returns the operations band frequency (backward compat).
function POS_Sandbox.getPOSnetFrequency()
    if POS_AZASIntegration and POS_AZASIntegration.getFrequency then
        return POS_AZASIntegration.getFrequency()
    end
    return 130000
end

---------------------------------------------------------------
-- Signal strength sandbox accessors
---------------------------------------------------------------

function POS_Sandbox.isSignalStrengthEnabled()
    return PhobosLib.getSandboxVar("POS", "EnableSignalStrength", true)
end

function POS_Sandbox.getSignalReferencePower()
    return PhobosLib.getSandboxVar("POS", "SignalReferencePower", 10000)
end

--- Returns threshold as 0.0–0.5 (sandbox stores as integer 0–50).
function POS_Sandbox.getMinSignalThreshold()
    local pct = PhobosLib.getSandboxVar("POS", "MinSignalThreshold", 15)
    return pct / 100
end

--- Whether signal strength affects mission distance/quality (placeholder).
function POS_Sandbox.isSignalAffectsMissionRange()
    return PhobosLib.getSandboxVar("POS", "SignalAffectsMissionRange", true)
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

---------------------------------------------------------------
-- Panel visibility sandbox accessors
---------------------------------------------------------------

--- Whether the persistent navigation sidebar is shown.
function POS_Sandbox.getEnableNavPanel()
    return PhobosLib.getSandboxVar("POS", "EnableNavPanel", true)
end

--- Whether the context detail panel is shown.
function POS_Sandbox.getEnableContextPanel()
    return PhobosLib.getSandboxVar("POS", "EnableContextPanel", true)
end

--- Returns terminal power drain rate as float (sandbox stores as integer hundredths).
--- 15 → 0.15 %/min. 0 disables drain entirely.
function POS_Sandbox.getTerminalPowerDrainRate()
    local pct = PhobosLib.getSandboxVar("POS", "TerminalPowerDrainRate", 15)
    return pct / 100
end

---------------------------------------------------------------
-- Market / exchange sandbox accessors
---------------------------------------------------------------

function POS_Sandbox.getEnableMarkets()
    return PhobosLib.getSandboxVar("POS", "EnableMarkets", true)
end

function POS_Sandbox.getEnableExchange()
    return PhobosLib.getSandboxVar("POS", "EnableExchange", false)
end

function POS_Sandbox.getIntelFreshnessDecayDays()
    return PhobosLib.getSandboxVar("POS", "IntelFreshnessDecayDays", 14)
end

function POS_Sandbox.getMarketBroadcastInterval()
    return PhobosLib.getSandboxVar("POS", "MarketBroadcastInterval", 120)
end

function POS_Sandbox.getMarketNoteActionTime()
    return PhobosLib.getSandboxVar("POS", "MarketNoteActionTime", 300)
end

function POS_Sandbox.getEnableMarketBroadcasts()
    return PhobosLib.getSandboxVar("POS", "EnableMarketBroadcasts", true)
end

function POS_Sandbox.getMarketBroadcastQuality()
    return PhobosLib.getSandboxVar("POS", "MarketBroadcastQuality", 50)
end

---------------------------------------------------------------
-- Item selection & category weighting sandbox accessors
---------------------------------------------------------------

function POS_Sandbox.getEnableCategoryWeighting()
    return PhobosLib.getSandboxVar("POS", "EnableCategoryWeighting", true)
end

function POS_Sandbox.getEnableItemLevelIntel()
    return PhobosLib.getSandboxVar("POS", "EnableItemLevelIntel", true)
end

function POS_Sandbox.getItemSelectionPoolSize()
    return PhobosLib.getSandboxVar("POS", "ItemSelectionPoolSize", 3)
end

function POS_Sandbox.getBroadcastItemsPerPacket()
    return PhobosLib.getSandboxVar("POS", "BroadcastItemsPerPacket", 2)
end

function POS_Sandbox.getReputationAffectsVariance()
    return PhobosLib.getSandboxVar("POS", "ReputationAffectsVariance", true)
end

function POS_Sandbox.getDailyPriceDriftPct()
    return PhobosLib.getSandboxVar("POS", "DailyPriceDriftPct", 2)
end

function POS_Sandbox.getEssentialGoodsPriority()
    return PhobosLib.getSandboxVar("POS", "EssentialGoodsPriority", true)
end

--- Returns fuel category weight as float (sandbox stores as integer, ÷100).
function POS_Sandbox.getWeightFuel()
    return PhobosLib.getSandboxVar("POS", "WeightFuel", 150) / 100
end

function POS_Sandbox.getWeightMedicine()
    return PhobosLib.getSandboxVar("POS", "WeightMedicine", 140) / 100
end

function POS_Sandbox.getWeightFood()
    return PhobosLib.getSandboxVar("POS", "WeightFood", 100) / 100
end

function POS_Sandbox.getWeightAmmunition()
    return PhobosLib.getSandboxVar("POS", "WeightAmmunition", 130) / 100
end

function POS_Sandbox.getWeightTools()
    return PhobosLib.getSandboxVar("POS", "WeightTools", 90) / 100
end

function POS_Sandbox.getWeightRadio()
    return PhobosLib.getSandboxVar("POS", "WeightRadio", 60) / 100
end

function POS_Sandbox.getPortableDrainDivisor()
    return PhobosLib.getSandboxVar("POS", "PortableBatteryDivisor", 1800)
end

---------------------------------------------------------------
-- Persistence & economy tick
---------------------------------------------------------------

function POS_Sandbox.getMaxObservationsPerCategory()
    return PhobosLib.getSandboxVar("POS", "MaxObservationsPerCategory", 24)
end

function POS_Sandbox.getMaxRollingCloses()
    return PhobosLib.getSandboxVar("POS", "MaxRollingCloses", 14)
end

function POS_Sandbox.getMaxGlobalEvents()
    return PhobosLib.getSandboxVar("POS", "MaxGlobalEvents", 100)
end

function POS_Sandbox.getMaxPlayerAlerts()
    return PhobosLib.getSandboxVar("POS", "MaxPlayerAlerts", 20)
end

function POS_Sandbox.getEconomyTickEnabled()
    return PhobosLib.getSandboxVar("POS", "EconomyTickEnabled", true)
end

function POS_Sandbox.getEnableEventLogs()
    return PhobosLib.getSandboxVar("POS", "EnableEventLogs", true)
end

function POS_Sandbox.getEventLogRetentionDays()
    return PhobosLib.getSandboxVar("POS", "EventLogRetentionDays", 30)
end

---------------------------------------------------------------
-- Passive recon devices
---------------------------------------------------------------

function POS_Sandbox.getEnablePassiveRecon()
    return PhobosLib.getSandboxVar("POS", "EnablePassiveRecon", true)
end

function POS_Sandbox.getPassiveReconInterval()
    return PhobosLib.getSandboxVar("POS", "PassiveReconInterval", 60)
end

function POS_Sandbox.getCamcorderScanRadius()
    return PhobosLib.getSandboxVar("POS", "CamcorderScanRadius", 40)
end

function POS_Sandbox.getLoggerScanRadius()
    return PhobosLib.getSandboxVar("POS", "LoggerScanRadius", 25)
end

function POS_Sandbox.getVHSTapeMinDays()
    return PhobosLib.getSandboxVar("POS", "VHSTapeMinDays", 3)
end

function POS_Sandbox.getCamcorderNoiseLevel()
    return PhobosLib.getSandboxVar("POS", "CamcorderNoiseLevel", 5)
end

function POS_Sandbox.getTapeDegradationRate()
    return PhobosLib.getSandboxVar("POS", "TapeDegradationRate", 10)
end

function POS_Sandbox.getCalculatorConfidenceBonus()
    return PhobosLib.getSandboxVar("POS", "CalculatorConfidenceBonus", 5)
end

function POS_Sandbox.getEnableVHSCrafting()
    return PhobosLib.getSandboxVar("POS", "EnableVHSCrafting", true)
end

function POS_Sandbox.getEnableForagingTapes()
    return PhobosLib.getSandboxVar("POS", "EnableForagingTapes", true)
end

---------------------------------------------------------------
-- Intel gathering cooldown
---------------------------------------------------------------

function POS_Sandbox.getIntelCooldownDays()
    return PhobosLib.getSandboxVar("POS", "IntelCooldownDays", 12)
end
