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

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_WBN"
require "POS_MarketSimulation"

local _TAG = "WBN:Compose"
POS_WBN_CompositionService = {}

---------------------------------------------------------------
-- Phrase bank definitions (translation key pools per slot)
---------------------------------------------------------------

-- Each pool is { key1, key2, ... } — resolved via PhobosLib.safeGetText()
local PHRASE_BANKS = {
    openers = {
        [POS_Constants.WBN_ARCHETYPE_QUARTERMASTER] = {
            "UI_WBN_Phrase_Opener_QM_01", "UI_WBN_Phrase_Opener_QM_02",
            "UI_WBN_Phrase_Opener_QM_03", "UI_WBN_Phrase_Opener_QM_04",
            "UI_WBN_Phrase_Opener_QM_05",
        },
        [POS_Constants.WBN_ARCHETYPE_FIELD_REPORTER] = {
            "UI_WBN_Phrase_Opener_FR_01", "UI_WBN_Phrase_Opener_FR_02",
            "UI_WBN_Phrase_Opener_FR_03", "UI_WBN_Phrase_Opener_FR_04",
        },
    },
    subjects = {
        [POS_Constants.WBN_DOMAIN_ECONOMY] = {
            "UI_WBN_Phrase_Subject_Econ_01", "UI_WBN_Phrase_Subject_Econ_02",
            "UI_WBN_Phrase_Subject_Econ_03", "UI_WBN_Phrase_Subject_Econ_04",
        },
    },
    conditions = {
        [POS_Constants.WBN_DIR_UP] = {
            "UI_WBN_Phrase_Cond_Up_01", "UI_WBN_Phrase_Cond_Up_02",
            "UI_WBN_Phrase_Cond_Up_03", "UI_WBN_Phrase_Cond_Up_04",
        },
        [POS_Constants.WBN_DIR_DOWN] = {
            "UI_WBN_Phrase_Cond_Down_01", "UI_WBN_Phrase_Cond_Down_02",
            "UI_WBN_Phrase_Cond_Down_03", "UI_WBN_Phrase_Cond_Down_04",
        },
        [POS_Constants.WBN_DIR_STABLE] = {
            "UI_WBN_Phrase_Cond_Stable_01", "UI_WBN_Phrase_Cond_Stable_02",
        },
    },
    qualifiers = {
        [POS_Constants.WBN_CONF_HIGH]   = { "UI_WBN_Phrase_Qual_High_01" },
        [POS_Constants.WBN_CONF_MEDIUM] = {
            "UI_WBN_Phrase_Qual_Med_01", "UI_WBN_Phrase_Qual_Med_02",
            "UI_WBN_Phrase_Qual_Med_03",
        },
        [POS_Constants.WBN_CONF_LOW] = {
            "UI_WBN_Phrase_Qual_Low_01", "UI_WBN_Phrase_Qual_Low_02",
            "UI_WBN_Phrase_Qual_Low_03",
        },
    },
    closers = {
        [POS_Constants.WBN_ARCHETYPE_QUARTERMASTER] = {
            "UI_WBN_Phrase_Closer_QM_01", "UI_WBN_Phrase_Closer_QM_02",
            "UI_WBN_Phrase_Closer_QM_03", "UI_WBN_Phrase_Closer_QM_04",
        },
        [POS_Constants.WBN_ARCHETYPE_FIELD_REPORTER] = {
            "UI_WBN_Phrase_Closer_FR_01", "UI_WBN_Phrase_Closer_FR_02",
            "UI_WBN_Phrase_Closer_FR_03", "UI_WBN_Phrase_Closer_FR_04",
        },
    },
    causes = {
        [POS_Constants.WBN_CAUSE_SCARCITY]    = "UI_WBN_Phrase_Cause_Scarcity",
        [POS_Constants.WBN_CAUSE_SURPLUS]      = "UI_WBN_Phrase_Cause_Surplus",
        [POS_Constants.WBN_CAUSE_BLACKOUT]     = "UI_WBN_Phrase_Cause_Blackout",
        [POS_Constants.WBN_CAUSE_CONVOY_LOSS]  = "UI_WBN_Phrase_Cause_ConvoyLoss",
        [POS_Constants.WBN_CAUSE_PANIC]        = "UI_WBN_Phrase_Cause_Panic",
        [POS_Constants.WBN_CAUSE_RECOVERY]     = "UI_WBN_Phrase_Cause_Recovery",
    },
    confidenceModifiers = {
        [POS_Constants.WBN_CONF_HIGH]   = {},  -- no modifier
        [POS_Constants.WBN_CONF_MEDIUM] = {
            "UI_WBN_Phrase_ConfMod_Med_01", "UI_WBN_Phrase_ConfMod_Med_02",
            "UI_WBN_Phrase_ConfMod_Med_03",
        },
        [POS_Constants.WBN_CONF_LOW] = {
            "UI_WBN_Phrase_ConfMod_Low_01", "UI_WBN_Phrase_ConfMod_Low_02",
            "UI_WBN_Phrase_ConfMod_Low_03",
        },
    },
}

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Pick a random entry from a pool and resolve its translation key.
--- @param pool table Array of translation key strings
--- @return string Resolved translated text, or empty string if pool is empty
local function pickPhrase(pool)
    if not pool or #pool == 0 then return "" end
    local key = pool[ZombRand(#pool) + 1]
    return PhobosLib.safeGetText(key)
end

--- Resolve human-readable zone name from zone registry or fallback formatting.
--- @param zoneId string The market zone identifier
--- @return string Display-friendly zone name
local function resolveZoneName(zoneId)
    -- Try zone registry first
    if POS_MarketSimulation and POS_MarketSimulation.getZoneRegistry then
        local ok, registry = PhobosLib.safecall(POS_MarketSimulation.getZoneRegistry)
        if ok and registry and registry.get then
            local entry = registry:get(zoneId)
            if entry and entry.displayName then return entry.displayName end
        end
    end
    -- Fallback: capitalise the zone ID
    if not zoneId then return "???" end
    return zoneId:sub(1,1):upper() .. zoneId:sub(2):gsub("_", " ")
end

--- Resolve human-readable category name via translation key or fallback.
--- @param categoryId string The item category identifier
--- @return string Display-friendly category name
local function resolveCategoryName(categoryId)
    -- Try translation key first
    local key = "UI_POS_Category_" .. (categoryId or "miscellaneous")
    local text = PhobosLib.safeGetText(key)
    if text and text ~= key then return text end
    -- Fallback: capitalise
    if not categoryId then return "goods" end
    return categoryId:sub(1,1):upper() .. categoryId:sub(2)
end

--- Build the percentage phrase with confidence modifier.
--- High confidence: "12"  Medium: "about 12"  Low: "said to be 12"
--- @param pct number The percentage value
--- @param confidenceBand string Confidence band constant
--- @return string Formatted percentage phrase with optional confidence modifier
local function buildPercentPhrase(pct, confidenceBand)
    local confModPool = PHRASE_BANKS.confidenceModifiers[confidenceBand]
    local modifier = pickPhrase(confModPool)  -- empty string for high confidence
    return modifier .. tostring(pct)
end

--- Fill template variables in a phrase string.
--- Replaces {key} placeholders with corresponding values from the vars table.
--- @param text string Template string containing {key} placeholders
--- @param vars table Key-value pairs for substitution
--- @return string Text with all recognised placeholders replaced
local function fillTemplate(text, vars)
    if not text then return "" end
    for k, v in pairs(vars) do
        text = text:gsub("{" .. k .. "}", tostring(v))
    end
    return text
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Compose a bulletin from an approved candidate.
--- Assembles the 5-slot grammar (opener, subject, condition, qualifier, closer)
--- with optional cause suffix into RadioLine-ready coloured text entries.
--- @param candidate table Approved candidate with stationClass, confidenceBand, etc.
--- @param archetypeId string Voice archetype to use (defaults to QUARTERMASTER)
--- @return table Array of { text = string, r = number, g = number, b = number }
function POS_WBN_CompositionService.compose(candidate, archetypeId)
    local c = candidate
    local arch = archetypeId or POS_Constants.WBN_ARCHETYPE_QUARTERMASTER
    local domain = c.domain or POS_Constants.WBN_DOMAIN_ECONOMY
    local direction = c.direction or POS_Constants.WBN_DIR_STABLE
    local confBand = c.confidenceBand or POS_Constants.WBN_CONF_MEDIUM

    -- Resolve display values
    local zoneName = resolveZoneName(c.zoneId)
    local categoryName = resolveCategoryName(c.categoryId)
    local pctPhrase = buildPercentPhrase(c.percentChange or 0, confBand)

    local vars = {
        zone     = zoneName,
        category = categoryName,
        pct      = pctPhrase,
    }

    -- 1. Opener
    local opener = pickPhrase(PHRASE_BANKS.openers[arch])

    -- 2. Subject
    local subjectPool = PHRASE_BANKS.subjects[domain] or PHRASE_BANKS.subjects[POS_Constants.WBN_DOMAIN_ECONOMY]
    local subject = fillTemplate(pickPhrase(subjectPool), vars)

    -- 3. Condition
    local condPool = PHRASE_BANKS.conditions[direction] or PHRASE_BANKS.conditions[POS_Constants.WBN_DIR_STABLE]
    local condition = fillTemplate(pickPhrase(condPool), vars)

    -- 4. Cause (optional — 50% chance to include if cause tag exists)
    local causeSuffix = ""
    if c.causeTag and PHRASE_BANKS.causes[c.causeTag] and ZombRand(2) == 0 then
        causeSuffix = " " .. PhobosLib.safeGetText(PHRASE_BANKS.causes[c.causeTag])
    end

    -- 5. Qualifier
    local qualifier = pickPhrase(PHRASE_BANKS.qualifiers[confBand])

    -- 6. Closer
    local closer = pickPhrase(PHRASE_BANKS.closers[arch])

    -- Assemble bulletin text
    local body = subject .. " " .. condition .. causeSuffix .. "."
    if qualifier and qualifier ~= "" then
        body = body .. " " .. qualifier
    end
    if closer and closer ~= "" then
        body = body .. " " .. closer
    end

    -- Choose colour based on domain
    local colour = POS_Constants.WBN_COLOUR_ECONOMY
    if domain == POS_Constants.WBN_DOMAIN_INFRASTRUCTURE then
        colour = POS_Constants.WBN_COLOUR_EMERGENCY
    end

    -- Station tag line (dimmer)
    local tagKey = POS_Constants.WBN_TAG_KEY_CIVILIAN
    if c.stationClass == POS_Constants.WBN_STATION_EMERGENCY then
        tagKey = POS_Constants.WBN_TAG_KEY_EMERGENCY
    end
    local tagText = PhobosLib.safeGetText(tagKey)

    local lines = {
        { text = tagText .. " " .. opener, r = POS_Constants.WBN_COLOUR_TAG.r, g = POS_Constants.WBN_COLOUR_TAG.g, b = POS_Constants.WBN_COLOUR_TAG.b },
        { text = body, r = colour.r, g = colour.g, b = colour.b },
    }

    PhobosLib.debug("POS", _TAG,
        "compose: " .. tagText .. " " .. opener .. " " .. body)

    return lines
end
