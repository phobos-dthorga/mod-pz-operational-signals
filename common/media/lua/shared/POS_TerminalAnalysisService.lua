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
-- POS_TerminalAnalysisService.lua
-- Business logic for Terminal Analysis (Tier II — Processing).
-- Input validation, tier distribution, fragment generation,
-- diversity bonuses, cooldown management.
-- All game-state mutations happen here — screen delegates only.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_SIGINTSkill"
require "POS_SIGINTService"

POS_TerminalAnalysisService = {}

local _TAG = "[POS:Analysis]"

---------------------------------------------------------------
-- Fragment tier distribution weights per SIGINT level
-- Each entry: { fragmentary, unverified, correlated, confirmed }
-- Indexed 1-11 for levels 0-10
---------------------------------------------------------------
local TIER_WEIGHTS = {
    { 50, 35, 12, 3 },     -- L0: mostly junk
    { 45, 35, 15, 5 },     -- L1
    { 40, 35, 18, 7 },     -- L2
    { 30, 35, 25, 10 },    -- L3
    { 25, 30, 30, 15 },    -- L4
    { 20, 25, 35, 20 },    -- L5: even spread
    { 15, 20, 35, 30 },    -- L6
    { 10, 18, 35, 37 },    -- L7
    { 8,  15, 35, 42 },    -- L8
    { 5,  10, 30, 55 },    -- L9
    { 3,  7,  25, 65 },    -- L10: mostly high-quality
}

--- Fragment tier IDs ordered by quality (index matches TIER_WEIGHTS columns).
local TIER_IDS = {
    POS_Constants.FRAGMENT_TIER_FRAGMENTARY,
    POS_Constants.FRAGMENT_TIER_UNVERIFIED,
    POS_Constants.FRAGMENT_TIER_CORRELATED,
    POS_Constants.FRAGMENT_TIER_CONFIRMED,
}

--- Map fragment tier ID to item full type.
local TIER_TO_ITEM = {
    [POS_Constants.FRAGMENT_TIER_FRAGMENTARY] = POS_Constants.ITEM_INTEL_FRAGMENTARY,
    [POS_Constants.FRAGMENT_TIER_UNVERIFIED]  = POS_Constants.ITEM_INTEL_UNVERIFIED,
    [POS_Constants.FRAGMENT_TIER_CORRELATED]  = POS_Constants.ITEM_INTEL_CORRELATED,
    [POS_Constants.FRAGMENT_TIER_CONFIRMED]   = POS_Constants.ITEM_INTEL_CONFIRMED,
}

---------------------------------------------------------------
-- Input Validation
---------------------------------------------------------------

--- Find all valid raw intel items in the player's inventory.
--- Items must have the POS_RawIntel tag.
---@param player IsoPlayer
---@return table Array of items with the raw intel tag
function POS_TerminalAnalysisService.findRawIntelItems(player)
    if not player then return {} end
    local inv = player:getInventory()
    if not inv then return {} end
    return PhobosLib.findItemsByTag(inv, POS_Constants.TAG_RAW_INTEL)
end

--- Validate that the given inputs are suitable for analysis.
---@param items table Array of items to validate
---@return boolean valid, string|nil errorKey
function POS_TerminalAnalysisService.validateInputs(items)
    if not items or #items == 0 then
        return false, "UI_POS_Analysis_NoInputs"
    end
    if #items > POS_Constants.ANALYSIS_MAX_INPUTS then
        return false, "UI_POS_Analysis_TooManyInputs"
    end
    return true, nil
end

---------------------------------------------------------------
-- Cooldown
---------------------------------------------------------------

--- Get the cooldown key for the terminal building.
---@param player IsoPlayer
---@return string|nil Cooldown key, or nil if not in a building
function POS_TerminalAnalysisService.getCooldownKey(player)
    if not player then return nil end
    local sq = player:getSquare()
    if not sq then return nil end
    local building = sq:getBuilding()
    if not building then return nil end

    local bx, by = 0, 0
    PhobosLib.safecall(function()
        local def = building:getDef()
        if def then
            bx = def:getX()
            by = def:getY()
        end
    end)

    return POS_Constants.ANALYSIS_VISIT_KEY_PREFIX
        .. tostring(bx) .. "_" .. tostring(by)
end

--- Check if the terminal analysis is on cooldown.
---@param player IsoPlayer
---@return boolean onCooldown, number minutesLeft
function POS_TerminalAnalysisService.isOnCooldown(player)
    local key = POS_TerminalAnalysisService.getCooldownKey(player)
    if not key then return false, 0 end

    local modData = player:getModData()
    local lastUseHour = modData[key] or -9999
    local currentHour = getGameTime():getWorldAgeHours()
    local cooldownMinutes = POS_Sandbox and POS_Sandbox.getAnalysisCooldownMinutes
        and POS_Sandbox.getAnalysisCooldownMinutes()
        or POS_Constants.ANALYSIS_COOLDOWN_MINUTES
    local cooldownHours = cooldownMinutes / 60
    local hoursSince = currentHour - lastUseHour

    if hoursSince < cooldownHours then
        local minutesLeft = math.ceil((cooldownHours - hoursSince) * 60)
        return true, minutesLeft
    end
    return false, 0
end

--- Record a cooldown timestamp.
---@param player IsoPlayer
function POS_TerminalAnalysisService.recordCooldown(player)
    local key = POS_TerminalAnalysisService.getCooldownKey(player)
    if not key then return end
    player:getModData()[key] = getGameTime():getWorldAgeHours()
end

---------------------------------------------------------------
-- Diversity Bonuses
---------------------------------------------------------------

--- Calculate diversity bonuses from a set of input items.
--- +3 confidence per unique source type (cap +12).
--- +2 confidence per unique category (cap +8).
---@param items table Array of input items
---@return number totalBonus
function POS_TerminalAnalysisService.calculateDiversityBonus(items)
    if not items or #items == 0 then return 0 end

    local sourceTypes = {}
    local categories = {}

    for _, item in ipairs(items) do
        local md = PhobosLib.getModData(item)
        if md then
            local srcType = md.POS_SourceType or "unknown"
            local cat = md.POS_Category or "unknown"
            sourceTypes[srcType] = true
            categories[cat] = true
        end
    end

    -- Count unique sources
    local sourceCount = 0
    for _ in pairs(sourceTypes) do sourceCount = sourceCount + 1 end
    local sourceBonus = math.min(
        sourceCount * POS_Constants.ANALYSIS_SOURCE_DIVERSITY_BONUS,
        POS_Constants.ANALYSIS_SOURCE_DIVERSITY_CAP
    )

    -- Count unique categories
    local catCount = 0
    for _ in pairs(categories) do catCount = catCount + 1 end
    local catBonus = math.min(
        catCount * POS_Constants.ANALYSIS_CATEGORY_DIVERSITY_BONUS,
        POS_Constants.ANALYSIS_CATEGORY_DIVERSITY_CAP
    )

    return sourceBonus + catBonus
end

---------------------------------------------------------------
-- Action Time Calculation
---------------------------------------------------------------

--- Calculate the effective action time for terminal analysis.
---@param player IsoPlayer
---@param inputCount number Number of inputs selected
---@return number Duration in seconds
function POS_TerminalAnalysisService.calculateActionTime(player, inputCount)
    local baseTime = POS_Sandbox and POS_Sandbox.getAnalysisBaseTime
        and POS_Sandbox.getAnalysisBaseTime()
        or POS_Constants.ANALYSIS_BASE_TIME

    -- Scale slightly with input count (more inputs = slightly longer)
    local scaledTime = baseTime + (inputCount - 1) * 10

    -- Apply SIGINT time reduction
    return POS_SIGINTService.calculateEffectiveTime(player, scaledTime)
end

---------------------------------------------------------------
-- Fragment Tier Selection
---------------------------------------------------------------

--- Roll a fragment tier based on SIGINT level.
---@param level number SIGINT level 0-10
---@return string Fragment tier ID (e.g., "correlated")
function POS_TerminalAnalysisService.rollFragmentTier(level)
    local idx = math.max(1, math.min(level + 1, #TIER_WEIGHTS))
    local weights = TIER_WEIGHTS[idx]

    -- Weighted random selection
    local totalWeight = 0
    for _, w in ipairs(weights) do
        totalWeight = totalWeight + w
    end

    local roll = ZombRand(totalWeight)
    local cumulative = 0
    for i, w in ipairs(weights) do
        cumulative = cumulative + w
        if roll < cumulative then
            return TIER_IDS[i]
        end
    end

    -- Fallback (should not reach)
    return TIER_IDS[1]
end

---------------------------------------------------------------
-- Core Processing
---------------------------------------------------------------

--- Process raw intel inputs and generate intel fragments.
--- This is the main business logic function called by the timed action.
---@param player IsoPlayer
---@param inputs table Array of input items to consume
---@return table results { fragments = table[], crossCorrelation = boolean, falseDataFiltered = boolean, xpAwarded = number }
function POS_TerminalAnalysisService.processIntelligence(player, inputs)
    local results = {
        fragments = {},
        crossCorrelation = false,
        falseDataFiltered = false,
        xpAwarded = 0,
    }

    if not player or not inputs or #inputs == 0 then return results end

    local inv = player:getInventory()
    if not inv then return results end

    local level = POS_SIGINTSkill.getLevel(player)
    local inputCount = math.min(#inputs, POS_Constants.ANALYSIS_MAX_INPUTS)

    -- 1. Calculate diversity bonus
    local diversityBonus = POS_TerminalAnalysisService.calculateDiversityBonus(inputs)

    -- 2. Determine yield count
    local fragmentCount = POS_SIGINTService.rollYield(player)

    -- 3. Check for noise filter (may suppress junk outputs)
    local noiseFilter = POS_SIGINTService.getNoiseFilter(player)
    local baseJunkChance = POS_Sandbox and POS_Sandbox.getAnalysisJunkChance
        and POS_Sandbox.getAnalysisJunkChance()
        or POS_Constants.ANALYSIS_BASE_JUNK_CHANCE

    -- 4. Check for cross-correlation
    if POS_SIGINTService.hasCrossCorrelation(player) and inputCount >= 3 then
        -- Cross-correlation requires 3+ diverse inputs
        local categories = {}
        for _, item in ipairs(inputs) do
            local md = PhobosLib.getModData(item)
            if md and md.POS_Category then
                categories[md.POS_Category] = true
            end
        end
        local catCount = 0
        for _ in pairs(categories) do catCount = catCount + 1 end
        if catCount >= 2 then
            -- Cross-correlation discovered: bonus fragment + upgrade chance
            results.crossCorrelation = true
            fragmentCount = fragmentCount + 1
        end
    end

    -- 5. Check for false data detection
    if POS_SIGINTService.hasFalseDataDetection(player) then
        -- Roll chance to detect false data in inputs
        if ZombRand(100) < 20 then  -- 20% base chance at L8+
            results.falseDataFiltered = true
            -- Filtering false data improves confidence of remaining outputs
            diversityBonus = diversityBonus + 5
        end
    end

    -- 6. Consume inputs
    for _, item in ipairs(inputs) do
        if inv:contains(item) then
            inv:Remove(item)
        end
    end

    -- 6b. Satellite link enhancement
    local hasSatelliteLink = false
    if POS_SatelliteService and POS_SatelliteService.hasTerminalLink then
        local sq = player:getSquare()
        if sq then
            hasSatelliteLink = POS_SatelliteService.hasTerminalLink(sq)
        end
    end

    -- 7. Generate fragments
    local confidenceBase = POS_SIGINTService.getConfidenceBonus(player) + diversityBonus
    if hasSatelliteLink then
        confidenceBase = confidenceBase + POS_Constants.ANALYSIS_SATELLITE_CONFIDENCE
    end
    local primaryCategory = nil
    if inputs[1] then
        local md = PhobosLib.getModData(inputs[1])
        if md then primaryCategory = md.POS_Category end
    end

    for i = 1, fragmentCount do
        -- Roll tier
        local tier = POS_TerminalAnalysisService.rollFragmentTier(level)

        -- Apply noise filter: chance to upgrade junk (fragmentary) to something better
        if tier == POS_Constants.FRAGMENT_TIER_FRAGMENTARY and noiseFilter > 0 then
            if ZombRand(100) < noiseFilter then
                tier = POS_Constants.FRAGMENT_TIER_UNVERIFIED
            end
        end

        -- Satellite link tier upgrade chance
        if hasSatelliteLink and ZombRand(100) < POS_Constants.ANALYSIS_SATELLITE_TIER_UPGRADE then
            if tier == POS_Constants.FRAGMENT_TIER_FRAGMENTARY then
                tier = POS_Constants.FRAGMENT_TIER_UNVERIFIED
            elseif tier == POS_Constants.FRAGMENT_TIER_UNVERIFIED then
                tier = POS_Constants.FRAGMENT_TIER_CORRELATED
            end
        end

        -- Cross-correlation bonus fragment gets upgraded tier
        if results.crossCorrelation and i == fragmentCount then
            if tier == POS_Constants.FRAGMENT_TIER_FRAGMENTARY then
                tier = POS_Constants.FRAGMENT_TIER_CORRELATED
            elseif tier == POS_Constants.FRAGMENT_TIER_UNVERIFIED then
                tier = POS_Constants.FRAGMENT_TIER_CORRELATED
            end
        end

        -- Junk suppression: low levels may produce nothing for some slots
        local isJunk = false
        if ZombRand(100) < baseJunkChance then
            if ZombRand(100) >= noiseFilter then
                isJunk = true
            end
        end

        if not isJunk then
            local itemType = TIER_TO_ITEM[tier]
            if itemType then
                local fragment = inv:AddItem(itemType)
                if fragment then
                    -- Populate modData
                    local fmd = fragment:getModData()
                    if fmd then
                        fmd.POS_FragmentTier = tier
                        fmd.POS_Confidence = math.min(99,
                            confidenceBase + ZombRand(5, 15))
                        fmd.POS_Category = primaryCategory or "mixed"
                        fmd.POS_SourceCount = inputCount
                        fmd.POS_AnalysisDay = getGameTime():getNightsSurvived()
                        fmd.POS_SIGINTLevel = level
                        fmd.POS_CrossRef = results.crossCorrelation
                    end

                    -- Apply tooltip
                    if POS_NoteTooltip and POS_NoteTooltip.applyToNote then
                        POS_NoteTooltip.applyToNote(fragment)
                    end

                    results.fragments[#results.fragments + 1] = {
                        tier = tier,
                        confidence = fmd and fmd.POS_Confidence or 0,
                    }
                end
            end
        end
    end

    -- 8. Award SIGINT XP
    local xpIdx = math.min(inputCount, #POS_Constants.ANALYSIS_XP_PER_INPUT)
    local baseXP = POS_Constants.ANALYSIS_XP_PER_INPUT[xpIdx]
        or POS_Constants.SIGINT_XP_TERMINAL_ANALYSIS
    POS_SIGINTSkill.addXP(player, baseXP)
    results.xpAwarded = baseXP

    -- Bonus XP for cross-correlation
    if results.crossCorrelation then
        POS_SIGINTSkill.addXP(player, POS_Constants.SIGINT_XP_CROSS_CORRELATION)
        results.xpAwarded = results.xpAwarded + POS_Constants.SIGINT_XP_CROSS_CORRELATION

        -- Track cross-correlation count
        local modData = player:getModData()
        local ccKey = POS_Constants.MODDATA_SIGINT_CROSSCOR_COUNT
        modData[ccKey] = (modData[ccKey] or 0) + 1
    end

    -- Bonus XP for false data detection
    if results.falseDataFiltered then
        POS_SIGINTSkill.addXP(player, POS_Constants.SIGINT_XP_RESOLVE_CONTRADICTION)
        results.xpAwarded = results.xpAwarded + POS_Constants.SIGINT_XP_RESOLVE_CONTRADICTION
    end

    -- 9. ZScience specimen roll (optional cross-mod)
    if POS_ZScienceIntegration and POS_ZScienceIntegration.rollSpecimen then
        POS_ZScienceIntegration.rollSpecimen(player, level)
    end

    -- 10. Record cooldown
    POS_TerminalAnalysisService.recordCooldown(player)

    -- 11. Tutorial milestones
    if POS_TutorialService and POS_TutorialService.tryAward then
        POS_TutorialService.tryAward(player, POS_Constants.TUTORIAL_FIRST_ANALYSIS)
        if results.crossCorrelation then
            POS_TutorialService.tryAward(player, POS_Constants.TUTORIAL_FIRST_CROSS_CORRELATION)
        end
    end

    PhobosLib.debug("POS", _TAG,
        "Processed " .. inputCount .. " inputs → "
        .. #results.fragments .. " fragments (SIGINT L" .. level .. ")")

    return results
end

---------------------------------------------------------------
-- Estimated Output Preview
---------------------------------------------------------------

--- Generate a preview estimate for the UI (no side effects).
---@param player IsoPlayer
---@param inputCount number Number of inputs selected
---@return table { estimatedFragments = string, estimatedTime = number, confidenceRange = string }
function POS_TerminalAnalysisService.getEstimate(player, inputCount)
    local minY, maxY = POS_SIGINTService.getYieldRange(player)
    local time = POS_TerminalAnalysisService.calculateActionTime(player, inputCount)
    local confBonus = POS_SIGINTService.getConfidenceBonus(player)
    local diversity = inputCount > 1 and (inputCount * POS_Constants.ANALYSIS_SOURCE_DIVERSITY_BONUS) or 0

    return {
        estimatedFragments = tostring(minY) .. "-" .. tostring(maxY),
        estimatedTime = time,
        confidenceRange = tostring(confBonus + diversity + 5) .. "-" .. tostring(confBonus + diversity + 15),
    }
end
