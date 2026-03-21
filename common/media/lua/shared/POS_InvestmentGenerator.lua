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
-- POS_InvestmentGenerator.lua
-- Server-side investment opportunity generation with risk formulas.
--
-- Generates investment opportunities with procedural NPC posters,
-- risk calculations, and return multipliers. All parameters are
-- sandbox-controllable.
--
-- Risk formulas:
--   baseRisk = lerp(MinBaseRisk, MaxBaseRisk, t) where t is payback normalised
--   actualRisk = clamp(baseRisk * (1 + randFloat(-RandomRiskPct, +RandomRiskPct)), 0.01, 0.95)
--   displayedRisk = clamp(actualRisk * (1 + randFloat(-ObfuscationPct, +ObfuscationPct)), 0.01, 0.99)
--   returnMultiplier = lerp(MinReturn, MaxReturn, t) + randFloat(-0.1, 0.1)
---------------------------------------------------------------

require "PhobosLib"

POS_InvestmentGenerator = {}

local _TAG = "[POS:InvGen]"

--- Investment description template keys (translation keys).
--- Each maps to a short flavour blurb shown in the BBS post.
local DESCRIPTION_KEYS = {
    "UI_POS_BBS_InvDesc_TradeRoute",
    "UI_POS_BBS_InvDesc_ScrapMetal",
    "UI_POS_BBS_InvDesc_FuelRun",
    "UI_POS_BBS_InvDesc_MedicalSupply",
    "UI_POS_BBS_InvDesc_FarmExpansion",
    "UI_POS_BBS_InvDesc_WaterPurification",
    "UI_POS_BBS_InvDesc_ToolSmithing",
    "UI_POS_BBS_InvDesc_RadioParts",
    "UI_POS_BBS_InvDesc_Ammunition",
    "UI_POS_BBS_InvDesc_ShelterRepair",
}

--- Principal amount brackets for investment tiers.
--- Each entry: { min, max } (inclusive).
local PRINCIPAL_BRACKETS = {
    { min = 50,  max = 200 },
    { min = 100, max = 500 },
    { min = 200, max = 1000 },
    { min = 500, max = 2000 },
}

---------------------------------------------------------------
-- Utility
---------------------------------------------------------------

--- Clamp a value between min and max.
local function clamp(value, minVal, maxVal)
    if value < minVal then return minVal end
    if value > maxVal then return maxVal end
    return value
end

--- Linear interpolation between a and b by factor t (0–1).
local function lerp(a, b, t)
    return a + (b - a) * t
end

--- Variance range applied to the return multiplier.
local RETURN_VARIANCE = 0.1

--- Minimum floor for the return multiplier (always at least 10% profit).
local MIN_RETURN_MULTIPLIER = 1.1

--- Generate a random float between min and max using ZombRand.
--- ZombRand(n) returns integer [0, n). We use a large range for precision.
local function randFloat(minVal, maxVal)
    local precision = 10000
    local raw = ZombRand(precision) / precision  -- [0, 1)
    return minVal + raw * (maxVal - minVal)
end

---------------------------------------------------------------
-- Risk calculation
---------------------------------------------------------------

--- Calculate risk and return parameters for a given payback period.
---@param paybackDays number The payback period in game days
---@return table { actualRisk, displayedRisk, returnMultiplier }
function POS_InvestmentGenerator.calculateRisk(paybackDays)
    local minPayback = POS_Sandbox.getInvestmentMinPaybackDays()
    local maxPayback = POS_Sandbox.getInvestmentMaxPaybackDays()
    local minBaseRisk = POS_Sandbox.getInvestmentMinBaseRisk() / 100
    local maxBaseRisk = POS_Sandbox.getInvestmentMaxBaseRisk() / 100
    local randomRiskPct = POS_Sandbox.getInvestmentRandomRiskPct() / 100
    local obfuscationPct = POS_Sandbox.getInvestmentObfuscationPct() / 100
    local minReturn = POS_Sandbox.getInvestmentMinReturn() / 100
    local maxReturn = POS_Sandbox.getInvestmentMaxReturn() / 100

    -- Normalise payback within range (t = 0 at min, 1 at max)
    local range = maxPayback - minPayback
    local t = 0.5
    if range > 0 then
        t = clamp((paybackDays - minPayback) / range, 0, 1)
    end

    -- Base risk: linear interpolation by payback period
    local baseRisk = lerp(minBaseRisk, maxBaseRisk, t)

    -- Actual risk: multiplicative random variance
    local randomFactor = 1.0 + randFloat(-randomRiskPct, randomRiskPct)
    local actualRisk = clamp(baseRisk * randomFactor, 0.01, 0.95)

    -- Displayed risk: obfuscated value shown to the player
    local obfuscationFactor = 1.0 + randFloat(-obfuscationPct, obfuscationPct)
    local displayedRisk = clamp(actualRisk * obfuscationFactor, 0.01, 0.99)

    -- Return multiplier: higher risk → higher reward
    local baseReturn = lerp(minReturn, maxReturn, t)
    local variance = POS_Sandbox and POS_Sandbox.getInvestmentReturnVariance
        and POS_Sandbox.getInvestmentReturnVariance() or RETURN_VARIANCE
    local minRet = POS_Sandbox and POS_Sandbox.getInvestmentMinReturnPct
        and POS_Sandbox.getInvestmentMinReturnPct() or MIN_RETURN_MULTIPLIER
    local returnMultiplier = baseReturn + randFloat(-variance, variance)
    returnMultiplier = math.max(minRet, returnMultiplier)

    return {
        actualRisk = actualRisk,
        displayedRisk = displayedRisk,
        returnMultiplier = returnMultiplier,
    }
end

---------------------------------------------------------------
-- Opportunity generation
---------------------------------------------------------------

--- Generate a new investment opportunity.
--- Called by POS_BroadcastSystem on timer tick.
---@return table|nil Investment opportunity data, or nil on failure
function POS_InvestmentGenerator.generate()
    if not POS_Sandbox.isInvestmentEnabled() then
        return nil
    end

    local gameTime = getGameTime()
    if not gameTime then return nil end
    local currentDay = gameTime:getNightsSurvived()

    -- Generate poster identity via PhobosLib
    local npc = PhobosLib.generateNPCName()

    -- Random payback period within sandbox range
    local minPayback = POS_Sandbox.getInvestmentMinPaybackDays()
    local maxPayback = POS_Sandbox.getInvestmentMaxPaybackDays()
    local paybackDays = minPayback + ZombRand(maxPayback - minPayback + 1)

    -- Calculate risk parameters
    local risk = POS_InvestmentGenerator.calculateRisk(paybackDays)

    -- Select principal bracket (weighted towards middle ranges)
    local bracket = PRINCIPAL_BRACKETS[ZombRand(#PRINCIPAL_BRACKETS) + 1]
    local principalMin = bracket.min
    local principalMax = bracket.max

    -- Select random description
    local descKey = DESCRIPTION_KEYS[ZombRand(#DESCRIPTION_KEYS) + 1]

    -- Expiry window: 7 days from creation
    local expiryDay = currentDay + 7

    local opportunity = {
        id = "POS_INV_" .. tostring(getTimestampMs()),
        posterName = npc.displayName,
        posterHandle = npc.handle,
        descriptionKey = descKey,
        principalMin = principalMin,
        principalMax = principalMax,
        returnMultiplier = math.floor(risk.returnMultiplier * 100) / 100,  -- 2 decimal places
        paybackDays = paybackDays,
        actualRisk = math.floor(risk.actualRisk * 1000) / 1000,            -- 3 decimal places
        displayedRisk = math.floor(risk.displayedRisk * 1000) / 1000,
        createdDay = currentDay,
        expiryDay = expiryDay,
        status = POS_Constants.OPP_STATUS_OPEN,
    }

    PhobosLib.debug("POS", _TAG, "[InvGen] Generated opportunity: " .. opportunity.id
        .. " (poster=" .. npc.displayName
        .. ", payback=" .. paybackDays .. "d"
        .. ", risk=" .. string.format("%.1f%%", risk.actualRisk * 100)
        .. ", return=" .. string.format("%.2fx", risk.returnMultiplier) .. ")")

    return opportunity
end
