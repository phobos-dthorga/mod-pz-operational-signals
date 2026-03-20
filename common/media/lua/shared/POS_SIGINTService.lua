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
-- POS_SIGINTService.lua
-- All SIGINT modifier calculations: confidence, yield, noise,
-- time reduction, tier distribution, false data detection.
-- Pure computation — no direct game state mutation.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_SIGINTSkill"

POS_SIGINTService = {}

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

--- Safe table lookup with level-based index (level+1 for 1-indexed Lua tables).
---@param tbl table Per-level table (indexed 1-11 for levels 0-10)
---@param level number SIGINT level 0-10
---@return any Value at index, or nil
local function lookupByLevel(tbl, level)
    if not tbl then return nil end
    local idx = math.max(1, math.min(level + 1, #tbl))
    return tbl[idx]
end

--- Apply sandbox noise reduction scaling.
--- Sandbox enum: 1=None, 2=Low, 3=Standard, 4=High.
---@param baseValue number Raw noise filter percentage
---@return number Scaled value
local function applyNoiseScaling(baseValue)
    local setting = POS_Sandbox and POS_Sandbox.getSIGINTNoiseReduction
        and POS_Sandbox.getSIGINTNoiseReduction() or 3
    if setting == 1 then return 0 end       -- None
    if setting == 2 then return baseValue * 0.5 end  -- Low
    if setting == 4 then return math.min(baseValue * 1.5, 100) end  -- High
    return baseValue                         -- Standard (3)
end

--- Apply sandbox confidence bonus scaling.
--- Sandbox enum: 1=None, 2=Low, 3=Standard, 4=High.
---@param baseValue number Raw confidence bonus
---@return number Scaled value
local function applyConfidenceScaling(baseValue)
    local setting = POS_Sandbox and POS_Sandbox.getSIGINTConfidenceBonus
        and POS_Sandbox.getSIGINTConfidenceBonus() or 3
    if setting == 1 then return 0 end        -- None
    if setting == 2 then return math.floor(baseValue * 0.5) end  -- Low
    if setting == 4 then return math.floor(baseValue * 1.5) end  -- High
    return baseValue                          -- Standard (3)
end

---------------------------------------------------------------
-- Confidence
---------------------------------------------------------------

--- Get the SIGINT confidence bonus for a given player.
--- Applied as flat additive bonus to all intelligence artifacts.
---@param player IsoPlayer
---@return number Confidence bonus (0+ integer)
function POS_SIGINTService.getConfidenceBonus(player)
    if not POS_SIGINTSkill.isAvailable() then return 0 end
    local level = POS_SIGINTSkill.getLevel(player)
    local base = lookupByLevel(POS_Constants.SIGINT_CONFIDENCE_PER_LEVEL, level) or 0
    return applyConfidenceScaling(base)
end

--- Get the field-level confidence bonus (minimal effect: +1 per 3 levels, cap +3).
--- Used by POS_MarketReconAction for manual note-taking.
---@param player IsoPlayer
---@return number Confidence bonus (0-3)
function POS_SIGINTService.getFieldConfidenceBonus(player)
    if not POS_SIGINTSkill.isAvailable() then return 0 end
    local level = POS_SIGINTSkill.getLevel(player)
    local bonus = math.floor(level / POS_Constants.SIGINT_FIELD_CONFIDENCE_DIVISOR)
    return math.min(bonus, POS_Constants.SIGINT_FIELD_CONFIDENCE_CAP)
end

---------------------------------------------------------------
-- Noise Filter
---------------------------------------------------------------

--- Get the noise filter percentage for a given player.
--- Represents chance of suppressing junk/misleading outputs.
---@param player IsoPlayer
---@return number Noise filter percentage (0-100)
function POS_SIGINTService.getNoiseFilter(player)
    if not POS_SIGINTSkill.isAvailable() then return 0 end
    local level = POS_SIGINTSkill.getLevel(player)
    local base = lookupByLevel(POS_Constants.SIGINT_NOISE_FILTER_PER_LEVEL, level) or 0

    -- Apply trait noise penalty (Disorganised Thinker)
    if POS_SIGINTTraits and POS_SIGINTTraits.getNoisePenalty then
        local penalty = POS_SIGINTTraits.getNoisePenalty(player)
        base = math.max(0, base - (base * penalty))
    end

    return applyNoiseScaling(base)
end

---------------------------------------------------------------
-- Time Reduction
---------------------------------------------------------------

--- Get the time reduction percentage for Terminal Analysis.
--- Returns 0 if sandbox option disables time reduction.
---@param player IsoPlayer
---@return number Time reduction percentage (0-100)
function POS_SIGINTService.getTimeReduction(player)
    if not POS_SIGINTSkill.isAvailable() then return 0 end

    -- Sandbox gate
    local enabled = POS_Sandbox and POS_Sandbox.getSIGINTTimeReduction
        and POS_Sandbox.getSIGINTTimeReduction()
    if enabled == false then return 0 end

    local level = POS_SIGINTSkill.getLevel(player)
    local base = lookupByLevel(POS_Constants.SIGINT_TIME_REDUCTION_PER_LEVEL, level) or 0

    -- Apply Impatient trait penalty (time takes longer, so less reduction)
    if POS_SIGINTTraits and POS_SIGINTTraits.getTimePenalty then
        local penalty = POS_SIGINTTraits.getTimePenalty(player)
        if penalty > 0 then
            -- Reduce the time reduction by the penalty amount
            base = math.max(0, base - (penalty * 100))
        end
    end

    return base
end

--- Calculate the effective action time given a base duration and player.
---@param player IsoPlayer
---@param baseDuration number Base action time in seconds
---@return number Effective duration in seconds (never below 25% of base)
function POS_SIGINTService.calculateEffectiveTime(player, baseDuration)
    local reduction = POS_SIGINTService.getTimeReduction(player)
    local factor = math.max(0.25, 1.0 - (reduction / 100))

    -- Apply Impatient trait: adds time penalty directly
    if POS_SIGINTTraits and POS_SIGINTTraits.getTimePenalty then
        local penalty = POS_SIGINTTraits.getTimePenalty(player)
        if penalty > 0 then
            factor = factor + penalty
        end
    end

    return math.max(1, math.floor(baseDuration * factor))
end

---------------------------------------------------------------
-- Yield
---------------------------------------------------------------

--- Get the analysis yield range for a given player.
---@param player IsoPlayer
---@return number min, number max
function POS_SIGINTService.getYieldRange(player)
    if not POS_SIGINTSkill.isAvailable() then return 1, 1 end
    local level = POS_SIGINTSkill.getLevel(player)
    local range = lookupByLevel(POS_Constants.SIGINT_YIELD_PER_LEVEL, level)
    if range then
        return range[1], range[2]
    end
    return 1, 1
end

--- Roll the actual yield count within the player's range.
---@param player IsoPlayer
---@return number Fragment count
function POS_SIGINTService.rollYield(player)
    local minY, maxY = POS_SIGINTService.getYieldRange(player)
    if minY == maxY then return minY end
    return ZombRand(minY, maxY + 1)
end

---------------------------------------------------------------
-- Cross-Correlation
---------------------------------------------------------------

--- Whether the player has unlocked cross-correlation.
--- Respects Systems Thinker trait (lowers threshold to L4).
---@param player IsoPlayer
---@return boolean
function POS_SIGINTService.hasCrossCorrelation(player)
    if not POS_SIGINTSkill.isAvailable() then return false end

    local level = POS_SIGINTSkill.getLevel(player)

    -- Systems Thinker trait overrides the threshold
    if POS_SIGINTTraits and POS_SIGINTTraits.getCrossCorrelationLevel then
        local traitLevel = POS_SIGINTTraits.getCrossCorrelationLevel(player)
        if traitLevel then
            return level >= traitLevel
        end
    end

    -- Sandbox-configurable threshold
    local threshold = POS_Sandbox and POS_Sandbox.getSIGINTCrossCorrelationLevel
        and POS_Sandbox.getSIGINTCrossCorrelationLevel()
        or POS_Constants.SIGINT_CROSS_CORRELATION_LEVEL
    return level >= threshold
end

---------------------------------------------------------------
-- False Data Detection
---------------------------------------------------------------

--- Whether the player can detect false/contradictory data.
--- Unlocked at SIGINT level 8+.
---@param player IsoPlayer
---@return boolean
function POS_SIGINTService.hasFalseDataDetection(player)
    if not POS_SIGINTSkill.isAvailable() then return false end
    local level = POS_SIGINTSkill.getLevel(player)
    return level >= POS_Constants.SIGINT_FALSE_DATA_DETECTION_LEVEL
end

---------------------------------------------------------------
-- Broadcast Credibility (Satellite — tertiary influence)
---------------------------------------------------------------

--- Get the broadcast credibility modifier for satellite uplink.
--- Higher SIGINT = stronger market impact per broadcast.
---@param player IsoPlayer
---@return number Credibility factor (0.0-1.0, added to base 1.0)
function POS_SIGINTService.getBroadcastCredibility(player)
    if not POS_SIGINTSkill.isAvailable() then return 0 end
    local level = POS_SIGINTSkill.getLevel(player)
    -- 1% per SIGINT level, max 10%
    return math.min(level * 0.01, 0.10)
end

---------------------------------------------------------------
-- Camera Verification Strength (Camera — secondary influence)
---------------------------------------------------------------

--- Get the verification strength modifier for camera compilation.
--- +1% per SIGINT level to final confidence multiplier, max +10%.
---@param player IsoPlayer
---@return number Verification modifier (0.0-0.10)
function POS_SIGINTService.getVerificationStrength(player)
    if not POS_SIGINTSkill.isAvailable() then return 0 end
    local level = POS_SIGINTSkill.getLevel(player)
    return math.min(level * 0.01, 0.10)
end

---------------------------------------------------------------
-- Qualitative Tier
---------------------------------------------------------------

--- Get the qualitative tier index for the given level.
--- 0 = Noise Drowner, 1 = Pattern Seeker, 2 = Analyst, 3 = Intel Operator
---@param level number SIGINT level 0-10
---@return number Tier index (0-3)
function POS_SIGINTService.getTierIndex(level)
    if level >= POS_Constants.SIGINT_TIER_INTEL_OPERATOR then return 3 end
    if level >= POS_Constants.SIGINT_TIER_ANALYST then return 2 end
    if level >= POS_Constants.SIGINT_TIER_PATTERN_SEEKER then return 1 end
    return 0
end
