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
require "POS_VoicePackRegistry"

local _TAG = "WBN:Compose"
POS_WBN_CompositionService = {}

---------------------------------------------------------------
-- Phrase bank definitions (translation key pools per slot)
---------------------------------------------------------------

-- Default opener/closer pools — used as fallback when no voice pack is registered
local DEFAULT_OPENERS = {
    [POS_Constants.WBN_ARCHETYPE_QUARTERMASTER] = {
        "UI_WBN_Phrase_Opener_QM_01", "UI_WBN_Phrase_Opener_QM_02",
        "UI_WBN_Phrase_Opener_QM_03", "UI_WBN_Phrase_Opener_QM_04",
        "UI_WBN_Phrase_Opener_QM_05",
    },
    [POS_Constants.WBN_ARCHETYPE_FIELD_REPORTER] = {
        "UI_WBN_Phrase_Opener_FR_01", "UI_WBN_Phrase_Opener_FR_02",
        "UI_WBN_Phrase_Opener_FR_03", "UI_WBN_Phrase_Opener_FR_04",
    },
}

local DEFAULT_CLOSERS = {
    [POS_Constants.WBN_ARCHETYPE_QUARTERMASTER] = {
        "UI_WBN_Phrase_Closer_QM_01", "UI_WBN_Phrase_Closer_QM_02",
        "UI_WBN_Phrase_Closer_QM_03", "UI_WBN_Phrase_Closer_QM_04",
    },
    [POS_Constants.WBN_ARCHETYPE_FIELD_REPORTER] = {
        "UI_WBN_Phrase_Closer_FR_01", "UI_WBN_Phrase_Closer_FR_02",
        "UI_WBN_Phrase_Closer_FR_03", "UI_WBN_Phrase_Closer_FR_04",
    },
}

-- Forecast time horizon openers
local FORECAST_OPENERS = {
    [1] = { "UI_WBN_Forecast_Opener_Tomorrow_01", "UI_WBN_Forecast_Opener_Tomorrow_02", "UI_WBN_Forecast_Opener_Tomorrow_03" },
    [2] = { "UI_WBN_Forecast_Opener_TwoDays_01", "UI_WBN_Forecast_Opener_TwoDays_02" },
    [3] = { "UI_WBN_Forecast_Opener_ThreeDays_01", "UI_WBN_Forecast_Opener_ThreeDays_02" },
}

-- Forecast confidence verbs (inserted into economy/power forecast text)
local FORECAST_CONF_VERBS = {
    high   = { "UI_WBN_Forecast_Verb_High_01", "UI_WBN_Forecast_Verb_High_02" },
    medium = { "UI_WBN_Forecast_Verb_Med_01", "UI_WBN_Forecast_Verb_Med_02", "UI_WBN_Forecast_Verb_Med_03" },
    low    = { "UI_WBN_Forecast_Verb_Low_01", "UI_WBN_Forecast_Verb_Low_02", "UI_WBN_Forecast_Verb_Low_03" },
}

-- Forecast weather condition keys
local FORECAST_WEATHER_KEYS = {
    forecast_storm        = "UI_WBN_Forecast_Weather_Storm",
    forecast_rain_heavy   = "UI_WBN_Forecast_Weather_HeavyRain",
    forecast_blizzard     = "UI_WBN_Forecast_Weather_Blizzard",
    forecast_snow         = "UI_WBN_Forecast_Weather_Snow",
    forecast_fog          = "UI_WBN_Forecast_Weather_Fog",
    forecast_cold_extreme = "UI_WBN_Forecast_Weather_ColdExtreme",
    forecast_heat_extreme = "UI_WBN_Forecast_Weather_HeatExtreme",
    forecast_wind_strong  = "UI_WBN_Forecast_Weather_WindStrong",
    forecast_clear        = "UI_WBN_Forecast_Weather_Clear",
    forecast_overcast     = "UI_WBN_Forecast_Weather_Overcast",
}

-- Forecast power keys
local FORECAST_POWER_KEYS = {
    forecast_failure = { "UI_WBN_Forecast_Power_Failure_01", "UI_WBN_Forecast_Power_Failure_02", "UI_WBN_Forecast_Power_Failure_03" },
}

-- Forecast closers
local FORECAST_CLOSERS = {
    "UI_WBN_Forecast_Closer_01", "UI_WBN_Forecast_Closer_02", "UI_WBN_Forecast_Closer_03",
}

-- Each pool is { key1, key2, ... } — resolved via PhobosLib.safeGetText()
local PHRASE_BANKS = {
    subjects = {
        [POS_Constants.WBN_DOMAIN_ECONOMY] = {
            "UI_WBN_Phrase_Subject_Econ_01", "UI_WBN_Phrase_Subject_Econ_02",
            "UI_WBN_Phrase_Subject_Econ_03", "UI_WBN_Phrase_Subject_Econ_04",
            "UI_WBN_Phrase_Subject_Econ_05", "UI_WBN_Phrase_Subject_Econ_06",
            "UI_WBN_Phrase_Subject_Econ_07", "UI_WBN_Phrase_Subject_Econ_08",
            "UI_WBN_Phrase_Subject_Econ_09", "UI_WBN_Phrase_Subject_Econ_10",
            "UI_WBN_Phrase_Subject_Econ_11", "UI_WBN_Phrase_Subject_Econ_12",
        },
        [POS_Constants.WBN_DOMAIN_INFRASTRUCTURE] = {
            "UI_WBN_Phrase_Subject_Infra_01", "UI_WBN_Phrase_Subject_Infra_02",
            "UI_WBN_Phrase_Subject_Infra_03", "UI_WBN_Phrase_Subject_Infra_04",
            "UI_WBN_Phrase_Subject_Infra_05", "UI_WBN_Phrase_Subject_Infra_06",
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
    conditionsConfidence = {
        [POS_Constants.WBN_DIR_UP] = {
            [POS_Constants.WBN_CONF_HIGH] = { "UI_WBN_Phrase_Cond_UpHigh_01", "UI_WBN_Phrase_Cond_UpHigh_02" },
            [POS_Constants.WBN_CONF_LOW]  = { "UI_WBN_Phrase_Cond_UpLow_01",  "UI_WBN_Phrase_Cond_UpLow_02" },
        },
        [POS_Constants.WBN_DIR_DOWN] = {
            [POS_Constants.WBN_CONF_HIGH] = { "UI_WBN_Phrase_Cond_DownHigh_01", "UI_WBN_Phrase_Cond_DownHigh_02" },
            [POS_Constants.WBN_CONF_LOW]  = { "UI_WBN_Phrase_Cond_DownLow_01",  "UI_WBN_Phrase_Cond_DownLow_02" },
        },
        [POS_Constants.WBN_DIR_STABLE] = {
            -- extra stable variants used regardless of confidence
            _extra = { "UI_WBN_Phrase_Cond_Stable_03", "UI_WBN_Phrase_Cond_Stable_04" },
        },
        [POS_Constants.WBN_DIR_MIXED] = {
            _default = { "UI_WBN_Phrase_Cond_Mixed_01", "UI_WBN_Phrase_Cond_Mixed_02" },
        },
    },
    qualifiers = {
        [POS_Constants.WBN_CONF_HIGH]   = {
            "UI_WBN_Phrase_Qual_High_01", "UI_WBN_Phrase_Qual_High_02",
            "UI_WBN_Phrase_Qual_High_03",
        },
        [POS_Constants.WBN_CONF_MEDIUM] = {
            "UI_WBN_Phrase_Qual_Med_01", "UI_WBN_Phrase_Qual_Med_02",
            "UI_WBN_Phrase_Qual_Med_03", "UI_WBN_Phrase_Qual_Med_04",
            "UI_WBN_Phrase_Qual_Med_05",
        },
        [POS_Constants.WBN_CONF_LOW] = {
            "UI_WBN_Phrase_Qual_Low_01", "UI_WBN_Phrase_Qual_Low_02",
            "UI_WBN_Phrase_Qual_Low_03", "UI_WBN_Phrase_Qual_Low_04",
            "UI_WBN_Phrase_Qual_Low_05",
        },
    },
    causes = {
        [POS_Constants.WBN_CAUSE_SCARCITY]    = { "UI_WBN_Phrase_Cause_Scarcity", "UI_WBN_Phrase_Cause_Scarcity_02", "UI_WBN_Phrase_Cause_Scarcity_03" },
        [POS_Constants.WBN_CAUSE_SURPLUS]     = { "UI_WBN_Phrase_Cause_Surplus", "UI_WBN_Phrase_Cause_Surplus_02", "UI_WBN_Phrase_Cause_Surplus_03" },
        [POS_Constants.WBN_CAUSE_BLACKOUT]    = { "UI_WBN_Phrase_Cause_Blackout", "UI_WBN_Phrase_Cause_Blackout_02", "UI_WBN_Phrase_Cause_Blackout_03" },
        [POS_Constants.WBN_CAUSE_CONVOY_LOSS] = { "UI_WBN_Phrase_Cause_ConvoyLoss", "UI_WBN_Phrase_Cause_ConvoyLoss_02", "UI_WBN_Phrase_Cause_ConvoyLoss_03" },
        [POS_Constants.WBN_CAUSE_PANIC]       = { "UI_WBN_Phrase_Cause_Panic", "UI_WBN_Phrase_Cause_Panic_02", "UI_WBN_Phrase_Cause_Panic_03" },
        [POS_Constants.WBN_CAUSE_RECOVERY]    = { "UI_WBN_Phrase_Cause_Recovery", "UI_WBN_Phrase_Cause_Recovery_02", "UI_WBN_Phrase_Cause_Recovery_03" },
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

--- Resolve a phrase pool from voice pack registry, with fallback.
--- Queries POS_VoicePackRegistry for an override text pool; if found, extracts
--- translation keys from its entries. Falls back to the provided default keys.
--- @param archetypeId string Voice archetype identifier
--- @param sectionName string Voice pack section (e.g. "wbn_opener")
--- @param fallbackKeys table Array of translation key strings to use as default
--- @return table Array of translation key strings
local function resolveArchetypePool(archetypeId, sectionName, fallbackKeys)
    -- Try voice pack registry first
    if POS_VoicePackRegistry and POS_VoicePackRegistry.getOverride then
        local poolId = POS_VoicePackRegistry.getOverride(archetypeId, sectionName)
        if poolId then
            local ok, poolDef = PhobosLib.safecall(require, poolId)
            if ok and poolDef and poolDef.entries and #poolDef.entries > 0 then
                -- Convert text pool entries to translation key array
                local keys = {}
                for _, entry in ipairs(poolDef.entries) do
                    if entry.text then keys[#keys + 1] = entry.text end
                end
                if #keys > 0 then
                    PhobosLib.debug("POS", _TAG,
                        "resolved voice pack pool: " .. poolId .. " (" .. #keys .. " entries)")
                    return keys
                end
            end
        end
    end
    -- Fallback to built-in defaults
    return fallbackKeys
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

    -- Delegate forecasts to specialised forecast composer
    if c.isForecast then
        return POS_WBN_CompositionService.composeForecast(c, arch)
    end

    -- Delegate operations domain to specialised composer
    if domain == POS_Constants.WBN_DOMAIN_OPERATIONS then
        return POS_WBN_CompositionService.composeOperations(c, arch)
    end

    -- Delegate world-state domains to specialised composer
    if domain == POS_Constants.WBN_DOMAIN_WEATHER
        or domain == POS_Constants.WBN_DOMAIN_POWER
        or domain == POS_Constants.WBN_DOMAIN_COLOUR then
        return POS_WBN_CompositionService.composeWorldState(c, arch)
    end

    -- Resolve display values
    local zoneName = resolveZoneName(c.zoneId)
    local categoryName = resolveCategoryName(c.categoryId)
    local pctPhrase = buildPercentPhrase(c.percentChange or 0, confBand)

    local vars = {
        zone     = zoneName,
        category = categoryName,
        pct      = pctPhrase,
    }

    -- 1. Opener (voice-pack aware)
    local openerPool = resolveArchetypePool(arch, POS_Constants.WBN_VP_SECTION_OPENER, DEFAULT_OPENERS[arch])
    local opener = pickPhrase(openerPool)

    -- 2. Subject
    local subjectPool = PHRASE_BANKS.subjects[domain] or PHRASE_BANKS.subjects[POS_Constants.WBN_DOMAIN_ECONOMY]
    local subject = fillTemplate(pickPhrase(subjectPool), vars)

    -- 3. Condition
    local condPool = PHRASE_BANKS.conditions[direction] or PHRASE_BANKS.conditions[POS_Constants.WBN_DIR_STABLE]
    local condition = fillTemplate(pickPhrase(condPool), vars)

    -- 4. Cause (optional — 50% chance to include if cause tag exists)
    local causeSuffix = ""
    if c.causeTag and PHRASE_BANKS.causes[c.causeTag] and ZombRand(2) == 0 then
        local causePool = PHRASE_BANKS.causes[c.causeTag]
        if type(causePool) == "table" then
            causeSuffix = " " .. pickPhrase(causePool)
        else
            -- Legacy single-key fallback
            causeSuffix = " " .. PhobosLib.safeGetText(causePool)
        end
    end

    -- 5. Qualifier
    local qualifier = pickPhrase(PHRASE_BANKS.qualifiers[confBand])

    -- 6. Closer (voice-pack aware)
    local closerPool = resolveArchetypePool(arch, POS_Constants.WBN_VP_SECTION_CLOSER, DEFAULT_CLOSERS[arch])
    local closer = pickPhrase(closerPool)

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

---------------------------------------------------------------
-- World-state domain composer (weather, power, colour)
---------------------------------------------------------------

-- Weather translation key mapping
local WEATHER_KEYS = {
    storm_wind    = "UI_WBN_Weather_Wind_Storm",
    rain_heavy    = "UI_WBN_Weather_Rain_Heavy",
    cold_extreme  = "UI_WBN_Weather_Cold_Extreme",
    heat_extreme  = "UI_WBN_Weather_Heat_Extreme",
    wind_strong   = "UI_WBN_Weather_Wind_Strong",
    snow          = "UI_WBN_Weather_Snow",
    fog           = "UI_WBN_Weather_Fog",
    rain_moderate = "UI_WBN_Weather_Rain_Mod",
    overcast      = "UI_WBN_Weather_Overcast",
    clear         = "UI_WBN_Weather_Clear",
}

-- Power transition translation key pools (multiple variants per transition)
local POWER_KEYS = {
    failed       = { "UI_WBN_Power_ShutOff_01", "UI_WBN_Power_ShutOff_02", "UI_WBN_Power_ShutOff_03" },
    restored     = { "UI_WBN_Power_Restored_01", "UI_WBN_Power_Restored_02", "UI_WBN_Power_Restored_03" },
    reminder_off = { "UI_WBN_Power_Reminder_Off", "UI_WBN_Power_Reminder_Off_02", "UI_WBN_Power_Reminder_Off_03" },
    status_on    = { "UI_WBN_Power_Status_On", "UI_WBN_Power_Status_On_02", "UI_WBN_Power_Status_On_03" },
}

-- Flavour pools by target station
local FLAVOUR_POOLS = {
    [POS_Constants.WBN_STATION_CIVILIAN_MARKET] = {
        "UI_WBN_Flavour_Market_01", "UI_WBN_Flavour_Market_02",
        "UI_WBN_Flavour_Market_03", "UI_WBN_Flavour_Market_04",
        "UI_WBN_Flavour_Market_05", "UI_WBN_Flavour_Market_06",
    },
    [POS_Constants.WBN_STATION_EMERGENCY] = {
        "UI_WBN_Flavour_Emergency_01", "UI_WBN_Flavour_Emergency_02",
        "UI_WBN_Flavour_Emergency_03", "UI_WBN_Flavour_Emergency_04",
        "UI_WBN_Flavour_Emergency_05", "UI_WBN_Flavour_Emergency_06",
    },
}

--- Compose a world-state bulletin (weather, power, or colour/flavour).
--- @param candidate table Approved candidate with domain-specific fields
--- @param archetypeId string Voice archetype to use
--- @return table Array of { text, r, g, b } RadioLine entries
function POS_WBN_CompositionService.composeWorldState(candidate, archetypeId)
    local c = candidate
    local arch = archetypeId or POS_Constants.WBN_ARCHETYPE_QUARTERMASTER
    local domain = c.domain

    -- Resolve station tag
    local tagKey = POS_Constants.WBN_TAG_KEY_CIVILIAN
    if c.stationClass == POS_Constants.WBN_STATION_EMERGENCY then
        tagKey = POS_Constants.WBN_TAG_KEY_EMERGENCY
    end
    local tagText = PhobosLib.safeGetText(tagKey)

    -- Resolve opener/closer via voice pack (using domain-specific sections with fallback)
    local vpSection = "wbn_weather"
    if domain == POS_Constants.WBN_DOMAIN_POWER then
        vpSection = "wbn_power"
    elseif domain == POS_Constants.WBN_DOMAIN_COLOUR then
        local ts = c.targetStation or POS_Constants.WBN_STATION_CIVILIAN_MARKET
        vpSection = (ts == POS_Constants.WBN_STATION_EMERGENCY)
            and "wbn_flavour_emergency"
            or "wbn_flavour_market"
    end

    local openerPool = resolveArchetypePool(arch, vpSection .. "_opener",
        DEFAULT_OPENERS[arch] or DEFAULT_OPENERS[POS_Constants.WBN_ARCHETYPE_QUARTERMASTER])
    local opener = pickPhrase(openerPool)

    local closerPool = resolveArchetypePool(arch, vpSection .. "_closer",
        DEFAULT_CLOSERS[arch] or DEFAULT_CLOSERS[POS_Constants.WBN_ARCHETYPE_QUARTERMASTER])
    local closer = pickPhrase(closerPool)

    -- Build domain-specific body text
    local body = ""
    local colour = POS_Constants.WBN_COLOUR_ECONOMY

    if domain == POS_Constants.WBN_DOMAIN_WEATHER then
        local wKey = WEATHER_KEYS[c.weatherKey or "clear"] or "UI_WBN_Weather_Clear"
        body = PhobosLib.safeGetText(wKey)
        -- Substitute template variables from extraData
        if c.extraData then
            if c.extraData.temp then
                body = body:gsub("{temp}", tostring(c.extraData.temp))
            end
            if c.extraData.wind then
                body = body:gsub("{wind}", tostring(c.extraData.wind))
            end
        end
        colour = POS_Constants.WBN_COLOUR_ECONOMY

    elseif domain == POS_Constants.WBN_DOMAIN_POWER then
        local transition = c.powerTransition or "status_on"
        local pKeys = POWER_KEYS[transition] or POWER_KEYS.status_on
        body = pickPhrase(pKeys)
        colour = POS_Constants.WBN_COLOUR_EMERGENCY

    elseif domain == POS_Constants.WBN_DOMAIN_COLOUR then
        local ts = c.targetStation or POS_Constants.WBN_STATION_CIVILIAN_MARKET
        local pool = FLAVOUR_POOLS[ts] or FLAVOUR_POOLS[POS_Constants.WBN_STATION_CIVILIAN_MARKET]
        body = pickPhrase(pool)
        colour = POS_Constants.WBN_COLOUR_TAG  -- subdued for flavour
    end

    -- Append closer
    if closer and closer ~= "" then
        body = body .. " " .. closer
    end

    local lines = {
        { text = tagText .. " " .. opener, r = POS_Constants.WBN_COLOUR_TAG.r, g = POS_Constants.WBN_COLOUR_TAG.g, b = POS_Constants.WBN_COLOUR_TAG.b },
        { text = body, r = colour.r, g = colour.g, b = colour.b },
    }

    PhobosLib.debug("POS", _TAG,
        "composeWorldState [" .. domain .. "]: " .. tagText .. " " .. opener .. " " .. body)

    return lines
end

---------------------------------------------------------------
-- Operations domain composer (agent state, missions)
---------------------------------------------------------------

--- Compose an operations bulletin from an agent/mission candidate.
--- @param candidate table Operations domain candidate
--- @param archetypeId string Voice pack archetype
--- @return table Array of { text, r, g, b } radio lines
function POS_WBN_CompositionService.composeOperations(candidate, archetypeId)
    local c = candidate
    local arch = archetypeId or POS_Constants.WBN_ARCHETYPE_QUARTERMASTER
    local C = POS_Constants.WBN_COLOUR_ECONOMY  -- reuse economy colour for ops
    local tagC = POS_Constants.WBN_COLOUR_TAG
    local stationTag = PhobosLib.safeGetText(POS_Constants.WBN_TAG_KEY_OPERATIONS)

    local openerPool = resolveArchetypePool(arch, POS_Constants.WBN_VP_SECTION_OPENER,
        DEFAULT_OPENERS[arch] or DEFAULT_OPENERS[POS_Constants.WBN_ARCHETYPE_QUARTERMASTER])
    local opener = pickPhrase(openerPool)

    local closerPool = resolveArchetypePool(arch, POS_Constants.WBN_VP_SECTION_CLOSER,
        DEFAULT_CLOSERS[arch] or DEFAULT_CLOSERS[POS_Constants.WBN_ARCHETYPE_QUARTERMASTER])
    local closer = pickPhrase(closerPool)

    local body = ""
    local eventType = c.eventType

    if eventType == POS_Constants.WBN_EVENT_AGENT_STATE_CHANGE then
        local agentName = c.agentName or PhobosLib.safeGetText("UI_WBN_Ops_UnknownAgent")
        local newState = c.newState or "unknown"
        local stateKey = "UI_WBN_Ops_AgentState_" .. newState
        local stateText = PhobosLib.safeGetText(stateKey)
        if stateText == stateKey then
            stateText = PhobosLib.safeGetText("UI_WBN_Ops_AgentState_Generic")
        end
        body = string.gsub(stateText, "{agent}", agentName)
    elseif eventType == POS_Constants.WBN_EVENT_MISSION_COMPLETED then
        if c.missionSuccess then
            body = PhobosLib.safeGetText("UI_WBN_Ops_MissionSuccess")
        else
            body = PhobosLib.safeGetText("UI_WBN_Ops_MissionFailure")
        end
    elseif eventType == POS_Constants.WBN_EVENT_WHOLESALER_POSTURE then
        body = PhobosLib.safeGetText("UI_WBN_Ops_WholesalerPosture")
    else
        body = PhobosLib.safeGetText("UI_WBN_Ops_GenericUpdate")
    end

    local lines = {
        { text = "[OPN] " .. opener, r = tagC.r, g = tagC.g, b = tagC.b },
        { text = body, r = C.r, g = C.g, b = C.b },
        { text = closer, r = tagC.r, g = tagC.g, b = tagC.b },
    }

    PhobosLib.debug("POS", _TAG,
        "composeOperations [" .. tostring(eventType) .. "]: " .. lines[1].text .. " " .. body .. " " .. closer)

    return lines
end

---------------------------------------------------------------
-- Forecast composer
---------------------------------------------------------------

--- Resolve confidence band label from raw forecast confidence value.
--- @param confidence number Raw confidence 0-1
--- @return string Band key for FORECAST_CONF_VERBS lookup
local function resolveForecastConfBand(confidence)
    if confidence >= 0.7 then return "high" end
    if confidence >= 0.4 then return "medium" end
    return "low"
end

--- Compose a forecast bulletin from an approved forecast candidate.
--- Assembles horizon opener, domain-specific body, and forecast closer
--- into RadioLine-ready coloured text entries.
--- @param candidate table Approved forecast candidate with isForecast=true
--- @param archetypeId string Voice archetype to use
--- @return table Array of { text, r, g, b } RadioLine entries
function POS_WBN_CompositionService.composeForecast(candidate, archetypeId)
    local c = candidate
    local arch = archetypeId or POS_Constants.WBN_ARCHETYPE_QUARTERMASTER
    local domain = c.domain or POS_Constants.WBN_DOMAIN_ECONOMY

    -- Resolve station tag
    local tagKey = POS_Constants.WBN_TAG_KEY_CIVILIAN
    if c.stationClass == POS_Constants.WBN_STATION_EMERGENCY then
        tagKey = POS_Constants.WBN_TAG_KEY_EMERGENCY
    end
    local tagText = PhobosLib.safeGetText(tagKey)

    -- Archetype opener (voice-pack aware)
    local openerPool = resolveArchetypePool(arch, POS_Constants.WBN_VP_SECTION_OPENER,
        DEFAULT_OPENERS[arch] or DEFAULT_OPENERS[POS_Constants.WBN_ARCHETYPE_QUARTERMASTER])
    local opener = pickPhrase(openerPool)

    -- Horizon opener
    local horizon = c.forecastHorizonDays or 1
    local horizonPool = FORECAST_OPENERS[horizon] or FORECAST_OPENERS[1]
    local horizonOpener = pickPhrase(horizonPool)

    -- Domain-specific body
    local body = ""
    local colour = POS_Constants.WBN_COLOUR_ECONOMY

    if domain == POS_Constants.WBN_DOMAIN_WEATHER then
        local wKey = FORECAST_WEATHER_KEYS[c.weatherKey or "forecast_clear"]
            or "UI_WBN_Forecast_Weather_Clear"
        body = PhobosLib.safeGetText(wKey)
        colour = POS_Constants.WBN_COLOUR_ECONOMY

    elseif domain == POS_Constants.WBN_DOMAIN_ECONOMY then
        local confBand = resolveForecastConfBand(c.forecastConfidence or 0.55)
        local verb = pickPhrase(FORECAST_CONF_VERBS[confBand])
        local zoneName = resolveZoneName(c.zoneId)
        local categoryName = resolveCategoryName(c.categoryId)
        local pct = tostring(c.percentChange or 0)
        local direction = c.direction or POS_Constants.WBN_DIR_STABLE

        if direction == POS_Constants.WBN_DIR_UP then
            body = PhobosLib.safeGetText("UI_WBN_Forecast_Econ_Up", categoryName, zoneName, verb, pct)
        elseif direction == POS_Constants.WBN_DIR_DOWN then
            body = PhobosLib.safeGetText("UI_WBN_Forecast_Econ_Down", categoryName, zoneName, verb)
        else
            body = PhobosLib.safeGetText("UI_WBN_Forecast_Econ_Stable", categoryName, zoneName, verb)
        end

        -- Append convoy note if present
        if c.convoyNote then
            local convoyText = PhobosLib.safeGetText("UI_WBN_Forecast_Econ_Convoy",
                resolveZoneName(c.convoyNote.zoneId), tostring(c.convoyNote.etaDays))
            body = body .. " " .. convoyText
        end

        colour = POS_Constants.WBN_COLOUR_ECONOMY

    elseif domain == POS_Constants.WBN_DOMAIN_POWER then
        local transition = c.powerTransition or "forecast_failure"
        local pKeys = FORECAST_POWER_KEYS[transition] or FORECAST_POWER_KEYS.forecast_failure
        body = pickPhrase(pKeys)
        colour = POS_Constants.WBN_COLOUR_EMERGENCY
    end

    -- Forecast closer
    local closer = pickPhrase(FORECAST_CLOSERS)

    -- Assemble full body with horizon opener + body + closer
    local fullBody = horizonOpener .. " " .. body
    if closer and closer ~= "" then
        fullBody = fullBody .. " " .. closer
    end

    local lines = {
        { text = tagText .. " " .. opener, r = POS_Constants.WBN_COLOUR_TAG.r, g = POS_Constants.WBN_COLOUR_TAG.g, b = POS_Constants.WBN_COLOUR_TAG.b },
        { text = fullBody, r = colour.r, g = colour.g, b = colour.b },
    }

    PhobosLib.debug("POS", _TAG,
        "composeForecast [" .. domain .. "]: " .. tagText .. " " .. opener .. " " .. fullBody)

    return lines
end

---------------------------------------------------------------
-- WBN text degradation (Signal Ecology v2)
---------------------------------------------------------------

--- Dropout rate lookup keyed by qualitative signal state.
local WBN_DROPOUT_RATES = {
    locked      = POS_Constants.SIGNAL_WBN_DROPOUT_LOCKED,
    clear       = POS_Constants.SIGNAL_WBN_DROPOUT_CLEAR,
    faded       = POS_Constants.SIGNAL_WBN_DROPOUT_FADED,
    fragmented  = POS_Constants.SIGNAL_WBN_DROPOUT_FRAGMENTED,
    ghosted     = POS_Constants.SIGNAL_WBN_DROPOUT_GHOSTED,
}

--- Pattern to detect number-like tokens (digits, optionally with decimal point or percent).
local NUMBER_PATTERN = "^%d+%.?%d*%%?$"

--- Degrade a single word based on the qualitative state and dropout rate.
--- For "fragmented" and worse, numbers become "???" and zone-like capitalised
--- words become "[garbled]". Otherwise dropped words become "...".
--- @param word string  The word to potentially degrade
--- @param dropoutRate number  Probability [0,1] of degrading this word
--- @param state string  Qualitative signal state
--- @return string  Original word or degraded replacement
local function degradeWord(word, dropoutRate, state)
    -- Roll for dropout
    local roll = PhobosLib.randFloat(0.0, 1.0)
    if roll >= dropoutRate then
        return word  -- survives
    end

    -- State-specific replacements for fragmented / ghosted
    if state == "fragmented" or state == "ghosted" then
        -- Numbers become vague
        if word:match(NUMBER_PATTERN) then
            return "???"
        end
        -- Capitalised multi-char words (likely zone or proper names) become garbled
        if #word > 2 and word:sub(1,1):match("%u") then
            return "[garbled]"
        end
    end

    return "..."
end

--- Degrade bulletin lines based on signal quality state.
--- Applies word-level dropout to each line's text, preserving colour data.
--- "lost" state returns an empty table (no bulletin delivered).
--- "locked" and "clear" states pass through unchanged.
--- @param lines table  Array of { text, r, g, b } composed bulletin lines
--- @param qualitativeState string  Signal state (locked/clear/faded/fragmented/ghosted/lost)
--- @return table  Degraded lines array (may be empty for "lost")
function POS_WBN_CompositionService.degradeBulletin(lines, qualitativeState)
    if not lines or #lines == 0 then return lines or {} end

    local state = qualitativeState or "clear"

    -- "lost" — no bulletin delivered
    if state == "lost" then
        PhobosLib.debug("POS", _TAG, "degradeBulletin: signal lost, bulletin suppressed")
        return {}
    end

    local dropoutRate = WBN_DROPOUT_RATES[state] or 0.00

    -- No degradation needed for locked / clear
    if dropoutRate <= 0.0 then return lines end

    local degraded = {}
    for i, line in ipairs(lines) do
        local text = line.text or ""
        local words = {}
        for w in text:gmatch("%S+") do
            words[#words + 1] = w
        end

        -- Apply per-word dropout
        local out = {}
        local prevWasEllipsis = false
        for _, w in ipairs(words) do
            local result = degradeWord(w, dropoutRate, state)
            -- Collapse consecutive "..." into a single one
            if result == "..." then
                if not prevWasEllipsis then
                    out[#out + 1] = result
                end
                prevWasEllipsis = true
            else
                out[#out + 1] = result
                prevWasEllipsis = false
            end
        end

        degraded[#degraded + 1] = {
            text = table.concat(out, " "),
            r = line.r,
            g = line.g,
            b = line.b,
        }
    end

    PhobosLib.debug("POS", _TAG,
        "degradeBulletin: state=" .. state .. " dropout=" .. tostring(dropoutRate))

    return degraded
end
