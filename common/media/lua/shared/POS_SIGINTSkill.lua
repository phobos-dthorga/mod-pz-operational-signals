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
-- POS_SIGINTSkill.lua
-- Perk registration and level access for the SIGINT skill.
-- Registration only — all calculations in POS_SIGINTService.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_SIGINTSkill = {}

local _TAG = "[POS:SIGINT]"

--- Cached PerkFactory.Perk enum reference (set on registration).
---@type PerkFactory.Perk|nil
local sigintPerk = nil

--- Whether registration was attempted (prevents double-registration).
local registered = false

---------------------------------------------------------------
-- Registration
---------------------------------------------------------------

--- Resolve the SIGINT perk reference from PerkFactory.
--- The perk itself is registered declaratively via common/media/perks.txt;
--- this function only caches the runtime enum value for getLevel()/addXP().
function POS_SIGINTSkill.register()
    if registered then return end
    registered = true

    -- Guard: ensure PerkFactory is available
    if not PerkFactory or not PerkFactory.Perks then
        PhobosLib.debug("POS", _TAG,
            "PerkFactory not available — SIGINT registration skipped")
        return
    end

    -- Resolve the perk enum value registered by perks.txt
    local ok, result = PhobosLib.safecall(Perks.FromString,
        POS_Constants.SIGINT_PERK_ID)
    if ok and result then
        sigintPerk = result
        PhobosLib.debug("POS", _TAG,
            "SIGINT perk resolved successfully (parent: "
            .. POS_Constants.SIGINT_PERK_PARENT .. ")")
    else
        PhobosLib.debug("POS", _TAG,
            "SIGINT perk not found — perks.txt may not have loaded")
    end
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Get the cached perk enum value for SIGINT.
---@return PerkFactory.Perk|nil
function POS_SIGINTSkill.getPerk()
    return sigintPerk
end

--- Whether the SIGINT perk is registered and available.
---@return boolean
function POS_SIGINTSkill.isAvailable()
    return sigintPerk ~= nil
end

--- Get the player's current SIGINT level (0-10).
--- Returns 0 if perk is not registered or player is nil.
---@param player IsoPlayer
---@return number
function POS_SIGINTSkill.getLevel(player)
    if not sigintPerk or not player then return 0 end
    local ok, level = PhobosLib.safecall(function()
        return PhobosLib.getPerkLevel(player, sigintPerk)
    end)
    if ok and level then
        return math.min(level, POS_Constants.SIGINT_MAX_LEVEL)
    end
    return 0
end

--- Award SIGINT XP to a player.
--- Respects sandbox XP multiplier and trait modifiers.
--- Does NOT scale by current SIGINT level (no runaway progression).
---@param player IsoPlayer
---@param baseAmount number Raw XP amount before modifiers
---@return boolean success
function POS_SIGINTSkill.addXP(player, baseAmount)
    if not sigintPerk or not player or not baseAmount then return false end
    if baseAmount <= 0 then return false end

    -- Apply sandbox multiplier (percentage, default 100)
    local multiplier = POS_Sandbox and POS_Sandbox.getSIGINTXPMultiplier
        and POS_Sandbox.getSIGINTXPMultiplier() or 100
    local scaledAmount = baseAmount * (multiplier / 100)

    -- Apply trait XP modifiers
    if POS_SIGINTTraits and POS_SIGINTTraits.getXPModifier then
        scaledAmount = scaledAmount * POS_SIGINTTraits.getXPModifier(player)
    end

    -- Enforce Signal Blindness cap
    if POS_SIGINTTraits and POS_SIGINTTraits.isLevelCapped then
        local cap = POS_SIGINTTraits.getLevelCap(player)
        local currentLevel = POS_SIGINTSkill.getLevel(player)
        if cap and currentLevel >= cap then
            return false  -- at cap, no more XP
        end
    end

    -- Round to nearest integer (PZ XP system uses integers)
    scaledAmount = math.max(1, math.floor(scaledAmount + 0.5))

    -- Capture level before XP award for tutorial threshold detection
    local levelBefore = POS_SIGINTSkill.getLevel(player)

    local ok = PhobosLib.addXP(player, sigintPerk, scaledAmount)

    -- Track total XP in modData (for ZScience mirror and stats)
    if ok then
        -- Tutorial: check for SIGINT level-up milestones
        local levelAfter = POS_SIGINTSkill.getLevel(player)
        if POS_TutorialService and POS_TutorialService.checkSIGINTLevelUp then
            POS_TutorialService.checkSIGINTLevelUp(player, levelBefore, levelAfter)
        end
        local modData = player:getModData()
        if modData then
            local totalKey = POS_Constants.MODDATA_SIGINT_TOTAL_XP
            modData[totalKey] = (modData[totalKey] or 0) + scaledAmount
        end

        -- Mirror XP to ZScience (optional cross-mod)
        if POS_ZScienceIntegration and POS_ZScienceIntegration.mirrorXP then
            POS_ZScienceIntegration.mirrorXP(player, scaledAmount)
        end
    end

    return ok == true
end

--- Get XP progress toward the next SIGINT level as a percentage (0-100).
--- Returns 100 at max level. Returns 0 if perk is unavailable.
---@param player IsoPlayer
---@return number percentage 0-100
function POS_SIGINTSkill.getLevelProgress(player)
    if not sigintPerk or not player then return 0 end
    local currentLevel = POS_SIGINTSkill.getLevel(player)
    if currentLevel >= POS_Constants.SIGINT_MAX_LEVEL then return 100 end

    local ok, currentXP = PhobosLib.safecall(function()
        return player:getXp():getXP(sigintPerk)
    end)
    if not ok or not currentXP then return 0 end

    local thresholds = POS_Constants.SIGINT_XP_THRESHOLDS
    -- Floor = cumulative XP for current level, ceiling = cumulative for next
    local floor = 0
    for i = 1, currentLevel do
        floor = floor + (thresholds[i] or 0)
    end
    local ceiling = floor + (thresholds[currentLevel + 1] or 1)

    local range = ceiling - floor
    if range <= 0 then return 100 end

    local progress = (currentXP - floor) / range * 100
    return math.max(0, math.min(100, math.floor(progress + 0.5)))
end

--- Get the qualitative tier name key for a given SIGINT level.
---@param level number 0-10
---@return string Translation key for the tier name
function POS_SIGINTSkill.getTierNameKey(level)
    if level >= POS_Constants.SIGINT_TIER_INTEL_OPERATOR then
        return "UI_POS_SIGINT_Tier_IntelOperator"
    elseif level >= POS_Constants.SIGINT_TIER_ANALYST then
        return "UI_POS_SIGINT_Tier_Analyst"
    elseif level >= POS_Constants.SIGINT_TIER_PATTERN_SEEKER then
        return "UI_POS_SIGINT_Tier_PatternSeeker"
    else
        return "UI_POS_SIGINT_Tier_NoiseDrowner"
    end
end

---------------------------------------------------------------
-- Event hook: register on game start
---------------------------------------------------------------

local function onGameStart()
    POS_SIGINTSkill.register()
end

Events.OnGameStart.Add(onGameStart)
