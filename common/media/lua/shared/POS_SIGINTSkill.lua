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

--- Cached PerkFactory.Perk enum reference (set on registration).
---@type PerkFactory.Perk|nil
local sigintPerk = nil

--- Whether registration was attempted (prevents double-registration).
local registered = false

---------------------------------------------------------------
-- Registration
---------------------------------------------------------------

--- Register the SIGINT perk with PZ's PerkFactory.
--- Must be called once during game initialisation.
--- Gated by sandbox option POS_Sandbox.getEnableSIGINTSkill().
function POS_SIGINTSkill.register()
    if registered then return end
    registered = true

    -- Sandbox gate
    if POS_Sandbox and POS_Sandbox.getEnableSIGINTSkill
        and not POS_Sandbox.getEnableSIGINTSkill() then
        PhobosLib.debug("POS", "[POS:SIGINT]",
            "SIGINT skill disabled by sandbox option")
        return
    end

    -- Guard: ensure PerkFactory is available
    if not PerkFactory or not PerkFactory.Perks then
        PhobosLib.debug("POS", "[POS:SIGINT]",
            "PerkFactory not available — SIGINT registration skipped")
        return
    end

    local ok, err = pcall(function()
        local perkId = POS_Constants.SIGINT_PERK_ID
        local parentPerk = PerkFactory.Perks[POS_Constants.SIGINT_PERK_PARENT]
            or PerkFactory.Perks.None

        -- Create the custom perk enum value
        local perk = PerkFactory.Perk.new(perkId)
        perk:setCustom()

        -- XP thresholds per level (values before PZ's internal 1.5x multiplier)
        local xp = POS_Constants.SIGINT_XP_THRESHOLDS
        PerkFactory.AddPerk(
            perk,
            perkId,         -- translation key → PZ looks up IGUI_perks_SIGINT
            parentPerk,
            xp[1], xp[2], xp[3], xp[4], xp[5],
            xp[6], xp[7], xp[8], xp[9], xp[10],
            true            -- passiv = true (passive skill category)
        )

        sigintPerk = perk
        PhobosLib.debug("POS", "[POS:SIGINT]",
            "SIGINT perk registered successfully (parent: "
            .. POS_Constants.SIGINT_PERK_PARENT .. ")")
    end)

    if not ok then
        PhobosLib.debug("POS", "[POS:SIGINT]",
            "SIGINT perk registration failed: " .. tostring(err))
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
    local ok, level = pcall(function()
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

    local ok = PhobosLib.addXP(player, sigintPerk, scaledAmount)

    -- Track total XP in modData (for ZScience mirror and stats)
    if ok then
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
